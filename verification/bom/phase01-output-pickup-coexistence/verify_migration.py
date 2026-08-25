#!/usr/bin/env python3
"""Verify P1.5 production migration trajectory and final pickup files."""

from __future__ import annotations

import argparse
import math
import re
import struct
from pathlib import Path


FIELDS = 24
SIG_FIELDS = 16
EVENTS = {
    2: (120.0, 120.0, 240.0),
    4: (240.0, 240.0, 360.0),
    6: (360.0, 360.0, 480.0),
    8: (480.0, 480.0, 600.0),
}
IDS = (1, 4_294_967_301, 9_007_199_254_740_993)
SEED_X = {IDS[0]: 1400.0, IDS[1]: -500.0, IDS[2]: 500.0}
TRAJECTORY_INVARIANT = (*range(0, 9), *range(11, 17), *range(20, 24))
PICKUP_INVARIANT = (*range(0, 7), *range(9, 15), *range(18, 24))
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


def close(value: float, expected: float) -> bool:
    return abs(value - expected) <= 1.0e-11 * max(1.0, abs(expected))


def read_records(path: Path, fields: int = FIELDS) -> list[tuple[float, ...]]:
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
    count = re.search(r"nrecords\s*=\s*\[\s*(\d+)\s*\]", text)
    timestep = re.search(r"timeStepNumber\s*=\s*\[\s*(-?\d+)\s*\]", text)
    require(precision is not None and precision.group(1) == "float64",
            f"bad precision in {path}")
    require(count is not None and int(count.group(1)) == records,
            f"bad record count in {path}")
    require(timestep is not None and int(timestep.group(1)) == iteration,
            f"bad timestep in {path}")


def owner_for_tile(
    tile_i: int, tile_j: int, npy: int, nsx: int, nsy: int
) -> tuple[int, int, int]:
    rank_x, local_i0 = divmod(tile_i - 1, nsx)
    rank_y, local_j0 = divmod(tile_j - 1, nsy)
    return rank_y + rank_x * npy, local_i0 + 1, local_j0 + 1


def particle_id(record: tuple[float, ...], label: str) -> int:
    high = exact_integer(record[0], f"{label}: ID high")
    low = exact_integer(record[1], f"{label}: ID low")
    require(0 <= high <= 0x7FFFFFFF and 0 <= low <= 0xFFFFFFFF,
            f"{label}: invalid ID words")
    return (high << 32) | low


def expected_state(particle: int, sample_time: float) -> tuple[int, float, float]:
    if particle == IDS[2] and sample_time < 180.0:
        return 6, 0.0, SEED_X[particle]
    active_time = sample_time if particle != IDS[2] else sample_time - 180.0
    return 1, active_time, SEED_X[particle] + 3.0 * active_time


