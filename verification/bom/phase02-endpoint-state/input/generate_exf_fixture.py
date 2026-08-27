#!/usr/bin/env python3
"""Generate deterministic big-endian EXF records for P2-E03/P2-N03."""

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

    write_records(output_dir / "uwind.bin", [1.0, 4.0, 7.0, 10.0])
    write_records(output_dir / "vwind.bin", [-2.0, 1.0, 4.0, 7.0])
    write_records(output_dir / "vwind-short.bin", [-2.0])
    write_records(output_dir / "uwind-nan.bin", [1.0, 4.0, math.nan, 10.0])

    partial = output_dir / "uwind-partial.bin"
    write_records(partial, [1.0, 4.0])
    with partial.open("ab") as stream:
        stream.write(b"\x00\x00\x00\x00")


if __name__ == "__main__":
    main()
