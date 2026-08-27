#!/usr/bin/env python3
"""Verify and canonicalize P2.5 BOM trajectory/pickup schema 2."""

from __future__ import annotations

import argparse
import math
import re
import struct
from pathlib import Path


TRAJ_FIELDS = 48
PICKUP_FIELDS = 45
LEGACY_TRAJ_FIELDS = 24
PICKUP_DIAG_OFFSET = 18
TRAJ_DIAG_OFFSET = 21
NDIAG = 27
SCHEMA = 2
CHUNK_FIELDS = 24
ENV_HEADER = 12
NEND = 2
NSOURCE = 3
EXPECTED_IDS = {1, 4_294_967_301, 9_007_199_254_740_993}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def exact_int(value: float, label: str) -> int:
    require(math.isfinite(value), f"{label}: non-finite")
    require(value == math.trunc(value), f"{label}: non-integral {value!r}")
    return int(value)


def read_records(path: Path, fields: int) -> list[tuple[float, ...]]:
    payload = path.read_bytes()
    record_bytes = fields * 8
    require(len(payload) % record_bytes == 0,
            f"partial {fields}-field record: {path}")
    return [
        struct.unpack(f">{fields}d", payload[offset:offset + record_bytes])
        for offset in range(0, len(payload), record_bytes)
    ]


def parse_tile(path: Path) -> tuple[int, int]:
    match = re.search(r"\.(\d{3})\.(\d{3})\.data$", path.name)
    require(match is not None, f"bad tiled filename: {path.name}")
    return int(match.group(1)), int(match.group(2))


def particle_id(record: tuple[float, ...], label: str) -> int:
    high = exact_int(record[0], f"{label} ID high")
    low = exact_int(record[1], f"{label} ID low")
    require(0 <= high <= 0x7FFFFFFF and 0 <= low <= 0xFFFFFFFF,
            f"{label}: ID word out of range")
    return (high << 32) | low


def check_diag(record: tuple[float, ...], offset: int, label: str) -> None:
    diag = record[offset:offset + NDIAG]
    require(len(diag) == NDIAG, f"{label}: diagnostic length")
    require(all(math.isfinite(value) for value in diag),
            f"{label}: non-finite diagnostic")
    if offset == TRAJ_DIAG_OFFSET:
        legacy = (record[11], record[12], record[13], record[14],
                  record[15], record[16])
    else:
        legacy = (record[9], record[10], record[11], record[12],
                  record[13], record[14])
    expected = (diag[0], diag[1], diag[4], diag[5], diag[25], diag[26])
    require(legacy == expected, f"{label}: legacy/diagnostic mismatch")
    require(diag[6] == diag[0] + diag[2],
            f"{label}: sigma=0 total-current identity")
    require(diag[7] == diag[1] + diag[3],
            f"{label}: sigma=0 total-current north identity")
    require(diag[8] == diag[6] and diag[9] == diag[7],
            f"{label}: alpha=0 carrier identity")


def verify_trajectory(args: argparse.Namespace) -> None:
    prefix = f"bom_traj.{args.trajectory_suffix}"
    paths = sorted(args.run_dir.glob(f"{prefix}.[0-9][0-9][0-9]."
                                     "[0-9][0-9][0-9].data"))
    require(paths, f"missing trajectory tiles: {prefix}")
    canonical: list[tuple[int, tuple[float, ...]]] = []
    invariant: list[tuple[int, tuple[float, ...]]] = []
    for path in paths:
        records = read_records(path, TRAJ_FIELDS)
        require(records, f"empty trajectory tile: {path}")
        header = records[0]
        require(all(math.isfinite(value) for value in header),
                f"non-finite trajectory header: {path}")
        count = exact_int(header[2], f"{path}: count")
        require(len(records) == count + 1, f"count mismatch: {path}")
        require(header[0] == SCHEMA and header[1] == TRAJ_FIELDS,
                f"schema/field mismatch: {path}")
        require(tuple(exact_int(header[index], f"{path}: code")
                      for index in range(18, 24)) == (2, 1, 1, 0, 0, 4),
                f"mode/source/integrator codes: {path}")
        require(header[24:27] == (27.0, 22.0, 48.0),
                f"diagnostic descriptor mismatch: {path}")
        previous = 0
        for record in records[1:]:
            require(all(math.isfinite(value) for value in record),
                    f"non-finite trajectory record: {path}")
            pid = particle_id(record, str(path))
            require(pid > previous, f"unsorted/duplicate tile ID: {path}")
            require(pid in EXPECTED_IDS, f"unexpected ID {pid}")
            require(record[3] == args.time and
                    exact_int(record[4], "trajectory iteration") == args.iteration,
                    f"sample label mismatch for ID {pid}")
            require(record[20] == 1.0, f"inactive trajectory record: ID {pid}")
            check_diag(record, TRAJ_DIAG_OFFSET, f"trajectory ID {pid}")
            canonical.append((pid, record))
            invariant_record = record[:17] + record[20:]
            invariant.append((pid, invariant_record))
            previous = pid
    require({pid for pid, _ in canonical} == EXPECTED_IDS,
            "trajectory global ID set")
    require(len(canonical) == len(EXPECTED_IDS), "duplicate global trajectory ID")
    canonical.sort(key=lambda item: item[0])
    invariant.sort(key=lambda item: item[0])
    with args.trajectory_output.open("w", encoding="ascii", newline="\n") as stream:
        stream.write("id\trecord_hex\n")
        for pid, record in canonical:
            stream.write(f"{pid}\t{struct.pack('>48d', *record).hex()}\n")
    with args.trajectory_invariant.open("w", encoding="ascii", newline="\n") as stream:
        stream.write("id\tinvariant_hex\n")
        for pid, record in invariant:
            stream.write(f"{pid}\t{struct.pack('>45d', *record).hex()}\n")


