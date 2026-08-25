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

for command_name in bash cmp date find git gfortran grep make mpif77 \
                    mpirun mv nm python3 rg sed sha256sum shellcheck \
                    sort uname xargs; do
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
PYTHONPYCACHEPREFIX="${RUN_ROOT}/pycache" \
  python3 -m py_compile "${CASE_DIR}/verify_pickup.py"
PYTHONPYCACHEPREFIX="${RUN_ROOT}/pycache" \
  python3 -m py_compile "${CASE_DIR}/mutate_pickup.py"
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
for symbol in bom_init_output_schedule_ bom_output_ bom_write_trajectory_ \
              bom_write_pickup_ bom_read_pickup_; do
  grep -q "${symbol}" "${BUILD_DIR}/symbols.txt" \
    || fail "missing production output symbol: ${symbol}"
done
record_pass build-output-serial 'GNU debug/IEEE build; production output symbols'

build_mpi_output_case() {
  local case_name="$1"
  local size_file="$2"
  local build_dir="${BUILD_ROOT}/${case_name}"
  local mods_dir="${BUILD_ROOT}/${case_name}-mods"
  local symbol

  log "build production ${case_name} output case"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${size_file}" "${mods_dir}/SIZE.h"
  cp "${P14_CASE}/code/packages.conf" "${mods_dir}/packages.conf"
  (
    cd "${build_dir}"
    "${REPO_ROOT}/tools/genmake2" \
      "-rootdir=${REPO_ROOT}" \
      "-mods=${mods_dir}" \
      "-of=${OPTFILE}" -mpi -ieee -devel > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] \
    || fail "missing ${case_name} executable"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_particle_exchange_ bom_init_output_schedule_ \
                bom_output_ bom_write_trajectory_ bom_write_pickup_ \
                bom_read_pickup_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing production MPI symbol ${symbol}: ${case_name}"
  done
  record_pass "build-output-${case_name}" \
    'GNU MPI debug/IEEE build; migration/output/pickup symbols'
}

build_mpi_output_case mpi2 "${P14_CASE}/code/SIZE.h.mpi2"
build_mpi_output_case mpi4 "${P14_CASE}/code/SIZE.h.mpi4"

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

