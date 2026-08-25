#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p13-rk4-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase01-single-tile}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase01-single-tile}"
readonly ARTIFACT_PARENT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly ARTIFACT_ROOT="${ARTIFACT_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly FIELD_CASE="${REPO_ROOT}/verification/bom/phase01-fields"
readonly JULIA_BIN="${MITGCM_BOM_JULIA:-/home/wyl/opt/mitgcm-bom/juliaup/bin/julia}"
readonly JULIA_DEPOT="${MITGCM_BOM_JULIA_DEPOT:-/home/wyl/opt/mitgcm-bom/julia-depot}"
readonly JULIA_REFERENCE="${MITGCM_BOM_JULIA_REFERENCE:-/home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl}"
readonly EXPECTED_JULIA_COMMIT="156557359185e4413ce82829f3ed26a4eb8c6283"

fail() {
  printf 'P1.3 RK4 GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.3-rk4] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

required_commands=(
  bash make nm grep git rg sed shellcheck mpirun sha256sum
)
for required_command in "${required_commands[@]}"; do
  require_command "${required_command}"
done
[[ -x "${REPO_ROOT}/tools/genmake2" ]] || fail 'genmake2 is not executable'
[[ -f "${OPTFILE}" ]] || fail "optfile not found: ${OPTFILE}"
[[ -x "${JULIA_BIN}" ]] || fail "Julia not found: ${JULIA_BIN}"
[[ -d "${JULIA_REFERENCE}/.git" ]] || fail "Julia reference missing: ${JULIA_REFERENCE}"
for fresh_root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${fresh_root}" ]] || fail "evidence root already exists: ${fresh_root}"
done

mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

build_case() {
  local case_name="$1"
  local size_file="$2"
  local mpi_enabled="$3"
  local build_dir="${BUILD_ROOT}/${case_name}"
  local mods_dir="${BUILD_ROOT}/${case_name}-mods"
  local -a genmake_args

  log "build ${case_name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_rk4.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/"

  genmake_args=(
    "${REPO_ROOT}/tools/genmake2"
    "-rootdir=${REPO_ROOT}"
    "-mods=${mods_dir}"
    "-of=${OPTFILE}"
    -ieee
    -devel
  )
  if [[ "${mpi_enabled}" == yes ]]; then
    genmake_args+=( -mpi )
  fi

  (
    cd "${build_dir}"
    "${genmake_args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable: ${case_name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  symbols=(
    bom_rk4_
    bom_rk_coord_update_
    bom_rk4_coord_update_
    bom_rhs_leeway_
    bom_verify_rk4_
  )
  for symbol in "${symbols[@]}"; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" || fail "missing ${symbol} in ${case_name}"
  done
  record_pass "build-${case_name}" 'GNU debug/IEEE build and stateless RK4 symbols'
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local scenario="$3"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  if [[ "${scenario}" == P1-I03-SPHERE ]]; then
    cp "${CASE_DIR}/input/data.spherical" "${run_dir}/data"
  else
    cp "${CASE_DIR}/input/data.cartesian" "${run_dir}/data"
    sed -i "s/the_run_name='P1-I01-ZERO'/the_run_name='${scenario}'/" "${run_dir}/data"
  fi
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/data.bom" "${run_dir}/data.bom"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" "${run_dir}/mitgcmuv"
}

assert_normal_log() {
  local log_file="$1"

  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" || fail "normal-end marker missing: ${log_file}"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

run_case() {
  local run_name="$1"
  local build_name="$2"
  local ranks="$3"
  local scenario="$4"
  local expected_text="$5"
  local run_dir="${RUN_ROOT}/${run_name}"
  local combined_log="${run_dir}/combined.log"
  local rank
  local rank_log

  log "run ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${scenario}"
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    assert_normal_log "${run_dir}/run.log"
    cp "${run_dir}/run.log" "${combined_log}"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    : > "${combined_log}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_normal_log "${rank_log}"
      cat "${rank_log}" >> "${combined_log}"
    done
  fi
  [[ "$(grep -c "${expected_text}" "${combined_log}")" -eq 1 ]] || fail "RK4 PASS marker count is not one: ${run_name}"
  record_pass "${run_name}" "${expected_text}"
}

log 'audit production/test separation and frozen RK4 contract'
readonly RK4_SOURCE="${REPO_ROOT}/pkg/bom/bom_rk4.F"
readonly UPDATE_SOURCE="${REPO_ROOT}/pkg/bom/bom_rk_coord_update.F"
readonly WEIGHTED_UPDATE_SOURCE="${REPO_ROOT}/pkg/bom/bom_rk4_coord_update.F"
readonly BOM_HEADER="${REPO_ROOT}/pkg/bom/BOM.h"
[[ -f "${RK4_SOURCE}" ]] || fail 'production RK4 routine is missing'
[[ -f "${UPDATE_SOURCE}" ]] || fail 'overflow-safe coordinate helper is missing'
[[ -f "${WEIGHTED_UPDATE_SOURCE}" ]] || fail 'RK4 weighted coordinate helper is missing'
[[ "$(grep -c 'CALL BOM_RHS_LEEWAY' "${RK4_SOURCE}")" -eq 5 ]] || fail 'RK4 must perform K1-K4 and FINAL full RHS calls'
[[ "$(grep -c 'CALL BOM_RK_COORD_UPDATE' "${RK4_SOURCE}")" -eq 6 ]] || fail 'RK4 must guard both coordinates at K2-K4'
[[ "$(grep -c 'CALL BOM_RK4_COORD_UPDATE' "${RK4_SOURCE}")" -eq 2 ]] || fail 'RK4 must guard both weighted final coordinates'
contract_texts=(
  'SUBROUTINE BOM_RK4'
  'x0, k1X, deltaT, 0.5'
  'x0, k2X, deltaT, 0.5'
  'x0, k3X, deltaT, 1.'
  'x0, k1X, k2X, k3X, k4X, deltaT'
  'xTrial, yTrial, 0.'
  'failStage = BOM_STAGE_K1'
  'failStage = BOM_STAGE_K2'
  'failStage = BOM_STAGE_K3'
  'failStage = BOM_STAGE_K4'
  'failStage = BOM_STAGE_FINAL'
)
for contract_text in "${contract_texts[@]}"; do
  grep -Fq "${contract_text}" "${RK4_SOURCE}" || fail "missing RK4 contract: ${contract_text}"
done
guard_texts=(
  'FRACTION(deltaT)*FRACTION(stageFactor)'
  'productExponent.GT.MAXEXPONENT(increment)'
  'SCALE(productFraction,productExponent)'
  'trialCoord = baseCoord'
)
for guard_text in "${guard_texts[@]}"; do
  grep -Fq "${guard_text}" "${UPDATE_SOURCE}" || fail "missing coordinate guard: ${guard_text}"
done
weighted_guard_texts=(
  'rateScale = MAX'
  '(rate1/rateScale)/6.'
  'CALL BOM_RK_COORD_UPDATE'
)
for guard_text in "${weighted_guard_texts[@]}"; do
  grep -Fq "${guard_text}" "${WEIGHTED_UPDATE_SOURCE}" || fail "missing RK4 weighted guard: ${guard_text}"
done
stage_codes=(
  'BOM_STAGE_NONE  = 0'
  'BOM_STAGE_K1    = 1'
  'BOM_STAGE_K2    = 2'
  'BOM_STAGE_K3    = 3'
  'BOM_STAGE_K4    = 4'
  'BOM_STAGE_FINAL = 5'
)
for stage_code in "${stage_codes[@]}"; do
  grep -Fq "${stage_code}" "${BOM_HEADER}" || fail "missing stable stage code: ${stage_code}"
done
if rg -n 'bom(X|Y|Age|Status|ReleaseTime|NPartTile)\([^)]*\)[[:space:]]*=' "${RK4_SOURCE}" "${UPDATE_SOURCE}" "${WEIGHTED_UPDATE_SOURCE}"; then
  fail 'RK4 writes authoritative particle state'
fi
if rg -n 'BOM_VERIFY_RK4|P1-I06|P1-N08' "${REPO_ROOT}/pkg/bom"; then
  fail 'RK4 verification marker leaked into production BOM'
fi
record_pass source-contract 'classical RK4; full RHS at K1-K4/final; rollback-only kernel'

log 'audit locked Julia Leeway reference'
[[ "$(git -C "${JULIA_REFERENCE}" rev-parse HEAD)" == "${EXPECTED_JULIA_COMMIT}" ]] || fail 'Julia reference commit changed'
git -C "${JULIA_REFERENCE}" diff --quiet || fail 'Julia reference worktree is dirty'
git -C "${JULIA_REFERENCE}" diff --cached --quiet || fail 'Julia reference index is dirty'
grep -Fq 'WATER_ITP.x.fields[:u](x, y, t) + α * WIND_ITP.x.fields[:u]' "${JULIA_REFERENCE}/src/physics.jl" || fail 'locked Julia east Leeway formula changed'
grep -Fq 'WATER_ITP.x.fields[:v](x, y, t) + α * WIND_ITP.x.fields[:v]' "${JULIA_REFERENCE}/src/physics.jl" || fail 'locked Julia north Leeway formula changed'
record_pass julia-source-contract 'commit 1565573; frozen water-plus-wind RHS reference'

build_case serial "${FIELD_CASE}/code/SIZE.h.serial" no
build_case mpi4 "${FIELD_CASE}/code/SIZE.h.mpi4" yes

run_case zero-serial serial 1 P1-RK4-ZERO 'P1-RK4 ZERO PASS: bitwise stationary step'
run_case zero-mpi4 mpi4 4 P1-RK4-ZERO 'P1-RK4 ZERO PASS: bitwise stationary step'
run_case constant-serial serial 1 P1-RK4-CONST 'P1-RK4 CONSTANT PASS: analytic displacement'
run_case constant-mpi4 mpi4 4 P1-RK4-CONST 'P1-RK4 CONSTANT PASS: analytic displacement'
run_case i03-spherical-serial serial 1 P1-I03-SPHERE 'P1-I03 RK4 PASS: spherical analytic displacement'
run_case i06-convergence-serial serial 1 P1-I06-RK4 'P1-I06 RK4 PASS: two finest orders='
run_case n08-rk4-serial serial 1 P1-N08-RK4 'P1-N08 RK4 PASS: staged failure rollback'

log 'run locked Julia affine RK4 convergence oracle'
env JULIA_DEPOT_PATH="${JULIA_DEPOT}" JULIA_PKG_OFFLINE=true "${JULIA_BIN}" --startup-file=no --history-file=no --project="${JULIA_REFERENCE}" "${CASE_DIR}/julia_rk4_smoke.jl" > "${RUN_ROOT}/julia-rk4.log" 2>&1
grep -q 'P1-I06 JULIA RK4 PASS' "${RUN_ROOT}/julia-rk4.log" || fail 'Julia RK4 marker missing'
grep -q 'sargassumbomb_version=0.7.14' "${RUN_ROOT}/julia-rk4.log" || fail 'Julia package version evidence missing'
record_pass julia-rk4 'SargassumBOMB 0.7.14 environment; affine classical-RK4 oracle'

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${ARTIFACT_ROOT}/source-head.txt"
git -C "${JULIA_REFERENCE}" rev-parse HEAD > "${ARTIFACT_ROOT}/julia-head.txt"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv source-head.txt julia-head.txt > manifest.sha256
)

log 'P1.3 RK4 GATE PASS'
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
