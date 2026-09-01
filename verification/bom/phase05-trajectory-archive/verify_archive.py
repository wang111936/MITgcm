#!/usr/bin/env python3
"""Decode and validate the BOM continuous MDS trajectory archive."""

from __future__ import annotations

import argparse
import math
import re
import struct
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

ARCHIVE_SCHEMA = 1
ARCHIVE_WIDTH = 64
SIGNATURE_WIDTH = 24
HEADER_KIND = 1
COMMIT_KIND = 2
WORD_RADIX = 1 << 32
Record = Tuple[bytes, Tuple[float, ...]]


def fail(message: str) -> None:
    raise SystemExit(f"P5.6 ARCHIVE VERIFY FAIL: {message}")


def exact_int(value: float, label: str) -> int:
    if not math.isfinite(value) or value != math.trunc(value):
        fail(f"{label} is not an exact integer: {value!r}")
    if abs(value) > (1 << 53):
        fail(f"{label} exceeds float64 exact-integer range: {value!r}")
    return int(value)


def word_pair(high: float, low: float, label: str) -> int:
    hi = exact_int(high, f"{label}.high")
    lo = exact_int(low, f"{label}.low")
    if hi < 0 or hi > 0x7FFFFFFF or lo < 0 or lo >= WORD_RADIX:
        fail(f"invalid unsigned word pair for {label}: {hi}, {lo}")
    return hi * WORD_RADIX + lo


def meta_nrecords(path: Path) -> int:
    text = path.read_text(encoding="ascii")
    match = re.search(r"nrecords\s*=\s*\[\s*(\d+)\s*\]", text)
    if match is None:
        fail(f"missing nrecords in {path}")
    if "float64" not in text:
        fail(f"archive member is not float64: {path}")
    return int(match.group(1))


def read_records(
    path: Path,
    width: int,
    committed_records: Optional[int] = None,
    allow_tail: bool = False,
) -> Tuple[List[Record], int]:
    raw = path.read_bytes()
    record_bytes = width * 8
    if committed_records is None:
        committed_records = len(raw) // record_bytes
    required_bytes = committed_records * record_bytes
    if len(raw) < required_bytes:
        fail(
            f"committed records exceed physical data in {path}: "
            f"need {required_bytes}, found {len(raw)} bytes"
        )
    if not allow_tail and len(raw) != required_bytes:
        fail(f"partial or extra record in {path}: {len(raw)} bytes")
    records: List[Record] = []
    for offset in range(0, required_bytes, record_bytes):
        chunk = raw[offset : offset + record_bytes]
        records.append((chunk, struct.unpack(f">{width}d", chunk)))
    return records, len(raw) - required_bytes


def require_equal(actual: object, expected: object, label: str) -> None:
    if actual != expected:
        fail(f"{label}: expected {expected!r}, got {actual!r}")


def require_zero(values: Iterable[float], label: str) -> None:
    for index, value in enumerate(values, start=1):
        if value != 0.0:
            fail(f"{label}[{index}] must be zero, got {value!r}")


def require_finite(values: Iterable[float], label: str) -> None:
    for index, value in enumerate(values, start=1):
        if not math.isfinite(value):
            fail(f"{label}[{index}] is not finite: {value!r}")


def find_segment(directory: Path, prefix: str, segment_iter: Optional[int]) -> str:
    if segment_iter is not None:
        if segment_iter < 0:
            fail("segment iteration must be nonnegative")
        segment = f"{prefix}.s{segment_iter:010d}"
        if not (directory / f"{segment}.index.data").is_file():
            fail(f"archive segment not found: {segment}")
        return segment
    index_files = sorted(directory.glob(f"{prefix}.s*.index.data"))
    if len(index_files) != 1:
        fail(f"expected one archive index in {directory}, found {len(index_files)}")
    return index_files[0].name[: -len(".index.data")]


