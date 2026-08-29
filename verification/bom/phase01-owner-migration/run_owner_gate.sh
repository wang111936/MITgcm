#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p14-owner-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase01-owner-migration}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase01-owner-migration}"
readonly ARTIFACT_PARENT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p14}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly ARTIFACT_ROOT="${ARTIFACT_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"

LAST_NEGATIVE_LOG=''
LAST_NEGATIVE_RC=0

fail() {
  printf 'P1.4 OWNER GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.4-owner] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 \
    || fail "required command not found: $1"
}

record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

required_commands=(
  bash cmp date find gfortran git grep make mpif77 mpirun nm rg sed sha256sum
  shellcheck sort uname xargs
)
for required_command in "${required_commands[@]}"; do
  require_command "${required_command}"
done
[[ -x "${REPO_ROOT}/tools/genmake2" ]] \
  || fail 'genmake2 is not executable'
[[ -f "${OPTFILE}" ]] || fail "optfile not found: ${OPTFILE}"
[[ "${REQUIRE_CLEAN}" == yes || "${REQUIRE_CLEAN}" == no ]] \
  || fail 'MITGCM_BOM_REQUIRE_CLEAN must be yes or no'
if [[ "${REQUIRE_CLEAN}" == yes \
      && -n "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]]; then
  fail 'exact-head evidence requires a clean worktree'
fi
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
  local size_file="$2"
  local mpi_enabled="$3"
  local bom_size_file="$4"
  local build_dir="${BUILD_ROOT}/${case_name}"
  local mods_dir="${BUILD_ROOT}/${case_name}-mods"
  local -a genmake_args
  local -a symbols
  local symbol

  log "build ${case_name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_owner_migration.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/"
  if [[ "${bom_size_file}" != - ]]; then
    cp "${bom_size_file}" "${mods_dir}/BOM_SIZE.h"
  fi

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
  symbols=(
    bom_locate_owner_
    bom_rhs_leeway_halo_
    bom_rk2_migrate_
    bom_rk4_migrate_
    bom_particle_exchange_
    bom_verify_owner_migration_
  )
  for symbol in "${symbols[@]}"; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${case_name}"
  done
  record_pass "build-${case_name}" \
    'GNU debug/IEEE build and P1.4 production symbols'
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local input_file="$3"
  local scenario="$4"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${input_file}" "${run_dir}/data"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/data.bom" "${run_dir}/data.bom"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  sed -i "s/the_run_name='[^']*'/the_run_name='${scenario}'/" \
    "${run_dir}/data"
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

collect_mpi_logs() {
  local run_dir="$1"
  local combined_log="$2"
  local ranks="$3"
  local rank
  local rank_log
  local rank_error_log

  : > "${combined_log}"
  if [[ -f "${run_dir}/mpi-launch.log" ]]; then
    cat "${run_dir}/mpi-launch.log" >> "${combined_log}"
  fi
  for ((rank=0; rank<ranks; rank++)); do
    printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
    if [[ -f "${rank_log}" ]]; then
      cat "${rank_log}" >> "${combined_log}"
    fi
    printf -v rank_error_log '%s/STDERR.%04d' "${run_dir}" "${rank}"
    if [[ -f "${rank_error_log}" ]]; then
      cat "${rank_error_log}" >> "${combined_log}"
    fi
  done
}

execute_positive() {
  local run_name="$1"
  local build_name="$2"
  local ranks="$3"
  local input_file="$4"
  local scenario="$5"
  local state_required="$6"
  local auxiliary_regex="$7"
  local run_dir="${RUN_ROOT}/${run_name}"
  local combined_log="${run_dir}/combined.log"
  local rank
  local rank_log
  local state_count

  log "run ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${input_file}" \
    "${scenario}"
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
    collect_mpi_logs "${run_dir}" "${combined_log}" "${ranks}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_normal_log "${rank_log}"
    done
  fi
  [[ "$(grep -c "P1.4 OWNER PASS: scenario=${scenario}" \
       "${combined_log}")" -eq 1 ]] \
    || fail "PASS marker count is not one: ${run_name}"
  if [[ "${auxiliary_regex}" != - ]]; then
    grep -Eq "${auxiliary_regex}" "${combined_log}" \
      || fail "auxiliary marker missing: ${run_name}"
  fi
  if [[ "${state_required}" == yes ]]; then
    state_count="$(grep -c 'P1-P14-STATE' "${combined_log}")"
    [[ "${state_count}" -eq 1 ]] \
      || fail "state marker count is not one: ${run_name}"
    sed -n 's/^.*\(P1-P14-STATE.*\)$/\1/p' "${combined_log}" \
      > "${run_dir}/state.txt"
  fi
  record_pass "${run_name}" \
    "${scenario}; unique owner; normal end"
}

execute_negative() {
  local run_name="$1"
  local build_name="$2"
  local ranks="$3"
  local input_file="$4"
  local scenario="$5"
  local run_dir="${RUN_ROOT}/${run_name}"
  local combined_log="${run_dir}/combined.log"
  local rc

  log "run expected failure ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${input_file}" \
    "${scenario}"
  set +e
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    rc=$?
    cp "${run_dir}/run.log" "${combined_log}"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    rc=$?
    collect_mpi_logs "${run_dir}" "${combined_log}" "${ranks}"
  fi
  set -e
  grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE' "${combined_log}" \
    || fail "fatal marker missing: ${run_name}"
  if grep -q 'PROGRAM MAIN: Execution ended Normally' "${combined_log}"; then
    fail "normal-end marker found in negative scenario: ${run_name}"
  fi
  LAST_NEGATIVE_LOG="${combined_log}"
  LAST_NEGATIVE_RC="${rc}"
}

compare_states() {
  local label="$1"
  local reference_file="$2"
  shift 2
  local candidate_file

  for candidate_file in "$@"; do
    cmp -s "${reference_file}" "${candidate_file}" \
      || fail "bitwise state mismatch: ${label}: ${candidate_file}"
  done
  record_pass "compare-${label}" 'P1-P14-STATE bitwise identical'
}

log 'audit frozen production owner-migration contract'
readonly LOCATE_SOURCE="${REPO_ROOT}/pkg/bom/bom_locate_owner.F"
readonly EXCHANGE_SOURCE="${REPO_ROOT}/pkg/bom/bom_particle_exchange.F"
readonly MAIN_SOURCE="${REPO_ROOT}/pkg/bom/bom_main.F"
readonly CHECK_SOURCE="${REPO_ROOT}/pkg/bom/bom_check.F"
readonly SIZE_SOURCE="${REPO_ROOT}/pkg/bom/BOM_SIZE.h"
for source_file in "${LOCATE_SOURCE}" "${EXCHANGE_SOURCE}" \
                   "${MAIN_SOURCE}" "${CHECK_SOURCE}" "${SIZE_SOURCE}"; do
  [[ -f "${source_file}" ]] \
    || fail "missing production owner source: ${source_file}"
done
[[ "$(grep -c 'DO WHILE ( lo.LT.hi )' "${LOCATE_SOURCE}")" -eq 2 ]] \
  || fail 'owner location must binary-search X and Y face tables'
grep -Fq 'CALL BOM_NORMALIZE_X' "${LOCATE_SOURCE}" \
  || fail 'periodic X normalization is missing'
grep -Fq 'mpi_myXGlobalLo(rankIndex).EQ.expectedXLo' "${LOCATE_SOURCE}" \
  || fail 'actual MPI X origin mapping is missing'
grep -Fq 'mpi_myYGlobalLo(rankIndex).EQ.expectedYLo' "${LOCATE_SOURCE}" \
  || fail 'actual MPI Y origin mapping is missing'
grep -Fq 'hopCount = MAX(dxTile,dyTile)' "${LOCATE_SOURCE}" \
  || fail 'Chebyshev tile hop is missing'
[[ "$(grep -c 'CALL BOM_RK2_MIGRATE' "${MAIN_SOURCE}")" -eq 1 ]] \
  || fail 'BOM_MAIN must call migration-aware RK2 once'
[[ "$(grep -c 'CALL BOM_RK4_MIGRATE' "${MAIN_SOURCE}")" -eq 1 ]] \
  || fail 'BOM_MAIN must call migration-aware RK4 once'
[[ "$(grep -c 'CALL BOM_PARTICLE_EXCHANGE' "${MAIN_SOURCE}")" -eq 1 ]] \
  || fail 'BOM_MAIN must exchange once per nominal substep'
[[ "$(grep -c 'CALL MPI_Alltoall(' "${EXCHANGE_SOURCE}")" -eq 1 ]] \
  || fail 'exactly one MPI_Alltoall count exchange is required'
[[ "$(grep -c 'CALL MPI_Alltoallv(' "${EXCHANGE_SOURCE}")" -eq 2 ]] \
  || fail 'exactly two MPI_Alltoallv packet exchanges are required'
grep -Fq 'PARAMETER ( bomPacketSchema   = 2 )' "${SIZE_SOURCE}" \
  || fail 'owner migration schema is not version 2'
grep -Fq 'packetSchemaActive=bomPacketSchema' "${EXCHANGE_SOURCE}" \
  || fail 'schema-v2 packet default is missing'
grep -Fq 'sendInt(packetOffsetI+1) = packetSchemaActive' \
  "${EXCHANGE_SOURCE}" || fail 'schema-v2 packet marker is missing'
grep -Fq 'sendInt(packetOffsetI+2) = INT(idHi8)' "${EXCHANGE_SOURCE}" \
  || fail 'schema-v2 64-bit ID high-word packing is missing'
grep -Fq 'sendInt(packetOffsetI+3) = INT(idLo8' "${EXCHANGE_SOURCE}" \
  || fail 'schema-v2 64-bit ID low-word packing is missing'
grep -Fq 'packetRealsActive=bomPacketReals' "${EXCHANGE_SOURCE}" \
  || fail 'schema-v2 real packet width is not the default'
grep -Fq 'sendReal(packetOffsetR+1) = planX' "${EXCHANGE_SOURCE}" \
  || fail 'minimal real packet X field is missing'
grep -Fq 'sendReal(packetOffsetR+4) = bomAge' "${EXCHANGE_SOURCE}" \
  || fail 'minimal real packet age field is missing'
grep -Fq 'IF ( globalMoveCount.EQ.0 ) RETURN' "${EXCHANGE_SOURCE}" \
  || fail 'bitwise no-movement fast path is missing'
grep -Fq 'targetCount(bi,bj).GT.bomMaxPartTile' "${EXCHANGE_SOURCE}" \
  || fail 'target tile capacity preflight is missing'
grep -Eq 'workId\(jp,bi,bj\)\.(GT|LE)\.keyId' \
  "${EXCHANGE_SOURCE}" \
  || fail 'full INTEGER*8 deterministic sort is missing'
grep -Fq 'PARAMETER ( bomMaxExchange    = bomMaxInitRecords )' \
  "${SIZE_SOURCE}" || fail 'production exchange capacity is below initial limit'
grep -Fq 'bomAdvCFL.GT.1.' "${CHECK_SOURCE}" \
  || fail 'P1.4 CFL upper-bound check is missing'
grep -Fq 'OLx.LT.2 .OR. OLy.LT.2' "${CHECK_SOURCE}" \
  || fail 'P1.4 overlap precondition is missing'
if rg -n 'MPI_INTEGER8' "${REPO_ROOT}/pkg/bom"; then
  fail 'non-portable MPI_INTEGER8 leaked into production BOM'
fi
if rg -n 'FLT_' "${REPO_ROOT}/pkg/bom"; then
  fail 'P1.4 production code accesses FLT state'
fi
if rg -n 'P1-X0|P1-N03|P1-P14|BOM_VERIFY_OWNER' \
     "${REPO_ROOT}/pkg/bom"; then
  fail 'owner verification marker leaked into production BOM'
fi
record_pass source-contract \
  'binary owner map; halo RK; transactional two-word MPI migration'

build_case serial "${CASE_DIR}/code/SIZE.h.serial" no -
build_case mpi2 "${CASE_DIR}/code/SIZE.h.mpi2" yes -
build_case mpi4 "${CASE_DIR}/code/SIZE.h.mpi4" yes -
build_case multi-serial "${CASE_DIR}/code/SIZE.h.multi.serial" no -
build_case multi-mpi4 "${CASE_DIR}/code/SIZE.h.multi.mpi4" yes -
build_case capacity-mpi4 "${CASE_DIR}/code/SIZE.h.mpi4" yes \
  "${CASE_DIR}/code/BOM_SIZE.h.small"
build_case tile-serial "${CASE_DIR}/code/SIZE.h.serial" no \
  "${CASE_DIR}/code/BOM_SIZE.h.tile-small"

for scenario_suffix in H V C; do
  execute_positive "x01-${scenario_suffix,,}-serial" serial 1 \
    "${CASE_DIR}/input/data.cartesian" "P1-X01-${scenario_suffix}" yes -
  execute_positive "x02-r-${scenario_suffix,,}-mpi2" mpi2 2 \
    "${CASE_DIR}/input/data.cartesian" "P1-X01-${scenario_suffix}" yes -
  execute_positive "x02-r-${scenario_suffix,,}-mpi4" mpi4 4 \
    "${CASE_DIR}/input/data.cartesian" "P1-X01-${scenario_suffix}" yes -
done

execute_positive x04-id-serial serial 1 \
  "${CASE_DIR}/input/data.cartesian" P1-X04-ID yes -
execute_positive x04-id-mpi2 mpi2 2 \
  "${CASE_DIR}/input/data.cartesian" P1-X04-ID yes -
execute_positive x04-id-mpi4 mpi4 4 \
  "${CASE_DIR}/input/data.cartesian" P1-X04-ID yes -

execute_positive x02-p-serial serial 1 \
  "${CASE_DIR}/input/data.spherical" P1-X02-P yes -
execute_positive x02-p-mpi2 mpi2 2 \
  "${CASE_DIR}/input/data.spherical" P1-X02-P yes -
execute_positive x02-p-mpi4 mpi4 4 \
  "${CASE_DIR}/input/data.spherical" P1-X02-P yes -

execute_positive x03-multi-serial multi-serial 1 \
  "${CASE_DIR}/input/data.multi" P1-X03 yes -
execute_positive x03-multi-mpi4 multi-mpi4 4 \
  "${CASE_DIR}/input/data.multi" P1-X03 yes -
execute_positive x-stencil-serial serial 1 \
  "${CASE_DIR}/input/data.cartesian" P1-X-STENCIL no \
  'P1-P14-STENCIL stage/code=[[:space:]]+2[[:space:]]+3'

for scenario_suffix in h v c; do
  compare_states "x01-${scenario_suffix}" \
    "${RUN_ROOT}/x01-${scenario_suffix}-serial/state.txt" \
    "${RUN_ROOT}/x02-r-${scenario_suffix}-mpi2/state.txt" \
    "${RUN_ROOT}/x02-r-${scenario_suffix}-mpi4/state.txt"
done
compare_states x04-id \
  "${RUN_ROOT}/x04-id-serial/state.txt" \
  "${RUN_ROOT}/x04-id-mpi2/state.txt" \
  "${RUN_ROOT}/x04-id-mpi4/state.txt"
compare_states x02-p \
  "${RUN_ROOT}/x02-p-serial/state.txt" \
  "${RUN_ROOT}/x02-p-mpi2/state.txt" \
  "${RUN_ROOT}/x02-p-mpi4/state.txt"
compare_states x03-multi \
  "${RUN_ROOT}/x03-multi-serial/state.txt" \
  "${RUN_ROOT}/x03-multi-mpi4/state.txt"

execute_negative n03b-capacity-mpi4 capacity-mpi4 4 \
  "${CASE_DIR}/input/data.capacity" P1-N03B-CAP
grep -Eq 'rank/direction=[[:space:]]+0[[:space:]]+SEND[[:space:]]+needed/limit=[[:space:]]+2[[:space:]]+1' \
  "${LAST_NEGATIVE_LOG}" || fail 'P1-N03b SEND diagnostic missing'
record_pass n03b-send \
  "rank 0 SEND needed/limit=2/1; collective fatal; rc=${LAST_NEGATIVE_RC}"
grep -Eq 'rank/direction=[[:space:]]+2[[:space:]]+RECV[[:space:]]+needed/limit=[[:space:]]+2[[:space:]]+1' \
  "${LAST_NEGATIVE_LOG}" || fail 'P1-N03b RECV diagnostic missing'
record_pass n03b-recv \
  "rank 2 RECV needed/limit=2/1; collective fatal; rc=${LAST_NEGATIVE_RC}"

execute_negative n03b-tile-serial tile-serial 1 \
  "${CASE_DIR}/input/data.cartesian" P1-N03B-TILE
grep -Eq 'rank/tile=[[:space:]]+0[[:space:]]+2[[:space:]]+1[[:space:]]+needed/limit=[[:space:]]+2[[:space:]]+1' \
  "${LAST_NEGATIVE_LOG}" || fail 'P1-N03b target tile diagnostic missing'
record_pass n03b-tile \
  "rank/tile=0/2/1 needed/limit=2/1; no truncation; rc=${LAST_NEGATIVE_RC}"

execute_negative x03-hop-serial multi-serial 1 \
  "${CASE_DIR}/input/data.multi" P1-X03-HOP
grep -Eq 'hop limit id=[[:space:]]+4100000001.*rank/source=[[:space:]]+0[[:space:]]+1[[:space:]]+1.*target/hop/limit=[[:space:]]+0[[:space:]]+3[[:space:]]+1[[:space:]]+2[[:space:]]+1' \
  "${LAST_NEGATIVE_LOG}" || fail 'P1-X03-HOP contextual diagnostic missing'
grep -Eq 'fatal owner/hop errors=.*iter/sub=[[:space:]]+9[[:space:]]+3' \
  "${LAST_NEGATIVE_LOG}" || fail 'P1-X03-HOP collective context missing'
record_pass x03-hop \
  "ID/source/target/hop/limit and iter/sub context; rc=${LAST_NEGATIVE_RC}"

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${ARTIFACT_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${ARTIFACT_ROOT}/git-status.txt"
{
  printf 'utc='; date -u +%Y-%m-%dT%H:%M:%SZ
  printf 'uname='; uname -a
  printf 'branch='; git -C "${REPO_ROOT}" branch --show-current
  printf 'gfortran='; gfortran --version | sed -n '1p'
  printf 'mpif77='; mpif77 --version | sed -n '1p'
  printf 'mpirun='; mpirun --version | sed -n '1p'
  printf 'optfile_sha256='; sha256sum "${OPTFILE}"
  printf 'make_jobs=%s\n' "${MAKE_JOBS}"
  printf 'require_clean=%s\n' "${REQUIRE_CLEAN}"
} > "${ARTIFACT_ROOT}/environment.txt"
(
  cd "${REPO_ROOT}"
  find verification/bom/phase01-owner-migration/code \
       verification/bom/phase01-owner-migration/input \
       -type f -print0 | sort -z | xargs -0 sha256sum
) > "${ARTIFACT_ROOT}/config.sha256"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum config.sha256 environment.txt git-status.txt \
    source-head.txt summary.tsv > manifest.sha256
)

PASS_COUNT="$(grep -c $'\tPASS\t' "${RUN_ROOT}/summary.tsv")"
readonly PASS_COUNT
[[ "${PASS_COUNT}" -eq 36 ]] \
  || fail "expected 36 PASS rows, found ${PASS_COUNT}"
log 'P1.4 OWNER GATE PASS (36/36)'
log "source head:    $(cat "${ARTIFACT_ROOT}/source-head.txt")"
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
