#!/usr/bin/env python3
"""Independent cardinality, provenance and authority audit for P5-SA-G99."""

from __future__ import annotations

import ast
import csv
import hashlib
import json
import subprocess
import sys
from pathlib import Path


V05_TAG_OBJECT = "f16e2345cbe596f37fe3434d1b2f23f85ff0ba74"
V05_COMMIT = "1f48a75d4865fa6d5235a4db306e8abe31534f3e"
P55_ADMISSION_BASELINE = "00ce0c39177afacf3eef6e7930a567ed52d3d785"
EXPECTED_TOTAL = 754
EXPECTED_GROUPS = (
    ("p5.1", 18),
    ("p5.2", 17),
    ("p5.3", 22),
    ("p5.4", 8),
    ("phase4-predecessor", 689),
)
P4_GROUPS = (
    ("p41-direct", 31),
    ("p42-direct", 18),
    ("p43-direct", 26),
    ("p44-direct", 57),
    ("p45-b19", 19),
    ("phase3-predecessor", 538),
)
P51_ROWS = (
    "p51-driver-audit",
    "p5-i01-generate",
    "p5-i01-independent-audit",
    "p5-i01-config-and-locks",
    "p5-b01-control-build",
    "p5-b01-serial-debug-build",
    "p5-b01-mpi-debug-build",
    "p5-b01-mpi-optimized-build",
    "p5-b01-symbols-serial-debug",
    "p5-b01-symbols-mpi-debug",
    "p5-b01-symbols-mpi-optimized",
    "p5-b01-source-isolation",
    "p5-b01-real8-reference",
    "p5-b01-control-smoke",
    "p5-b01-linked-smoke",
    "p5-b01-bomoff-bitwise",
    "p5-b01-fingerprints",
    "p51-independent-evidence-audit",
)
P52_ROWS = (
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
    "p52-independent-evidence-audit",
)
P53_ROWS = (
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
    "p53-independent-evidence-audit",
)
P54_ROWS = (
    "p5.4-source-admission",
    "p5.4-production-builds",
    "p5-f01",
    "p5-o01",
    "p5-r01",
    "p5-l01",
    "p5.4-evidence-inventory",
    "p5.4-independent-audit",
)
DIRECT_ROWS = {
    "p5.1": P51_ROWS,
    "p5.2": P52_ROWS,
    "p5.3": P53_ROWS,
    "p5.4": P54_ROWS,
}
EXPECTED_CASES = (
    ("P5-B01", "production-packaging", "p5.1", "p5-b01-production-build", "PRODUCTION"),
    ("P5-I01", "deterministic-input", "p5.1", "p5-i01-independent-audit", "PRODUCTION"),
    ("P5-J01", "locked-julia", "p5.2", "p5-j01-julia-trajectory", "JULIA"),
    ("P5-P01", "paper2024-parity", "p5.3", "p5-p01-paper-oracle", "PAPER2024"),
    ("P5-P02", "paper2024-convergence", "p5.3", "p5-p02-temporal-convergence", "PAPER2024"),
    ("P5-F01", "spring", "p5.4", "p5-f01-audit.json", "PRODUCTION"),
    ("P5-F01", "birth", "p5.4", "p5-f01-audit.json", "PRODUCTION"),
    ("P5-F01", "cancel", "p5.4", "p5-f01-audit.json", "PRODUCTION"),
    ("P5-F01", "death", "p5.4", "p5-f01-audit.json", "PRODUCTION"),
    ("P5-F01", "coast", "p5.4", "p5-f01-audit.json", "PRODUCTION"),
    ("P5-F01", "combined", "p5.4", "p5-f01-audit.json", "PRODUCTION"),
    ("P5-O01", "dynamic-ocean", "p5.4", "p5-o01-audit.json", "PRODUCTION"),
    ("P5-R01", "restart-mpi", "p5.4", "p5-r01-audit.json", "PRODUCTION"),
    ("P5-L01", "endurance", "p5.4", "p5-l01-audit.json", "PRODUCTION"),
)
LOCKS = {
    "verification/bom/phase05-scientific-acceptance/SCIENTIFIC_ACCEPTANCE_PLAN.md":
        "c9d2372d132e48d55b213db293c84cfe67006cf29fa6d7aa2fdfb4b545aefafe",
    "verification/bom/phase05-scientific-acceptance/P5.3_TEST_CONTRACT.md":
        "c321e9ac8edce06ec7371520e95df77b59bfc805f082a0263ed18ac9b8509275",
    "verification/bom/phase05-scientific-acceptance/P5.3_P02_FIXTURE_LOCK.md":
        "078ec8ffb0846463d81e2f75e0312f9e5d36bc002a7ea4983c5a38373dcb404b",
    "verification/bom/phase05-scientific-acceptance/p53_p02_affine_fields.csv":
        "39191181950409246d793257f8f58e63106ed2e9657733018103b9c46d46ce4e",
    "verification/bom/phase05-scientific-acceptance/P5.4_TEST_CONTRACT.md":
        "40febed4351dcd592732e4236801b1829cbc92ba422a5e4800afde7dac200f83",
    "verification/bom/reference/julia_env/Project.toml":
        "12cfb1288a21b19216662a719d430bf41b5587dfd8b00e973f8b3c9c25f1f99d",
    "verification/bom/reference/julia_env/Manifest.toml":
        "86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695",
    "verification/bom/reference/phase02/golden_checksums.sha256":
        "040a001482247088195f8db11538312ba8dbe5a972a1f14f78799b7800d2ab03",
}
ALLOWED_POST_ADMISSION = {
    "verification/bom/phase02-integration-closure/audit_closure.py",
    "verification/bom/phase03-integration-closure/audit_p3_g99.py",
    "verification/bom/phase03-integration-closure/run_p3_g99.sh",
    "verification/bom/phase04-integration-closure/audit_p4_g99.py",
    "verification/bom/phase04-integration-closure/run_p4_g99.sh",
    "verification/bom/phase05-scientific-acceptance/P5.5_TEST_CONTRACT.md",
    "verification/bom/phase05-scientific-acceptance/P5.5_REQUIREMENTS_TRACEABILITY.md",
    "verification/bom/phase05-scientific-acceptance/run_p5_sa_g99.sh",
    "verification/bom/phase05-scientific-acceptance/audit_p5_sa_g99.py",
    "verification/bom/phase05-scientific-acceptance/run_phase5_scientific_exit_audit.sh",
    "verification/bom/phase05-scientific-acceptance/audit_phase5_scientific_exit.py",
    "verification/bom/phase05-scientific-acceptance/P5.5_CLOSEOUT.md",
    "verification/bom/phase05-scientific-acceptance/PHASE5_SCIENTIFIC_EXIT_AUDIT.md",
    "verification/bom/phase05-scientific-acceptance/README.md",
    "verification/bom/README.md",
    "doc/phys_pkgs/MITGCM-BOM/PROJECT_STATUS.md",
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


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON object required: {path}")
    return value


def validate_native_root(
    group: str, root: Path, expected_head: str, expected_rows: tuple[str, ...]
) -> None:
    require(root.is_dir(), f"{group}: evidence root missing: {root}")
    subprocess.check_call(
        ["sha256sum", "-c", "manifest.sha256"], cwd=root,
        stdout=subprocess.DEVNULL,
    )
    require((root / "source-head.txt").read_text(encoding="utf-8").strip()
            == expected_head, f"{group}: native source head mismatch")
    summary = read_tsv(root / "summary.tsv")
    name_key = "gate" if group == "p5.4" else "case"
    require(tuple(row[name_key] for row in summary) == expected_rows,
            f"{group}: native row names/order changed")
    require(all(row["result"] == "PASS" for row in summary),
            f"{group}: native non-PASS row")
    expected_file = root / "expected-final.txt"
    if expected_file.exists():
        frozen = tuple(expected_file.read_text(encoding="utf-8").splitlines())
        require(frozen == expected_rows,
                f"{group}: expected-final inventory changed")
    audit = read_json(root / "independent-audit.json")
    require(audit.get("result") == "PASS",
            f"{group}: native independent audit failed")
    require(audit.get("source_head") == expected_head,
            f"{group}: independent audit head mismatch")


def validate_p4(root: Path, expected_head: str) -> None:
    subprocess.check_call(
        ["sha256sum", "-c", "manifest.sha256"], cwd=root,
        stdout=subprocess.DEVNULL,
    )
    require((root / "source-head.txt").read_text(encoding="utf-8").strip()
            == expected_head, "Phase 4 predecessor head mismatch")
    require((root / "mode.txt").read_text(encoding="utf-8").strip()
            == "predecessor", "Phase 4 gate did not use predecessor mode")
    rows = read_tsv(root / "row-audit.tsv")
    require(tuple((row["group"], int(row["expected"])) for row in rows[:-1])
            == P4_GROUPS, "Phase 4 group order/count changed")
    require(all(int(row["actual"]) == expected and row["result"] == "PASS"
                for row, (_, expected) in zip(rows[:-1], P4_GROUPS)),
            "Phase 4 group failed")
    require(rows[-1] == {"group": "TOTAL", "expected": "689",
                         "actual": "689", "result": "PASS"},
            "Phase 4 predecessor total differs from 689/689")
    require(len(read_tsv(root / "all-rows.tsv")) == 689,
            "Phase 4 all-row cardinality changed")
    marker = (root / "independent-audit.log").read_text(encoding="utf-8")
    require(marker.startswith("P4-G99 PREDECESSOR AUDIT PASS"),
            "Phase 4 predecessor independent marker missing")


def validate_oracle_isolation(repo: Path) -> None:
    oracle = repo / ("verification/bom/phase05-scientific-acceptance/"
                     "generate_p53_paper_oracle.py")
    source = oracle.read_text(encoding="ascii")
    tree = ast.parse(source)
    allowed = {"__future__", "argparse", "csv", "hashlib", "json",
               "decimal", "pathlib"}
    imports: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imports.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            imports.add((node.module or "").split(".")[0])
    require(imports <= allowed,
            f"PAPER2024 oracle imports changed: {sorted(imports - allowed)}")
    lowered = source.lower()
    for token in ("pkg/bom", "bom_rhs_", "mitgcmuv", "subprocess",
                  "ctypes", "f2py"):
        require(token not in lowered,
                f"PAPER2024 oracle production coupling: {token}")


def main() -> int:
    if len(sys.argv) != 7:
        raise SystemExit(
            "usage: audit_p5_sa_g99.py REPO EVIDENCE HEAD TOTAL "
            "SARGASSUM_ROOT JULIA_BIN"
        )
    repo = Path(sys.argv[1]).resolve()
    evidence = Path(sys.argv[2]).resolve()
    expected_head = sys.argv[3]
    expected_total = int(sys.argv[4])
    sargassum = Path(sys.argv[5]).resolve()
    julia = Path(sys.argv[6]).resolve()

    require(expected_total == EXPECTED_TOTAL, "aggregate total constant changed")
    require(git(repo, "rev-parse", "HEAD") == expected_head, "head mismatch")
    branch = git(repo, "branch", "--show-current")
    require(branch.startswith("MITGCM-BOM/"), "MITGCM-BOM branch required")
    require(git(repo, "status", "--porcelain=v1") == "", "dirty worktree")
    require(git(repo, "rev-parse", "MITGCM-BOM-v0.5") == V05_TAG_OBJECT,
            "v0.5 annotated tag object changed")
    require(git(repo, "rev-parse", "MITGCM-BOM-v0.5^{commit}") == V05_COMMIT,
            "v0.5 peeled commit changed")
    subprocess.check_call(
        ["git", "-C", str(repo), "merge-base", "--is-ancestor",
         V05_COMMIT, expected_head]
    )
    subprocess.check_call(
        ["git", "-C", str(repo), "merge-base", "--is-ancestor",
         P55_ADMISSION_BASELINE, expected_head]
    )
    require((evidence / "source-head.txt").read_text(encoding="utf-8").strip()
            == expected_head, "aggregate source head mismatch")
    require((evidence / "candidate-branch.txt").read_text(
        encoding="utf-8").strip() == branch, "candidate branch mismatch")
    require((evidence / "tags-before.txt").read_bytes() ==
            (evidence / "tags-after.txt").read_bytes(),
            "source tag refs changed during P5-SA-G99")

    row_audit = read_tsv(evidence / "row-audit-candidate.tsv")
    require(tuple((row["group"], int(row["expected"]))
                  for row in row_audit[:-1]) == EXPECTED_GROUPS,
            "aggregate group order/count changed")
    for row, (_, expected) in zip(row_audit[:-1], EXPECTED_GROUPS):
        require(int(row["actual"]) == expected and row["result"] == "PASS",
                f"aggregate group failed: {row['group']}")
    require(row_audit[-1] == {
        "group": "TOTAL", "expected": "754", "actual": "754",
        "result": "PASS"
    }, "aggregate total differs from 754/754")

    provenance = read_tsv(evidence / "provenance.tsv")
    require(tuple(row["group"] for row in provenance) ==
            tuple(name for name, _ in EXPECTED_GROUPS),
            "provenance group inventory changed")
    roots = {row["group"]: Path(row["evidence_root"]).resolve()
             for row in provenance}
    roots_table = read_tsv(evidence / "roots.tsv")
    require(tuple(row["group"] for row in roots_table) ==
            tuple(name for name, _ in EXPECTED_GROUPS),
            "explicit root group inventory changed")
    require(all(Path(row["artifact_root"]).resolve() == roots[row["group"]]
                for row in roots_table), "root/provenance disagreement")
    for group, rows in DIRECT_ROWS.items():
        validate_native_root(group, roots[group], expected_head, rows)
        require(sha256(roots[group] / "independent-audit.json") ==
                sha256(evidence / "native-audits" / f"{group}.json"),
                f"{group}: copied independent audit differs")
    validate_p4(roots["phase4-predecessor"], expected_head)

    all_rows = read_tsv(evidence / "all-rows.tsv")
    require(len(all_rows) == EXPECTED_TOTAL, "all-row cardinality mismatch")
    require(all(row["result"] == "PASS" for row in all_rows),
            "aggregate contains a non-PASS row")
    distribution = {
        group: sum(row["package"] == group for row in all_rows)
        for group, _ in EXPECTED_GROUPS
    }
    require(tuple(distribution.items()) == EXPECTED_GROUPS,
            f"all-row group distribution changed: {distribution}")
    keys = [(row["package"], row["group"], row["case"])
            for row in all_rows]
    require(len(keys) == len(set(keys)), "duplicate aggregate row key")
    for group, expected_rows in DIRECT_ROWS.items():
        actual = tuple(row["case"] for row in all_rows
                       if row["package"] == group)
        require(actual == expected_rows, f"{group}: aggregate row order changed")

    inventory = read_tsv(evidence / "acceptance-inventory.tsv")
    observed = tuple((row["decision"], row["case"], row["group"],
                      row["locator"], row["authority"])
                     for row in inventory)
    require(observed == EXPECTED_CASES, "required scientific case inventory changed")
    require(all(row["result"] == "PASS" for row in inventory),
            "required scientific case failed")
    p54 = roots["p5.4"]
    f01 = read_json(p54 / "p5-f01-audit.json")
    require(f01.get("result") == "PASS" and
            f01.get("cases") == ["spring", "birth", "cancel", "death",
                                 "coast", "combined"],
            "P5-F01 native case inventory changed")
    o01 = read_json(p54 / "p5-o01-audit.json")
    r01 = read_json(p54 / "p5-r01-audit.json")
    l01 = read_json(p54 / "p5-l01-audit.json")
    require(o01.get("result") == "PASS" and
            o01.get("trajectory_rows_per_layout") == 30,
            "P5-O01 native evidence failed")
    require(r01.get("result") == "PASS" and
            r01.get("positive_runs") == 18 and
            r01.get("changed_decomposition_rejections") == 2,
            "P5-R01 native evidence failed")
    require(l01.get("result") == "PASS" and l01.get("days") == 30 and
            l01.get("hourly_frames") == 720,
            "P5-L01 native evidence failed")

    for relative, expected in LOCKS.items():
        require(sha256(repo / relative) == expected,
                f"frozen authority hash changed: {relative}")
    require(julia.is_file(), "locked Julia executable missing")
    version = subprocess.check_output(
        [str(julia), "--startup-file=no", "--version"], text=True
    ).strip()
    require(version == "julia version 1.10.12", "locked Julia version changed")
    require(git(sargassum, "rev-parse", "HEAD") ==
            "156557359185e4413ce82829f3ed26a4eb8c6283",
            "SargassumBOMB commit changed")
    require(sha256(sargassum / "src/physics.jl") ==
            "1acef9ed3c8d13646c95799565387a4add76e839827cea1c0e745ced73f1885d",
            "locked physics.jl hash changed")
    validate_oracle_isolation(repo)

    modified = git(
        repo, "diff", "--name-only", f"{P55_ADMISSION_BASELINE}...{expected_head}"
    ).splitlines()
    require(set(modified) <= ALLOWED_POST_ADMISSION,
            f"post-admission source or scientific rule changed: "
            f"{sorted(set(modified) - ALLOWED_POST_ADMISSION)}")
    changed_from_v05 = git(
        repo, "diff", "--name-only", f"{V05_COMMIT}...{expected_head}"
    ).splitlines()
    for path in changed_from_v05:
        lowered = path.lower()
        require("skrips" not in lowered and "codex" not in lowered,
                f"foreign project path in candidate: {path}")
    phase5 = repo / "verification/bom/phase05-scientific-acceptance"
    overrides = sorted(path for path in phase5.rglob("bom_*.F")
                       if "code" in path.parts)
    require(not overrides, f"production BOM verification override: {overrides}")
    require(not any(path.is_symlink() for path in phase5.rglob("*")),
            "symlink found in Phase 5 scientific source")

    expected_actual = read_tsv(evidence / "expected-actual-inventory.tsv")
    require(len(expected_actual) == len(EXPECTED_GROUPS) + 1 +
            len(EXPECTED_CASES), "expected/actual control count changed")
    require(all(row["result"] == "PASS" and
                row["expected"] == row["actual"] for row in expected_actual),
            "expected/actual inventory failed")
    print(
        "P5-SA-G99 INDEPENDENT AUDIT PASS: "
        f"head={expected_head} rows={EXPECTED_TOTAL} "
        f"cases={len(EXPECTED_CASES)} roots={len(provenance)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
