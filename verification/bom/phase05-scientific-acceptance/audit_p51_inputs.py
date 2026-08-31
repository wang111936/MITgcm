#!/usr/bin/env python3
"""Independent decoder/oracle for the P5-I01 production-input bundle."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import struct
from pathlib import Path
from typing import Iterable


SCHEMA = "MITGCM-BOM-P5-I01-v1"
NX, NY, NR = 8, 6, 2
DX_M = DY_M = 50_000.0
DT_S = 900
ENDPOINT_TIMES_S = tuple(range(0, 86_400 + DT_S, DT_S))
FORCING_TIMES_S = (*ENDPOINT_TIMES_S, 87_300)
F0_S_INV = 2.18213 / 86_400.0
TEMP = (20.0, 2.0e-6, -1.0e-6, 1.0e-7, -0.5)
NUTRIENT = (1.5, 1.0e-6, -5.0e-7, 2.0e-7)


def fail(message: str) -> None:
    raise SystemExit(f"P5-I01 INPUT AUDIT FAIL: {message}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def pack(values: Iterable[float]) -> bytes:
    sequence = tuple(values)
    return struct.pack(f">{len(sequence)}d", *sequence)


def read_reference_fields(path: Path) -> dict[tuple[int, int], tuple[float, float, float, float]]:
    result: dict[tuple[int, int], tuple[float, float, float, float]] = {}
    with path.open(newline="", encoding="ascii") as stream:
        for row in csv.DictReader(stream):
            result[(int(row["source_code"]), int(row["component_code"]))] = (
                float(row["c0_m_s"]),
                float(row["cx_s_inv"]),
                float(row["cy_s_inv"]),
                float(row["ct_m_s2"]),
            )
    expected = {(source, component) for source in range(1, 4) for component in range(1, 3)}
    if set(result) != expected:
        fail("locked affine reference key set differs")
    return result


def read_reference_particles(path: Path) -> list[tuple[int, float, float]]:
    with path.open(newline="", encoding="ascii") as stream:
        result = [
            (int(row["particle_id"]), float(row["x_m"]), float(row["y_m"]))
            for row in csv.DictReader(stream)
        ]
    if len(result) != 3:
        fail("locked particle reference is not three rows")
    return result


def affine(coeff: tuple[float, float, float, float], x: float, y: float, t: float) -> float:
    c0, cx, cy, ct = coeff
    return c0 + cx * x + cy * y + ct * t


def vector_3d(
    coeff: tuple[float, float, float, float], component: str, t: float
) -> bytes:
    values: list[float] = []
    for _k in range(NR):
        for j in range(NY):
            for i in range(NX):
                if component == "u":
                    x, y = i * DX_M, (j + 0.5) * DY_M
                elif component == "v":
                    x, y = (i + 0.5) * DX_M, j * DY_M
                else:
                    fail(f"unknown vector component {component!r}")
                values.append(affine(coeff, x, y, t))
    return pack(values)


def scalar_2d(coeff: tuple[float, float, float, float], t: float) -> list[float]:
    return [
        affine(coeff, (i + 0.5) * DX_M, (j + 0.5) * DY_M, t)
        for j in range(NY)
        for i in range(NX)
    ]


def temperature_3d(t: float) -> bytes:
    c0, cx, cy, ct, cz = TEMP
    values: list[float] = []
    for k in range(NR):
        for j in range(NY):
            for i in range(NX):
                x = (i + 0.5) * DX_M
                y = (j + 0.5) * DY_M
                values.append(c0 + cx * x + cy * y + ct * t + cz * k)
    return pack(values)


def nutrient_2d(t: float) -> list[float]:
    return scalar_2d(NUTRIENT, t)


def compare_bytes(path: Path, expected: bytes, label: str) -> None:
    actual = path.read_bytes()
    if actual != expected:
        fail(f"{label} byte mismatch: expected={len(expected)} actual={len(actual)}")


def require_tokens(path: Path, tokens: Iterable[str]) -> None:
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
            fail(f"bad manifest entry for {name}")
        path = bundle / name
        if path.stat().st_size != entry.get("bytes"):
            fail(f"size mismatch for {name}")
        if sha256(path) != entry.get("sha256"):
            fail(f"SHA-256 mismatch for {name}")
    checksum_lines = (bundle / "SHA256SUMS").read_text(encoding="ascii").splitlines()
    parsed: dict[str, str] = {}
    for line in checksum_lines:
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
        if match is None:
            fail(f"invalid SHA256SUMS line: {line!r}")
        parsed[match.group(2)] = match.group(1)
    expected_checksum_names = expected_names - {"SHA256SUMS"}
    if set(parsed) != expected_checksum_names:
        fail("SHA256SUMS inventory differs")
    for name, digest in parsed.items():
        if sha256(bundle / name) != digest:
            fail(f"SHA256SUMS digest mismatch for {name}")
    return len(actual_names)


def audit_manifest(
    manifest: dict[str, object], fields: dict[tuple[int, int], tuple[float, float, float, float]], particles: list[tuple[int, float, float]]
) -> None:
    if manifest.get("schema") != SCHEMA:
        fail("manifest schema differs")
    if manifest.get("dimensions") != {"nx": NX, "ny": NY, "nr": NR}:
        fail("manifest dimensions differ")
    time = manifest.get("time")
    if not isinstance(time, dict):
        fail("manifest time member is not an object")
    if time.get("records") != len(ENDPOINT_TIMES_S):
        fail("manifest endpoint record count differs")
    if time.get("timestamps_s") != list(ENDPOINT_TIMES_S):
        fail("manifest endpoint timestamps differ")
    if time.get("forcing_records") != len(FORCING_TIMES_S):
        fail("manifest forcing record count differs")
    if time.get("forcing_timestamps_s") != list(FORCING_TIMES_S):
        fail("manifest forcing timestamps differ")
    if time.get("read_ahead_s") != FORCING_TIMES_S[-1]:
        fail("manifest read-ahead timestamp differs")
    precision = manifest.get("precision")
    if precision != {"binary": "IEEE754-binary64", "endianness": "big"}:
        fail("manifest precision/endianness differs")
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
        entry = manifest_fields.get(f"source{source}_component{component}")
        if entry != {"c0": coeff[0], "cx": coeff[1], "cy": coeff[2], "ct": coeff[3]}:
            fail(f"manifest coefficient mismatch source={source} component={component}")
    expected_particles = [
        {"id": particle_id, "x_m": x, "y_m": y, "status": 1}
        for particle_id, x, y in particles
    ]
    if manifest.get("particles") != expected_particles:
        fail("manifest particle list differs")


def audit_binary_fields(
    bundle: Path,
    fields: dict[tuple[int, int], tuple[float, float, float, float]],
) -> int:
    compare_bytes(bundle / "bathy.bin", pack([-100.0] * (NX * NY)), "bathymetry")
    compare_bytes(bundle / "uvel_init.bin", vector_3d(fields[(1, 1)], "u", 0.0), "initial U")
    compare_bytes(bundle / "vvel_init.bin", vector_3d(fields[(1, 2)], "v", 0.0), "initial V")
    stokes_u: list[float] = []
    stokes_v: list[float] = []
    wind_u: list[float] = []
    wind_v: list[float] = []
    nutrient: list[float] = []
    for record, t in enumerate(FORCING_TIMES_S):
        suffix = f"{record:010d}"
        compare_bytes(bundle / f"offline_u.{suffix}", vector_3d(fields[(1, 1)], "u", t), f"offline U {record}")
        compare_bytes(bundle / f"offline_v.{suffix}", vector_3d(fields[(1, 2)], "v", t), f"offline V {record}")
        compare_bytes(bundle / f"offline_theta.{suffix}", temperature_3d(t), f"offline theta {record}")
        stokes_u.extend(scalar_2d(fields[(2, 1)], t))
        stokes_v.extend(scalar_2d(fields[(2, 2)], t))
        wind_u.extend(scalar_2d(fields[(3, 1)], t))
        wind_v.extend(scalar_2d(fields[(3, 2)], t))
        nutrient.extend(nutrient_2d(t))
    compare_bytes(bundle / "ustokes.bin", pack(stokes_u), "Stokes U")
    compare_bytes(bundle / "vstokes.bin", pack(stokes_v), "Stokes V")
    compare_bytes(bundle / "uwind.bin", pack(wind_u), "wind U")
    compare_bytes(bundle / "vwind.bin", pack(wind_v), "wind V")
    compare_bytes(bundle / "nutrient.bin", pack(nutrient), "nutrient")
    little_endian_first = struct.unpack("<d", (bundle / "bathy.bin").read_bytes()[:8])[0]
    if math.isclose(little_endian_first, -100.0, rel_tol=0.0, abs_tol=0.0):
        fail("bathymetry unexpectedly decodes as little-endian")
    return 3 * len(FORCING_TIMES_S) + 8


def audit_particles(bundle: Path, particles: list[tuple[int, float, float]]) -> None:
    expected = [1.0, 8.0, 3.0, 1.0, 1.0, 64.0, 0.0, 0.0]
    for particle_id, x, y in particles:
        expected.extend(
            [
                float(particle_id >> 32),
                float(particle_id & 0xFFFFFFFF),
                x,
                y,
                0.0,
                1.0,
                0.0,
                0.0,
            ]
        )
    compare_bytes(bundle / "bom_particles.data", pack(expected), "particle MDS")
    require_tokens(
        bundle / "bom_particles.meta",
        ("nDims = [   3 ]", "dataprec = [ 'float64' ]", "nrecords = [     4 ]", "'BOMV0001'"),
    )


def audit_configs(bundle: Path) -> None:
    require_tokens(
        bundle / "data",
        (
            "endTime=86400.",
            "deltaTClock=900.",
            "usingCartesianGrid=.TRUE.",
            "delR=50.,50.",
            "viscAr=1.E-3",
            "diffKrT=0.",
            "diffKrS=0.",
            "bathyFile='bathy.bin'",
            "uVelInitFile='uvel_init.bin'",
            f"f0={F0_S_INV:.17e}",
        ),
    )
    data_text = (bundle / "data").read_text(encoding="ascii")
    for forbidden in (
        "viscAz=",
        "viscAp=",
        "diffKzT=",
        "diffKpT=",
        "diffKzS=",
        "diffKpS=",
    ):
        if forbidden in data_text:
            fail(f"data mixes delR with coordinate-specific token {forbidden!r}")
    require_tokens(bundle / "data.smoke", ("endTime=1800.", "pChkptFreq=1800."))
    require_tokens(
        bundle / "data.pkg",
        ("useOffLine=.TRUE.", "useEXF=.TRUE.", "useBOM=.TRUE."),
    )
    require_tokens(
        bundle / "data.pkg.bomoff",
        ("useOffLine=.FALSE.", "useEXF=.FALSE.", "useBOM=.FALSE."),
    )
    require_tokens(
        bundle / "data.off",
        (
            "UvelFile='offline_u'",
            "VvelFile='offline_v'",
            "ThetFile='offline_theta'",
            "deltaToffline=900.",
            "offlineTimeOffset=450.",
            "offlineForcingPeriod=900.",
            "offlineLoadPrec=64",
        ),
    )
    require_tokens(
        bundle / "data.exf",
        (
            "useAtmWind=.TRUE.",
            "exf_iprec=64",
            "uwindfile='uwind.bin'",
            "vwindfile='vwind.bin'",
            "uwindperiod=900.",
            "vwindperiod=900.",
        ),
    )
    common_bom = (
        "bomIntegrator='RK4'",
        "bomPickupFreq=0.",
        "bomMaxParticles=3",
        "bomInitialFile='bom_particles'",
        "bomCurrentPolicy='EULERIAN'",
        "bomWindSource='EXF'",
        "bomStokesSource='FILES'",
        "bomStokesPeriod=900.",
        "bomStokesFilePrec=64",
    )
    require_tokens(bundle / "data.bom", ("bomEquationMode='JULIA'", *common_bom))
    require_tokens(
        bundle / "data.bom.paper2024",
        ("bomEquationMode='PAPER2024'", *common_bom),
    )
    require_tokens(
        bundle / "data.bom.phase4",
        (
            "bomEquationMode='PAPER2024'",
            "bomUseBiology=.TRUE.",
            "bomUseLand=.TRUE.",
            "bomTempSource='THETA'",
            "bomNSource='FILES'",
            "bomNFile='nutrient.bin'",
            "bomNPeriod=900.",
            *common_bom,
        ),
    )
    require_tokens(bundle / "eedata", ("nTx=1", "nTy=1"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    repo_root = (
        args.repo_root.resolve()
        if args.repo_root is not None
        else Path(__file__).resolve().parents[3]
    )
    if not bundle.is_dir():
        fail(f"bundle is not a directory: {bundle}")
    if args.report.exists():
        fail(f"report already exists: {args.report}")

    reference_root = repo_root / "verification/bom/reference/phase02"
    fields_path = reference_root / "input_fields_v1.csv"
    particles_path = reference_root / "input_particles_v1.csv"
    parameters_path = reference_root / "input_parameters_v1.toml"
    fields = read_reference_fields(fields_path)
    particles = read_reference_particles(particles_path)
    manifest = json.loads((bundle / "input-manifest.json").read_text(encoding="ascii"))
    locks = manifest.get("reference_locks")
    expected_locks = {
        path.name: sha256(path) for path in (fields_path, particles_path, parameters_path)
    }
    if locks != expected_locks:
        fail("reference locks differ from the repository authority")

    audit_manifest(manifest, fields, particles)
    file_count = audit_checksums(bundle, manifest)
    binary_count = audit_binary_fields(bundle, fields)
    audit_particles(bundle, particles)
    audit_configs(bundle)

    report = {
        "schema": SCHEMA,
        "result": "PASS",
        "bundle": str(bundle),
        "file_count": file_count,
        "binary_field_checks": binary_count,
        "time_records": len(ENDPOINT_TIMES_S),
        "forcing_records": len(FORCING_TIMES_S),
        "particles": len(particles),
        "reference_locks": expected_locks,
        "manifest_sha256": sha256(bundle / "input-manifest.json"),
        "checksums_sha256": sha256(bundle / "SHA256SUMS"),
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print(
        f"P5-I01 INPUT AUDIT PASS files={file_count} "
        f"binary_checks={binary_count} endpoints={len(ENDPOINT_TIMES_S)} "
        f"forcing_records={len(FORCING_TIMES_S)}"
    )


if __name__ == "__main__":
    main()
