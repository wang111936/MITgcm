#!/usr/bin/env python3
"""Independent Phase 4 ancestry, requirements and scope audit."""

from __future__ import annotations

import csv
import re
import subprocess
import sys
from pathlib import Path


BASELINE = "70c02a277ea7d472ccf6e9a7533b2b41ed7eab5a"
PACKAGE_HEADS = (
    ("P4.0", "260d54518f4cfea2499b586a0e742f86d8d1e1be"),
    ("P4.1", "77a780f0f3c7bb01a6e846b51c2049cd64ca6fbf"),
    ("P4.2", "9d50924fe06f60652f042864874d6e37c261a739"),
    ("P4.3", "ed6c6f301d6c438d334b188dc752dff378f789c1"),
    ("P4.4", "3db095463bfc7bc64bd0ce198951ba0f805c6015"),
)
EXPECTED_ROWS = 689
EXPECTED_REQUIREMENTS = [f"P4-R{index:02d}" for index in range(1, 21)]


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
            "usage: audit_phase4_exit.py REPO EVIDENCE HEAD G99 P45_HEAD"
        )
    repo = Path(sys.argv[1]).resolve()
    evidence = Path(sys.argv[2]).resolve()
    expected_head = sys.argv[3]
    g99_root = Path(sys.argv[4]).resolve()
    p45_head = sys.argv[5]

    require(git(repo, "rev-parse", "HEAD") == expected_head,
            "head mismatch")
    require(git(repo, "branch", "--show-current") ==
            "MITGCM-BOM/development", "development branch required")
    require(git(repo, "status", "--porcelain=v1") == "",
            "dirty worktree")
    require(git(repo, "tag", "-l", "MITGCM-BOM-v0.5") == "",
            "v0.5 already exists")
    require(git(repo, "rev-parse", "MITGCM-BOM-v0.4^{commit}") ==
            BASELINE, "v0.4 baseline mismatch")

    g99_rows = read_tsv(g99_root / "row-audit.tsv")
    require(g99_rows[-1] == {
        "group": "TOTAL", "expected": str(EXPECTED_ROWS),
        "actual": str(EXPECTED_ROWS), "result": "PASS"
    }, "P4-G99 total differs from 689/689")
    require((g99_root / "source-head.txt").read_text(
        encoding="utf-8").strip() == expected_head,
        "P4-G99 exact head mismatch")
    require((g99_root / "independent-audit.log").read_text(
        encoding="utf-8").startswith("P4-G99 FINAL AUDIT PASS"),
        "P4-G99 independent audit missing")

    package_heads = PACKAGE_HEADS + (("P4.5", p45_head),)
    for label, package_head in package_heads:
        subprocess.check_call(
            ["git", "-C", str(repo), "merge-base", "--is-ancestor",
             package_head, expected_head]
        )
        identity = git(
            repo, "show", "-s", "--format=%an%x09%ae", package_head
        ).split("\t")
        require(identity == ["WangYuLin", "wang111936@outlook.com"],
                f"{label}: package author identity changed: {identity}")

    first_parent = git(
        repo, "rev-list", "--first-parent", "--reverse",
        f"{BASELINE}..{expected_head}"
    ).splitlines()
    merge_positions: list[int] = []
    merge_rows: list[str] = []
    for label, package_head in package_heads:
        matches: list[tuple[int, str]] = []
        for position, commit in enumerate(first_parent):
            parents = git(repo, "rev-list", "--parents", "-n", "1",
                          commit).split()
            if len(parents) >= 3 and parents[2] == package_head:
                matches.append((position, commit))
        require(len(matches) == 1,
                f"{label}: expected one dedicated first-parent merge")
        position, merge_commit = matches[0]
        merge_positions.append(position)
        merge_rows.append(
            f"{label}\t{package_head}\t{merge_commit}\t"
            f"{git(repo, 'show', '-s', '--format=%s', merge_commit)}"
        )
    require(merge_positions == sorted(merge_positions) and
            len(set(merge_positions)) == len(merge_positions),
            "P4 package merge order changed")
    (evidence / "package-merges.tsv").write_text(
        "package\tpackage_head\tmerge_commit\tsubject\n" +
        "\n".join(merge_rows) + "\n", encoding="utf-8"
    )

    traceability = (repo / "verification/bom/phase04-biology-land/"
                    "REQUIREMENTS_TRACEABILITY.md").read_text(
                        encoding="utf-8")
    found_requirements = re.findall(r"\| (P4-R\d{2}) \|", traceability)
    require(found_requirements == EXPECTED_REQUIREMENTS,
            "P4-R01--P4-R20 rows missing, duplicated or reordered")

    size = (repo / "pkg/bom/BOM_SIZE.h").read_text(encoding="ascii")
    for frozen in (
        "bomP4ContainerSchema = 4",
        "bomP4SidecarSchema = 1",
        "bomP4SidecarFields = 4",
        "bomP4ManifestSchema = 1",
        "bomP4EventSchema = 1",
        "bomP4EventFields = 32",
    ):
        require(frozen in size, f"schema constant changed: {frozen}")

    event_source = (repo / "pkg/bom/bom_event_transaction_p43.F").read_text(
        encoding="ascii")
    gather = re.compile(r"CALL\s+MPI_(?:Gather|Gatherv|Allgather|Allgatherv)",
                        re.I)
    require(not gather.search(event_source),
            "event transaction gathers live owners")
    require("CALL BOM_EVENT_PREFLIGHT" in event_source,
            "event capacity preflight missing")
    birth = (repo / "pkg/bom/bom_birth_order.F").read_text(
        encoding="ascii")
    require("capacityValid" in birth and "bomMaxEventBuffer" in birth,
            "bounded birth metadata preflight missing")
    spring = (repo / "pkg/bom/bom_spring_stage.F").read_text(
        encoding="ascii")
    require("No rank enters component collectives" in spring,
            "collective-safe graph preflight marker missing")

    changed = git(repo, "diff", "--name-only",
                  f"{BASELINE}...{expected_head}").splitlines()
    require(changed, "empty Phase 4 diff")
    require(all("skrips" not in path.lower() and
                "codex" not in path.lower() for path in changed),
            "foreign project path in Phase 4 diff")
    added = git(repo, "diff", "--unified=0", f"{BASELINE}...{expected_head}")
    added_lines = "\n".join(
        line[1:] for line in added.splitlines()
        if line.startswith("+") and not line.startswith("+++")
    )
    forbidden_claim = re.compile(
        r"Phase\s*[56].{0,80}(?:STATUS:\s*(?:COMPLETE|CLOSED)|"
        r"(?:IS\s+)?(?:COMPLETE|COMPLETED|IMPLEMENTED|CLOSED))",
        re.I,
    )
    require(not forbidden_claim.search(added_lines),
            "Phase 5/6 completion claim leaked into Phase 4")

    print(
        "PHASE 4 INDEPENDENT EXIT AUDIT PASS: "
        f"head={expected_head} rows={EXPECTED_ROWS} "
        f"requirements={len(EXPECTED_REQUIREMENTS)} merges={len(package_heads)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
