#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p23-rhs-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase02-rhs-components}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase02-rhs-components}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p23-rhs-components}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly P22_CASE="${REPO_ROOT}/verification/bom/phase02-derivatives"

fail() { printf 'P2.3 RHS COMPONENT GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P2.3-rhs] %s\n' "$*"; }
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
record_pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

static_audit() {
  local source
  for source in bom_rhs_components.F bom_rhs_paper2024.F bom_rhs_julia.F; do
    [[ -f "${REPO_ROOT}/pkg/bom/${source}" ]] || fail "missing ${source}"
  done
  grep -Fq 'SUBROUTINE BOM_RHS_PAPER2024' "${REPO_ROOT}/pkg/bom/bom_rhs_paper2024.F" || fail 'missing PAPER2024 kernel'
  grep -Fq 'SUBROUTINE BOM_RHS_JULIA' "${REPO_ROOT}/pkg/bom/bom_rhs_julia.F" || fail 'missing JULIA kernel'
  grep -Fq "bomEquationMode  = 'PAPER2024'" "${REPO_ROOT}/pkg/bom/bom_readparms.F" || fail 'PAPER2024 is not default'
  if grep -Eqi 'bom(X|Y|Age|Status|Id|DriftEast|DriftNorth)[[:space:]]*\(' "${REPO_ROOT}/pkg/bom/bom_rhs_components.F" "${REPO_ROOT}/pkg/bom/bom_rhs_paper2024.F" "${REPO_ROOT}/pkg/bom/bom_rhs_julia.F"; then
    fail 'stateless RHS source references authoritative particle arrays'
  fi
  if grep -Fq 'BOM_RHS_COMPONENTS' "${REPO_ROOT}"/pkg/bom/bom_rk*.F "${REPO_ROOT}/pkg/bom/bom_main.F"; then
    fail 'P2.3 must not wire particle RK stages'
  fi
  record_pass p2-h-static 'separate named modes, default and stateless/P2.4 boundary'
}

build_case() {
  local name="$1" size="$2" mpi="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${P22_CASE}/code/${size}" "${mods_dir}/SIZE.h"
  cp "${P22_CASE}/code/packages.conf" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_rhs_components.F" "${mods_dir}/"
  args=("${REPO_ROOT}/tools/genmake2" "-rootdir=${REPO_ROOT}" "-mods=${mods_dir}" "-of=${OPTFILE}" -ieee -devel)
  [[ "${mpi}" == yes ]] && args+=( -mpi )
  (
    cd "${build_dir}"
    "${args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable ${name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_rhs_components_ bom_rhs_paper2024_ bom_rhs_julia_ bom_rhs_finalize_ bom_rhs_cfl_guard_ bom_verify_rhs_components_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" || fail "missing ${symbol} in ${name}"
  done
  record_pass "build-${name}" 'debug compile and all P2.3 RHS symbols'
}

prepare_run() {
  local name="$1" build="$2"
  local run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${P22_CASE}/input/data" "${run_dir}/data"
  cp "${P22_CASE}/input/eedata" "${run_dir}/"
  cp "${P22_CASE}/input/data.pkg" "${run_dir}/"
  cp "${P22_CASE}/input/data.bom" "${run_dir}/"
  ln -s "${BUILD_ROOT}/${build}/mitgcmuv" "${run_dir}/mitgcmuv"
}

assert_log() {
  local log_file="$1"
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" || fail "normal end missing: ${log_file}"
  for marker in P2-H01 P2-H02 P2-H03 P2-H04 P2-H05 P2-H06 P2-N06; do
    grep -q "${marker} PASS:" "${log_file}" || fail "${marker} marker missing"
  done
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

run_serial() {
  local run_dir="${RUN_ROOT}/serial"
  prepare_run serial serial
  (cd "${run_dir}"; ./mitgcmuv > run.log 2>&1)
  assert_log "${run_dir}/run.log"
  grep 'P23-RHS-RECORD' "${run_dir}/run.log" | sed 's/^.*P23-RHS-RECORD/P23-RHS-RECORD/' | sort > "${RUN_ROOT}/serial.records"
  for id in h01 h02 h03 h04 h05 h06 n06; do
    record_pass "p2-${id}-serial" 'analytic/stateless component assertion'
  done
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
  grep 'P23-RHS-RECORD' "${run_dir}"/STDOUT.* | sed 's/^.*P23-RHS-RECORD/P23-RHS-RECORD/' | sort > "${RUN_ROOT}/mpi4.records"
  for id in h01 h02 h03 h04 h05 h06 n06; do
    record_pass "p2-${id}-mpi4" 'analytic/stateless component assertion'
  done
}

static_audit
log 'build serial'
build_case serial SIZE.h.serial no
log 'build MPI4'
build_case mpi4 SIZE.h.mpi4 yes
log 'run serial'
run_serial
log 'run MPI4'
run_mpi4
[[ "$(wc -l < "${RUN_ROOT}/serial.records")" -eq 8 ]] || fail 'serial record count is not 8'
[[ "$(wc -l < "${RUN_ROOT}/mpi4.records")" -eq 8 ]] || fail 'MPI record count is not 8'
cmp -s "${RUN_ROOT}/serial.records" "${RUN_ROOT}/mpi4.records" || fail 'serial/MPI RHS records differ'
record_pass p2-h-decomposition '8 sorted RHS records are bitwise decomposition-equal'
if grep -v $'PASS\t' "${RUN_ROOT}/summary.tsv" | tail -n +2 | grep -q .; then
  fail 'summary contains a non-PASS row'
fi
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/"
cp "${RUN_ROOT}/serial.records" "${ARTIFACT_ROOT}/"
cp "${RUN_ROOT}/mpi4.records" "${ARTIFACT_ROOT}/"
cp "${BUILD_ROOT}/serial/build.log" "${ARTIFACT_ROOT}/serial-build.log"
cp "${BUILD_ROOT}/mpi4/build.log" "${ARTIFACT_ROOT}/mpi4-build.log"
cp "${RUN_ROOT}/serial/run.log" "${ARTIFACT_ROOT}/serial-run.log"
cp "${RUN_ROOT}/mpi4/combined.log" "${ARTIFACT_ROOT}/mpi4-run.log"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv serial.records mpi4.records serial-build.log mpi4-build.log serial-run.log mpi4-run.log > SHA256SUMS
)
log 'P2.3 RHS COMPONENT GATE PASS'
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
