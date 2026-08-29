#!/usr/bin/env python3
"""Independent structural and evidence audit for Phase 2 regressions."""

from __future__ import annotations

import argparse
import csv
import os
import subprocess
from pathlib import Path


P2_ALLOWED_PREFIXES = (
    "pkg/bom/",
    "verification/bom/phase02-integration-closure/",
    "verification/bom/phase02-slow-manifold/",
)
P2_ALLOWED_PATHS = {
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.small",
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.tile-small",
    "verification/bom/phase02-b16/README.md",
    "verification/bom/phase02-stage-rk/README.md",
}
P31_ALLOWED_PREFIXES = (
    "verification/bom/phase03-reference-laws/",
    "verification/bom/phase03-springs-neighbors/reference/",
)
P31_ALLOWED_PATHS = {
    "pkg/bom/BOM.h",
    "pkg/bom/bom_check.F",
    "pkg/bom/bom_pair_geometry.F",
    "pkg/bom/bom_readparms.F",
    "pkg/bom/bom_spring_pair.F",
    "pkg/bom/bom_validate_spring_config.F",
    "verification/bom/phase02-integration-closure/audit_closure.py",
}
P33_ALLOWED_PREFIXES = (
    "verification/bom/phase03-spring-ensemble/",
)
P33_ALLOWED_PATHS = {
    "pkg/bom/BOM.h",
    "pkg/bom/BOM_GRAPH_SIZE.h",
    "pkg/bom/BOM_SIZE.h",
    "pkg/bom/bom_check.F",
    "pkg/bom/bom_check_state.F",
    "pkg/bom/bom_ghost_exchange.F",
    "pkg/bom/bom_init_state.F",
    "pkg/bom/bom_main.F",
    "pkg/bom/bom_particle_exchange.F",
    "pkg/bom/bom_spring_ensemble.F",
    "pkg/bom/bom_spring_rhs_stage.F",
    "pkg/bom/bom_spring_stage.F",
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.small",
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.tile-small",
    "verification/bom/phase01-owner-migration/run_owner_gate.sh",
    "verification/bom/phase02-integration-closure/audit_closure.py",
}
P35_ALLOWED_PREFIXES = (
    "pkg/bom/",
    "verification/bom/phase03-components-schema3/",
    "verification/bom/phase03-integration-closure/",
    "verification/bom/phase03-performance-closeout/",
    "verification/bom/phase03-springs-neighbors/",
    "doc/phys_pkgs/MITGCM-BOM/",
)
P35_ALLOWED_PATHS = {
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.small",
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.tile-small",
    "verification/bom/phase01-owner-migration/run_owner_gate.sh",
    "verification/bom/phase02-integration-closure/audit_closure.py",
    "verification/bom/phase03-cutoff-graph/run_cutoff_graph_gate.sh",
    "verification/bom/phase03-reference-laws/run_reference_law_gate.sh",
    "verification/bom/phase03-spring-ensemble/run_spring_ensemble_gate.sh",
}
P41_BASELINE = "70c02a277ea7d472ccf6e9a7533b2b41ed7eab5a"
P41_ALLOWED_PREFIXES = (
    "pkg/bom/",
    "verification/bom/phase04-biology-land/",
)
P41_ALLOWED_PATHS = {
    "doc/phys_pkgs/MITGCM-BOM/PHASE_RECORDS/PHASE-04.md",
    "doc/phys_pkgs/MITGCM-BOM/PROJECT_STATUS.md",
    "verification/bom/README.md",
    "verification/bom/phase02-integration-closure/audit_closure.py",
    "verification/bom/phase03-integration-closure/audit_p3_g99.py",
    "verification/bom/phase03-integration-closure/run_p3_g99.sh",
}
P42_ALLOWED_PATHS = P41_ALLOWED_PATHS | {
    "verification/bom/phase03-performance-closeout/run_performance_gate.sh",
}
P43_ALLOWED_PATHS = P42_ALLOWED_PATHS | {
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.small",
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.tile-small",
    "verification/bom/phase01-owner-migration/run_owner_gate.sh",
    "verification/bom/phase03-performance-closeout/code/BOM_SIZE.h.performance",
    "verification/bom/phase03-spring-ensemble/run_spring_ensemble_gate.sh",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True
    ).strip()


