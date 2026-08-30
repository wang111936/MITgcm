#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p53-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase05-scientific-acceptance}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase05-scientific-acceptance}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/scientific-acceptance}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly JULIA_BIN="${MITGCM_BOM_JULIA_BIN:-/home/wyl/tools/julia-1.10.12/bin/julia}"
readonly JULIA_ENV="${MITGCM_BOM_JULIA_ENV:-${REPO_ROOT}/verification/bom/reference/julia_env}"
readonly SARGASSUM_ROOT="${MITGCM_BOM_SARGASSUM_ROOT:-/home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl}"
readonly REF_DIR="${REPO_ROOT}/verification/bom/reference/phase02"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"

fail() { printf 'P5.3 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P5.3] %s\n' "$*"; }
record_pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

readonly -a PREAUDIT_ROWS=(
  p53-driver-audit
  p53-oracle-isolation
  p53-oracle-determinism
  p5-p01-input-generate
  p5-p01-input-audit
  p5-p02-input-generate
  p5-p02-input-audit
  p53-reference-preflight
  p53-component-reference-repeat
  p53-production-build
  p53-build-isolation
  p5-p01-production-run
  p5-p02-production-runs
  p53-call-chain
  p53-trajectory-inventory
  p5-p01-paper-oracle
  p5-p01-mode-discrimination
  p5-p02-same-step-oracle
  p5-p02-temporal-convergence
  p53-comparison-products
  p53-checksums
)
readonly -a FINAL_ROWS=("${PREAUDIT_ROWS[@]}" p53-independent-evidence-audit)

for command_name in awk bash cmp diff find gfortran git grep make mpirun nm \
  python3 sed sha256sum shellcheck sort uname xargs; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing command: ${command_name}"
done
[[ -x /usr/bin/time ]] || fail 'missing /usr/bin/time'
[[ -x "${JULIA_BIN}" ]] || fail "missing locked Julia: ${JULIA_BIN}"
[[ -x "${REPO_ROOT}/tools/genmake2" ]] || fail 'genmake2 is not executable'
[[ -f "${OPTFILE}" ]] || fail "missing optfile: ${OPTFILE}"
[[ -f "${JULIA_ENV}/Project.toml" && -f "${JULIA_ENV}/Manifest.toml" ]] \
  || fail 'locked Julia environment is incomplete'
