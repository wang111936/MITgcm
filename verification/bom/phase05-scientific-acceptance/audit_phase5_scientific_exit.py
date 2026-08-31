#!/usr/bin/env python3
"""Independent requirements-level exit audit for Phase 5 scientific acceptance."""

from __future__ import annotations

import ast
import csv
import hashlib
import json
import re
import subprocess
import sys
from collections import OrderedDict
from pathlib import Path, PurePosixPath


V05_TAG_OBJECT = "f16e2345cbe596f37fe3434d1b2f23f85ff0ba74"
V05_COMMIT = "1f48a75d4865fa6d5235a4db306e8abe31534f3e"
EXPECTED_TOTAL = 754
DECISIONS = tuple(f"P5-D{index:03d}" for index in range(1, 22))
EXPECTED_GROUPS = OrderedDict((
    ("p5.1", 18),
    ("p5.2", 17),
    ("p5.3", 22),
    ("p5.4", 8),
    ("phase4-predecessor", 689),
))
PRODUCTION_DIFF_EXACT = {
    "eesupp/src/ini_procs.F",
    "pkg/bom/bom_build_endpoints.F",
    "pkg/bom/bom_build_fields.F",
    "pkg/bom/bom_event_transaction_p43.F",
    "pkg/bom/bom_fill_cgrid_boundary.F",
    "pkg/bom/bom_read_initial.F",
    "pkg/bom/bom_terminal_plan.F",
}
ALLOWED_EXACT = PRODUCTION_DIFF_EXACT | {
    "verification/bom/README.md",
    "pkg/bom/README.md",
    "pkg/bom/BOM_INPUT_OUTPUT_REFERENCE.md",
    "pkg/bom/BOM_PARAMETER_REFERENCE.md",
    "verification/bom/phase02-integration-closure/audit_closure.py",
    "verification/bom/phase03-integration-closure/audit_p3_g99.py",
    "verification/bom/phase03-integration-closure/run_p3_g99.sh",
    "verification/bom/phase04-integration-closure/audit_p4_g99.py",
    "verification/bom/phase04-integration-closure/run_p4_g99.sh",
}
ALLOWED_PREFIXES = (
    "verification/bom/phase05-scientific-acceptance/",
    "verification/tutorial_MITGCM-BOM/",
    "doc/phys_pkgs/MITGCM-BOM/",
)
FROZEN_HASHES = {
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
    "verification/bom/phase05-scientific-acceptance/generate_p51_inputs.py":
        "88a544ed70b59047cc1d890645cd8b70f9499c4ac6d45d37f1902cf6bf66d2a1",
    "verification/bom/phase05-scientific-acceptance/generate_p52_reference.jl":
        "2554b2b74bcccd3e5137bb3ea84720cdc30e92692c0f2e692aa9141af67bce03",
    "verification/bom/phase05-scientific-acceptance/generate_p53_inputs.py":
        "a41dfdc5a894bc29c8bc8b6ba29f93734b4a99f36c0ac59d16f4e0812fb60876",
    "verification/bom/phase05-scientific-acceptance/generate_p53_paper_oracle.py":
        "dfe444662ce61bfaf0cce808e661d1d7adf3114cd9afbe23525e49b8f27c096b",
    "verification/bom/phase05-scientific-acceptance/compare_p52_julia.py":
        "1d0cc54ba7c43f73e8449cac8b27e4bbea32a65b948be7fbe8e859eb1c1e9365",
    "verification/bom/phase05-scientific-acceptance/compare_p53_paper2024.py":
        "f16ab6ab44f7defa74217474e9e646ee085ebaf4f0d8ed7bf7aab8fbd999ea5b",
    "verification/bom/phase05-scientific-acceptance/generate_p54_inputs.py":
        "d96c44eeeaeab77de02b65fa8354ee664e75f32f0d2e47b1f8b33958c1545490",
    "verification/bom/phase05-scientific-acceptance/generate_p54_gyre.py":
        "d016721bbc1497fe59737bdf53c3db890bbdd2c6c379de03e68e159ed10e3d58",
    "verification/bom/phase05-scientific-acceptance/prepare_p54_restart.py":
        "4acc5cb733f3f7a52f89a91acfd6685653f1795f19c925cab096145f5a3f3b7f",
    "verification/bom/phase05-scientific-acceptance/generate_p54_longrun.py":
        "f03d9341046575590f98959e16a796de6edba33f03d4b72d153c2605938f7bb1",
    "verification/bom/phase05-scientific-acceptance/audit_p54_f01.py":
        "dc52dcf5f6ecf7b940a4884c6b96f136636b1f745dc919bdc4849380c429ec13",
    "verification/bom/phase05-scientific-acceptance/audit_p54_o01.py":
        "6ebf7ccd0d2faf18a579bf0468178507efb9a6daf1bc9249be489840a0cc2c97",
    "verification/bom/phase05-scientific-acceptance/audit_p54_r01.py":
        "ad2a1e7f51f8ac101a766b9424c6e7330bf0d4e177108353cf2560854aa460d5",
    "verification/bom/phase05-scientific-acceptance/audit_p54_l01.py":
        "1c4b83891b1e97ed62b55c7bd87d8d65daccd12f0aa13478dcd065e4eab0abcb",
    "verification/bom/reference/julia_env/Project.toml":
        "12cfb1288a21b19216662a719d430bf41b5587dfd8b00e973f8b3c9c25f1f99d",
    "verification/bom/reference/julia_env/Manifest.toml":
        "86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695",
    "verification/bom/reference/phase02/context_checksums.sha256":
        "0afafbc5c56a173db66298f1f3586d17c5fb7fb313fae4165719676625977724",
    "verification/bom/reference/phase02/golden_checksums.sha256":
        "040a001482247088195f8db11538312ba8dbe5a972a1f14f78799b7800d2ab03",
    "verification/bom/reference/phase02/input_checksums.sha256":
        "1eabce204e5454c926199aaf2c1dce31e49b0663696688c764ca2b3a59a305d3",
}
CORE_HASHES = {
    "pkg/bom/bom_rhs_julia.F":
        "5a373abf14483528b8a08d261c05c73bd49b84da1e790c6691c149d15b1009e4",
    "pkg/bom/bom_rhs_paper2024.F":
        "dfef40046b8b373f609a00716b78876d80f6d2f3cab756bbf3057b553fa331cb",
    "pkg/bom/bom_rhs_slow_manifold.F":
        "341d3d54dabe4a6a3382b28da09f04f8351c6d1af3d6e1fcf62031b31639961e",
    "pkg/bom/bom_rk4.F":
        "4b96b8672581d0ed0a10a8c03eeb14af8b821d3729550cf186a0c0118cd80463",
    "pkg/bom/bom_rk2.F":
        "cbd224bf50aec009de61dda9a52647f009d466b29e48f14e858bfedd55140151",
    "model/src/forward_step.F":
        "0e6ff55e466c7348d138c33777207a57b6d1a4d2e1b51d6cb8f901581c310a42",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True
    ).strip()


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def load_json(path: Path, schema: str | None = None) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"{path}: object required")
    if schema is not None:
        require(value.get("schema") == schema, f"{path}: schema changed")
    require(value.get("result") == "PASS", f"{path}: result is not PASS")
    return value


