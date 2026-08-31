#!/usr/bin/env python3
"""Independent compact-evidence audit for the frozen P5-J01 gate."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from pathlib import Path


PREAUDIT_ROWS = (
    "p52-driver-audit",
    "p5-j01-input-generate",
    "p5-j01-input-audit",
    "p5-j01-reference-preflight",
    "p5-j01-production-build",
    "p5-j01-build-isolation",
    "p5-j01-reference-byte-reproduction",
    "p5-j01-component-reference-repeat",
    "p5-j01-production-run",
    "p5-j01-call-chain",
    "p5-j01-trajectory-inventory",
    "p5-j01-pickup-schema",
    "p5-j01-julia-trajectory",
    "p5-j01-julia-components",
    "p5-j01-comparison-products",
    "p5-j01-checksums",
)
REQUIRED_SYMBOLS = (
    "bom_init_fixed_",
    "bom_init_varia_",
    "bom_main_",
    "bom_build_endpoints_",
    "bom_build_fields_",
    "bom_fill_cgrid_boundary_",
    "bom_rhs_julia_",
    "bom_rk4_",
    "bom_particle_exchange_",
    "bom_write_trajectory_",
    "bom_write_pickup_",
    "bom_read_pickup_",
)


def fail(message: str) -> None:
    raise SystemExit(f"P5.2 INDEPENDENT EVIDENCE AUDIT FAIL: {message}")


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
        path = Path(match.group(2))
        if not path.is_absolute():
            path = root / path
        if not path.is_file() or sha256(path) != match.group(1):
            fail(f"checksummed file missing or changed: {path}")
        count += 1
    if count == 0:
        fail(f"empty checksum file: {checksum_file}")
    return count


def audit_summary(artifact: Path) -> int:
    expected = (artifact / "expected-preaudit.txt").read_text(encoding="ascii").splitlines()
    if tuple(expected) != PREAUDIT_ROWS:
        fail("expected pre-audit inventory differs from frozen P5.2 inventory")
    lines = (artifact / "summary-preaudit.tsv").read_text(encoding="ascii").splitlines()
    if not lines or lines[0] != "case\tresult\tdetail":
        fail("summary header differs")
    rows = [line.split("\t", 2) for line in lines[1:]]
    if any(len(row) != 3 or row[1] != "PASS" or not row[2] for row in rows):
        fail("summary contains malformed or non-PASS rows")
    actual = tuple(row[0] for row in rows)
    if actual != PREAUDIT_ROWS or len(set(actual)) != len(actual):
        fail("summary inventory, ordering, or uniqueness differs")
    return len(actual)


def audit_build(build_root: Path) -> None:
    build = build_root / "mpi-debug"
    for name in (
        "mitgcmuv", "genmake.log", "depend.log", "build.log", "Makefile",
        "PACKAGES_CONFIG.h", "symbols.txt", "fingerprint.txt", "command.txt",
    ):
        if not (build / name).is_file():
            fail(f"production build lacks {name}")
    if not (build / "mitgcmuv").stat().st_mode & 0o111:
        fail("production executable bit missing")
    command = (build / "command.txt").read_text(encoding="ascii")
    if not all(flag in command for flag in ("-mpi", "-ieee", "-devel")):
        fail("production build command lacks MPI/debug/IEEE flags")
    makefile = (build / "Makefile").read_text(encoding="ascii", errors="replace")
    if re.search(r"(^|\s)-DLET_RS_BE_REAL4(\s|$)", makefile):
        fail("production reference build weakened _RS to Real*4")
    symbols = (build / "symbols.txt").read_text(encoding="ascii", errors="replace")
    for symbol in REQUIRED_SYMBOLS:
        if len(re.findall(rf"\s{re.escape(symbol)}$", symbols, re.MULTILINE)) != 1:
            fail(f"production symbol count differs: {symbol}")
    if re.search(r"\sbom_verify\S*_$", symbols, re.IGNORECASE | re.MULTILINE):
        fail("verification-only BOM symbol linked into production executable")
    fingerprint = (build / "fingerprint.txt").read_text(encoding="ascii")
    if sha256(build / "mitgcmuv") not in fingerprint:
        fail("executable checksum absent from build fingerprint")
    cpp = (build_root / "mpi-debug-mods" / "CPP_EEOPTIONS.h").read_text(encoding="ascii")
    for macro in ("ALWAYS_PREVENT_X_PERIODICITY", "ALWAYS_PREVENT_Y_PERIODICITY"):
        if re.search(rf"^#define\s+{macro}\s*$", cpp, re.MULTILINE) is None:
            fail(f"non-periodic build macro missing: {macro}")


def audit_reference(repo: Path, run_root: Path) -> None:
    locked = repo / "verification/bom/reference/phase02"
    rerun = run_root / "reference-rerun"
    for name in (
        "golden_rhs_julia_v1.csv",
        "golden_traj_julia_rk2_v1.csv",
        "golden_traj_julia_rk4_v1.csv",
    ):
        if (locked / name).read_bytes() != (rerun / name).read_bytes():
            fail(f"locked Julia regeneration differs: {name}")
    reference = run_root / "reference"
    if (reference / "components.csv").read_bytes() != (reference / "components.rerun.csv").read_bytes():
        fail("full Julia component generator is not byte-repeatable")
    with (reference / "components.csv").open(newline="", encoding="ascii") as stream:
        rows = list(csv.DictReader(stream))
    if len(rows) != 291:
        fail("full Julia component reference does not contain 291 rows")


def audit_call_chain(run: Path) -> int:
    logs = sorted(run.glob("STDOUT.[0-9][0-9][0-9][0-9]"))
    if len(logs) != 4:
        fail(f"expected four MPI STDOUT logs, found {len(logs)}")
    pattern = re.compile(
        r"No\. starts:\s+96\s*\n[^\n]*No\. stops:\s+96\s*\n"
        r"[^\n]*Seconds in section \"BOM\s+\[FORWARD_STEP\]\":"
    )
    for log in logs:
        text = log.read_text(encoding="ascii", errors="replace")
        if "PROGRAM MAIN: Execution ended Normally" not in text:
            fail(f"normal termination marker missing: {log.name}")
        if pattern.search(text) is None:
            fail(f"96-call FORWARD_STEP -> BOM timer proof missing: {log.name}")
        if re.search(r"ABNORMAL END|S/R ALL_PROC_DIE|Fortran runtime error", text, re.IGNORECASE):
            fail(f"fatal marker present: {log.name}")
    return len(logs) * 96


def audit_comparison(run_root: Path) -> tuple[int, int, int]:
    comparison = run_root / "comparison"
    result = json.loads((comparison / "result.json").read_text(encoding="ascii"))
    if result.get("schema") != "MITGCM-BOM-P5-J01-result-v1" or result.get("result") != "PASS":
        fail("comparison result is not frozen-schema PASS")
    trajectory = result["trajectory"]
    components = result["components"]
    inventory = result["inventory"]
    if trajectory["rows"] != 291 or trajectory["failures"] != 0:
        fail("trajectory row/failure count differs")
    if components["production_rows"] != 288 or components["comparisons"] != 8352:
        fail("component row/comparison count differs")
    if components["failures"] != 0:
        fail("component tolerance failure recorded")
    if trajectory["tolerance"] != {"absolute_m": 1e-06, "relative_to_reference_path": 5e-11}:
        fail("trajectory tolerance differs from frozen bound")
    if components["tolerance"] != {"absolute": 2e-12, "relative": 5e-12}:
        fail("component tolerance differs from frozen bound")
    if not all(value > 0.0 for value in result["net_displacement_m"].values()):
        fail("one or more particles did not move")
    if inventory["iterations"] != 96 or inventory["data_files"] != 384 or inventory["meta_files"] != 384:
        fail("trajectory raw-file inventory differs")
    if inventory["normalized_trajectory_rows"] != 291 or inventory["normalized_component_rows"] != 288:
        fail("normalized inventory differs")
    for suffix, expected_time in (("0000000048", 43200.0), ("0000000096", 86400.0)):
        pickup = inventory["pickup"].get(suffix)
        if pickup is None or pickup["particles"] != 3 or pickup["tiles"] != 4:
            fail(f"pickup particle/tile inventory differs: {suffix}")
        if pickup["signature_fields"] != 1333 or pickup["time_s"] != expected_time:
            fail(f"pickup signature/time differs: {suffix}")
    for name in (
        "normalized_trajectory.csv", "trajectory_errors.csv",
        "normalized_components.csv", "component_errors.csv", "inventory_audit.json",
        "review.md", "particle_1001_timeseries.svg", "particle_1002_timeseries.svg",
        "particle_1003_timeseries.svg", "trajectory_planview.svg",
    ):
        if not (comparison / name).is_file() or (comparison / name).stat().st_size == 0:
            fail(f"comparison product missing or empty: {name}")
    return trajectory["rows"], components["comparisons"], inventory["data_files"] + inventory["meta_files"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--build-root", type=Path, required=True)
    parser.add_argument("--run-root", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    artifact = args.artifact.resolve()
    repo = args.repo_root.resolve()
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
    if (artifact / "v05-ancestor.txt").read_text(encoding="ascii").strip() != "yes":
        fail("source head is not recorded as a v0.5 descendant")

    rows = audit_summary(artifact)
    input_report = json.loads((artifact / "input-audit.json").read_text(encoding="ascii"))
    if input_report.get("result") != "PASS" or input_report.get("time_records") != 97:
        fail("input audit does not prove a 97-record PASS")
    if input_report.get("forcing_records") != 98 or input_report.get("particles") != 3:
        fail("input read-ahead/particle counts differ")
    input_checks = verify_checksum_file(run_root / "input-bundle", run_root / "input-bundle/SHA256SUMS")
    audit_build(build_root)
    audit_reference(repo, run_root)
    calls = audit_call_chain(run_root / "run")
    trajectory_rows, component_checks, raw_traj_files = audit_comparison(run_root)
    build_checks = verify_checksum_file(build_root, build_root / "SHA256SUMS")
    run_checks = verify_checksum_file(run_root, run_root / "SHA256SUMS")

    report = {
        "schema": "MITGCM-BOM-P5.2-EVIDENCE-v1",
        "result": "PASS",
        "source_head": head,
        "preaudit_rows": rows,
        "mpi_rank_bom_calls": calls,
        "trajectory_rows": trajectory_rows,
        "component_comparisons": component_checks,
        "raw_trajectory_files": raw_traj_files,
        "input_checksum_files": input_checks,
        "build_checksum_files": build_checks,
        "run_checksum_files": run_checks,
    }
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print(
        f"P5.2 INDEPENDENT EVIDENCE AUDIT PASS rows={rows} "
        f"trajectory={trajectory_rows} components={component_checks} calls={calls}"
    )


if __name__ == "__main__":
    main()
