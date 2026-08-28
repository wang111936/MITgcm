#!/usr/bin/env python3
"""Independent post-integration audit for the Phase 3 release decision."""

from __future__ import annotations

import csv
import subprocess
import sys
from pathlib import Path


EXPECTED_TOTAL = 538


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True
    ).strip()


def is_ancestor(repo: Path, ancestor: str, descendant: str) -> bool:
    return subprocess.run(
        ["git", "-C", str(repo), "merge-base", "--is-ancestor", ancestor, descendant],
        check=False,
    ).returncode == 0


def main() -> int:
    if len(sys.argv) != 6:
        raise SystemExit(
            "usage: audit_phase3_exit.py REPO G99 HEAD P34_HEAD P35_HEAD"
        )
    repo = Path(sys.argv[1]).resolve()
    g99 = Path(sys.argv[2]).resolve()
    head, p34_head, p35_head = sys.argv[3:6]
    require(git(repo, "rev-parse", "HEAD") == head, "development head mismatch")
    require(git(repo, "branch", "--show-current") == "MITGCM-BOM/development",
            "exit audit is not on development")
    require(git(repo, "status", "--porcelain=v1") == "", "dirty worktree")
    require(git(repo, "tag", "-l", "MITGCM-BOM-v0.4") == "", "v0.4 exists")
    require((g99 / "mode.txt").read_text(encoding="ascii").strip() == "final",
            "P3-G99 evidence is not final mode")
    require((g99 / "source-head.txt").read_text(encoding="ascii").strip() == head,
            "P3-G99 source head mismatch")
    rows = list(csv.DictReader(
        (g99 / "row-audit.tsv").open(encoding="ascii"), delimiter="\t"
    ))
    require(rows and rows[-1]["group"] == "TOTAL", "P3-G99 TOTAL missing")
    require(int(rows[-1]["expected"]) == EXPECTED_TOTAL and
            int(rows[-1]["actual"]) == EXPECTED_TOTAL and
            rows[-1]["result"] == "PASS", "P3-G99 total failed")
    require(all(row["result"] == "PASS" for row in rows), "P3-G99 non-PASS row")

    require(is_ancestor(repo, p34_head, head), "P3.4 head not integrated")
    require(is_ancestor(repo, p35_head, head), "P3.5 head not integrated")
    baseline = git(repo, "rev-parse", "MITGCM-BOM-v0.3^{commit}")
    first_parent = git(
        repo, "rev-list", "--first-parent", "--reverse", f"{baseline}..{head}"
    ).splitlines()
    p34_merge: tuple[int, str] | None = None
    p35_merge: tuple[int, str] | None = None
    for index, commit in enumerate(first_parent):
        parents = git(repo, "rev-list", "--parents", "-n", "1", commit).split()
        if len(parents) < 3:
            continue
        second_parent = parents[2]
        has_p34 = is_ancestor(repo, p34_head, second_parent)
        has_p35 = is_ancestor(repo, p35_head, second_parent)
        if has_p34 and not has_p35 and p34_merge is None:
            p34_merge = (index, commit)
        if has_p35 and p35_merge is None:
            p35_merge = (index, commit)
    require(p34_merge is not None, "dedicated P3.4 merge commit missing")
    require(p35_merge is not None, "dedicated P3.5 merge commit missing")
    require(p34_merge[0] < p35_merge[0], "P3.4/P3.5 merge order invalid")

    expected_identity = (
        "WangYuLin <wang111936@outlook.com>|"
        "WangYuLin <wang111936@outlook.com>"
    )
    github_merge_identity = (
        "wang111936 <124120376+wang111936@users.noreply.github.com>|"
        "GitHub <noreply@github.com>"
    )
    commits = git(
        repo, "log", "--format=%H%x09%P%x09%an <%ae>|%cn <%ce>%x09%s",
        f"{baseline}..{head}"
    ).splitlines()
    require(commits, "Phase 3 commit list is empty")
    for entry in commits:
        commit, parents, identity, subject = entry.split("\t", 3)
        is_merge = len(parents.split()) >= 2
        hosted_merge = (
            is_merge and identity == github_merge_identity and
            subject.startswith("Merge PR #")
        )
        require(identity == expected_identity or hosted_merge,
                f"unexpected Phase 3 identity at {commit}")
    print(f"P3.4_MERGE\t{p34_merge[1]}")
    print(f"P3.5_MERGE\t{p35_merge[1]}")
    print(
        f"PHASE3 INDEPENDENT EXIT AUDIT PASS: head={head} "
        f"rows={EXPECTED_TOTAL} p35={p35_head}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
