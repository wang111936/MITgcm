#!/usr/bin/env python3
"""Apply one deterministic corruption to a copied P1.5 pickup fixture."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


def replace_field(path: Path, record: int, field: int, value: float) -> None:
    payload = bytearray(path.read_bytes())
    offset = (record * 24 + field) * 8
    payload[offset:offset + 8] = struct.pack(">d", value)
    path.write_bytes(payload)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("suffix")
    parser.add_argument(
        "mode",
        choices=("signature-npx", "signature-time", "tile-schema", "duplicate-id"),
    )
    args = parser.parse_args()

    prefix = f"pickup_bom.{args.suffix}"
    signature = args.run_dir / f"{prefix}.sig.data"
    tile = args.run_dir / f"{prefix}.001.001.data"
    if args.mode == "signature-npx":
        payload = bytearray(signature.read_bytes())
        payload[2 * 8:3 * 8] = struct.pack(">d", 2.0)
        signature.write_bytes(payload)
    elif args.mode == "signature-time":
        payload = bytearray(signature.read_bytes())
        payload[13 * 8:14 * 8] = struct.pack(">d", 301.0)
        signature.write_bytes(payload)
    elif args.mode == "tile-schema":
        replace_field(tile, 0, 0, 2.0)
    elif args.mode == "duplicate-id":
        payload = bytearray(tile.read_bytes())
        first_id = payload[24 * 8:24 * 8 + 16]
        second_id_offset = 2 * 24 * 8
        payload[second_id_offset:second_id_offset + 16] = first_id
        tile.write_bytes(payload)


if __name__ == "__main__":
    main()
