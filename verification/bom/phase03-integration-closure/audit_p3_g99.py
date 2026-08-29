#!/usr/bin/env python3
"""Independent evidence and production-path audit for P3-G99."""

from __future__ import annotations

import csv
import re
import subprocess
import sys
from pathlib import Path


EXPECTED_GROUPS = {
    "p35-performance": 20,
    "p34-components": 42,
    "p33-ensemble": 34,
    "p32-cutoff": 18,
    "p31-reference": 34,
    "phase2": 390,
}
P4_RELEASE_BASELINE = "70c02a277ea7d472ccf6e9a7533b2b41ed7eab5a"
ALLOWED_PREFIXES = (
    "pkg/bom/",
    "verification/bom/phase03-",
    "doc/phys_pkgs/MITGCM-BOM/",
)
ALLOWED_PATHS = {
    "verification/bom/README.md",
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.small",
    "verification/bom/phase01-owner-migration/code/BOM_SIZE.h.tile-small",
    "verification/bom/phase01-owner-migration/run_owner_gate.sh",
    "verification/bom/phase02-integration-closure/audit_closure.py",
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
    if len(sys.argv) != 6:
        raise SystemExit(
            "usage: audit_p3_g99.py REPO EVIDENCE HEAD MODE TOTAL"
        )
    repo = Path(sys.argv[1]).resolve()
    evidence = Path(sys.argv[2]).resolve()
    expected_head = sys.argv[3]
    mode = sys.argv[4]
    expected_total = int(sys.argv[5])
    require(mode in {"candidate", "final", "predecessor"},
            f"invalid mode: {mode}")
    require(git(repo, "rev-parse", "HEAD") == expected_head, "head mismatch")
    require(git(repo, "status", "--porcelain=v1") == "", "dirty worktree")
    if mode != "predecessor":
        require(git(repo, "tag", "-l", "MITGCM-BOM-v0.4") == "",
                "v0.4 exists")

    if mode == "predecessor":
        baseline = git(repo, "rev-parse", P4_RELEASE_BASELINE)
        allowed_prefixes = ALLOWED_PREFIXES + (
            "verification/bom/phase04-",
        )
    else:
        baseline = git(repo, "rev-parse", "MITGCM-BOM-v0.3^{commit}")
        allowed_prefixes = ALLOWED_PREFIXES
    changed = git(repo, "diff", "--name-only", f"{baseline}...{expected_head}").splitlines()
    require(changed, "Phase 3 diff is empty")
    for path in changed:
        lowered = path.lower()
        require("skrips" not in lowered and "codex" not in lowered,
                f"forbidden project term: {path}")
        require(path in ALLOWED_PATHS or path.startswith(allowed_prefixes),
                f"path outside Phase 3 scope: {path}")

    row_audit = read_tsv(evidence / "row-audit.tsv")
    require(row_audit and row_audit[-1]["group"] == "TOTAL", "missing TOTAL")
    groups = {row["group"]: row for row in row_audit[:-1]}
    require(set(groups) == set(EXPECTED_GROUPS), "registered groups differ")
    for name, expected in EXPECTED_GROUPS.items():
        row = groups[name]
        require(int(row["expected"]) == expected, f"{name}: expected changed")
        require(int(row["actual"]) == expected and row["result"] == "PASS",
                f"{name}: row audit failed")
    total = row_audit[-1]
    require(expected_total == sum(EXPECTED_GROUPS.values()), "total constant mismatch")
    require(int(total["expected"]) == expected_total and
            int(total["actual"]) == expected_total and
            total["result"] == "PASS", "aggregate total mismatch")

    all_rows = read_tsv(evidence / "all-rows.tsv")
    require(len(all_rows) == expected_total, "all-row cardinality mismatch")
    require(all(row["result"] == "PASS" for row in all_rows), "non-PASS row")
    cases = {(row["package"], row["group"], row["case"]) for row in all_rows}
    require(any(pkg == "p31-reference" and "p3-s01" in case
                for pkg, _, case in cases), "B07/Hooke rows missing")
    require(any(pkg == "p31-reference" and "p3-s02" in case
                for pkg, _, case in cases), "B08/eBOMB rows missing")
    require(any(pkg == "p33-ensemble" and "b09" in case
                for pkg, _, case in cases), "B09 rows missing")
    require(any(pkg == "p33-ensemble" and "b17" in case
                for pkg, _, case in cases), "B17 dynamics rows missing")
    require(any(pkg == "p34-components" and "schema" in case
                for pkg, _, case in cases), "schema-3 restart rows missing")
    require(any(pkg == "phase2" and group == "p15-coexistence"
                for pkg, group, _ in cases), "FLT/BOM coexistence rows missing")
    require(any(pkg == "phase2" and group == "p25-k01"
                for pkg, group, _ in cases), "BOM coexistence rows missing")

    production = list((repo / "pkg" / "bom").glob("*.F"))
    gather_files: set[str] = set()
    gather_pattern = re.compile(
        r"CALL\s+MPI_(?:Gather|Gatherv|Allgather|Allgatherv)", re.IGNORECASE
    )
    for source in production:
        text = source.read_text(encoding="ascii")
        if gather_pattern.search(text):
            gather_files.add(source.name)
        require(not re.search(r"MPI_INTEGER8\s*[,)]", text),
                f"non-portable MPI_INTEGER8: {source.name}")
    expected_gather_files = {"bom_check_state.F", "bom_read_pickup.F"}
    if mode == "predecessor":
        expected_gather_files.add("bom_terminal_plan.F")
        terminal = (repo / "pkg/bom/bom_terminal_plan.F").read_text(
            encoding="ascii"
        )
        require("INTEGER localMeta(9),allMeta(9,nPx*nPy)" in terminal and
                "CALL MPI_Allgather(" in terminal and
                "localMeta,9,MPI_INTEGER" in terminal and
                "allMeta,9,MPI_INTEGER" in terminal,
                "P4 terminal gather is not fixed failure metadata")
        birth_path = repo / "pkg/bom/bom_birth_order.F"
        if birth_path.exists():
            birth = birth_path.read_text(encoding="ascii")
            if gather_pattern.search(birth):
                expected_gather_files.add("bom_birth_order.F")
                require("PARAMETER ( metaInts=6 )" in birth and
                        "PARAMETER ( metaInts=13,metaReals=2 )" in birth and
                        "bomMaxEventBuffer" in birth,
                        "P4 birth gather is not bounded event metadata")
                require(not re.search(
                    r"bom(?:NPartTile|Status|Id|X|Y)\s*\(", birth
                ), "P4 birth gather references live owner arrays")
    require(gather_files == expected_gather_files,
            f"unexpected global collective files: {sorted(gather_files)}")
    spring = (repo / "pkg/bom/bom_spring_stage.F").read_text(encoding="ascii")
    require("CALL BOM_BUILD_CELL_LIST" in spring and
            "CALL BOM_BUILD_NEIGHBORS" in spring,
            "spring path does not use cell-linked graph")

    manifest_files = sorted((evidence / "native-manifests").glob("*.sha256"))
    require(len(manifest_files) == len(EXPECTED_GROUPS), "native manifests missing")
    markers = {
        "candidate": "P3-G99 CANDIDATE AUDIT PASS",
        "final": "P3-G99 FINAL AUDIT PASS",
        "predecessor": "P3-G99 PREDECESSOR AUDIT PASS",
    }
    marker = markers[mode]
    print(f"{marker}: head={expected_head} rows={expected_total} files={len(changed)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
