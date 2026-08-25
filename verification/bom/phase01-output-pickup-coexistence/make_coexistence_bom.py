#!/usr/bin/env python3
"""Create deterministic nonzero BOM input for the exp4 FLT matrix."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


IDS = (1, 4_294_967_301, 9_007_199_254_740_993)


def split_id(particle_id: int) -> tuple[float, float]:
    return float(particle_id >> 32), float(particle_id & 0xFFFFFFFF)


def record(
    particle_id: int,
    x: float,
    y: float,
    release_time: float,
    status: int,
) -> tuple[float, ...]:
    high, low = split_id(particle_id)
    return high, low, x, y, release_time, float(status), 0.0, 0.0


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    particles = (
        record(IDS[0], 25_000.0, 25_000.0, 0.0, 1),
        record(IDS[1], 100_000.0, 50_000.0, 0.0, 1),
        record(IDS[2], 200_000.0, 100_000.0, 216_000.0, 6),
    )
    header = (1.0, 8.0, 3.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    prefix = args.output_dir / "bom_coexistence"
    with prefix.with_suffix(".data").open("wb") as stream:
        for item in (header, *particles):
            stream.write(struct.pack(">8d", *item))
    prefix.with_suffix(".meta").write_text(
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
        encoding="ascii",
    )
    print("P1.5 COEXISTENCE BOM INPUT PASS: 3 exact IDs")


if __name__ == "__main__":
    main()