[[ -d "${SARGASSUM_ROOT}/.git" ]] || fail 'locked SargassumBOMB checkout is missing'
[[ "${REQUIRE_CLEAN}" == yes || "${REQUIRE_CLEAN}" == no ]] || fail 'bad REQUIRE_CLEAN'
if [[ "${REQUIRE_CLEAN}" == yes && -n "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]]; then
  fail 'exact-head evidence requires a clean worktree'
fi
git -C "${REPO_ROOT}" merge-base --is-ancestor MITGCM-BOM-v0.5 HEAD \
  || fail 'P5.3 source head is not descended from MITGCM-BOM-v0.5'
for fresh_root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${fresh_root}" ]] || fail "evidence root already exists: ${fresh_root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"
printf '%s\n' "${PREAUDIT_ROWS[@]}" > "${RUN_ROOT}/expected-preaudit.txt"
printf '%s\n' "${FINAL_ROWS[@]}" > "${RUN_ROOT}/expected-final.txt"
git -C "${REPO_ROOT}" rev-parse HEAD > "${RUN_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" branch --show-current > "${RUN_ROOT}/source-branch.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 > "${RUN_ROOT}/git-status-before.txt"
git -C "${REPO_ROOT}" diff --binary MITGCM-BOM-v0.5..HEAD -- . > "${RUN_ROOT}/source-diff-from-v05.patch"
printf 'yes\n' > "${RUN_ROOT}/v05-ancestor.txt"
{
  uname -a
  git --version
  gfortran --version | sed -n '1p'
  mpirun --version | sed -n '1p'
  "${JULIA_BIN}" --startup-file=no --version
  python3 --version
  sha256sum "${JULIA_ENV}/Project.toml" "${JULIA_ENV}/Manifest.toml"
  printf 'sargassum_head=%s\n' "$(git -C "${SARGASSUM_ROOT}" rev-parse HEAD)"
  printf 'optfile=%s\nmake_jobs=%s\nstack=%s\n' "${OPTFILE}" "${MAKE_JOBS}" "$(ulimit -s)"
} > "${RUN_ROOT}/environment.txt"

bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${BUILD_ROOT}/pycache" python3 -m py_compile \
  "${CASE_DIR}/generate_p53_paper_oracle.py" \
  "${CASE_DIR}/generate_p53_inputs.py" \
  "${CASE_DIR}/audit_p53_inputs.py" \
  "${CASE_DIR}/compare_p53_paper2024.py" \
  "${CASE_DIR}/audit_p53_evidence.py"
record_pass p53-driver-audit 'gate shell and all P5.3 Python tools pass static checks'

python3 - "${CASE_DIR}/generate_p53_paper_oracle.py" <<'PY'
import ast
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text(encoding="ascii")
tree = ast.parse(source)
allowed = {"__future__", "argparse", "csv", "hashlib", "json", "decimal", "pathlib"}
imports = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        imports.update(alias.name.split(".")[0] for alias in node.names)
    elif isinstance(node, ast.ImportFrom):
        imports.add((node.module or "").split(".")[0])
if not imports <= allowed:
    raise SystemExit(f"oracle has non-independent imports: {sorted(imports-allowed)}")
for forbidden in ("pkg/bom", "bom_rhs_", "mitgcmuv", "subprocess", "ctypes", "f2py"):
    if forbidden.lower() in source.lower():
        raise SystemExit(f"oracle contains forbidden production coupling: {forbidden}")
print("P5.3 ORACLE ISOLATION PASS")
PY
record_pass p53-oracle-isolation 'oracle uses only standard-library arithmetic/I/O and contains no production-source or executable coupling'

log 'generating the independent PAPER2024 oracle twice'
python3 "${CASE_DIR}/generate_p53_paper_oracle.py" \
  --repo-root "${REPO_ROOT}" "${RUN_ROOT}/oracle" > "${RUN_ROOT}/oracle-generation.log"
python3 "${CASE_DIR}/generate_p53_paper_oracle.py" \
  --repo-root "${REPO_ROOT}" "${RUN_ROOT}/oracle-rerun" > "${RUN_ROOT}/oracle-generation-rerun.log"
grep -q 'P5.3 PAPER2024 ORACLE PASS files=5 rows=1455 precision_digits=90' \
  "${RUN_ROOT}/oracle-generation.log" || fail 'oracle generation marker missing'
diff -qr "${RUN_ROOT}/oracle" "${RUN_ROOT}/oracle-rerun" > "${RUN_ROOT}/oracle-diff.log"
(
  cd "${RUN_ROOT}/oracle"
  sha256sum -c SHA256SUMS > "${RUN_ROOT}/oracle-checksums.log"
)
record_pass p53-oracle-determinism 'five 90-decimal reference CSVs are byte-repeatable and their SHA-256 inventory validates'

log 'generating and independently auditing P5-P01 input'
python3 "${CASE_DIR}/generate_p53_inputs.py" --repo-root "${REPO_ROOT}" \
  --case p01 --dt-s 900 "${RUN_ROOT}/input-p01-dt900" \
  > "${RUN_ROOT}/input-p01-generation.log"
grep -q 'P5.3 INPUT GENERATION PASS case=p01 dt=900' \
  "${RUN_ROOT}/input-p01-generation.log" || fail 'P5-P01 input marker missing'
record_pass p5-p01-input-generate 'Case J PAPER2024 dt=900 input bundle generated with exact read-ahead'
python3 "${CASE_DIR}/audit_p53_inputs.py" --repo-root "${REPO_ROOT}" \
  --case p01 --dt-s 900 --report "${RUN_ROOT}/input-p01-audit.json" \
  "${RUN_ROOT}/input-p01-dt900" > "${RUN_ROOT}/input-p01-audit.log"
grep -q 'P5.3 INPUT AUDIT PASS case=p01 dt=900' "${RUN_ROOT}/input-p01-audit.log" \
  || fail 'P5-P01 input audit marker missing'
record_pass p5-p01-input-audit 'independent byte audit validates Case J C-grid fields, particles, times, schemas and hashes'

log 'generating and independently auditing three P5-P02 input bundles'
for dt_s in 900 450 225; do
  python3 "${CASE_DIR}/generate_p53_inputs.py" --repo-root "${REPO_ROOT}" \
    --case p02 --dt-s "${dt_s}" "${RUN_ROOT}/input-p02-dt${dt_s}" \
    > "${RUN_ROOT}/input-p02-dt${dt_s}-generation.log"
done
record_pass p5-p02-input-generate 'identical locked smooth functions generated at dt=900/450/225 with common 900 s output'
for dt_s in 900 450 225; do
  python3 "${CASE_DIR}/audit_p53_inputs.py" --repo-root "${REPO_ROOT}" \
    --case p02 --dt-s "${dt_s}" --report "${RUN_ROOT}/input-p02-dt${dt_s}-audit.json" \
    "${RUN_ROOT}/input-p02-dt${dt_s}" > "${RUN_ROOT}/input-p02-dt${dt_s}-audit.log"
  grep -q "P5.3 INPUT AUDIT PASS case=p02 dt=${dt_s}" \
    "${RUN_ROOT}/input-p02-dt${dt_s}-audit.log" || fail "P5-P02 input audit marker missing: ${dt_s}"
done
record_pass p5-p02-input-audit 'independent audits validate all 2085 files and native C-grid values across three time axes'

python3 "${REF_DIR}/verify_b16_preflight.py" --mode full \
  --phase-dir "${REF_DIR}" --source-root "${SARGASSUM_ROOT}" \
  --julia-bin "${JULIA_BIN}" --project-file "${JULIA_ENV}/Project.toml" \
  --manifest-file "${JULIA_ENV}/Manifest.toml" \
  > "${RUN_ROOT}/reference-preflight.log"
record_pass p53-reference-preflight 'locked Julia environment, Sargassum source, physics inputs and B16 manifests validate'
mkdir "${RUN_ROOT}/reference"
for suffix in components.csv components.rerun.csv; do
  "${JULIA_BIN}" --startup-file=no --project="${JULIA_ENV}" \
    "${CASE_DIR}/generate_p52_reference.jl" "${RUN_ROOT}/reference/${suffix}" \
    "${REF_DIR}/generate_b16_golden.jl" "${REF_DIR}" "${SARGASSUM_ROOT}" \
    "${JULIA_ENV}/Project.toml" "${JULIA_ENV}/Manifest.toml" \
    > "${RUN_ROOT}/reference/${suffix}.log"
done
cmp "${RUN_ROOT}/reference/components.csv" "${RUN_ROOT}/reference/components.rerun.csv" \
  || fail 'Julia component discriminator reference is not byte-repeatable'
record_pass p53-component-reference-repeat '291-row locked Julia component reference is byte-identical across two runs'

log 'building the production MPI/IEEE executable from the exact source head'
mkdir "${BUILD_ROOT}/mpi-debug" "${BUILD_ROOT}/mpi-debug-mods"
cp -a "${EXP2_CODE}/." "${BUILD_ROOT}/mpi-debug-mods/"
cp "${CASE_DIR}/code/SIZE.h.mpi4" "${BUILD_ROOT}/mpi-debug-mods/SIZE.h"
cp "${CASE_DIR}/code/packages.conf" "${BUILD_ROOT}/mpi-debug-mods/packages.conf"
cp "${CASE_DIR}/code/CPP_EEOPTIONS.h" "${BUILD_ROOT}/mpi-debug-mods/CPP_EEOPTIONS.h"
if find "${BUILD_ROOT}/mpi-debug-mods" -maxdepth 1 -type f -iname 'bom*.F' -print -quit | grep -q .; then
  fail 'production source override found in P5.3 mods'
fi
printf '%q ' "${REPO_ROOT}/tools/genmake2" "-rootdir=${REPO_ROOT}" \
  "-mods=${BUILD_ROOT}/mpi-debug-mods" "-of=${OPTFILE}" -mpi -ieee -devel \
  > "${BUILD_ROOT}/mpi-debug/command.txt"
printf '\n' >> "${BUILD_ROOT}/mpi-debug/command.txt"
(
  cd "${BUILD_ROOT}/mpi-debug"
  "${REPO_ROOT}/tools/genmake2" -rootdir="${REPO_ROOT}" \
    -mods="${BUILD_ROOT}/mpi-debug-mods" -of="${OPTFILE}" \
    -mpi -ieee -devel > genmake.log 2>&1
  /usr/bin/time -v -o depend.time make depend > depend.log 2>&1
  /usr/bin/time -v -o build.time make -j "${MAKE_JOBS}" > build.log 2>&1
  nm -g mitgcmuv > symbols.txt
)
[[ -x "${BUILD_ROOT}/mpi-debug/mitgcmuv" ]] || fail 'production executable missing'
record_pass p53-production-build 'GNU OpenMPI debug/IEEE production executable builds from the admitted package set'

for symbol in bom_init_fixed_ bom_init_varia_ bom_main_ bom_build_endpoints_ \
  bom_build_fields_ bom_fill_cgrid_boundary_ bom_rhs_julia_ bom_rhs_paper2024_ \
  bom_rk4_ bom_particle_exchange_ bom_write_trajectory_; do
  [[ "$(grep -Ec "[[:space:]]${symbol}$" "${BUILD_ROOT}/mpi-debug/symbols.txt")" -eq 1 ]] \
    || fail "production symbol count differs: ${symbol}"
done
if grep -Eqi '[[:space:]]bom_verify[^[:space:]]*_$' "${BUILD_ROOT}/mpi-debug/symbols.txt"; then
  fail 'verification-only BOM symbol linked into production executable'
fi
if grep -Eq '(^|[[:space:]])-DLET_RS_BE_REAL4([[:space:]]|$)' "${BUILD_ROOT}/mpi-debug/Makefile"; then
  fail 'P5.3 unexpectedly weakens _RS to Real*4'
fi
for macro in ALLOW_CD_CODE ALLOW_OFFLINE ALLOW_EXF ALLOW_DIAGNOSTICS ALLOW_MNC ALLOW_BOM; do
  grep -Eq "^#define[[:space:]]+${macro}([[:space:]]|$)" \
    "${BUILD_ROOT}/mpi-debug/PACKAGES_CONFIG.h" || fail "build lacks ${macro}"
done
for macro in ALWAYS_PREVENT_X_PERIODICITY ALWAYS_PREVENT_Y_PERIODICITY; do
  grep -Eq "^#define[[:space:]]+${macro}([[:space:]]|$)" \
    "${BUILD_ROOT}/mpi-debug-mods/CPP_EEOPTIONS.h" || fail "build lacks ${macro}"
done
{
  printf 'source_head=%s\n' "$(cat "${RUN_ROOT}/source-head.txt")"
  sha256sum "${BUILD_ROOT}/mpi-debug/mitgcmuv" \
    "${BUILD_ROOT}/mpi-debug/genmake.log" "${BUILD_ROOT}/mpi-debug/depend.log" \
    "${BUILD_ROOT}/mpi-debug/build.log" "${BUILD_ROOT}/mpi-debug/Makefile" \
    "${BUILD_ROOT}/mpi-debug/PACKAGES_CONFIG.h" "${BUILD_ROOT}/mpi-debug/symbols.txt" \
    "${BUILD_ROOT}/mpi-debug-mods/SIZE.h" "${BUILD_ROOT}/mpi-debug-mods/packages.conf" \
    "${BUILD_ROOT}/mpi-debug-mods/CPP_EEOPTIONS.h" "${OPTFILE}"
} > "${BUILD_ROOT}/mpi-debug/fingerprint.txt"
record_pass p53-build-isolation 'PAPER2024/Julia RHS and production call chain link once; no source override/verifier/Real4 weakening'

run_case() {
  local label="$1"
  local input_dir="$2"
  local expected_steps="$3"
  local run_dir="${RUN_ROOT}/run-${label}"
  mkdir "${run_dir}"
  cp -a "${input_dir}/." "${run_dir}/"
  ln -s "${BUILD_ROOT}/mpi-debug/mitgcmuv" "${run_dir}/mitgcmuv"
  (
    cd "${run_dir}"
    /usr/bin/time -v -o resource.txt mpirun --oversubscribe -np 4 ./mitgcmuv \
      > stdout.log 2> stderr.log
  )
  mapfile -t rank_logs < <(find "${run_dir}" -maxdepth 1 -type f \
    -name 'STDOUT.[0-9][0-9][0-9][0-9]' -print | sort)
  [[ "${#rank_logs[@]}" -eq 4 ]] || fail "four MPI rank logs missing: ${label}"
  for rank_log in "${rank_logs[@]}"; do
    grep -q 'PROGRAM MAIN: Execution ended Normally' "${rank_log}" \
      || fail "normal end missing: ${rank_log}"
    if grep -Eqi 'ABNORMAL END|S/R ALL_PROC_DIE|Fortran runtime error' "${rank_log}"; then
      fail "fatal marker in ${rank_log}"
    fi
    timer_block="$(grep -B 3 'Seconds in section "BOM[[:space:]]*\[FORWARD_STEP\]":' "${rank_log}")"
    grep -Eq "No\. starts:[[:space:]]+${expected_steps}$" <<< "${timer_block}" \
      || fail "BOM start count differs: ${rank_log}"
    grep -Eq "No\. stops:[[:space:]]+${expected_steps}$" <<< "${timer_block}" \
      || fail "BOM stop count differs: ${rank_log}"
  done
}

log 'running P5-P01 and the three P5-P02 production simulations on four MPI ranks'
run_case p01-dt900 "${RUN_ROOT}/input-p01-dt900" 96
record_pass p5-p01-production-run 'four-rank normal PAPER2024 Case J run completes 96 production steps'
run_case p02-dt900 "${RUN_ROOT}/input-p02-dt900" 96
run_case p02-dt450 "${RUN_ROOT}/input-p02-dt450" 192
run_case p02-dt225 "${RUN_ROOT}/input-p02-dt225" 384
record_pass p5-p02-production-runs 'four-rank dt=900/450/225 runs complete 96/192/384 stable finite steps'
record_pass p53-call-chain 'all rank timers prove 3072 total FORWARD_STEP to BOM production calls'

python3 "${CASE_DIR}/compare_p53_paper2024.py" \
  --run-p01 "${RUN_ROOT}/run-p01-dt900" --input-p01 "${RUN_ROOT}/input-p01-dt900" \
  --run-p02-dt900 "${RUN_ROOT}/run-p02-dt900" \
  --run-p02-dt450 "${RUN_ROOT}/run-p02-dt450" \
  --run-p02-dt225 "${RUN_ROOT}/run-p02-dt225" \
  --input-p02-dt900 "${RUN_ROOT}/input-p02-dt900" \
  --input-p02-dt450 "${RUN_ROOT}/input-p02-dt450" \
  --input-p02-dt225 "${RUN_ROOT}/input-p02-dt225" \
  --oracle "${RUN_ROOT}/oracle" \
  --julia-components "${RUN_ROOT}/reference/components.csv" \
  --julia-trajectory "${REF_DIR}/golden_traj_julia_rk4_v1.csv" \
  --output "${RUN_ROOT}/comparison" > "${RUN_ROOT}/comparison.log"
grep -q 'P5.3 PAPER2024 COMPARISON PASS p01_components=8352 p02_ratios=12' \
  "${RUN_ROOT}/comparison.log" || fail 'P5.3 comparison PASS marker missing'
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); i=r["inventory"]; assert r["result"]=="PASS"; assert i["p01"]["data_files"]==384; assert all(i["p02"][str(dt)]["data_files"]==384 for dt in (900,450,225))' \
  "${RUN_ROOT}/comparison/result.json"
record_pass p53-trajectory-inventory 'four cases each contain exact 96-frame, four-tile, three-ID, 384 data/meta trajectory inventories'
python3 -c 'import json,sys; p=json.load(open(sys.argv[1]))["p5_p01"]; assert p["result"]=="PASS"; assert p["trajectory"]["rows"]==291 and p["trajectory"]["failures"]==0; assert p["components"]["comparisons"]==8352 and p["components"]["failures"]==0' \
  "${RUN_ROOT}/comparison/result.json"
record_pass p5-p01-paper-oracle '291 full trajectory rows and 8352 native-rate/27-component values pass the independent PAPER2024 oracle'
python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))["p5_p01"]["mode_discrimination"]; assert d["component"]["result"]==d["trajectory"]["result"]=="PASS"; assert d["component"]["difference"]>10*d["component"]["roundoff_bound"]; assert d["trajectory"]["difference"]>10*d["trajectory"]["roundoff_bound"]' \
  "${RUN_ROOT}/comparison/result.json"
