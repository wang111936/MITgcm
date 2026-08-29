#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import pathlib
import re
import struct
import sys


EVENT_TYPES = {
    1: "birth",
    2: "death",
    3: "beach",
    4: "outside",
    5: "cancel",
}


def fail(message: str) -> None:
    raise SystemExit(f"P4.4 ARTIFACT AUDIT FAIL: {message}")


def manifests(root: pathlib.Path) -> list[pathlib.Path]:
    return sorted(root.glob("*.p4manifest"))


def parse_manifest(path: pathlib.Path) -> dict[str, object]:
    lines = path.read_text(encoding="ascii").splitlines()
    if not lines or lines[0] != "MITGCM_BOM_P4_MANIFEST 1":
        fail(f"bad manifest magic: {path.name}")
    if lines[-1:] != ["complete 1"]:
        fail(f"manifest is not complete: {path.name}")
    values: dict[str, object] = {}
    members: list[tuple[int, int, str, str]] = []
    for line in lines[1:-1]:
        if line.startswith("MEMBER "):
            fields = line.split(maxsplit=4)
            if len(fields) != 5:
                fail(f"bad MEMBER line: {line}")
            members.append((int(fields[1]), int(fields[2]), fields[3], fields[4]))
        else:
            values[line.split(maxsplit=1)[0]] = line
    count_line = str(values.get("member_count", ""))
    match = re.fullmatch(r"member_count (\d+)", count_line)
    if not match or int(match.group(1)) != len(members):
        fail(f"member count mismatch: {path.name}")
    for expected_index, (index, size, digest, name) in enumerate(members, 1):
        if index != expected_index:
            fail(f"member order mismatch: {path.name}")
        member = root_for(path) / name
        if not member.is_file() or member.stat().st_size != size:
            fail(f"member size/presence mismatch: {name}")
        actual = hashlib.sha256(member.read_bytes()).hexdigest()
        if actual != digest:
            fail(f"member SHA mismatch: {name}")
    values["members"] = members
    return values


def root_for(path: pathlib.Path) -> pathlib.Path:
    return path.parent


def unpack_record(path: pathlib.Path, fields: int, record: int = 0) -> tuple[float, ...]:
    raw = path.read_bytes()
    begin = record * fields * 8
    chunk = raw[begin : begin + fields * 8]
    if len(chunk) != fields * 8:
        fail(f"short record in {path.name}")
    big = struct.unpack(f">{fields}d", chunk)
    if big[0] in (1.0, 2.0, 4.0):
        return big
    little = struct.unpack(f"<{fields}d", chunk)
    return little


def audit_owner_set(
    root: pathlib.Path, prefix: str, core_fields: int, expected_schema: int
) -> None:
    core = sorted(
        root.glob(f"{prefix}.[0-9][0-9][0-9].[0-9][0-9][0-9].data")
    )
    sidecars = sorted(
        root.glob(f"{prefix}.p4.[0-9][0-9][0-9].[0-9][0-9][0-9].data")
    )
    if not core or len(core) != len(sidecars):
        fail(f"{prefix} core/P4 tile set mismatch")
    owner_total = 0
    for core_path, sidecar in zip(core, sidecars, strict=True):
        header = unpack_record(core_path, core_fields)
        p4_header = unpack_record(sidecar, 4)
        if header[0:2] != (float(expected_schema), float(core_fields)):
            fail(f"released core schema changed: {core_path.name}")
        if p4_header[0:3] != (1.0, 4.0, 4.0):
            fail(f"schema-4 sidecar header mismatch: {sidecar.name}")
        count = int(header[2])
        if int(p4_header[3]) != count:
            fail(f"owner alignment mismatch: {sidecar.name}")
        if core_path.stat().st_size != (count + 1) * core_fields * 8:
            fail(f"core framing mismatch: {core_path.name}")
        if sidecar.stat().st_size != (count + 3) * 4 * 8:
            fail(f"P4 framing mismatch: {sidecar.name}")
        owner_total += count
    if owner_total != 2:
        fail(f"expected two live owners in {prefix}, found {owner_total}")


