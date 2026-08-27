#!/usr/bin/env python3
"""Generate deterministic big-endian Stokes records for P2-E04/P2-N03."""

from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path

NX = 8
NY = 6
VALUES_PER_RECORD = NX * NY


def write_records(path: Path, values: list[float]) -> None:
    with path.open("wb") as stream:
        for value in values:
            stream.write(struct.pack(">d", value) * VALUES_PER_RECORD)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    write_records(output_dir / "ustokes.bin", [1.0, 4.0, 7.0])
    write_records(output_dir / "vstokes.bin", [-2.0, 1.0, 4.0])
    write_records(output_dir / "vstokes-short.bin", [-2.0])
    write_records(output_dir / "ustokes-nan.bin", [1.0, 4.0, math.nan])

    partial = output_dir / "ustokes-partial.bin"
    write_records(partial, [1.0, 4.0])
    with partial.open("ab") as stream:
        stream.write(b"\x00\x00\x00\x00")


if __name__ == "__main__":
    main()
