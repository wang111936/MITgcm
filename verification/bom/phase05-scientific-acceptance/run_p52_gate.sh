#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p52-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
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

fail() { printf 'P5.2 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P5.2] %s\n' "$*"; }
record_pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

readonly -a PREAUDIT_ROWS=(
  p52-driver-audit
  p5-j01-input-generate
  p5-j01-input-audit
  p5-j01-reference-preflight
  p5-j01-production-build
  p5-j01-build-isolation
  p5-j01-reference-byte-reproduction
  p5-j01-component-reference-repeat
  p5-j01-production-run
  p5-j01-call-chain
  p5-j01-trajectory-inventory
  p5-j01-pickup-schema
  p5-j01-julia-trajectory
  p5-j01-julia-components
  p5-j01-comparison-products
  p5-j01-checksums
)
readonly -a FINAL_ROWS=("${PREAUDIT_ROWS[@]}" p52-independent-evidence-audit)

for command_name in awk bash cmp find gfortran git grep make mpirun nm python3 \
  sed sha256sum shellcheck sort uname xargs; do
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
  || fail 'P5.2 source head is not descended from MITGCM-BOM-v0.5'
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
  "${CASE_DIR}/generate_p51_inputs.py" \
  "${CASE_DIR}/audit_p51_inputs.py" \
  "${CASE_DIR}/compare_p52_julia.py" \
  "${CASE_DIR}/audit_p52_evidence.py"
record_pass p52-driver-audit 'gate shell and independent Python generator/decoders pass static checks'

log 'generating and independently decoding P5-J01 production input'
python3 "${CASE_DIR}/generate_p51_inputs.py" \
  "${RUN_ROOT}/input-bundle" --repo-root "${REPO_ROOT}" \
  > "${RUN_ROOT}/input-generation.log"
grep -q 'P5-I01 INPUT GENERATION PASS' "${RUN_ROOT}/input-generation.log" \
  || fail 'input generation marker missing'
record_pass p5-j01-input-generate '8x6x2 non-periodic case, 97 endpoints plus one read-ahead and three particles generated'
python3 "${CASE_DIR}/audit_p51_inputs.py" \
  "${RUN_ROOT}/input-bundle" --repo-root "${REPO_ROOT}" \
  --report "${RUN_ROOT}/input-audit.json" > "${RUN_ROOT}/input-audit.log"
grep -q 'P5-I01 INPUT AUDIT PASS' "${RUN_ROOT}/input-audit.log" \
  || fail 'input audit marker missing'
record_pass p5-j01-input-audit 'independent binary oracle validates native C-grid values, exact times, schemas and hashes'

python3 "${REF_DIR}/verify_b16_preflight.py" --mode full \
  --phase-dir "${REF_DIR}" --source-root "${SARGASSUM_ROOT}" \
  --julia-bin "${JULIA_BIN}" \
  --project-file "${JULIA_ENV}/Project.toml" \
  --manifest-file "${JULIA_ENV}/Manifest.toml" \
  > "${RUN_ROOT}/reference-preflight.log"
record_pass p5-j01-reference-preflight 'locked Julia 1.10.12, Sargassum commit, physics, environment and B16 manifests validate'

log 'building the production MPI/IEEE executable'
mkdir "${BUILD_ROOT}/mpi-debug" "${BUILD_ROOT}/mpi-debug-mods"
cp -a "${EXP2_CODE}/." "${BUILD_ROOT}/mpi-debug-mods/"
cp "${CASE_DIR}/code/SIZE.h.mpi4" "${BUILD_ROOT}/mpi-debug-mods/SIZE.h"
cp "${CASE_DIR}/code/packages.conf" "${BUILD_ROOT}/mpi-debug-mods/packages.conf"
cp "${CASE_DIR}/code/CPP_EEOPTIONS.h" "${BUILD_ROOT}/mpi-debug-mods/CPP_EEOPTIONS.h"
if find "${BUILD_ROOT}/mpi-debug-mods" -maxdepth 1 -type f -iname 'bom*.F' -print -quit | grep -q .; then
  fail 'production source override found in P5.2 mods'
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
record_pass p5-j01-production-build 'GNU OpenMPI debug/IEEE production executable builds from admitted package set'

