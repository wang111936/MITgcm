#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p13-rhs-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
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
readonly JULIA_BIN="${MITGCM_BOM_JULIA:-/home/wyl/opt/mitgcm-bom/juliaup/bin/julia}"
readonly JULIA_DEPOT="${MITGCM_BOM_JULIA_DEPOT:-/home/wyl/opt/mitgcm-bom/julia-depot}"
readonly JULIA_REFERENCE="${MITGCM_BOM_JULIA_REFERENCE:-/home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl}"
readonly EXPECTED_JULIA_COMMIT="156557359185e4413ce82829f3ed26a4eb8c6283"

fail() {
  printf 'P1.3 RHS GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.3-rhs] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 \
    || fail "required command not found: $1"
}

record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

for required_command in bash make nm grep git rg sed shellcheck mpirun \
                        sha256sum; do
  require_command "${required_command}"
done
[[ -x "${REPO_ROOT}/tools/genmake2" ]] \
  || fail 'genmake2 is not executable'
[[ -f "${OPTFILE}" ]] || fail "optfile not found: ${OPTFILE}"
[[ -x "${JULIA_BIN}" ]] || fail "Julia not found: ${JULIA_BIN}"
[[ -d "${JULIA_REFERENCE}/.git" ]] \
  || fail "Julia reference missing: ${JULIA_REFERENCE}"
for fresh_root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${fresh_root}" ]] \
    || fail "evidence root already exists: ${fresh_root}"
done

mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

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
  cp "${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_rhs.F" "${mods_dir}/"
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
  for symbol in bom_rhs_leeway_ bom_interp_wet_pair_ \
                bom_verify_rhs_; do
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
    'GNU debug/IEEE build and RHS symbols'
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local scenario="$3"
  local grid_input="$4"
  local source_kind="$5"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/${grid_input}" "${run_dir}/data"
  if [[ "${source_kind}" == exf ]]; then
    cp "${CASE_DIR}/input/data.pkg.exf" "${run_dir}/data.pkg"
    cp "${CASE_DIR}/input/data.bom.exf" "${run_dir}/data.bom"
    cp "${CASE_DIR}/input/data.exf" "${run_dir}/data.exf"
  else
    cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
    cp "${CASE_DIR}/input/data.bom" "${run_dir}/data.bom"
  fi
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  sed -i \
    -e "s/the_run_name='P1-I01-ZERO'/the_run_name='${scenario}'/" \
    -e "s/the_run_name='P1-I03-SPHERE'/the_run_name='${scenario}'/" \
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
  local grid_input="$5"
  local source_kind="$6"
  local expected_text="$7"
  local run_dir="${RUN_ROOT}/${run_name}"
  local combined_log="${run_dir}/combined.log"
  local rank
  local rank_log

  log "run ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${scenario}" \
    "${grid_input}" "${source_kind}"
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
    || fail "RHS PASS marker count is not one: ${run_name}"
  record_pass "${run_name}" "${expected_text}"
}

log 'audit production/test separation and frozen RHS contract'
readonly RHS_SOURCE="${REPO_ROOT}/pkg/bom/bom_rhs_leeway.F"
readonly BOM_HEADER="${REPO_ROOT}/pkg/bom/BOM.h"
[[ -f "${RHS_SOURCE}" ]] || fail 'production RHS routine is missing'
for contract_text in \
    'SUBROUTINE BOM_RHS_LEEWAY' \
    'bomLeewayWindCoeff*windEast' \
    'rSphere*deg2rad' \
    'COS(deg2rad*yy)' \
    'recip_dxF(iC,jC,bi,bj)' \
    'stageCFL = dtGuard*MAX(cflX,cflY)'; do
  grep -Fq "${contract_text}" "${RHS_SOURCE}" \
    || fail "missing RHS contract: ${contract_text}"
done
for stable_code in \
    'BOM_FAIL_NONE      = 0' 'BOM_FAIL_MAP       = 1' \
    'BOM_FAIL_OWNER     = 2' 'BOM_FAIL_STENCIL   = 3' \
    'BOM_FAIL_INTERP    = 4' 'BOM_FAIL_NONFINITE = 5' \
    'BOM_FAIL_CFL       = 6' 'BOM_FAIL_STATE     = 7' \
    'BOM_FAIL_RELEASE   = 8' 'BOM_STAGE_FINAL = 5'; do
  grep -Fq "${stable_code}" "${BOM_HEADER}" \
    || fail "missing stable code: ${stable_code}"
