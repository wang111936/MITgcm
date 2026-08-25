#!/usr/bin/env python3
"""Verify the frozen P1.5 schema-1 tiled trajectory contract."""

from __future__ import annotations

import argparse
import math
import re
import struct
from pathlib import Path


FIELDS = 24
SCHEMA = 1
EVENTS = {
    3: (180.0, 150.0, 300.0),
    5: (300.0, 300.0, 450.0),
    8: (480.0, 450.0, 600.0),
}
EXPECTED_IDS = {1, 4_294_967_301, 9_007_199_254_740_993}
INVARIANT_FIELDS = (*range(0, 9), *range(11, 17), *range(20, 24))
FILE_RE = re.compile(
    r"^bom_traj\.(?P<iteration>\d{10})\.(?P<i_global>\d{3})\."
    r"(?P<j_global>\d{3})\.data$"
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def exact_integer(value: float, label: str) -> int:
    require(math.isfinite(value), f"{label}: non-finite value")
    require(value == math.trunc(value), f"{label}: non-integral value {value!r}")
    return int(value)


def parse_meta(path: Path, expected_records: int, expected_iteration: int) -> None:
    require(path.is_file(), f"missing meta file: {path}")
    text = path.read_text(encoding="ascii")
    precision = re.search(r"dataprec\s*=\s*\[\s*'([^']+)'\s*\]", text)
    records = re.search(r"nrecords\s*=\s*\[\s*(\d+)\s*\]", text)
    iteration = re.search(r"timeStepNumber\s*=\s*\[\s*(-?\d+)\s*\]", text)
    require(precision is not None and precision.group(1) == "float64",
            f"bad precision in {path}")
    require(records is not None and int(records.group(1)) == expected_records,
            f"bad record count in {path}")
    require(iteration is not None and int(iteration.group(1)) == expected_iteration,
            f"bad iteration in {path}")


def read_records(path: Path) -> list[tuple[float, ...]]:
    payload = path.read_bytes()
    record_bytes = FIELDS * 8
    require(len(payload) % record_bytes == 0,
            f"partial record in {path}: {len(payload)} bytes")
    return [
        struct.unpack(">24d", payload[offset:offset + record_bytes])
        for offset in range(0, len(payload), record_bytes)
    ]


def owner_for_tile(
    tile_i: int, tile_j: int, npy: int, nsx: int, nsy: int
) -> tuple[int, int, int]:
    rank_x, local_i0 = divmod(tile_i - 1, nsx)
    rank_y, local_j0 = divmod(tile_j - 1, nsy)
    return rank_y + rank_x * npy, local_i0 + 1, local_j0 + 1


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir", type=Path)
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

    data_files = sorted(args.run_dir.glob("bom_traj.*.*.*.data"))
    expected_files = len(EVENTS) * tiles_x * tiles_y
    require(len(data_files) == expected_files,
            f"expected {expected_files} tiled data files, "
            f"found {len(data_files)}")

    seen_tiles: dict[int, set[tuple[int, int]]] = {iteration: set() for iteration in EVENTS}
    canonical: list[tuple[int, int, tuple[float, ...]]] = []

    for data_path in data_files:
        match = FILE_RE.match(data_path.name)
        require(match is not None, f"invalid trajectory name: {data_path.name}")
        iteration = int(match.group("iteration"))
        tile_i = int(match.group("i_global"))
        tile_j = int(match.group("j_global"))
        require(iteration in EVENTS, f"unexpected output iteration {iteration}")
        require(1 <= tile_i <= tiles_x and 1 <= tile_j <= tiles_y,
                f"unexpected tile suffix in {data_path.name}")
        require((tile_i, tile_j) not in seen_tiles[iteration],
                f"duplicate tile file in iteration {iteration}")
        seen_tiles[iteration].add((tile_i, tile_j))

        records = read_records(data_path)
        require(records, f"empty trajectory file: {data_path}")
        header = records[0]
        tile_count = exact_integer(header[2], f"{data_path}: tile count")
        require(len(records) == tile_count + 1,
                f"record count disagrees with header in {data_path}")
        parse_meta(data_path.with_suffix(".meta"), len(records), iteration)

        sample_time, scheduled_time, next_time = EVENTS[iteration]
        owner_rank, owner_bi, owner_bj = owner_for_tile(
            tile_i, tile_j, args.npy, args.nsx, args.nsy
        )
        expected_header = {
            0: SCHEMA,
            1: FIELDS,
            3: len(EXPECTED_IDS),
            4: 1,
            5: 1,
            6: 64,
            7: iteration,
            8: sample_time,
            9: scheduled_time,
            10: next_time,
            11: args.npx,
            12: args.npy,
            13: 1 + (tile_i - 1) * 4,
            14: 1 + (tile_j - 1) * 3,
            15: owner_rank,
            16: owner_bi,
            17: owner_bj,
        }
        require(all(math.isfinite(value) for value in header),
                f"non-finite header in {data_path}")
        for field, expected in expected_header.items():
            require(header[field] == expected,
                    f"header field {field + 1} in {data_path}: "
                    f"{header[field]!r} != {expected!r}")
        require(all(value == 0.0 for value in header[18:24]),
                f"nonzero reserved header field in {data_path}")

        for record_index, record in enumerate(records[1:], start=2):
            require(all(math.isfinite(value) for value in record),
                    f"non-finite particle record {record_index} in {data_path}")
            id_high = exact_integer(record[0], f"{data_path}: ID high")
            id_low = exact_integer(record[1], f"{data_path}: ID low")
            require(0 <= id_high <= 0xFFFFFFFF and 0 <= id_low <= 0xFFFFFFFF,
                    f"ID word outside unsigned 32-bit range in {data_path}")
            particle_id = (id_high << 32) | id_low
            require(particle_id in EXPECTED_IDS,
                    f"unexpected particle ID {particle_id} in {data_path}")
            require(record[3] == sample_time and record[4] == iteration,
                    f"particle sample/iteration mismatch in {data_path}")
            require(record[17] == owner_rank
                    and record[18] == owner_bi
                    and record[19] == owner_bj,
                    f"particle owner mismatch in {data_path}")
            require(record[20] == 1.0,
                    f"particle coordinate code mismatch in {data_path}")
            require(all(value == 0.0 for value in record[21:24]),
                    f"nonzero particle reserved field in {data_path}")
            canonical.append((iteration, particle_id, record))

    expected_tiles = {
        (tile_i, tile_j)
        for tile_i in range(1, tiles_x + 1)
        for tile_j in range(1, tiles_y + 1)
    }
    for iteration, tiles in seen_tiles.items():
        require(tiles == expected_tiles,
                f"incomplete tile set at iteration {iteration}: {sorted(tiles)}")

    require(len(canonical) == len(EVENTS) * len(EXPECTED_IDS),
            f"expected 9 particle records, found {len(canonical)}")
    keys = [(iteration, particle_id) for iteration, particle_id, _ in canonical]
    require(len(keys) == len(set(keys)), "duplicate (iteration, ID) output key")
    for iteration in EVENTS:
        ids = {particle_id for event_iter, particle_id, _ in canonical
               if event_iter == iteration}
        require(ids == EXPECTED_IDS,
                f"ID set mismatch at iteration {iteration}: {sorted(ids)}")

    canonical.sort(key=lambda item: (item[0], item[1]))
    args.canonical_output.parent.mkdir(parents=True, exist_ok=True)
    with args.canonical_output.open("w", encoding="ascii", newline="\n") as stream:
        stream.write("iteration\tid\trecord_hex\n")
        for iteration, particle_id, record in canonical:
            record_hex = struct.pack(">24d", *record).hex()
            stream.write(f"{iteration}\t{particle_id}\t{record_hex}\n")

    if args.invariant_output is not None:
        args.invariant_output.parent.mkdir(parents=True, exist_ok=True)
        with args.invariant_output.open(
            "w", encoding="ascii", newline="\n"
        ) as stream:
            stream.write("iteration\tid\tinvariant_record_hex\n")
            for iteration, particle_id, record in canonical:
                invariant = tuple(record[field] for field in INVARIANT_FIELDS)
                stream.write(
                    f"{iteration}\t{particle_id}\t"
                    f"{struct.pack('>19d', *invariant).hex()}\n"
                )

    print(
        "P1.5 TRAJECTORY VERIFY PASS: "
        f"{expected_files} files, 3 events, 9 unique records"
    )


if __name__ == "__main__":
    main()