record_pass p5-p01-mode-discrimination 'predeclared dv_e and final x samples differ from locked Julia by more than ten frozen bounds'
python3 -c 'import json,sys; p=json.load(open(sys.argv[1]))["p5_p02"]; s=p["same_step_oracle"]; assert s["comparisons"]==873 and s["failures"]==0' \
  "${RUN_ROOT}/comparison/result.json"
record_pass p5-p02-same-step-oracle '873 production positions match independent same-step 90-decimal PAPER2024 RK4 references'
python3 -c 'import json,sys; p=json.load(open(sys.argv[1]))["p5_p02"]; assert p["result"]=="PASS" and p["failures"]==0; assert p["norm_rows"]==18 and p["ratio_rows"]==12; assert p["reference"]["fixed_rk4_step_s"]==28.125 and p["reference"]["minimum_binary_precision_bits"]>=256' \
  "${RUN_ROOT}/comparison/result.json"
record_pass p5-p02-temporal-convergence 'all endpoint/full norms strictly decrease; interpreted adjacent RK4 ratios exceed 12 against 28.125 s 90-decimal reference'

for product in normalized_p01.csv normalized_p02_dt0900.csv normalized_p02_dt0450.csv \
  normalized_p02_dt0225.csv p01_normalized_components.csv p01_component_errors.csv \
  p01_trajectory_errors.csv p02_same_step_errors.csv p02_norms.csv p02_ratios.csv \
  p01_result.json p02_result.json result.json inventory_audit.json review.md \
  p01_particle_1001_timeseries.svg p01_particle_1002_timeseries.svg \
  p01_particle_1003_timeseries.svg p01_trajectory_planview.svg \
  p02_particle_1001_timeseries.svg p02_particle_1002_timeseries.svg \
  p02_particle_1003_timeseries.svg p02_trajectory_planview.svg; do
  [[ -s "${RUN_ROOT}/comparison/${product}" ]] || fail "comparison product missing: ${product}"
