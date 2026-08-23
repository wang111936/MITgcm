#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase01-state}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase01-state}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXPECTED_SHA="${REPO_ROOT}/verification/bom/phase00-skeleton/exp2_checkpoint.sha256"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXP2_INPUT="${REPO_ROOT}/verification/exp2/input"
readonly P0_CASE="${REPO_ROOT}/verification/bom/phase00-zero-particle"

fail() {
  printf 'P1.1 STATE GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.1] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

for required_command in bash make nm python3 sha256sum grep mpirun shellcheck; do
  require_command "${required_command}"
done

[[ -x "${REPO_ROOT}/tools/genmake2" ]] || fail "genmake2 is not executable"
[[ -f "${OPTFILE}" ]] || fail "optfile not found: ${OPTFILE}"
[[ -f "${EXPECTED_SHA}" ]] || fail "checkpoint manifest not found"
[[ ! -e "${BUILD_ROOT}" ]] || fail "build root already exists: ${BUILD_ROOT}"
[[ ! -e "${RUN_ROOT}" ]] || fail "run root already exists: ${RUN_ROOT}"

mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}"

bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${RUN_ROOT}/pycache" python3 -m py_compile \
  "${CASE_DIR}/make_initial.py"

printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

build_case() {
  local case_name="$1"
  local size_file="$2"
  local mpi_enabled="$3"
  local debug_enabled="$4"
  local build_dir="${BUILD_ROOT}/${case_name}"
  local mods_dir="${BUILD_ROOT}/${case_name}-mods"
  local -a genmake_args

  log "build ${case_name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${size_file}" "${mods_dir}/SIZE.h"
  cp "${P0_CASE}/code/packages.conf" "${mods_dir}/packages.conf"

  genmake_args=(
    "${REPO_ROOT}/tools/genmake2"
    "-rootdir=${REPO_ROOT}"
    "-mods=${mods_dir}"
    "-of=${OPTFILE}"
  )
  if [[ "${mpi_enabled}" == yes ]]; then
    genmake_args+=( -mpi )
  fi

  (
    cd "${build_dir}"
    if [[ "${debug_enabled}" == yes ]]; then
      env IEEE=t DEVEL=t "${genmake_args[@]}" > genmake.log 2>&1
    else
      "${genmake_args[@]}" > genmake.log 2>&1
    fi
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable: ${case_name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_init_state_ bom_read_initial_ bom_locate_initial_ bom_id_from_words_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${case_name}"
  done
  printf '%s\tPASS\tbuild, link, and P1.1 symbols\n' "${case_name}" \
    >> "${RUN_ROOT}/summary.tsv"
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local bom_input="$3"
  local scenario="$4"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp -a "${EXP2_INPUT}/." "${run_dir}/"
  cp "${P0_CASE}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${bom_input}" "${run_dir}/data.bom"
  if [[ "${scenario}" != none ]]; then
    python3 "${CASE_DIR}/make_initial.py" \
      "${scenario}" "${run_dir}/bom_particles"
    sha256sum "${run_dir}/bom_particles.data" \
      "${run_dir}/bom_particles.meta" > "${run_dir}/initial.sha256"
  fi
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" "${run_dir}/mitgcmuv"
}

assert_log_normal() {
  local log_file="$1"
  [[ -f "${log_file}" ]] || fail "missing log: ${log_file}"
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" \
    || fail "normal-end marker missing: ${log_file}"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

assert_bom_lifecycle() {
  local log_file="$1"
  grep -Eq 'pkg/bom.*compiled.*used' "${log_file}" \
    || fail "BOM activation evidence missing: ${log_file}"
  grep -q 'BOM_CHECK: Phase-1.1 state and initial-file gate' "${log_file}" \
    || fail "P1.1 check evidence missing: ${log_file}"
  grep -q 'BOM_CHECK: done' "${log_file}" \
    || fail "BOM_CHECK completion missing: ${log_file}"
}

check_hashes() {
  local run_dir="$1"
  (
    cd "${run_dir}"
    sha256sum -c "${EXPECTED_SHA}" > checkpoint-check.log
  ) || fail "checkpoint mismatch: ${run_dir}"
}

assert_state() {
  local combined_log="$1"
  local scenario="$2"
  local id_count
  local expected_owners
  local expected_alive
  local expected_waiting
  local -a expected_ids

  case "${scenario}" in
    one)
      expected_owners=1
      expected_alive=1
      expected_waiting=0
      expected_ids=(1)
      ;;
    two)
      expected_owners=2
      expected_alive=2
      expected_waiting=0
      expected_ids=(1 4294967301)
      ;;
    valid)
      expected_owners=3
      expected_alive=2
      expected_waiting=1
      expected_ids=(1 4294967301 9007199254740993)
      ;;
    *)
      fail "unsupported positive state scenario: ${scenario}"
      ;;
  esac

  grep -Eq "BOM_READ_INITIAL: complete +owners= +${expected_owners} +alive= +${expected_alive} +waiting= +${expected_waiting}" \
    "${combined_log}" || fail "state summary mismatch: ${combined_log}"
  id_count="$(grep -Ec 'BOM_READ_INITIAL: id=' "${combined_log}")"
  [[ "${id_count}" -eq "${expected_owners}" ]] \
    || fail "expected ${expected_owners} unique owner records, got ${id_count}"
  for particle_id in "${expected_ids[@]}"; do
    [[ "$(grep -Ec "id= *${particle_id} +rank=.*tile=" "${combined_log}")" -eq 1 ]] \
      || fail "ID ${particle_id} does not have exactly one owner"
  done
  if [[ "${scenario}" == valid ]]; then
    grep -Eq 'id= *9007199254740993 +rank=.*tile=.*status= *6' \
      "${combined_log}" || fail "WAITING state or large ID was not preserved"
  fi
}

