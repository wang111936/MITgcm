#!/usr/bin/env python3
"""Independent compact-evidence audit for the frozen P5.3 gate."""

from __future__ import annotations

import argparse
import ast
import csv
import hashlib
import json
import math
import re
from pathlib import Path


PREAUDIT_ROWS = (
    "p53-driver-audit",
    "p53-oracle-isolation",
    "p53-oracle-determinism",
    "p5-p01-input-generate",
    "p5-p01-input-audit",
    "p5-p02-input-generate",
    "p5-p02-input-audit",
    "p53-reference-preflight",
    "p53-component-reference-repeat",
    "p53-production-build",
    "p53-build-isolation",
    "p5-p01-production-run",
    "p5-p02-production-runs",
    "p53-call-chain",
    "p53-trajectory-inventory",
    "p5-p01-paper-oracle",
    "p5-p01-mode-discrimination",
    "p5-p02-same-step-oracle",
    "p5-p02-temporal-convergence",
    "p53-comparison-products",
    "p53-checksums",
)
REQUIRED_SYMBOLS = (
    "bom_init_fixed_",
    "bom_init_varia_",
    "bom_main_",
    "bom_build_endpoints_",
    "bom_build_fields_",
    "bom_fill_cgrid_boundary_",
    "bom_rhs_julia_",
    "bom_rhs_paper2024_",
    "bom_rk4_",
    "bom_particle_exchange_",
    "bom_write_trajectory_",
)
RUNS = {
    "p01-dt900": 96,
    "p02-dt900": 96,
    "p02-dt450": 192,
    "p02-dt225": 384,
}


def fail(message: str) -> None:
    raise SystemExit(f"P5.3 INDEPENDENT EVIDENCE AUDIT FAIL: {message}")


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
        fail("expected pre-audit inventory differs from frozen P5.3 inventory")
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


def audit_oracle(repo: Path, run_root: Path) -> int:
    source_path = repo / "verification/bom/phase05-scientific-acceptance/generate_p53_paper_oracle.py"
    source = source_path.read_text(encoding="ascii")
    imports: set[str] = set()
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Import):
            imports.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            imports.add((node.module or "").split(".")[0])
    allowed = {"__future__", "argparse", "csv", "hashlib", "json", "decimal", "pathlib"}
    if not imports <= allowed:
        fail(f"oracle has non-independent imports: {sorted(imports-allowed)}")
    for forbidden in ("pkg/bom", "bom_rhs_", "mitgcmuv", "subprocess", "ctypes", "f2py"):
        if forbidden.lower() in source.lower():
            fail(f"oracle contains forbidden coupling: {forbidden}")

    oracle = run_root / "oracle"
    rerun = run_root / "oracle-rerun"
    names = sorted(path.name for path in oracle.iterdir() if path.is_file())
    if names != sorted(path.name for path in rerun.iterdir() if path.is_file()):
        fail("oracle rerun file inventory differs")
    for name in names:
        if (oracle / name).read_bytes() != (rerun / name).read_bytes():
            fail(f"oracle rerun differs: {name}")
    checksum_count = verify_checksum_file(oracle, oracle / "SHA256SUMS")
    manifest = json.loads((oracle / "oracle-manifest.json").read_text(encoding="ascii"))
    if manifest.get("schema") != "MITGCM-BOM-P5-PAPER2024-ORACLE-v1":
        fail("oracle manifest schema differs")
    arithmetic = manifest.get("arithmetic", {})
    if arithmetic.get("decimal_digits") != 90 or arithmetic.get("minimum_binary_precision_bits", 0) < 256:
        fail("oracle precision differs")
    if manifest.get("time", {}).get("fine_reference_step_s") != "28.125":
        fail("oracle fine step differs")
    files = manifest.get("files", {})
    if len(files) != 5 or any(entry.get("rows") != 291 for entry in files.values()):
        fail("oracle CSV inventory/cardinality differs")
    contract = repo / "verification/bom/phase05-scientific-acceptance/P5.3_TEST_CONTRACT.md"
    fixture = repo / "verification/bom/phase05-scientific-acceptance/p53_p02_affine_fields.csv"
    if manifest.get("source_sha256") != sha256(source_path):
        fail("oracle source hash differs")
    if manifest.get("contract_sha256") != sha256(contract):
        fail("P5.3 contract hash differs")
    if manifest.get("p02_affine_fixture_sha256") != sha256(fixture):
        fail("P5-P02 fixture hash differs")
    return checksum_count


