#!/usr/bin/env python3
"""Generate three big-endian scalar records for the P4.1 FILES gate."""

import argparse
import pathlib
import struct


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--nx", type=int, default=8)
    parser.add_argument("--ny", type=int, default=6)
    args = parser.parse_args()
    output = pathlib.Path(args.output_dir) / "p41_nutrient.bin"
    with output.open("wb") as stream:
        for value in (2.0, 4.0, 2.0):
            stream.write(struct.pack(">d", value) * (args.nx * args.ny))


if __name__ == "__main__":
    main()