done
record_pass p53-comparison-products 'normalized CSVs, error tables, machine reports, review and eight SVG plots are nonempty'

git -C "${REPO_ROOT}" status --porcelain=v1 > "${RUN_ROOT}/git-status-after.txt"
if [[ "${REQUIRE_CLEAN}" == yes && -s "${RUN_ROOT}/git-status-after.txt" ]]; then
  fail 'source worktree changed during exact-head gate'
fi
(
  cd "${BUILD_ROOT}"
  find . -type f \( -name 'mitgcmuv' -o -name '*.log' -o -name '*.time' \
    -o -name 'symbols.txt' -o -name 'fingerprint.txt' -o -name 'command.txt' \
    -o -name 'PACKAGES_CONFIG.h' -o -name 'Makefile' -o -name 'SIZE.h' \
    -o -name 'packages.conf' -o -name 'CPP_EEOPTIONS.h' \) -print0 \
    | sort -z | xargs -0 sha256sum > SHA256SUMS
  sha256sum -c SHA256SUMS >/dev/null
)
(
  cd "${RUN_ROOT}"
  find . -type f ! -name 'SHA256SUMS' ! -name 'summary.tsv' \
    ! -name 'expected-preaudit.txt' ! -name 'expected-final.txt' -print0 \
    | sort -z | xargs -0 sha256sum > SHA256SUMS
  sha256sum -c SHA256SUMS >/dev/null
)
record_pass p53-checksums 'self-validating build/input/oracle/reference/raw-run/comparison SHA-256 inventories pass'

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary-preaudit.tsv"
cp "${RUN_ROOT}/expected-preaudit.txt" "${ARTIFACT_ROOT}/expected-preaudit.txt"
cp "${RUN_ROOT}/expected-final.txt" "${ARTIFACT_ROOT}/expected-final.txt"
for name in source-head.txt source-branch.txt git-status-before.txt git-status-after.txt \
  source-diff-from-v05.patch v05-ancestor.txt environment.txt \
  oracle-generation.log oracle-checksums.log reference-preflight.log comparison.log; do
  cp "${RUN_ROOT}/${name}" "${ARTIFACT_ROOT}/${name}"
