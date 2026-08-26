#!/usr/bin/env python3
"""Fail-closed B16 source, environment, input, and golden preflight."""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import subprocess
import sys

LOCKED_JULIA = "julia version 1.10.12"
LOCKED_COMMIT = "156557359185e4413ce82829f3ed26a4eb8c6283"
LOCKED_PHYSICS_SHA = "1acef9ed3c8d13646c95799565387a4add76e839827cea1c0e745ced73f1885d"
LOCKED_PROJECT_SHA = "12cfb1288a21b19216662a719d430bf41b5587dfd8b00e973f8b3c9c25f1f99d"
LOCKED_MANIFEST_SHA = "86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695"


def digest(path: pathlib.Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def fail(message: str) -> None:
    raise RuntimeError(message)


def checksum_manifest(path: pathlib.Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        parts = line.split()
        if len(parts) != 2 or len(parts[0]) != 64:
            fail(f"invalid checksum line in {path}")
        name = parts[1].removeprefix("*")
        if name in result:
            fail(f"duplicate checksum entry: {name}")
        result[name] = parts[0]
    return result


def parse_overrides(values: list[str]) -> dict[str, pathlib.Path]:
    result: dict[str, pathlib.Path] = {}
    for value in values:
        if "=" not in value:
            fail(f"invalid override: {value}")
        name, raw_path = value.split("=", 1)
        if pathlib.Path(name).name != name or name in result:
            fail(f"invalid override name: {name}")
        result[name] = pathlib.Path(raw_path).resolve()
    return result


def check_manifest(
    manifest_file: pathlib.Path,
    phase_dir: pathlib.Path,
    overrides: dict[str, pathlib.Path],
) -> None:
    entries = checksum_manifest(manifest_file)
    if not entries:
        fail(f"empty checksum manifest: {manifest_file}")
    for name, expected in entries.items():
        target = overrides.get(name, phase_dir / name)
        if not target.is_file():
            fail(f"missing checksummed file: {target}")
        actual = digest(target)
        if actual != expected:
            fail(f"checksum mismatch for {name}: {actual}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("input", "full"), required=True)
    parser.add_argument("--phase-dir", type=pathlib.Path, required=True)
    parser.add_argument("--source-root", type=pathlib.Path, required=True)
    parser.add_argument("--julia-bin", type=pathlib.Path, required=True)
    parser.add_argument("--project-file", type=pathlib.Path, required=True)
    parser.add_argument("--manifest-file", type=pathlib.Path, required=True)
    parser.add_argument("--physics-file", type=pathlib.Path)
    parser.add_argument("--source-head")
    parser.add_argument("--override", action="append", default=[])
    args = parser.parse_args()

    phase_dir = args.phase_dir.resolve()
    source_root = args.source_root.resolve()
    project_file = args.project_file.resolve()
    manifest_file = args.manifest_file.resolve()
    physics_file = (args.physics_file or source_root / "src" / "physics.jl").resolve()
    overrides = parse_overrides(args.override)

    julia_version = subprocess.run(
        [str(args.julia_bin.resolve()), "--version"],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    ).stdout.strip()
    if julia_version != LOCKED_JULIA:
        fail(f"wrong Julia version: {julia_version}")
    source_head = args.source_head
    if source_head is None:
        source_head = subprocess.run(
            ["git", "-C", str(source_root), "rev-parse", "HEAD"],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        ).stdout.strip()
    if source_head != LOCKED_COMMIT:
        fail(f"wrong SargassumBOMB commit: {source_head}")
    if digest(physics_file) != LOCKED_PHYSICS_SHA:
        fail("SargassumBOMB physics.jl checksum mismatch")
    if digest(project_file) != LOCKED_PROJECT_SHA:
        fail("Project.toml checksum mismatch")
    if digest(manifest_file) != LOCKED_MANIFEST_SHA:
        fail("Manifest.toml checksum mismatch")

    check_manifest(phase_dir / "input_checksums.sha256", phase_dir, overrides)
    if args.mode == "full":
        check_manifest(phase_dir / "golden_checksums.sha256", phase_dir, overrides)
        check_manifest(phase_dir / "context_checksums.sha256", phase_dir, overrides)
    print(f"B16 PREFLIGHT PASS: {args.mode}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"B16 PREFLIGHT FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
