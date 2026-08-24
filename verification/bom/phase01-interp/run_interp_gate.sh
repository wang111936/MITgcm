#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p12-interp-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase01-interp}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase01-interp}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly FIELD_CASE="${REPO_ROOT}/verification/bom/phase01-fields"

fail() {
  printf 'P1.2 INTERP GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.2-interp] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 \
    || fail "required command not found: $1"
}

for required_command in bash make nm grep rg sed shellcheck mpirun; do
  require_command "${required_command}"
done

[[ -x "${REPO_ROOT}/tools/genmake2" ]] \
  || fail 'genmake2 is not executable'
[[ -f "${OPTFILE}" ]] || fail "optfile not found: ${OPTFILE}"
[[ ! -e "${BUILD_ROOT}" ]] \
  || fail "build root already exists: ${BUILD_ROOT}"
[[ ! -e "${RUN_ROOT}" ]] \
  || fail "run root already exists: ${RUN_ROOT}"

mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}"
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
  cp "${CASE_DIR}/code/bom_verify_interp.F" "${mods_dir}/"
  cp "${FIELD_CASE}/code/packages.conf" "${mods_dir}/"

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
  [[ -x "${build_dir}/mitgcmuv" ]] \
    || fail "missing executable: ${case_name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_interp_wet_pair_ bom_verify_interp_ \
                bom_verify_main_diagnostic_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${case_name}"
  done
  printf '%s\tPASS\tdebug build and interpolation symbols\n' \
    "build-${case_name}" >> "${RUN_ROOT}/summary.tsv"
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local scenario="$3"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${FIELD_CASE}/input/data" "${run_dir}/data"
  cp "${FIELD_CASE}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${FIELD_CASE}/input/data.bom" "${run_dir}/data.bom"
  cp "${FIELD_CASE}/input/eedata" "${run_dir}/eedata"
  sed -i \
    "s/the_run_name='P1-F01-UNIFORM'/the_run_name='${scenario}'/" \
    "${run_dir}/data"
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" \
    "${run_dir}/mitgcmuv"
}

assert_normal_log() {
  local log_file="$1"

  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" \
    || fail "normal-end marker missing: ${log_file}"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' \
      "${log_file}"; then
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
  local rank_err

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
  [[ "$(grep -c "${expected_text}" "${combined_log}")" -eq 1 ]] \
    || fail "interpolation PASS marker count is not one: ${run_name}"
  printf '%s\tPASS\t%s\n' "${run_name}" "${expected_text}" \
    >> "${RUN_ROOT}/summary.tsv"
}

run_negative() {
  local run_name="$1"
  local build_name="$2"
  local ranks="$3"
  local scenario="$4"
  local run_dir="${RUN_ROOT}/${run_name}"
  local combined_log="${run_dir}/combined.log"
  local process_status
  local rank
  local rank_log

  log "run expected failure ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${scenario}"
  set +e
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    process_status=$?
    cp "${run_dir}/run.log" "${combined_log}"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    process_status=$?
    cp "${run_dir}/mpi-launch.log" "${combined_log}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      if [[ -f "${rank_log}" ]]; then
        cat "${rank_log}" >> "${combined_log}"
      fi
      printf -v rank_err '%s/STDERR.%04d' "${run_dir}" "${rank}"
      if [[ -f "${rank_err}" ]]; then
        cat "${rank_err}" >> "${combined_log}"
      fi
    done
  fi
  set -e

  if grep -q 'PROGRAM MAIN: Execution ended Normally' "${combined_log}"; then
    fail "negative gate ended normally: ${run_name}"
  fi
  for expected_text in \
      'BOM_MAIN: invalid diagnostic ip=' \
      'BOM_MAIN: xMap/ix/jy/wetWeight=' \
      'BOM_MAIN: owner/stencil/interpValid=' \
      'fatal P1.2 particle diagnostic error(s)'; do
    grep -q "${expected_text}" "${combined_log}" \
      || fail "missing caller diagnostic in ${run_name}: ${expected_text}"
  done
  grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE|Error termination' \
    "${combined_log}" \
    || fail "failure marker missing: ${run_name}"
  printf '%s\tPASS\tcaller rejected; process status=%s\n' \
    "${run_name}" "${process_status}" >> "${RUN_ROOT}/summary.tsv"
}

