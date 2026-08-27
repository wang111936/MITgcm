#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p24-stage-rk-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase02-stage-rk}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase02-stage-rk}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p24-stage-rk}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly P22_CODE="${REPO_ROOT}/verification/bom/phase02-derivatives/code"

fail() { printf 'P2.4 STAGE/RK GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P2.4-stage-rk] %s\n' "$*"; }
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
  for source in bom_rhs_slow_manifold.F bom_rk2_slow_migrate.F bom_rk4_slow_migrate.F; do
    [[ -f "${REPO_ROOT}/pkg/bom/${source}" ]] || fail "missing ${source}"
  done
  grep -Fq 'CALL BOM_RK2_SLOW_MIGRATE' "${REPO_ROOT}/pkg/bom/bom_main.F" || fail 'BOM_MAIN missing RK2 slow path'
  grep -Fq 'CALL BOM_RK4_SLOW_MIGRATE' "${REPO_ROOT}/pkg/bom/bom_main.F" || fail 'BOM_MAIN missing RK4 slow path'
  grep -Fq 'bomRhsDiag(iDiag,ip,bi,bj)' "${REPO_ROOT}/pkg/bom/bom_main.F" || fail 'BOM_MAIN missing final diagnostic commit'
  grep -Fq 'CALL BOM_RHS_COMPONENTS' "${REPO_ROOT}/pkg/bom/bom_rhs_slow_manifold.F" || fail 'stage wrapper does not dispatch frozen components'
  if grep -Eqi 'bom(X|Y|Age|Status|Id|RhsDiag)[[:space:]]*\(' "${REPO_ROOT}/pkg/bom/bom_rhs_slow_manifold.F" "${REPO_ROOT}/pkg/bom/bom_rk2_slow_migrate.F" "${REPO_ROOT}/pkg/bom/bom_rk4_slow_migrate.F"; then
    fail 'stateless stage/RK source references authoritative particle arrays'
  fi
  record_pass p2-i-static 'stage-time wrapper, RK dispatch and one-point commit boundary'
}

build_case() {
  local name="$1" size="$2" mpi="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${P22_CODE}/${size}" "${mods_dir}/SIZE.h"
  cp "${P22_CODE}/packages.conf" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_stage_rk.F" "${mods_dir}/"
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
  for symbol in bom_rhs_slow_manifold_ bom_rk2_slow_migrate_ bom_rk4_slow_migrate_ bom_verify_stage_rk_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" || fail "missing ${symbol} in ${name}"
  done
  record_pass "build-${name}" 'debug compile and P2.4 production symbols'
}

prepare_run() {
  local name="$1" build="$2"
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
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" || fail "normal end missing: ${log_file}"
  for marker in P2-I01 P2-I02 P2-I03 P2-I04; do
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
  for id in i01 i02 i03 i04; do
    record_pass "p2-${id}-serial" 'production stage/RK analytic assertion'
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
  for id in i01 i02 i03 i04; do
    record_pass "p2-${id}-mpi4" 'production stage/RK analytic assertion'
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
if tail -n +2 "${RUN_ROOT}/summary.tsv" | grep -v $'PASS\t' | grep -q .; then
  fail 'summary contains a non-PASS row'
fi
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/"
cp "${BUILD_ROOT}/serial/build.log" "${ARTIFACT_ROOT}/serial-build.log"
cp "${BUILD_ROOT}/mpi4/build.log" "${ARTIFACT_ROOT}/mpi4-build.log"
cp "${RUN_ROOT}/serial/run.log" "${ARTIFACT_ROOT}/serial-run.log"
cp "${RUN_ROOT}/mpi4/combined.log" "${ARTIFACT_ROOT}/mpi4-run.log"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv serial-build.log mpi4-build.log serial-run.log mpi4-run.log > SHA256SUMS
)
log 'P2.4 STAGE/RK GATE PASS'
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
