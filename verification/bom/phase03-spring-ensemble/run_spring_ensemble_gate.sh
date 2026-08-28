#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:-$(git -C "${REPO_ROOT}" rev-parse HEAD)}"
readonly BASELINE_REF="${MITGCM_BOM_BASELINE_REF:-MITGCM-BOM/development}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly SHORT_HEAD="${EXPECTED_HEAD:0:10}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p33-spring-${SHORT_HEAD}-attempt01}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase03-spring-ensemble}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase03-spring-ensemble}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p33-spring-ensemble}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXPECTED_ROWS=34

fail() { printf 'P3.3 SPRING ENSEMBLE GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P3.3-spring] %s\n' "$*"; }
record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

for command_name in awk bash cmp date find gfortran git grep make mpirun \
  nm rg sed sha256sum shellcheck sort tr uname wc; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || fail "missing ${command_name}"
done
[[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" == "${EXPECTED_HEAD}" ]] \
  || fail 'current HEAD differs from MITGCM_BOM_EXPECTED_HEAD'
if [[ "${REQUIRE_CLEAN}" == yes ]]; then
  [[ -z "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]] \
    || fail 'authoritative run requires a clean worktree'
fi
git -C "${REPO_ROOT}" rev-parse --verify "${BASELINE_REF}^{commit}" \
  >/dev/null || fail "missing baseline ref ${BASELINE_REF}"
for root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${root}" ]] || fail "evidence root already exists: ${root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

source_audit() {
  local path
  local -a allowed_production=(
    pkg/bom/BOM.h
    pkg/bom/BOM_GRAPH_SIZE.h
    pkg/bom/BOM_SIZE.h
    pkg/bom/bom_check.F
    pkg/bom/bom_check_state.F
    pkg/bom/bom_ghost_exchange.F
    pkg/bom/bom_init_state.F
    pkg/bom/bom_main.F
    pkg/bom/bom_particle_exchange.F
    pkg/bom/bom_spring_ensemble.F
    pkg/bom/bom_spring_rhs_stage.F
    pkg/bom/bom_spring_stage.F
  )
  git -C "${REPO_ROOT}" diff --name-only \
    "${BASELINE_REF}...${EXPECTED_HEAD}" > "${RUN_ROOT}/changed-paths.txt"
  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    if [[ "${path}" == pkg/bom/* ]]; then
      printf '%s\n' "${allowed_production[@]}" | grep -Fxq "${path}" \
        || fail "out-of-scope production path: ${path}"
    fi
    if [[ "${path,,}" =~ skrips ]]; then
      fail "forbidden project identity in path: ${path}"
    fi
  done < "${RUN_ROOT}/changed-paths.txt"
  record_pass p33-source-scope \
    'P3.3 production/test/document paths only; no foreign project identity'

  grep -Fq "bomSpringLaw.NE.'NONE'" \
    "${REPO_ROOT}/pkg/bom/bom_main.F" \
    || fail 'missing spring-enabled ensemble dispatch guard'
  grep -Fq 'CALL BOM_RK2_SPRING_ENSEMBLE' \
    "${REPO_ROOT}/pkg/bom/bom_main.F" \
    || fail 'missing RK2 spring ensemble dispatch'
  grep -Fq 'CALL BOM_RK4_SPRING_ENSEMBLE' \
    "${REPO_ROOT}/pkg/bom/bom_main.F" \
    || fail 'missing RK4 spring ensemble dispatch'
  record_pass p33-none-dispatch \
    'spring NONE remains on the accepted v0.3 branch'

  grep -Fq 'PARAMETER ( bomGhostSchema    = 1 )' \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    || fail 'ghost schema is not version 1'
  grep -Fq 'PARAMETER ( bomGhostPacketInts = 9 )' \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    || fail 'ghost integer packet width changed'
  grep -Fq 'PARAMETER ( bomGhostPacketReals = 2 )' \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    || fail 'ghost real packet width changed'
  grep -Fq 'MPI_Alltoallv' \
    "${REPO_ROOT}/pkg/bom/bom_ghost_exchange.F" \
    || fail 'ghost packet collective is missing'
  record_pass p33-ghost-contract \
    'version-1 9-int/2-real packet and all-to-all-v transaction'

  grep -Fq 'PARAMETER ( bomPacketSchema   = 2 )' \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    || fail 'owner migration schema is not version 2'
  grep -Fq 'sendReal(5,packetIndex) = bomSpringEast' \
    "${REPO_ROOT}/pkg/bom/bom_particle_exchange.F" \
    || fail 'migration packet does not carry spring east'
  grep -Fq 'sendInt(10,packetIndex) = bomRaftSize' \
    "${REPO_ROOT}/pkg/bom/bom_particle_exchange.F" \
    || fail 'migration packet does not carry raft size'
  record_pass p33-migration-contract \
    'version-2 owner packet carries spring/neighbor/reserved raft fields'

  if rg -i 'MPI_(Gather|Gatherv|Allgather|Allgatherv)' \
    "${REPO_ROOT}/pkg/bom/bom_ghost_exchange.F" \
    "${REPO_ROOT}/pkg/bom/bom_spring_stage.F" \
    "${REPO_ROOT}/pkg/bom/bom_spring_rhs_stage.F" \
    "${REPO_ROOT}/pkg/bom/bom_spring_ensemble.F"; then
    fail 'prohibited global particle gather in P3.3 path'
  fi
  record_pass p33-no-global-gather \
    'no gather/allgather or root particle-list construction'

  : > "${RUN_ROOT}/fixed-line-overflow.txt"
  while IFS= read -r source_file; do
    awk 'length($0)>72 && substr($0,1,1)!="C" {print FNR ":" $0}' \
      "${source_file}" | sed "s#^#${source_file}:#" \
      >> "${RUN_ROOT}/fixed-line-overflow.txt"
  done < <(find "${REPO_ROOT}/pkg/bom" "${CASE_DIR}/code" \
    -maxdepth 1 -type f \( -name '*.F' -o -name '*.h' \) | sort)
  [[ ! -s "${RUN_ROOT}/fixed-line-overflow.txt" ]] \
    || fail 'non-comment fixed-form source exceeds column 72'
  record_pass p33-fixed-line \
    'P3.3 production and direct-driver fixed-form lines are bounded'
}

build_case() {
  local name="$1" size="$2" mpi="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_spring_ensemble.F" "${mods_dir}/"
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
  for symbol in bom_ghost_exchange_ bom_spring_stage_ \
    bom_spring_rhs_stage_ bom_rk2_spring_ensemble_ \
    bom_rk4_spring_ensemble_ bom_particle_exchange_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing symbol ${symbol} in ${name}"
  done
  record_pass "build-${name}" \
    "genmake2/depend/compile/link and P3.3 symbols (${mpi})"
}

run_case() {
  local name="$1" np="$2"
  local build_dir="${BUILD_ROOT}/${name}"
  local run_dir="${RUN_ROOT}/${name}"
  local marker
  local -a outputs
  mkdir -p "${run_dir}"
  cp -a "${CASE_DIR}/input/." "${run_dir}/"
  cp "${build_dir}/mitgcmuv" "${run_dir}/"
  if [[ "${np}" -eq 1 ]]; then
    ( cd "${run_dir}"; ./mitgcmuv > output.txt 2>&1 )
    outputs=( "${run_dir}/output.txt" )
  else
    ( cd "${run_dir}"; mpirun -np "${np}" ./mitgcmuv > output.txt 2>&1 )
    outputs=( "${run_dir}"/STDOUT.* )
  fi
  local -a markers=(
    'P3-G01 PASS:'
    'P3-G02 PASS:'
    'P3-I01 PASS:'
    'P3-I02 PASS:'
    'P3-I03 PASS:'
    'B09 PASS:'
    'P3-M01 PASS:'
    'B17 PASS:'
  )
  for marker in "${markers[@]}"; do
    rg -q "${marker}" "${outputs[@]}" \
      || fail "missing ${marker} in ${name}"
    record_pass "run-${name}-$(printf '%s' "${marker}" \
      | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')" \
      "${marker} np=${np}"
  done
  rg --no-filename '^P3-B17 RECORD' "${outputs[@]}" | sort \
    > "${RUN_ROOT}/b17-${name}.txt"
  [[ "$(wc -l < "${RUN_ROOT}/b17-${name}.txt")" -eq 2 ]] \
    || fail "expected two B17 records in ${name}"
}

source_audit
build_case serial SIZE.h.serial no
build_case mpi2 SIZE.h.mpi2 yes
build_case mpi4 SIZE.h.mpi4 yes
run_case serial 1
run_case mpi2 2
run_case mpi4 4
cmp "${RUN_ROOT}/b17-serial.txt" "${RUN_ROOT}/b17-mpi2.txt"
cmp "${RUN_ROOT}/b17-serial.txt" "${RUN_ROOT}/b17-mpi4.txt"
record_pass p33-b17-bitwise \
  'canonical ID-sorted dynamics are bitwise equal for serial/MPI2/MPI4'

actual_rows="$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END {print n+0}' \
  "${RUN_ROOT}/summary.tsv")"
[[ "${actual_rows}" -eq "${EXPECTED_ROWS}" ]] \
  || fail "expected ${EXPECTED_ROWS} PASS rows, got ${actual_rows}"
git -C "${REPO_ROOT}" rev-parse HEAD > "${RUN_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 > "${RUN_ROOT}/git-status.txt"
if [[ "${REQUIRE_CLEAN}" == yes ]]; then
  [[ ! -s "${RUN_ROOT}/git-status.txt" ]] || fail 'tests changed worktree'
fi
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
cp "${RUN_ROOT}/changed-paths.txt" "${ARTIFACT_ROOT}/changed-paths.txt"
cp "${RUN_ROOT}/source-head.txt" "${ARTIFACT_ROOT}/source-head.txt"
cp "${RUN_ROOT}/git-status.txt" "${ARTIFACT_ROOT}/git-status.txt"
cp "${RUN_ROOT}/b17-serial.txt" "${ARTIFACT_ROOT}/b17-canonical.txt"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum b17-canonical.txt changed-paths.txt git-status.txt \
    source-head.txt summary.tsv > manifest.sha256
  sha256sum -c manifest.sha256 > manifest-check.log
)
log "P3.3 SPRING ENSEMBLE GATE PASS (${EXPECTED_ROWS}/${EXPECTED_ROWS})"
log "source head: ${EXPECTED_HEAD}"
log "evidence root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
