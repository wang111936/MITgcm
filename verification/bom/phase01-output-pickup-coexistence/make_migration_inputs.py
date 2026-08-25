#!/usr/bin/env python3
"""Create deterministic production inputs for P1.5 migration I/O tests."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


BOM_ALIVE = 1
BOM_WAITING = 6
IDS = (1, 4_294_967_301, 9_007_199_254_740_993)


def split_id(particle_id: int) -> tuple[float, float]:
    return float(particle_id >> 32), float(particle_id & 0xFFFFFFFF)


def particle(
    particle_id: int,
    x: float,
    release_time: float,
    status: int,
) -> tuple[float, ...]:
    id_high, id_low = split_id(particle_id)
    return (
        id_high,
        id_low,
        x,
        -1000.0,
        release_time,
        float(status),
        0.0,
        0.0,
    )


def write_meta(path: Path, records: int) -> None:
    path.write_text(
        f""" nDims = [   3 ];
 dimList = [
     1,    1,    1,
     1,    1,    1,
     8,    1,    8
 ];
 dataprec = [ 'float64' ];
 nrecords = [ {records:5d} ];
 timeStepNumber = [          0 ];
 nFlds = [    1 ];
 fldList = {{
 'BOMV0001'
 }};
""",
        encoding="ascii",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    # MITgcm global compact fields: Nx=8, Ny=6, Nr=2, big-endian float64.
    field_size = 8 * 6 * 2
    (args.output_dir / "U.const").write_bytes(
        struct.pack(f">{field_size}d", *([3.0] * field_size))
    )
    (args.output_dir / "V.const").write_bytes(
        struct.pack(f">{field_size}d", *([0.0] * field_size))
    )

    header = (1.0, 8.0, 3.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    records = (
        particle(IDS[0], 1400.0, 0.0, BOM_ALIVE),
        particle(IDS[1], -500.0, 0.0, BOM_ALIVE),
        particle(IDS[2], 500.0, 180.0, BOM_WAITING),
    )
    data_path = args.output_dir / "bom_migration.data"
    with data_path.open("wb") as stream:
        for record in (header, *records):
            stream.write(struct.pack(">8d", *record))
    write_meta(args.output_dir / "bom_migration.meta", len(records) + 1)

    print("P1.5 MIGRATION INPUT PASS: U=3 m/s; 3 particles; release=180 s")


if __name__ == "__main__":
    main()
