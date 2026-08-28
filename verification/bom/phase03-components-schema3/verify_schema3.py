#!/usr/bin/env python3
"""Validate P3.4 schema-3 files and continuous/restart bitwise identity."""

from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path


def read_f64(path: Path) -> list[float]:
    raw = path.read_bytes()
    if len(raw) % 8:
        raise AssertionError(f"unaligned float64 file: {path}")
    return list(struct.unpack(f">{len(raw) // 8}d", raw))


def exact_int(value: float, label: str) -> int:
    if not math.isfinite(value) or value != round(value):
        raise AssertionError(f"non-integral {label}: {value!r}")
    return int(value)


def exact_id(hi: float, lo: float, label: str) -> int:
    hi_i = exact_int(hi, f"{label}.hi")
    lo_i = exact_int(lo, f"{label}.lo")
    if hi_i < 0 or lo_i < 0 or lo_i >= 2**32:
        raise AssertionError(f"invalid exact ID words for {label}")
    return hi_i * 2**32 + lo_i


def tile_files(root: Path, prefix: str) -> list[Path]:
    files = sorted(root.glob(f"{prefix}.[0-9][0-9][0-9].[0-9][0-9][0-9].data"))
    if not files:
        raise AssertionError(f"no tiled files for {prefix} in {root}")
    return files


def validate_tiled_pair(
    root: Path,
    core_prefix: str,
    side_prefix: str,
    core_width: int,
    iteration: int,
    sample_time: float,
    scheduled_time: float,
    next_time: float,
) -> None:
    cores = tile_files(root, core_prefix)
    sides = tile_files(root, side_prefix)
    if len(cores) != len(sides):
        raise AssertionError("core/sidecar tile count mismatch")
    for core_path in cores:
        tile = core_path.name.removeprefix(f"{core_prefix}.")
        side_path = root / f"{side_prefix}.{tile}"
        if side_path not in sides:
            raise AssertionError(f"missing sidecar tile {side_path.name}")
        for data_path in (core_path, side_path):
            meta_path = data_path.with_suffix(".meta")
            if not meta_path.is_file():
                raise AssertionError(f"missing metadata {meta_path}")
        core = read_f64(core_path)
        side = read_f64(side_path)
        if len(core) % core_width or len(side) % 8:
            raise AssertionError(f"record width mismatch in tile {tile}")
        core_records = [core[i : i + core_width] for i in range(0, len(core), core_width)]
        side_records = [side[i : i + 8] for i in range(0, len(side), 8)]
        core_header = core_records[0]
        side_header = side_records[0]
        count = exact_int(core_header[2], "core.count")
        if exact_int(core_header[0], "core.schema") != 2:
            raise AssertionError("schema-2 core changed")
        if exact_int(core_header[1], "core.width") != core_width:
            raise AssertionError("core field width changed")
        if len(core_records) != count + 1 or len(side_records) != count + 1:
            raise AssertionError("header/physical record count mismatch")
        expected_side = [1, 8, 3, count, iteration]
        if [exact_int(v, "side.header") for v in side_header[:5]] != expected_side:
            raise AssertionError("invalid schema-3 sidecar header")
        if side_header[5:] != [sample_time, scheduled_time, next_time]:
            raise AssertionError("sidecar time/schedule mismatch")
        if core_width == 48:
            if core_header[7:11] != [iteration, sample_time, scheduled_time, next_time]:
                raise AssertionError("trajectory core time/schedule mismatch")
        else:
            if core_header[7:10] != [iteration, sample_time, next_time]:
                raise AssertionError("pickup core time/schedule mismatch")
        for index, (core_record, side_record) in enumerate(
            zip(core_records[1:], side_records[1:]), start=1
        ):
            particle_id = exact_id(core_record[0], core_record[1], f"core[{index}]")
            side_id = exact_id(side_record[0], side_record[1], f"side[{index}]")
            raft_id = exact_id(side_record[2], side_record[3], f"raft[{index}]")
            neighbor = exact_int(side_record[4], "neighbor")
            raft_size = exact_int(side_record[5], "raft_size")
            if side_id != particle_id:
                raise AssertionError("core/sidecar exact-ID order mismatch")
            if not (0 < raft_id <= particle_id and 0 <= neighbor and raft_size >= 1):
                raise AssertionError("invalid component invariant")
            if not all(math.isfinite(v) for v in side_record[6:8]):
                raise AssertionError("non-finite spring diagnostic")


def validate_signature(root: Path, pickup_prefix: str) -> None:
    p2 = read_f64(root / f"{pickup_prefix}.sig.data")
    p3 = read_f64(root / f"{pickup_prefix}.p3sig.data")
    p3_fields = exact_int(p3[1], "p3sig.fields")
    p2_fields = exact_int(p3[42], "p3sig.p2_fields")
    p2_start = exact_int(p3[43], "p3sig.p2_start")
    if p3[:4] != [3.0, float(p3_fields), 1.0, 8.0]:
        raise AssertionError("invalid P3 signature header")
    if p3_fields != 44 + p2_fields or p2_start != 45:
        raise AssertionError("invalid P2 embedding metadata")
    if p3[44:p3_fields] != p2[:p2_fields]:
        raise AssertionError("embedded P2 fingerprint changed")


def normalized_members(root: Path, prefix: str) -> dict[str, bytes]:
    members: dict[str, bytes] = {}
    for path in sorted(root.glob(f"{prefix}*")):
        if path.is_file():
            members[path.name.removeprefix(prefix)] = path.read_bytes()
    if not members:
        raise AssertionError(f"no members for {prefix}")
    return members


def write_canonical_sidecar(root: Path, output: Path) -> None:
    records: list[list[float]] = []
    for path in tile_files(root, "bom_traj.0000000002.p3"):
        values = read_f64(path)
        if len(values) % 8:
            raise AssertionError(f"invalid final sidecar width: {path}")
        records.extend(values[index : index + 8] for index in range(8, len(values), 8))
    records.sort(key=lambda record: exact_id(record[0], record[1], "canonical"))
    output.write_bytes(b"".join(struct.pack(">8d", *record) for record in records))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("initial", type=Path)
    parser.add_argument("restart", type=Path)
    parser.add_argument("--canonical-out", type=Path)
    args = parser.parse_args()
    validate_tiled_pair(
        args.initial,
        "bom_traj.0000000001",
        "bom_traj.0000000001.p3",
        48,
        1,
        100.0,
        100.0,
        200.0,
    )
    validate_tiled_pair(
        args.initial,
        "pickup_bom.p34schema3",
        "pickup_bom.p34schema3.p3",
        45,
        1,
        100.0,
        100.0,
        200.0,
    )
    validate_signature(args.initial, "pickup_bom.p34schema3")
    continuous = normalized_members(args.initial, "pickup_bom.p34cont")
    split = normalized_members(args.restart, "pickup_bom.p34split")
    if continuous != split:
        differing = sorted(set(continuous) ^ set(split) | {
            key for key in continuous.keys() & split.keys() if continuous[key] != split[key]
        })
        raise AssertionError(f"continuous/split pickup mismatch: {differing}")
    traj_cont = normalized_members(args.initial, "bom_traj.0000000002")
    traj_split = normalized_members(args.restart, "bom_traj.0000000002")
    if traj_cont != traj_split:
        raise AssertionError("continuous/split trajectory mismatch")
    if args.canonical_out is not None:
        write_canonical_sidecar(args.initial, args.canonical_out)
    print("P3_SCHEMA3_VERIFY_PASS")


if __name__ == "__main__":
    main()