done
if rg -n 'bom(X|Y|Age|Status|ReleaseTime|NPartTile)\([^)]*\)[[:space:]]*=' \
    "${RHS_SOURCE}"; then
  fail 'RHS writes authoritative particle state'
fi
if rg -n 'BOM_VERIFY_RHS|P1-I0[1-4]|P1-N08' \
    "${REPO_ROOT}/pkg/bom"; then
  fail 'verification marker leaked into production BOM'
fi
record_pass source-contract \
  'stateless SI Leeway, native-rate conversion, stable fail/stage codes'

log 'audit locked Julia Leeway reference'
[[ "$(git -C "${JULIA_REFERENCE}" rev-parse HEAD)" == \
    "${EXPECTED_JULIA_COMMIT}" ]] \
  || fail 'Julia reference commit changed'
git -C "${JULIA_REFERENCE}" diff --quiet \
  || fail 'Julia reference worktree is dirty'
git -C "${JULIA_REFERENCE}" diff --cached --quiet \
  || fail 'Julia reference index is dirty'
grep -Fq 'WATER_ITP.x.fields[:u](x, y, t) + α * WIND_ITP.x.fields[:u]' \
  "${JULIA_REFERENCE}/src/physics.jl" \
  || fail 'locked Julia east Leeway formula changed'
grep -Fq 'WATER_ITP.x.fields[:v](x, y, t) + α * WIND_ITP.x.fields[:v]' \
  "${JULIA_REFERENCE}/src/physics.jl" \
  || fail 'locked Julia north Leeway formula changed'
record_pass julia-source-contract \
  'commit 1565573; water plus alpha wind in both components'

build_case serial packages.conf \
  "${FIELD_CASE}/code/SIZE.h.serial" no no
build_case mpi4 packages.conf \
  "${FIELD_CASE}/code/SIZE.h.mpi4" yes no
build_case exf-serial packages.exf.conf \
  "${FIELD_CASE}/code/SIZE.h.serial" no yes
build_case exf-mpi4 packages.exf.conf \
  "${FIELD_CASE}/code/SIZE.h.mpi4" yes yes

run_case i01-zero-serial serial 1 P1-I01-ZERO data.cartesian none \
  'P1-I01 PASS: zero Leeway RHS'
run_case i01-zero-mpi4 mpi4 4 P1-I01-ZERO data.cartesian none \
  'P1-I01 PASS: zero Leeway RHS'
run_case i02-cartesian-serial serial 1 P1-I02-CART data.cartesian none \
  'P1-I02 PASS: Cartesian SI coordinate rate'
run_case i02-cartesian-mpi4 mpi4 4 P1-I02-CART data.cartesian none \
  'P1-I02 PASS: Cartesian SI coordinate rate'
run_case i03-spherical-serial serial 1 P1-I03-SPHERE data.spherical none \
  'P1-I03 PASS: spherical degree-per-second rate'
run_case i04-leeway-serial exf-serial 1 P1-I04-LEEWAY \
  data.cartesian exf \
  'P1-I04 PASS: water plus wind Leeway algebra'
run_case i04-leeway-mpi4 exf-mpi4 4 P1-I04-LEEWAY \
  data.cartesian exf \
  'P1-I04 PASS: water plus wind Leeway algebra'
run_case n08-rhs-serial serial 1 P1-N08-RHS data.cartesian none \
  'P1-N08 RHS PASS: stable failure codes and no commit'

log 'run locked Julia RHS algebra and unit conversion'
env JULIA_DEPOT_PATH="${JULIA_DEPOT}" JULIA_PKG_OFFLINE=true \
  "${JULIA_BIN}" --startup-file=no --history-file=no \
  --project="${JULIA_REFERENCE}" "${CASE_DIR}/julia_rhs_smoke.jl" \
  > "${RUN_ROOT}/julia-rhs.log" 2>&1
grep -q 'P1-I04 JULIA RHS PASS' "${RUN_ROOT}/julia-rhs.log" \
  || fail 'Julia RHS marker missing'
grep -q 'sargassumbomb_version=0.7.14' \
  "${RUN_ROOT}/julia-rhs.log" \
  || fail 'Julia package version evidence missing'
record_pass julia-rhs \
  'SargassumBOMB 0.7.14 algebra and 1 m/s = 86.4 km/day'

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${ARTIFACT_ROOT}/source-head.txt"
git -C "${JULIA_REFERENCE}" rev-parse HEAD \
  > "${ARTIFACT_ROOT}/julia-head.txt"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv source-head.txt julia-head.txt > manifest.sha256
)

log 'P1.3 RHS GATE PASS'
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
