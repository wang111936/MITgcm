#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p15-migration-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase01-output-pickup-coexistence}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase01-output-pickup-coexistence}"
readonly ARTIFACT_PARENT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly ARTIFACT_ROOT="${ARTIFACT_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly P14_CASE="${REPO_ROOT}/verification/bom/phase01-owner-migration"

fail() {
  printf 'P1.5 MIGRATION GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.5-migration] %s\n' "$*"
}

record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

for command_name in bash cmp date find git gfortran grep make mpif77 \
                    mpirun mv nm python3 sed sha256sum shellcheck sort \
                    uname xargs; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || fail "required command not found: ${command_name}"
done
[[ -x "${REPO_ROOT}/tools/genmake2" ]] || fail 'genmake2 is not executable'
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
PYTHONPYCACHEPREFIX="${RUN_ROOT}/pycache" \
  python3 -m py_compile "${CASE_DIR}/make_migration_inputs.py"
PYTHONPYCACHEPREFIX="${RUN_ROOT}/pycache" \
  python3 -m py_compile "${CASE_DIR}/verify_migration.py"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

grep -Fq 'CALL BOM_PARTICLE_EXCHANGE' "${REPO_ROOT}/pkg/bom/bom_main.F" \
  || fail 'production migration call is missing'
grep -Fq 'CALL BOM_OUTPUT( myTime, myIter, myThid )' \
  "${REPO_ROOT}/model/src/do_the_model_io.F" \
  || fail 'production model I/O hook is missing'
grep -Fq 'CALL BOM_WRITE_PICKUP' \
  "${REPO_ROOT}/model/src/packages_write_pickup.F" \
  || fail 'production package pickup hook is missing'
record_pass source-migration-io-contract \
  'production migration, model-I/O, and package-pickup hooks'

build_case() {
  local case_name="$1"
  local size_file="$2"
  local mpi_enabled="$3"
  local build_dir="${BUILD_ROOT}/${case_name}"
  local mods_dir="${BUILD_ROOT}/${case_name}-mods"
  local -a genmake_args
  local symbol

  log "build ${case_name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${size_file}" "${mods_dir}/SIZE.h"
  cp "${P14_CASE}/code/packages.conf" "${mods_dir}/packages.conf"
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
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing ${case_name} executable"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_main_ bom_particle_exchange_ bom_output_ \
                bom_write_trajectory_ bom_write_pickup_ bom_read_pickup_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${case_name}"
  done
  record_pass "build-migration-${case_name}" \
    'GNU debug/IEEE production executable and migration/I/O symbols'
}

build_case serial "${P14_CASE}/code/SIZE.h.serial" no
build_case mpi4 "${P14_CASE}/code/SIZE.h.mpi4" yes

