#!/usr/bin/env python3
"""Write the fixed global 8x6x2 big-endian P2.5 velocity fixture."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--east", type=float, default=3.0)
    args = parser.parse_args()
    args.output.write_bytes(struct.pack(">96d", *([args.east] * 96)))
    print(f"P2.5 VELOCITY FIXTURE: {args.output} east={args.east}")


if __name__ == "__main__":
    main()