def audit_inputs(run_root: Path) -> int:
    definitions = (
        ("p01", 900, 96, 98, 311),
        ("p02", 900, 96, 98, 311),
        ("p02", 450, 192, 194, 599),
        ("p02", 225, 384, 386, 1175),
    )
    checksum_files = 0
    for case_id, dt_s, steps, forcing, file_count in definitions:
        stem = f"input-{case_id}-dt{dt_s}"
        report_name = "input-p01-audit.json" if case_id == "p01" else f"{stem}-audit.json"
        report = json.loads((run_root / report_name).read_text(encoding="ascii"))
        expected = {
            "result": "PASS", "case": case_id, "dt_s": dt_s,
            "steps": steps, "forcing_records": forcing,
            "common_output_records": 97, "file_count": file_count,
            "particles": 3,
        }
        if any(report.get(key) != value for key, value in expected.items()):
            fail(f"input audit contract differs: {stem}")
        bundle = run_root / stem
        checksum_files += verify_checksum_file(bundle, bundle / "SHA256SUMS")
    return checksum_files


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
    if sha256(build / "mitgcmuv") not in (build / "fingerprint.txt").read_text(encoding="ascii"):
        fail("executable checksum absent from build fingerprint")
    mods = build_root / "mpi-debug-mods"
    if any(path.name.lower().startswith("bom") and path.suffix.upper() == ".F"
           for path in mods.iterdir() if path.is_file()):
        fail("production BOM source override present")


def audit_runs(run_root: Path) -> int:
    total_calls = 0
    for label, steps in RUNS.items():
        run = run_root / f"run-{label}"
        logs = sorted(run.glob("STDOUT.[0-9][0-9][0-9][0-9]"))
        if len(logs) != 4:
            fail(f"expected four MPI logs for {label}")
        timer = re.compile(
            rf"No\. starts:\s+{steps}\s*\n[^\n]*No\. stops:\s+{steps}\s*\n"
            rf"[^\n]*Seconds in section \"BOM\s+\[FORWARD_STEP\]\":"
        )
        for log in logs:
            text = log.read_text(encoding="ascii", errors="replace")
            if "PROGRAM MAIN: Execution ended Normally" not in text or timer.search(text) is None:
                fail(f"normal termination/call proof missing: {log}")
            if re.search(r"ABNORMAL END|S/R ALL_PROC_DIE|Fortran runtime error", text, re.I):
                fail(f"fatal marker present: {log}")
        data = list(run.glob("bom_traj.*.data"))
        meta = list(run.glob("bom_traj.*.meta"))
        if len(data) != 384 or len(meta) != 384:
            fail(f"trajectory file inventory differs: {label}")
        total_calls += 4 * steps
    return total_calls