def validate_physical(
    particle: int,
    sample_time: float,
    status: float,
    x: float,
    y: float,
    release: float,
    age: float,
    east: float,
    north: float,
    drift_east: float,
    drift_north: float,
    label: str,
) -> None:
    expected_status, expected_age, expected_x = expected_state(
        particle, sample_time
    )
    expected_release = 180.0 if particle == IDS[2] else 0.0
    require(status == expected_status, f"{label}: status mismatch")
    require(close(x, expected_x) and close(y, -1000.0),
            f"{label}: position mismatch: {x}, {y}")
    require(release == expected_release and close(age, expected_age),
            f"{label}: release/age mismatch")
    expected_velocity = 0.0 if expected_status == 6 else 3.0
    require(close(east, expected_velocity) and close(north, 0.0),
            f"{label}: ocean velocity mismatch")
    require(close(drift_east, expected_velocity) and close(drift_north, 0.0),
            f"{label}: drift velocity mismatch")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("trajectory_output", type=Path)
    parser.add_argument("pickup_output", type=Path)
    parser.add_argument("--npx", type=int, required=True)
    parser.add_argument("--npy", type=int, required=True)
    parser.add_argument("--nsx", type=int, required=True)
    parser.add_argument("--nsy", type=int, required=True)
    parser.add_argument("--trajectory-invariant", type=Path, required=True)
    parser.add_argument("--pickup-invariant", type=Path, required=True)
    args = parser.parse_args()

    tiles_x = args.npx * args.nsx
    tiles_y = args.npy * args.nsy
    require((tiles_x, tiles_y) == (2, 2), "migration gate requires 2x2 tiles")
    expected_tiles = {
        (tile_i, tile_j)
        for tile_i in range(1, tiles_x + 1)
        for tile_j in range(1, tiles_y + 1)
    }

    trajectory: list[tuple[int, int, tuple[float, ...]]] = []
    seen_tiles = {iteration: set() for iteration in EVENTS}
    data_files = sorted(args.run_dir.glob("bom_traj.*.*.*.data"))
    require(len(data_files) == len(EVENTS) * len(expected_tiles),
            f"unexpected trajectory file count: {len(data_files)}")
    for path in data_files:
        match = FILE_RE.match(path.name)
        require(match is not None, f"bad trajectory name: {path.name}")
        iteration = int(match.group("iteration"))
        tile_i = int(match.group("tile_i"))
        tile_j = int(match.group("tile_j"))
        require(iteration in EVENTS and (tile_i, tile_j) in expected_tiles,
                f"unexpected trajectory event/tile: {path.name}")
        seen_tiles[iteration].add((tile_i, tile_j))
        records = read_records(path)
        require(records, f"empty trajectory tile: {path}")
        count = exact_integer(records[0][2], f"{path}: count")
        require(len(records) == count + 1, f"bad tile count: {path}")
        parse_meta(path.with_suffix(".meta"), len(records), iteration)
        sample, scheduled, next_time = EVENTS[iteration]
        rank, bi, bj = owner_for_tile(
            tile_i, tile_j, args.npy, args.nsx, args.nsy
        )
        expected_header = {
            0: 1, 1: 24, 3: 3, 4: 1, 5: 1, 6: 64,
            7: iteration, 8: sample, 9: scheduled, 10: next_time,
            11: args.npx, 12: args.npy,
            13: 1 + (tile_i - 1) * 4,
            14: 1 + (tile_j - 1) * 3,
            15: rank, 16: bi, 17: bj,
        }
        header = records[0]
        require(all(math.isfinite(value) for value in header),
                f"non-finite header: {path}")
        for field, expected in expected_header.items():
            require(header[field] == expected,
                    f"header field {field + 1} mismatch: {path}")
        require(all(value == 0.0 for value in header[18:]),
                f"reserved header mismatch: {path}")
        for record in records[1:]:
            require(all(math.isfinite(value) for value in record),
                    f"non-finite trajectory record: {path}")
            current_id = particle_id(record, str(path))
            require(current_id in IDS, f"unexpected ID {current_id}: {path}")
            require(record[3] == sample and record[4] == iteration,
                    f"sample/iteration mismatch: {path}")
            require(record[17] == rank and record[18] == bi and record[19] == bj,
                    f"owner mismatch: {path}")
            require(record[20] == 1.0 and all(v == 0.0 for v in record[21:]),
                    f"coordinate/reserved mismatch: {path}")
            validate_physical(
                current_id, sample, record[2], record[5], record[6],
                record[7], record[8], record[11], record[12],
                record[15], record[16], str(path),
            )
            trajectory.append((iteration, current_id, record))

    require(all(tiles == expected_tiles for tiles in seen_tiles.values()),
            "incomplete trajectory tile set")
    require(len(trajectory) == len(EVENTS) * len(IDS),
            "trajectory record count mismatch")
    require(len({(iteration, pid) for iteration, pid, _ in trajectory})
            == len(trajectory), "duplicate trajectory key")
    for iteration in EVENTS:
        require({pid for event, pid, _ in trajectory if event == iteration}
                == set(IDS), f"ID set mismatch at iteration {iteration}")
    first_cross = next(
        record for iteration, pid, record in trajectory
        if iteration == 2 and pid == IDS[0]
    )
    require(first_cross[5] > 1500.0,
            "crossing particle did not leave the west tile")
    waiting = next(
        record for iteration, pid, record in trajectory
        if iteration == 2 and pid == IDS[2]
    )
    released = next(
        record for iteration, pid, record in trajectory
        if iteration == 4 and pid == IDS[2]
    )
    require(waiting[2] == 6.0 and released[2] == 1.0,
            "WAITING-to-ALIVE transition missing")

    trajectory.sort(key=lambda item: (item[0], item[1]))
    args.trajectory_output.parent.mkdir(parents=True, exist_ok=True)
    with args.trajectory_output.open("w", encoding="ascii", newline="\n") as stream:
        stream.write("iteration\tid\trecord_hex\n")
        for iteration, pid, record in trajectory:
            stream.write(
                f"{iteration}\t{pid}\t{struct.pack('>24d', *record).hex()}\n"
            )
    with args.trajectory_invariant.open(
        "w", encoding="ascii", newline="\n"
    ) as stream:
        stream.write("iteration\tid\tinvariant_record_hex\n")
        for iteration, pid, record in trajectory:
            invariant = tuple(record[field] for field in TRAJECTORY_INVARIANT)
            stream.write(
                f"{iteration}\t{pid}\t{struct.pack('>19d', *invariant).hex()}\n"
            )

    prefix = "pickup_bom.ckptA"
    sig_path = args.run_dir / f"{prefix}.sig.data"
    signature_records = read_records(sig_path, SIG_FIELDS)
    require(len(signature_records) == 1, "pickup signature record count")
    signature = signature_records[0]
    parse_meta(sig_path.with_suffix(".meta"), 1, 8)
    expected_signature = (
        1.0, 16.0, float(args.npx), float(args.npy), 4.0, 3.0,
        float(args.nsx), float(args.nsy), 8.0, 6.0, 64.0, 3.0,
        8.0, 480.0, 120.0, 600.0,
    )
    require(signature == expected_signature, "pickup signature mismatch")

    pickup: list[tuple[int, tuple[float, ...]]] = []
    pickup_tiles: set[tuple[int, int]] = set()
    pickup_files = sorted(args.run_dir.glob(f"{prefix}.*.*.data"))
    require(len(pickup_files) == 4, "pickup tile file count mismatch")
    for path in pickup_files:
        match = re.search(r"\.(\d{3})\.(\d{3})\.data$", path.name)
        require(match is not None, f"bad pickup tile name: {path.name}")
        tile_i, tile_j = int(match.group(1)), int(match.group(2))
        require((tile_i, tile_j) in expected_tiles, f"bad pickup tile: {path}")
        pickup_tiles.add((tile_i, tile_j))
        records = read_records(path)
        count = exact_integer(records[0][2], f"{path}: count")
        require(len(records) == count + 1, f"pickup count mismatch: {path}")
        parse_meta(path.with_suffix(".meta"), len(records), 8)
        rank, bi, bj = owner_for_tile(
            tile_i, tile_j, args.npy, args.nsx, args.nsy
        )
        expected_header = {
            0: 1, 1: 24, 3: 3, 4: 1, 5: 1, 6: 64,
            7: 8, 8: 480, 9: 600, 10: 120,
            11: args.npx, 12: args.npy, 13: 4, 14: 3,
            15: args.nsx, 16: args.nsy,
            17: 1 + (tile_i - 1) * 4,
            18: 1 + (tile_j - 1) * 3,
            19: rank, 20: bi, 21: bj, 22: 64, 23: 0,
        }
        header = records[0]
        for field, expected in expected_header.items():
            require(header[field] == expected,
                    f"pickup header field {field + 1}: {path}")
        previous = 0
        for record in records[1:]:
            current_id = particle_id(record, str(path))
            require(current_id in IDS and current_id > previous,
                    f"pickup ID order/set mismatch: {path}")
            require(record[15] == rank and record[16] == bi and record[17] == bj,
                    f"pickup owner mismatch: {path}")
            require(all(value == 0.0 for value in record[18:]),
                    f"pickup reserved mismatch: {path}")
            validate_physical(
                current_id, 480.0, record[2], record[3], record[4],
                record[5], record[6], record[9], record[10],
                record[13], record[14], str(path),
            )
            pickup.append((current_id, record))
            previous = current_id
    require(pickup_tiles == expected_tiles, "incomplete pickup tile set")
    require({pid for pid, _ in pickup} == set(IDS) and len(pickup) == 3,
            "pickup global ID set mismatch")
    pickup.sort(key=lambda item: item[0])
    with args.pickup_output.open("w", encoding="ascii", newline="\n") as stream:
        stream.write(f"signature\t{struct.pack('>16d', *signature).hex()}\n")
        stream.write("id\trecord_hex\n")
        for pid, record in pickup:
            stream.write(f"{pid}\t{struct.pack('>24d', *record).hex()}\n")
    invariant_signature = (*signature[0:2], *signature[8:16])
    with args.pickup_invariant.open(
        "w", encoding="ascii", newline="\n"
    ) as stream:
        stream.write(
            f"signature\t{struct.pack('>10d', *invariant_signature).hex()}\n"
        )
        stream.write("id\tinvariant_record_hex\n")
        for pid, record in pickup:
            invariant = tuple(record[field] for field in PICKUP_INVARIANT)
            stream.write(
                f"{pid}\t{struct.pack('>19d', *invariant).hex()}\n"
            )

    print(
        "P1.5 MIGRATION VERIFY PASS: 4 events; cross-owner; "
        "WAITING release; final pickup"
    )


if __name__ == "__main__":
    main()