run_positive() {
  local run_name="$1"
  local build_name="$2"
  local ranks="$3"
  local bom_input="$4"
  local scenario="$5"
  local run_dir="${RUN_ROOT}/${run_name}"
  local combined_log="${run_dir}/combined.log"
  local rank
  local rank_log

  log "run ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${bom_input}" "${scenario}"
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    assert_log_normal "${run_dir}/run.log"
    assert_bom_lifecycle "${run_dir}/run.log"
    cp "${run_dir}/run.log" "${combined_log}"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    : > "${combined_log}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_log_normal "${rank_log}"
      cat "${rank_log}" >> "${combined_log}"
    done
    assert_bom_lifecycle "${run_dir}/STDOUT.0000"
  fi
  if [[ "${scenario}" == one || "${scenario}" == two \
     || "${scenario}" == valid ]]; then
    assert_state "${combined_log}" "${scenario}"
  fi
  if [[ "${run_name}" == valid-mpi4 ]]; then
    grep -Eq 'id= *4294967301 +rank= *3 +tile=.*xy= *180\.0000 +0\.0000' \
      "${combined_log}" || fail "corner owner is not the north-east half-open tile"
  fi
  check_hashes "${run_dir}"
  printf '%s\tPASS\tnormal end; state and 8/8 hashes\n' "${run_name}" \
    >> "${RUN_ROOT}/summary.tsv"
}

run_negative() {
  local run_name="$1"
  local bom_input="$2"
  local scenario="$3"
  local expected_text="$4"
  local run_dir="${RUN_ROOT}/${run_name}"
  local process_status

  log "run expected failure ${run_name}"
  prepare_run "${run_name}" serial "${bom_input}" "${scenario}"
  set +e
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  process_status=$?
  set -e

  if grep -q 'PROGRAM MAIN: Execution ended Normally' "${run_dir}/run.log"; then
    fail "negative gate ended normally: ${run_name}"
  fi
  grep -q "${expected_text}" "${run_dir}/run.log" \
    || fail "expected rejection text missing: ${run_name}"
  grep -Eq 'ABNORMAL END|Fortran runtime error|Error termination' \
    "${run_dir}/run.log" \
    || fail "failure marker missing: ${run_name}"
  printf '%s\tPASS\trejected; process status=%s\n' \
    "${run_name}" "${process_status}" >> "${RUN_ROOT}/summary.tsv"
}

build_case serial "${EXP2_CODE}/SIZE.h" no no
build_case mpi2 "${EXP2_CODE}/SIZE.h_mpi" yes no
build_case mpi4 "${P0_CASE}/code/SIZE.h.mpi4" yes no
build_case debug "${EXP2_CODE}/SIZE.h" no yes

run_positive zero-serial serial 1 "${P0_CASE}/input/data.bom" none
run_positive one-serial serial 1 "${CASE_DIR}/input/data.bom.one" one
run_positive two-serial serial 1 "${CASE_DIR}/input/data.bom.two" two
run_positive valid-serial serial 1 "${CASE_DIR}/input/data.bom.valid" valid
run_positive valid-mpi2 mpi2 2 "${CASE_DIR}/input/data.bom.valid" valid
run_positive valid-mpi4 mpi4 4 "${CASE_DIR}/input/data.bom.valid" valid
run_positive valid-debug debug 1 "${CASE_DIR}/input/data.bom.valid" valid

run_negative duplicate-id "${CASE_DIR}/input/data.bom.two" \
  duplicate 'duplicate ID='
run_negative bad-schema "${CASE_DIR}/input/data.bom.valid" \
  bad-schema 'schema='
run_negative bad-id "${CASE_DIR}/input/data.bom.one" \
  bad-id 'invalid ID record='
run_negative bad-status "${CASE_DIR}/input/data.bom.one" \
  bad-status 'invalid status record='
run_negative nan-coordinate "${CASE_DIR}/input/data.bom.one" \
  nan-coordinate 'non-finite record='
run_negative infinite-age "${CASE_DIR}/input/data.bom.one" \
  infinite-age 'non-finite record='
run_negative bad-release "${CASE_DIR}/input/data.bom.one" \
  bad-release 'invalid release time record='
run_negative truncated-file "${CASE_DIR}/input/data.bom.one" \
  truncated 'MDS_READVEC_LOC'
run_negative outside-domain "${CASE_DIR}/input/data.bom.one" \
  outside 'owner count='
run_negative tile-capacity "${CASE_DIR}/input/data.bom.capacity" \
  capacity 'capacity='
run_negative global-limit "${CASE_DIR}/input/data.bom.limit" \
  limit 'invalid particle count='
run_negative premature-stokes "${CASE_DIR}/input/data.bom.stokes" \
  valid 'Phase-1 Stokes source must be NONE'
run_negative bad-mode "${CASE_DIR}/input/data.bom.bad-mode" \
  none 'unsupported bomMode:'
run_negative bad-integrator "${CASE_DIR}/input/data.bom.bad-integrator" \
  none 'unsupported bomIntegrator:'
run_negative bad-step "${CASE_DIR}/input/data.bom.bad-step" \
  none 'bomDeltaTTarget must be positive'
run_negative bad-frequency "${CASE_DIR}/input/data.bom.bad-frequency" \
  none 'output frequencies must be non-negative'

log "P1.1 STATE GATE PASS"
log "build root: ${BUILD_ROOT}"
log "run root:   ${RUN_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
