#!/usr/bin/env python3
"""Canonicalize BOM output and pickup from the exp4 coexistence matrix."""

from __future__ import annotations

import argparse
import math
import re
import struct
from pathlib import Path


FIELDS = 24
SIG_FIELDS = 16
EVENTS = {
    6: (3600.0, 3600.0, 7200.0),
    12: (7200.0, 7200.0, 10800.0),
}
IDS = {1, 4_294_967_301, 9_007_199_254_740_993}
FILE_RE = re.compile(
    r"^bom_traj\.(?P<iteration>\d{10})\.(?P<tile_i>\d{3})\."
    r"(?P<tile_j>\d{3})\.data$"
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def exact_integer(value: float, label: str) -> int:
    require(math.isfinite(value), f"{label}: non-finite")
    require(value == math.trunc(value), f"{label}: non-integral {value!r}")
    return int(value)


def read_records(path: Path, fields: int = FIELDS) -> list[tuple[float, ...]]:
    payload = path.read_bytes()
    record_bytes = fields * 8
    require(len(payload) % record_bytes == 0,
            f"partial record in {path}: {len(payload)}")
    return [
        struct.unpack(f">{fields}d", payload[offset:offset + record_bytes])
        for offset in range(0, len(payload), record_bytes)
    ]


def parse_meta(path: Path, records: int, iteration: int) -> None:
    require(path.is_file(), f"missing meta: {path}")
    text = path.read_text(encoding="ascii")
    precision = re.search(r"dataprec\s*=\s*\[\s*'([^']+)'\s*\]", text)
    count = re.search(r"nrecords\s*=\s*\[\s*(\d+)\s*\]", text)
    timestep = re.search(r"timeStepNumber\s*=\s*\[\s*(-?\d+)\s*\]", text)
    require(precision is not None and precision.group(1) == "float64",
            f"bad precision: {path}")
    require(count is not None and int(count.group(1)) == records,
            f"bad record count: {path}")
    require(timestep is not None and int(timestep.group(1)) == iteration,
            f"bad timestep: {path}")


def owner_for_tile(
    tile_i: int, tile_j: int, npy: int, nsx: int, nsy: int
) -> tuple[int, int, int]:
    rank_x, local_i0 = divmod(tile_i - 1, nsx)
    rank_y, local_j0 = divmod(tile_j - 1, nsy)
    return rank_y + rank_x * npy, local_i0 + 1, local_j0 + 1


def decode_id(record: tuple[float, ...], label: str) -> int:
    high = exact_integer(record[0], f"{label}: ID high")
    low = exact_integer(record[1], f"{label}: ID low")
    require(0 <= high <= 0x7FFFFFFF and 0 <= low <= 0xFFFFFFFF,
            f"{label}: invalid ID words")
    return (high << 32) | low


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("trajectory_output", type=Path)
    parser.add_argument("pickup_output", type=Path)
    parser.add_argument("--npx", type=int, required=True)
    parser.add_argument("--npy", type=int, required=True)
    parser.add_argument("--nsx", type=int, required=True)
    parser.add_argument("--nsy", type=int, required=True)
    args = parser.parse_args()

    tiles_x = args.npx * args.nsx
    tiles_y = args.npy * args.nsy
    require((tiles_x, tiles_y) == (2, 2), "exp4 must retain a 2x2 tile grid")
    expected_tiles = {
        (tile_i, tile_j)
        for tile_i in range(1, tiles_x + 1)
        for tile_j in range(1, tiles_y + 1)
    }

    trajectory: list[tuple[int, int, tuple[float, ...]]] = []
    seen_tiles = {iteration: set() for iteration in EVENTS}
    paths = sorted(args.run_dir.glob("bom_traj.*.*.*.data"))
    require(len(paths) == len(EVENTS) * len(expected_tiles),
            f"trajectory file count mismatch: {len(paths)}")
    for path in paths:
        match = FILE_RE.match(path.name)
        require(match is not None, f"bad trajectory name: {path.name}")
        iteration = int(match.group("iteration"))
        tile_i = int(match.group("tile_i"))
        tile_j = int(match.group("tile_j"))
        require(iteration in EVENTS and (tile_i, tile_j) in expected_tiles,
                f"unexpected event/tile: {path.name}")
        seen_tiles[iteration].add((tile_i, tile_j))
        records = read_records(path)
        require(records, f"empty trajectory tile: {path}")
        count = exact_integer(records[0][2], f"{path}: count")
        require(len(records) == count + 1, f"trajectory count mismatch: {path}")
        parse_meta(path.with_suffix(".meta"), len(records), iteration)
        sample, scheduled, next_time = EVENTS[iteration]
        rank, bi, bj = owner_for_tile(
            tile_i, tile_j, args.npy, args.nsx, args.nsy
        )
        expected_header = {
            0: 1, 1: 24, 3: 3, 4: 1, 5: 1, 6: 64,
            7: iteration, 8: sample, 9: scheduled, 10: next_time,
            11: args.npx, 12: args.npy,
            13: 1 + (tile_i - 1) * 40,
            14: 1 + (tile_j - 1) * 21,
            15: rank, 16: bi, 17: bj,
        }
        header = records[0]
        require(all(math.isfinite(value) for value in header),
                f"non-finite trajectory header: {path}")
        for field, expected in expected_header.items():
            require(header[field] == expected,
                    f"trajectory header field {field + 1}: {path}")
        require(all(value == 0.0 for value in header[18:]),
                f"trajectory reserved header: {path}")
        previous = 0
        for record in records[1:]:
            require(all(math.isfinite(value) for value in record),
                    f"non-finite trajectory record: {path}")
            current_id = decode_id(record, str(path))
            require(current_id in IDS and current_id > previous,
                    f"trajectory ID order/set: {path}")
            require(record[3] == sample and record[4] == iteration,
                    f"trajectory sample/iteration: {path}")
            require(record[17] == rank and record[18] == bi and record[19] == bj,
                    f"trajectory owner: {path}")
            require(record[20] == 1.0 and all(v == 0.0 for v in record[21:]),
                    f"trajectory coordinate/reserved: {path}")
            require(record[2] == (6.0 if current_id == max(IDS) else 1.0),
                    f"trajectory status: {path}")
            trajectory.append((iteration, current_id, record))
            previous = current_id
    require(all(tiles == expected_tiles for tiles in seen_tiles.values()),
            "incomplete trajectory tile set")
    require(len(trajectory) == len(EVENTS) * len(IDS),
            "trajectory global count mismatch")
    require(len({(iteration, pid) for iteration, pid, _ in trajectory})
            == len(trajectory), "duplicate trajectory key")
    trajectory.sort(key=lambda item: (item[0], item[1]))
    with args.trajectory_output.open("w", encoding="ascii", newline="\n") as stream:
        stream.write("iteration\tid\trecord_hex\n")
        for iteration, pid, record in trajectory:
            stream.write(
                f"{iteration}\t{pid}\t{struct.pack('>24d', *record).hex()}\n"
            )

    prefix = "pickup_bom.0000000012"
    sig_path = args.run_dir / f"{prefix}.sig.data"
    signature_records = read_records(sig_path, SIG_FIELDS)
    require(len(signature_records) == 1, "signature record count mismatch")
    signature = signature_records[0]
    parse_meta(sig_path.with_suffix(".meta"), 1, 12)
    expected_signature = (
        1.0, 16.0, float(args.npx), float(args.npy), 40.0, 21.0,
        float(args.nsx), float(args.nsy), 80.0, 42.0, 64.0, 3.0,
        12.0, 7200.0, 3600.0, 10800.0,
    )
    require(signature == expected_signature, "pickup signature mismatch")

    pickup: list[tuple[int, tuple[float, ...]]] = []
    pickup_tiles: set[tuple[int, int]] = set()
    pickup_paths = sorted(args.run_dir.glob(f"{prefix}.*.*.data"))
    require(len(pickup_paths) == 4,
            f"pickup tile file count mismatch: {len(pickup_paths)}")
    for path in pickup_paths:
        match = re.search(r"\.(\d{3})\.(\d{3})\.data$", path.name)
        require(match is not None, f"bad pickup tile name: {path.name}")
        tile_i, tile_j = int(match.group(1)), int(match.group(2))
        require((tile_i, tile_j) in expected_tiles, f"bad pickup tile: {path}")
        pickup_tiles.add((tile_i, tile_j))
        records = read_records(path)
        count = exact_integer(records[0][2], f"{path}: count")
        require(len(records) == count + 1, f"pickup count mismatch: {path}")
        parse_meta(path.with_suffix(".meta"), len(records), 12)
        rank, bi, bj = owner_for_tile(
            tile_i, tile_j, args.npy, args.nsx, args.nsy
        )
        expected_header = {
            0: 1, 1: 24, 3: 3, 4: 1, 5: 1, 6: 64,
            7: 12, 8: 7200, 9: 10800, 10: 3600,
            11: args.npx, 12: args.npy, 13: 40, 14: 21,
            15: args.nsx, 16: args.nsy,
            17: 1 + (tile_i - 1) * 40,
            18: 1 + (tile_j - 1) * 21,
            19: rank, 20: bi, 21: bj, 22: 64, 23: 0,
        }
        header = records[0]
        for field, expected in expected_header.items():
            require(header[field] == expected,
                    f"pickup header field {field + 1}: {path}")
        previous = 0
        for record in records[1:]:
            require(all(math.isfinite(value) for value in record),
                    f"non-finite pickup record: {path}")
            current_id = decode_id(record, str(path))
            require(current_id in IDS and current_id > previous,
                    f"pickup ID order/set: {path}")
            require(record[15] == rank and record[16] == bi and record[17] == bj,
                    f"pickup owner: {path}")
            require(all(value == 0.0 for value in record[18:]),
                    f"pickup reserved: {path}")
            require(record[2] == (6.0 if current_id == max(IDS) else 1.0),
                    f"pickup status: {path}")
            pickup.append((current_id, record))
            previous = current_id
    require(pickup_tiles == expected_tiles, "incomplete pickup tile set")
    require({pid for pid, _ in pickup} == IDS and len(pickup) == len(IDS),
            "pickup global ID set mismatch")
    pickup.sort(key=lambda item: item[0])
    with args.pickup_output.open("w", encoding="ascii", newline="\n") as stream:
        stream.write(f"signature\t{struct.pack('>16d', *signature).hex()}\n")
        stream.write("id\trecord_hex\n")
        for pid, record in pickup:
            stream.write(f"{pid}\t{struct.pack('>24d', *record).hex()}\n")

    print("P1.5 COEXISTENCE BOM VERIFY PASS: 2 events; final pickup; 3 IDs")


if __name__ == "__main__":
    main()
