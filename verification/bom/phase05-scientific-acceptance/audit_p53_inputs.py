#!/usr/bin/env python3
"""Independent byte-level audit for a P5.3 PAPER2024 input bundle."""

from __future__ import annotations

import argparse
import json
import math
import re
import struct
from pathlib import Path

import audit_p51_inputs as base


SCHEMA = "MITGCM-BOM-P5-PAPER2024-INPUT-v2"
END_TIME_S = 86_400
OUTPUT_PERIOD_S = 900
ALLOWED_DT_S = (900, 450, 225)
CASES = ("p01", "p02")


def fail(message: str) -> None:
    raise SystemExit(f"P5.3 INPUT AUDIT FAIL: {message}")


def require_tokens(path: Path, tokens: tuple[str, ...]) -> None:
    text = path.read_text(encoding="ascii")
    for token in tokens:
        if token not in text:
            fail(f"{path.name} lacks token {token!r}")


def audit_checksums(bundle: Path, manifest: dict[str, object]) -> int:
    files = manifest.get("files")
    if not isinstance(files, dict):
        fail("manifest files member is not an object")
    expected_names = set(files) | {"input-manifest.json", "SHA256SUMS"}
    actual_names = {path.name for path in bundle.iterdir() if path.is_file()}
    if actual_names != expected_names:
        fail(
            f"file inventory differs missing={sorted(expected_names-actual_names)} "
            f"extra={sorted(actual_names-expected_names)}"
        )
    for name, entry in files.items():
        if not isinstance(entry, dict):
            fail(f"bad manifest entry: {name}")
        path = bundle / name
        if path.stat().st_size != entry.get("bytes") or base.sha256(path) != entry.get("sha256"):
            fail(f"manifest size/hash mismatch: {name}")
    lines = (bundle / "SHA256SUMS").read_text(encoding="ascii").splitlines()
    parsed: dict[str, str] = {}
    for line in lines:
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
        if match is None or match.group(2) in parsed:
            fail(f"invalid/duplicate checksum line: {line!r}")
        parsed[match.group(2)] = match.group(1)
    if set(parsed) != expected_names - {"SHA256SUMS"}:
        fail("checksum inventory differs")
    for name, digest in parsed.items():
        if base.sha256(bundle / name) != digest:
            fail(f"checksum mismatch: {name}")
    return len(actual_names)


def audit_manifest(
    manifest: dict[str, object],
    case_id: str,
    dt_s: int,
    fields: dict[tuple[int, int], tuple[float, float, float, float]],
    particles: list[tuple[int, float, float]],
) -> None:
    if manifest.get("schema") != SCHEMA or manifest.get("case") != f"P5-{case_id.upper()}":
        fail("manifest schema/case differs")
    if manifest.get("equation_mode") != "PAPER2024":
        fail("manifest equation mode differs")
    if manifest.get("dimensions") != {"nx": 8, "ny": 6, "nr": 2}:
        fail("manifest dimensions differ")
    if manifest.get("grid") != {
        "coordinate_system": "cartesian_m", "dx_m": 50_000.0,
        "dy_m": 50_000.0, "periodic_x": False, "periodic_y": False,
        "all_wet": True,
    }:
        fail("manifest grid differs")
    endpoint_times = tuple(range(0, END_TIME_S + dt_s, dt_s))
    forcing_times = (*endpoint_times, END_TIME_S + dt_s)
    common_times = list(range(0, END_TIME_S + OUTPUT_PERIOD_S, OUTPUT_PERIOD_S))
    expected_time = {
        "start_s": 0, "end_s": END_TIME_S, "dt_s": dt_s,
        "n_steps": END_TIME_S // dt_s,
        "endpoint_records": len(endpoint_times),
        "forcing_records": len(forcing_times),
        "read_ahead_s": forcing_times[-1],
        "output_period_s": OUTPUT_PERIOD_S,
        "common_times_s": common_times,
    }
    if manifest.get("time") != expected_time:
        fail("manifest time contract differs")
    if manifest.get("precision") != {"binary": "IEEE754-binary64", "endianness": "big"}:
        fail("manifest precision differs")
    if manifest.get("c_grid") != {
        "u": "x-face/y-center/i-fastest/k-outer",
        "v": "x-center/y-face/i-fastest/k-outer",
        "scalar": "x-center/y-center/i-fastest/record-outer",
    }:
        fail("manifest native C-grid contract differs")
    manifest_fields = manifest.get("affine_fields")
    if not isinstance(manifest_fields, dict):
        fail("manifest affine fields missing")
    for (source, component), coeff in fields.items():
        if manifest_fields.get(f"source{source}_component{component}") != {
            "c0": coeff[0], "cx": coeff[1], "cy": coeff[2], "ct": coeff[3]
        }:
            fail(f"manifest affine coefficient differs: {source}/{component}")
    expected_particles = [
        {"id": particle_id, "x_m": x, "y_m": y, "status": 1}
        for particle_id, x, y in particles
    ]
    if manifest.get("particles") != expected_particles:
        fail("manifest particle inventory differs")