def verify_pickup(args: argparse.Namespace) -> None:
    prefix = f"pickup_bom.{args.pickup_suffix}"
    sig_path = args.run_dir / f"{prefix}.sig.data"
    signature_records = read_records(sig_path, CHUNK_FIELDS)
    signature = tuple(value for record in signature_records for value in record)
    sig_fields = exact_int(signature[1], "signature field count")
    signature = signature[:sig_fields]
    require(signature[0] == SCHEMA, "pickup signature schema")
    require(signature[2:8] == (float(args.npx), float(args.npy),
                               float(args.snx), float(args.sny),
                               float(args.nsx), float(args.nsy)),
            "pickup decomposition signature")
    require(signature[12] == args.iteration and signature[13] == args.time,
            "pickup iteration/time signature")
    require(signature[14] == args.frequency and signature[15] == args.next_time,
            "pickup output schedule signature")
    require(signature[16:22] == (2.0, 1.0, 1.0, 0.0, 0.0, 4.0),
            "pickup mode/source/integrator signature")
    require(signature[52] == PICKUP_FIELDS,
            "pickup schema-2 particle field count")

    paths = sorted(args.run_dir.glob(f"{prefix}.[0-9][0-9][0-9]."
                                     "[0-9][0-9][0-9].data"))
    require(paths, f"missing pickup tiles: {prefix}")
    canonical: list[tuple[int, tuple[float, ...]]] = []
    invariant: list[tuple[int, tuple[float, ...]]] = []
    for path in paths:
        records = read_records(path, PICKUP_FIELDS)
        require(records, f"empty pickup tile: {path}")
        header = records[0]
        count = exact_int(header[2], f"{path}: count")
        require(len(records) == count + 1, f"pickup count mismatch: {path}")
        require(header[0] == SCHEMA and header[1] == PICKUP_FIELDS,
                f"pickup schema/field mismatch: {path}")
        require(header[23] == NDIAG, f"pickup diagnostic descriptor: {path}")
        previous = 0
        for record in records[1:]:
            require(all(math.isfinite(value) for value in record),
                    f"non-finite pickup record: {path}")
            pid = particle_id(record, str(path))
            require(pid > previous, f"unsorted/duplicate tile ID: {path}")
            require(pid in EXPECTED_IDS, f"unexpected pickup ID {pid}")
            check_diag(record, PICKUP_DIAG_OFFSET, f"pickup ID {pid}")
            canonical.append((pid, record))
            invariant_record = record[:15] + record[18:]
            invariant.append((pid, invariant_record))
            previous = pid
    require({pid for pid, _ in canonical} == EXPECTED_IDS,
            "pickup global ID set")
    require(len(canonical) == len(EXPECTED_IDS), "duplicate global pickup ID")
    canonical.sort(key=lambda item: item[0])
    invariant.sort(key=lambda item: item[0])
    with args.pickup_output.open("w", encoding="ascii", newline="\n") as stream:
        stream.write(f"signature\t{struct.pack(f'>{sig_fields}d', *signature).hex()}\n")
        stream.write("id\trecord_hex\n")
        for pid, record in canonical:
            stream.write(f"{pid}\t{struct.pack('>45d', *record).hex()}\n")
    with args.pickup_invariant.open("w", encoding="ascii", newline="\n") as stream:
        invariant_signature = signature[8:16] + signature[16:53]
        stream.write(
            f"signature\t{struct.pack(f'>{len(invariant_signature)}d', *invariant_signature).hex()}\n"
        )
        stream.write("id\tinvariant_hex\n")
        for pid, record in invariant:
            stream.write(f"{pid}\t{struct.pack('>42d', *record).hex()}\n")

    env_paths = sorted(args.run_dir.glob(f"{prefix}.env.[0-9][0-9][0-9]."
                                         "[0-9][0-9][0-9].data"))
    require(len(env_paths) == args.npx * args.npy * args.nsx * args.nsy,
            "endpoint sidecar tile count")
    env_values: list[tuple[int, int, int, int, float, float, float]] = []
    env_fields = ENV_HEADER + 3 * (args.snx + 2 * args.olx) * (args.sny + 2 * args.oly) * NEND * NSOURCE
    env_records = (env_fields + CHUNK_FIELDS - 1) // CHUNK_FIELDS
    for path in env_paths:
        records = read_records(path, CHUNK_FIELDS)
        require(len(records) == env_records, f"endpoint record count: {path}")
        flat = tuple(value for record in records for value in record)[:env_fields]
        require(all(math.isfinite(value) for value in flat),
                f"non-finite endpoint sidecar: {path}")
        require(flat[0] == SCHEMA and flat[1] == env_fields,
                f"endpoint schema/fields: {path}")
        require(flat[2] == args.iteration and flat[3] == args.time,
                f"endpoint iteration/time: {path}")
        i_global = exact_int(flat[10], "endpoint iGlobal")
        j_global = exact_int(flat[11], "endpoint jGlobal")
        index = ENV_HEADER
        for source in range(1, NSOURCE + 1):
            for endpoint in range(1, NEND + 1):
                for local_j in range(1 - args.oly, args.sny + args.oly + 1):
                    for local_i in range(1 - args.olx, args.snx + args.olx + 1):
                        east, north, valid = flat[index:index + 3]
                        index += 3
                        require(valid in (0.0, 1.0), f"endpoint validity: {path}")
                        if 1 <= local_i <= args.snx and 1 <= local_j <= args.sny:
                            env_values.append((source, endpoint,
                                               i_global + local_i - 1,
                                               j_global + local_j - 1,
                                               east, north, valid))
        require(index == env_fields, f"endpoint decode length: {path}")
    env_values.sort(key=lambda item: item[:4])
    require(len(env_values) == args.npx * args.npy * args.nsx * args.nsy *
            args.snx * args.sny * NEND * NSOURCE,
            "endpoint interior cardinality")
    with args.endpoint_invariant.open("w", encoding="ascii", newline="\n") as stream:
        stream.write("source\tendpoint\ti\tj\tvalue_hex\n")
        for source, endpoint, i_value, j_value, east, north, valid in env_values:
            packed = struct.pack(">3d", east, north, valid).hex()
            stream.write(f"{source}\t{endpoint}\t{i_value}\t{j_value}\t{packed}\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_dir", type=Path)
    parser.add_argument("--trajectory-suffix")
    parser.add_argument("--trajectory-output", type=Path)
    parser.add_argument("--trajectory-invariant", type=Path)
    parser.add_argument("--pickup-suffix")
    parser.add_argument("--pickup-output", type=Path)
    parser.add_argument("--pickup-invariant", type=Path)
    parser.add_argument("--endpoint-invariant", type=Path)
    parser.add_argument("--iteration", type=int, required=True)
    parser.add_argument("--time", type=float, required=True)
    parser.add_argument("--frequency", type=float, default=150.0)
    parser.add_argument("--next-time", type=float, default=600.0)
    parser.add_argument("--npx", type=int, default=1)
    parser.add_argument("--npy", type=int, default=1)
    parser.add_argument("--nsx", type=int, default=2)
    parser.add_argument("--nsy", type=int, default=2)
    parser.add_argument("--snx", type=int, default=4)
    parser.add_argument("--sny", type=int, default=3)
    parser.add_argument("--olx", type=int, default=2)
    parser.add_argument("--oly", type=int, default=2)
    args = parser.parse_args()

    if args.trajectory_suffix is not None:
        require(args.trajectory_output is not None and
                args.trajectory_invariant is not None,
                "trajectory output paths are required")
        verify_trajectory(args)
    if args.pickup_suffix is not None:
        require(args.pickup_output is not None and
                args.pickup_invariant is not None and
                args.endpoint_invariant is not None,
                "pickup output paths are required")
        verify_pickup(args)
    require(args.trajectory_suffix is not None or args.pickup_suffix is not None,
            "select trajectory and/or pickup verification")
    print("P2.5 SCHEMA-2 VERIFY PASS")


if __name__ == "__main__":
    main()
