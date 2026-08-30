#!/usr/bin/env python3
"""Independent evidence, ancestry and production-path audit for P4-G99."""

from __future__ import annotations

import csv
import re
import subprocess
import sys
from pathlib import Path


EXPECTED_GROUPS = {
    "p41-direct": 31,
    "p42-direct": 18,
    "p43-direct": 26,
    "p44-direct": 57,
    "p45-b19": 19,
    "phase3-predecessor": 538,
}
P4_BASELINE = "70c02a277ea7d472ccf6e9a7533b2b41ed7eab5a"
ALLOWED_PREFIXES = (
    "pkg/bom/",
    "verification/bom/phase04-",
    "doc/phys_pkgs/MITGCM-BOM/",
)
ALLOWED_PATHS = {
    "verification/bom/README.md",
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.small",
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.tile-small",
    "verification/bom/phase01-owner-migration/run_owner_gate.sh",
    "verification/bom/phase02-integration-closure/audit_closure.py",
    "verification/bom/phase03-integration-closure/audit_p3_g99.py",
    "verification/bom/phase03-integration-closure/run_p3_g99.sh",
    "verification/bom/phase03-performance-closeout/code/BOM_SIZE.h.performance",
    "verification/bom/phase03-performance-closeout/run_performance_gate.sh",
    "verification/bom/phase03-spring-ensemble/run_spring_ensemble_gate.sh",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True
    ).strip()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def main() -> int:
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: audit_p4_g99.py REPO EVIDENCE HEAD TOTAL"
        )
    repo = Path(sys.argv[1]).resolve()
    evidence = Path(sys.argv[2]).resolve()
    expected_head = sys.argv[3]
    expected_total = int(sys.argv[4])
    require(git(repo, "rev-parse", "HEAD") == expected_head,
            "head mismatch")
    require(git(repo, "branch", "--show-current") ==
            "MITGCM-BOM/development", "development branch required")
    require(git(repo, "status", "--porcelain=v1") == "",
            "dirty worktree")
    require(git(repo, "tag", "-l", "MITGCM-BOM-v0.5") == "",
            "v0.5 exists")
    require(git(repo, "rev-parse", "MITGCM-BOM-v0.4^{commit}") ==
            P4_BASELINE, "v0.4 baseline mismatch")

    changed = git(
        repo, "diff", "--name-only", f"{P4_BASELINE}...{expected_head}"
    ).splitlines()
    require(changed, "Phase 4 diff is empty")
    for path in changed:
        lowered = path.lower()
        require("skrips" not in lowered and "codex" not in lowered,
                f"forbidden project term: {path}")
        require(path in ALLOWED_PATHS or path.startswith(ALLOWED_PREFIXES),
                f"path outside Phase 4 scope: {path}")

    audit_rows = read_tsv(evidence / "row-audit.tsv")
    require(audit_rows and audit_rows[-1]["group"] == "TOTAL",
            "missing TOTAL row")
    groups = {row["group"]: row for row in audit_rows[:-1]}
    require(set(groups) == set(EXPECTED_GROUPS),
            "registered P4-G99 groups differ")
    for name, expected in EXPECTED_GROUPS.items():
        row = groups[name]
        require(int(row["expected"]) == expected,
                f"{name}: expected count changed")
        require(int(row["actual"]) == expected and
                row["result"] == "PASS", f"{name}: row audit failed")
    require(expected_total == sum(EXPECTED_GROUPS.values()),
            "aggregate total constant mismatch")
    total = audit_rows[-1]
    require(int(total["expected"]) == expected_total and
            int(total["actual"]) == expected_total and
            total["result"] == "PASS", "aggregate TOTAL failed")

    all_rows = read_tsv(evidence / "all-rows.tsv")
    require(len(all_rows) == expected_total,
            "all-row cardinality mismatch")
    require(all(row["result"] == "PASS" for row in all_rows),
            "non-PASS all-row entry")
    cases = {
        (row["package"], row["group"], row["case"])
        for row in all_rows
    }
    for package, token in (
        ("p41-direct", "b12"),
        ("p42-direct", "b11"),
        ("p43-direct", "b14"),
        ("p43-direct", "b17"),
        ("p44-direct", "b15"),
        ("p45-b19", "b19"),
    ):
        require(any(pkg == package and token in case.lower()
                    for pkg, _, case in cases),
                f"{package}: {token} coverage missing")
    require(any(row["package"] == "p44-direct" and
                "budget" in row["detail"].lower()
                for row in all_rows),
            "p44-direct: B18 budget coverage missing")
    require(any(pkg == "phase3-predecessor" and
                group == "phase2/p15-coexistence"
                for pkg, group, case in cases),
            "compatibility-only FLT+BOM predecessor row missing")

    brooks = repo / "verification/bom/phase04-biology-land/reference/brooks_oracle.py"
    philox = repo / "verification/bom/phase04-biology-land/reference/philox_oracle.py"
    require(brooks.is_file() and philox.is_file(),
            "Julia/reference or Philox oracle missing")
    source_manifest = (evidence / "source-files.sha256").read_text(
        encoding="utf-8"
    )
    require(str(brooks) in source_manifest and str(philox) in source_manifest,
            "reference oracles absent from source manifest")

    gather_pattern = re.compile(
        r"CALL\s+MPI_(?:Gather|Gatherv|Allgather|Allgatherv)", re.I
    )
    gather_files: set[str] = set()
    for source in (repo / "pkg/bom").glob("*.F"):
        text = source.read_text(encoding="ascii")
        if gather_pattern.search(text):
            gather_files.add(source.name)
        require(not re.search(r"MPI_INTEGER8\s*[,)]", text),
                f"non-portable MPI_INTEGER8: {source.name}")
    require(gather_files == {
        "bom_birth_order.F",
        "bom_check_state.F",
        "bom_p4_schema.F",
        "bom_read_pickup.F",
        "bom_terminal_plan.F",
    }, f"unexpected gather files: {sorted(gather_files)}")
    birth = (repo / "pkg/bom/bom_birth_order.F").read_text(encoding="ascii")
    require("PARAMETER ( metaInts=6 )" in birth and
            "PARAMETER ( metaInts=13,metaReals=2 )" in birth and
            "bomMaxEventBuffer" in birth,
            "birth gather is not bounded event metadata")
    require(not re.search(r"bom(?:NPartTile|Status|Id|X|Y)\s*\(", birth),
            "birth gather references live owner arrays")
    terminal = (repo / "pkg/bom/bom_terminal_plan.F").read_text(
        encoding="ascii"
    )
    require("INTEGER localMeta(9),allMeta(9,nPx*nPy)" in terminal and
            "localMeta,9,MPI_INTEGER" in terminal,
            "terminal gather is not fixed failure metadata")
    event = (repo / "pkg/bom/bom_event_transaction_p43.F").read_text(
        encoding="ascii"
    )
    require(not gather_pattern.search(event),
            "event transaction gathers live owners")
    require("CALL BOM_EVENT_PREFLIGHT" in event,
            "event transaction bypasses P4.5 capacity preflight")
    spring = (repo / "pkg/bom/bom_spring_stage.F").read_text(
        encoding="ascii"
    )
    require("No rank enters component collectives" in spring and
            "CALL BOM_P3_GLOBAL_STATUS" in spring,
            "graph capacity failure is not collective-safe")

    native = sorted((evidence / "native-manifests").glob("*.sha256"))
    require(len(native) == len(EXPECTED_GROUPS),
            "native manifests missing")
    print(
        f"P4-G99 FINAL AUDIT PASS: head={expected_head} "
        f"rows={expected_total} files={len(changed)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