def verify_manifest(root: Path, name: str = "manifest.sha256") -> int:
    root = root.resolve()
    manifest = root / name
    require(manifest.is_file(), f"manifest missing: {manifest}")
    seen: set[str] = set()
    for line in manifest.read_text(encoding="ascii").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (\*?)(.+)", line)
        require(match is not None, f"{manifest}: malformed row")
        digest, _, raw = match.groups()
        rel = PurePosixPath(raw.removeprefix("./"))
        require(not rel.is_absolute() and ".." not in rel.parts,
                f"{manifest}: path escape")
        key = str(rel)
        require(key not in seen, f"{manifest}: duplicate {key}")
        seen.add(key)
        target = (root / key).resolve(strict=True)
        require(target.is_relative_to(root), f"{manifest}: resolved escape")
        require(target.is_file() and sha256(target) == digest,
                f"{manifest}: hash mismatch {key}")
    require(seen, f"{manifest}: empty")
    return len(seen)


def source_audit(repo: Path, head: str) -> tuple[list[str], set[str]]:
    require(git(repo, "rev-parse", "HEAD") == head, "HEAD mismatch")
    require(git(repo, "status", "--porcelain=v1") == "", "dirty source tree")
    require(git(repo, "rev-parse", "MITGCM-BOM-v0.5") == V05_TAG_OBJECT,
            "v0.5 tag object changed")
    require(git(repo, "rev-parse", "MITGCM-BOM-v0.5^{commit}") == V05_COMMIT,
            "v0.5 peeled commit changed")
    subprocess.check_call(
        ["git", "-C", str(repo), "merge-base", "--is-ancestor",
         V05_COMMIT, head]
    )
    changed = git(repo, "diff", "--name-only", f"{V05_COMMIT}...{head}").splitlines()
    for path in changed:
        lowered = path.lower()
        require("skrips" not in lowered and "codex" not in lowered,
                f"foreign project path: {path}")
        require(path in ALLOWED_EXACT or path.startswith(ALLOWED_PREFIXES),
                f"path outside frozen P5 scope: {path}")
    production = {
        path for path in changed
        if path.endswith((".F", ".F90", ".c", ".h"))
        and not path.startswith(("verification/", "doc/"))
        and path not in {
            "pkg/bom/BOM_INPUT_OUTPUT_REFERENCE.md",
            "pkg/bom/BOM_PARAMETER_REFERENCE.md",
        }
    }
    require(production == PRODUCTION_DIFF_EXACT,
            f"production diff changed: {sorted(production)}")
    for table in (FROZEN_HASHES, CORE_HASHES):
        for relative, expected in table.items():
            require(sha256(repo / relative) == expected,
                    f"frozen hash changed: {relative}")
    return changed, production


