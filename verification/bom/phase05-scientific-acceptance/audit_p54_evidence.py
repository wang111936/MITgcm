#!/usr/bin/env python3
"""Independent exact-head and evidence audit for the P5.4 production gate."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path


EXPECTED_BUILDS = ("common-mpi1", "common-mpi2", "common-mpi4",
                   "gyre-serial", "gyre-mpi4")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(("git", "-C", str(repo), *args), check=True,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return result.stdout.strip()


def parse_sha_lines(path: Path) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    for line in path.read_text(encoding="ascii").splitlines():
        require("  " in line, f"SHA line framing {path}")
        digest, name = line.split("  ", 1)
        require(len(digest) == 64 and all(char in "0123456789abcdef" for char in digest),
                f"SHA digest {path}")
        rows.append((digest, name))
    require(rows and len({name for _, name in rows}) == len(rows), f"SHA inventory {path}")
    return rows


def verify_inventory(path: Path, relative_root: Path | None = None) -> int:
    rows = parse_sha_lines(path)
    for digest, name in rows:
        target = Path(name)
        if not target.is_absolute():
            require(relative_root is not None, f"relative SHA target {name}")
            target = relative_root / target
        require(target.is_file() and sha256(target) == digest, f"SHA mismatch {target}")
    return len(rows)


def verify_manifest(evidence: Path) -> tuple[int, str]:
    manifest = evidence / "manifest.sha256"
    rows = parse_sha_lines(manifest)
    names = {name for _, name in rows}
    actual = {f"./{path.relative_to(evidence).as_posix()}" for path in evidence.rglob("*")
              if path.is_file() and path.name not in ("manifest.sha256", "independent-audit.json")}
    require(names == actual, "self-manifest exact inventory")
    for digest, name in rows:
        target = evidence / name.removeprefix("./")
        require(target.is_file() and sha256(target) == digest, f"manifest SHA {name}")
    return len(rows), sha256(manifest)


def audit_summary(evidence: Path) -> int:
    lines = (evidence / "summary.tsv").read_text(encoding="ascii").splitlines()
    require(lines[:1] == ["gate\tresult\tdetail"], "summary header")
    rows = [line.split("\t", 2) for line in lines[1:]]
    require(len(rows) in (7, 8) and all(len(row) == 3 and row[1] == "PASS" for row in rows),
            "summary PASS rows")
    names = [row[0] for row in rows]
    require(len(set(names)) == len(names), "summary unique rows")
    for required in ("p5-f01", "p5-o01", "p5-r01", "p5-l01"):
        require(required in names, f"summary missing {required}")
    if len(rows) == 8:
        require("p5.4-independent-audit" in names, "final independent audit row")
    return len(rows)


def audit_reports(evidence: Path) -> dict[str, int]:
    f01 = json.loads((evidence / "p5-f01-audit.json").read_text(encoding="ascii"))
    o01 = json.loads((evidence / "p5-o01-audit.json").read_text(encoding="ascii"))
    r01 = json.loads((evidence / "p5-r01-audit.json").read_text(encoding="ascii"))
    l01 = json.loads((evidence / "p5-l01-audit.json").read_text(encoding="ascii"))
    require(f01["result"] == "PASS" and len(f01["cases"]) == 6 and
            f01["spring_frames"] == 4, "F01 report")
    require(o01["result"] == "PASS" and o01["ocean_pickup_files_exact"] == 80 and
            o01["trajectory_rows_per_layout"] == 30 and
            o01["sparse_replay_rows"] == 30, "O01 report")
    require(r01["result"] == "PASS" and r01["positive_runs"] == 18 and
            r01["changed_decomposition_rejections"] == 2 and
            r01["within_layout_exact_files"] >= 1400, "R01 report")
    require(l01["result"] == "PASS" and l01["days"] == 30 and
            l01["hourly_frames"] == 720 and l01["daily_pickups"] == 30 and
            l01["maximum_mass_budget_error"] == 0.0 and
            l01["within_layout_exact_files"] >= 14000 and
            l01["finite_float64_values"] > 1_000_000, "L01 report")
    return {"f01_cases": len(f01["cases"]),
            "o01_trajectory_rows_per_layout": o01["trajectory_rows_per_layout"],
            "r01_positive_runs": r01["positive_runs"], "l01_frames": l01["hourly_frames"]}


def audit_builds(build_root: Path) -> int:
    require(tuple(sorted(path.name for path in build_root.iterdir()
                         if path.is_dir() and not path.name.endswith("-mods"))) ==
            tuple(sorted(EXPECTED_BUILDS)), "build directory inventory")
    for name in EXPECTED_BUILDS:
        build = build_root / name
        executable = build / "mitgcmuv"
        require(executable.is_file() and os.access(executable, os.X_OK), f"executable {name}")
        command = (build / "command.txt").read_text(encoding="ascii")
        require("-ieee" in command and "-devel" in command, f"scientific flags {name}")
        if name != "gyre-serial":
            require("-mpi" in command, f"MPI flag {name}")
        makefile = (build / "Makefile").read_text(encoding="ascii", errors="replace")
        require("-DLET_RS_BE_REAL4" not in makefile, f"_RS precision {name}")
        symbols = (build / "symbols.txt").read_text(encoding="ascii", errors="replace")
        for symbol in ("bom_main_", "bom_rhs_paper2024_", "bom_event_transaction_",
                       "bom_write_pickup_"):
            require(symbol in symbols, f"symbol {name}/{symbol}")
        mods = build_root / f"{name}-mods"
        require(not list(mods.glob("bom_*.F")), f"BOM source override {name}")
    return len(EXPECTED_BUILDS)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--build-root", type=Path, required=True)
    parser.add_argument("--run-root", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    build_root = args.build_root.resolve()
    run_root = args.run_root.resolve()
    repo = Path("/home/wyl/projects/mitgcm-bom").resolve()
    require(evidence.is_dir() and build_root.is_dir() and run_root.is_dir(), "audit roots")
    head = (evidence / "source-head.txt").read_text(encoding="ascii").strip()
    require(len(head) == 40 and head == git(repo, "rev-parse", "HEAD"), "exact source head")
    require((evidence / "git-status.txt").read_text(encoding="ascii") == "" and
            git(repo, "status", "--porcelain") == "", "clean source status")
    require(git(repo, "merge-base", "--is-ancestor", "MITGCM-BOM-v0.5", head) == "",
            "v0.5 ancestry")
    grep_result = subprocess.run(
        ("git", "-C", str(repo), "grep", "-Iin", "skrips", "--", "pkg/bom",
         "verification/bom/phase05-scientific-acceptance"),
        text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(grep_result.returncode == 1 and grep_result.stdout == "",
            "SKRIPS dependency in P5.4 scope")

    manifest_files, manifest_digest = verify_manifest(evidence)
    summary_rows = audit_summary(evidence)
    reports = audit_reports(evidence)
    builds = audit_builds(build_root)
    executable_hashes = verify_inventory(evidence / "executables.sha256")
    source_hashes = verify_inventory(evidence / "source-files.sha256", repo)
    build_hashes = verify_inventory(evidence / "build-files.sha256")
    run_hashes = verify_inventory(evidence / "run-files.sha256")
    require(executable_hashes == 5, "executable SHA count")
    require((run_root / "p5-o01-normalized.csv").is_file(), "normalized O01 product")
    report = {
        "schema": "MITGCM-BOM-P5.4-independent-audit-v1",
        "result": "PASS",
        "source_head": head,
        "summary_rows": summary_rows,
        "production_builds": builds,
        "manifest_files": manifest_files,
        "manifest_sha256": manifest_digest,
        "executable_hashes": executable_hashes,
        "source_hashes": source_hashes,
        "build_hashes": build_hashes,
        "run_hashes": run_hashes,
        "reports": reports,
    }
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="ascii")
    print(f"P5.4 INDEPENDENT AUDIT PASS rows={summary_rows} builds={builds} "
          f"run_hashes={run_hashes}")


if __name__ == "__main__":
    main()