def legacy_owners(
    directory: Path,
    iteration: int,
    active_fields: int,
    has_p3: int,
    has_p4: int,
) -> Dict[Tuple[int, int], bytes]:
    suffix = f"{iteration:010d}"
    pattern = re.compile(
        rf"bom_traj\.{suffix}\.(\d{{3}})\.(\d{{3}})\.data$"
    )
    paths = sorted(
        path for path in directory.iterdir() if pattern.fullmatch(path.name)
    )
    if not paths:
        fail(f"no FRAME members for iteration {iteration} in {directory}")
    result: Dict[Tuple[int, int], bytes] = {}
    for path in paths:
        match = pattern.fullmatch(path.name)
        if match is None:
            fail(f"cannot parse FRAME tile suffix: {path.name}")
        tile_suffix = f"{match.group(1)}.{match.group(2)}"
        records, _ = read_records(path, active_fields)
        if not records:
            fail(f"empty FRAME member: {path}")
        header = records[0][1]
        count = exact_int(header[2], f"{path.name}.owner_count")
        require_equal(len(records), count + 1, f"{path.name}.record_count")
        p3_raw = [bytes(8 * 8) for _ in range(count)]
        p4_raw = [bytes(4 * 8) for _ in range(count)]
        if has_p3:
            p3_path = directory / f"bom_traj.{suffix}.p3.{tile_suffix}.data"
            p3_records, _ = read_records(p3_path, 8)
            require_equal(len(p3_records), count + 1, f"{p3_path.name}.records")
            p3_raw = [raw for raw, _ in p3_records[1:]]
        if has_p4:
            p4_path = directory / f"bom_traj.{suffix}.p4.{tile_suffix}.data"
            p4_records, _ = read_records(p4_path, 4)
            require_equal(len(p4_records), count + 3, f"{p4_path.name}.records")
            p4_raw = [raw for raw, _ in p4_records[3:]]
        for owner_index, (raw, values) in enumerate(records[1:]):
            key = (
                exact_int(values[0], f"{path.name}.id_hi"),
                exact_int(values[1], f"{path.name}.id_lo"),
            )
            if key in result:
                fail(f"duplicate FRAME owner ID at iteration {iteration}: {key}")
            result[key] = (
                raw
                + bytes((48 - active_fields) * 8)
                + p3_raw[owner_index]
                + p4_raw[owner_index]
                + bytes(4 * 8)
            )
    return result


def verify_signature_stream(
    directory: Path,
    segment: str,
    suffix: str,
    fields: int,
    records_per_frame: int,
    commits: List[Tuple[float, ...]],
    frame_dir: Optional[Path],
) -> Tuple[int, int]:
    if fields <= 0 or records_per_frame <= 0:
        fail(f"active {suffix} stream has invalid dimensions")
    if not (
        (records_per_frame - 1) * SIGNATURE_WIDTH
        < fields
        <= records_per_frame * SIGNATURE_WIDTH
    ):
        fail(f"invalid {suffix} field/chunk relation")
    data_path = directory / f"{segment}.{suffix}.data"
    meta_path = directory / f"{segment}.{suffix}.meta"
    committed = len(commits) * records_per_frame
    meta_records = meta_nrecords(meta_path)
    if meta_records < committed:
        fail(f"{suffix} meta high-water is below the index commit")
    records, extra_bytes = read_records(
        data_path,
        SIGNATURE_WIDTH,
        committed_records=committed,
        allow_tail=True,
    )
    for frame_index, commit in enumerate(commits, start=1):
        per_frame_index = 32 if suffix == "p3sig" else 34
        high_water_index = 33 if suffix == "p3sig" else 35
        declared_per_frame = exact_int(
            commit[per_frame_index], f"commit.{suffix}.records_per_frame"
        )
        declared_high_water = exact_int(
            commit[high_water_index], f"commit.{suffix}.high_water"
        )
        require_equal(declared_per_frame, records_per_frame, f"{suffix} chunk count")
        require_equal(
            declared_high_water,
            frame_index * records_per_frame,
            f"{suffix} committed high-water",
        )
        if frame_dir is not None:
            iteration = exact_int(commit[5], "index.iteration")
            legacy_path = frame_dir / f"bom_traj.{iteration:010d}.{suffix}.data"
            legacy_raw = legacy_path.read_bytes()
            begin = (frame_index - 1) * records_per_frame
            archive_raw = b"".join(
                raw for raw, _ in records[begin : begin + records_per_frame]
            )
            require_equal(archive_raw, legacy_raw, f"{suffix} FRAME equivalence")
    return meta_records - committed, extra_bytes