for symbol in bom_init_fixed_ bom_init_varia_ bom_main_ bom_build_endpoints_ \
  bom_build_fields_ bom_fill_cgrid_boundary_ bom_rhs_julia_ bom_rk4_ \
  bom_particle_exchange_ \
  bom_write_trajectory_ bom_write_pickup_ bom_read_pickup_; do
  [[ "$(grep -Ec "[[:space:]]${symbol}$" "${BUILD_ROOT}/mpi-debug/symbols.txt")" -eq 1 ]] \
    || fail "production symbol count differs: ${symbol}"
done
if grep -Eqi '[[:space:]]bom_verify[^[:space:]]*_$' "${BUILD_ROOT}/mpi-debug/symbols.txt"; then
  fail 'verification-only BOM symbol linked into production executable'
fi
if grep -Eq '(^|[[:space:]])-DLET_RS_BE_REAL4([[:space:]]|$)' "${BUILD_ROOT}/mpi-debug/Makefile"; then
  fail 'P5-J01 unexpectedly weakens _RS to Real*4'
fi
for macro in ALLOW_CD_CODE ALLOW_OFFLINE ALLOW_EXF ALLOW_DIAGNOSTICS ALLOW_MNC ALLOW_BOM; do
  grep -Eq "^#define[[:space:]]+${macro}([[:space:]]|$)" \
    "${BUILD_ROOT}/mpi-debug/PACKAGES_CONFIG.h" || fail "build lacks ${macro}"
done
for macro in ALWAYS_PREVENT_X_PERIODICITY ALWAYS_PREVENT_Y_PERIODICITY; do
  grep -Eq "^#define[[:space:]]+${macro}([[:space:]]|$)" \
    "${BUILD_ROOT}/mpi-debug-mods/CPP_EEOPTIONS.h" || fail "build lacks ${macro}"
done
grep -q 'mpiPidW = MPI_PROC_NULL' "${REPO_ROOT}/eesupp/src/ini_procs.F" \
  || fail 'non-periodic MPI boundary guard missing'
for source_file in pkg/bom/bom_build_fields.F pkg/bom/bom_build_endpoints.F; do
  [[ "$(grep -Ec 'CALL BOM_FILL_CGRID_BOUNDARY' \
    "${REPO_ROOT}/${source_file}")" -eq 1 ]] \
    || fail "BOM native C-grid closure wiring differs: ${source_file}"
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
record_pass p5-j01-build-isolation 'production routines including native C-grid closure linked once; no override/verifier/EXCH2, Real*8 and non-periodic MPI guards proven'

log 'reproducing the locked Julia references'
"${JULIA_BIN}" --startup-file=no --project="${JULIA_ENV}" \
  "${REF_DIR}/generate_b16_golden.jl" "${RUN_ROOT}/reference-rerun" \
  "${REF_DIR}" "${SARGASSUM_ROOT}" "${JULIA_ENV}/Project.toml" \
  "${JULIA_ENV}/Manifest.toml" > "${RUN_ROOT}/reference-rerun.log"
for name in golden_rhs_julia_v1.csv golden_traj_julia_rk2_v1.csv golden_traj_julia_rk4_v1.csv; do
  cmp "${REF_DIR}/${name}" "${RUN_ROOT}/reference-rerun/${name}" \
    || fail "locked reference regeneration differs: ${name}"
done
record_pass p5-j01-reference-byte-reproduction 'locked generator reproduces all checked-in RHS/RK2/RK4 CSV files byte-for-byte'

mkdir "${RUN_ROOT}/reference"
"${JULIA_BIN}" --startup-file=no --project="${JULIA_ENV}" \
  "${CASE_DIR}/generate_p52_reference.jl" "${RUN_ROOT}/reference/components.csv" \
  "${REF_DIR}/generate_b16_golden.jl" "${REF_DIR}" "${SARGASSUM_ROOT}" \
  "${JULIA_ENV}/Project.toml" "${JULIA_ENV}/Manifest.toml" \
  > "${RUN_ROOT}/reference/generation.log"
"${JULIA_BIN}" --startup-file=no --project="${JULIA_ENV}" \
  "${CASE_DIR}/generate_p52_reference.jl" "${RUN_ROOT}/reference/components.rerun.csv" \
  "${REF_DIR}/generate_b16_golden.jl" "${REF_DIR}" "${SARGASSUM_ROOT}" \
  "${JULIA_ENV}/Project.toml" "${JULIA_ENV}/Manifest.toml" \
  > "${RUN_ROOT}/reference/generation-rerun.log"
