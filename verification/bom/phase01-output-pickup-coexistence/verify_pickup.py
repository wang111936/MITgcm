#!/usr/bin/env python3
"""Verify and canonicalize a schema-1 P1.5 BOM pickup."""

from __future__ import annotations

import argparse
import math
import re
import struct
from pathlib import Path


FIELDS = 24
SIG_FIELDS = 16
SCHEMA = 1
EXPECTED_IDS = {1, 4_294_967_301, 9_007_199_254_740_993}
INVARIANT_FIELDS = (*range(0, 7), *range(9, 15), *range(18, 24))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def exact_integer(value: float, label: str) -> int:
    require(math.isfinite(value), f"{label}: non-finite")
    require(value == math.trunc(value), f"{label}: non-integral {value!r}")
    return int(value)


def read_records(path: Path, fields: int) -> list[tuple[float, ...]]:
    payload = path.read_bytes()
    record_bytes = fields * 8
    require(len(payload) % record_bytes == 0,
            f"partial record in {path}: {len(payload)} bytes")
    return [
        struct.unpack(f">{fields}d", payload[offset:offset + record_bytes])
        for offset in range(0, len(payload), record_bytes)
    ]


def parse_meta(path: Path, records: int, iteration: int) -> None:
    require(path.is_file(), f"missing meta file: {path}")
    text = path.read_text(encoding="ascii")
    precision = re.search(r"dataprec\s*=\s*\[\s*'([^']+)'\s*\]", text)
    nrecords = re.search(r"nrecords\s*=\s*\[\s*(\d+)\s*\]", text)
    timestep = re.search(r"timeStepNumber\s*=\s*\[\s*(-?\d+)\s*\]", text)
    require(precision is not None and precision.group(1) == "float64",
            f"bad precision in {path}")
    require(nrecords is not None and int(nrecords.group(1)) == records,
            f"bad record count in {path}")
    require(timestep is not None and int(timestep.group(1)) == iteration,
            f"bad timestep in {path}")


