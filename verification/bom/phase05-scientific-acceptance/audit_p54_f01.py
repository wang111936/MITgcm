#!/usr/bin/env python3
"""Independent P5-F01 input, event, trajectory and pickup auditor."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
from pathlib import Path


CASES = ("spring", "birth", "cancel", "death", "coast", "combined")
TILES = ((1, 1), (1, 2), (2, 1), (2, 2))
EVENT_COUNTS = {"birth": 1, "death": 2, "beach": 3, "outside": 4, "cancel": 5}
MASK32 = (1 << 32) - 1
M0, M1 = 3528531795, 3449720151
W0, W1 = 2654435769, 3144134277
TWO32 = 1 << 32
TWO_PI = float("6.28318530717958647692528676655900577")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exact_int(value: float, label: str) -> int:
    require(math.isfinite(value) and value == round(value), f"non-exact integer {label}")
    return int(value)


def read_records(path: Path, fields: int) -> list[tuple[float, ...]]:
    raw = path.read_bytes()
    size = fields * 8
    require(len(raw) % size == 0, f"record framing: {path}")
    values = struct.unpack(f">{len(raw) // 8}d", raw)
    return [values[offset : offset + fields] for offset in range(0, len(values), fields)]


def words_id(high: int, low: int) -> int:
    require(0 <= high <= MASK32 and 0 <= low <= MASK32, "ID word range")
    return (high << 32) | low


def record_id(record: tuple[float, ...], label: str) -> int:
    return words_id(exact_int(record[0], label + " high"), exact_int(record[1], label + " low"))


def bits_float(word: int) -> float:
    return struct.unpack(">d", word.to_bytes(8, "big"))[0]


def audit_input(case_dir: Path, case: str) -> dict[str, object]:
    expected = json.loads((case_dir / "expected.json").read_text(encoding="ascii"))
    require(expected["schema"] == "MITGCM-BOM-P5-F01-input-v1", f"input schema {case}")
    require(expected["case"] == case, f"input case label {case}")
    lines = (case_dir / "SHA256SUMS").read_text(encoding="ascii").splitlines()
    require(lines, f"empty checksum inventory {case}")
    names: list[str] = []
    for line in lines:
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
        require(match is not None, f"bad checksum row {case}: {line}")
        assert match is not None
        path = case_dir / match.group(2)
        require(path.is_file() and sha256(path) == match.group(1), f"input SHA {case}/{path.name}")
        names.append(path.name)
    require(len(names) == len(set(names)), f"duplicate checksum path {case}")
    require((case_dir / "nutrient.bin").stat().st_size == 3 * 8 * 6 * 8,
            f"nutrient read-ahead size {case}")
    particles = read_records(case_dir / "bom_particles.data", 8)
    require(particles[0][:6] == (1.0, 8.0, float(len(particles) - 1), 1.0, 1.0, 64.0),
            f"particle header {case}")
    ids = tuple(record_id(row, case) for row in particles[1:])
    expected_ids = tuple(int(item["id"]) for item in expected["particles"])
    require(ids == expected_ids and ids == tuple(sorted(set(ids))), f"particle IDs {case}")
    require(all(row[5] == 1.0 and row[7] == 0.0 for row in particles[1:]),
            f"particle status/reserved {case}")
    return expected


def audit_log(case_dir: Path, case: str) -> None:
    stdout = "\n".join(
        path.read_text(encoding="ascii", errors="replace")
        for path in sorted(case_dir.glob("STDOUT.*"))
    )
    stderr = "\n".join(
        path.read_text(encoding="ascii", errors="replace")
        for path in sorted(case_dir.glob("STDERR.*"))
    )
    require("PROGRAM MAIN: Execution ended Normally" in stdout, f"normal end {case}")
    forbidden = ("ABNORMAL END", "S/R ALL_PROC_DIE", "particle failure", "event failure")
    require(not any(marker in stdout + stderr for marker in forbidden), f"fatal marker {case}")


def parse_manifest(path: Path) -> list[str]:
    lines = path.read_text(encoding="ascii").splitlines()
    require(lines[:1] == ["MITGCM_BOM_P4_MANIFEST 1"] and lines[-1:] == ["complete 1"],
            f"P4 manifest framing {path}")
    members: list[str] = []
    for line in lines:
        if not line.startswith("MEMBER "):
            continue
        fields = line.split(maxsplit=4)
        require(len(fields) == 5 and int(fields[1]) == len(members) + 1,
                f"P4 member order {path}")
        size, digest, name = int(fields[2]), fields[3], fields[4]
        member = path.parent / name
        require(member.is_file() and member.stat().st_size == size, f"P4 member size {name}")
        require(sha256(member) == digest, f"P4 member SHA {name}")
        members.append(name)
    count_line = next(line for line in lines if line.startswith("member_count "))
    require(int(count_line.split()[1]) == len(members), f"P4 member count {path}")
    return members


def sidecar_path(root: Path, prefix: str, kind: str, tile: tuple[int, int]) -> Path:
    return root / f"{prefix}.{kind}.{tile[0]:03d}.{tile[1]:03d}.data"


def core_path(root: Path, prefix: str, tile: tuple[int, int]) -> Path:
    return root / f"{prefix}.{tile[0]:03d}.{tile[1]:03d}.data"


def decode_owner_set(
    root: Path, prefix: str, core_fields: int, *, p3: bool, p4: bool,
) -> tuple[dict[int, dict[str, object]], int]:
    owners: dict[int, dict[str, object]] = {}
    initial_count: int | None = None
    live_count: int | None = None
    for tile in TILES:
        path = core_path(root, prefix, tile)
        records = read_records(path, core_fields)
        header = records[0]
        require(header[0:2] == (2.0, float(core_fields)), f"core schema {path}")
        local_count = exact_int(header[2], f"local count {path}")
        require(local_count == len(records) - 1, f"core local framing {path}")
        this_initial = exact_int(header[3], f"initial count {path}")
        initial_count = this_initial if initial_count is None else initial_count
        require(initial_count == this_initial, f"initial count agreement {path}")
        p3_rows: list[tuple[float, ...]] = []
        p4_rows: list[tuple[float, ...]] = []
        if p3:
            p3_rows = read_records(sidecar_path(root, prefix, "p3", tile), 8)
            require(p3_rows[0][0:4] == (1.0, 8.0, 3.0, float(local_count)),
                    f"P3 header {path}")
            require(len(p3_rows) == local_count + 1, f"P3 framing {path}")
        if p4:
            p4_rows = read_records(sidecar_path(root, prefix, "p4", tile), 4)
            require(p4_rows[0] == (1.0, 4.0, 4.0, float(local_count)), f"P4 header {path}")
            require(len(p4_rows) == local_count + 3, f"P4 framing {path}")
            this_live = exact_int(p4_rows[2][3], f"live count {path}")
            live_count = this_live if live_count is None else live_count
            require(live_count == this_live, f"live count agreement {path}")
        previous = 0
        for index, core in enumerate(records[1:], 1):
            require(all(math.isfinite(value) for value in core), f"finite owner {path}")
            particle_id = record_id(core, str(path))
            require(previous < particle_id and particle_id not in owners, f"owner ID order {path}")
            previous = particle_id
            item: dict[str, object] = {
                "id": particle_id,
                "status": exact_int(core[2], "owner status"),
                "x": core[5] if core_fields == 48 else core[3],
                "y": core[6] if core_fields == 48 else core[4],
                "core": core,
                "tile": tile,
            }
            if p3:
                row = p3_rows[index]
                require(record_id(row, "P3 owner") == particle_id, f"P3 alignment {path}")
                item["raft_id"] = words_id(exact_int(row[2], "raft high"), exact_int(row[3], "raft low"))
                item["neighbor"] = exact_int(row[4], "neighbor")
                item["raft_size"] = exact_int(row[5], "raft size")
                item["spring_e"] = row[6]
                item["spring_n"] = row[7]
            if p4:
                row = p4_rows[index + 2]
                item["parent_id"] = words_id(exact_int(row[0], "parent high"), exact_int(row[1], "parent low"))
                item["amount"] = row[2]
                item["birth_count"] = exact_int(row[3], "birth count")
            owners[particle_id] = item
    require(initial_count is not None, f"missing owner headers {prefix}")
    if p4:
        require(live_count == len(owners), f"P4 live owner budget {prefix}")
    else:
        require(initial_count == len(owners), f"core owner budget {prefix}")
    return owners, initial_count


def event_records(root: Path, expected_ranks: int = 4) -> list[tuple[int, ...]]:
    manifests = sorted(root.glob("p54_events.r[0-9][0-9][0-9][0-9][0-9][0-9].manifest"))
    require(len(manifests) == expected_ranks, f"event manifest rank count {root}")
    all_records: list[tuple[int, ...]] = []
    aggregate = [0] * 5
    for expected_rank, manifest in enumerate(manifests):
        lines = manifest.read_text(encoding="ascii").splitlines()
        require(len(lines) == 13 and lines[0] == "MITGCM_BOM_EVENT_MANIFEST 1" and
                lines[-1] == "complete 1", f"event manifest framing {manifest}")
        rank_match = re.fullmatch(r"rank (\d+) ranks (\d+)", lines[4])
        require(rank_match is not None and tuple(map(int, rank_match.groups())) ==
                (expected_rank, expected_ranks), f"event rank {manifest}")
        count = int(lines[5].split()[1])
        counts = tuple(map(int, (lines[6] + " " + lines[7]).split()[1::2]))
        require(len(counts) == 5 and sum(counts) == count, f"event counts {manifest}")
        size = int(lines[9].split()[1])
        digest = lines[10].split()[1]
        shard = root / lines[11].split()[1]
        require(shard.stat().st_size == size and sha256(shard) == digest, f"event SHA {shard}")
        shard_lines = shard.read_text(encoding="ascii").splitlines()
        require(shard_lines[:1] == ["MITGCM_BOM_EVENT_SHARD 1 32"], f"event shard header {shard}")
        records: list[tuple[int, ...]] = []
        for line in shard_lines[1:]:
            fields = line.split()
            require(len(fields) == 32 and all(re.fullmatch(r"[0-9A-F]{16}", word) for word in fields),
                    f"event record framing {shard}")
            record = tuple(int(word, 16) for word in fields)
            require(record[0] == 1 and record[1] in EVENT_COUNTS.values(), f"event schema/type {shard}")
            require(record[24] == expected_rank, f"event source rank {shard}")
            records.append(record)
        require(len(records) == count, f"event record count {shard}")
        actual_counts = tuple(sum(row[1] == event_type for row in records) for event_type in range(1, 6))
        require(actual_counts == counts, f"event type counts {shard}")
        all_records.extend(records)
        aggregate = [left + right for left, right in zip(aggregate, counts)]
    require(len(all_records) == len(set(all_records)), f"duplicate canonical event {root}")
    return sorted(all_records, key=lambda row: (row[2], row[3], row[1], row[8], row[12]))


def mul_high_low_32(a: int, b: int) -> tuple[int, int]:
    a0, a1, b0, b1 = a & 0xFFFF, a >> 16, b & 0xFFFF, b >> 16
    p0, p1, p2, p3 = a0 * b0, a0 * b1, a1 * b0, a1 * b1
    carry = (p0 >> 16) + (p1 & 0xFFFF) + (p2 & 0xFFFF)
    return (p3 + (p1 >> 16) + (p2 >> 16) + (carry >> 16)) & MASK32, \
        (p0 & 0xFFFF) + ((carry & 0xFFFF) << 16)


def philox4x32(counter: tuple[int, int, int, int], key: tuple[int, int]) -> tuple[int, int, int, int]:
    c0, c1, c2, c3 = counter
    k0, k1 = key
    for round_index in range(10):
        hi0, lo0 = mul_high_low_32(M0, c0)
        hi1, lo1 = mul_high_low_32(M1, c2)
        c0, c1, c2, c3 = hi1 ^ c1 ^ k0, lo1, hi0 ^ c3 ^ k1, lo0
        if round_index != 9:
            k0, k1 = (k0 + W0) & MASK32, (k1 + W1) & MASK32
    return c0, c1, c2, c3


def birth_attempt(seed: int, parent: int, count: int, event: int, attempt: int,
                  radius: float, x: float, y: float) -> tuple[int, float, float]:
    first = philox4x32((parent & MASK32, parent >> 32, count, seed & MASK32), (0, 0))
    second = philox4x32((event & MASK32, event >> 32, attempt, 0), (first[0], first[2]))
    angle = TWO_PI * ((second[0] + 0.5) / TWO32)
    return second[0], x + radius * math.cos(angle), y + radius * math.sin(angle)


def check_event_common(row: tuple[int, ...], event_type: int) -> None:
    require(row[0] == 1 and row[1] == event_type, "event type")
    require(words_id(row[2], row[3]) == 0, "event time index")
    require(bits_float(row[4]) == 100.0 and row[5:7] == (1, 1), "event time/iter/substep")


def check_event_cases(root: Path, expected: dict[str, dict[str, object]]) -> None:
    for case in ("birth", "cancel", "death", "coast", "combined"):
        rows = event_records(root / case)
        expected_counts = {int(key): int(value) for key, value in
                           expected[case]["expected_event_counts"].items()}
        actual_counts = {kind: sum(row[1] == kind for row in rows) for kind in range(1, 6)}
        require(all(actual_counts[kind] == expected_counts.get(kind, 0) for kind in range(1, 6)),
                f"global event counts {case}")
        for row in rows:
            check_event_common(row, row[1])

        if case in ("birth", "cancel"):
            row = rows[0]
            parent, child = 1001, 1002
            radius = 100.0 if case == "birth" else 10000.0
            _, attempt_x, attempt_y = birth_attempt(20260831, parent, 0, 0, 0,
                                                    radius, 1500.0, 1500.0)
            require(math.isclose(bits_float(row[17]), attempt_x, abs_tol=1e-10) and
                    math.isclose(bits_float(row[18]), attempt_y, abs_tol=1e-10),
                    f"Philox first attempt {case}")
            warm_trial = float(expected[case]["biology"]["warm_s_trial"])
            require(bits_float(row[19]) == 1.0 and
                    math.isclose(bits_float(row[20]), warm_trial, abs_tol=2e-15),
                    f"amount before/trial {case}")
            if case == "birth":
                require(record_subject_parent_child(row) == (child, parent, child), "birth IDs")
                require(row[13:15] == (1, 1) and row[22] == 0 and row[23] == 0,
                        "birth status/retry/stage")
                require(math.isclose(bits_float(row[15]), attempt_x, abs_tol=1e-10) and
                        math.isclose(bits_float(row[16]), attempt_y, abs_tol=1e-10) and
                        bits_float(row[21]) == 1.0, "birth accepted/S-after")
            else:
                require(record_subject_parent_child(row) == (parent, parent, 0), "cancel IDs")
                require(row[13:15] == (1, 1) and row[22] == 4 and row[23] == 0,
                        "cancel status/retry/stage")
                require(bits_float(row[15]) == 1500.0 and bits_float(row[16]) == 1500.0 and
                        bits_float(row[21]) == 1.0, "cancel rollback")
        elif case == "death":
            row = rows[0]
            require(record_subject_parent_child(row) == (1001, 0, 0), "death IDs")
            require(row[13:15] == (1, 2) and row[22:24] == (0, 0), "death status")
            require(bits_float(row[15]) == bits_float(row[17]) == 1500.0 and
                    bits_float(row[16]) == bits_float(row[18]) == 1500.0, "death position")
            require(bits_float(row[19]) == 1.0 and
                    math.isclose(bits_float(row[20]), float(expected[case]["biology"]["cold_s_trial"]),
                                 abs_tol=2e-15) and bits_float(row[21]) == 0.0,
                    "death amount")
        elif case == "coast":
            by_type = {row[1]: row for row in rows}
            beach, outside = by_type[3], by_type[4]
            require(record_subject_parent_child(beach) == (2001, 0, 0), "beach ID")
            require(beach[13:15] == (1, 3) and beach[23] == 4,
                    f"beach status/stage actual={beach[13:15]}/{beach[23]}")
            require(tuple(bits_float(beach[i]) for i in (15, 16, 17, 18)) ==
                    (2500.0, 2500.0, 3000.0, 2500.0), "beach last-wet/attempt")
            require(record_subject_parent_child(outside) == (2002, 0, 0), "outside ID")
            require(outside[13:15] == (1, 4) and outside[23] == 2,
                    f"outside status/stage actual={outside[13:15]}/{outside[23]}")
            require(tuple(bits_float(outside[i]) for i in (15, 16, 17, 18)) ==
                    (7500.0, 4500.0, 8000.0, 4500.0), "outside last-wet/attempt")
        else:
            by_type = {row[1]: row for row in rows}
            death, birth = by_type[2], by_type[1]
            require(record_subject_parent_child(death) == (3002, 0, 0), "combined death IDs")
            require(record_subject_parent_child(birth) == (3003, 3001, 3003), "combined birth IDs")
            _, x_attempt, y_attempt = birth_attempt(20260831, 3001, 0, 0, 0,
                                                    100.0, 1500.0, 1500.0)
            require(math.isclose(bits_float(birth[15]), x_attempt, abs_tol=1e-10) and
                    math.isclose(bits_float(birth[16]), y_attempt, abs_tol=1e-10),
                    "combined birth Philox")


def record_subject_parent_child(row: tuple[int, ...]) -> tuple[int, int, int]:
    return (words_id(row[7], row[8]), words_id(row[9], row[10]), words_id(row[11], row[12]))


def ebomb_rhs(positions: dict[int, tuple[float, float]]) -> tuple[
    dict[int, tuple[float, float]], dict[int, int], list[tuple[int, int]]
]:
    result = {particle_id: [0.0, 0.0] for particle_id in positions}
    neighbor = {particle_id: 0 for particle_id in positions}
    edges: list[tuple[int, int]] = []
    ids = sorted(positions)
    for left_index, left in enumerate(ids):
        for right in ids[left_index + 1 :]:
            dx = positions[right][0] - positions[left][0]
            dy = positions[right][1] - positions[left][1]
            distance = math.hypot(dx, dy)
            if distance > 350.0:
                continue
            stiffness = 0.001 / (1.0 + math.exp((distance - 200.0) / 25.0))
            scalar = stiffness * (100.0 / distance - 1.0)
            east, north = -scalar * dx, -scalar * dy
            result[left][0] += east
            result[left][1] += north
            result[right][0] -= east
            result[right][1] -= north
            neighbor[left] += 1
            neighbor[right] += 1
            edges.append((left, right))
    return {key: tuple(value) for key, value in result.items()}, neighbor, edges


def spring_rk4_step(positions: dict[int, tuple[float, float]], dt: float) -> dict[int, tuple[float, float]]:
    ids = sorted(positions)
    k1, _, _ = ebomb_rhs(positions)
    p2 = {key: (positions[key][0] + 0.5 * dt * k1[key][0],
                positions[key][1] + 0.5 * dt * k1[key][1]) for key in ids}
    k2, _, _ = ebomb_rhs(p2)
    p3 = {key: (positions[key][0] + 0.5 * dt * k2[key][0],
                positions[key][1] + 0.5 * dt * k2[key][1]) for key in ids}
    k3, _, _ = ebomb_rhs(p3)
    p4 = {key: (positions[key][0] + dt * k3[key][0],
                positions[key][1] + dt * k3[key][1]) for key in ids}
    k4, _, _ = ebomb_rhs(p4)
    return {
        key: (
            positions[key][0] + dt * (k1[key][0] + 2 * k2[key][0] + 2 * k3[key][0] + k4[key][0]) / 6,
            positions[key][1] + dt * (k1[key][1] + 2 * k2[key][1] + 2 * k3[key][1] + k4[key][1]) / 6,
        ) for key in ids
    }


def audit_spring(root: Path) -> None:
    positions = {101: (2500.0, 2500.0), 202: (2700.0, 2500.0), 303: (2500.0, 2700.0)}
    initial_center = tuple(sum(point[index] for point in positions.values()) / 3 for index in (0, 1))
    initial_rhs, initial_neighbors, initial_edges = ebomb_rhs(positions)
    require(initial_edges == [(101, 202), (101, 303), (202, 303)], "initial spring graph")
    require(initial_neighbors == {101: 2, 202: 2, 303: 2}, "initial neighbors")
    require(abs(sum(value[0] for value in initial_rhs.values())) < 1e-15 and
            abs(sum(value[1] for value in initial_rhs.values())) < 1e-15,
            "initial pair-force budget")
    for iteration in range(1, 5):
        positions = spring_rk4_step(positions, 20.0)
        prefix = f"bom_traj.{iteration:010d}"
        owners, initial_count = decode_owner_set(root, prefix, 48, p3=True, p4=False)
        require(initial_count == 3 and set(owners) == set(positions), f"spring owner set {iteration}")
        rhs, neighbors, edges = ebomb_rhs(positions)
        require(edges == [(101, 202), (101, 303), (202, 303)], f"spring graph {iteration}")
        for particle_id, reference in positions.items():
            actual = owners[particle_id]
            error = math.hypot(float(actual["x"]) - reference[0], float(actual["y"]) - reference[1])
            require(error <= 1e-6, f"spring RK4 trajectory {iteration}/{particle_id}: {error}")
            require(actual["neighbor"] == neighbors[particle_id] and actual["raft_id"] == 101 and
                    actual["raft_size"] == 3, f"spring graph sidecar {iteration}/{particle_id}")
            component_tol = 2e-12 + 5e-12 * max(abs(rhs[particle_id][0]), abs(rhs[particle_id][1]))
            require(abs(float(actual["spring_e"]) - rhs[particle_id][0]) <= component_tol and
                    abs(float(actual["spring_n"]) - rhs[particle_id][1]) <= component_tol,
                    f"spring component {iteration}/{particle_id}")
    final_center = tuple(sum(point[index] for point in positions.values()) / 3 for index in (0, 1))
    require(math.hypot(final_center[0] - initial_center[0], final_center[1] - initial_center[1]) < 1e-10,
            "oracle center of mass")


def read_p4_signature(path: Path) -> tuple[float, ...]:
    raw = path.read_bytes()
    require(len(raw) % 8 == 0 and len(raw) >= 80 * 8, f"P4 signature framing {path}")
    values = struct.unpack(f">{len(raw) // 8}d", raw)
    require(values[0:3] in ((4.0, values[1], 1.0), (4.0, values[1], 2.0)),
            f"P4 signature schema {path}")
    return values


def budget_word(signature: tuple[float, ...], one_based_high: int) -> int:
    return words_id(exact_int(signature[one_based_high - 1], "budget high"),
                    exact_int(signature[one_based_high], "budget low"))


def audit_discrete_states(root: Path) -> None:
    expected_states = {
        "birth": {1001: (0, 1.0, 1), 1002: (1001, 1.0, 0)},
        "cancel": {1001: (0, 1.0, 0)},
        "death": {},
        "coast": {},
        "combined": {3001: (0, 1.0, 1), 3003: (3001, 1.0, 0)},
    }
    for case, state in expected_states.items():
        case_root = root / case
        owners, _ = decode_owner_set(
            case_root, "bom_traj.0000000001", 48,
            p3=case == "combined", p4=True,
        )
        require(set(owners) == set(state), f"final owner IDs {case}")
        for particle_id, (parent, amount, births) in state.items():
            owner = owners[particle_id]
            require(owner["status"] == 1 and owner["parent_id"] == parent and
                    owner["amount"] == amount and owner["birth_count"] == births,
                    f"final P4 state {case}/{particle_id}")
            x, y = float(owner["x"]), float(owner["y"])
            require(0.0 <= x <= 8000.0 and 0.0 <= y <= 6000.0,
                    f"live owner domain {case}/{particle_id}")
        manifest = case_root / "bom_traj.0000000001.p4manifest"
        members = parse_manifest(manifest)
        require(any(".p4." in name for name in members), f"trajectory P4 member {case}")
        if case == "combined":
            require(any(".p3." in name for name in members), "combined trajectory P3 member")

    combined = root / "combined"
    pickup, _ = decode_owner_set(combined, "pickup_bom.0000000001", 45, p3=True, p4=True)
    trajectory, _ = decode_owner_set(combined, "bom_traj.0000000001", 48, p3=True, p4=True)
    require(set(pickup) == set(trajectory) == {3001, 3003}, "combined pickup IDs")
    for particle_id in pickup:
        for key in ("status", "x", "y", "parent_id", "amount", "birth_count",
                    "neighbor", "raft_id", "raft_size", "spring_e", "spring_n"):
            left, right = pickup[particle_id][key], trajectory[particle_id][key]
            if isinstance(left, float):
                require(struct.pack(">d", left) == struct.pack(">d", float(right)),
                        f"pickup/trajectory bitwise {particle_id}/{key}")
            else:
                require(left == right, f"pickup/trajectory exact {particle_id}/{key}")
    members = parse_manifest(combined / "pickup_bom.0000000001.p4manifest")
    require(any(".p4bio." in name for name in members), "combined P4 biology pickup member")
    for prefix, file_class in (("bom_traj.0000000001", 1), ("pickup_bom.0000000001", 2)):
        signature = read_p4_signature(combined / f"{prefix}.p4sig.data")
        require(exact_int(signature[2], "file class") == file_class, "P4 signature file class")
        require(exact_int(signature[25], "initial owners") == 2 and
                exact_int(signature[26], "live owners") == 2, "P4 signature owner budget")
        require(budget_word(signature, 30) == 3004, "P4 next ID")
        require(budget_word(signature, 32) == 1, "P4 event time index")
        require(budget_word(signature, 34) == 1 and budget_word(signature, 36) == 1,
                "P4 birth/death budget")
        require(all(budget_word(signature, field) == 0 for field in (38, 40, 42, 44)),
                "P4 zero event budgets")
        require(exact_int(signature[46], "event buffer") == 0 and signature[79] == 1.0,
                "P4 flushed buffer proof")
    bio_paths = sorted(combined.glob("pickup_bom.0000000001.p4bio.*.data"))
    require(len(bio_paths) == 4, "P4 biology tile count")
    for path in bio_paths:
        values = struct.unpack(f">{path.stat().st_size // 8}d", path.read_bytes())
        require(all(math.isfinite(value) for value in values), f"P4 biology finite {path}")
        require(values[0] == 1.0 and values[2] == 4.0 and values[3:9] ==
                (1.0, 100.0, 0.0, 1.0, 0.0, 100.0), f"P4 biology header {path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    expected: dict[str, dict[str, object]] = {}
    for case in CASES:
        case_dir = root / case
        require(case_dir.is_dir(), f"missing case directory {case}")
        expected[case] = audit_input(case_dir, case)
        audit_log(case_dir, case)
    audit_spring(root / "spring")
    check_event_cases(root, expected)
    audit_discrete_states(root)
    report = {
        "schema": "MITGCM-BOM-P5-F01-audit-v1",
        "result": "PASS",
        "cases": list(CASES),
        "event_records": {case: sum(map(int, expected[case]["expected_event_counts"].values()))
                          for case in CASES},
        "spring_frames": 4,
        "manifest_sha256": sha256(root / "combined" / "pickup_bom.0000000001.p4manifest"),
    }
    if args.report:
        args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print("P5-F01 AUDIT PASS cases=6 spring_frames=4 events=7 schema4_pickup=1")


if __name__ == "__main__":
    main()
