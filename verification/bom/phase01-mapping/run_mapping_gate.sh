#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p12-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase01-mapping}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase01-mapping}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"

fail() {
  printf 'P1.2 MAPPING GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.2-map] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

for required_command in bash make nm grep rg sed shellcheck; do
  require_command "${required_command}"
done

[[ -x "${REPO_ROOT}/tools/genmake2" ]] || fail "genmake2 is not executable"
[[ -f "${OPTFILE}" ]] || fail "optfile not found: ${OPTFILE}"
[[ ! -e "${BUILD_ROOT}" ]] || fail "build root already exists: ${BUILD_ROOT}"
[[ ! -e "${RUN_ROOT}" ]] || fail "run root already exists: ${RUN_ROOT}"

mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

build_case() {
  local case_name="$1"
  local build_mode="$2"
  local packages_file="$3"
  local build_dir="${BUILD_ROOT}/${case_name}"
  local mods_dir="${BUILD_ROOT}/${case_name}-mods"
  local -a genmake_args

  log "build ${case_name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp -a "${CASE_DIR}/code/." "${mods_dir}/"
  cp "${packages_file}" "${mods_dir}/packages.conf"

  genmake_args=(
    "${REPO_ROOT}/tools/genmake2"
    "-rootdir=${REPO_ROOT}"
    "-mods=${mods_dir}"
    "-of=${OPTFILE}"
    -ieee
    -devel
  )
  if [[ "${build_mode}" == omp ]]; then
    genmake_args+=( -omp )
  fi

  (
    cd "${build_dir}"
    "${genmake_args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable: ${case_name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_init_mapping_ bom_normalize_x_ \
                bom_map_xy2ijlocal_ bom_map_ijlocal2xy_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${case_name}"
  done
  printf '%s\tPASS\tdebug build, link, and mapping symbols\n' \
    "build-${case_name}" >> "${RUN_ROOT}/summary.tsv"
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local data_file="$3"
  local ee_file="$4"
  local scenario_name="$5"
  local with_exch2="$6"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${data_file}" "${run_dir}/data"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/data.bom" "${run_dir}/data.bom"
  cp "${ee_file}" "${run_dir}/eedata"
  if [[ "${scenario_name}" != keep ]]; then
    sed -i \
      "s/the_run_name='P1-M01-CARTESIAN'/the_run_name='${scenario_name}'/" \
      "${run_dir}/data"
  fi
  if [[ "${with_exch2}" == yes ]]; then
    cp "${CASE_DIR}/input/data.exch2" "${run_dir}/data.exch2"
  fi
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" "${run_dir}/mitgcmuv"
}

assert_normal() {
  local log_file="$1"
  local expected_text="$2"

  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" \
    || fail "normal-end marker missing: ${log_file}"
  grep -q "${expected_text}" "${log_file}" \
    || fail "mapping evidence missing: ${expected_text}"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

run_positive() {
  local run_name="$1"
  local data_file="$2"
  local expected_text="$3"
  local run_dir="${RUN_ROOT}/${run_name}"

  log "run ${run_name}"
  prepare_run "${run_name}" regular "${data_file}" \
    "${CASE_DIR}/input/eedata" keep no
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  assert_normal "${run_dir}/run.log" "${expected_text}"
  grep -q 'BOM_INIT_MAPPING: scaled tolerance' "${run_dir}/run.log" \
    || fail "scaled-tolerance evidence missing: ${run_name}"
  printf '%s\tPASS\t%s\n' "${run_name}" "${expected_text}" \
    >> "${RUN_ROOT}/summary.tsv"
}

run_negative() {
  local run_name="$1"
  local build_name="$2"
  local ee_file="$3"
  local scenario_name="$4"
  local expected_text="$5"
  local with_exch2="$6"
  local run_dir="${RUN_ROOT}/${run_name}"
  local process_status

  log "run expected failure ${run_name}"
  prepare_run "${run_name}" "${build_name}" \
    "${CASE_DIR}/input/data.cartesian" "${ee_file}" \
    "${scenario_name}" "${with_exch2}"
  set +e
  (
    cd "${run_dir}"
    if [[ "${build_name}" == omp ]]; then
      env OMP_NUM_THREADS=2 GOMP_STACKSIZE=256m \
        ./mitgcmuv > run.log 2>&1
    else
      ./mitgcmuv > run.log 2>&1
    fi
  )
  process_status=$?
  set -e

  if grep -q 'PROGRAM MAIN: Execution ended Normally' "${run_dir}/run.log"; then
    fail "negative gate ended normally: ${run_name}"
  fi
  grep -q "${expected_text}" "${run_dir}/run.log" \
    || fail "expected rejection text missing: ${run_name}"
  grep -q 'mapping state is unavailable' "${run_dir}/run.log" \
    || fail "unavailable-state marker missing: ${run_name}"
  grep -Eq 'ABNORMAL END|Fortran runtime error|Error termination' \
    "${run_dir}/run.log" \
    || fail "failure marker missing: ${run_name}"
  printf '%s\tPASS\trejected; process status=%s\n' \
    "${run_name}" "${process_status}" >> "${RUN_ROOT}/summary.tsv"
}

log 'audit production/test separation'
grep -q 'CALL BOM_INIT_MAPPING' "${REPO_ROOT}/pkg/bom/bom_init_fixed.F" \
  || fail 'production fixed-init does not call BOM_INIT_MAPPING'
if rg -n 'BOM_VERIFY_|P1-M0[12]' "${REPO_ROOT}/pkg/bom"; then
  fail 'verification hook leaked into production pkg/bom'
fi
printf 'source-separation\tPASS\tverification hook confined to case mods\n' \
  >> "${RUN_ROOT}/summary.tsv"

build_case regular serial "${CASE_DIR}/code/packages.conf"
build_case omp omp "${CASE_DIR}/code/packages.conf"
build_case exch2 serial "${CASE_DIR}/code/packages.exch2.conf"

run_positive m01-cartesian "${CASE_DIR}/input/data.cartesian" \
  'P1-M01 PASS: Cartesian mapping and floor semantics'
run_positive m02-global "${CASE_DIR}/input/data.spherical-global" \
  'P1-M02 GLOBAL PASS: 360-degree normalization'
run_positive m02-regional "${CASE_DIR}/input/data.spherical-regional" \
  'P1-M02 REGIONAL PASS: no longitude wrapping'

run_negative n04-rotate regular "${CASE_DIR}/input/eedata" \
  P1-N04-ROTATE 'rotateGrid unsupported in Phase 1' no
run_negative n04-curvilinear regular "${CASE_DIR}/input/eedata" \
  P1-N04-CURVILINEAR 'curvilinear/cylindrical grid unsupported' no
run_negative n04-pcoords regular "${CASE_DIR}/input/eedata" \
  P1-N04-PCOORDS 'usingPCoords unsupported in Phase 1' no
run_negative n04-nonpositive-spacing regular "${CASE_DIR}/input/eedata" \
  P1-N04-DELX 'invalid delX(' no
run_negative n04-inconsistent-bound regular "${CASE_DIR}/input/eedata" \
  P1-N04-TILE-BOUND 'inconsistent tile west bound' no
run_negative n04-openmp omp "${CASE_DIR}/input/eedata.omp2" \
  P1-N04-THREAD 'Phase-1 mapping is MPI-only' no
run_negative n04-exch2 exch2 "${CASE_DIR}/input/eedata.exch2" \
  P1-N04-EXCH2 'EXCH2 unsupported in Phase 1' yes

log 'P1.2 MAPPING GATE PASS'
log "build root: ${BUILD_ROOT}"
log "run root:   ${RUN_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