def owner_for_tile(
    tile_i: int, tile_j: int, npy: int, nsx: int, nsy: int
) -> tuple[int, int, int]:
    rank_x, local_i0 = divmod(tile_i - 1, nsx)
    rank_y, local_j0 = divmod(tile_j - 1, nsy)
    return rank_y + rank_x * npy, local_i0 + 1, local_j0 + 1


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("suffix")
    parser.add_argument("iteration", type=int)
    parser.add_argument("time", type=float)
    parser.add_argument("frequency", type=float)
    parser.add_argument("next_time", type=float)
    parser.add_argument("canonical_output", type=Path)
    parser.add_argument("--npx", type=int, default=1)
    parser.add_argument("--npy", type=int, default=1)
    parser.add_argument("--nsx", type=int, default=2)
    parser.add_argument("--nsy", type=int, default=2)
    parser.add_argument("--invariant-output", type=Path)
    args = parser.parse_args()

    require(min(args.npx, args.npy, args.nsx, args.nsy) > 0,
            "layout dimensions must be positive")
    tiles_x = args.npx * args.nsx
    tiles_y = args.npy * args.nsy

    prefix = f"pickup_bom.{args.suffix}"
    sig_path = args.run_dir / f"{prefix}.sig.data"
    signature_records = read_records(sig_path, SIG_FIELDS)
    require(len(signature_records) == 1, "signature must contain one record")
    signature = signature_records[0]
    parse_meta(sig_path.with_suffix(".meta"), 1, args.iteration)
    require(all(math.isfinite(value) for value in signature),
            "non-finite signature field")
    expected_signature = (
        1.0, 16.0, float(args.npx), float(args.npy), 4.0, 3.0,
        float(args.nsx), float(args.nsy),
        8.0, 6.0, 64.0, 3.0, float(args.iteration), args.time,
        args.frequency, args.next_time,
    )
    require(signature == expected_signature,
            f"signature mismatch: {signature!r}")

    data_files = sorted(args.run_dir.glob(f"{prefix}.[0-9][0-9][0-9]."
                                          "[0-9][0-9][0-9].data"))
    expected_tiles_count = tiles_x * tiles_y
    require(len(data_files) == expected_tiles_count,
            f"expected {expected_tiles_count} tiled pickup files, "
            f"found {len(data_files)}")
    canonical: list[tuple[int, tuple[float, ...]]] = []
    tiles: set[tuple[int, int]] = set()

    for data_path in data_files:
        match = re.search(r"\.(\d{3})\.(\d{3})\.data$", data_path.name)
        require(match is not None, f"bad tiled name: {data_path.name}")
        tile_i, tile_j = (int(match.group(1)), int(match.group(2)))
        require(1 <= tile_i <= tiles_x and 1 <= tile_j <= tiles_y,
                f"unexpected tile: {data_path.name}")
        require((tile_i, tile_j) not in tiles, f"duplicate tile {tile_i},{tile_j}")
        tiles.add((tile_i, tile_j))

        records = read_records(data_path, FIELDS)
        require(records, f"empty pickup tile: {data_path}")
        header = records[0]
        tile_count = exact_integer(header[2], f"{data_path}: tile count")
        require(len(records) == tile_count + 1,
                f"header/data count mismatch in {data_path}")
        parse_meta(data_path.with_suffix(".meta"), len(records), args.iteration)
        owner_rank, owner_bi, owner_bj = owner_for_tile(
            tile_i, tile_j, args.npy, args.nsx, args.nsy
        )
        expected_header = {
            0: 1,
            1: 24,
            3: 3,
            4: 1,
            5: 1,
            6: 64,
            7: args.iteration,
            8: args.time,
            9: args.next_time,
            10: args.frequency,
            11: args.npx,
            12: args.npy,
            13: 4,
            14: 3,
            15: args.nsx,
            16: args.nsy,
            17: 1 + (tile_i - 1) * 4,
            18: 1 + (tile_j - 1) * 3,
            19: owner_rank,
            20: owner_bi,
            21: owner_bj,
            22: 64,
            23: 0,
        }
        require(all(math.isfinite(value) for value in header),
                f"non-finite header in {data_path}")
        for field, expected in expected_header.items():
            require(header[field] == expected,
                    f"header field {field + 1} mismatch in {data_path}")

        previous_id = 0
        for record in records[1:]:
            require(all(math.isfinite(value) for value in record),
                    f"non-finite particle record in {data_path}")
            id_high = exact_integer(record[0], "ID high")
            id_low = exact_integer(record[1], "ID low")
            require(0 <= id_high <= 0x7FFFFFFF and 0 <= id_low <= 0xFFFFFFFF,
                    f"invalid ID words in {data_path}")
            particle_id = (id_high << 32) | id_low
            require(particle_id > previous_id,
                    f"unsorted/duplicate ID in {data_path}")
            require(particle_id in EXPECTED_IDS,
                    f"unexpected ID {particle_id} in {data_path}")
            status = exact_integer(record[2], "status")
            if particle_id == 9_007_199_254_740_993:
                require(status == 6 and record[5] == 216_000.0 and record[6] == 0.0,
                        "WAITING state was not preserved")
            else:
                require(status == 1 and record[5] == 0.0 and record[6] == args.time,
                        f"ALIVE age/release mismatch for ID {particle_id}")
            require(record[15] == owner_rank
                    and record[16] == owner_bi
                    and record[17] == owner_bj,
                    f"owner mismatch for ID {particle_id}")
            require(all(value == 0.0 for value in record[18:24]),
                    f"reserved field mismatch for ID {particle_id}")
            canonical.append((particle_id, record))
            previous_id = particle_id

    expected_tiles = {
        (tile_i, tile_j)
        for tile_i in range(1, tiles_x + 1)
        for tile_j in range(1, tiles_y + 1)
    }
    require(tiles == expected_tiles, "incomplete tile set")
    require({particle_id for particle_id, _ in canonical} == EXPECTED_IDS,
            "global pickup ID set mismatch")
    require(len(canonical) == len(EXPECTED_IDS), "duplicate global pickup ID")
    canonical.sort(key=lambda item: item[0])

    args.canonical_output.parent.mkdir(parents=True, exist_ok=True)
    with args.canonical_output.open("w", encoding="ascii", newline="\n") as stream:
        stream.write(f"signature\t{struct.pack('>16d', *signature).hex()}\n")
        stream.write("id\trecord_hex\n")
        for particle_id, record in canonical:
            stream.write(f"{particle_id}\t{struct.pack('>24d', *record).hex()}\n")

    if args.invariant_output is not None:
        args.invariant_output.parent.mkdir(parents=True, exist_ok=True)
        invariant_signature = (*signature[0:2], *signature[8:16])
        with args.invariant_output.open(
            "w", encoding="ascii", newline="\n"
        ) as stream:
            stream.write(
                f"signature\t"
                f"{struct.pack('>10d', *invariant_signature).hex()}\n"
            )
            stream.write("id\tinvariant_record_hex\n")
            for particle_id, record in canonical:
                invariant = tuple(record[field] for field in INVARIANT_FIELDS)
                stream.write(
                    f"{particle_id}\t"
                    f"{struct.pack('>19d', *invariant).hex()}\n"
                )

    print(
        "P1.5 PICKUP VERIFY PASS: signature, "
        f"{expected_tiles_count} tiles, 3 exact IDs"
    )


if __name__ == "__main__":
    main()
