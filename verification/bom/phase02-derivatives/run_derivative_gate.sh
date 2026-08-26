#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p22-derivative-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase02-derivatives}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase02-derivatives}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p22-derivatives}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"

fail() {
  printf 'P2.2 DERIVATIVE GATE FAIL: %s\n' "$*" >&2
  exit 1
}
log() {
  printf '[P2.2-derivative] %s\n' "$*"
}
for required in bash make nm grep cmp sort sed mpirun sha256sum shellcheck; do
  command -v "${required}" >/dev/null 2>&1 || fail "missing ${required}"
done
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
  local size="$2"
  local mpi="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_cartesian_derivatives.F" "${mods_dir}/"
  args=(
    "${REPO_ROOT}/tools/genmake2"
    "-rootdir=${REPO_ROOT}"
    "-mods=${mods_dir}"
    "-of=${OPTFILE}"
    -ieee
    -devel
  )
  [[ "${mpi}" == yes ]] && args+=( -mpi )
  (
    cd "${build_dir}"
    "${args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable ${name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_build_derivatives_ bom_try_build_derivatives_       bom_interp_env_derivatives_ bom_derivative_x_pair_       bom_derivative_y_pair_ bom_exch_grad_slice_       bom_deriv_coeff_central_ bom_deriv_coeff_forward_       bom_deriv_coeff_backward_ bom_deriv_apply3_       bom_verify_cartesian_derivatives_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt"       || fail "missing symbol ${symbol} in ${name}"
  done
  record_pass "build-${name}" 'debug compile and derivative symbols'
}

prepare_run() {
  local name="$1"
  local build="$2"
  local run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/"
  cp "${CASE_DIR}/input/data.bom" "${run_dir}/"
  ln -s "${BUILD_ROOT}/${build}/mitgcmuv" "${run_dir}/mitgcmuv"
}

assert_log() {
  local log_file="$1"
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}"     || fail "normal-end marker missing: ${log_file}"
  grep -q 'P2-D01 PASS:' "${log_file}" || fail "P2-D01 marker missing"
  grep -q 'P2-D02 PASS:' "${log_file}" || fail "P2-D02 marker missing"
  grep -q 'P2-N05 PASS:' "${log_file}" || fail "P2-N05 marker missing"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

run_serial() {
  local run_dir="${RUN_ROOT}/serial"
  prepare_run serial serial
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  assert_log "${run_dir}/run.log"
  grep 'P22-GRAD-RECORD' "${run_dir}/run.log"     | sed 's/^.*P22-GRAD-RECORD/P22-GRAD-RECORD/'     | sort > "${RUN_ROOT}/serial.records"
  record_pass p2-d01-serial 'nonuniform constant/affine and exact secant'
  record_pass p2-d02-serial 'centered/one-sided observed order in [1.8,2.2]'
  record_pass p2-n05-serial 'stencil invalidity and metric rollback'
}

run_mpi4() {
  local run_dir="${RUN_ROOT}/mpi4"
  prepare_run mpi4 mpi4
  (
    cd "${run_dir}"
    mpirun -np 4 ./mitgcmuv > mpi-launch.log 2>&1
    : > combined.log
    for rank in 0 1 2 3; do
      cat "STDOUT.$(printf '%04d' "${rank}")" >> combined.log
      cat "STDERR.$(printf '%04d' "${rank}")" >> combined.log
    done
  )
  assert_log "${run_dir}/combined.log"
  grep 'P22-GRAD-RECORD' "${run_dir}"/STDOUT.*     | sed 's/^.*P22-GRAD-RECORD/P22-GRAD-RECORD/'     | sort > "${RUN_ROOT}/mpi4.records"
  record_pass p2-d01-mpi4 'nonuniform constant/affine and exact secant'
  record_pass p2-d02-mpi4 'centered/one-sided observed order in [1.8,2.2]'
  record_pass p2-n05-mpi4 'collective metric failure and rollback'
}

log 'build serial'
build_case serial SIZE.h.serial no
log 'build mpi4'
build_case mpi4 SIZE.h.mpi4 yes
log 'run serial'
run_serial
log 'run mpi4'
run_mpi4

[[ "$(wc -l < "${RUN_ROOT}/serial.records")" -eq 8 ]]   || fail 'serial record count is not 8'
[[ "$(wc -l < "${RUN_ROOT}/mpi4.records")" -eq 8 ]]   || fail 'MPI record count is not 8'
cmp -s "${RUN_ROOT}/serial.records" "${RUN_ROOT}/mpi4.records"   || fail 'serial/MPI gradient records differ'
record_pass p2-d03 '8 sorted C-point records are bitwise decomposition-equal'

if grep -v $'PASS\t' "${RUN_ROOT}/summary.tsv" | tail -n +2 | grep -q .; then
  fail 'summary contains a non-PASS row'
fi
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
cp "${RUN_ROOT}/serial.records" "${ARTIFACT_ROOT}/serial.records"
cp "${RUN_ROOT}/mpi4.records" "${ARTIFACT_ROOT}/mpi4.records"
cp "${BUILD_ROOT}/serial/build.log" "${ARTIFACT_ROOT}/serial-build.log"
cp "${BUILD_ROOT}/mpi4/build.log" "${ARTIFACT_ROOT}/mpi4-build.log"
cp "${RUN_ROOT}/serial/run.log" "${ARTIFACT_ROOT}/serial-run.log"
cp "${RUN_ROOT}/mpi4/combined.log" "${ARTIFACT_ROOT}/mpi4-run.log"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv serial.records mpi4.records     serial-build.log mpi4-build.log serial-run.log mpi4-run.log     > SHA256SUMS
)
log 'P2.2 DERIVATIVE GATE PASS'
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