def parse_event_manifest(path: pathlib.Path) -> dict[str, object]:
    lines = path.read_text(encoding="ascii").splitlines()
    if len(lines) != 13 or lines[0] != "MITGCM_BOM_EVENT_MANIFEST 1":
        fail(f"bad event manifest framing: {path.name}")

    patterns = [
        r"schema (\d+) fields (\d+)",
        r"source_head ([0-9a-f]{40})",
        r"parameter_sha256 ([0-9a-f]{64})",
        r"rank (\d+) ranks (\d+)",
        r"record_count (\d+)",
        r"birth (\d+) death (\d+) beach (\d+)",
        r"outside (\d+) cancel (\d+)",
        r"time_min_bits ([0-9A-F]{16}) time_max_bits ([0-9A-F]{16})",
        r"shard_size (\d+)",
        r"shard_sha256 ([0-9a-f]{64})",
        r"shard_name (\S+)",
    ]
    matches = [re.fullmatch(pattern, line) for pattern, line in zip(patterns, lines[1:12])]
    if any(match is None for match in matches) or lines[12] != "complete 1":
        fail(f"bad event manifest content: {path.name}")
    assert all(match is not None for match in matches)
    values = [match.groups() for match in matches if match is not None]
    if values[0] != ("1", "32"):
        fail(f"event schema mismatch: {path.name}")
    return {
        "source_head": values[1][0],
        "parameter_sha": values[2][0],
        "rank": int(values[3][0]),
        "ranks": int(values[3][1]),
        "records": int(values[4][0]),
        "counts": tuple(map(int, values[5] + values[6])),
        "time_bits": tuple(int(value, 16) for value in values[7]),
        "size": int(values[8][0]),
        "sha": values[9][0],
        "shard": values[10][0],
    }


def audit_events(
    root: pathlib.Path, expected_ranks: int | None, expected_records: int | None
) -> str:
    manifest_paths = sorted(root.glob("*.r[0-9][0-9][0-9][0-9][0-9][0-9].manifest"))
    if not manifest_paths:
        fail("event manifests are absent")
    manifests_parsed = [parse_event_manifest(path) for path in manifest_paths]
    ranks = int(manifests_parsed[0]["ranks"])
    if expected_ranks is not None and ranks != expected_ranks:
        fail(f"event rank count {ranks}, expected {expected_ranks}")
    if len(manifests_parsed) != ranks:
        fail(f"event manifest count {len(manifests_parsed)}, expected {ranks}")
    if sorted(int(item["rank"]) for item in manifests_parsed) != list(range(ranks)):
        fail("event rank coverage is not exact")
    source_heads = {str(item["source_head"]) for item in manifests_parsed}
    parameter_shas = {str(item["parameter_sha"]) for item in manifests_parsed}
    if len(source_heads) != 1 or len(parameter_shas) != 1:
        fail("event provenance differs between ranks")

    all_records: list[tuple[int, ...]] = []
    aggregate = [0, 0, 0, 0, 0]
    for item in manifests_parsed:
        shard = root / str(item["shard"])
        raw = shard.read_bytes()
        if len(raw) != int(item["size"]) or hashlib.sha256(raw).hexdigest() != item["sha"]:
            fail(f"event shard size/SHA mismatch: {shard.name}")
        lines = raw.decode("ascii").splitlines()
        if not lines or lines[0] != "MITGCM_BOM_EVENT_SHARD 1 32":
            fail(f"event shard header mismatch: {shard.name}")
        records: list[tuple[int, ...]] = []
        for line in lines[1:]:
            fields = line.split()
            if len(fields) != 32 or any(re.fullmatch(r"[0-9A-F]{16}", field) is None for field in fields):
                fail(f"event record framing mismatch: {shard.name}")
            words = tuple(int(field, 16) for field in fields)
            if words[0] != 1 or words[1] not in EVENT_TYPES:
                fail(f"event record schema/type mismatch: {shard.name}")
            if words[24] != int(item["rank"]):
                fail(f"event source rank mismatch: {shard.name}")
            records.append(words)
        if len(records) != int(item["records"]):
            fail(f"event record count mismatch: {shard.name}")
        actual_counts = tuple(sum(record[1] == event_type for record in records) for event_type in EVENT_TYPES)
        if actual_counts != item["counts"]:
            fail(f"event type counts mismatch: {shard.name}")
        time_bits = tuple(sorted(record[4] for record in records))
        expected_time_bits = (time_bits[0], time_bits[-1]) if time_bits else (0, 0)
        if expected_time_bits != item["time_bits"]:
            fail(f"event time bounds mismatch: {shard.name}")
        all_records.extend(records)
        aggregate = [left + right for left, right in zip(aggregate, actual_counts)]

    if expected_records is not None and len(all_records) != expected_records:
        fail(f"event record total {len(all_records)}, expected {expected_records}")
    if len(set(all_records)) != len(all_records):
        fail("duplicate canonical event record")
    canonical_lines = [" ".join(f"{word:016X}" for word in record) for record in sorted(all_records)]
    reverse_lines = [
        " ".join(f"{word:016X}" for word in record)
        for record in sorted(reversed(all_records))
    ]
    canonical = "\n".join(canonical_lines).encode("ascii")
    reverse_canonical = "\n".join(reverse_lines).encode("ascii")
    if canonical != reverse_canonical:
        fail("canonical events depend on shard/rank traversal order")
    digest = hashlib.sha256(canonical).hexdigest()
    print(
        "P4-EV01 AUDIT PASS: "
        f"records={len(all_records)} counts={','.join(map(str, aggregate))} sha256={digest}"
    )
    return digest