def scope_rules() -> tuple[str, tuple[str, ...], set[str], str | None]:
    scope = os.environ.get("MITGCM_BOM_CLOSURE_SCOPE", "P2.5")
    if scope == "P2.5":
        return scope, P2_ALLOWED_PREFIXES, P2_ALLOWED_PATHS, None
    if scope == "P3.1":
        return scope, P31_ALLOWED_PREFIXES, P31_ALLOWED_PATHS, None
    if scope == "P3.3":
        return scope, P33_ALLOWED_PREFIXES, P33_ALLOWED_PATHS, None
    if scope == "P3.5":
        return scope, P35_ALLOWED_PREFIXES, P35_ALLOWED_PATHS, None
    if scope == "P4.1":
        return scope, P41_ALLOWED_PREFIXES, P41_ALLOWED_PATHS, P41_BASELINE
    if scope == "P4.2":
        return scope, P41_ALLOWED_PREFIXES, P42_ALLOWED_PATHS, P41_BASELINE
    if scope == "P4.3":
        return scope, P41_ALLOWED_PREFIXES, P43_ALLOWED_PATHS, P41_BASELINE
    raise RuntimeError(f"unsupported closure scope: {scope}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", type=Path)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("expected_head")
    parser.add_argument("expected_total", type=int)
    args = parser.parse_args()

    scope, allowed_prefixes, allowed_paths, replay_baseline = scope_rules()
    head = git(args.repo, "rev-parse", "HEAD")
    require(head == args.expected_head, f"head mismatch: {head}")
    require(git(args.repo, "status", "--porcelain=v1") == "",
            "functional head worktree is not clean")
    if replay_baseline is None:
        baseline = git(args.repo, "rev-parse", "HEAD^")
        diff_range = (baseline, head)
    else:
        baseline = git(args.repo, "rev-parse", replay_baseline)
        diff_range = (f"{baseline}...{head}",)
    changed = git(args.repo, "diff", "--name-only", *diff_range).splitlines()
    require(changed, "functional commit has no changed files")
    for path in changed:
        lowered = path.lower()
        require("skrips" not in lowered and "codex" not in lowered,
                f"forbidden project term in path: {path}")
        require(path in allowed_paths or path.startswith(allowed_prefixes),
                f"path outside {scope} scope: {path}")

    size_text = (args.repo / "pkg/bom/BOM_SIZE.h").read_text(encoding="ascii")
    require("bomOutputFields2  = 48" in size_text, "trajectory width is not 48")
    require("bomPickupFields2  = 45" in size_text, "pickup width is not 45")
    require("bomPickup2SigBase = 53" in size_text, "signature base is not 53")

    reader = (args.repo / "pkg/bom/bom_read_pickup.F").read_text(encoding="ascii")
    scratch_decl = reader.index("scratchDiag(")
    scratch_load = reader.index("scratchDiag(iDiag,ip,bi,bj) =", scratch_decl)
    commit_marker = reader.index("C--   One commit publishes")
    diag_commit = reader.index("bomRhsDiag(iDiag,ip,bi,bj) =", commit_marker)
    require(scratch_decl < scratch_load < commit_marker < diag_commit,
            "diagnostic scratch/commit ordering is not transactional")
    require("BOM_FAIL_PICKUP_SCHEMA" in reader[commit_marker - 6000:commit_marker],
            "schema failure code is missing before commit")

    audit_rows = list(csv.DictReader(
        (args.evidence / "row-audit.tsv").open(encoding="ascii"),
        delimiter="\t",
    ))
    require(audit_rows and audit_rows[-1]["group"] == "TOTAL",
            "row audit lacks TOTAL")
    require(all(row["result"] == "PASS" for row in audit_rows),
            "row audit contains non-PASS result")
    total = audit_rows[-1]
    require(int(total["expected"]) == args.expected_total and
            int(total["actual"]) == args.expected_total,
            f"aggregate total mismatch: {total}")

    provenance = list(csv.DictReader(
        (args.evidence / "provenance.tsv").open(encoding="ascii"),
        delimiter="\t",
    ))
    require(len(provenance) == len(audit_rows) - 1,
            "provenance/group cardinality mismatch")
    for row in provenance:
        source = Path(row["source"])
        require(source.is_file(), f"missing summary: {source}")
        with source.open(encoding="ascii") as stream:
            summary = list(csv.reader(stream, delimiter="\t"))
        require(len(summary) > 1, f"empty summary: {source}")
        require(all(len(item) >= 2 and item[1] == "PASS" for item in summary[1:]),
                f"non-PASS summary row: {source}")
        source_head = source.parent / "source-head.txt"
        if source_head.is_file():
            require(source_head.read_text(encoding="ascii").strip() == head,
                    f"summary source head mismatch: {source}")

    print(
        f"P2.5 INDEPENDENT AUDIT PASS: scope={scope} head={head} "
        f"files={len(changed)} rows={args.expected_total}"
    )


if __name__ == "__main__":
    main()
