#!/usr/bin/env python3
"""Generate the self-contained MITGCM-BOM controlled tutorial input bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path
from typing import Iterable, Sequence


SCHEMA = "MITGCM-BOM-TUTORIAL-I01-v1"
NX, NY, NR = 8, 6, 2
DX_M = 50_000.0
DY_M = 50_000.0
DT_S = 900
N_STEPS = 24
END_TIME_S = DT_S * N_STEPS
FORCING_TIMES_S = tuple(range(0, END_TIME_S + 2 * DT_S, DT_S))
PARTICLE_FIELDS = 8
BOM_ALIVE = 1

FIELD_COEFFICIENTS = {
    "current_u": {"c0": 1.2e-1, "cx": 1.1e-7, "cy": -7.0e-8, "ct": 2.0e-7},
    "current_v": {"c0": -5.0e-2, "cx": 4.0e-8, "cy": 9.0e-8, "ct": -1.2e-7},
    "stokes_u": {"c0": 1.5e-2, "cx": -3.0e-8, "cy": 2.0e-8, "ct": 4.0e-8},
    "stokes_v": {"c0": 8.0e-3, "cx": 5.0e-8, "cy": -4.0e-8, "ct": 3.0e-8},
    "wind_u": {"c0": 3.2, "cx": 1.4e-6, "cy": 2.0e-7, "ct": -1.0e-6},
    "wind_v": {"c0": -1.1, "cx": -3.0e-7, "cy": 1.1e-6, "ct": 8.0e-7},
}

PARTICLES = (
    (1001, 80_000.0, 60_000.0),
    (1002, 200_000.0, 150_000.0),
    (1003, 320_000.0, 240_000.0),
)

STATIC_TEMPLATES = ("data", "data.pkg", "data.off", "data.exf", "eedata")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="ascii", newline="\n")


def write_be64(path: Path, values: Iterable[float]) -> None:
    sequence = tuple(values)
    path.write_bytes(struct.pack(f">{len(sequence)}d", *sequence))


def affine(coeff: dict[str, float], x: float, y: float, time_s: float) -> float:
    return coeff["c0"] + coeff["cx"] * x + coeff["cy"] * y + coeff["ct"] * time_s


def field_3d(coeff: dict[str, float], component: str, time_s: float) -> list[float]:
    values: list[float] = []
    for _k in range(NR):
        for j in range(NY):
            for i in range(NX):
                if component == "u":
                    x = i * DX_M
                    y = (j + 0.5) * DY_M
                elif component == "v":
                    x = (i + 0.5) * DX_M
                    y = j * DY_M
                else:
                    raise ValueError(f"unknown C-grid component: {component}")
                values.append(affine(coeff, x, y, time_s))
    return values


def scalar_2d(coeff: dict[str, float], time_s: float) -> list[float]:
    return [
        affine(coeff, (i + 0.5) * DX_M, (j + 0.5) * DY_M, time_s)
        for j in range(NY)
        for i in range(NX)
    ]


def temperature_3d(time_s: float) -> list[float]:
    values: list[float] = []
    for k in range(NR):
        for j in range(NY):
            for i in range(NX):
                x = (i + 0.5) * DX_M
                y = (j + 0.5) * DY_M
                values.append(20.0 + 2.0e-6 * x - 1.0e-6 * y + 1.0e-7 * time_s - 0.5 * k)
    return values


def split_id(particle_id: int) -> tuple[float, float]:
    if particle_id <= 0 or particle_id >= 2**63:
        raise ValueError(f"particle ID outside supported range: {particle_id}")
    return float(particle_id >> 32), float(particle_id & 0xFFFFFFFF)


def write_particle_mds(output: Path) -> None:
    records: list[Sequence[float]] = [
        (1.0, float(PARTICLE_FIELDS), float(len(PARTICLES)), 1.0, 1.0, 64.0, 0.0, 0.0)
    ]
    for particle_id, x, y in PARTICLES:
        id_hi, id_lo = split_id(particle_id)
        records.append((id_hi, id_lo, x, y, 0.0, float(BOM_ALIVE), 0.0, 0.0))
    write_be64(
        output / "bom_particles.data",
        (value for record in records for value in record),
    )
    write_text(
        output / "bom_particles.meta",
        """ nDims = [   3 ];
 dimList = [
     1,    1,    1,
     1,    1,    1,
     8,    1,    8
 ];
 dataprec = [ 'float64' ];
 nrecords = [     4 ];
 timeStepNumber = [          0 ];
 nFlds = [    1 ];
 fldList = {
 'BOMV0001'
 };