def ensure_external_root(path: Path, repo: Path, prefix: Path) -> Path:
    require(path.is_absolute() and not path.is_symlink(),
            f"root is not absolute/non-symlink: {path}")
    resolved = path.resolve(strict=True)
    require(not resolved.is_relative_to(repo.resolve()),
            f"root lies inside source: {resolved}")
    require(resolved.is_relative_to(prefix.resolve()),
            f"root outside admitted base {prefix}: {resolved}")
    return resolved


def scan_mods(build_root: Path) -> tuple[int, int]:
    mods_dirs = sorted(path for path in build_root.rglob("*-mods") if path.is_dir())
    require(mods_dirs, f"no build mods under {build_root}")
    files = 0
    for mods in mods_dirs:
        for path in mods.iterdir():
            if not path.is_file():
                continue
            files += 1
            require(not (path.name.lower().startswith("bom_") and
                         path.suffix.lower() in {".f", ".f90"}),
                    f"production BOM override: {path}")
            require(path.name in {"CPP_OPTIONS.h", "CD_CODE_OPTIONS.h",
                                  "CPP_EEOPTIONS.h", "DIAGNOSTICS_SIZE.h",
                                  "SIZE.h", "SIZE.h_mpi", "packages.conf"},
                    f"unexpected build-mod source: {path}")
    return len(mods_dirs), files


