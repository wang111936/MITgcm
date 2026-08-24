#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p15-output-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
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
readonly P11_CASE="${REPO_ROOT}/verification/bom/phase01-bom-lite"
readonly P14_CASE="${REPO_ROOT}/verification/bom/phase01-owner-migration"

fail() {
  printf 'P1.5 OUTPUT GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.5-output] %s\n' "$*"
}

record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

for command_name in bash date find git grep make nm python3 sed sha256sum \
                    shellcheck sort uname xargs; do
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
  python3 -m py_compile "${CASE_DIR}/verify_trajectory.py"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

log 'audit output source contract'
grep -Fq 'CALL BOM_OUTPUT( myTime, myIter, myThid )' \
  "${REPO_ROOT}/model/src/do_the_model_io.F" \
  || fail 'DO_THE_MODEL_IO output hook is missing'
grep -Fq "WRITE(fileName,'(A,A10)') 'bom_traj.', suffix" \
  "${REPO_ROOT}/pkg/bom/bom_write_trajectory.F" \
  || fail 'frozen trajectory prefix is missing'
grep -Fq 'idHi8 = bomId(ip,bi,bj)/idRadix' \
  "${REPO_ROOT}/pkg/bom/bom_write_trajectory.F" \
  || fail 'trajectory ID high-word encoding is missing'
grep -Fq 'idLo8 = MOD(bomId(ip,bi,bj),idRadix)' \
  "${REPO_ROOT}/pkg/bom/bom_write_trajectory.F" \
  || fail 'trajectory ID low-word encoding is missing'
if rg -n 'FLT_|float_trajectories|pickup_flt' \
     "${REPO_ROOT}/pkg/bom/bom_output.F" \
     "${REPO_ROOT}/pkg/bom/bom_write_trajectory.F"; then
  fail 'FLT state or prefix leaked into BOM output'
fi
record_pass source-output-contract \
  'post-migration hook; frozen prefix/schema; exact two-word ID'

log 'build production serial output case'
readonly BUILD_DIR="${BUILD_ROOT}/serial"
readonly MODS_DIR="${BUILD_ROOT}/serial-mods"
mkdir -p "${BUILD_DIR}" "${MODS_DIR}"
cp -a "${EXP2_CODE}/." "${MODS_DIR}/"
cp "${P14_CASE}/code/SIZE.h.serial" "${MODS_DIR}/SIZE.h"
cp "${P14_CASE}/code/packages.conf" "${MODS_DIR}/packages.conf"
(
  cd "${BUILD_DIR}"
  "${REPO_ROOT}/tools/genmake2" \
    "-rootdir=${REPO_ROOT}" \
    "-mods=${MODS_DIR}" \
    "-of=${OPTFILE}" -ieee -devel > genmake.log 2>&1
  make depend > build.log 2>&1
  make -j "${MAKE_JOBS}" >> build.log 2>&1
)
[[ -x "${BUILD_DIR}/mitgcmuv" ]] || fail 'missing serial executable'
nm "${BUILD_DIR}/mitgcmuv" > "${BUILD_DIR}/symbols.txt"
for symbol in bom_init_output_schedule_ bom_output_ bom_write_trajectory_; do
  grep -q "${symbol}" "${BUILD_DIR}/symbols.txt" \
    || fail "missing production output symbol: ${symbol}"
done
record_pass build-output-serial 'GNU debug/IEEE build; production output symbols'

prepare_run() {
  local run_name="$1"
  local bom_input="$2"
  local end_time="$3"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${P14_CASE}/input/data.cartesian" "${run_dir}/data"
  cp "${P14_CASE}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${P14_CASE}/input/eedata" "${run_dir}/eedata"
  cp "${bom_input}" "${run_dir}/data.bom"
  sed -i \
    -e "s/endTime=0\./endTime=${end_time}./" \
    -e 's/deltaTmom=1200\./deltaTmom=60./' \
    -e 's/deltaTtracer=1200\./deltaTtracer=60./' \
    -e 's/deltaTClock=1200\./deltaTClock=60./' \
    -e "s/the_run_name='[^']*'/the_run_name='${run_name}'/" \
    "${run_dir}/data"
  python3 "${P11_CASE}/make_initial.py" valid \
    "${run_dir}/bom_particles"
  ln -s "${BUILD_DIR}/mitgcmuv" "${run_dir}/mitgcmuv"
}