""",
    )


def copy_configuration(source: Path, output: Path, equation: str) -> None:
    for name in STATIC_TEMPLATES:
        shutil.copyfile(source / name, output / name)
    selected = source / f"data.bom.{equation.lower()}"
    shutil.copyfile(selected, output / "data.bom")
    shutil.copyfile(source / "data.bom.julia", output / "data.bom.julia")
    shutil.copyfile(source / "data.bom.paper2024", output / "data.bom.paper2024")


def generate(output: Path, equation: str) -> None:
    source = Path(__file__).resolve().parent
    if output.exists():
        raise FileExistsError(f"refusing existing output directory: {output}")
    output.mkdir(parents=True)

    copy_configuration(source, output, equation)
    write_be64(output / "bathy.bin", [-100.0] * (NX * NY))
    write_be64(
        output / "uvel_init.bin",
        field_3d(FIELD_COEFFICIENTS["current_u"], "u", 0.0),
    )
    write_be64(
        output / "vvel_init.bin",
        field_3d(FIELD_COEFFICIENTS["current_v"], "v", 0.0),
    )
    write_particle_mds(output)

    ustokes: list[float] = []
    vstokes: list[float] = []
    uwind: list[float] = []
    vwind: list[float] = []
    for record, time_s in enumerate(FORCING_TIMES_S):
        suffix = f"{record:010d}"
        write_be64(
            output / f"offline_u.{suffix}",
            field_3d(FIELD_COEFFICIENTS["current_u"], "u", time_s),
        )
        write_be64(
            output / f"offline_v.{suffix}",
            field_3d(FIELD_COEFFICIENTS["current_v"], "v", time_s),
        )
        write_be64(output / f"offline_theta.{suffix}", temperature_3d(time_s))
        ustokes.extend(scalar_2d(FIELD_COEFFICIENTS["stokes_u"], time_s))
        vstokes.extend(scalar_2d(FIELD_COEFFICIENTS["stokes_v"], time_s))
        uwind.extend(scalar_2d(FIELD_COEFFICIENTS["wind_u"], time_s))
        vwind.extend(scalar_2d(FIELD_COEFFICIENTS["wind_v"], time_s))

    write_be64(output / "ustokes.bin", ustokes)
    write_be64(output / "vstokes.bin", vstokes)
    write_be64(output / "uwind.bin", uwind)
    write_be64(output / "vwind.bin", vwind)

    generated = sorted(output.iterdir(), key=lambda item: item.name)
    manifest = {
        "schema": SCHEMA,
        "equation": equation,
        "dimensions": {"nx": NX, "ny": NY, "nr": NR},
        "grid": {
            "coordinate_system": "cartesian_m",
            "dx_m": DX_M,
            "dy_m": DY_M,
            "bathy_m": -100.0,
            "domain_m": [0.0, NX * DX_M, 0.0, NY * DY_M],
        },
        "time": {
            "dt_s": DT_S,
            "steps": N_STEPS,
            "end_s": END_TIME_S,
            "forcing_records": len(FORCING_TIMES_S),
            "forcing_timestamps_s": list(FORCING_TIMES_S),
        },
        "precision": {"binary": "IEEE754-binary64", "endianness": "big"},
        "c_grid_order": {
            "u": "x-face/y-center/i-fastest/k-outer",
            "v": "x-center/y-face/i-fastest/k-outer",
            "scalar": "x-center/y-center/i-fastest/record-outer",
        },
        "affine_fields": FIELD_COEFFICIENTS,
        "particles": [
            {"id": particle_id, "x_m": x, "y_m": y, "status": BOM_ALIVE}
            for particle_id, x, y in PARTICLES
        ],
        "files": {
            path.name: {"bytes": path.stat().st_size, "sha256": sha256(path)}
            for path in generated
            if path.is_file()
        },
    }
    manifest_path = output / "input-manifest.json"
    write_text(manifest_path, json.dumps(manifest, indent=2, sort_keys=True) + "\n")

    checksum_paths = sorted(
        [path for path in output.iterdir() if path.is_file() and path.name != "SHA256SUMS"],
        key=lambda item: item.name,
    )
    write_text(
        output / "SHA256SUMS",
        "".join(f"{sha256(path)}  {path.name}\n" for path in checksum_paths),
    )
    print(
        "MITGCM-BOM TUTORIAL INPUT PASS "
        f"equation={equation} files={len(checksum_paths) + 1} "
        f"forcing_records={len(FORCING_TIMES_S)} output={output}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="new directory for the complete input bundle")
    parser.add_argument(
        "--equation",
        choices=("JULIA", "PAPER2024"),
        default="JULIA",
        help="slow-manifold equation convention (default: JULIA)",
    )
    args = parser.parse_args()
    generate(args.output.resolve(), args.equation)


if __name__ == "__main__":
    main()
