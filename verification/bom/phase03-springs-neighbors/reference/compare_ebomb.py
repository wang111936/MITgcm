#!/usr/bin/env python3
"""Compare the stable Fortran eBOMB kernel with the locked Julia fixture."""

from __future__ import annotations

import argparse
import csv
import math
import struct
from pathlib import Path


def read_fortran_record(path: Path) -> float:
    matches: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        fields = line.split()
        if len(fields) >= 3 and fields[:2] == ["P31-LAW-RECORD", "EBOMB"]:
            matches.append(fields[2])
    if len(matches) != 1:
        raise ValueError(f"expected one Fortran EBOMB record, found {len(matches)}")
    bits = int(matches[0], 16)
    return struct.unpack(">d", struct.pack(">Q", bits))[0]


def read_julia_value(path: Path) -> float:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    if len(rows) != 1 or rows[0]["fixture"] != "ebomb-200m":
        raise ValueError("locked Julia eBOMB fixture is missing or ambiguous")
    return float(rows[0]["stiffness_per_s2"])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("fortran_records", type=Path)
    parser.add_argument("julia_tsv", type=Path)
    args = parser.parse_args()
    fortran_value = read_fortran_record(args.fortran_records)
    julia_value = read_julia_value(args.julia_tsv)
    tolerance = 128.0 * math.ulp(1.0) * max(1.0, abs(julia_value))
    if not math.isfinite(fortran_value) or not math.isfinite(julia_value):
        raise AssertionError("non-finite eBOMB comparison value")
    if abs(fortran_value - julia_value) > tolerance:
        raise AssertionError(
            f"eBOMB mismatch: Fortran={fortran_value!r} Julia={julia_value!r} "
            f"tolerance={tolerance!r}"
        )
    print(
        "P3-S02-JULIA PASS: "
        f"Fortran={fortran_value:.17g} Julia={julia_value:.17g}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
