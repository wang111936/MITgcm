#!/usr/bin/env python3
"""Independent structural and evidence audit for the P2.5 functional head."""

from __future__ import annotations

import argparse
import csv
import subprocess
from pathlib import Path


ALLOWED_PREFIXES = (
    "pkg/bom/",
    "verification/bom/phase02-integration-closure/",
    "verification/bom/phase02-slow-manifold/",
)
ALLOWED_PATHS = {
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.small",
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.tile-small",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True
    ).strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", type=Path)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("expected_head")
    parser.add_argument("expected_total", type=int)
    args = parser.parse_args()

    head = git(args.repo, "rev-parse", "HEAD")
    require(head == args.expected_head, f"head mismatch: {head}")
    require(git(args.repo, "status", "--porcelain=v1") == "",
            "functional head worktree is not clean")
    parent = git(args.repo, "rev-parse", "HEAD^")
    changed = git(args.repo, "diff", "--name-only", parent, head).splitlines()
    require(changed, "functional commit has no changed files")
    for path in changed:
        lowered = path.lower()
        require("skrips" not in lowered and "codex" not in lowered,
                f"forbidden project term in path: {path}")
        require(path in ALLOWED_PATHS or path.startswith(ALLOWED_PREFIXES),
                f"path outside P2.5 scope: {path}")

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
        f"P2.5 INDEPENDENT AUDIT PASS: head={head} "
        f"files={len(changed)} rows={args.expected_total}"
    )


if __name__ == "__main__":
    main()
