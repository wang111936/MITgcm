#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p13-setup-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase01-single-tile}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase01-single-tile}"
readonly ARTIFACT_PARENT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly ARTIFACT_ROOT="${ARTIFACT_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"

fail() {
  printf 'P1.3 SETUP GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.3-setup] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 \
    || fail "required command not found: $1"
}

for required_command in bash make nm grep rg sed shellcheck mpirun sha256sum; do
  require_command "${required_command}"
done

[[ -x "${REPO_ROOT}/tools/genmake2" ]] \
  || fail 'genmake2 is not executable'
[[ -f "${OPTFILE}" ]] || fail "optfile not found: ${OPTFILE}"
for fresh_root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${fresh_root}" ]] \
    || fail "evidence root already exists: ${fresh_root}"
done

mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

build_case() {
  local case_name="$1"
  local packages_file="$2"
  local size_file="$3"
  local mpi_enabled="$4"
  local expect_exf="$5"
  local build_dir="${BUILD_ROOT}/${case_name}"
  local mods_dir="${BUILD_ROOT}/${case_name}-mods"
  local -a genmake_args

  log "build ${case_name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/${packages_file}" "${mods_dir}/packages.conf"

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
  for symbol in bom_check_ bom_init_state_ bom_read_initial_ \
                bom_build_fields_ bom_verify_setup_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${case_name}"
  done
  if [[ "${expect_exf}" == yes ]]; then
    grep -q 'exf_init_varia_' "${build_dir}/symbols.txt" \
      || fail "EXF symbol missing in ${case_name}"
  elif grep -q 'exf_init_varia_' "${build_dir}/symbols.txt"; then
    fail "EXF symbol leaked into ${case_name}"
  fi
  record_pass "build-${case_name}" \
    "debug build; BOM setup symbols; EXF=${expect_exf}"
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local scenario="$3"
  local package_input="$4"
  local bom_input="$5"
  local exf_input="$6"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/${package_input}" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/${bom_input}" "${run_dir}/data.bom"
  if [[ "${exf_input}" != none ]]; then
    cp "${CASE_DIR}/input/${exf_input}" "${run_dir}/data.exf"
  fi
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
  grep -Eq 'BOM_CHECK: substep preflight ratio= *4\.00000000E\+00 +nSub= *4 +dtSub= *3\.00000000E\+02' \
    "${log_file}" || fail "substep preflight evidence missing: ${log_file}"
}

run_positive() {
  local run_name="$1"
  local build_name="$2"
  local ranks="$3"
  local scenario="$4"
  local package_input="$5"
  local bom_input="$6"
  local exf_input="$7"
  local expected_text="$8"
  local run_dir="${RUN_ROOT}/${run_name}"
  local combined_log="${run_dir}/combined.log"
  local rank
  local rank_log

  log "run ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${scenario}" \
    "${package_input}" "${bom_input}" "${exf_input}"
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
    || fail "setup PASS marker count is not one: ${run_name}"
  record_pass "${run_name}" "${expected_text}"
}

run_negative() {
  local run_name="$1"
  local build_name="$2"
  local scenario="$3"
  local package_input="$4"
  local bom_input="$5"
  local exf_input="$6"
  local expected_text="$7"
  local run_dir="${RUN_ROOT}/${run_name}"
  local process_status

  log "run expected failure ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${scenario}" \
    "${package_input}" "${bom_input}" "${exf_input}"
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
  record_pass "${run_name}" \
    "rejected before publication; status=${process_status}"
}

log 'audit production/test separation and setup contract'
for symbol in bomNPartExpected bomGridWindEast bomGridWindNorth \
              bomWindFieldTime bomWindFieldIter; do
  grep -q "${symbol}" "${REPO_ROOT}/pkg/bom/BOM.h" \
    || fail "missing BOM declaration: ${symbol}"
done
grep -q 'subRatio.GT.DFLOAT(HUGE(nSub))' \
  "${REPO_ROOT}/pkg/bom/bom_check.F" \
  || fail 'integer-range guard missing before CEILING'
grep -q 'deltaTClock/DFLOAT(HUGE(nSub))' \
  "${REPO_ROOT}/pkg/bom/bom_check.F" \
  || fail 'pre-division integer-range guard missing'
grep -q 'IEEE_IS_FINITE(bomDeltaTTarget)' \
  "${REPO_ROOT}/pkg/bom/bom_check.F" \
  || fail 'trap-safe finite-value preflight missing'
grep -q 'bomNPartExpected = nInput' \
  "${REPO_ROOT}/pkg/bom/bom_read_initial.F" \
  || fail 'successful expected-count publication missing'
if rg -n 'P1-SETUP|BOM_VERIFY_SETUP' "${REPO_ROOT}/pkg/bom"; then
  fail 'verification marker leaked into production BOM'
fi
record_pass source-contract \
  'numeric guard, expected budget, and wind snapshot interfaces'

build_case noexf-serial packages.noexf.conf SIZE.h.serial no no
build_case exf-serial packages.exf.conf SIZE.h.serial no yes
build_case exf-mpi4 packages.exf.conf SIZE.h.mpi4 yes yes

run_positive none-serial noexf-serial 1 P13-SETUP-NONE \
  data.pkg.none data.bom.none none \
  'P1-SETUP PASS: NONE zero wind snapshot'
run_positive exf-serial exf-serial 1 P13-SETUP-EXF \
  data.pkg.exf data.bom.exf data.exf.true \
  'P1-SETUP PASS: EXF frozen wind snapshot'
run_positive exf-mpi4 exf-mpi4 4 P13-SETUP-EXF \
  data.pkg.exf data.bom.exf data.exf.true \
  'P1-SETUP PASS: EXF frozen wind snapshot'

run_negative time-overflow noexf-serial P13-TIME-OVERFLOW \
  data.pkg.none data.bom.none none 'wind time overflow'
run_negative exf-not-compiled noexf-serial P13-SETUP-NONE \
  data.pkg.none data.bom.exf none 'requires ALLOW_EXF'
run_negative exf-not-enabled exf-serial P13-SETUP-NONE \
  data.pkg.none data.bom.exf none 'requires useEXF=.TRUE.'
run_negative atm-wind-disabled exf-serial P13-SETUP-NONE \
  data.pkg.exf data.bom.exf data.exf.false \
  'requires useAtmWind=.TRUE.'
run_negative none-nonzero-coeff noexf-serial P13-SETUP-NONE \
  data.pkg.none data.bom.none-coeff none 'wind source=NONE coeff='
run_negative illegal-source noexf-serial P13-SETUP-NONE \
  data.pkg.none data.bom.illegal-source none \
  'unsupported bomWindSource='
run_negative nan-target noexf-serial P13-SETUP-NONE \
  data.pkg.none data.bom.nan-target none \
  'non-finite bomDeltaTTarget='
run_negative nan-coeff noexf-serial P13-SETUP-NONE \
  data.pkg.none data.bom.nan-coeff none \
  'non-finite bomLeewayWindCoeff='
run_negative nan-cfl noexf-serial P13-SETUP-NONE \
  data.pkg.none data.bom.nan-cfl none 'non-finite bomAdvCFL='
run_negative subratio-range noexf-serial P13-SETUP-NONE \
  data.pkg.none data.bom.range-ratio none \
  'subRatio exceeds INTEGER range'

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${ARTIFACT_ROOT}/source-head.txt"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv source-head.txt > manifest.sha256
)

log 'P1.3 SETUP GATE PASS'
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