def main() -> int:
    if len(sys.argv) != 7:
        raise SystemExit(
            "usage: audit_phase5_scientific_exit.py REPO EXIT_EVIDENCE "
            "HEAD G99_ROOT SARGASSUM_ROOT JULIA_BIN"
        )
    repo = Path(sys.argv[1]).resolve()
    exit_evidence = Path(sys.argv[2]).resolve()
    head = sys.argv[3]
    g99 = Path(sys.argv[4]).resolve()
    sargassum = Path(sys.argv[5]).resolve()
    julia = Path(sys.argv[6]).resolve()
    changed, production = source_audit(repo, head)
    g99_manifest_files = verify_manifest(g99)
    require((g99 / "source-head.txt").read_text(encoding="utf-8").strip()
            == head, "G99 source head mismatch")
    require((g99 / "git-status-before.txt").read_text(encoding="utf-8") == "" and
            (g99 / "git-status-after.txt").read_text(encoding="utf-8") == "",
            "G99 source was not clean before/after")
    require((g99 / "independent-audit.log").read_text(
        encoding="utf-8").startswith("P5-SA-G99 INDEPENDENT AUDIT PASS"),
        "G99 independent marker missing")
    rows = read_tsv(g99 / "row-audit.tsv")
    require(tuple((row["group"], int(row["expected"])) for row in rows[:-1])
            == tuple(EXPECTED_GROUPS.items()), "G99 groups changed")
    require(all(int(row["actual"]) == expected and row["result"] == "PASS"
                for row, expected in zip(rows[:-1], EXPECTED_GROUPS.values())),
            "G99 group failure")
    require(rows[-1] == {"group": "TOTAL", "expected": "754",
                         "actual": "754", "result": "PASS"},
            "G99 total is not 754/754")

    root_rows = read_tsv(g99 / "roots.tsv")
    require(tuple(row["group"] for row in root_rows) ==
            tuple(EXPECTED_GROUPS), "root inventory changed")
    roots: dict[str, dict[str, Path]] = {}
    for row in root_rows:
        group = row["group"]
        artifact = ensure_external_root(
            Path(row["artifact_root"]), repo,
            Path("/home/wyl/projects/mitgcm-bom-test-artifacts"),
        )
        build_prefix = Path("/home/wyl/build/mitgcm-bom")
        run_prefix = Path("/home/wyl/runs/mitgcm-bom")
        build = ensure_external_root(Path(row["build_root"]), repo, build_prefix)
        if group == "phase4-predecessor":
            run = ensure_external_root(Path(row["run_root"]), repo, build_prefix)
        else:
            run = ensure_external_root(Path(row["run_root"]), repo, run_prefix)
        roots[group] = {"artifact": artifact, "build": build, "run": run}
        require(g99.name in artifact.as_posix() or g99.name in build.as_posix(),
                f"{group}: root is not bound to aggregate attempt")
    require(len({str(value) for group in roots.values()
                 for value in group.values()}) >= 13,
            "roots unexpectedly alias each other")
    child_manifest_files = {
        group: verify_manifest(paths["artifact"])
        for group, paths in roots.items()
    }
    for group in ("p5.1", "p5.2", "p5.3", "p5.4"):
        require(sha256(roots[group]["artifact"] / "independent-audit.json") ==
                sha256(g99 / "native-audits" / f"{group}.json"),
                f"{group}: native/aggregate audit copy mismatch")

    p51 = load_json(roots["p5.1"]["artifact"] / "independent-audit.json",
                    "MITGCM-BOM-P5.1-EVIDENCE-v1")
    p52 = load_json(roots["p5.2"]["artifact"] / "independent-audit.json",
                    "MITGCM-BOM-P5.2-EVIDENCE-v1")
    p53 = load_json(roots["p5.3"]["artifact"] / "independent-audit.json",
                    "MITGCM-BOM-P5.3-EVIDENCE-v1")
    p54 = load_json(roots["p5.4"]["artifact"] / "independent-audit.json",
                    "MITGCM-BOM-P5.4-independent-audit-v1")
    for report in (p51, p52, p53, p54):
        require(report.get("source_head") == head,
                "child independent report head mismatch")
    f01 = load_json(roots["p5.4"]["artifact"] / "p5-f01-audit.json",
                    "MITGCM-BOM-P5-F01-audit-v1")
    o01 = load_json(roots["p5.4"]["artifact"] / "p5-o01-audit.json",
                    "MITGCM-BOM-P5-O01-audit-v1")
    r01 = load_json(roots["p5.4"]["artifact"] / "p5-r01-audit.json",
                    "MITGCM-BOM-P5-R01-audit-v1")
    l01 = load_json(roots["p5.4"]["artifact"] / "p5-l01-audit.json",
                    "MITGCM-BOM-P5-L01-audit-v1")
    p52_result = load_json(
        roots["p5.2"]["artifact"] / "comparison-result.json",
        "MITGCM-BOM-P5-J01-result-v1",
    )
    p53_result = load_json(
        roots["p5.3"]["artifact"] / "comparison-result.json",
        "MITGCM-BOM-P5.3-result-v1",
    )
    oracle = json.loads((roots["p5.3"]["artifact"] /
                         "oracle-manifest.json").read_text(encoding="utf-8"))

    trace: list[dict[str, str]] = []
    def passed(decision: str, detail: str) -> None:
        require(decision == DECISIONS[len(trace)],
                f"decision order changed at {decision}")
        trace.append({"decision": decision, "result": "PASS", "evidence": detail})

    input_audit = json.loads((roots["p5.1"]["artifact"] /
                              "input-audit.json").read_text(encoding="utf-8"))
    require(input_audit == input_audit | {
        "schema": "MITGCM-BOM-P5-I01-v1", "result": "PASS",
        "particles": 3, "time_records": 97,
    }, "P5-I01 input identity changed")
    require(p52["trajectory_rows"] == 291 and
            p53["p01_trajectory_rows"] == 291 and
            f01["spring_frames"] == 4 and o01["trajectory_rows_per_layout"] == 30 and
            l01["hourly_frames"] == 720,
            "positive integration step inventory changed")
    reconciliation = (repo / ("verification/bom/phase05-scientific-acceptance/"
                              "P5.5_TEST_CONTRACT.md")).read_text(encoding="utf-8")
    require("specialised one-step definitions control for\ncommit count" in reconciliation,
            "D001 specialised F01 reconciliation missing")
    passed("P5-D001", "I01 particles=3/times=97; J/P=96 steps; spring=4; O01=10; L01=720; specialised F01 one-step probes declared pre-run")

    forward = (repo / "model/src/forward_step.F").read_text(encoding="ascii")
    require(len(re.findall(r"CALL\s+BOM_MAIN", forward, re.I)) == 1,
            "FORWARD_STEP does not call BOM_MAIN exactly once")
    require(p52["mpi_rank_bom_calls"] == 384 and
            p53["mpi_rank_bom_calls"] == 3072 and
            l01["bom_timer_rank_calls"] == 5760,
            "production BOM call inventory changed")
    passed("P5-D002", "FORWARD_STEP has one BOM_MAIN call; P52/P53/L01 calls=384/3072/5760")

    mod_counts = {group: scan_mods(paths["build"])
                  for group, paths in roots.items()
                  if group != "phase4-predecessor"}
    passed("P5-D003", f"no bom_*.F/F90 override in {sum(v[0] for v in mod_counts.values())} build-mod directories")
    passed("P5-D004", f"all {sum(v[1] for v in mod_counts.values())} mod files are admitted SIZE/package/options headers")

    require(p51["builds"] == ["control-serial-debug", "serial-debug",
                              "mpi-debug", "mpi-optimized"] and
            p54["production_builds"] == 5,
            "production build matrices changed")
    passed("P5-D005", "all child reports use exact head; P51=4 builds and P54=5 builds")

    production_text = "\n".join(path.read_text(encoding="ascii", errors="ignore")
                                 for path in (repo / "pkg/bom").glob("*.F"))
    require(not re.search(r"#include\s+[\"<]OFFLINE|CALL\s+OFFLINE_", production_text,
                          re.I), "OFFLINE became a pkg/bom dependency")
    passed("P5-D006", "pkg/bom has no OFFLINE include/call; OFFLINE remains case provider")

    require(input_audit["binary_field_checks"] == 299 and
            input_audit["file_count"] == 313,
            "native C-grid input inventory changed")
    passed("P5-D007", "independent P5-I01 reader: 299 binary checks, 313 files, 97 native-time records")

    require(p52["component_comparisons"] == 8352 and
            p52_result["components"]["tolerance"] == {
                "absolute": 2e-12, "relative": 5e-12} and
            p52_result["trajectory"]["tolerance"] == {
                "absolute_m": 1e-6, "relative_to_reference_path": 5e-11},
            "locked Julia comparison changed")
    require(julia.is_file() and subprocess.check_output(
        [str(julia), "--startup-file=no", "--version"], text=True
    ).strip() == "julia version 1.10.12", "Julia version changed")
    require(git(sargassum, "rev-parse", "HEAD") ==
            "156557359185e4413ce82829f3ed26a4eb8c6283" and
            sha256(sargassum / "src/physics.jl") ==
            "1acef9ed3c8d13646c95799565387a4add76e839827cea1c0e745ced73f1885d",
            "Julia authority checkout changed")
    passed("P5-D008", "Julia 1.10.12/Sargassum/physics locks; 8352 components and frozen tolerances")

    require(oracle["schema"] == "MITGCM-BOM-P5-PAPER2024-ORACLE-v1" and
            oracle["arithmetic"] == {
                "decimal_digits": 90, "implementation": "python-decimal",
                "minimum_binary_precision_bits": 298} and
            oracle["source_sha256"] == FROZEN_HASHES[
                "verification/bom/phase05-scientific-acceptance/generate_p53_paper_oracle.py"] and
            oracle["contract_sha256"] == FROZEN_HASHES[
                "verification/bom/phase05-scientific-acceptance/P5.3_TEST_CONTRACT.md"] and
            oracle["p02_affine_fixture_sha256"] == FROZEN_HASHES[
                "verification/bom/phase05-scientific-acceptance/p53_p02_affine_fields.csv"] and
            oracle["time"]["fine_reference_step_s"] == "28.125",
            "PAPER2024 independent oracle identity changed")
    oracle_source = (repo / ("verification/bom/phase05-scientific-acceptance/"
                             "generate_p53_paper_oracle.py")).read_text(encoding="ascii")
    tree = ast.parse(oracle_source)
    imports = {alias.name.split(".")[0] for node in ast.walk(tree)
               if isinstance(node, ast.Import) for alias in node.names}
    imports |= {(node.module or "").split(".")[0] for node in ast.walk(tree)
                if isinstance(node, ast.ImportFrom)}
    require(imports <= {"__future__", "argparse", "csv", "hashlib", "json",
                        "decimal", "pathlib"}, "PAPER2024 oracle imports changed")
    passed("P5-D009", "Python Decimal oracle: 90 digits/298 bits, source/contract/fixture hashes locked")

    discrimination = p53_result["p5_p01"]["mode_discrimination"]
    component = discrimination["component"]
    trajectory = discrimination["trajectory"]
    require((component["name"], component["particle_id"], component["time_index"])
            == ("dv_e", 1001, 1) and
            (trajectory["name"], trajectory["particle_id"], trajectory["time_index"])
            == ("x_m", 1003, 96) and
            component["required_multiplier"] == trajectory["required_multiplier"] == 10.0 and
            component["difference"] > 10 * component["roundoff_bound"] and
            trajectory["difference"] > 10 * trajectory["roundoff_bound"],
            "mode-discrimination samples changed")
    passed("P5-D010", "predeclared dv_e(1,1001) and x_m(96,1003) exceed ten roundoff bounds")

    require(p52["trajectory_rows"] == 291 and p52["component_comparisons"] == 8352 and
            p53["p01_trajectory_rows"] == 291 and
            p53["p01_component_comparisons"] == 8352 and
            p53["p02_same_step_comparisons"] == 873 and
            o01["trajectory_rows_per_layout"] == 30 and
            l01["particle_rows"] == 2160,
            "complete trajectory/component inventories changed")
    passed("P5-D011", "full rows P52=291/8352, P53=291/8352+873, O01=30/layout, L01=2160")

    require(f01["cases"] == ["spring", "birth", "cancel", "death", "coast", "combined"] and
            f01["event_records"] == {"spring": 0, "birth": 1, "cancel": 1,
                                      "death": 1, "coast": 2, "combined": 2} and
            r01["canonical_combined_events"] == 2 and
            l01["maximum_mass_budget_error"] == 0.0,
            "exact semantic/event/budget evidence changed")
    passed("P5-D012", "F01 exact six-case/event inventory; R01 canonical events=2; L01 mass error=0")

    p02 = p53_result["p5_p02"]
    require(p53_result["p5_p01"]["components"]["tolerance"] == {
                "absolute": 2e-12, "relative": 5e-12} and
            p53_result["p5_p01"]["trajectory"]["tolerance"] == {
                "absolute_m": 1e-6, "relative_to_reference_path": 5e-11} and
            p02["minimum_interpreted_ratio"] == 12.0 and
            p02["production_steps_s"] == [900, 450, 225] and
            p02["reference"]["fixed_rk4_step_s"] == 28.125,
            "frozen tolerance/convergence definition changed")
    passed("P5-D013", f"{len(FROZEN_HASHES)+len(CORE_HASHES)} protected hashes plus fixed tolerances/steps validate")

    require(r01["positive_runs"] == 18 and
            r01["within_layout_exact_files"] == 1472 and
            r01["changed_decomposition_rejections"] == 2,
            "restart contract changed")
    passed("P5-D014", "R01 positive=18, exact files=1472, prepublication changed-decomposition rejects=2")

    require(r01["cross_layout_owner_comparisons"] == 580 and
            r01["canonical_combined_events"] == 2,
            "canonical MPI comparison changed")
    passed("P5-D015", "R01 cross-layout owners=580 and canonical combined events=2")

    require(all(count > 0 for count in child_manifest_files.values()) and
            all(report["result"] == "PASS" for report in (p51, p52, p53, p54)),
            "independent reader/manifest evidence incomplete")
    passed("P5-D016", f"five child manifests independently rehashed; schemas P5.1--P5.4 PASS")

    require(o01["ocean_pickup_files_exact"] == 80 and
            o01["mnc_selected_files_exact"] == 16 and
            o01["maximum_replay_error_m"] == 0.0,
            "one-way ocean invariance changed")
    smoke = (roots["p5.1"]["artifact"] /
             "smoke-comparison.txt").read_text(encoding="utf-8")
    require("result=PASS" in smoke, "BOM-off smoke comparison failed")
    passed("P5-D017", "P51 BOM-off pickup exact; O01 pickup=80/MNC=16 and replay error=0")

    aggregate_driver = (repo / ("verification/bom/phase05-scientific-acceptance/"
                                "run_p5_sa_g99.sh")).read_text(encoding="utf-8")
    for token in ("failure-manifest.sha256", "freeze_failure_evidence",
                  "fresh root exists", "FINALIZED=1"):
        require(token in aggregate_driver, f"failure retention missing: {token}")
    require(not (g99 / "failure.tsv").exists(), "accepted G99 also records failure")
    passed("P5-D018", "fresh-root refusal and immutable failure-manifest trap present; accepted root has no failure record")

    require("OUTCOME=BLOCKED" in aggregate_driver and "block()" in aggregate_driver,
            "BLOCKED semantics missing")
    for table in ("row-audit.tsv", "all-rows.tsv", "controls.tsv"):
        text = (g99 / table).read_text(encoding="utf-8")
        require("\tSKIP\t" not in text and "\tFAIL\t" not in text,
                f"accepted evidence contains SKIP/FAIL: {table}")
    passed("P5-D019", "required dependency path emits BLOCKED/nonzero; accepted inventories contain no SKIP")

    forbidden = re.compile(r"/(?:skrips)/|skrips-project|scripps_kaust_model", re.I)
    for path in g99.rglob("*"):
        if path.is_file() and path.suffix.lower() in {
            ".txt", ".tsv", ".json", ".log", ".patch", ".md", ".sha256"
        }:
            data = path.read_text(encoding="utf-8", errors="ignore")
            require(not forbidden.search(data), f"foreign dependency in evidence: {path}")
    passed("P5-D020", f"strict {len(changed)}-path allowlist, external roots and evidence text contain no foreign-project dependency")

    reference_builds = [roots[group]["build"] / "mpi-debug"
                        for group in ("p5.2", "p5.3")]
    for build in reference_builds:
        makefile = (build / "Makefile").read_text(
            encoding="utf-8", errors="ignore")
        require(not re.search(r"(^|\s)-DLET_RS_BE_REAL4(\s|$)", makefile),
                f"scientific build weakens _RS: {build}")
        options = (Path(f"{build}-mods") / "CPP_EEOPTIONS.h").read_text(
            encoding="ascii")
        require("#define REAL4_IS_SLOW" in options,
                f"scientific build does not retain REAL4_IS_SLOW: {build}")
    p51_cases = {row["case"]: row for row in
                 read_tsv(roots["p5.1"]["artifact"] / "summary.tsv")}
    require(p51_cases["p5-b01-real8-reference"]["result"] == "PASS",
            "P5.1 Real*8 admission row failed")
    passed("P5-D021", "P51 Real*8 row PASS; P52/P53 CPP options define REAL4_IS_SLOW and Makefiles omit LET_RS_BE_REAL4")

    require(tuple(row["decision"] for row in trace) == DECISIONS and
            len(trace) == 21 and all(row["result"] == "PASS" for row in trace),
            "decision trace incomplete")
    traceability = (repo / ("verification/bom/phase05-scientific-acceptance/"
                            "P5.5_REQUIREMENTS_TRACEABILITY.md")).read_text(
                                encoding="utf-8")
    found = re.findall(r"\| (P5-D\d{3}) \|", traceability)
    require(tuple(found) == DECISIONS, "source decision traceability changed")
    with (exit_evidence / "decision-trace.tsv").open(
        "w", encoding="utf-8", newline=""
    ) as stream:
        writer = csv.DictWriter(stream, fieldnames=("decision", "result", "evidence"),
                                delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(trace)
    report = {
        "schema": "MITGCM-BOM-P5-scientific-exit-audit-v1",
        "result": "PASS",
        "source_head": head,
        "aggregate_rows": EXPECTED_TOTAL,
        "decision_rows": len(trace),
        "required_cases": len(read_tsv(g99 / "acceptance-inventory.tsv")),
        "g99_manifest_files": g99_manifest_files,
        "child_manifest_files": child_manifest_files,
        "production_diff": sorted(production),
        "scientific_acceptance": "PASS",
        "hpc_acceptance": "NOT_EVALUATED",
    }
    (exit_evidence / "independent-exit-audit.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        "PHASE 5 SCIENTIFIC INDEPENDENT EXIT AUDIT PASS: "
        f"head={head} rows={EXPECTED_TOTAL} decisions={len(trace)}; "
        "HPC acceptance not evaluated"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