assert_normal() {
  local log_file="$1"
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" \
    || fail "normal-end marker missing: ${log_file}"
  if grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE|fatal error' "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

run_positive() {
  local run_name="$1"
  local bom_input="$2"
  local end_time="$3"
  local run_dir="${RUN_ROOT}/${run_name}"

  log "run ${run_name}"
  prepare_run "${run_name}" "${bom_input}" "${end_time}"
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  assert_normal "${run_dir}/run.log"
}

run_positive o02-nonintegral "${CASE_DIR}/input/data.bom.output" 480
python3 "${CASE_DIR}/verify_trajectory.py" \
  "${RUN_ROOT}/o02-nonintegral" \
  "${RUN_ROOT}/o02-nonintegral/canonical.tsv" \
  > "${RUN_ROOT}/o02-nonintegral/verify.log"
grep -q 'P1.5 TRAJECTORY VERIFY PASS' \
  "${RUN_ROOT}/o02-nonintegral/verify.log" \
  || fail 'trajectory verifier PASS marker missing'
[[ "$(grep -c 'BOM_WRITE_TRAJECTORY: suffix=' \
     "${RUN_ROOT}/o02-nonintegral/run.log")" -eq 3 ]] \
  || fail 'expected exactly three writer completion markers'
record_pass p1-o02-nonintegral \
  'sample=180/300/480; scheduled=150/300/450; next=600; schema 1'

run_positive o02-disabled "${CASE_DIR}/input/data.bom.output-off" 480
if find "${RUN_ROOT}/o02-disabled" -maxdepth 1 \
     -name 'bom_traj*' -print -quit | grep -q .; then
  fail 'disabled output created trajectory files'
fi
record_pass p1-o02-disabled 'bomOutputFreq=0; normal run; no trajectory files'

log 'run expected failure output frequency below ocean step'
prepare_run n-output-too-fast \
  "${CASE_DIR}/input/data.bom.output-too-fast" 0
set +e
(
  cd "${RUN_ROOT}/n-output-too-fast"
  ./mitgcmuv > run.log 2>&1
)
negative_status=$?
set -e
grep -q 'BOM_CHECK: output frequency below ocean step=' \
  "${RUN_ROOT}/n-output-too-fast/run.log" \
  || fail 'too-fast output diagnostic missing'
grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE' \
  "${RUN_ROOT}/n-output-too-fast/run.log" \
  || fail 'too-fast output fatal marker missing'
if grep -q 'PROGRAM MAIN: Execution ended Normally' \
     "${RUN_ROOT}/n-output-too-fast/run.log"; then
  fail 'too-fast output case ended normally'
fi
record_pass n-output-too-fast \
  "30 s output rejected below 60 s ocean step; status=${negative_status}"

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${ARTIFACT_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${ARTIFACT_ROOT}/git-status.txt"
{
  printf 'utc='; date -u +%Y-%m-%dT%H:%M:%SZ
  printf 'uname='; uname -a
  printf 'branch='; git -C "${REPO_ROOT}" branch --show-current
  printf 'gfortran='; gfortran --version | sed -n '1p'
  printf 'optfile_sha256='; sha256sum "${OPTFILE}"
  printf 'make_jobs=%s\n' "${MAKE_JOBS}"
  printf 'require_clean=%s\n' "${REQUIRE_CLEAN}"
} > "${ARTIFACT_ROOT}/environment.txt"
(
  cd "${REPO_ROOT}"
  find verification/bom/phase01-output-pickup-coexistence/input \
       -type f -print0 | sort -z | xargs -0 sha256sum
  sha256sum verification/bom/phase01-output-pickup-coexistence/verify_trajectory.py
) > "${ARTIFACT_ROOT}/config.sha256"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum config.sha256 environment.txt git-status.txt \
    source-head.txt summary.tsv > manifest.sha256
)

pass_count="$(grep -c $'\tPASS\t' "${RUN_ROOT}/summary.tsv")"
[[ "${pass_count}" -eq 5 ]] \
  || fail "expected 5 PASS rows, found ${pass_count}"
log 'P1.5 OUTPUT GATE PASS (5/5)'
log "source head:    $(cat "${ARTIFACT_ROOT}/source-head.txt")"
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