def audit_comparison(run_root: Path) -> tuple[int, int, int]:
    comparison = run_root / "comparison"
    result = json.loads((comparison / "result.json").read_text(encoding="ascii"))
    if result.get("schema") != "MITGCM-BOM-P5.3-result-v1" or result.get("result") != "PASS":
        fail("aggregate P5.3 comparison is not PASS")
    p01 = result["p5_p01"]
    if p01.get("result") != "PASS":
        fail("P5-P01 is not PASS")
    if p01["trajectory"]["rows"] != 291 or p01["trajectory"]["failures"] != 0:
        fail("P5-P01 trajectory count differs")
    if p01["components"]["comparisons"] != 8352 or p01["components"]["failures"] != 0:
        fail("P5-P01 component count differs")
    if p01["trajectory"]["tolerance"] != {"absolute_m": 1e-6, "relative_to_reference_path": 5e-11}:
        fail("P5-P01 trajectory tolerance differs")
    if p01["components"]["tolerance"] != {"absolute": 2e-12, "relative": 5e-12}:
        fail("P5-P01 component tolerance differs")
    for discriminator in p01["mode_discrimination"].values():
        if discriminator["result"] != "PASS":
            fail("mode discriminator failed")
        if not discriminator["difference"] > 10.0 * discriminator["roundoff_bound"]:
            fail("mode discriminator margin differs")

    p02 = result["p5_p02"]
    if p02.get("result") != "PASS" or p02.get("failures") != 0:
        fail("P5-P02 is not a zero-failure PASS")
    if p02["same_step_oracle"] != {
        **p02["same_step_oracle"], "comparisons": 873, "failures": 0
    }:
        fail("P5-P02 same-step count differs")
    reference = p02["reference"]
    if reference.get("fixed_rk4_step_s") != 28.125 or reference.get("decimal_digits") != 90:
        fail("P5-P02 reference step/precision differs")
    if reference.get("minimum_binary_precision_bits", 0) < 256:
        fail("P5-P02 reference has insufficient precision")
    if p02.get("floor_m") != 1e-6 or p02.get("interpret_above_floor_multiplier") != 50.0:
        fail("P5-P02 floor interpretation differs")
    if p02.get("minimum_interpreted_ratio") != 12.0:
        fail("P5-P02 ratio threshold differs")
    if p02.get("norm_rows") != 18 or p02.get("ratio_rows") != 12:
        fail("P5-P02 norm/ratio cardinality differs")
    for particle in ("1001", "1002", "1003"):
        for norm in ("endpoint", "full_linf"):
            errors = [p02["errors_m"][particle][str(dt)][norm] for dt in (900, 450, 225)]
            if not all(math.isfinite(value) for value in errors) or not errors[0] > errors[1] > errors[2]:
                fail(f"P5-P02 errors do not strictly decrease: {particle}/{norm}")
    with (comparison / "p02_ratios.csv").open(newline="", encoding="ascii") as stream:
        ratios = list(csv.DictReader(stream))
    if len(ratios) != 12 or any(row["result"] != "PASS" for row in ratios):
        fail("P5-P02 ratio table differs")
    for row in ratios:
        ratio = float(row["ratio"])
        if row["interpreted"] == "yes" and ratio < 12.0:
            fail("interpreted P5-P02 ratio is below 12")

    inventory = result["inventory"]
    cases = [inventory["p01"], *(inventory["p02"][str(dt)] for dt in (900, 450, 225))]
    if any(case["data_files"] != 384 or case["meta_files"] != 384
           or case["output_frames"] != 96 or case["particle_records"] != 288
           for case in cases):
        fail("comparison raw inventory differs")
    products = (
        "normalized_p01.csv", "normalized_p02_dt0900.csv",
        "normalized_p02_dt0450.csv", "normalized_p02_dt0225.csv",
        "p01_normalized_components.csv", "p01_component_errors.csv",
        "p01_trajectory_errors.csv", "p02_same_step_errors.csv",
        "p02_norms.csv", "p02_ratios.csv", "inventory_audit.json", "review.md",
        "p01_particle_1001_timeseries.svg", "p01_particle_1002_timeseries.svg",
        "p01_particle_1003_timeseries.svg", "p01_trajectory_planview.svg",
        "p02_particle_1001_timeseries.svg", "p02_particle_1002_timeseries.svg",
        "p02_particle_1003_timeseries.svg", "p02_trajectory_planview.svg",
    )
    for name in products:
        if not (comparison / name).is_file() or (comparison / name).stat().st_size == 0:
            fail(f"comparison product missing or empty: {name}")
    return 291, 8352, 873


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
        fail("source is not recorded as a v0.5 descendant")

    rows = audit_summary(artifact)
    oracle_checks = audit_oracle(repo, run_root)
    input_checks = audit_inputs(run_root)
    if (run_root / "reference/components.csv").read_bytes() != (run_root / "reference/components.rerun.csv").read_bytes():
        fail("locked Julia component reference is not repeatable")
    audit_build(build_root)
    calls = audit_runs(run_root)
    if calls != 3072:
        fail(f"aggregate BOM call count differs: {calls}")
    trajectory_rows, component_checks, same_step_checks = audit_comparison(run_root)
    build_checks = verify_checksum_file(build_root, build_root / "SHA256SUMS")
    run_checks = verify_checksum_file(run_root, run_root / "SHA256SUMS")

    report = {
        "schema": "MITGCM-BOM-P5.3-EVIDENCE-v1",
        "result": "PASS",
        "source_head": head,
        "preaudit_rows": rows,
        "oracle_checksum_files": oracle_checks,
        "input_checksum_files": input_checks,
        "mpi_rank_bom_calls": calls,
        "p01_trajectory_rows": trajectory_rows,
        "p01_component_comparisons": component_checks,
        "p02_same_step_comparisons": same_step_checks,
        "build_checksum_files": build_checks,
        "run_checksum_files": run_checks,
    }
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print(
        f"P5.3 INDEPENDENT EVIDENCE AUDIT PASS rows={rows} "
        f"p01_components={component_checks} p02_same_step={same_step_checks} calls={calls}"
    )


if __name__ == "__main__":
    main()
