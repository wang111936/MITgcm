#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p13-lifecycle-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
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

fail() {
  printf 'P1.3 LIFECYCLE GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.3-lifecycle] %s\n' "$*"
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
  local -a symbols
  local symbol

  log "build ${case_name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_lifecycle.F" "${mods_dir}/"
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
    bom_main_
    bom_release_step_
    bom_substep_setup_
    bom_substep_bounds_
    bom_check_state_
    bom_sort_id_words_
    bom_rk2_
    bom_rk4_
    bom_verify_lifecycle_
  )
  for symbol in "${symbols[@]}"; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" || fail "missing ${symbol} in ${case_name}"
  done
  record_pass "build-${case_name}" 'GNU debug/IEEE build and production lifecycle symbols'
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local scenario="$3"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data.cartesian" "${run_dir}/data"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/data.bom" "${run_dir}/data.bom"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  sed -i "s/the_run_name='P1-S04B-RK4'/the_run_name='${scenario}'/" "${run_dir}/data"
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" "${run_dir}/mitgcmuv"
}

assert_normal_log() {
  local log_file="$1"

  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" || fail "normal-end marker missing: ${log_file}"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

collect_mpi_logs() {
  local run_dir="$1"
  local combined_log="$2"
  local ranks="$3"
  local rank
  local rank_log
  local rank_error_log

  : > "${combined_log}"
  if [[ -f "${run_dir}/mpi-launch.log" ]]; then
    cat "${run_dir}/mpi-launch.log" >> "${combined_log}"
  fi
  for ((rank=0; rank<ranks; rank++)); do
    printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
    if [[ -f "${rank_log}" ]]; then
      cat "${rank_log}" >> "${combined_log}"
    fi
    printf -v rank_error_log '%s/STDERR.%04d' "${run_dir}" "${rank}"
    if [[ -f "${rank_error_log}" ]]; then
      cat "${rank_error_log}" >> "${combined_log}"
    fi
  done
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
    collect_mpi_logs "${run_dir}" "${combined_log}" "${ranks}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_normal_log "${rank_log}"
    done
  fi
  [[ "$(grep -c "${expected_text}" "${combined_log}")" -eq 1 ]] || fail "PASS marker count is not one: ${run_name}"
  record_pass "${run_name}" "${expected_text}"
}

run_negative() {
  local run_name="$1"
  local build_name="$2"
  local ranks="$3"
  local scenario="$4"
  local expected_regex="$5"
  local detail="$6"
  local run_dir="${RUN_ROOT}/${run_name}"
  local combined_log="${run_dir}/combined.log"
  local rc

  log "run expected failure ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${scenario}"
  set +e
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    rc=$?
    cp "${run_dir}/run.log" "${combined_log}"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    rc=$?
    collect_mpi_logs "${run_dir}" "${combined_log}" "${ranks}"
  fi
  set -e
  grep -Eq "${expected_regex}" "${combined_log}" || fail "expected diagnostic missing: ${run_name}"
  grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE' "${combined_log}" || fail "fatal marker missing: ${run_name}"
  if grep -q 'PROGRAM MAIN: Execution ended Normally' "${combined_log}"; then
    fail "normal-end marker found in negative scenario: ${run_name}"
  fi
  record_pass "${run_name}" "${detail}; fatal log; rc=${rc}"
}

log 'audit production/test separation and frozen lifecycle contract'
readonly MAIN_SOURCE="${REPO_ROOT}/pkg/bom/bom_main.F"
readonly RELEASE_SOURCE="${REPO_ROOT}/pkg/bom/bom_release_step.F"
readonly SUBSTEP_SOURCE="${REPO_ROOT}/pkg/bom/bom_substep_setup.F"
readonly CHECK_SOURCE="${REPO_ROOT}/pkg/bom/bom_check_state.F"
for source_file in "${MAIN_SOURCE}" "${RELEASE_SOURCE}" "${SUBSTEP_SOURCE}" "${CHECK_SOURCE}"; do
  [[ -f "${source_file}" ]] || fail "missing production lifecycle source: ${source_file}"
done
[[ "$(grep -c 'CALL BOM_RELEASE_STEP' "${MAIN_SOURCE}")" -eq 1 ]] || fail 'BOM_MAIN must use the stateless release helper once per slot/substep'
[[ "$(grep -c 'CALL BOM_CHECK_STATE' "${MAIN_SOURCE}")" -eq 3 ]] || fail 'BOM_MAIN must budget start, optional substeps, and end'
grep -Fq 'nSub = MAX(1,CEILING(subRatio))' "${SUBSTEP_SOURCE}" || fail 'equal substep count is not frozen'
grep -Fq 'tSub1 = stepEnd' "${SUBSTEP_SOURCE}" || fail 'final endpoint is not forced'
grep -Fq 'releaseEffective.GT.tSub1' "${RELEASE_SOURCE}" || fail 'future WAITING branch is missing'
grep -Fq 'doAdvance = dtActive.GT.0.' "${RELEASE_SOURCE}" || fail 'zero-active-time distinction is missing'
grep -Fq 'age0.GT.HUGE(ageCandidate)-dtActive' "${RELEASE_SOURCE}" || fail 'age overflow guard is missing'
grep -Fq 'MPI_Allgather' "${CHECK_SOURCE}" || fail 'global ID count gather is missing'
[[ "$(grep -c 'MPI_Allgatherv' "${CHECK_SOURCE}")" -eq 2 ]] || fail 'exact two-word ID gather is missing'
grep -Fq 'idRadix = 4294967296_8' "${CHECK_SOURCE}" || fail 'schema-1 ID radix is missing'
grep -Fq 'duplicate ID words=' "${CHECK_SOURCE}" || fail 'exact duplicate check is missing'
grep -Fq 'bomStatus(ip,bi,bj).NE.BOM_UNUSED' "${CHECK_SOURCE}" || fail 'compact tail status check is missing'
grep -Fq 'bomNPartExpected' "${CHECK_SOURCE}" || fail 'immutable owner budget check is missing'
if rg -n 'BOM_VERIFY_LIFECYCLE|P1-S04B|P1-LIFECYCLE' "${REPO_ROOT}/pkg/bom"; then
  fail 'lifecycle verification marker leaked into production BOM'
fi
if rg -n 'CALL[[:space:]]+BOM_.*MIGRAT' "${MAIN_SOURCE}"; then
  fail 'P1.4 owner migration leaked into the P1.3 lifecycle caller'
fi
record_pass source-contract 'equal substeps; exact release/age transactions; compact global state budget'

build_case serial "${FIELD_CASE}/code/SIZE.h.serial" no
build_case mpi4 "${FIELD_CASE}/code/SIZE.h.mpi4" yes

run_case s04b-rk2-serial serial 1 P1-S04B-RK2 'P1-S04B RK2 PASS: exact release transactions'
run_case s04b-rk4-serial serial 1 P1-S04B-RK4 'P1-S04B RK4 PASS: exact release transactions'
run_case i01-lifecycle-serial serial 1 P1-I01-LIFE 'P1-I01 LIFECYCLE PASS: zero ALIVE and WAITING'
run_case lifecycle-mpi4 mpi4 4 P1-LIFE-MPI4 'P1-LIFECYCLE MPI4 PASS: exact global ID budget'

run_negative n08-age-serial serial 1 P1-N08-AGE 'stage/code=[[:space:]]+0[[:space:]]+5' 'age overflow rejected before authoritative commit'
run_negative n08-duplicate-mpi4 mpi4 4 P1-N08-DUPID 'duplicate ID words=' 'duplicate 64-bit ID rejected across ranks'
run_negative n08-count-serial serial 1 P1-N08-COUNT 'owner/expected mismatch=' 'global owner budget mismatch rejected'
run_negative n08-tail-serial serial 1 P1-N08-TAIL 'tail tile/slot=' 'non-compact tail rejected'
run_negative n08-status-serial serial 1 P1-N08-STATUS 'invalid status=' 'unsupported P1.3 status rejected'
run_negative n08-owner-serial serial 1 P1-N08-OWNER 'stage/code=[[:space:]]+4[[:space:]]+2' 'RK4 K4 owner departure rejected before commit'

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${ARTIFACT_ROOT}/source-head.txt"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv source-head.txt > manifest.sha256
)

PASS_COUNT="$(grep -c $'\tPASS\t' "${RUN_ROOT}/summary.tsv")"
readonly PASS_COUNT
[[ "${PASS_COUNT}" -eq 13 ]] || fail "expected 13 PASS rows, found ${PASS_COUNT}"
log 'P1.3 LIFECYCLE GATE PASS (13/13)'
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