assert_normal() {
  local log_file="$1"
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" \
    || fail "normal-end marker missing: ${log_file}"
  if grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE|fatal error' "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

collect_mpi_logs() {
  local run_dir="$1"
  local combined_log="$2"
  local ranks="$3"
  local rank
  local rank_log

  : > "${combined_log}"
  [[ ! -f "${run_dir}/mpi-launch.log" ]] \
    || cat "${run_dir}/mpi-launch.log" >> "${combined_log}"
  for ((rank=0; rank<ranks; rank++)); do
    printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
    [[ ! -f "${rank_log}" ]] || cat "${rank_log}" >> "${combined_log}"
    printf -v rank_log '%s/STDERR.%04d' "${run_dir}" "${rank}"
    [[ ! -f "${rank_log}" ]] || cat "${rank_log}" >> "${combined_log}"
  done
}

assert_mpi_normal() {
  local run_dir="$1"
  local ranks="$2"
  local rank
  local rank_log

  for ((rank=0; rank<ranks; rank++)); do
    printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
    assert_normal "${rank_log}"
  done
}

prepare_run() {
  local run_name="$1"
  local build_name="$2"
  local end_time="$3"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${P14_CASE}/input/data.cartesian" "${run_dir}/data"
  cp "${P14_CASE}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${P14_CASE}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/data.bom.migration" "${run_dir}/data.bom"
  sed -i \
    -e "s/endTime=0\./endTime=${end_time}./" \
    -e 's/deltaTmom=1200\./deltaTmom=60./' \
    -e 's/deltaTtracer=1200\./deltaTtracer=60./' \
    -e 's/deltaTClock=1200\./deltaTClock=60./' \
    -e "s/the_run_name='[^']*'/the_run_name='${run_name}'/" \
    "${run_dir}/data"
  sed -i "/&PARM05/a\\
 uVelInitFile='U.const',\\
 vVelInitFile='V.const'," "${run_dir}/data"
  python3 "${CASE_DIR}/make_migration_inputs.py" "${run_dir}" \
    > "${run_dir}/input.log"
  grep -q 'P1.5 MIGRATION INPUT PASS' "${run_dir}/input.log" \
    || fail "migration input marker missing: ${run_name}"
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" "${run_dir}/mitgcmuv"
}

execute_run() {
  local run_name="$1"
  local build_name="$2"
  local ranks="$3"
  local end_time="$4"
  local permanent_frequency="${5:-0}"
  local run_dir="${RUN_ROOT}/${run_name}"

  log "run ${run_name}"
  prepare_run "${run_name}" "${build_name}" "${end_time}"
  if [[ "${permanent_frequency}" != 0 ]]; then
    sed -i "s/pChkptFreq=0\./pChkptFreq=${permanent_frequency}./" \
      "${run_dir}/data"
  fi
  if [[ "${ranks}" -eq 1 ]]; then
    (
      cd "${run_dir}"
      ./mitgcmuv > run.log 2>&1
    )
    assert_normal "${run_dir}/run.log"
  else
    (
      cd "${run_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    collect_mpi_logs "${run_dir}" "${run_dir}/combined.log" "${ranks}"
    assert_mpi_normal "${run_dir}" "${ranks}"
  fi
}

verify_run() {
  local run_name="$1"
  local npx="$2"
  local npy="$3"
  local nsx="$4"
  local nsy="$5"
  local run_dir="${RUN_ROOT}/${run_name}"

  python3 "${CASE_DIR}/verify_migration.py" \
    "${run_dir}" "${run_dir}/trajectory.tsv" "${run_dir}/pickup.tsv" \
    --npx "${npx}" --npy "${npy}" --nsx "${nsx}" --nsy "${nsy}" \
    --trajectory-invariant "${run_dir}/trajectory-invariant.tsv" \
    --pickup-invariant "${run_dir}/pickup-invariant.tsv" \
    > "${run_dir}/verify.log"
  grep -q 'P1.5 MIGRATION VERIFY PASS' "${run_dir}/verify.log" \
    || fail "migration verifier marker missing: ${run_name}"
}

verify_layout() {
  local layout="$1"
  local ranks="$2"
  local npx="$3"
  local npy="$4"
  local nsx="$5"
  local nsy="$6"
  local continuous="migration-continuous-${layout}"
  local split="migration-split-${layout}"
  local split_dir="${RUN_ROOT}/${split}"
  local log_file

  execute_run "${continuous}" "${layout}" "${ranks}" 480
  verify_run "${continuous}" "${npx}" "${npy}" "${nsx}" "${nsy}"
  record_pass "p1-o01-${layout}-continuous" \
    '4 frames; cross-owner; WAITING release; final pickup verified'

  execute_run "${split}" "${layout}" "${ranks}" 300 300
  [[ -f "${split_dir}/pickup_bom.0000000005.sig.data" ]] \
    || fail "missing ${layout} iteration-5 BOM signature"
  [[ -f "${split_dir}/pickup.0000000005.001.001.meta" ]] \
    || fail "missing ${layout} iteration-5 core pickup"
  record_pass "p1-p02-${layout}-segment" \
    'iteration 5 permanent core+BOM pickup after owner migration'

  cp "${split_dir}/data" "${split_dir}/data.segment"
  sed -i \
    -e 's/nIter0=0,/nIter0=5,/' \
    -e '/nIter0=5,/a\ startTime=300.,' \
    -e 's/endTime=300\./endTime=480./' \
    "${split_dir}/data"
  if [[ "${ranks}" -eq 1 ]]; then
    mv "${split_dir}/run.log" "${split_dir}/segment.log"
    (
      cd "${split_dir}"
      ./mitgcmuv > restart.log 2>&1
    )
    assert_normal "${split_dir}/restart.log"
    grep -q 'BOM_READ_PICKUP: complete suffix=0000000005' \
      "${split_dir}/restart.log" \
      || fail "${layout} restart reader marker missing"
  else
    mkdir "${split_dir}/segment-logs"
    for log_file in "${split_dir}"/STDOUT.* "${split_dir}"/STDERR.* \
                    "${split_dir}/mpi-launch.log"; do
      [[ -e "${log_file}" ]] || continue
      mv "${log_file}" "${split_dir}/segment-logs/"
    done
    (
      cd "${split_dir}"
      mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
    )
    collect_mpi_logs "${split_dir}" "${split_dir}/restart-combined.log" \
      "${ranks}"
    assert_mpi_normal "${split_dir}" "${ranks}"
    grep -q 'BOM_READ_PICKUP: complete suffix=0000000005' \
      "${split_dir}/restart-combined.log" \
      || fail "${layout} restart reader marker missing"
  fi
  verify_run "${split}" "${npx}" "${npy}" "${nsx}" "${nsy}"
  cmp -s "${RUN_ROOT}/${continuous}/trajectory.tsv" \
         "${split_dir}/trajectory.tsv" \
    || fail "${layout} migration continuous/split trajectory mismatch"
  cmp -s "${RUN_ROOT}/${continuous}/pickup.tsv" \
         "${split_dir}/pickup.tsv" \
    || fail "${layout} migration continuous/split pickup mismatch"
  record_pass "p1-p02-${layout}-restart" \
    '5+3 split equals continuous migrated owner state and output bitwise'
}

verify_layout serial 1 1 1 2 2
verify_layout mpi4 4 2 2 1 1

cmp -s "${RUN_ROOT}/migration-continuous-serial/trajectory-invariant.tsv" \
       "${RUN_ROOT}/migration-continuous-mpi4/trajectory-invariant.tsv" \
  || fail 'serial/MPI4 migrated trajectory physical fields differ'
record_pass p1-o01-cross-layout \
  'serial/MPI4 migrated physical trajectory fields bitwise identical'
cmp -s "${RUN_ROOT}/migration-continuous-serial/pickup-invariant.tsv" \
       "${RUN_ROOT}/migration-continuous-mpi4/pickup-invariant.tsv" \
  || fail 'serial/MPI4 migrated pickup physical state differs'
record_pass p1-p02-cross-layout \
  'serial/MPI4 migrated final physical state bitwise identical'
record_pass p1-p02-mpi4-migration \
  'MPI4 cross-rank state, large ID, release, pickup, and restart exact'

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
  sha256sum \
    verification/bom/phase01-output-pickup-coexistence/input/data.bom.migration \
    verification/bom/phase01-output-pickup-coexistence/make_migration_inputs.py \
    verification/bom/phase01-output-pickup-coexistence/verify_migration.py
) > "${ARTIFACT_ROOT}/config.sha256"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum config.sha256 environment.txt git-status.txt \
    source-head.txt summary.tsv > manifest.sha256
)

pass_count="$(grep -c $'\tPASS\t' "${RUN_ROOT}/summary.tsv")"
[[ "${pass_count}" -eq 12 ]] \
  || fail "expected 12 PASS rows, found ${pass_count}"
log 'P1.5 MIGRATION OUTPUT/PICKUP GATE PASS (12/12)'
log "source head:    $(cat "${ARTIFACT_ROOT}/source-head.txt")"
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
