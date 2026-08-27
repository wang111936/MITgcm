#!/usr/bin/env python3
"""Create one deterministic P2.5 schema-2 pickup corruption."""

from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path


CHUNK_FIELDS = 24
PICKUP_FIELDS = 45


def replace_double(path: Path, index: int, value: float) -> None:
    payload = bytearray(path.read_bytes())
    offset = index * 8
    if offset + 8 > len(payload):
        raise RuntimeError(f"field {index + 1} outside {path}")
    payload[offset:offset + 8] = struct.pack(">d", value)
    path.write_bytes(payload)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("suffix")
    parser.add_argument(
        "mutation",
        choices=("mode", "source", "parameter", "decomposition",
                 "particle-diag", "field-block"),
    )
    args = parser.parse_args()
    prefix = f"pickup_bom.{args.suffix}"

    if args.mutation in {"mode", "source", "parameter", "decomposition"}:
        path = args.run_dir / f"{prefix}.sig.data"
        field = {
            "mode": 16,
            "source": 19,
            "parameter": 23,
            "decomposition": 2,
        }[args.mutation]
        current = struct.unpack(">d", path.read_bytes()[field * 8:(field + 1) * 8])[0]
        replace_double(path, field, math.nextafter(current + 1.0, math.inf))
    elif args.mutation == "particle-diag":
        paths = sorted(args.run_dir.glob(
            f"{prefix}.[0-9][0-9][0-9].[0-9][0-9][0-9].data"
        ))
        path = next((candidate for candidate in paths
                     if len(candidate.read_bytes()) > PICKUP_FIELDS * 8), None)
        if path is None:
            raise RuntimeError("no nonempty pickup tile")
        # First particle, schema-2 field 19 (vBaseE); legacy field 10 remains.
        replace_double(path, PICKUP_FIELDS + 18, 12345.0)
    else:
        paths = sorted(args.run_dir.glob(
            f"{prefix}.env.[0-9][0-9][0-9].[0-9][0-9][0-9].data"
        ))
        if not paths:
            raise RuntimeError("no endpoint sidecar")
        payload = paths[0].read_bytes()
        paths[0].write_bytes(payload[:-CHUNK_FIELDS * 8])

    print(f"P2.5 MUTATION READY: {args.mutation}")


if __name__ == "__main__":
    main()