log 'audit production/test separation and interpolation contract'
readonly INTERP_SOURCE="${REPO_ROOT}/pkg/bom/bom_interp_wet_pair.F"
readonly MAIN_SOURCE="${REPO_ROOT}/pkg/bom/bom_main.F"
grep -q 'SUBROUTINE BOM_INTERP_WET_PAIR' "${INTERP_SOURCE}" \
  || fail 'production interpolation routine is missing'
for contract_text in bomFieldsReady bomWetWeightMin maskC \
                     'ix.LT.DFLOAT(1-OLx)' \
                     'INT(ix)' 'DFLOAT(i1).GT.ix'; do
  grep -q "${contract_text}" "${INTERP_SOURCE}" \
    || fail "missing interpolation contract: ${contract_text}"
done
grep -q 'CALL BOM_MAP_XY2IJLOCAL' "${MAIN_SOURCE}" \
  || fail 'production BOM_MAIN does not map existing records'
grep -q 'CALL BOM_INTERP_WET_PAIR' "${MAIN_SOURCE}" \
  || fail 'production BOM_MAIN does not interpolate existing records'
if rg -n 'bom(X|Y|Age|Status|ReleaseTime)\(ip,bi,bj\)[[:space:]]*=' \
    "${MAIN_SOURCE}"; then
  fail 'P1.2 BOM_MAIN modifies authoritative particle state'
fi
if rg -n 'CALL FLT_|BOM_VERIFY_INTERP|P1-F03|P1-N05' \
    "${REPO_ROOT}/pkg/bom"; then
  fail 'FLT call or verification marker leaked into production'
fi
printf 'source-contract\tPASS\tshared wet pair and explicit invalid result\n' \
  >> "${RUN_ROOT}/summary.tsv"

build_case serial "${FIELD_CASE}/code/SIZE.h.serial" no
build_case mpi4 "${FIELD_CASE}/code/SIZE.h.mpi4" yes

run_case f03-full-serial serial 1 P1-F03-FULL \
  'P1-F03 FULL PASS: constant and linear wet-pair fields'
run_case f03-full-mpi4 mpi4 4 P1-F03-FULL \
  'P1-F03 FULL PASS: constant and linear wet-pair fields'
run_case f03-partial-serial serial 1 P1-F03-PARTIAL \
  'P1-F03 PARTIAL PASS: shared normalized wet weights'
run_case f03-partial-mpi4 mpi4 4 P1-F03-PARTIAL \
  'P1-F03 PARTIAL PASS: shared normalized wet weights'
run_case n05-serial serial 1 P1-N05-INVALID \
  'P1-N05 PASS: invalid interpolation contracts'
run_case n05-mpi4 mpi4 4 P1-N05-INVALID \
  'P1-N05 PASS: invalid interpolation contracts'
run_case lifecycle-serial serial 1 P1-P12-LIFECYCLE \
  'P1.2 LIFECYCLE PASS: non-moving production diagnostics'
run_case lifecycle-mpi4 mpi4 4 P1-P12-LIFECYCLE \
  'P1.2 LIFECYCLE PASS: non-moving production diagnostics'
run_negative n05-main-outside-serial serial 1 \
  P1-N05-MAIN-OUTSIDE
run_negative n05-main-outside-mpi4 mpi4 4 \
  P1-N05-MAIN-OUTSIDE
run_negative n05-main-wet-serial serial 1 \
  P1-N05-MAIN-WET
run_negative n05-main-wet-mpi4 mpi4 4 \
  P1-N05-MAIN-WET

log 'P1.2 INTERP GATE PASS'
log "build root: ${BUILD_ROOT}"
log "run root:   ${RUN_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
