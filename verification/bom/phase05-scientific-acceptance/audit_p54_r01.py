#!/usr/bin/env python3
"""Independent continuous/split and decomposition audit for P5-R01."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
from pathlib import Path


LAYOUTS = ("serial", "mpi2", "mpi4")
TILES = ((1, 1), (1, 2), (2, 1), (2, 2))
CASEJ_IDS = (1001, 1002, 1003)
F_IDS = (3001, 3003)
FATAL = re.compile(r"ABNORMAL END|ALL_PROC_DIE|Fortran runtime error|\bNaN\b|Infinity", re.I)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def exact_int(value: float, label: str) -> int:
    require(math.isfinite(value) and value == math.trunc(value), f"{label}: exact integer")
    return int(value)


def read_records(path: Path, fields: int) -> list[tuple[float, ...]]:
    payload = path.read_bytes()
    width = fields * 8
    require(payload and len(payload) % width == 0, f"record width {path}")
    return [struct.unpack(f">{fields}d", payload[index:index + width])
            for index in range(0, len(payload), width)]


def words_id(high: int, low: int) -> int:
    require(0 <= high <= 0x7FFFFFFF and 0 <= low <= 0xFFFFFFFF, "ID words")
    return (high << 32) | low


def record_id(record: tuple[float, ...]) -> int:
    return words_id(exact_int(record[0], "ID high"), exact_int(record[1], "ID low"))


def check_positive_logs(root: Path) -> int:
    count = 0
    for case in ("casej", "combined"):
        for layout in LAYOUTS:
            for segment in ("continuous", "part1", "part2"):
                path = root / f"{case}-{layout}-{segment}" / "combined.log"
                text = path.read_text(encoding="ascii", errors="replace")
                require("PROGRAM MAIN: Execution ended Normally" in text,
                        f"normal end missing {path}")
                require(FATAL.search(text) is None, f"fatal marker {path}")
                count += 1
    return count


def selected_files(root: Path, predicate) -> dict[str, Path]:
    return {path.name: path for path in root.iterdir() if path.is_file() and predicate(path.name)}


def compare_files(left: Path, right: Path, predicate, label: str) -> int:
    a, b = selected_files(left, predicate), selected_files(right, predicate)
    require(set(a) == set(b) and a, f"{label}: filename inventory")
    for name in a:
        require(a[name].read_bytes() == b[name].read_bytes(), f"{label}: byte difference {name}")
    return len(a)


def audit_split_identity(root: Path) -> int:
    comparisons = 0
    trajectory_pattern = re.compile(r"^bom_traj\.(\d{10}).*\.(?:data|meta)$")
    for layout in LAYOUTS:
        continuous = root / f"casej-{layout}-continuous"
        split = root / f"casej-{layout}-part2"
        comparisons += compare_files(
            continuous, split,
            lambda name: bool(trajectory_pattern.match(name)) and
            int(trajectory_pattern.match(name).group(1)) >= 49,
            f"Case J subsequent trajectory {layout}",
        )
        comparisons += compare_files(
            continuous, split,
            lambda name: name.startswith("pickup.0000000096") or
            name.startswith("pickup_bom.0000000096"),
            f"Case J final pickup {layout}",
        )

        continuous = root / f"combined-{layout}-continuous"
        split = root / f"combined-{layout}-part2"
        comparisons += compare_files(
            continuous, split,
            lambda name: name.startswith("bom_traj.0000000002"),
            f"F combined subsequent trajectory {layout}",
        )
        comparisons += compare_files(
            continuous, split,
            lambda name: name.startswith("pickup.0000000002") or
            name.startswith("pickup_bom.0000000002"),
            f"F combined final pickup {layout}",
        )
        comparisons += compare_files(
            continuous, split, lambda name: name.startswith("p54_events"),
            f"F combined final event stream {layout}",
        )
    return comparisons


def core_path(root: Path, prefix: str, tile: tuple[int, int]) -> Path:
    return root / f"{prefix}.{tile[0]:03d}.{tile[1]:03d}.data"


def sidecar_path(root: Path, prefix: str, kind: str, tile: tuple[int, int]) -> Path:
    return root / f"{prefix}.{kind}.{tile[0]:03d}.{tile[1]:03d}.data"


def decode_owners(root: Path, prefix: str, p3: bool, p4: bool) -> dict[int, dict[str, object]]:
    owners: dict[int, dict[str, object]] = {}
    for tile in TILES:
        path = core_path(root, prefix, tile)
        records = read_records(path, 48)
        count = exact_int(records[0][2], "core local count")
        require(records[0][:2] == (2.0, 48.0) and len(records) == count + 1,
                f"core framing {path}")
        p3_records = read_records(sidecar_path(root, prefix, "p3", tile), 8) if p3 else []
        p4_records = read_records(sidecar_path(root, prefix, "p4", tile), 4) if p4 else []
        if p3:
            require(p3_records[0][:4] == (1.0, 8.0, 3.0, float(count)) and
                    len(p3_records) == count + 1, f"P3 framing {path}")
        if p4:
            require(p4_records[0] == (1.0, 4.0, 4.0, float(count)) and
                    len(p4_records) == count + 3, f"P4 framing {path}")
        for index, record in enumerate(records[1:], 1):
            require(all(math.isfinite(value) for value in record), f"finite owner {path}")
            pid = record_id(record)
            require(pid not in owners, f"duplicate owner ID {pid}")
            item: dict[str, object] = {"core": record, "status": exact_int(record[2], "status")}
            if p3:
                row = p3_records[index]
                require(record_id(row) == pid, "P3/core ID alignment")
                item["p3"] = row
            if p4:
                row = p4_records[index + 2]
                item["parent"] = words_id(exact_int(row[0], "parent high"),
                                           exact_int(row[1], "parent low"))
                item["amount"] = row[2]
                item["birth_count"] = exact_int(row[3], "birth count")
            owners[pid] = item
    return owners


def compare_owner_maps(reference: dict[int, dict[str, object]],
                       candidate: dict[int, dict[str, object]], path_m: dict[int, float],
                       label: str, p4: bool) -> None:
    require(set(reference) == set(candidate), f"{label}: owner IDs")
    for pid in reference:
        a = reference[pid]["core"]
        b = candidate[pid]["core"]
        require(isinstance(a, tuple) and isinstance(b, tuple), "core tuple")
        # The frozen cross-decomposition contract makes the canonical identity,
        # lifecycle clock and active-record marker exact.  Local fractional
        # indices and the 27 floating diagnostics legitimately reflect the
        # decomposition-specific interpolation path and are not exact fields.
        exact_indices = (0, 1, 2, 3, 4, 7, 8, 20)
        require(all(a[index] == b[index] for index in exact_indices),
                f"{label}: exact identity/lifecycle state ID {pid}")
        error = math.hypot(a[5] - b[5], a[6] - b[6])
        bound = max(1.0e-6, 5.0e-11 * max(path_m[pid], 1.0))
        require(error <= bound, f"{label}: coordinate ID {pid} error={error} bound={bound}")
        if p4:
            for key in ("parent", "birth_count"):
                require(reference[pid][key] == candidate[pid][key], f"{label}: {key} ID {pid}")
            amount_a = reference[pid]["amount"]
            amount_b = candidate[pid]["amount"]
            require(math.isclose(amount_a, amount_b, rel_tol=5.0e-11, abs_tol=1.0e-12),
                    f"{label}: biological amount ID {pid}")


def casej_paths(root: Path) -> dict[int, float]:
    initial_records = read_records(root / "casej-serial-continuous" / "bom_particles.data", 8)
    previous = {record_id(record): (record[2], record[3]) for record in initial_records[1:]}
    paths = {pid: 0.0 for pid in CASEJ_IDS}
    for iteration in range(1, 97):
        owners = decode_owners(root / "casej-serial-continuous",
                               f"bom_traj.{iteration:010d}", False, False)
        require(tuple(sorted(owners)) == CASEJ_IDS, "Case J serial ID inventory")
        for pid in CASEJ_IDS:
            core = owners[pid]["core"]
            current = (core[5], core[6])
            paths[pid] += math.hypot(current[0] - previous[pid][0], current[1] - previous[pid][1])
            previous[pid] = current
    return paths


def decode_events(root: Path, ranks: int) -> list[tuple[int, ...]]:
    manifests = sorted(root.glob("p54_events.r[0-9][0-9][0-9][0-9][0-9][0-9].manifest"))
    require(len(manifests) == ranks, f"event manifest rank count {root}")
    rows: list[tuple[int, ...]] = []
    for manifest in manifests:
        lines = manifest.read_text(encoding="ascii").splitlines()
        require(lines[0] == "MITGCM_BOM_EVENT_MANIFEST 1" and lines[-1] == "complete 1",
                f"event manifest framing {manifest}")
        shard = root / lines[11].split()[1]
        payload = shard.read_bytes()
        require(shard.stat().st_size == int(lines[9].split()[1]) and
                hashlib.sha256(payload).hexdigest() == lines[10].split()[1],
                f"event size/SHA {manifest}")
        shard_lines = payload.decode("ascii").splitlines()
        require(shard_lines[:1] == ["MITGCM_BOM_EVENT_SHARD 1 32"],
                f"event shard header {shard}")
        local_rows: list[tuple[int, ...]] = []
        for line in shard_lines[1:]:
            fields = line.split()
            require(len(fields) == 32 and
                    all(re.fullmatch(r"[0-9A-F]{16}", word) for word in fields),
                    f"event record framing {shard}")
            local_rows.append(tuple(int(word, 16) for word in fields))
        require(len(local_rows) == int(lines[5].split()[1]),
                f"event record count {shard}")
        rows.extend(local_rows)
    rows.sort(key=lambda row: (row[2], row[3], row[1], row[7], row[8]))
    return rows


def audit_decomposition(root: Path) -> tuple[int, int]:
    paths = casej_paths(root)
    owner_comparisons = 0
    for iteration in range(1, 97):
        reference = decode_owners(root / "casej-serial-continuous",
                                  f"bom_traj.{iteration:010d}", False, False)
        for layout in ("mpi2", "mpi4"):
            candidate = decode_owners(root / f"casej-{layout}-continuous",
                                      f"bom_traj.{iteration:010d}", False, False)
            compare_owner_maps(reference, candidate, paths, f"Case J {layout} iter={iteration}", False)
            owner_comparisons += len(reference)

    reference = decode_owners(root / "combined-serial-continuous", "bom_traj.0000000002",
                              True, True)
    require(tuple(sorted(reference)) == F_IDS, "combined final ID set")
    require(reference[3001]["parent"] == 0 and reference[3003]["parent"] == 3001,
            "combined parent graph")
    require(reference[3001]["birth_count"] == 1 and reference[3003]["birth_count"] == 0,
            "combined birth counters")
    f_paths = {pid: 400.0 for pid in F_IDS}
    for layout in ("mpi2", "mpi4"):
        candidate = decode_owners(root / f"combined-{layout}-continuous",
                                  "bom_traj.0000000002", True, True)
        compare_owner_maps(reference, candidate, f_paths, f"combined {layout}", True)
        owner_comparisons += len(reference)

    reference_events = decode_events(root / "combined-serial-continuous", 1)
    require(len(reference_events) == 2 and sorted(row[1] for row in reference_events) == [1, 2],
            "combined exact birth/death events")
    for layout, ranks in (("mpi2", 2), ("mpi4", 4)):
        candidate_events = decode_events(root / f"combined-{layout}-continuous", ranks)
        require(len(candidate_events) == len(reference_events), f"{layout}: event count")
        for a, b in zip(reference_events, candidate_events):
            require(a[:24] + a[30:] == b[:24] + b[30:], f"{layout}: canonical event decision")
    return owner_comparisons, len(reference_events)


def audit_negatives(root: Path) -> int:
    for case, suffix in (("casej", "0000000049"), ("combined", "0000000002")):
        directory = root / f"negative-{case}-serial-to-mpi2"
        text = (directory / "combined.log").read_text(encoding="ascii", errors="replace")
        require("PROGRAM MAIN: Execution ended Normally" not in text, f"negative accepted {case}")
        require(re.search(r"decomposition|schema-2|schema-4|signature", text, re.I) is not None,
                f"negative reason {case}")
        require(re.search(r"ABNORMAL END|ALL_PROC_DIE", text) is not None, f"negative fatal {case}")
        require("BOM_READ_PICKUP: complete" not in text, f"negative owner publication {case}")
        require(not list(directory.glob(f"bom_traj.{suffix}*")), f"negative trajectory publication {case}")
    return 2


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    manifest = json.loads((root / "expected.json").read_text(encoding="ascii"))
    require(manifest["schema"] == "MITGCM-BOM-P5-R01-input-v1", "input manifest schema")
    positive_runs = check_positive_logs(root)
    exact_files = audit_split_identity(root)
    owner_comparisons, events = audit_decomposition(root)
    negative_runs = audit_negatives(root)
    report = {
        "schema": "MITGCM-BOM-P5-R01-audit-v1", "result": "PASS",
        "positive_runs": positive_runs, "changed_decomposition_rejections": negative_runs,
        "within_layout_exact_files": exact_files,
        "cross_layout_owner_comparisons": owner_comparisons,
        "canonical_combined_events": events,
    }
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print(f"P5-R01 AUDIT PASS positive={positive_runs} exact_files={exact_files} "
          f"owners={owner_comparisons} negatives={negative_runs}")


if __name__ == "__main__":
    main()