def verify(args: argparse.Namespace) -> None:
    directory = args.archive_dir.resolve()
    if not directory.is_dir():
        fail(f"archive directory not found: {directory}")
    segment = find_segment(directory, args.prefix, args.segment_iter)
    claim_path = directory / f"{segment}.claim"
    if not claim_path.is_file():
        fail(f"missing atomic segment claim: {claim_path}")
    if not claim_path.read_text(encoding="ascii").startswith(
        "MITGCM_BOM_ARCHIVE_CLAIM 1"
    ):
        fail(f"invalid atomic segment claim: {claim_path}")

    index_data = directory / f"{segment}.index.data"
    index_meta = directory / f"{segment}.index.meta"
    index_committed = meta_nrecords(index_meta)
    index_records, index_extra_bytes = read_records(
        index_data,
        ARCHIVE_WIDTH,
        committed_records=index_committed,
        allow_tail=True,
    )
    if len(index_records) < 2:
        fail("index has no committed frame")

    descriptor = index_records[0][1]
    require_finite(descriptor, "index descriptor")
    require_equal(exact_int(descriptor[0], "index.schema"), 1, "index schema")
    require_equal(exact_int(descriptor[1], "index.width"), 64, "index width")
    require_equal(exact_int(descriptor[2], "index.kind"), HEADER_KIND, "index kind")
    require_equal(exact_int(descriptor[3], "data.schema"), ARCHIVE_SCHEMA, "data schema")
    require_equal(exact_int(descriptor[4], "data.width"), ARCHIVE_WIDTH, "data width")
    require_equal(exact_int(descriptor[5], "data.precision"), 64, "data precision")
    niter0 = exact_int(descriptor[6], "index.nIter0")
    active_fields = exact_int(descriptor[11], "core.fields")
    if active_fields not in (24, 48):
        fail(f"unsupported active core width: {active_fields}")
    has_p3 = exact_int(descriptor[18], "has_p3")
    has_p4 = exact_int(descriptor[24], "has_p4")
    if has_p3 not in (0, 1) or has_p4 not in (0, 1):
        fail("P3/P4 descriptor flags must be zero or one")
    expected_tiles = exact_int(descriptor[37], "global_tiles")
    tile_capacity = exact_int(descriptor[38], "tile_capacity")
    npx = exact_int(descriptor[41], "nPx")
    npy = exact_int(descriptor[42], "nPy")
    nsx = exact_int(descriptor[43], "nSx")
    nsy = exact_int(descriptor[44], "nSy")
    snx = exact_int(descriptor[45], "sNx")
    sny = exact_int(descriptor[46], "sNy")
    require_equal(expected_tiles, npx * npy * nsx * nsy, "global tile product")
    if tile_capacity <= 0:
        fail(f"tile capacity must be positive, got {tile_capacity}")
    global_capacity = tile_capacity * expected_tiles
    descriptor_initial = exact_int(descriptor[39], "descriptor.initial_count")
    descriptor_live = exact_int(descriptor[40], "descriptor.live_count")
    if not (0 <= descriptor_initial <= global_capacity):
        fail("descriptor initial owner count is outside global capacity")
    if not (0 <= descriptor_live <= global_capacity):
        fail("descriptor live owner count is outside global capacity")
    signature_width = exact_int(descriptor[55], "signature width")
    require_equal(signature_width, SIGNATURE_WIDTH, "signature record width")
    p3_fields = exact_int(descriptor[56], "P3 signature fields")
    p3_records = exact_int(descriptor[57], "P3 signature records")
    p4_fields = exact_int(descriptor[58], "P4 signature fields")
    p4_records = exact_int(descriptor[59], "P4 signature records")
    require_equal(bool(p3_records), bool(has_p3), "P3 signature presence")
    require_equal(bool(p4_records), bool(has_p4), "P4 signature presence")
    if not has_p3:
        require_equal(p3_fields, 0, "inactive P3 signature fields")
    if not has_p4:
        require_equal(p4_fields, 0, "inactive P4 signature fields")
    require_zero(descriptor[60:62], "descriptor reserved 61:62")
    require_equal(exact_int(descriptor[62], "publication order"), 1, "publication marker")
    require_equal(descriptor[63], 0.0, "descriptor reserved 64")

    commits = [values for _, values in index_records[1:]]
    if args.expected_frames is not None:
        require_equal(len(commits), args.expected_frames, "committed frame count")
    for frame_index, commit in enumerate(commits, start=1):
        require_finite(commit, f"index commit {frame_index}")
        require_equal(exact_int(commit[0], "commit.schema"), 1, "commit schema")
        require_equal(exact_int(commit[1], "commit.width"), 64, "commit width")
        require_equal(exact_int(commit[2], "commit.kind"), COMMIT_KIND, "commit kind")
        require_equal(exact_int(commit[3], "commit.frame"), frame_index, "frame ordinal")
        require_equal(exact_int(commit[4], "commit.nIter0"), niter0, "commit nIter0")
        require_equal(exact_int(commit[12], "commit.tiles"), expected_tiles, "frame tiles")
        live_count = exact_int(commit[9], "commit.owner_count")
        initial_count = exact_int(commit[10], "commit.initial_count")
        require_equal(exact_int(commit[11], "commit.live_count"), live_count, "live count")
        require_equal(initial_count, descriptor_initial, "initial owner count")
        if frame_index == 1:
            require_equal(
                live_count,
                descriptor_live,
                "descriptor first-frame live owner count",
            )
        if not (0 <= live_count <= global_capacity):
            fail("live owner count is outside global capacity")
        require_equal(
            exact_int(commit[13], "commit.block_records"),
            live_count + 2 * expected_tiles,
            "global block record count",
        )
        require_equal(exact_int(commit[20], "commit.has_p3"), has_p3, "P3 flag")
        require_equal(exact_int(commit[21], "commit.has_p4"), has_p4, "P4 flag")
        require_equal(exact_int(commit[36], "commit.complete"), 1, "signature marker")
        require_equal(exact_int(commit[27], "commit.complete"), 1, "commit marker")

    tile_pattern = re.compile(
        rf"{re.escape(segment)}\.(\d{{3}})\.(\d{{3}})\.data$"
    )
    tile_paths = sorted(
        path for path in directory.iterdir() if tile_pattern.fullmatch(path.name)
    )
    require_equal(len(tile_paths), expected_tiles, "tile member count")
    segment_members = sorted(
        path for path in directory.iterdir() if path.name.startswith(segment)
    )
    expected_member_count = (
        2 * (expected_tiles + 1) + 1 + 2 * has_p3 + 2 * has_p4
    )
    require_equal(len(segment_members), expected_member_count, "segment file count")
    if args.expected_files is not None:
        require_equal(len(segment_members), args.expected_files, "requested file count")

    owners_by_frame: List[Dict[Tuple[int, int], bytes]] = [dict() for _ in commits]
    owner_totals = [0 for _ in commits]
    tile_orphan_records = 0
    tile_orphan_meta_records = 0
    tile_trailing_bytes = 0
    for tile_path in tile_paths:
        tile_match = tile_pattern.fullmatch(tile_path.name)
        if tile_match is None:
            fail(f"cannot parse archive tile suffix: {tile_path.name}")
        suffix_i = int(tile_match.group(1))
        suffix_j = int(tile_match.group(2))
        meta_path = tile_path.with_suffix(".meta")
        tile_meta_records = meta_nrecords(meta_path)
        records, trailing_bytes = read_records(
            tile_path, ARCHIVE_WIDTH, allow_tail=True
        )
        tile_trailing_bytes += trailing_bytes
        cursor = 0
        for frame_index, index_commit in enumerate(commits, start=1):
            if cursor >= len(records):
                fail(f"missing frame {frame_index} in {tile_path.name}")
            _, header = records[cursor]
            require_finite(header, f"{tile_path.name} header {frame_index}")
            require_equal(exact_int(header[0], "header.schema"), 1, "header schema")
            require_equal(exact_int(header[1], "header.width"), 64, "header width")
            require_equal(exact_int(header[2], "header.kind"), HEADER_KIND, "header kind")
            require_equal(exact_int(header[3], "header.frame"), frame_index, "header frame")
            require_equal(exact_int(header[4], "header.nIter0"), niter0, "header nIter0")
            require_equal(
                exact_int(header[5], "header.iter"),
                exact_int(index_commit[5], "index.iter"),
                "iteration",
            )
            require_equal(header[6:9], index_commit[6:9], "frame times")
            local_count = exact_int(header[9], "header.local_count")
            require_equal(
                exact_int(header[10], "header.initial_count"),
                exact_int(index_commit[10], "index.initial_count"),
                "initial count",
            )
            require_equal(
                exact_int(header[11], "header.live_count"),
                exact_int(index_commit[11], "index.live_count"),
                "live count",
            )
            require_equal(header[14:20], index_commit[14:20], "mode codes")
            require_equal(exact_int(header[20], "header.has_p3"), has_p3, "P3 flag")
            require_equal(exact_int(header[25], "header.has_p4"), has_p4, "P4 flag")
            i_origin = exact_int(header[46], "header.i_origin")
            j_origin = exact_int(header[47], "header.j_origin")
            require_equal(1 + (i_origin - 1) // snx, suffix_i, "tile i suffix")
            require_equal(1 + (j_origin - 1) // sny, suffix_j, "tile j suffix")
            previous = word_pair(header[51], header[52], "header.previous")
            start = word_pair(header[53], header[54], "header.start")
            owner_start = word_pair(header[55], header[56], "header.owner_start")
            end = word_pair(header[57], header[58], "header.end")
            require_equal(previous, cursor, "previous high-water")
            require_equal(start, cursor + 1, "block start")
            require_equal(owner_start, start + 1, "owner start")
            require_equal(end, start + local_count + 1, "block end")
            commit_position = end - 1
            if commit_position >= len(records):
                fail(f"truncated block in {tile_path.name}, frame {frame_index}")
            _, tile_commit = records[commit_position]
            require_finite(tile_commit, f"{tile_path.name} commit {frame_index}")
            require_equal(exact_int(tile_commit[2], "tile_commit.kind"), COMMIT_KIND, "tile commit kind")
            require_equal(exact_int(tile_commit[3], "tile_commit.frame"), frame_index, "tile commit frame")
            require_equal(exact_int(tile_commit[9], "tile_commit.count"), local_count, "tile commit count")
            require_equal(exact_int(tile_commit[10], "tile_commit.initial"), exact_int(index_commit[10], "index.initial"), "tile initial count")
            require_equal(exact_int(tile_commit[11], "tile_commit.live"), exact_int(index_commit[11], "index.live"), "tile live count")
            require_equal(exact_int(tile_commit[27], "tile_commit.complete"), 1, "tile commit marker")
            for raw, owner in records[cursor + 1 : cursor + 1 + local_count]:
                require_finite(owner, f"{tile_path.name} owner")
                require_equal(exact_int(owner[4], "owner.iter"), exact_int(index_commit[5], "index.iter"), "owner iteration")
                require_equal(owner[3], index_commit[6], "owner sample time")
                require_zero(owner[60:64], "owner reserved")
                if not has_p3:
                    require_zero(owner[48:56], "inactive P3")
                else:
                    require_equal(owner[48:50], owner[0:2], "P3 owner ID")
                if not has_p4:
                    require_zero(owner[56:60], "inactive P4")
                key = (
                    exact_int(owner[0], "owner.id_hi"),
                    exact_int(owner[1], "owner.id_lo"),
                )
                if key in owners_by_frame[frame_index - 1]:
                    fail(f"duplicate archive owner ID in frame {frame_index}: {key}")
                owners_by_frame[frame_index - 1][key] = raw
                owner_totals[frame_index - 1] += 1
            cursor = end
        if tile_meta_records < cursor:
            fail(f"{tile_path.name} meta high-water is below the index commit")
        tile_orphan_records += len(records) - cursor
        tile_orphan_meta_records += tile_meta_records - cursor

    for frame_index, (commit, total) in enumerate(
        zip(commits, owner_totals), start=1
    ):
        require_equal(
            total,
            exact_int(commit[9], "index owners"),
            f"frame {frame_index} owner total",
        )

    signature_orphan_meta = 0
    signature_extra_bytes = 0
    frame_dir = args.frame_dir.resolve() if args.frame_dir is not None else None
    if has_p3:
        orphan_meta, extra_bytes = verify_signature_stream(
            directory,
            segment,
            "p3sig",
            p3_fields,
            p3_records,
            commits,
            frame_dir,
        )
        signature_orphan_meta += orphan_meta
        signature_extra_bytes += extra_bytes
    if has_p4:
        orphan_meta, extra_bytes = verify_signature_stream(
            directory,
            segment,
            "p4sig",
            p4_fields,
            p4_records,
            commits,
            frame_dir,
        )
        signature_orphan_meta += orphan_meta
        signature_extra_bytes += extra_bytes

    if frame_dir is not None:
        for frame_index, commit in enumerate(commits, start=1):
            iteration = exact_int(commit[5], "index.iteration")
            legacy = legacy_owners(
                frame_dir, iteration, active_fields, has_p3, has_p4
            )
            archive = owners_by_frame[frame_index - 1]
            require_equal(set(archive), set(legacy), f"frame {frame_index} ID set")
            for key in sorted(archive):
                if archive[key] != legacy[key]:
                    fail(f"FRAME/ARCHIVE owner mismatch frame={frame_index} id={key}")

    orphan_total = (
        index_extra_bytes
        + tile_orphan_records * ARCHIVE_WIDTH * 8
        + tile_orphan_meta_records * ARCHIVE_WIDTH * 8
        + tile_trailing_bytes
        + signature_orphan_meta * SIGNATURE_WIDTH * 8
        + signature_extra_bytes
    )
    if args.require_no_orphans and orphan_total:
        fail(f"unexpected orphan tail evidence: score={orphan_total}")

    print(
        "P5.6 ARCHIVE VERIFY PASS "
        f"segment={segment} frames={len(commits)} tiles={len(tile_paths)} "
        f"files={len(segment_members)} owners={owner_totals} "
        f"orphan_score={orphan_total}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive_dir", type=Path)
    parser.add_argument("--frame-dir", type=Path)
    parser.add_argument("--expected-frames", type=int)
    parser.add_argument("--expected-files", type=int)
    parser.add_argument("--prefix", default="bom_trajectories")
    parser.add_argument("--segment-iter", type=int)
    parser.add_argument("--require-no-orphans", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    verify(parse_args())
