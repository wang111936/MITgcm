#!/usr/bin/env python3
"""Independent P5-L01 30-day endurance and restart auditor."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
from pathlib import Path


TILES = ((1, 1), (2, 1), (1, 2), (2, 2))
IDS = (1001, 1002, 1003)
DT_S = 3600
NSTEPS = 720
SPLIT = 360


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def exact_int(value: float, label: str) -> int:
    require(math.isfinite(value) and value == round(value), f"non-integral {label}")
    return int(value)


def words_id(high: int, low: int) -> int:
    return high * (1 << 32) + low


def record_id(record: tuple[float, ...]) -> int:
    return words_id(exact_int(record[0], "ID high"), exact_int(record[1], "ID low"))


def read_records(path: Path, width: int) -> list[tuple[float, ...]]:
    payload = path.read_bytes()
    require(len(payload) % (width * 8) == 0, f"record width {path}")
    return [struct.unpack(f">{width}d", payload[offset:offset + width * 8])
            for offset in range(0, len(payload), width * 8)]


def core_path(root: Path, prefix: str, tile: tuple[int, int]) -> Path:
    return root / f"{prefix}.{tile[0]:03d}.{tile[1]:03d}.data"


def sidecar_path(root: Path, prefix: str, tile: tuple[int, int]) -> Path:
    return root / f"{prefix}.p4.{tile[0]:03d}.{tile[1]:03d}.data"


def decode_owners(root: Path, prefix: str, core_width: int) -> dict[int, dict[str, object]]:
    owners: dict[int, dict[str, object]] = {}
    live_count: int | None = None
    for tile in TILES:
        core_rows = read_records(core_path(root, prefix, tile), core_width)
        local = exact_int(core_rows[0][2], "local count")
        require(core_rows[0][0:2] == (2.0, float(core_width)) and len(core_rows) == local + 1,
                f"core framing {prefix}/{tile}")
        p4_rows = read_records(sidecar_path(root, prefix, tile), 4)
        require(p4_rows[0] == (1.0, 4.0, 4.0, float(local)) and len(p4_rows) == local + 3,
                f"P4 framing {prefix}/{tile}")
        this_live = exact_int(p4_rows[2][3], "live count")
        live_count = this_live if live_count is None else live_count
        require(live_count == this_live, f"live-count agreement {prefix}")
        for index, core in enumerate(core_rows[1:], 1):
            require(all(math.isfinite(value) for value in core), f"finite core {prefix}/{tile}")
            pid = record_id(core)
            require(pid not in owners, f"duplicate ID {pid} in {prefix}")
            p4 = p4_rows[index + 2]
            require(all(math.isfinite(value) for value in p4), f"finite P4 {prefix}/{tile}")
            owners[pid] = {
                "core": core,
                "status": exact_int(core[2], "status"),
                "x": core[5] if core_width == 48 else core[3],
                "y": core[6] if core_width == 48 else core[4],
                "parent": words_id(exact_int(p4[0], "parent high"),
                                   exact_int(p4[1], "parent low")),
                "amount": p4[2],
                "birth_count": exact_int(p4[3], "birth count"),
            }
    require(live_count == len(owners) == 3, f"live/owner budget {prefix}")
    return owners


def parse_p4_manifest(path: Path, expected_members: int) -> int:
    lines = path.read_text(encoding="ascii").splitlines()
    require(lines[:1] == ["MITGCM_BOM_P4_MANIFEST 1"] and lines[-1:] == ["complete 1"],
            f"manifest framing {path}")
    declared = int(next(line for line in lines if line.startswith("member_count ")).split()[1])
    require(declared == expected_members, f"manifest member count {path}")
    members = [line for line in lines if line.startswith("MEMBER ")]
    require(len(members) == declared, f"manifest member inventory {path}")
    for ordinal, line in enumerate(members, 1):
        fields = line.split(maxsplit=4)
        require(int(fields[1]) == ordinal, f"manifest member order {path}")
        member = path.parent / fields[4]
        require(member.is_file() and member.stat().st_size == int(fields[2]) and
                sha256(member) == fields[3], f"manifest member size/SHA {member}")
    return declared


def parse_signature(path: Path) -> tuple[float, ...]:
    payload = path.read_bytes()
    require(len(payload) % 8 == 0, f"signature framing {path}")
    values = struct.unpack(f">{len(payload) // 8}d", payload)
    require(len(values) >= 80 and all(math.isfinite(value) for value in values),
            f"finite signature {path}")
    return values


def budget_word(signature: tuple[float, ...], one_based_high: int) -> int:
    return words_id(exact_int(signature[one_based_high - 1], "budget high"),
                    exact_int(signature[one_based_high], "budget low"))


def scheduled_files(root: Path, first: int, last: int) -> dict[str, Path]:
    result: dict[str, Path] = {}
    pattern = re.compile(r"^(?:bom_traj|pickup(?:_bom)?)\.(\d{10})")
    for path in root.iterdir():
        if not path.is_file() or path.is_symlink():
            continue
        match = pattern.match(path.name)
        if match and first <= int(match.group(1)) <= last:
            result[path.name] = path
    return result


def compare_scheduled(reference: Path, candidate: Path, first: int, last: int,
                      label: str) -> int:
    left = scheduled_files(reference, first, last)
    right = scheduled_files(candidate, first, last)
    require(set(left) == set(right) and left, f"{label}: scheduled inventory")
    for name in left:
        require(left[name].stat().st_size == right[name].stat().st_size and
                sha256(left[name]) == sha256(right[name]), f"{label}: byte mismatch {name}")
    return len(left)


def audit_input_hashes(root: Path, expected: dict[str, object]) -> int:
    count = 0
    hashes = expected["case_input_sha256"]
    require(isinstance(hashes, dict), "input hash object")
    for case in ("continuous", "part1", "part2"):
        entries = hashes[case]
        require(isinstance(entries, dict), f"input hashes {case}")
        for name, digest in entries.items():
            path = root / case / name
            require(path.is_file() and sha256(path) == digest, f"input hash {case}/{name}")
            count += 1
    return count


def audit_logs_and_timers(root: Path) -> tuple[dict[str, list[float]], int]:
    expected_steps = {"continuous": 720, "part1": 360, "part2": 360}
    timer_pattern = re.compile(
        r'Seconds in section "BOM\s+\[FORWARD_STEP\]":.*?'
        r'Wall clock time:\s*([0-9.Ee+\-]+).*?No\. starts:\s*(\d+).*?'
        r'No\. stops:\s*(\d+)', re.S)
    timers: dict[str, list[float]] = {}
    calls = 0
    for case, steps in expected_steps.items():
        text = (root / case / "combined.log").read_text(encoding="ascii", errors="replace")
        require("PROGRAM MAIN: Execution ended Normally" in text, f"normal end {case}")
        forbidden = ("ABNORMAL END", "ALL_PROC_DIE", "Fortran runtime error",
                     "particle failure", "event failure")
        require(not any(marker in text for marker in forbidden), f"fatal marker {case}")
        matches = timer_pattern.findall(text)
        require(len(matches) == 4, f"four rank BOM timers {case}")
        timers[case] = []
        for wall, starts, stops in matches:
            require(int(starts) == int(stops) == steps, f"BOM timer calls {case}")
            timers[case].append(float(wall))
            calls += int(starts)
    return timers, calls


def audit_trajectory(root: Path) -> tuple[int, int, dict[int, float]]:
    previous: dict[int, tuple[float, float]] = {}
    paths = {pid: 0.0 for pid in IDS}
    particle_rows = 0
    for iteration in range(1, NSTEPS + 1):
        prefix = f"bom_traj.{iteration:010d}"
        owners = decode_owners(root / "continuous", prefix, 48)
        require(tuple(sorted(owners)) == IDS, f"trajectory IDs {iteration}")
        for pid in IDS:
            owner = owners[pid]
            core = owner["core"]
            require(owner["status"] == 1 and core[3] == iteration * DT_S and
                    core[4] == iteration, f"trajectory lifecycle {iteration}/{pid}")
            require(owner["parent"] == 0 and owner["amount"] == 1.0 and
                    owner["birth_count"] == 0, f"trajectory P4 state {iteration}/{pid}")
            position = (float(owner["x"]), float(owner["y"]))
            require(0.0 < position[0] < 400_000.0 and 0.0 < position[1] < 300_000.0,
                    f"trajectory domain {iteration}/{pid}")
            if pid in previous:
                paths[pid] += math.hypot(position[0] - previous[pid][0],
                                         position[1] - previous[pid][1])
            previous[pid] = position
            particle_rows += 1
        parse_p4_manifest(root / "continuous" / f"{prefix}.p4manifest", 18)
    require(all(distance > 100.0 for distance in paths.values()), "nontrivial periodic motion")
    return NSTEPS, particle_rows, paths


def audit_daily_pickups(root: Path) -> tuple[int, int, float]:
    free_slots: list[int] = []
    manifest_counts: list[int] = []
    max_mass_error = 0.0
    for day in range(1, 31):
        iteration = day * 24
        prefix = f"pickup_bom.{iteration:010d}"
        owners = decode_owners(root / "continuous", prefix, 45)
        require(tuple(sorted(owners)) == IDS, f"pickup IDs day {day}")
        total_mass = 0.0
        for pid in IDS:
            owner = owners[pid]
            require(owner["status"] == 1 and owner["parent"] == 0 and
                    owner["birth_count"] == 0 and owner["amount"] == 1.0,
                    f"pickup state day {day}/{pid}")
            total_mass += float(owner["amount"])
        max_mass_error = max(max_mass_error, abs(total_mass - 3.0))
        signature = parse_signature(root / "continuous" / f"{prefix}.p4sig.data")
        require(signature[0] == 4.0 and signature[2] == 2.0 and signature[8] == 1.0,
                f"pickup schema day {day}")
        require(signature[21] == iteration and signature[22] == iteration * DT_S and
                signature[23] == iteration * DT_S, f"pickup time day {day}")
        require(signature[25:29] == (3.0, 3.0, 20260831.0, 4.0),
                f"pickup owner/seed budget day {day}")
        require(budget_word(signature, 30) == 1004 and
                budget_word(signature, 32) == iteration, f"pickup ID/event index day {day}")
        require(all(budget_word(signature, field) == 0 for field in (34, 36, 38, 40, 42, 44)),
                f"zero event budgets day {day}")
        free_slots.append(exact_int(signature[45], "free slots"))
        require(signature[46] == 0.0 and signature[52:56] == (1.0, 1.0, 1.0, 1.0) and
                signature[65:68] == (0.0, 0.0, 1.0) and signature[79] == 1.0,
                f"P4 readiness/rates/buffer day {day}")
        manifest_counts.append(parse_p4_manifest(
            root / "continuous" / f"{prefix}.p4manifest", 36))
        for tile in TILES:
            bio = root / "continuous" / f"{prefix}.p4bio.{tile[0]:03d}.{tile[1]:03d}.data"
            values = struct.unpack(f">{bio.stat().st_size // 8}d", bio.read_bytes())
            require(all(math.isfinite(value) for value in values), f"finite P4 biology day {day}")
    require(len(set(free_slots)) == 1 and free_slots[0] == 253,
            "stable compact-tail free-stack budget")
    require(len(set(manifest_counts)) == 1 and manifest_counts[0] == 36,
            "stable pickup manifest count")
    require(max_mass_error == 0.0, "exact declared mass budget")
    return len(free_slots), free_slots[0], max_mass_error


def audit_events(root: Path) -> int:
    for case in ("continuous", "part1", "part2"):
        manifests = sorted((root / case).glob("p54_events.r[0-9][0-9][0-9][0-9][0-9][0-9].manifest"))
        require(len(manifests) == 4, f"event manifest rank count {case}")
        for manifest in manifests:
            lines = manifest.read_text(encoding="ascii").splitlines()
            require(lines[0] == "MITGCM_BOM_EVENT_MANIFEST 1" and lines[-1] == "complete 1",
                    f"event manifest framing {manifest}")
            require(lines[5:9] == ["record_count 0", "birth 0 death 0 beach 0",
                                   "outside 0 cancel 0",
                                   "time_min_bits 0000000000000000 time_max_bits 0000000000000000"],
                    f"zero event budget {manifest}")
            shard = manifest.parent / lines[11].split()[1]
            require(shard.stat().st_size == int(lines[9].split()[1]) and
                    sha256(shard) == lines[10].split()[1] and
                    shard.read_text(encoding="ascii") == "MITGCM_BOM_EVENT_SHARD 1 32\n",
                    f"empty event shard {shard}")
    return 12


def audit_all_bom_data_finite(root: Path) -> tuple[int, int]:
    files = 0
    values = 0
    for case in ("continuous", "part1", "part2"):
        for path in (root / case).iterdir():
            if not path.is_file() or path.is_symlink() or not path.name.endswith(".data"):
                continue
            if not (path.name.startswith("bom_traj.") or path.name.startswith("pickup_bom.")):
                continue
            payload = path.read_bytes()
            require(len(payload) % 8 == 0, f"float64 data width {path}")
            decoded = struct.unpack(f">{len(payload) // 8}d", payload)
            require(all(math.isfinite(value) for value in decoded), f"non-finite saved value {path}")
            files += 1
            values += len(decoded)
    return files, values


def parse_elapsed(text: str) -> float:
    parts = [float(value) for value in text.split(":")]
    if len(parts) == 2:
        return parts[0] * 60.0 + parts[1]
    require(len(parts) == 3, f"elapsed format {text}")
    return parts[0] * 3600.0 + parts[1] * 60.0 + parts[2]


def resource_context(root: Path, expected: dict[str, object]) -> dict[str, dict[str, int | float]]:
    result: dict[str, dict[str, int | float]] = {}
    inputs = expected["case_input_sha256"]
    require(isinstance(inputs, dict), "resource input object")
    for case in ("continuous", "part1", "part2"):
        text = (root / case / "resource.txt").read_text(encoding="ascii")
        elapsed = re.search(
            r"^\s*Elapsed \(wall clock\) time .*:\s*(\d+(?::\d+){1,2}(?:\.\d+)?)\s*$",
            text, re.M)
        rss = re.search(r"Maximum resident set size \(kbytes\):\s*(\d+)", text)
        require(elapsed is not None and rss is not None, f"resource fields {case}")
        input_names = set(inputs[case])
        output_bytes = sum(path.stat().st_size for path in (root / case).iterdir()
                           if path.is_file() and not path.is_symlink() and path.name not in input_names)
        result[case] = {"wall_seconds": parse_elapsed(elapsed.group(1)),
                        "peak_rss_kbytes": int(rss.group(1)),
                        "output_bytes": output_bytes}
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    expected = json.loads((root / "expected.json").read_text(encoding="ascii"))
    require(expected["schema"] == "MITGCM-BOM-P5-L01-input-v1" and
            expected["steps"] == 720 and expected["split_iteration"] == 360,
            "frozen input manifest")
    input_hashes = audit_input_hashes(root, expected)
    timers, timer_calls = audit_logs_and_timers(root)
    exact_files = compare_scheduled(root / "continuous", root / "part1", 1, SPLIT,
                                    "continuous/part1")
    exact_files += compare_scheduled(root / "continuous", root / "part2", SPLIT + 1, NSTEPS,
                                     "continuous/part2")
    for name in ("p54_events.r000000.events", "p54_events.r000000.manifest",
                 "p54_events.r000001.events", "p54_events.r000001.manifest",
                 "p54_events.r000002.events", "p54_events.r000002.manifest",
                 "p54_events.r000003.events", "p54_events.r000003.manifest"):
        require(sha256(root / "continuous" / name) == sha256(root / "part2" / name),
                f"continuous/part2 final event member {name}")
        exact_files += 1
    frames, rows, paths = audit_trajectory(root)
    pickup_count, free_slots, mass_error = audit_daily_pickups(root)
    event_manifests = audit_events(root)
    finite_files, finite_values = audit_all_bom_data_finite(root)
    resources = resource_context(root, expected)
    report = {
        "schema": "MITGCM-BOM-P5-L01-audit-v1",
        "result": "PASS",
        "days": 30,
        "hourly_frames": frames,
        "particle_rows": rows,
        "daily_pickups": pickup_count,
        "within_layout_exact_files": exact_files,
        "input_hashes": input_hashes,
        "event_manifests": event_manifests,
        "free_slots_each_day": free_slots,
        "maximum_mass_budget_error": mass_error,
        "finite_data_files": finite_files,
        "finite_float64_values": finite_values,
        "path_m": {str(pid): paths[pid] for pid in IDS},
        "bom_timer_rank_calls": timer_calls,
        "bom_timer_wall_seconds": timers,
        "resources": resources,
    }
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print(f"P5-L01 AUDIT PASS frames={frames} exact_files={exact_files} "
          f"finite_values={finite_values} pickups={pickup_count}")


if __name__ == "__main__":
    main()
