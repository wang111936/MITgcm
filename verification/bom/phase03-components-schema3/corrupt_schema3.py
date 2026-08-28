#!/usr/bin/env python3
"""Apply one deterministic schema-3 corruption to a restart fixture."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


def p3_tiles(root: Path) -> list[Path]:
    files = sorted(root.glob("pickup_bom.p34schema3.p3.[0-9][0-9][0-9].[0-9][0-9][0-9].data"))
    if len(files) < 2:
        raise AssertionError("corruption fixture needs at least two P3 tiles")
    return files


def replace_f64(path: Path, index: int, value: float) -> None:
    data = bytearray(path.read_bytes())
    offset = index * 8
    data[offset : offset + 8] = struct.pack(">d", value)
    path.write_bytes(data)


def flip_low_bit(path: Path, byte_offset: int) -> None:
    data = bytearray(path.read_bytes())
    data[byte_offset + 7] ^= 1
    path.write_bytes(data)


def increment_f64(path: Path, index: int) -> None:
    data = bytearray(path.read_bytes())
    offset = index * 8
    value = struct.unpack(">d", data[offset : offset + 8])[0]
    data[offset : offset + 8] = struct.pack(">d", value + 1.0)
    path.write_bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument(
        "mutation",
        choices=(
            "missing-p3sig",
            "missing-sidecar",
            "signature-header",
            "signature-p2",
            "side-header",
            "particle-id",
            "raft-id",
            "neighbor",
            "raft-size",
            "spring-east",
            "spring-north",
            "truncate",
            "append",
            "reorder",
        ),
    )
    args = parser.parse_args()
    root = args.root
    mutation = args.mutation
    tiles = p3_tiles(root)
    first = tiles[0]
    if mutation == "missing-p3sig":
        (root / "pickup_bom.p34schema3.p3sig.data").unlink()
    elif mutation == "missing-sidecar":
        first.unlink()
    elif mutation == "signature-header":
        replace_f64(root / "pickup_bom.p34schema3.p3sig.data", 0, 4.0)
    elif mutation == "signature-p2":
        flip_low_bit(root / "pickup_bom.p34schema3.p3sig.data", 44 * 8)
    elif mutation == "side-header":
        replace_f64(first, 0, 2.0)
    elif mutation == "particle-id":
        replace_f64(first, 8 + 1, 999.0)
    elif mutation == "raft-id":
        replace_f64(first, 8 + 3, 999.0)
    elif mutation == "neighbor":
        increment_f64(first, 8 + 4)
    elif mutation == "raft-size":
        replace_f64(first, 8 + 5, 3.0)
    elif mutation == "spring-east":
        flip_low_bit(first, (8 + 6) * 8)
    elif mutation == "spring-north":
        flip_low_bit(first, (8 + 7) * 8)
    elif mutation == "truncate":
        first.write_bytes(first.read_bytes()[:-8])
    elif mutation == "append":
        first.write_bytes(first.read_bytes() + b"\x00" * 8)
    elif mutation == "reorder":
        second = tiles[1]
        first_data = bytearray(first.read_bytes())
        second_data = bytearray(second.read_bytes())
        first_record = first_data[64:128]
        second_record = second_data[64:128]
        first_data[64:128] = second_record
        second_data[64:128] = first_record
        first.write_bytes(first_data)
        second.write_bytes(second_data)
    print(f"P3_SCHEMA3_CORRUPTION_APPLIED {mutation}")


if __name__ == "__main__":
    main()