def audit_binary_fields(
    bundle: Path,
    dt_s: int,
    fields: dict[tuple[int, int], tuple[float, float, float, float]],
) -> int:
    base.compare_bytes(bundle / "bathy.bin", base.pack([-100.0] * 48), "bathymetry")
    base.compare_bytes(bundle / "uvel_init.bin", base.vector_3d(fields[(1, 1)], "u", 0.0), "initial U")
    base.compare_bytes(bundle / "vvel_init.bin", base.vector_3d(fields[(1, 2)], "v", 0.0), "initial V")
    forcing_times = (*range(0, END_TIME_S + dt_s, dt_s), END_TIME_S + dt_s)
    stokes_u: list[float] = []
    stokes_v: list[float] = []
    wind_u: list[float] = []
    wind_v: list[float] = []
    for record, time_s in enumerate(forcing_times):
        suffix = f"{record:010d}"
        base.compare_bytes(
            bundle / f"offline_u.{suffix}", base.vector_3d(fields[(1, 1)], "u", time_s),
            f"offline U record {record}",
        )
        base.compare_bytes(
            bundle / f"offline_v.{suffix}", base.vector_3d(fields[(1, 2)], "v", time_s),
            f"offline V record {record}",
        )
        base.compare_bytes(
            bundle / f"offline_theta.{suffix}", base.temperature_3d(time_s),
            f"offline theta record {record}",
        )
        stokes_u.extend(base.scalar_2d(fields[(2, 1)], time_s))
        stokes_v.extend(base.scalar_2d(fields[(2, 2)], time_s))
        wind_u.extend(base.scalar_2d(fields[(3, 1)], time_s))
        wind_v.extend(base.scalar_2d(fields[(3, 2)], time_s))
    base.compare_bytes(bundle / "ustokes.bin", base.pack(stokes_u), "Stokes U")
    base.compare_bytes(bundle / "vstokes.bin", base.pack(stokes_v), "Stokes V")
    base.compare_bytes(bundle / "uwind.bin", base.pack(wind_u), "wind U")
    base.compare_bytes(bundle / "vwind.bin", base.pack(wind_v), "wind V")
    little = struct.unpack("<d", (bundle / "bathy.bin").read_bytes()[:8])[0]
    if math.isclose(little, -100.0, rel_tol=0.0, abs_tol=0.0):
        fail("bathymetry unexpectedly decodes as little-endian")
    return 3 * len(forcing_times) + 7


