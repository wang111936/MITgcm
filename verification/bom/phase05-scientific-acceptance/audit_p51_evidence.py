#!/usr/bin/env python3
"""Independent compact-evidence audit for the complete P5.1 gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


PRODUCTION_BUILDS = ("serial-debug", "mpi-debug", "mpi-optimized")
ALL_BUILDS = ("control-serial-debug", *PRODUCTION_BUILDS)
REQUIRED_SYMBOLS = (
    "bom_init_fixed_",
    "bom_init_varia_",
    "bom_check_",
    "bom_main_",
    "bom_build_endpoints_",
    "bom_build_fields_",
    "bom_rhs_julia_",
    "bom_rhs_paper2024_",
    "bom_rk4_",
    "bom_particle_exchange_",
    "bom_write_trajectory_",
    "bom_write_pickup_",
    "bom_read_pickup_",
    "bom_event_flush_impl_",
    "bom_event_budget_check_",
)
REQUIRED_MACROS = (
    "ALLOW_GENERIC_ADVDIFF",
    "ALLOW_MOM_COMMON",
    "ALLOW_MOM_FLUXFORM",
    "ALLOW_MOM_VECINV",
    "ALLOW_CD_CODE",
    "ALLOW_OFFLINE",
    "ALLOW_EXF",
    "ALLOW_DIAGNOSTICS",
    "ALLOW_MNC",
    "ALLOW_BOM",
)
REQUIRED_OBJECTS = (
    "gad_advection.o",
    "mom_fluxform.o",
    "mom_vecinv.o",
    "cd_code_scheme.o",
    "offline_fields_load.o",
    "exf_wind.o",
    "diagnostics_fill.o",
    "mnc_init.o",
    "bom_main.o",
)


def fail(message: str) -> None:
    raise SystemExit(f"P5.1 INDEPENDENT EVIDENCE AUDIT FAIL: {message}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_checksum_file(root: Path, checksum_file: Path) -> int:
    count = 0
    for line in checksum_file.read_text(encoding="ascii").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if match is None:
            fail(f"invalid checksum line in {checksum_file}: {line!r}")
        path_text = match.group(2)
        path = Path(path_text)
        if not path.is_absolute():
            path = root / path
        if not path.is_file():
            fail(f"checksummed file missing: {path}")
        if sha256(path) != match.group(1):
            fail(f"checksummed file changed: {path}")
        count += 1
    if count == 0:
        fail(f"empty checksum file: {checksum_file}")
    return count


def audit_summary(artifact: Path) -> int:
    expected = (artifact / "expected-preaudit.txt").read_text(encoding="ascii").splitlines()
    lines = (artifact / "summary-preaudit.tsv").read_text(encoding="ascii").splitlines()
    if not lines or lines[0] != "case\tresult\tdetail":
        fail("summary header differs")
    rows = [line.split("\t", 2) for line in lines[1:]]
    if any(len(row) != 3 or row[1] != "PASS" or not row[2] for row in rows):
        fail("summary has malformed or non-PASS row")
    actual = [row[0] for row in rows]
    if actual != expected:
        fail(f"summary inventory/order differs expected={expected} actual={actual}")
    if len(set(actual)) != len(actual):
        fail("summary contains duplicate rows")
    return len(actual)


def audit_build(build_root: Path, name: str) -> None:
    build = build_root / name
    for required in (
        "mitgcmuv",
        "genmake.log",
        "depend.log",
        "build.log",
        "Makefile",
        "PACKAGES_CONFIG.h",
        "symbols.txt",
        "fingerprint.txt",
        "command.txt",
    ):
        if not (build / required).is_file():
            fail(f"{name} lacks {required}")
    if not (build / "mitgcmuv").stat().st_mode & 0o111:
        fail(f"{name} executable bit missing")
    fingerprint = (build / "fingerprint.txt").read_text(encoding="ascii")
    if sha256(build / "mitgcmuv") not in fingerprint:
        fail(f"{name} executable hash absent from fingerprint")
    makefile = (build / "Makefile").read_text(encoding="ascii", errors="replace")
    if re.search(r"(^|\s)-DLET_RS_BE_REAL4(\s|$)", makefile):
        fail(f"{name} unexpectedly uses LET_RS_BE_REAL4")
    command = (build / "command.txt").read_text(encoding="ascii")
    if name in {"mpi-debug", "mpi-optimized"} and "-mpi" not in command:
        fail(f"{name} lacks -mpi")
    if name.endswith("debug") and ("-ieee" not in command or "-devel" not in command):
        fail(f"{name} lacks debug/IEEE flags")
    if name == "mpi-optimized" and ("-ieee" in command or "-devel" in command):
        fail("optimized build contains debug/IEEE genmake flags")

    symbols = (build / "symbols.txt").read_text(encoding="ascii", errors="replace")
    if name == "control-serial-debug":
        if re.search(r"\sbom_main_$", symbols, flags=re.MULTILINE):
            fail("BOM main leaked into control build")
        return
    for symbol in REQUIRED_SYMBOLS:
        count = len(re.findall(rf"\s{re.escape(symbol)}$", symbols, flags=re.MULTILINE))
        if count != 1:
            fail(f"{name} symbol {symbol} count={count}")
    if re.search(r"\sbom_verify\S*_$", symbols, flags=re.IGNORECASE | re.MULTILINE):
        fail(f"verification-only symbol in {name}")
    packages = (build / "PACKAGES_CONFIG.h").read_text(encoding="ascii")
    for macro in REQUIRED_MACROS:
        if re.search(rf"^#define\s+{macro}(\s|$)", packages, flags=re.MULTILINE) is None:
            fail(f"{name} lacks {macro}")
    for object_name in REQUIRED_OBJECTS:
        if not (build / object_name).is_file():
            fail(f"{name} lacks package object {object_name}")


def audit_smoke(run_root: Path, artifact: Path) -> int:
    report = (artifact / "smoke-comparison.txt").read_text(encoding="ascii").splitlines()
    if "result=PASS" not in report:
        fail("smoke comparison is not PASS")
    try:
        declared = int(next(line.split("=", 1)[1] for line in report if line.startswith("files=")))
    except (StopIteration, ValueError) as exc:
        fail(f"bad smoke file count: {exc}")
    if declared < 2:
        fail("smoke comparison covers fewer than pickup data/meta")
    left = run_root / "smoke-control"
    right = run_root / "smoke-linked"
    names = sorted(path.name for path in left.glob("pickup.0000000002*"))
    if len(names) != declared:
        fail("smoke pickup count differs from report")
    for name in names:
        if (left / name).read_bytes() != (right / name).read_bytes():
            fail(f"BOM-off pickup differs: {name}")
    for directory in (left, right):
        log = (directory / "combined.log").read_text(encoding="ascii", errors="replace")
        if "PROGRAM MAIN: Execution ended Normally" not in log:
            fail(f"normal termination missing: {directory.name}")
        if list(directory.glob("pickup_bom*")):
            fail(f"BOM pickup exists while off: {directory.name}")
    return declared


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--build-root", type=Path, required=True)
    parser.add_argument("--run-root", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    artifact = args.artifact.resolve()
    build_root = args.build_root.resolve()
    run_root = args.run_root.resolve()
    if args.report.exists():
        fail(f"report already exists: {args.report}")
    if (artifact / "git-status-before.txt").read_bytes() != b"":
        fail("source was dirty before exact-head gate")
    if (artifact / "git-status-after.txt").read_bytes() != b"":
        fail("source changed during exact-head gate")
    head = (artifact / "source-head.txt").read_text(encoding="ascii").strip()
    if re.fullmatch(r"[0-9a-f]{40}", head) is None:
        fail("source head is not a full commit")

    row_count = audit_summary(artifact)
    input_report = json.loads((artifact / "input-audit.json").read_text(encoding="ascii"))
    if input_report.get("result") != "PASS" or input_report.get("time_records") != 97:
        fail("input audit report does not prove 97-record PASS")
    input_bundle = run_root / "input-bundle"
    input_checks = verify_checksum_file(input_bundle, input_bundle / "SHA256SUMS")
    for name in ALL_BUILDS:
        audit_build(build_root, name)
    build_checks = verify_checksum_file(build_root, build_root / "SHA256SUMS")
    run_checks = verify_checksum_file(run_root, run_root / "SHA256SUMS")
    smoke_files = audit_smoke(run_root, artifact)

    report = {
        "schema": "MITGCM-BOM-P5.1-EVIDENCE-v1",
        "result": "PASS",
        "source_head": head,
        "preaudit_rows": row_count,
        "builds": list(ALL_BUILDS),
        "input_checksum_files": input_checks,
        "build_checksum_files": build_checks,
        "run_checksum_files": run_checks,
        "smoke_pickup_files": smoke_files,
    }
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print(
        f"P5.1 INDEPENDENT EVIDENCE AUDIT PASS rows={row_count} "
        f"builds={len(ALL_BUILDS)} smoke_files={smoke_files}"
    )


if __name__ == "__main__":
    main()