cmp "${RUN_ROOT}/reference/components.csv" "${RUN_ROOT}/reference/components.rerun.csv" \
  || fail 'full Julia component reference is not byte-repeatable'
grep -q 'P5-J01 JULIA COMPONENT REFERENCE PASS rows=291' \
  "${RUN_ROOT}/reference/generation.log" || fail 'component reference marker missing'
record_pass p5-j01-component-reference-repeat '291-row full-time component reference is byte-identical across two locked Julia runs'

log 'running 96-step production P5-J01 on four MPI ranks'
mkdir "${RUN_ROOT}/run"
cp -a "${RUN_ROOT}/input-bundle/." "${RUN_ROOT}/run/"
ln -s "${BUILD_ROOT}/mpi-debug/mitgcmuv" "${RUN_ROOT}/run/mitgcmuv"
(
  cd "${RUN_ROOT}/run"
  /usr/bin/time -v -o resource.txt mpirun --oversubscribe -np 4 ./mitgcmuv \
    > stdout.log 2> stderr.log
)
mapfile -t rank_logs < <(find "${RUN_ROOT}/run" -maxdepth 1 -type f \
  -name 'STDOUT.[0-9][0-9][0-9][0-9]' -print | sort)
[[ "${#rank_logs[@]}" -eq 4 ]] || fail 'four MPI rank logs were not produced'
for rank_log in "${rank_logs[@]}"; do
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${rank_log}" \
    || fail "normal end missing: ${rank_log}"
  if grep -Eqi 'ABNORMAL END|S/R ALL_PROC_DIE|Fortran runtime error' "${rank_log}"; then
    fail "fatal marker in ${rank_log}"
  fi
done
record_pass p5-j01-production-run 'four-rank normal MITgcm time loop completes 96 ocean/BOM steps with nonzero particles'

for rank_log in "${rank_logs[@]}"; do
  timer_block="$(grep -B 3 'Seconds in section "BOM[[:space:]]*\[FORWARD_STEP\]":' "${rank_log}")"
  grep -Eq 'No\. starts:[[:space:]]+96$' <<< "${timer_block}" \
    || fail "BOM start count differs in ${rank_log}"
  grep -Eq 'No\. stops:[[:space:]]+96$' <<< "${timer_block}" \
    || fail "BOM stop count differs in ${rank_log}"
done
record_pass p5-j01-call-chain 'each MPI rank timer proves 96 FORWARD_STEP -> BOM production calls'

python3 "${CASE_DIR}/compare_p52_julia.py" \
  "${RUN_ROOT}/run" "${RUN_ROOT}/input-bundle" \
  "${REF_DIR}/golden_traj_julia_rk4_v1.csv" \
  "${RUN_ROOT}/reference/components.csv" "${RUN_ROOT}/comparison" \
  > "${RUN_ROOT}/comparison.log"
grep -q 'P5-J01 LOCKED JULIA COMPARISON PASS trajectory=291 components=8352' \
  "${RUN_ROOT}/comparison.log" || fail 'Julia comparison PASS marker missing'
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); assert r["result"]=="PASS"; assert r["inventory"]["iterations"]==96; assert r["inventory"]["data_files"]==384; assert r["inventory"]["meta_files"]==384' \
  "${RUN_ROOT}/comparison/result.json"
record_pass p5-j01-trajectory-inventory 'exact 1..96 suffixes, four tiles, three IDs and 384 data/meta pairs independently decoded'
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); p=r["inventory"]["pickup"]; assert set(p)=={"0000000048","0000000096"}; assert all(v["particles"]==3 and v["tiles"]==4 and v["signature_fields"]==1333 for v in p.values())' \
  "${RUN_ROOT}/comparison/result.json"
record_pass p5-j01-pickup-schema 'iterations 48/96 pickup tiles, signatures, schedules, schema and exact IDs independently decode'
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); t=r["trajectory"]; assert t["rows"]==291 and t["failures"]==0; assert t["tolerance"]=={"absolute_m":1e-6,"relative_to_reference_path":5e-11}; assert all(v>0 for v in r["net_displacement_m"].values())' \
  "${RUN_ROOT}/comparison/result.json"