collect_mpi_logs() {
  local run_dir="$1"
  local combined_log="$2"
  local ranks="$3"
  local rank
  local rank_log

  : > "${combined_log}"
  if [[ -f "${run_dir}/mpi-launch.log" ]]; then
    cat "${run_dir}/mpi-launch.log" >> "${combined_log}"
  fi
  for ((rank=0; rank<ranks; rank++)); do
    printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
    if [[ -f "${rank_log}" ]]; then
      cat "${rank_log}" >> "${combined_log}"
    fi
    printf -v rank_log '%s/STDERR.%04d' "${run_dir}" "${rank}"
    if [[ -f "${rank_log}" ]]; then
      cat "${rank_log}" >> "${combined_log}"
    fi
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

prepare_mpi_run() {
  local run_name="$1"
  local build_name="$2"
  local bom_input="$3"
  local end_time="$4"
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
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" \
    "${run_dir}/mitgcmuv"
}

run_mpi_positive() {
  local run_name="$1"
  local build_name="$2"
  local ranks="$3"
  local end_time="$4"
  local permanent_frequency="${5:-0}"
  local run_dir="${RUN_ROOT}/${run_name}"

  log "run ${run_name}"
  prepare_mpi_run "${run_name}" "${build_name}" \
    "${CASE_DIR}/input/data.bom.output" "${end_time}"
  if [[ "${permanent_frequency}" != 0 ]]; then
    sed -i "s/pChkptFreq=0\./pChkptFreq=${permanent_frequency}./" \
      "${run_dir}/data"
  fi
  (
    cd "${run_dir}"
    mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
  )
  collect_mpi_logs "${run_dir}" "${run_dir}/combined.log" "${ranks}"
  assert_mpi_normal "${run_dir}" "${ranks}"
}

run_positive() {
  local run_name="$1"
  local bom_input="$2"
  local end_time="$3"
  local permanent_frequency="${4:-0}"
  local run_dir="${RUN_ROOT}/${run_name}"

  log "run ${run_name}"
  prepare_run "${run_name}" "${bom_input}" "${end_time}"
  if [[ "${permanent_frequency}" != 0 ]]; then
    sed -i "s/pChkptFreq=0\./pChkptFreq=${permanent_frequency}./" \
      "${run_dir}/data"
  fi
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
  --invariant-output "${RUN_ROOT}/o02-nonintegral/invariant.tsv" \
  > "${RUN_ROOT}/o02-nonintegral/verify.log"
grep -q 'P1.5 TRAJECTORY VERIFY PASS' \
  "${RUN_ROOT}/o02-nonintegral/verify.log" \
  || fail 'trajectory verifier PASS marker missing'
[[ "$(grep -c 'BOM_WRITE_TRAJECTORY: suffix=' \
     "${RUN_ROOT}/o02-nonintegral/run.log")" -eq 3 ]] \
  || fail 'expected exactly three writer completion markers'
record_pass p1-o02-nonintegral \
  'sample=180/300/480; scheduled=150/300/450; next=600; schema 1'

python3 "${CASE_DIR}/verify_pickup.py" \
  "${RUN_ROOT}/o02-nonintegral" ckptA 8 480 150 600 \
  "${RUN_ROOT}/o02-nonintegral/pickup-canonical.tsv" \
  --invariant-output \
  "${RUN_ROOT}/o02-nonintegral/pickup-invariant.tsv" \
  > "${RUN_ROOT}/o02-nonintegral/pickup-verify.log"
grep -q 'P1.5 PICKUP VERIFY PASS' \
  "${RUN_ROOT}/o02-nonintegral/pickup-verify.log" \
  || fail 'continuous pickup verifier PASS marker missing'
record_pass p1-pickup-writer \
  'core ckptA suffix; 16-field signature; four 24-field owner tiles'

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

run_positive p01-split "${CASE_DIR}/input/data.bom.output" 300 300
python3 "${CASE_DIR}/verify_pickup.py" \
  "${RUN_ROOT}/p01-split" 0000000005 5 300 150 450 \
  "${RUN_ROOT}/p01-split/pickup-0000000005-canonical.tsv" \
  > "${RUN_ROOT}/p01-split/pickup-0000000005-verify.log"
grep -q 'P1.5 PICKUP VERIFY PASS' \
  "${RUN_ROOT}/p01-split/pickup-0000000005-verify.log" \
  || fail 'segment pickup verifier PASS marker missing'
record_pass p1-p01-segment \
  'iteration 5 permanent core+BOM pickup; big ID and WAITING state exact'

cp "${RUN_ROOT}/p01-split/data" "${RUN_ROOT}/p01-split/data.segment"
sed -i \
  -e 's/nIter0=0,/nIter0=5,/' \
  -e '/nIter0=5,/a\ startTime=300.,' \
  -e 's/endTime=300\./endTime=480./' \
  "${RUN_ROOT}/p01-split/data"
(
  cd "${RUN_ROOT}/p01-split"
  ./mitgcmuv > restart.log 2>&1
)
assert_normal "${RUN_ROOT}/p01-split/restart.log"
grep -q 'BOM_READ_PICKUP: complete suffix=0000000005' \
  "${RUN_ROOT}/p01-split/restart.log" \
  || fail 'restart reader completion marker missing'
python3 "${CASE_DIR}/verify_trajectory.py" \
  "${RUN_ROOT}/p01-split" \
  "${RUN_ROOT}/p01-split/canonical.tsv" \
  > "${RUN_ROOT}/p01-split/trajectory-verify.log"
python3 "${CASE_DIR}/verify_pickup.py" \
  "${RUN_ROOT}/p01-split" ckptA 8 480 150 600 \
  "${RUN_ROOT}/p01-split/pickup-canonical.tsv" \
  > "${RUN_ROOT}/p01-split/pickup-verify.log"
cmp -s "${RUN_ROOT}/o02-nonintegral/canonical.tsv" \
       "${RUN_ROOT}/p01-split/canonical.tsv" \
  || fail 'continuous and split trajectory records differ'
cmp -s "${RUN_ROOT}/o02-nonintegral/pickup-canonical.tsv" \
       "${RUN_ROOT}/p01-split/pickup-canonical.tsv" \
  || fail 'continuous and split final BOM pickup records differ'
record_pass p1-p01-restart \
  '5+3 split equals continuous trajectory, final state, and next time bitwise'

prepare_negative_restart() {
  local run_name="$1"
  local run_dir="${RUN_ROOT}/${run_name}"

  mkdir -p "${run_dir}"
  cp "${RUN_ROOT}/p01-split/data" "${run_dir}/data"
  cp "${RUN_ROOT}/p01-split/data.pkg" "${run_dir}/data.pkg"
  cp "${RUN_ROOT}/p01-split/data.bom" "${run_dir}/data.bom"
  cp "${RUN_ROOT}/p01-split/eedata" "${run_dir}/eedata"
  cp "${RUN_ROOT}/p01-split"/pickup.0000000005* "${run_dir}/"
  cp "${RUN_ROOT}/p01-split"/pickup_bom.0000000005* "${run_dir}/"
  sed -i 's/endTime=480\./endTime=300./' "${run_dir}/data"
  ln -s "${BUILD_DIR}/mitgcmuv" "${run_dir}/mitgcmuv"
}

run_pickup_negative() {
  local run_name="$1"
  local mutation="$2"
  local expected_text="$3"
  local run_dir="${RUN_ROOT}/${run_name}"
  local status

  log "run expected pickup failure ${run_name}"
  prepare_negative_restart "${run_name}"
  if [[ "${mutation}" == missing-tile ]]; then
    mv "${run_dir}/pickup_bom.0000000005.002.002.data" \
       "${run_dir}/pickup_bom.0000000005.002.002.data.missing"
  else
    python3 "${CASE_DIR}/mutate_pickup.py" \
      "${run_dir}" 0000000005 "${mutation}"
  fi
  set +e
  (
    cd "${run_dir}"
    ./mitgcmuv > run.log 2>&1
  )
  status=$?
  set -e
  grep -q "${expected_text}" "${run_dir}/run.log" \
    || fail "expected pickup diagnostic missing: ${run_name}"
  grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE' "${run_dir}/run.log" \
    || fail "pickup fatal marker missing: ${run_name}"
  if grep -q 'PROGRAM MAIN: Execution ended Normally' "${run_dir}/run.log"; then
    fail "negative pickup case ended normally: ${run_name}"
  fi
  record_pass "${run_name}" \
    "transaction rejected before owner commit; status=${status}"
}

run_pickup_negative p1-p03-signature signature-npx \
  'BOM_READ_PICKUP: signature mismatch suffix='
if grep -q 'BOM_READ_PICKUP: tiled preflight' \
     "${RUN_ROOT}/p1-p03-signature/run.log"; then
  fail 'decomposition mismatch reached tiled preflight'
fi
run_pickup_negative p1-n09-time signature-time \
  'BOM_READ_PICKUP: signature mismatch suffix='
run_pickup_negative p1-n09-missing missing-tile \
  'BOM_READ_PICKUP: tiled preflight failed suffix='
run_pickup_negative p1-n09-schema tile-schema \
  'BOM_READ_PICKUP: scratch validation failed suffix='
run_pickup_negative p1-n09-duplicate duplicate-id \
  'BOM_READ_PICKUP: scratch validation failed suffix='

verify_parallel_layout() {
  local layout="$1"
  local ranks="$2"
  local npx="$3"
  local npy="$4"
  local nsx="$5"
  local nsy="$6"
  local continuous="p01-continuous-${layout}"
  local split="p01-split-${layout}"
  local run_dir="${RUN_ROOT}/${split}"
  local log_file
  local -a layout_args=(
    --npx "${npx}" --npy "${npy}" --nsx "${nsx}" --nsy "${nsy}"
  )

  run_mpi_positive "${continuous}" "${layout}" "${ranks}" 480
  python3 "${CASE_DIR}/verify_trajectory.py" \
    "${RUN_ROOT}/${continuous}" \
    "${RUN_ROOT}/${continuous}/canonical.tsv" \
    "${layout_args[@]}" \
    --invariant-output "${RUN_ROOT}/${continuous}/invariant.tsv" \
    > "${RUN_ROOT}/${continuous}/trajectory-verify.log"
  python3 "${CASE_DIR}/verify_pickup.py" \
    "${RUN_ROOT}/${continuous}" ckptA 8 480 150 600 \
    "${RUN_ROOT}/${continuous}/pickup-canonical.tsv" \
    "${layout_args[@]}" \
    --invariant-output "${RUN_ROOT}/${continuous}/pickup-invariant.tsv" \
    > "${RUN_ROOT}/${continuous}/pickup-verify.log"
  grep -q 'P1.5 TRAJECTORY VERIFY PASS' \
    "${RUN_ROOT}/${continuous}/trajectory-verify.log" \
    || fail "${layout} continuous trajectory verifier marker missing"
  grep -q 'P1.5 PICKUP VERIFY PASS' \
    "${RUN_ROOT}/${continuous}/pickup-verify.log" \
    || fail "${layout} continuous pickup verifier marker missing"
  record_pass "p1-p01-${layout}-continuous" \
    '8 steps; layout-aware trajectory and final pickup verified'

  run_mpi_positive "${split}" "${layout}" "${ranks}" 300 300
  python3 "${CASE_DIR}/verify_pickup.py" \
    "${run_dir}" 0000000005 5 300 150 450 \
    "${run_dir}/pickup-0000000005-canonical.tsv" \
    "${layout_args[@]}" \
    > "${run_dir}/pickup-0000000005-verify.log"
  grep -q 'P1.5 PICKUP VERIFY PASS' \
    "${run_dir}/pickup-0000000005-verify.log" \
    || fail "${layout} segment pickup verifier marker missing"
  record_pass "p1-p01-${layout}-segment" \
    'iteration 5 permanent core+BOM pickup verified'

  cp "${run_dir}/data" "${run_dir}/data.segment"
  sed -i \
    -e 's/nIter0=0,/nIter0=5,/' \
    -e '/nIter0=5,/a\ startTime=300.,' \
    -e 's/endTime=300\./endTime=480./' \
    "${run_dir}/data"
  mkdir "${run_dir}/segment-logs"
  for log_file in "${run_dir}"/STDOUT.* "${run_dir}"/STDERR.* \
                  "${run_dir}/mpi-launch.log"; do
    [[ -e "${log_file}" ]] || continue
    mv "${log_file}" "${run_dir}/segment-logs/"
  done
  (
    cd "${run_dir}"
    mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1
  )
  collect_mpi_logs "${run_dir}" "${run_dir}/restart-combined.log" \
    "${ranks}"
  assert_mpi_normal "${run_dir}" "${ranks}"
  grep -q 'BOM_READ_PICKUP: complete suffix=0000000005' \
    "${run_dir}/restart-combined.log" \
    || fail "${layout} restart reader completion marker missing"
  python3 "${CASE_DIR}/verify_trajectory.py" \
    "${run_dir}" "${run_dir}/canonical.tsv" \
    "${layout_args[@]}" \
    --invariant-output "${run_dir}/invariant.tsv" \
    > "${run_dir}/trajectory-verify.log"
  python3 "${CASE_DIR}/verify_pickup.py" \
    "${run_dir}" ckptA 8 480 150 600 \
    "${run_dir}/pickup-canonical.tsv" \
    "${layout_args[@]}" \
    --invariant-output "${run_dir}/pickup-invariant.tsv" \
    > "${run_dir}/pickup-verify.log"
  cmp -s "${RUN_ROOT}/${continuous}/canonical.tsv" \
         "${run_dir}/canonical.tsv" \
    || fail "${layout} continuous/split trajectory mismatch"
  cmp -s "${RUN_ROOT}/${continuous}/pickup-canonical.tsv" \
         "${run_dir}/pickup-canonical.tsv" \
    || fail "${layout} continuous/split final pickup mismatch"
  record_pass "p1-p01-${layout}-restart" \
    '5+3 equals continuous trajectory, owner state, and next time bitwise'
}

verify_parallel_layout mpi2 2 2 1 1 2
verify_parallel_layout mpi4 4 2 2 1 1

cmp -s "${RUN_ROOT}/o02-nonintegral/invariant.tsv" \
       "${RUN_ROOT}/p01-continuous-mpi2/invariant.tsv" \
  || fail 'serial/MPI2 decomposition-invariant trajectory mismatch'
cmp -s "${RUN_ROOT}/o02-nonintegral/invariant.tsv" \
       "${RUN_ROOT}/p01-continuous-mpi4/invariant.tsv" \
  || fail 'serial/MPI4 decomposition-invariant trajectory mismatch'
record_pass p1-o01-layout-invariant \
  'serial/MPI2/MPI4 physical trajectory fields bitwise identical'

cmp -s "${RUN_ROOT}/o02-nonintegral/pickup-invariant.tsv" \
       "${RUN_ROOT}/p01-continuous-mpi2/pickup-invariant.tsv" \
  || fail 'serial/MPI2 decomposition-invariant pickup mismatch'
cmp -s "${RUN_ROOT}/o02-nonintegral/pickup-invariant.tsv" \
       "${RUN_ROOT}/p01-continuous-mpi4/pickup-invariant.tsv" \
  || fail 'serial/MPI4 decomposition-invariant pickup mismatch'
record_pass p1-p02-layout-invariant \
  'serial/MPI2/MPI4 physical pickup state bitwise identical'
record_pass p1-p02-mpi4 \
  'big ID, WAITING status, owner fields, diagnostics, and next time verified'

log 'run expected MPI2-to-MPI4 pickup decomposition failure'
readonly P03_RUN_DIR="${RUN_ROOT}/p1-p03-mpi2-to-mpi4"
mkdir -p "${P03_RUN_DIR}"
cp "${RUN_ROOT}/p01-split-mpi2/data" "${P03_RUN_DIR}/data"
cp "${RUN_ROOT}/p01-split-mpi2/data.pkg" "${P03_RUN_DIR}/data.pkg"
cp "${RUN_ROOT}/p01-split-mpi2/data.bom" "${P03_RUN_DIR}/data.bom"
cp "${RUN_ROOT}/p01-split-mpi2/eedata" "${P03_RUN_DIR}/eedata"
cp "${RUN_ROOT}/p01-split-mpi2"/pickup.0000000005* "${P03_RUN_DIR}/"
cp "${RUN_ROOT}/p01-split-mpi2"/pickup_bom.0000000005* \
  "${P03_RUN_DIR}/"
sed -i 's/endTime=480\./endTime=300./' "${P03_RUN_DIR}/data"
ln -s "${BUILD_ROOT}/mpi4/mitgcmuv" "${P03_RUN_DIR}/mitgcmuv"
set +e
(
  cd "${P03_RUN_DIR}"
  mpirun -np 4 ./mitgcmuv > mpi-launch.log 2>&1
)
p03_status=$?
set -e
collect_mpi_logs "${P03_RUN_DIR}" "${P03_RUN_DIR}/combined.log" 4
grep -q 'BOM_READ_PICKUP: signature mismatch suffix=' \
  "${P03_RUN_DIR}/combined.log" \
  || fail 'MPI2-to-MPI4 signature mismatch diagnostic missing'
grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE' "${P03_RUN_DIR}/combined.log" \
  || fail 'MPI2-to-MPI4 fatal marker missing'
if grep -q 'BOM_READ_PICKUP: tiled preflight' \
     "${P03_RUN_DIR}/combined.log"; then
  fail 'MPI2-to-MPI4 mismatch reached tiled BOM preflight'
fi
record_pass p1-p03-mpi2-to-mpi4 \
  "signature rejected before tiled BOM read; status=${p03_status}"

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
  find verification/bom/phase01-output-pickup-coexistence/input \
       -type f -print0 | sort -z | xargs -0 sha256sum
  sha256sum verification/bom/phase01-output-pickup-coexistence/verify_trajectory.py
  sha256sum verification/bom/phase01-output-pickup-coexistence/verify_pickup.py
  sha256sum verification/bom/phase01-output-pickup-coexistence/mutate_pickup.py
) > "${ARTIFACT_ROOT}/config.sha256"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum config.sha256 environment.txt git-status.txt \
    source-head.txt summary.tsv > manifest.sha256
)

pass_count="$(grep -c $'\tPASS\t' "${RUN_ROOT}/summary.tsv")"
[[ "${pass_count}" -eq 25 ]] \
  || fail "expected 25 PASS rows, found ${pass_count}"
log 'P1.5 OUTPUT/PICKUP GATE PASS (25/25)'
log "source head:    $(cat "${ARTIFACT_ROOT}/source-head.txt")"
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