done
for name in input-p01-audit.json input-p02-dt900-audit.json \
  input-p02-dt450-audit.json input-p02-dt225-audit.json; do
  cp "${RUN_ROOT}/${name}" "${ARTIFACT_ROOT}/${name}"
done
cp "${RUN_ROOT}/oracle/oracle-manifest.json" "${ARTIFACT_ROOT}/oracle-manifest.json"
cp "${RUN_ROOT}/comparison/result.json" "${ARTIFACT_ROOT}/comparison-result.json"
cp "${RUN_ROOT}/comparison/inventory_audit.json" "${ARTIFACT_ROOT}/comparison-inventory.json"
cp "${RUN_ROOT}/comparison/review.md" "${ARTIFACT_ROOT}/comparison-review.md"
cp "${BUILD_ROOT}/SHA256SUMS" "${ARTIFACT_ROOT}/build-SHA256SUMS"
cp "${RUN_ROOT}/SHA256SUMS" "${ARTIFACT_ROOT}/run-SHA256SUMS"
cp "${BUILD_ROOT}/mpi-debug/fingerprint.txt" "${ARTIFACT_ROOT}/mpi-debug-fingerprint.txt"

python3 "${CASE_DIR}/audit_p53_evidence.py" "${ARTIFACT_ROOT}" \
  --repo-root "${REPO_ROOT}" --build-root "${BUILD_ROOT}" --run-root "${RUN_ROOT}" \
  --report "${ARTIFACT_ROOT}/independent-audit.json" \
  > "${ARTIFACT_ROOT}/independent-audit.log"
grep -q 'P5.3 INDEPENDENT EVIDENCE AUDIT PASS' \
  "${ARTIFACT_ROOT}/independent-audit.log" || fail 'independent evidence audit marker missing'
record_pass p53-independent-evidence-audit 'independent provenance/build/oracle/input/run/numerical/hash audit passes'

actual_rows="$(awk 'NR>1 {print $1}' "${RUN_ROOT}/summary.tsv")"
expected_rows="$(printf '%s\n' "${FINAL_ROWS[@]}")"
[[ "${actual_rows}" == "${expected_rows}" ]] || fail 'final row order/inventory differs'
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
(
  cd "${ARTIFACT_ROOT}"
  find . -maxdepth 1 -type f ! -name 'manifest.sha256' -print0 \
    | sort -z | xargs -0 sha256sum > manifest.sha256
  sha256sum -c manifest.sha256 >/dev/null
)

log "P5.3 GATE PASS (${#FINAL_ROWS[@]}/${#FINAL_ROWS[@]})"
log "build root: ${BUILD_ROOT}"
log "run root: ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
