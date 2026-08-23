#!/usr/bin/env python3
"""Generate deterministic Phase-1.1 BOM initial-vector test inputs."""

from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path


BOM_ALIVE = 1
BOM_WAITING = 6
FIELDS = 8


def split_id(particle_id: int) -> tuple[float, float]:
    return float(particle_id >> 32), float(particle_id & 0xFFFFFFFF)


def particle_record(
    particle_id: int,
    x: float,
    y: float,
    release_time: float,
    status: int,
    age: float = 0.0,
) -> tuple[float, ...]:
    id_hi, id_lo = split_id(particle_id)
    return (id_hi, id_lo, x, y, release_time, float(status), age, 0.0)


def scenario_records(name: str) -> tuple[tuple[float, ...], list[tuple[float, ...]]]:
    valid = [
        particle_record(1, 10.0, -10.0, 0.0, BOM_ALIVE),
        particle_record(4_294_967_301, 180.0, 0.0, 0.0, BOM_ALIVE),
        particle_record(9_007_199_254_740_993, 350.0, 70.0, 216_000.0, BOM_WAITING),
    ]

    if name == "valid":
        records = valid
        header = (1.0, 8.0, float(len(records)), 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "one":
        records = valid[:1]
        header = (1.0, 8.0, 1.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "two":
        records = valid[:2]
        header = (1.0, 8.0, 2.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "duplicate":
        records = [valid[0], valid[0]]
        header = (1.0, 8.0, 2.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "bad-schema":
        records = valid
        header = (2.0, 8.0, 3.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "bad-id":
        records = [(0.0, 1.5, 10.0, -10.0, 0.0, 1.0, 0.0, 0.0)]
        header = (1.0, 8.0, 1.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "bad-status":
        records = [particle_record(7, 10.0, -10.0, 0.0, 2)]
        header = (1.0, 8.0, 1.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "nan-coordinate":
        records = [particle_record(7, math.nan, -10.0, 0.0, BOM_ALIVE)]
        header = (1.0, 8.0, 1.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "infinite-age":
        records = [particle_record(7, 10.0, -10.0, 0.0, BOM_ALIVE, math.inf)]
        header = (1.0, 8.0, 1.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "bad-release":
        records = [particle_record(7, 10.0, -10.0, -1.0, BOM_ALIVE)]
        header = (1.0, 8.0, 1.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "outside":
        records = [particle_record(7, 10.0, 90.0, 0.0, BOM_ALIVE)]
        header = (1.0, 8.0, 1.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "capacity":
        records = [
            particle_record(i + 1, 10.0, -10.0, 0.0, BOM_ALIVE)
            for i in range(65)
        ]
        header = (1.0, 8.0, 65.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "limit":
        records = []
        header = (1.0, 8.0, 10_001.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    elif name == "truncated":
        records = []
        header = (1.0, 8.0, 1.0, 1.0, 1.0, 64.0, 0.0, 0.0)
    else:
        raise ValueError(f"unknown scenario: {name}")

    return header, records


def write_meta(path: Path, nrecords: int) -> None:
    text = f""" nDims = [   3 ];
 dimList = [
  1,    1,    1,
  1,    1,    1,
  8,    1,    8
 ];
 dataprec = [ 'float64' ];
 nrecords = [ {nrecords:5d} ];
 timeStepNumber = [          0 ];
"""
    path.write_text(text, encoding="ascii")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "scenario",
        choices=(
            "valid",
            "one",
            "two",
            "duplicate",
            "bad-schema",
            "bad-id",
            "bad-status",
            "nan-coordinate",
            "infinite-age",
            "bad-release",
            "outside",
            "capacity",
            "limit",
            "truncated",
        ),
    )
    parser.add_argument("output_prefix", type=Path)
    args = parser.parse_args()

    header, records = scenario_records(args.scenario)
    data_path = args.output_prefix.with_suffix(".data")
    meta_path = args.output_prefix.with_suffix(".meta")
    data_path.parent.mkdir(parents=True, exist_ok=True)

    with data_path.open("wb") as stream:
        for record in [header, *records]:
            stream.write(struct.pack(">8d", *record))
    if args.scenario == "truncated":
        write_meta(meta_path, 2)
    else:
        write_meta(meta_path, len(records) + 1)


if __name__ == "__main__":
    main()
