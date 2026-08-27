#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p21-endpoint-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase02-endpoint-state}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase02-endpoint-state}"
readonly ARTIFACT_PARENT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly ARTIFACT_ROOT="${ARTIFACT_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"

fail() {
  printf 'P2.1 ENDPOINT STATE GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P2.1-endpoint] %s\n' "$*"
}

for required in bash make nm grep shellcheck mpirun sha256sum python3; do
  command -v "${required}" >/dev/null 2>&1 \
    || fail "required command not found: ${required}"
done
[[ -x "${REPO_ROOT}/tools/genmake2" ]] || fail 'genmake2 not executable'
[[ -f "${OPTFILE}" ]] || fail "optfile not found: ${OPTFILE}"
for root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${root}" ]] || fail "evidence root already exists: ${root}"
done

mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

build_case() {
  local name="$1"
  local size_file="$2"
  local mpi_enabled="$3"
  local test_driver="$4"
  local packages_file="${5:-packages.conf}"
  local bom_options="${6:-}"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  local -a symbols

  log "build ${name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/${packages_file}" "${mods_dir}/packages.conf"
  if [[ -n "${bom_options}" ]]; then
    cp "${CASE_DIR}/code/${bom_options}" "${mods_dir}/BOM_OPTIONS.h"
  fi
  if [[ "${test_driver}" == yes ]]; then
    cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
    cp "${CASE_DIR}/code/bom_verify_endpoint_transaction.F" \
      "${mods_dir}/"
    cp "${CASE_DIR}/code/bom_verify_exf_endpoints.F" \
      "${mods_dir}/"
    cp "${CASE_DIR}/code/bom_verify_stokes_files.F" \
      "${mods_dir}/"
    cp "${CASE_DIR}/code/bom_verify_coupler_stokes.F" \
      "${mods_dir}/"
    cp "${CASE_DIR}/code/bom_verify_env_time.F" \
      "${mods_dir}/"
  fi
  args=(
    "${REPO_ROOT}/tools/genmake2"
    "-rootdir=${REPO_ROOT}"
    "-mods=${mods_dir}"
    "-of=${OPTFILE}"
    -ieee
    -devel
  )
  if [[ "${mpi_enabled}" == yes ]]; then
    args+=( -mpi )
  fi
  (
    cd "${build_dir}"
    "${args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable: ${name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  symbols=(bom_check_ bom_init_state_ bom_build_endpoints_ \
           bom_try_build_endpoints_ bom_get_exf_wind_ bom_get_stokes_ \
           bom_interp_env_time_ \
           bom_clear_coupler_stokes_ bom_set_coupler_stokes_ \
           bom_get_coupler_stokes_)
  if [[ "${test_driver}" == yes ]]; then
    symbols+=(bom_verify_endpoint_state_ \
              bom_verify_endpoint_transaction_ \
              bom_verify_stokes_files_ bom_verify_env_time_)
  fi
  if [[ "${packages_file}" == packages.exf.conf ]]; then
    symbols+=(exf_init_varia_)
    if [[ "${test_driver}" == yes ]]; then
      symbols+=(bom_verify_exf_endpoints_)
    fi
  fi
  for symbol in "${symbols[@]}"; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${name}"
  done
  record_pass "build-${name}" 'debug compile and transaction symbols'
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local bom_input="$3"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/${bom_input}" "${run_dir}/data.bom"
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" "${run_dir}/mitgcmuv"
}

prepare_env_time_run() {
  local run_name="$1"
  local build_name="$2"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  sed -i 's/P21-ENDPOINT-STATE/P21-ENV-TIME/' \
    "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/data.bom.valid" "${run_dir}/data.bom"
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" \
    "${run_dir}/mitgcmuv"
}

prepare_exf_run() {
  local run_name="$1"
  local build_name="$2"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  sed -i 's/P21-ENDPOINT-STATE/P21-EXF-ENDPOINTS/' \
    "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/data.pkg.exf" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/data.bom.exf" "${run_dir}/data.bom"
  cp "${CASE_DIR}/input/data.exf" "${run_dir}/data.exf"
  python3 "${CASE_DIR}/input/generate_exf_fixture.py" \
    --output-dir "${run_dir}"
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" \
    "${run_dir}/mitgcmuv"
}

prepare_stokes_run() {
  local run_name="$1"
  local build_name="$2"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  sed -i 's/P21-ENDPOINT-STATE/P21-STOKES-FILES/' \
    "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/data.bom.stokes-files" \
    "${run_dir}/data.bom"
  python3 "${CASE_DIR}/input/generate_stokes_fixture.py" \
    --output-dir "${run_dir}"
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" \
    "${run_dir}/mitgcmuv"
}

prepare_coupler_run() {
  local run_name="$1"
  local build_name="$2"
  local bom_input="$3"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  sed -i 's/P21-ENDPOINT-STATE/P21-COUPLER-STOKES/' \
    "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/${bom_input}" "${run_dir}/data.bom"
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" \
    "${run_dir}/mitgcmuv"
}

assert_normal_log() {
  local log_file="$1"
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" \
    || fail "normal-end marker missing: ${log_file}"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

run_positive() {
  local name="$1"
  local build_name="$2"
  local ranks="$3"
  local run_dir="${RUN_ROOT}/${name}"
  local combined="${run_dir}/combined.log"
  local rank
  local rank_log

  log "run ${name}"
  prepare_run "${name}" "${build_name}" data.bom.valid
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    assert_normal_log "${run_dir}/run.log"
    cp "${run_dir}/run.log" "${combined}"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    : > "${combined}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_normal_log "${rank_log}"
      cat "${rank_log}" >> "${combined}"
    done
  fi
  [[ "$(grep -c 'P2.1 ENDPOINT STATE PASS' "${combined}")" -eq 1 ]] \
    || fail "positive marker count is not one: ${name}"
  [[ "$(grep -c 'P2.1 ENDPOINT TRANSACTION PASS' "${combined}")" -eq 1 ]] \
    || fail "transaction marker count is not one: ${name}"
  record_pass "${name}" \
    'fresh/normal ocean-NONE-NONE and rollback transaction'
}

run_env_time_positive() {
  local name="$1"
  local build_name="$2"
  local ranks="$3"
  local run_dir="${RUN_ROOT}/${name}"
  local combined="${run_dir}/combined.log"
  local rank
  local rank_log

  log "run ${name}"
  prepare_env_time_run "${name}" "${build_name}"
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    assert_normal_log "${run_dir}/run.log"
    cp "${run_dir}/run.log" "${combined}"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    : > "${combined}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_normal_log "${rank_log}"
      cat "${rank_log}" >> "${combined}"
    done
  fi
  [[ "$(grep -c 'P2.1 ENV TIME PASS' "${combined}")" -eq 1 ]] \
    || fail "environment time marker count is not one: ${name}"
  record_pass "${name}" \
    'P2-E06 snap/linear/secant and P2-N02 no extrapolation'
}

run_exf_positive() {
  local name="$1"
  local build_name="$2"
  local ranks="$3"
  local run_dir="${RUN_ROOT}/${name}"
  local combined="${run_dir}/combined.log"
  local rank
  local rank_log

  log "run ${name}"
  prepare_exf_run "${name}" "${build_name}"
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    assert_normal_log "${run_dir}/run.log"
    cp "${run_dir}/run.log" "${combined}"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    : > "${combined}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_normal_log "${rank_log}"
      cat "${rank_log}" >> "${combined}"
    done
  fi
  [[ "$(grep -c 'P2.1 EXF ENDPOINT PASS' "${combined}")" -eq 1 ]] \
    || fail "EXF endpoint marker count is not one: ${name}"
  record_pass "${name}" \
    'P2-E03 exact EXF values and P2-N03 transactional rollback'
}

run_stokes_positive() {
  local name="$1"
  local build_name="$2"
  local ranks="$3"
  local run_dir="${RUN_ROOT}/${name}"
  local combined="${run_dir}/combined.log"
  local rank
  local rank_log

  log "run ${name}"
  prepare_stokes_run "${name}" "${build_name}"
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    assert_normal_log "${run_dir}/run.log"
    cp "${run_dir}/run.log" "${combined}"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    : > "${combined}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_normal_log "${rank_log}"
      cat "${rank_log}" >> "${combined}"
    done
  fi
  [[ "$(grep -c 'P2.1 STOKES FILES PASS' "${combined}")" -eq 1 ]] \
    || fail "Stokes FILES marker count is not one: ${name}"
  record_pass "${name}" \
    'P2-E04 exact/repeat FILES Stokes and P2-N03 rollback'
}

run_coupler_positive() {
  local name="$1"
  local build_name="$2"
  local ranks="$3"
  local bom_input="$4"
  local run_dir="${RUN_ROOT}/${name}"
  local combined="${run_dir}/combined.log"
  local rank
  local rank_log

  log "run ${name}"
  prepare_coupler_run "${name}" "${build_name}" "${bom_input}"
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    assert_normal_log "${run_dir}/run.log"
    cp "${run_dir}/run.log" "${combined}"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    : > "${combined}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_normal_log "${rank_log}"
      cat "${rank_log}" >> "${combined}"
    done
  fi
  [[ "$(grep -c 'P2.1 COUPLER STOKES PASS' "${combined}")" -eq 1 ]] \
    || fail "COUPLER Stokes marker count is not one: ${name}"
  record_pass "${name}" \
    'P2-E05 copied exact labels and P2-N03 transactional rollback'
}

run_production_smoke() {
  local run_dir="${RUN_ROOT}/production-one-step"

  log 'run production-one-step'
  prepare_run production-one-step production-serial data.bom.valid
  sed -i 's/endTime=0\./endTime=1200./' "${run_dir}/data"
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  assert_normal_log "${run_dir}/run.log"
  if grep -q 'P2.1 ENDPOINT TRANSACTION PASS' "${run_dir}/run.log"; then
    fail 'test-only transaction driver leaked into production build'
  fi
  record_pass production-one-step \
    'production fresh hook and one normal zero-particle step'
}

run_exf_production_smoke() {
  local run_dir="${RUN_ROOT}/production-exf-one-step"

  log 'run production-exf-one-step'
  prepare_exf_run production-exf-one-step production-exf-serial
  sed -i 's/endTime=0\./endTime=1200./' "${run_dir}/data"
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  assert_normal_log "${run_dir}/run.log"
  if grep -q 'P2.1 EXF ENDPOINT PASS' "${run_dir}/run.log"; then
    fail 'test-only EXF endpoint driver leaked into production build'
  fi
  record_pass production-exf-one-step \
    'production exact-time EXF fresh hook and one normal step'
}

run_stokes_production_smoke() {
  local run_dir="${RUN_ROOT}/production-stokes-one-step"

  log 'run production-stokes-one-step'
  prepare_stokes_run production-stokes-one-step production-serial
  sed -i 's/endTime=0\./endTime=1200./' "${run_dir}/data"
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  assert_normal_log "${run_dir}/run.log"
  if grep -q 'P2.1 STOKES FILES PASS' "${run_dir}/run.log"; then
    fail 'test-only Stokes FILES driver leaked into production build'
  fi
  record_pass production-stokes-one-step \
    'production BOM-owned FILES fresh hook and one normal step'
}

run_precombined_none_smoke() {
  local run_dir="${RUN_ROOT}/production-precombined-none"

  log 'run production-precombined-none'
  prepare_run production-precombined-none production-serial \
    data.bom.precombined-none
  sed -i 's/endTime=0\./endTime=1200./' "${run_dir}/data"
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  assert_normal_log "${run_dir}/run.log"
  record_pass production-precombined-none \
    'P2-E05 legal PRECOMBINED plus NONE source row'
}

run_leew_compat() {
  local run_dir="${RUN_ROOT}/leew-compat"

  log 'run leew-compat'
  prepare_run leew-compat serial data.bom.leew
  sed -i 's/P21-ENDPOINT-STATE/P21-LEEW-COMPAT/' \
    "${run_dir}/data"
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  assert_normal_log "${run_dir}/run.log"
  grep -q "'UNSET'" "${run_dir}/run.log" \
    || fail 'LEEW compatibility run did not retain UNSET default'
  if grep -q 'BOM requires explicit current policy' \
      "${run_dir}/run.log"; then
    fail 'BOM-only current-policy check leaked into LEEW'
  fi
  record_pass leew-compat 'Phase-1 defaults and normal end preserved'
}

run_negative() {
  local name="$1"
  local bom_input="$2"
  local expected="$3"
  local run_dir="${RUN_ROOT}/${name}"
  local status

  log "run expected failure ${name}"
  prepare_run "${name}" serial "${bom_input}"
  set +e
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  status=$?
  set -e
  if grep -q 'PROGRAM MAIN: Execution ended Normally' "${run_dir}/run.log"; then
    fail "negative case ended normally: ${name}"
  fi
  grep -q "${expected}" "${run_dir}/run.log" \
    || fail "expected rejection missing: ${name}"
  grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE' "${run_dir}/run.log" \
    || fail "fatal marker missing: ${name}"
  record_pass "${name}" "rejected before init; status=${status}"
}

log 'audit frozen names and production/test separation'
for name in bomCurrentPolicy bomTauDays bomEnvEast bomEnvNorth \
            bomEnvTime bomEnvIter bomEnvValid bomEnvReady \
            bomEnvEastScratch bomEnvTimeScratch; do
  grep -R -q "${name}" "${REPO_ROOT}/pkg/bom" \
    || fail "missing production interface: ${name}"
done
if grep -R -n 'P2.1 ENDPOINT STATE PASS\|BOM_VERIFY_ENDPOINT' \
    "${REPO_ROOT}/pkg/bom"; then
  fail 'verification marker leaked into production source'
fi
for source_file in bom_init_varia.F bom_main.F; do
  grep -q 'CALL BOM_BUILD_ENDPOINTS' \
    "${REPO_ROOT}/pkg/bom/${source_file}" \
    || fail "production lifecycle hook missing: ${source_file}"
done
grep -q 'CALL BOM_GET_EXF_WIND' \
  "${REPO_ROOT}/pkg/bom/bom_build_endpoints.F" \
  || fail 'production EXF endpoint provider hook missing'
grep -q 'CALL BOM_GET_STOKES' \
  "${REPO_ROOT}/pkg/bom/bom_build_endpoints.F" \
  || fail 'production FILES Stokes provider hook missing'
grep -q 'CALL BOM_GET_COUPLER_STOKES' \
  "${REPO_ROOT}/pkg/bom/bom_get_stokes.F" \
  || fail 'production COUPLER Stokes provider hook missing'
grep -q 'SUBROUTINE BOM_INTERP_ENV_TIME' \
  "${REPO_ROOT}/pkg/bom/bom_interp_env_time.F" \
  || fail 'production environmental time interpolator missing'
record_pass source-contract 'frozen names; test code remains isolated'

build_case serial SIZE.h.serial no yes
build_case mpi4 SIZE.h.mpi4 yes yes
build_case production-serial SIZE.h.serial no no
build_case exf-serial SIZE.h.serial no yes packages.exf.conf
build_case exf-mpi4 SIZE.h.mpi4 yes yes packages.exf.conf
build_case production-exf-serial SIZE.h.serial no no packages.exf.conf
build_case coupler-serial SIZE.h.serial no yes packages.conf \
  BOM_OPTIONS.h.coupler
build_case coupler-mpi4 SIZE.h.mpi4 yes yes packages.conf \
  BOM_OPTIONS.h.coupler
build_case production-coupler-serial SIZE.h.serial no no packages.conf \
  BOM_OPTIONS.h.coupler
run_positive bom-serial serial 1
run_positive bom-mpi4 mpi4 4
run_env_time_positive bom-env-time-serial serial 1
run_env_time_positive bom-env-time-mpi4 mpi4 4
run_stokes_positive bom-stokes-serial serial 1
run_stokes_positive bom-stokes-mpi4 mpi4 4
run_coupler_positive bom-coupler-serial coupler-serial 1 data.bom.coupler
run_coupler_positive bom-coupler-mpi4 coupler-mpi4 4 data.bom.coupler
run_coupler_positive bom-coupler-sigma-zero coupler-serial 1 \
  data.bom.coupler-zero
run_exf_positive bom-exf-serial exf-serial 1
run_exf_positive bom-exf-mpi4 exf-mpi4 4
run_production_smoke
run_stokes_production_smoke
run_exf_production_smoke
run_precombined_none_smoke
run_leew_compat
run_negative current-unset data.bom.unset \
  'BOM requires explicit current policy'
run_negative nan-alpha data.bom.nan-alpha 'non-finite bomAlpha='
run_negative tau-overflow data.bom.tau-overflow \
  'bomTauDays overflows seconds='
run_negative none-sigma data.bom.none-sigma \
  'Stokes source=NONE requires sigma=0:'
run_negative duplicate-files data.bom.duplicate-files \
  'precombined current duplicates FILES Stokes'
run_negative bad-files data.bom.bad-files \
  'bomStokesFilePrec must be 32 or 64:'
run_negative coupler-unavailable data.bom.coupler \
  'COUPLER provider hook is not compiled'
run_negative duplicate-coupler data.bom.duplicate-coupler \
  'precombined current duplicates COUPLER Stokes'

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${ARTIFACT_ROOT}/source-head.txt"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv source-head.txt > manifest.sha256
)

log 'P2.1 ENDPOINT STATE GATE PASS'
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