def audit(root: pathlib.Path) -> None:
    found = manifests(root)
    if len(found) < 2:
        fail("pickup and trajectory manifests were not both published")
    for path in found:
        values = parse_manifest(path)
        flags = str(values.get("p3", ""))
        if "p4 1" not in flags:
            fail(f"P4 flag absent: {path.name}")
        members = values["members"]
        assert isinstance(members, list)
        if not any(".p4." in name for _, _, _, name in members):
            fail(f"P4 sidecar absent: {path.name}")
    audit_owner_set(root, "pickup_bom.0000000000", 45, 2)
    audit_owner_set(root, "bom_traj.0000000000", 48, 2)
    audit_events(root, None, None)
    print("P4-S01 AUDIT PASS: checksummed pickup/trajectory framing and alignment")


def mutate(root: pathlib.Path, mode: str) -> None:
    pickup_manifest = root / "pickup_bom.0000000000.p4manifest"
    sidecars = sorted(
        path
        for path in root.glob("pickup_bom.0000000000.p4.*.data")
        if path.stat().st_size > 3 * 4 * 8
    )
    signature = root / "pickup_bom.0000000000.p4sig.data"
    bio = sorted(root.glob("pickup_bom.0000000000.p4bio.*.data"))[0]
    event_manifest = sorted(root.glob("*.r000000.manifest"))[0]
    event_shard = sorted(root.glob("*.r000000.events"))[0]

    def flip(path: pathlib.Path, offset: int) -> None:
        data = bytearray(path.read_bytes())
        data[offset] ^= 1
        path.write_bytes(data)

    if mode == "manifest":
        data = bytearray(pickup_manifest.read_bytes())
        data[data.index(b"container_schema 4") + len("container_schema ")] = ord("3")
        pickup_manifest.write_bytes(data)
    elif mode == "p4-header":
        flip(sidecars[0], 0)
    elif mode == "parent-hi":
        flip(sidecars[0], 3 * 4 * 8)
    elif mode == "parent-lo":
        flip(sidecars[0], (3 * 4 + 1) * 8)
    elif mode == "amount-s":
        flip(sidecars[0], (3 * 4 + 2) * 8)
    elif mode == "birth-count":
        flip(sidecars[0], (3 * 4 + 3) * 8)
    elif mode == "record-order":
        data = bytearray(sidecars[0].read_bytes())
        offset = 3 * 4 * 8
        fields = [bytes(data[offset + index * 8 : offset + (index + 1) * 8]) for index in range(4)]
        data[offset : offset + 4 * 8] = b"".join(reversed(fields))
        sidecars[0].write_bytes(data)
    elif mode == "sidecar-count":
        flip(sidecars[0], 3 * 8)
    elif mode == "sidecar-truncate":
        data = sidecars[0].read_bytes()
        sidecars[0].write_bytes(data[:-1])
    elif mode == "sidecar-append":
        with sidecars[0].open("ab") as stream:
            stream.write(b"X")
    elif mode == "sidecar-missing":
        sidecars[0].unlink()
    elif mode == "signature":
        flip(signature, 0)
    elif mode == "p4bio-byte":
        flip(bio, len(bio.read_bytes()) - 1)
    elif mode == "event-manifest":
        data = bytearray(event_manifest.read_bytes())
        data[data.index(b"schema 1 fields 32") + len("schema ")] = ord("2")
        event_manifest.write_bytes(data)
    elif mode == "event-truncate":
        data = event_shard.read_bytes()
        event_shard.write_bytes(data[:-1])
    elif mode == "event-append":
        with event_shard.open("ab") as stream:
            stream.write(b"X")
    else:
        fail(f"unknown mutation: {mode}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=pathlib.Path)
    parser.add_argument("--events", action="store_true")
    parser.add_argument("--expected-ranks", type=int)
    parser.add_argument("--expected-records", type=int)
    parser.add_argument("--mutate", choices=[
        "manifest", "p4-header", "parent-hi", "parent-lo", "amount-s",
        "birth-count", "record-order", "sidecar-count", "sidecar-truncate",
        "sidecar-append", "sidecar-missing", "signature", "p4bio-byte",
        "event-manifest", "event-truncate", "event-append"
    ])
    args = parser.parse_args()
    if args.mutate:
        mutate(args.root, args.mutate)
    elif args.events:
        audit_events(args.root, args.expected_ranks, args.expected_records)
    else:
        audit(args.root)


if __name__ == "__main__":
    main()