def audit_configs(bundle: Path, case_id: str, dt_s: int) -> None:
    half = dt_s / 2
    require_tokens(
        bundle / "data",
        (
            "endTime=86400.", f"deltaTmom={dt_s}.", f"deltaTtracer={dt_s}.",
            f"deltaTClock={dt_s}.", "pChkptFreq=43200.",
            "usingCartesianGrid=.TRUE.", "delR=50.,50.",
            "uVelInitFile='uvel_init.bin'", "vVelInitFile='vvel_init.bin'",
            f"f0={base.F0_S_INV:.17e}",
            f"the_run_name='P5-{case_id.upper()}-PAPER2024-DT{dt_s}'",
        ),
    )
    require_tokens(bundle / "data.pkg", ("useOffLine=.TRUE.", "useEXF=.TRUE.", "useBOM=.TRUE."))
    require_tokens(
        bundle / "data.off",
        (
            "UvelFile='offline_u'", "VvelFile='offline_v'",
            f"deltaToffline={dt_s}.", f"offlineTimeOffset={half:.1f}",
            f"offlineForcingPeriod={dt_s}.", "offlineLoadPrec=64",
        ),
    )
    require_tokens(
        bundle / "data.exf",
        (
            "useAtmWind=.TRUE.", "exf_iprec=64", "uwindfile='uwind.bin'",
            "vwindfile='vwind.bin'", f"uwindperiod={dt_s}.",
            f"vwindperiod={dt_s}.",
        ),
    )
    require_tokens(
        bundle / "data.bom",
        (
            "bomEquationMode='PAPER2024'", "bomIntegrator='RK4'",
            f"bomDeltaTTarget={dt_s}.", "bomOutputFreq=900.",
            "bomPickupFreq=0.", "bomMaxParticles=3",
            "bomCurrentPolicy='EULERIAN'", "bomWindSource='EXF'",
            "bomStokesSource='FILES'", f"bomStokesPeriod={dt_s}.",
            "bomUseBiology=.FALSE.", "bomUseLand=.FALSE.",
        ),
    )
    require_tokens(bundle / "eedata", ("nTx=1", "nTy=1"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--case", choices=CASES, required=True)
    parser.add_argument("--dt-s", type=int, choices=ALLOWED_DT_S, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    repo = args.repo_root.resolve()
    report = args.report.resolve()
    case_id = args.case
    if case_id == "p01" and args.dt_s != 900:
        fail("P5-P01 is frozen at dt=900 s")
    if not bundle.is_dir() or report.exists():
        fail("bundle missing or report already exists")

    reference = repo / "verification/bom/reference/phase02"
    field_path = (
        reference / "input_fields_v1.csv"
        if case_id == "p01"
        else repo / "verification/bom/phase05-scientific-acceptance/p53_p02_affine_fields.csv"
    )
    particle_path = reference / "input_particles_v1.csv"
    parameter_path = reference / "input_parameters_v1.toml"
    fields = base.read_reference_fields(field_path)
    particles = base.read_reference_particles(particle_path)
    manifest = json.loads((bundle / "input-manifest.json").read_text(encoding="ascii"))
    expected_locks = {
        path.name: base.sha256(path) for path in (field_path, particle_path, parameter_path)
    }
    if manifest.get("reference_locks") != expected_locks:
        fail("reference locks differ")

    audit_manifest(manifest, case_id, args.dt_s, fields, particles)
    file_count = audit_checksums(bundle, manifest)
    binary_checks = audit_binary_fields(bundle, args.dt_s, fields)
    base.audit_particles(bundle, particles)
    audit_configs(bundle, case_id, args.dt_s)
    forcing_records = END_TIME_S // args.dt_s + 2
    result = {
        "schema": "MITGCM-BOM-P5.3-INPUT-AUDIT-v1",
        "result": "PASS", "case": case_id, "dt_s": args.dt_s,
        "steps": END_TIME_S // args.dt_s,
        "forcing_records": forcing_records,
        "common_output_records": 97,
        "file_count": file_count,
        "binary_field_checks": binary_checks,
        "particles": len(particles),
        "manifest_sha256": base.sha256(bundle / "input-manifest.json"),
        "checksums_sha256": base.sha256(bundle / "SHA256SUMS"),
    }
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print(
        f"P5.3 INPUT AUDIT PASS case={case_id} dt={args.dt_s} files={file_count} "
        f"binary_checks={binary_checks} forcing_records={forcing_records}"
    )


if __name__ == "__main__":
    main()
