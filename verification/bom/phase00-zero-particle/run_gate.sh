#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase00-zero-particle}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase00-zero-particle}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXPECTED_SHA="${REPO_ROOT}/verification/bom/phase00-skeleton/exp2_checkpoint.sha256"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXP2_INPUT="${REPO_ROOT}/verification/exp2/input"

fail() {
  printf 'P0.4 GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P0.4] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

for required_command in bash make sha256sum grep mpirun; do
  require_command "${required_command}"
done

[[ -x "${REPO_ROOT}/tools/genmake2" ]] || fail "genmake2 is not executable"
[[ -f "${OPTFILE}" ]] || fail "optfile not found: ${OPTFILE}"
[[ -f "${EXPECTED_SHA}" ]] || fail "checkpoint manifest not found"
[[ ! -e "${BUILD_ROOT}" ]] || fail "build root already exists: ${BUILD_ROOT}"
[[ ! -e "${RUN_ROOT}" ]] || fail "run root already exists: ${RUN_ROOT}"

mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

build_case() {
  local case_name="$1"
  local size_file="$2"
  local packages_file="$3"
  local mpi_enabled="$4"
  local build_dir="${BUILD_ROOT}/${case_name}"
  local mods_dir="${BUILD_ROOT}/${case_name}-mods"
  local -a genmake_args

  log "build ${case_name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${size_file}" "${mods_dir}/SIZE.h"
  cp "${packages_file}" "${mods_dir}/packages.conf"

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
    "${genmake_args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable: ${case_name}"
  printf '%s\tPASS\tbuild and link\n' "${case_name}" >> "${RUN_ROOT}/summary.tsv"
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local bom_input="$3"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp -a "${EXP2_INPUT}/." "${run_dir}/"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  if [[ "${bom_input}" != none ]]; then
    cp "${bom_input}" "${run_dir}/data.bom"
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
  grep -q 'BOM_READPARMS: finished reading data.bom' "${log_file}" \
    || fail "BOM_READPARMS evidence missing: ${log_file}"
  grep -q 'BOM_CHECK: done' "${log_file}" \
    || fail "BOM_CHECK evidence missing: ${log_file}"
  grep -q 'BOM               \[FORWARD_STEP\]' "${log_file}" \
    || fail "BOM_MAIN timer evidence missing: ${log_file}"
}

check_hashes() {
  local run_dir="$1"
  (
    cd "${run_dir}"
    sha256sum -c "${EXPECTED_SHA}" > checkpoint-check.log
  ) || fail "checkpoint mismatch: ${run_dir}"
}

run_positive() {
  local run_name="$1"
  local build_name="$2"
  local ranks="$3"
  local run_dir="${RUN_ROOT}/${run_name}"
  local rank
  local rank_log

  log "run ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${CASE_DIR}/input/data.bom"
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    assert_log_normal "${run_dir}/run.log"
    assert_bom_lifecycle "${run_dir}/run.log"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_log_normal "${rank_log}"
    done
    assert_bom_lifecycle "${run_dir}/STDOUT.0000"
  fi
  check_hashes "${run_dir}"
  printf '%s\tPASS\tnormal end; 8/8 hashes\n' "${run_name}" \
    >> "${RUN_ROOT}/summary.tsv"
}

run_negative() {
  local run_name="$1"
  local build_name="$2"
  local bom_input="$3"
  local expected_text="$4"
  local run_dir="${RUN_ROOT}/${run_name}"
  local process_status

  log "run expected failure ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${bom_input}"
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
  grep -q 'ABNORMAL END' "${run_dir}/run.log" \
    || fail "abnormal-end marker missing: ${run_name}"
  printf '%s\tPASS\trejected; process status=%s\n' \
    "${run_name}" "${process_status}" >> "${RUN_ROOT}/summary.tsv"
}

build_case serial-on "${EXP2_CODE}/SIZE.h" \
  "${CASE_DIR}/code/packages.conf" no
build_case mpi2-on "${EXP2_CODE}/SIZE.h_mpi" \
  "${CASE_DIR}/code/packages.conf" yes
build_case mpi4-on "${CASE_DIR}/code/SIZE.h.mpi4" \
  "${CASE_DIR}/code/packages.conf" yes
build_case serial-off "${EXP2_CODE}/SIZE.h" \
  "${CASE_DIR}/code/packages.off.conf" no

run_positive serial-on serial-on 1
run_positive mpi2-on mpi2-on 2
run_positive mpi4-on mpi4-on 4

run_negative uncompiled-activation serial-off none 'ALLOW_BOM undef'
run_negative nonzero-particles serial-on \
  "${CASE_DIR}/input/data.bom.nonzero" \
  'particle state is unavailable in Phase 0'

log "P0.4 GATE PASS"
log "build root: ${BUILD_ROOT}"
log "run root:   ${RUN_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
