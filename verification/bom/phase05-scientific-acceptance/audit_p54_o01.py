#!/usr/bin/env python3
"""Independent P5-O01 ocean-transparency and sparse-replay auditor."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import struct
from dataclasses import dataclass
from pathlib import Path


NX = NY = 62
SNX = SNY = 31
OL = 2
DT = 1200.0
NSTEPS = 10
IDS = (4001, 4002, 4003)
TRAJ_FIELDS = 48
ENV_HEADER = 12
ENV_SOURCES = 3
ENV_ENDS = 2
R_SPHERE = 6_370_000.0
ROTATION_PERIOD = 86_164.0
OMEGA = 2.0 * math.pi / ROTATION_PERIOD
DEG = math.pi / 180.0
ALPHA = 0.0
TAU = 0.0103 * 86_400.0
R_VALUE = 0.823
SIGMA = 0.0
EXPECTED_CODES = (2, 1, 1, 0, 0, 4)
FATAL = re.compile(r"ABNORMAL END|ALL_PROC_DIE|Fortran runtime error|\bNaN\b|Infinity", re.I)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def exact_int(value: float, label: str) -> int:
    require(math.isfinite(value) and value == math.trunc(value), f"{label}: not exact integer")
    return int(value)


def read_be64(path: Path) -> tuple[float, ...]:
    payload = path.read_bytes()
    require(payload and len(payload) % 8 == 0, f"invalid float64 payload: {path}")
    return struct.unpack(f">{len(payload) // 8}d", payload)


def particle_id(record: tuple[float, ...]) -> int:
    high = exact_int(record[0], "ID high")
    low = exact_int(record[1], "ID low")
    require(0 <= high <= 0x7FFFFFFF and 0 <= low <= 0xFFFFFFFF, "ID word range")
    return (high << 32) | low


def check_log(path: Path) -> None:
    text = path.read_text(encoding="ascii", errors="replace")
    require("PROGRAM MAIN: Execution ended Normally" in text, f"normal end missing: {path}")
    require(FATAL.search(text) is None, f"fatal/non-finite marker: {path}")


def audit_normal_ends(root: Path) -> None:
    for label in ("mpi4-off", "mpi4-on"):
        logs = sorted((root / label).glob("STDOUT.[0-9][0-9][0-9][0-9]"))
        require(len(logs) == 4, f"{label}: four rank logs")
        for path in logs:
            check_log(path)
        for path in sorted((root / label).glob("STDERR.*")):
            require(path.stat().st_size == 0, f"nonempty stderr: {path}")
    check_log(root / "serial-on" / "run.log")


def file_inventory(root: Path, predicate) -> dict[str, Path]:
    return {
        path.relative_to(root).as_posix(): path
        for path in sorted(root.rglob("*"))
        if path.is_file() and predicate(path.relative_to(root).as_posix())
    }


def exact_inventory(left: Path, right: Path, predicate, label: str) -> int:
    left_files = file_inventory(left, predicate)
    right_files = file_inventory(right, predicate)
    require(set(left_files) == set(right_files), f"{label}: filename inventory")
    for name in left_files:
        require(left_files[name].read_bytes() == right_files[name].read_bytes(),
                f"{label}: byte difference {name}")
    return len(left_files)


def audit_ocean_identity(root: Path) -> tuple[int, int]:
    off, on = root / "mpi4-off", root / "mpi4-on"
    pickup_count = exact_inventory(
        off, on,
        lambda name: Path(name).name.startswith("pickup.") and
        Path(name).suffix in (".data", ".meta"),
        "ocean pickup",
    )
    off_mnc = {path.name: path for path in off.glob("mnc_test_*/*.nc")}
    on_mnc = {path.name: path for path in on.glob("mnc_test_*/*.nc")}
    require(len(off_mnc) == len(list(off.glob("mnc_test_*/*.nc"))),
            "BOM-off MNC basenames are not unique")
    require(len(on_mnc) == len(list(on.glob("mnc_test_*/*.nc"))),
            "BOM-on MNC basenames are not unique")
    require(set(off_mnc) == set(on_mnc), "selected MNC canonical filename inventory")
    for name in off_mnc:
        require(off_mnc[name].read_bytes() == on_mnc[name].read_bytes(),
                f"selected MNC byte difference {name}")
    mnc_count = len(off_mnc)
    require(pickup_count == NSTEPS * 4 * 2, "ocean pickup inventory count")
    require(mnc_count == 16, "selected MNC inventory count")
    return pickup_count, mnc_count


def decode_initial(run: Path) -> dict[int, tuple[float, float]]:
    values = read_be64(run / "bom_particles.data")
    require(len(values) == 4 * 8, "initial record count")
    records = [values[index:index + 8] for index in range(0, len(values), 8)]
    require(records[0] == (1.0, 8.0, 3.0, 1.0, 1.0, 64.0, 0.0, 0.0),
            "initial header")
    result: dict[int, tuple[float, float]] = {}
    for record in records[1:]:
        pid = particle_id(record)
        require(record[4:] == (0.0, 1.0, 0.0, 0.0), "initial state")
        result[pid] = (record[2], record[3])
    require(tuple(result) == IDS, "initial ID set/order")
    return result


def trajectory_files(run: Path) -> dict[int, list[Path]]:
    pattern = re.compile(r"^bom_traj\.(\d{10})\.(\d{3})\.(\d{3})\.data$")
    result: dict[int, list[Path]] = {}
    for path in run.iterdir():
        match = pattern.match(path.name)
        if match:
            result.setdefault(int(match.group(1)), []).append(path)
    require(tuple(sorted(result)) == tuple(range(1, NSTEPS + 1)), "trajectory iterations")
    return result


def decode_trajectory(run: Path, process_grid: tuple[int, int]) -> dict[tuple[int, int], tuple[float, ...]]:
    indexed = trajectory_files(run)
    result: dict[tuple[int, int], tuple[float, ...]] = {}
    for iteration in range(1, NSTEPS + 1):
        paths = sorted(indexed[iteration])
        require(len(paths) == 4, f"iter {iteration}: trajectory tile count")
        frame_ids: list[int] = []
        for path in paths:
            values = read_be64(path)
            require(len(values) % TRAJ_FIELDS == 0, f"trajectory record width: {path}")
            records = [values[index:index + TRAJ_FIELDS]
                       for index in range(0, len(values), TRAJ_FIELDS)]
            header = records[0]
            require(all(math.isfinite(value) for value in header), f"non-finite header: {path}")
            count = exact_int(header[2], "local owner count")
            require(len(records) == count + 1, f"local owner record count: {path}")
            require(header[:2] == (2.0, 48.0) and header[3] == 3.0, "schema/global count")
            require(header[7] == float(iteration), "trajectory iteration")
            require(header[8:11] == (iteration * DT, iteration * DT, (iteration + 1) * DT),
                    "trajectory schedule")
            require(header[11:13] == tuple(map(float, process_grid)), "process grid")
            codes = tuple(exact_int(header[index], "trajectory code") for index in range(18, 24))
            require(codes == EXPECTED_CODES, f"trajectory codes actual={codes}")
            require(header[24:27] == (27.0, 22.0, 48.0), "trajectory descriptor")
            require(path.with_suffix(".meta").is_file(), f"trajectory meta missing: {path}")
            for record in records[1:]:
                require(all(math.isfinite(value) for value in record), f"non-finite owner: {path}")
                pid = particle_id(record)
                require(pid in IDS and record[2] == 1.0 and record[20] == 1.0,
                        "owner ID/status/active")
                require(record[3:5] == (iteration * DT, float(iteration)), "owner time/iter")
                diag = record[21:48]
                require(len(diag) == 27 and all(math.isfinite(value) for value in diag),
                        "trajectory diagnostics")
                require(diag[6:10] == (diag[0], diag[1], diag[0], diag[1]),
                        "NONE/alpha=0 field identities")
                require(record[15:17] == diag[25:27], "drift diagnostic identity")
                require((iteration, pid) not in result, "duplicate global trajectory ID")
                result[(iteration, pid)] = record
                frame_ids.append(pid)
        require(tuple(sorted(frame_ids)) == IDS, f"iter {iteration}: global ID set")
    require(len(result) == NSTEPS * len(IDS), "trajectory row total")
    return result


def distance_m(a: tuple[float, float], b: tuple[float, float]) -> float:
    mean_lat = DEG * 0.5 * (a[1] + b[1])
    dx = R_SPHERE * DEG * math.cos(mean_lat) * (a[0] - b[0])
    dy = R_SPHERE * DEG * (a[1] - b[1])
    return math.hypot(dx, dy)


def audit_layouts(root: Path) -> tuple[dict[tuple[int, int], tuple[float, ...]], dict[int, float]]:
    mpi = decode_trajectory(root / "mpi4-on", (2, 2))
    serial = decode_trajectory(root / "serial-on", (1, 1))
    initial = decode_initial(root / "mpi4-on")
    paths = {pid: 0.0 for pid in IDS}
    previous = initial.copy()
    for iteration in range(1, NSTEPS + 1):
        for pid in IDS:
            a, b = mpi[(iteration, pid)], serial[(iteration, pid)]
            require(a[0:5] == b[0:5], f"serial/MPI exact ID/state iter={iteration} id={pid}")
            require(a[7:11] == b[7:11], f"serial/MPI exact release/age/index iter={iteration} id={pid}")
            error = distance_m((a[5], a[6]), (b[5], b[6]))
            bound = max(1.0e-6, 5.0e-11 * max(paths[pid], 1.0))
            require(error <= bound, f"serial/MPI coordinate error={error} bound={bound}")
            current = (a[5], a[6])
            paths[pid] += distance_m(current, previous[pid])
            previous[pid] = current
            require(0.5 < current[0] < 59.5 and 15.5 < current[1] < 74.5,
                    f"owner outside safe wet interior id={pid}")
    require(all(path > 0.0 and math.isfinite(path) for path in paths.values()),
            "finite nonzero production paths")
    return mpi, paths


@dataclass
class EnvFrame:
    old_time: float
    new_time: float
    values: dict[tuple[int, int, int, int], tuple[float, float, bool]]
    gradients: dict[tuple[int, int, int, int], tuple[float, float, float, float]]


def decode_env_frame(run: Path, iteration: int) -> EnvFrame:
    paths = sorted(run.glob(f"pickup_bom.{iteration:010d}.env.*.*.data"))
    require(len(paths) == 4, f"endpoint tile count iter={iteration}")
    interior: dict[tuple[int, int, int, int], tuple[float, float, bool]] = {}
    old_time = new_time = -1.0
    for path in paths:
        flat = read_be64(path)
        fields = exact_int(flat[1], "env fields")
        require(fields == ENV_HEADER + 3 * (SNX + 2 * OL) * (SNY + 2 * OL) * ENV_ENDS * ENV_SOURCES,
                "env field count")
        record = flat[:fields]
        require(record[0] == 2.0 and record[2:4] == (float(iteration), iteration * DT),
                "env schema/iteration/time")
        require(record[6:8] == ((iteration - 1) * DT, iteration * DT), "env bracket")
        old_time, new_time = record[6], record[7]
        i_global, j_global = exact_int(record[10], "env iGlobal"), exact_int(record[11], "env jGlobal")
        offset = ENV_HEADER
        for source in range(ENV_SOURCES):
            for endpoint in range(ENV_ENDS):
                for local_j in range(1 - OL, SNY + OL + 1):
                    for local_i in range(1 - OL, SNX + OL + 1):
                        east, north, valid = record[offset:offset + 3]
                        offset += 3
                        require(math.isfinite(east) and math.isfinite(north) and valid in (0.0, 1.0),
                                "endpoint finite/valid")
                        if 1 <= local_i <= SNX and 1 <= local_j <= SNY:
                            key = (source, endpoint, i_global + local_i - 1,
                                   j_global + local_j - 1)
                            require(key not in interior, f"duplicate endpoint cell {key}")
                            interior[key] = (east, north, valid == 1.0)
        require(offset == fields, "endpoint decode length")
    require(len(interior) == ENV_SOURCES * ENV_ENDS * NX * NY,
            "global endpoint interior cardinality")
    return EnvFrame(old_time, new_time, interior, {})


def endpoint_gradient(frame: EnvFrame, source: int, endpoint: int, i: int, j: int
                      ) -> tuple[float, float, float, float]:
    key = (source, endpoint, i, j)
    if key in frame.gradients:
        return frame.gradients[key]
    center = frame.values[key]
    west, east = frame.values[(source, endpoint, i - 1, j)], frame.values[(source, endpoint, i + 1, j)]
    south, north = frame.values[(source, endpoint, i, j - 1)], frame.values[(source, endpoint, i, j + 1)]
    require(center[2] and west[2] and east[2] and south[2] and north[2],
            f"replay derivative not in five-point wet interior {(i, j)}")
    latitude = 14.0 + j - 0.5
    dx = R_SPHERE * DEG * math.cos(DEG * latitude)
    dy = R_SPHERE * DEG
    result = ((east[0] - west[0]) / (2.0 * dx),
              (north[0] - south[0]) / (2.0 * dy),
              (east[1] - west[1]) / (2.0 * dx),
              (north[1] - south[1]) / (2.0 * dy))
    frame.gradients[key] = result
    return result


def point_at_time(frame: EnvFrame, source: int, i: int, j: int, time_s: float
                  ) -> tuple[float, float, float, float, float, float, float, float]:
    old = frame.values[(source, 0, i, j)]
    new = frame.values[(source, 1, i, j)]
    require(old[2] and new[2], "invalid replay endpoint")
    theta = (time_s - frame.old_time) / (frame.new_time - frame.old_time)
    require(0.0 <= theta <= 1.0, "replay time outside endpoint bracket")
    weight = 1.0 - theta
    east = weight * old[0] + theta * new[0]
    north = weight * old[1] + theta * new[1]
    dt_east = (new[0] - old[0]) / (frame.new_time - frame.old_time)
    dt_north = (new[1] - old[1]) / (frame.new_time - frame.old_time)
    grad0 = endpoint_gradient(frame, source, 0, i, j)
    grad1 = endpoint_gradient(frame, source, 1, i, j)
    gradients = tuple(weight * grad0[index] + theta * grad1[index] for index in range(4))
    return east, north, dt_east, dt_north, *gradients


def interpolate(frame: EnvFrame, x: float, y: float, time_s: float):
    ix, jy = x + 1.5, y - 13.5
    i0, j0 = math.floor(ix), math.floor(jy)
    fi, fj = ix - i0, jy - j0
    require(3 <= i0 <= NX - 3 and 3 <= j0 <= NY - 3, "replay leaves central stencil")
    weights = ((i0, j0, (1.0 - fi) * (1.0 - fj)),
               (i0 + 1, j0, fi * (1.0 - fj)),
               (i0, j0 + 1, (1.0 - fi) * fj),
               (i0 + 1, j0 + 1, fi * fj))
    sources = [[0.0] * 8 for _ in range(ENV_SOURCES)]
    f_cori = tau_sphere = 0.0
    for i, j, weight in weights:
        latitude = 14.0 + j - 0.5
        f_cori += weight * (2.0 * OMEGA * math.sin(DEG * latitude))
        tau_sphere += weight * (math.tan(DEG * latitude) / R_SPHERE)
        for source in range(ENV_SOURCES):
            point = point_at_time(frame, source, i, j, time_s)
            for index, value in enumerate(point):
                sources[source][index] += weight * value
    return sources, f_cori, tau_sphere


def covariant(east: float, north: float, dt_east: float, dt_north: float,
              de_east: float, dn_east: float, de_north: float, dn_north: float,
              tau_sphere: float) -> tuple[float, float, float]:
    material_e = dt_east + east * de_east + north * dn_east - tau_sphere * east * north
    material_n = dt_north + east * de_north + north * dn_north + tau_sphere * east * east
    vorticity = de_north - dn_east + tau_sphere * east
    return material_e, material_n, vorticity


def rhs(frame: EnvFrame, x: float, y: float, time_s: float) -> tuple[float, float]:
    source, f_cori, tau_sphere = interpolate(frame, x, y, time_s)
    ocean, stokes, wind = source
    v = [ocean[index] + SIGMA * stokes[index] for index in range(8)]
    u = [(1.0 - ALPHA) * v[index] + ALPHA * wind[index] for index in range(8)]
    dv_e, dv_n, omega = covariant(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7],
                                  tau_sphere)
    du_e, du_n, _ = covariant(u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7],
                              tau_sphere)
    c_v = f_cori + omega / 3.0
    c_u = f_cori + tau_sphere * u[0] + R_VALUE * omega / 3.0
    inert_e = R_VALUE * dv_e - R_VALUE * c_v * v[1] - du_e + c_u * u[1]
    inert_n = R_VALUE * dv_n + R_VALUE * c_v * v[0] - du_n - c_u * u[0]
    drift_e = u[0] + TAU * inert_e
    drift_n = u[1] + TAU * inert_n
    denom_y = R_SPHERE * DEG
    denom_x = denom_y * math.cos(DEG * y)
    return drift_e / denom_x, drift_n / denom_y


def rk4(frame: EnvFrame, state: tuple[float, float], time_s: float) -> tuple[float, float]:
    x, y = state
    k1 = rhs(frame, x, y, time_s)
    k2 = rhs(frame, x + 0.5 * DT * k1[0], y + 0.5 * DT * k1[1], time_s + 0.5 * DT)
    k3 = rhs(frame, x + 0.5 * DT * k2[0], y + 0.5 * DT * k2[1], time_s + 0.5 * DT)
    k4 = rhs(frame, x + DT * k3[0], y + DT * k3[1], time_s + DT)
    scale = DT / 6.0
    return (x + scale * (k1[0] + 2.0 * k2[0] + 2.0 * k3[0] + k4[0]),
            y + scale * (k1[1] + 2.0 * k2[1] + 2.0 * k3[1] + k4[1]))


def audit_replay(root: Path, production: dict[tuple[int, int], tuple[float, ...]],
                 paths: dict[int, float], output: Path) -> tuple[int, float]:
    run = root / "mpi4-on"
    states = decode_initial(run)
    rows: list[dict[str, object]] = []
    maximum_error = 0.0
    for iteration in range(1, NSTEPS + 1):
        frame = decode_env_frame(run, iteration)
        for pid in IDS:
            states[pid] = rk4(frame, states[pid], (iteration - 1) * DT)
            record = production[(iteration, pid)]
            actual = (record[5], record[6])
            error = distance_m(states[pid], actual)
            bound = max(1.0e-6, 5.0e-11 * paths[pid])
            require(error <= bound,
                    f"sparse replay error iter={iteration} id={pid} error={error} bound={bound}")
            maximum_error = max(maximum_error, error)
            rows.append({
                "iteration": iteration, "particle_id": pid, "time_s": iteration * DT,
                "actual_x_deg": f"{actual[0]:.17e}", "actual_y_deg": f"{actual[1]:.17e}",
                "replay_x_deg": f"{states[pid][0]:.17e}",
                "replay_y_deg": f"{states[pid][1]:.17e}",
                "error_m": f"{error:.17e}", "bound_m": f"{bound:.17e}",
            })
    with output.open("w", encoding="ascii", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return len(rows), maximum_error


def audit_standard_copy(root: Path) -> int:
    expected = json.loads((root / "expected.json").read_text(encoding="ascii"))
    require(expected["schema"] == "MITGCM-BOM-P5-O01-input-v1", "input manifest schema")
    stock = root / "stock-input"
    inventory = expected["standard_sha256"]
    require(set(inventory) == {path.name for path in stock.iterdir() if path.is_file()},
            "stock input filename inventory")
    for name, digest in inventory.items():
        require(sha256(stock / name) == digest, f"stock copy checksum: {name}")
    return len(inventory)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--normalized", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    stock_files = audit_standard_copy(root)
    audit_normal_ends(root)
    ocean_files, mnc_files = audit_ocean_identity(root)
    production, paths = audit_layouts(root)
    replay_rows, maximum_error = audit_replay(root, production, paths, args.normalized)
    result = {
        "schema": "MITGCM-BOM-P5-O01-audit-v1",
        "result": "PASS",
        "standard_input_files": stock_files,
        "ocean_pickup_files_exact": ocean_files,
        "mnc_selected_files_exact": mnc_files,
        "trajectory_rows_per_layout": len(production),
        "endpoint_frames": NSTEPS,
        "sparse_replay_rows": replay_rows,
        "maximum_replay_error_m": maximum_error,
        "path_m": {str(pid): paths[pid] for pid in IDS},
    }
    args.report.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print("P5-O01 AUDIT PASS ocean_pickups=80 mnc=16 trajectories=60 replay=30")


if __name__ == "__main__":
    main()
