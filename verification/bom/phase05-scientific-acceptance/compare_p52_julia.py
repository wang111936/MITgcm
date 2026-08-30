#!/usr/bin/env python3
"""Independently decode P5-J01 production output and compare locked Julia truth."""

from __future__ import annotations

import argparse
import csv
import html
import json
import math
import re
import struct
import sys
from collections import defaultdict
from pathlib import Path
from typing import Iterable


SCHEMA = 2
TRAJ_FIELDS = 48
PICKUP_FIELDS = 45
NDIAG = 27
TRAJ_DIAG_OFFSET = 21
PICKUP_DIAG_OFFSET = 18
EXPECTED_IDS = (1001, 1002, 1003)
EXPECTED_TILES = ((1, 1), (1, 2), (2, 1), (2, 2))
EXPECTED_CODES = (2, 2, 1, 1, 1, 4)
NSTEPS = 96
DT = 900.0
COMP_ABS_TOL = 2.0e-12
COMP_REL_TOL = 5.0e-12
POS_ABS_TOL_M = 1.0e-6
POS_PATH_REL_TOL = 5.0e-11
DIAG_NAMES = (
    "vbase_e", "vbase_n", "vs_e", "vs_n", "vw_e", "vw_n",
    "v_e", "v_n", "u_e", "u_n", "dv_e", "dv_n", "du_e", "du_n",
    "omega", "f_cori", "tau_sphere", "c_v", "c_u",
    "rot_v_e", "rot_v_n", "rot_u_e", "rot_u_n",
    "inert_e", "inert_n", "drift_e", "drift_n",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def exact_int(value: float, label: str) -> int:
    require(math.isfinite(value), f"{label}: non-finite")
    require(value == math.trunc(value), f"{label}: non-integral {value!r}")
    return int(value)


def close_exact(a: float, b: float, label: str) -> None:
    require(a == b, f"{label}: {a!r} != {b!r}")


def particle_id(record: tuple[float, ...], label: str) -> int:
    high = exact_int(record[0], f"{label} ID high")
    low = exact_int(record[1], f"{label} ID low")
    require(0 <= high <= 0x7FFFFFFF, f"{label}: high ID word")
    require(0 <= low <= 0xFFFFFFFF, f"{label}: low ID word")
    return (high << 32) | low


def read_be64_records(path: Path, fields: int) -> list[tuple[float, ...]]:
    payload = path.read_bytes()
    width = fields * 8
    require(payload and len(payload) % width == 0,
            f"{path}: partial/empty {fields}-field record")
    return [
        struct.unpack(f">{fields}d", payload[offset:offset + width])
        for offset in range(0, len(payload), width)
    ]


def parse_meta(path: Path) -> dict[str, object]:
    text = path.read_text(encoding="ascii")
    result: dict[str, object] = {}
    for key in ("nDims", "nrecords", "timeStepNumber"):
        match = re.search(rf"\b{key}\s*=\s*\[\s*([0-9]+)\s*\]", text)
        require(match is not None, f"{path}: missing {key}")
        result[key] = int(match.group(1))
    match = re.search(r"\bdataprec\s*=\s*\[\s*'([^']+)'\s*\]", text)
    require(match is not None, f"{path}: missing dataprec")
    result["dataprec"] = match.group(1)
    match = re.search(r"\bdimList\s*=\s*\[(.*?)\];", text, re.S)
    require(match is not None, f"{path}: missing dimList")
    result["dimList"] = tuple(int(value) for value in re.findall(r"[0-9]+", match.group(1)))
    return result


def check_meta(path: Path, fields: int, records: int, iteration: int) -> None:
    meta = parse_meta(path)
    require(meta["nDims"] == 3, f"{path}: nDims")
    require(meta["dataprec"] == "float64", f"{path}: dataprec")
    require(meta["nrecords"] == records, f"{path}: nrecords")
    require(meta["timeStepNumber"] == iteration, f"{path}: timeStepNumber")
    dim_list = meta["dimList"]
    require(isinstance(dim_list, tuple) and len(dim_list) == 9,
            f"{path}: dimList length")
    require(dim_list[6:9] == (fields, 1, fields), f"{path}: field dimension")


def check_diag(record: tuple[float, ...], offset: int, label: str) -> tuple[float, ...]:
    diag = record[offset:offset + NDIAG]
    require(len(diag) == NDIAG and all(math.isfinite(v) for v in diag),
            f"{label}: invalid diagnostics")
    legacy_start = 11 if offset == TRAJ_DIAG_OFFSET else 9
    legacy = record[legacy_start:legacy_start + 6]
    expected = (diag[0], diag[1], diag[4], diag[5], diag[25], diag[26])
    require(legacy == expected, f"{label}: legacy/diagnostic mismatch")
    require(diag[6] == diag[0] + 1.2 * diag[2], f"{label}: v_e identity")
    require(diag[7] == diag[1] + 1.2 * diag[3], f"{label}: v_n identity")
    require(diag[8] == (1.0 - 0.00337) * diag[6] + 0.00337 * diag[4],
            f"{label}: u_e identity")
    require(diag[9] == (1.0 - 0.00337) * diag[7] + 0.00337 * diag[5],
            f"{label}: u_n identity")
    require(diag[25] == record[15 if offset == TRAJ_DIAG_OFFSET else 13],
            f"{label}: east drift identity")
    require(diag[26] == record[16 if offset == TRAJ_DIAG_OFFSET else 14],
            f"{label}: north drift identity")
    return diag


def read_initial(input_bundle: Path) -> dict[int, dict[str, float]]:
    data = input_bundle / "bom_particles.data"
    meta = input_bundle / "bom_particles.meta"
    records = read_be64_records(data, 8)
    check_meta(meta, 8, 4, 0)
    require(records[0] == (1.0, 8.0, 3.0, 1.0, 1.0, 64.0, 0.0, 0.0),
            "initial particle header")
    result: dict[int, dict[str, float]] = {}
    previous = 0
    for record in records[1:]:
        require(all(math.isfinite(v) for v in record), "initial non-finite")
        pid = particle_id(record, "initial")
        require(pid > previous, "initial duplicate/reordered ID")
        require(record[4:] == (0.0, 1.0, 0.0, 0.0), f"initial flags ID {pid}")
        result[pid] = {"time_s": 0.0, "x_m": record[2], "y_m": record[3]}
        previous = pid
    require(tuple(result) == EXPECTED_IDS, "initial exact ID set/order")
    return result


def tile_from_name(path: Path) -> tuple[int, int]:
    match = re.search(r"\.(\d{3})\.(\d{3})\.data$", path.name)
    require(match is not None, f"bad tile name: {path.name}")
    return int(match.group(1)), int(match.group(2))


def decode_trajectory(run_dir: Path) -> tuple[dict[tuple[int, int], dict[str, object]], dict[str, object]]:
    pattern = re.compile(r"^bom_traj\.(\d{10})\.(\d{3})\.(\d{3})\.data$")
    indexed: dict[int, list[Path]] = defaultdict(list)
    for path in run_dir.iterdir():
        match = pattern.match(path.name)
        if match:
            indexed[int(match.group(1))].append(path)
    require(tuple(sorted(indexed)) == tuple(range(1, NSTEPS + 1)),
            "trajectory suffix set must be exactly 1..96")
    actual: dict[tuple[int, int], dict[str, object]] = {}
    expected_all_files: set[str] = set()
    tile_counts: dict[str, int] = {}
    for iteration in range(1, NSTEPS + 1):
        paths = sorted(indexed[iteration], key=tile_from_name)
        require(tuple(tile_from_name(p) for p in paths) == EXPECTED_TILES,
                f"iteration {iteration}: exact tile set/order")
        frame: list[tuple[int, tuple[float, ...], tuple[int, int]]] = []
        for path in paths:
            meta_path = path.with_suffix(".meta")
            require(meta_path.is_file(), f"missing metadata: {meta_path}")
            expected_all_files.update((path.name, meta_path.name))
            records = read_be64_records(path, TRAJ_FIELDS)
            check_meta(meta_path, TRAJ_FIELDS, len(records), iteration)
            header = records[0]
            require(all(math.isfinite(v) for v in header), f"{path}: non-finite header")
            count = exact_int(header[2], f"{path}: local count")
            require(len(records) == count + 1, f"{path}: local count mismatch")
            require(header[0:2] == (2.0, 48.0), f"{path}: schema/fields")
            require(exact_int(header[3], f"{path}: global count") == 3,
                    f"{path}: global count")
            require(header[4:7] == (1.0, 1.0, 64.0), f"{path}: version/precision")
            require(exact_int(header[7], f"{path}: iteration") == iteration,
                    f"{path}: iteration")
            time_s = iteration * DT
            require(header[8:11] == (time_s, time_s, time_s + DT),
                    f"{path}: sample schedule")
            require(header[11:13] == (2.0, 2.0), f"{path}: process grid")
            tile = tile_from_name(path)
            derived_tile = (1 + (exact_int(header[13], f"{path}: iGlobal") - 1) // 4,
                            1 + (exact_int(header[14], f"{path}: jGlobal") - 1) // 3)
            require(derived_tile == tile, f"{path}: global tile origin/name")
            require(header[16:18] == (1.0, 1.0), f"{path}: local tile index")
            codes = tuple(exact_int(header[i], f"{path}: code") for i in range(18, 24))
            require(codes == EXPECTED_CODES, f"{path}: mode/source/integrator codes")
            require(header[24:27] == (27.0, 22.0, 48.0),
                    f"{path}: diagnostic descriptor")
            require(all(v == 0.0 for v in header[27:]), f"{path}: reserved header")
            previous = 0
            for record in records[1:]:
                require(all(math.isfinite(v) for v in record), f"{path}: non-finite particle")
                pid = particle_id(record, str(path))
                require(pid > previous, f"{path}: duplicate/reordered tile ID")
                require(pid in EXPECTED_IDS, f"{path}: unexpected ID {pid}")
                require(record[2] == 1.0 and record[20] == 1.0,
                        f"{path}: inactive/status ID {pid}")
                require(record[3] == time_s and exact_int(record[4], "record iteration") == iteration,
                        f"{path}: record time/iteration ID {pid}")
                diag = check_diag(record, TRAJ_DIAG_OFFSET, f"iter {iteration} ID {pid}")
                require(record[17:20] == (header[15], header[16], header[17]),
                        f"{path}: ownership ID {pid}")
                frame.append((pid, record, tile))
                previous = pid
            tile_counts[f"{iteration:010d}.{tile[0]:03d}.{tile[1]:03d}"] = count
        frame.sort(key=lambda item: item[0])
        require(tuple(item[0] for item in frame) == EXPECTED_IDS,
                f"iteration {iteration}: global ID set/order/duplicates")
        for pid, record, tile in frame:
            actual[(iteration, pid)] = {
                "time_s": record[3], "x_m": record[5], "y_m": record[6],
                "rhs_x_m_s": record[15], "rhs_y_m_s": record[16],
                "diag": record[TRAJ_DIAG_OFFSET:TRAJ_DIAG_OFFSET + NDIAG],
                "tile": f"{tile[0]:03d}.{tile[1]:03d}",
            }
    matching_names = {
        p.name for p in run_dir.iterdir()
        if p.name.startswith("bom_traj.") and (p.suffix in (".data", ".meta"))
    }
    require(matching_names == expected_all_files,
            "trajectory inventory has missing, duplicate, or unexpected data/meta files")
    inventory = {
        "iterations": NSTEPS,
        "tiles_per_iteration": len(EXPECTED_TILES),
        "data_files": NSTEPS * len(EXPECTED_TILES),
        "meta_files": NSTEPS * len(EXPECTED_TILES),
        "production_particle_records": len(actual),
        "tile_local_counts": tile_counts,
    }
    return actual, inventory


def decode_pickups(run_dir: Path) -> dict[str, object]:
    report: dict[str, object] = {}
    for iteration in (48, 96):
        suffix = f"{iteration:010d}"
        time_s = iteration * DT
        sig_data = run_dir / f"pickup_bom.{suffix}.sig.data"
        sig_meta = run_dir / f"pickup_bom.{suffix}.sig.meta"
        require(sig_data.is_file() and sig_meta.is_file(), f"pickup {suffix}: signature family")
        signature_records = read_be64_records(sig_data, 24)
        check_meta(sig_meta, 24, len(signature_records), iteration)
        flat = tuple(value for record in signature_records for value in record)
        sig_fields = exact_int(flat[1], f"pickup {suffix}: signature fields")
        require(sig_fields == 1333 and len(flat) >= sig_fields,
                f"pickup {suffix}: signature length")
        signature = flat[:sig_fields]
        require(signature[0] == 2.0, f"pickup {suffix}: schema")
        require(signature[2:12] == (2.0, 2.0, 4.0, 3.0, 1.0, 1.0,
                                     8.0, 6.0, 64.0, 3.0),
                f"pickup {suffix}: decomposition/global signature")
        require(signature[12:16] == (float(iteration), time_s, DT, time_s + DT),
                f"pickup {suffix}: time signature")
        require(tuple(exact_int(signature[i], "pickup code") for i in range(16, 22))
                == EXPECTED_CODES, f"pickup {suffix}: mode/source/integrator")
        require(signature[52] == 45.0, f"pickup {suffix}: particle fields")
        paths = sorted(run_dir.glob(f"pickup_bom.{suffix}.[0-9][0-9][0-9]."
                                    "[0-9][0-9][0-9].data"), key=tile_from_name)
        require(tuple(tile_from_name(p) for p in paths) == EXPECTED_TILES,
                f"pickup {suffix}: exact tile set")
        rows: list[tuple[int, tuple[float, ...]]] = []
        for path in paths:
            records = read_be64_records(path, PICKUP_FIELDS)
            check_meta(path.with_suffix(".meta"), PICKUP_FIELDS, len(records), iteration)
            header = records[0]
            count = exact_int(header[2], f"{path}: count")
            require(len(records) == count + 1, f"{path}: count mismatch")
            require(header[:7] == (2.0, 45.0, float(count), 3.0, 1.0, 1.0, 64.0),
                    f"{path}: header")
            require(header[7:11] == (float(iteration), time_s, time_s + DT, DT),
                    f"{path}: schedule")
            require(header[11:17] == (2.0, 2.0, 4.0, 3.0, 1.0, 1.0),
                    f"{path}: decomposition")
            derived_tile = (1 + (exact_int(header[17], f"{path}: iGlobal") - 1) // 4,
                            1 + (exact_int(header[18], f"{path}: jGlobal") - 1) // 3)
            require(derived_tile == tile_from_name(path), f"{path}: global tile")
            require(header[20:22] == (1.0, 1.0), f"{path}: local tile")
            require(header[22:24] == (64.0, 27.0), f"{path}: descriptor")
            previous = 0
            for record in records[1:]:
                pid = particle_id(record, str(path))
                require(pid > previous and pid in EXPECTED_IDS, f"{path}: ID order/set")
                require(record[2] == 1.0, f"{path}: status ID {pid}")
                check_diag(record, PICKUP_DIAG_OFFSET, f"pickup {iteration} ID {pid}")
                rows.append((pid, record))
                previous = pid
        rows.sort(key=lambda item: item[0])
        require(tuple(pid for pid, _ in rows) == EXPECTED_IDS,
                f"pickup {suffix}: global exact IDs")
        main_data = sorted(run_dir.glob(f"pickup.{suffix}*.data"))
        main_meta = sorted(run_dir.glob(f"pickup.{suffix}*.meta"))
        report[suffix] = {
            "time_s": time_s, "particles": len(rows), "tiles": len(paths),
            "signature_fields": sig_fields,
            "main_data_files": len(main_data), "main_meta_files": len(main_meta),
        }
    return report


def read_csv(path: Path, required_fields: Iterable[str]) -> list[dict[str, str]]:
    with path.open(newline="", encoding="ascii") as stream:
        reader = csv.DictReader(stream)
        require(reader.fieldnames is not None, f"{path}: missing header")
        require(tuple(reader.fieldnames) == tuple(required_fields), f"{path}: exact header mismatch")
        rows = list(reader)
    require(rows, f"{path}: empty")
    return rows


def write_csv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="ascii") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def svg_polyline(path: Path, title: str, series: list[tuple[str, list[tuple[float, float]], str]],
                 x_label: str, y_label: str) -> None:
    width, height = 900, 520
    left, right, top, bottom = 85, 25, 55, 70
    points = [point for _, values, _ in series for point in values]
    require(points, f"{path}: no plot points")
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    xmin, xmax, ymin, ymax = min(xs), max(xs), min(ys), max(ys)
    if xmax == xmin:
        xmax = xmin + 1.0
    if ymax == ymin:
        ymax = ymin + 1.0
    padx, pady = 0.04 * (xmax - xmin), 0.06 * (ymax - ymin)
    xmin, xmax, ymin, ymax = xmin - padx, xmax + padx, ymin - pady, ymax + pady
    plot_w, plot_h = width - left - right, height - top - bottom
    sx = lambda x: left + (x - xmin) / (xmax - xmin) * plot_w
    sy = lambda y: top + (ymax - y) / (ymax - ymin) * plot_h
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width/2}" y="28" text-anchor="middle" font-family="sans-serif" font-size="18">{html.escape(title)}</text>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top+plot_h}" stroke="#333"/>',
        f'<line x1="{left}" y1="{top+plot_h}" x2="{left+plot_w}" y2="{top+plot_h}" stroke="#333"/>',
    ]
    for tick in range(6):
        frac = tick / 5
        xv, yv = xmin + frac * (xmax - xmin), ymin + frac * (ymax - ymin)
        xpix, ypix = sx(xv), sy(yv)
        lines.extend([
            f'<line x1="{xpix:.2f}" y1="{top}" x2="{xpix:.2f}" y2="{top+plot_h}" stroke="#ddd"/>',
            f'<text x="{xpix:.2f}" y="{top+plot_h+22}" text-anchor="middle" font-family="monospace" font-size="11">{xv:.4g}</text>',
            f'<line x1="{left}" y1="{ypix:.2f}" x2="{left+plot_w}" y2="{ypix:.2f}" stroke="#ddd"/>',
            f'<text x="{left-8}" y="{ypix+4:.2f}" text-anchor="end" font-family="monospace" font-size="11">{yv:.4g}</text>',
        ])
    for index, (label, values, color) in enumerate(series):
        encoded = " ".join(f"{sx(x):.3f},{sy(y):.3f}" for x, y in values)
        dash = ' stroke-dasharray="8 5"' if "reference" in label.lower() else ""
        lines.append(f'<polyline points="{encoded}" fill="none" stroke="{color}" stroke-width="2"{dash}/>' )
        lx = left + 15 + index * 190
        lines.extend([
            f'<line x1="{lx}" y1="{height-20}" x2="{lx+28}" y2="{height-20}" stroke="{color}" stroke-width="3"{dash}/>',
            f'<text x="{lx+34}" y="{height-16}" font-family="sans-serif" font-size="12">{html.escape(label)}</text>',
        ])
    lines.extend([
        f'<text x="{left+plot_w/2}" y="{height-40}" text-anchor="middle" font-family="sans-serif" font-size="13">{html.escape(x_label)}</text>',
        f'<text x="18" y="{top+plot_h/2}" transform="rotate(-90 18 {top+plot_h/2})" text-anchor="middle" font-family="sans-serif" font-size="13">{html.escape(y_label)}</text>',
        '</svg>',
    ])
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def compare(args: argparse.Namespace) -> dict[str, object]:
    args.output_dir.mkdir(parents=True, exist_ok=False)
    initial = read_initial(args.input_bundle)
    production, inventory = decode_trajectory(args.run_dir)
    pickups = decode_pickups(args.run_dir)

    traj_fields = ("particle_id", "time_s", "x_m", "y_m", "path_m")
    component_fields = ("time_index", "particle_id", "time_s", "x_m", "y_m",
                        "rhs_x_m_s", "rhs_y_m_s", *DIAG_NAMES)
    ref_traj_rows = read_csv(args.reference_trajectory, traj_fields)
    ref_comp_rows = read_csv(args.reference_components, component_fields)
    require(len(ref_traj_rows) == 291 and len(ref_comp_rows) == 291,
            "locked Julia row cardinality must be 291")

    ref_traj: dict[tuple[int, int], dict[str, float]] = {}
    previous_key: tuple[int, int] | None = None
    for row in ref_traj_rows:
        pid, time_s = int(row["particle_id"]), float(row["time_s"])
        time_index = exact_int(time_s / DT, "reference trajectory time index")
        key = (time_index, pid)
        require(key > previous_key if previous_key is not None else True,
                "reference trajectory exact time/ID order")
        require(pid in EXPECTED_IDS and 0 <= time_index <= NSTEPS,
                "reference trajectory key range")
        ref_traj[key] = {name: float(row[name]) for name in traj_fields[1:]}
        previous_key = key
    ref_comp: dict[tuple[int, int], dict[str, float]] = {}
    previous_key = None
    for row in ref_comp_rows:
        time_index, pid = int(row["time_index"]), int(row["particle_id"])
        key = (time_index, pid)
        require(key > previous_key if previous_key is not None else True,
                "reference component exact time/ID order")
        require(pid in EXPECTED_IDS and 0 <= time_index <= NSTEPS,
                "reference component key range")
        values = {name: float(row[name]) for name in component_fields[2:]}
        require(all(math.isfinite(v) for v in values.values()), "reference non-finite")
        ref_comp[key] = values
        previous_key = key
    expected_keys = {(i, pid) for i in range(NSTEPS + 1) for pid in EXPECTED_IDS}
    require(set(ref_traj) == expected_keys and set(ref_comp) == expected_keys,
            "reference exact key set")

    normalized: dict[tuple[int, int], dict[str, float]] = {}
    for pid in EXPECTED_IDS:
        normalized[(0, pid)] = dict(initial[pid], path_m=0.0)
    for iteration in range(1, NSTEPS + 1):
        for pid in EXPECTED_IDS:
            current = production[(iteration, pid)]
            previous = normalized[(iteration - 1, pid)]
            step_path = math.hypot(float(current["x_m"]) - previous["x_m"],
                                   float(current["y_m"]) - previous["y_m"])
            normalized[(iteration, pid)] = {
                "time_s": float(current["time_s"]),
                "x_m": float(current["x_m"]),
                "y_m": float(current["y_m"]),
                "path_m": previous["path_m"] + step_path,
            }

    norm_rows: list[dict[str, object]] = []
    traj_error_rows: list[dict[str, object]] = []
    max_position = {"error_m": -1.0}
    max_path = {"error_m": -1.0}
    for key in sorted(expected_keys):
        iteration, pid = key
        actual = normalized[key]
        reference = ref_traj[key]
        require(actual["time_s"] == reference["time_s"] == iteration * DT,
                f"trajectory time label {key}")
        for name in ("x_m", "y_m"):
            require(reference[name] == ref_comp[key][name], f"reference cross-check {key} {name}")
        position_error = math.hypot(actual["x_m"] - reference["x_m"],
                                    actual["y_m"] - reference["y_m"])
        path_error = abs(actual["path_m"] - reference["path_m"])
        tolerance = max(POS_ABS_TOL_M, POS_PATH_REL_TOL * abs(reference["path_m"]))
        passed = position_error <= tolerance and path_error <= tolerance
        if position_error > float(max_position["error_m"]):
            max_position = {"error_m": position_error, "time_index": iteration,
                            "particle_id": pid, "tolerance_m": tolerance}
        if path_error > float(max_path["error_m"]):
            max_path = {"error_m": path_error, "time_index": iteration,
                        "particle_id": pid, "tolerance_m": tolerance}
        norm_rows.append({"time_index": iteration, "particle_id": pid,
                          **{name: f"{actual[name]:.17e}" for name in traj_fields[1:]}})
        traj_error_rows.append({
            "time_index": iteration, "particle_id": pid,
            "time_s": f"{actual['time_s']:.17e}",
            "actual_x_m": f"{actual['x_m']:.17e}",
            "reference_x_m": f"{reference['x_m']:.17e}",
            "actual_y_m": f"{actual['y_m']:.17e}",
            "reference_y_m": f"{reference['y_m']:.17e}",
            "position_error_m": f"{position_error:.17e}",
            "actual_path_m": f"{actual['path_m']:.17e}",
            "reference_path_m": f"{reference['path_m']:.17e}",
            "path_error_m": f"{path_error:.17e}",
            "tolerance_m": f"{tolerance:.17e}", "result": "PASS" if passed else "FAIL",
        })
    write_csv(args.output_dir / "normalized_trajectory.csv",
              ["time_index", *traj_fields], norm_rows)
    write_csv(args.output_dir / "trajectory_errors.csv", list(traj_error_rows[0]), traj_error_rows)

    normalized_components: list[dict[str, object]] = []
    component_errors: list[dict[str, object]] = []
    max_component = {"error": -1.0}
    failed_components = 0
    compare_names = ("rhs_x_m_s", "rhs_y_m_s", *DIAG_NAMES)
    for iteration in range(1, NSTEPS + 1):
        for pid in EXPECTED_IDS:
            key = (iteration, pid)
            prod = production[key]
            ref = ref_comp[key]
            actual_values = {
                "rhs_x_m_s": float(prod["rhs_x_m_s"]),
                "rhs_y_m_s": float(prod["rhs_y_m_s"]),
                **dict(zip(DIAG_NAMES, prod["diag"])),
            }
            normalized_components.append({
                "time_index": iteration, "particle_id": pid,
                "time_s": f"{float(prod['time_s']):.17e}",
                "x_m": f"{float(prod['x_m']):.17e}",
                "y_m": f"{float(prod['y_m']):.17e}",
                **{name: f"{actual_values[name]:.17e}" for name in compare_names},
            })
            for name in compare_names:
                av, rv = actual_values[name], ref[name]
                error = abs(av - rv)
                tolerance = COMP_ABS_TOL + COMP_REL_TOL * abs(rv)
                passed = error <= tolerance
                failed_components += int(not passed)
                if error > float(max_component["error"]):
                    max_component = {"error": error, "time_index": iteration,
                                     "particle_id": pid, "component": name,
                                     "actual": av, "reference": rv,
                                     "tolerance": tolerance}
                component_errors.append({
                    "time_index": iteration, "particle_id": pid,
                    "time_s": f"{float(prod['time_s']):.17e}", "component": name,
                    "actual": f"{av:.17e}", "reference": f"{rv:.17e}",
                    "abs_error": f"{error:.17e}", "tolerance": f"{tolerance:.17e}",
                    "result": "PASS" if passed else "FAIL",
                })
    write_csv(args.output_dir / "normalized_components.csv",
              list(normalized_components[0]), normalized_components)
    write_csv(args.output_dir / "component_errors.csv", list(component_errors[0]), component_errors)

    for pid in EXPECTED_IDS:
        keys = [(i, pid) for i in range(NSTEPS + 1)]
        actual_x = [(normalized[k]["time_s"] / 3600.0, normalized[k]["x_m"]) for k in keys]
        ref_x = [(ref_traj[k]["time_s"] / 3600.0, ref_traj[k]["x_m"]) for k in keys]
        actual_y = [(normalized[k]["time_s"] / 3600.0, normalized[k]["y_m"]) for k in keys]
        ref_y = [(ref_traj[k]["time_s"] / 3600.0, ref_traj[k]["y_m"]) for k in keys]
        actual_path = [(normalized[k]["time_s"] / 3600.0, normalized[k]["path_m"]) for k in keys]
        ref_path = [(ref_traj[k]["time_s"] / 3600.0, ref_traj[k]["path_m"]) for k in keys]
        # Three panels are normalized by value range into one diagnostic canvas.
        combined = []
        colors = ("#0072B2", "#56B4E9", "#D55E00", "#E69F00", "#009E73", "#66C2A5")
        for label, values, color in zip(("x actual", "x reference", "y actual", "y reference",
                                         "path actual", "path reference"),
                                        (actual_x, ref_x, actual_y, ref_y, actual_path, ref_path), colors):
            combined.append((label, values, color))
        svg_polyline(args.output_dir / f"particle_{pid}_timeseries.svg",
                     f"P5-J01 particle {pid}: x, y and cumulative path", combined,
                     "time (hours)", "position/path (m)")
    plan_series = []
    colors = ("#0072B2", "#D55E00", "#009E73")
    for pid, color in zip(EXPECTED_IDS, colors):
        plan_series.append((f"particle {pid} actual",
                            [(normalized[(i, pid)]["x_m"], normalized[(i, pid)]["y_m"])
                             for i in range(NSTEPS + 1)], color))
        plan_series.append((f"particle {pid} reference",
                            [(ref_traj[(i, pid)]["x_m"], ref_traj[(i, pid)]["y_m"])
                             for i in range(NSTEPS + 1)], color))
    svg_polyline(args.output_dir / "trajectory_planview.svg", "P5-J01 trajectory plan view",
                 plan_series, "x (m)", "y (m)")

    trajectory_failures = sum(row["result"] == "FAIL" for row in traj_error_rows)
    nonzero = {
        str(pid): math.hypot(normalized[(NSTEPS, pid)]["x_m"] - normalized[(0, pid)]["x_m"],
                             normalized[(NSTEPS, pid)]["y_m"] - normalized[(0, pid)]["y_m"])
        for pid in EXPECTED_IDS
    }
    require(all(value > 0.0 for value in nonzero.values()), "zero net displacement")
    result_status = "PASS" if trajectory_failures == 0 and failed_components == 0 else "FAIL"
    inventory.update({
        "normalized_trajectory_rows": len(norm_rows),
        "normalized_component_rows": len(normalized_components),
        "component_comparisons": len(component_errors),
        "pickup": pickups,
    })
    (args.output_dir / "inventory_audit.json").write_text(
        json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="ascii")
    result = {
        "schema": "MITGCM-BOM-P5-J01-result-v1",
        "result": result_status,
        "trajectory": {
            "rows": len(traj_error_rows), "failures": trajectory_failures,
            "max_position": max_position, "max_path": max_path,
            "tolerance": {"absolute_m": POS_ABS_TOL_M,
                          "relative_to_reference_path": POS_PATH_REL_TOL},
        },
        "components": {
            "production_rows": len(normalized_components),
            "comparisons": len(component_errors), "failures": failed_components,
            "max": max_component,
            "tolerance": {"absolute": COMP_ABS_TOL, "relative": COMP_REL_TOL},
            "note": "t=0 component row is locked-reference context; production components are t=900..86400",
        },
        "net_displacement_m": nonzero,
        "inventory": inventory,
    }
    (args.output_dir / "result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="ascii")
    review = f"""# P5-J01 locked Julia comparison review

- Result: **{result_status}**
- Normalized trajectory: {len(norm_rows)} rows (initial input plus 96 production samples for 3 particles)
- Production component rows: {len(normalized_components)}; scalar comparisons: {len(component_errors)}
- Maximum position error: {float(max_position['error_m']):.17e} m at time index {max_position.get('time_index')} particle {max_position.get('particle_id')}
- Maximum path error: {float(max_path['error_m']):.17e} m at time index {max_path.get('time_index')} particle {max_path.get('particle_id')}
- Maximum component error: {float(max_component['error']):.17e} in {max_component.get('component')} at time index {max_component.get('time_index')} particle {max_component.get('particle_id')}
- Trajectory failures: {trajectory_failures}; component failures: {failed_components}
- Pickup checkpoints: iteration 48 and 96 independently decoded with exact schema, IDs and tile inventory.

The production trajectory begins at iteration 1. The normalized time-zero row is independently decoded from `bom_particles.data`; it is not synthesized from the model output. Julia component values at time zero are retained only as locked-reference context and are not reported as production component samples.
"""
    (args.output_dir / "review.md").write_text(review, encoding="ascii")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("input_bundle", type=Path)
    parser.add_argument("reference_trajectory", type=Path)
    parser.add_argument("reference_components", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    try:
        result = compare(args)
    except Exception as error:  # emit a machine-readable failure when possible
        if args.output_dir.exists():
            (args.output_dir / "result.json").write_text(
                json.dumps({"schema": "MITGCM-BOM-P5-J01-result-v1",
                            "result": "FAIL", "error": str(error)}, indent=2) + "\n",
                encoding="ascii")
        print(f"P5-J01 COMPARISON FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
    if result["result"] != "PASS":
        print("P5-J01 COMPARISON FAIL: numerical tolerance", file=sys.stderr)
        raise SystemExit(1)
    print("P5-J01 LOCKED JULIA COMPARISON PASS "
          f"trajectory={result['trajectory']['rows']} "
          f"components={result['components']['comparisons']}")


if __name__ == "__main__":
    main()