record_pass p5-j01-julia-trajectory 'all 291 positions and accumulated paths pass frozen tolerance; all particles move'
python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); c=r["components"]; assert c["production_rows"]==288 and c["comparisons"]==8352 and c["failures"]==0; assert c["tolerance"]=={"absolute":2e-12,"relative":5e-12}' \
  "${RUN_ROOT}/comparison/result.json"
record_pass p5-j01-julia-components 'all 8352 production coordinate-rate and 27-component comparisons pass frozen tolerance'
for product in normalized_trajectory.csv trajectory_errors.csv normalized_components.csv \
  component_errors.csv inventory_audit.json result.json review.md \
  particle_1001_timeseries.svg particle_1002_timeseries.svg \
  particle_1003_timeseries.svg trajectory_planview.svg; do
  [[ -s "${RUN_ROOT}/comparison/${product}" ]] || fail "comparison product missing: ${product}"
done
record_pass p5-j01-comparison-products 'normalized CSVs, machine reports, review and four comparison plots are present and nonempty'

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
record_pass p5-j01-checksums 'self-validating build, input, reference, raw run and normalized-product SHA-256 inventories pass'

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary-preaudit.tsv"
cp "${RUN_ROOT}/expected-preaudit.txt" "${ARTIFACT_ROOT}/expected-preaudit.txt"
cp "${RUN_ROOT}/expected-final.txt" "${ARTIFACT_ROOT}/expected-final.txt"
cp "${RUN_ROOT}/source-head.txt" "${ARTIFACT_ROOT}/source-head.txt"
cp "${RUN_ROOT}/source-branch.txt" "${ARTIFACT_ROOT}/source-branch.txt"
cp "${RUN_ROOT}/git-status-before.txt" "${ARTIFACT_ROOT}/git-status-before.txt"
cp "${RUN_ROOT}/git-status-after.txt" "${ARTIFACT_ROOT}/git-status-after.txt"
cp "${RUN_ROOT}/source-diff-from-v05.patch" "${ARTIFACT_ROOT}/source-diff-from-v05.patch"
cp "${RUN_ROOT}/v05-ancestor.txt" "${ARTIFACT_ROOT}/v05-ancestor.txt"
cp "${RUN_ROOT}/environment.txt" "${ARTIFACT_ROOT}/environment.txt"
cp "${RUN_ROOT}/input-audit.json" "${ARTIFACT_ROOT}/input-audit.json"
cp "${RUN_ROOT}/input-audit.log" "${ARTIFACT_ROOT}/input-audit.log"
cp "${RUN_ROOT}/reference-preflight.log" "${ARTIFACT_ROOT}/reference-preflight.log"
cp "${RUN_ROOT}/comparison.log" "${ARTIFACT_ROOT}/comparison.log"
cp "${RUN_ROOT}/comparison/result.json" "${ARTIFACT_ROOT}/comparison-result.json"
cp "${RUN_ROOT}/comparison/inventory_audit.json" "${ARTIFACT_ROOT}/comparison-inventory.json"
cp "${RUN_ROOT}/comparison/review.md" "${ARTIFACT_ROOT}/comparison-review.md"
cp "${BUILD_ROOT}/SHA256SUMS" "${ARTIFACT_ROOT}/build-SHA256SUMS"
cp "${RUN_ROOT}/SHA256SUMS" "${ARTIFACT_ROOT}/run-SHA256SUMS"
cp "${BUILD_ROOT}/mpi-debug/fingerprint.txt" "${ARTIFACT_ROOT}/mpi-debug-fingerprint.txt"

python3 "${CASE_DIR}/audit_p52_evidence.py" "${ARTIFACT_ROOT}" \
  --repo-root "${REPO_ROOT}" --build-root "${BUILD_ROOT}" --run-root "${RUN_ROOT}" \
  --report "${ARTIFACT_ROOT}/independent-audit.json" \
  > "${ARTIFACT_ROOT}/independent-audit.log"
grep -q 'P5.2 INDEPENDENT EVIDENCE AUDIT PASS' \
  "${ARTIFACT_ROOT}/independent-audit.log" || fail 'independent evidence audit marker missing'
record_pass p52-independent-evidence-audit 'independent provenance/build/reference/call/inventory/numerical/hash audit passes'

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

log "P5.2 GATE PASS (${#FINAL_ROWS[@]}/${#FINAL_ROWS[@]})"
log "build root: ${BUILD_ROOT}"
log "run root: ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
