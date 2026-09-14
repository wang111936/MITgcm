#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p56-archive-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase05-trajectory-archive}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase05-trajectory-archive}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/p56-archive}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly P11_CASE="${REPO_ROOT}/verification/bom/phase01-bom-lite"
readonly P14_CASE="${REPO_ROOT}/verification/bom/phase01-owner-migration"
readonly P25_CASE="${REPO_ROOT}/verification/bom/phase02-integration-closure"

fail() { printf 'P5.6 ARCHIVE GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P5.6-archive] %s\n' "$*"; }
pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

for command_name in bash cmp date find git grep make mpirun nm python3 sed \
                    sha256sum shellcheck sort; do
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
for root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${root}" ]] || fail "evidence root already exists: ${root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${RUN_ROOT}/pycache" \
  python3 -m py_compile \
    "${CASE_DIR}/verify_archive.py" "${CASE_DIR}/inject_orphan_tail.py"

grep -Fq "bomTrajectoryMode.EQ.'ARCHIVE'" \
  "${REPO_ROOT}/pkg/bom/bom_output.F" \
  || fail 'ARCHIVE dispatch is missing'
grep -Fq 'PARAMETER ( bomArchiveFields = 64 )' \
  "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
  || fail '64-field archive schema is not frozen'
grep -Fq 'CALL BOM_WRITE_TRAJECTORY_ARCHIVE' \
  "${REPO_ROOT}/pkg/bom/bom_output.F" \
  || fail 'archive writer hook is missing'
grep -Fq "STATUS='NEW'" \
  "${REPO_ROOT}/pkg/bom/bom_write_trajectory_archive.F" \
  || fail 'atomic segment claim is missing'
pass source-contract 'explicit dispatch; 64-field owner; atomic claim; index commit'

log 'build production serial debug/IEEE executable'
mkdir -p "${BUILD_ROOT}/build" "${BUILD_ROOT}/mods"
cp -a "${EXP2_CODE}/." "${BUILD_ROOT}/mods/"
cp "${P14_CASE}/code/SIZE.h.serial" "${BUILD_ROOT}/mods/SIZE.h"
cp "${P14_CASE}/code/packages.conf" "${BUILD_ROOT}/mods/packages.conf"
(
  cd "${BUILD_ROOT}/build"
  "${REPO_ROOT}/tools/genmake2" \
    "-rootdir=${REPO_ROOT}" "-mods=${BUILD_ROOT}/mods" \
    "-of=${OPTFILE}" -ieee -devel > genmake.log 2>&1
  make depend > build.log 2>&1
  make -j "${MAKE_JOBS}" >> build.log 2>&1
)
[[ -x "${BUILD_ROOT}/build/mitgcmuv" ]] || fail 'missing executable'
nm "${BUILD_ROOT}/build/mitgcmuv" > "${BUILD_ROOT}/build/symbols.txt"
grep -q 'bom_write_trajectory_archive_' "${BUILD_ROOT}/build/symbols.txt" \
  || fail 'archive writer is not linked'
pass build-serial 'GNU debug/IEEE build; archive writer linked'

log 'build production MPI-2 debug/IEEE executable'
mkdir -p "${BUILD_ROOT}/mpi2-build" "${BUILD_ROOT}/mpi2-mods"
cp -a "${EXP2_CODE}/." "${BUILD_ROOT}/mpi2-mods/"
cp "${P14_CASE}/code/SIZE.h.mpi2" "${BUILD_ROOT}/mpi2-mods/SIZE.h"
cp "${P14_CASE}/code/packages.conf" "${BUILD_ROOT}/mpi2-mods/packages.conf"
(
  cd "${BUILD_ROOT}/mpi2-build"
  "${REPO_ROOT}/tools/genmake2" \
    "-rootdir=${REPO_ROOT}" "-mods=${BUILD_ROOT}/mpi2-mods" \
    "-of=${OPTFILE}" -ieee -devel -mpi > genmake.log 2>&1
  make depend > build.log 2>&1
  make -j "${MAKE_JOBS}" >> build.log 2>&1
)
[[ -x "${BUILD_ROOT}/mpi2-build/mitgcmuv" ]] || fail 'missing MPI-2 executable'
nm "${BUILD_ROOT}/mpi2-build/mitgcmuv" > "${BUILD_ROOT}/mpi2-build/symbols.txt"
grep -q 'bom_write_trajectory_archive_' "${BUILD_ROOT}/mpi2-build/symbols.txt" \
  || fail 'archive writer is not linked in MPI-2 build'
pass build-mpi2 'GNU MPI-2 debug/IEEE build; archive writer linked'

prepare_run() {
  local name="$1" mode="$2" end_time="$3"
  local executable="${4:-${BUILD_ROOT}/build/mitgcmuv}"
  local run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${P14_CASE}/input/data.cartesian" "${run_dir}/data"
  cp "${P14_CASE}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${P14_CASE}/input/eedata" "${run_dir}/eedata"
  cp "${P25_CASE}/input/data.bom" "${run_dir}/data.bom"
  sed -i \
    -e "s/endTime=0\./endTime=${end_time}./" \
    -e 's/deltaTmom=1200\./deltaTmom=60./' \
    -e 's/deltaTtracer=1200\./deltaTtracer=60./' \
    -e 's/deltaTClock=1200\./deltaTClock=60./' \
    -e "s/the_run_name='[^']*'/the_run_name='${name}'/" \
    "${run_dir}/data"
  sed -i "/bomInitialFile=/a\\ bomTrajectoryMode='${mode}',\\n bomTrajectoryFile='bom_trajectories'," \
    "${run_dir}/data.bom"
  python3 "${P11_CASE}/make_initial.py" valid "${run_dir}/bom_particles"
  ln -s "${executable}" "${run_dir}/mitgcmuv"
}

collect_logs() {
  local run_dir="$1" ranks="$2" output="$3" rank rank_file
  : > "${output}"
  [[ ! -f "${run_dir}/mpi-launch.log" ]] \
    || cat "${run_dir}/mpi-launch.log" >> "${output}"
  for ((rank=0; rank<ranks; rank++)); do
    printf -v rank_file '%s/STDOUT.%04d' "${run_dir}" "${rank}"
    [[ ! -f "${rank_file}" ]] || cat "${rank_file}" >> "${output}"
    printf -v rank_file '%s/STDERR.%04d' "${run_dir}" "${rank}"
    [[ ! -f "${rank_file}" ]] || cat "${rank_file}" >> "${output}"
  done
}

run_normal() {
  local name="$1" run_dir="${RUN_ROOT}/$1"
  log "run ${name}"
  (cd "${run_dir}"; ./mitgcmuv > run.log 2>&1)
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${run_dir}/run.log" \
    || fail "normal-end marker missing: ${name}"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${run_dir}/run.log"; then
    fail "fatal marker found: ${name}"
  fi
}

prepare_run frame3 FRAME 480
prepare_run archive1 ARCHIVE 180
prepare_run archive3 ARCHIVE 480
run_normal frame3
run_normal archive1
run_normal archive3

python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/archive1" \
  --expected-frames 1 --expected-files 11 --require-no-orphans \
  > "${RUN_ROOT}/archive1/verify.log"
python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/archive3" \
  --expected-frames 3 --expected-files 11 --require-no-orphans \
  --frame-dir "${RUN_ROOT}/frame3" \
  > "${RUN_ROOT}/archive3/verify.log"
grep -q 'P5.6 ARCHIVE VERIFY PASS' "${RUN_ROOT}/archive1/verify.log" \
  || fail 'one-frame verifier marker missing'
grep -q 'P5.6 ARCHIVE VERIFY PASS' "${RUN_ROOT}/archive3/verify.log" \
  || fail 'three-frame verifier marker missing'
pass serial-append 'one and three frames both use exactly 11 files'
pass frame-equivalence 'all 64 owner words match normalized legacy FRAME output'
pass atomic-claim 'one persistent STATUS=NEW segment claim is present'

find "${RUN_ROOT}/archive1" -maxdepth 1 -type f \
  -name 'bom_trajectories*' -print0 | sort -z | xargs -0 sha256sum \
  > "${RUN_ROOT}/archive1/before-rerun.sha256"
set +e
(cd "${RUN_ROOT}/archive1"; ./mitgcmuv > collision.log 2>&1)
set -e
grep -q 'preflight failed' "${RUN_ROOT}/archive1/collision.log" \
  || fail 'collision rejection marker missing'
if grep -q 'PROGRAM MAIN: Execution ended Normally' \
     "${RUN_ROOT}/archive1/collision.log"; then
  fail 'collision run reached the normal-end marker'
fi
find "${RUN_ROOT}/archive1" -maxdepth 1 -type f \
  -name 'bom_trajectories*' -print0 | sort -z | xargs -0 sha256sum \
  > "${RUN_ROOT}/archive1/after-rerun.sha256"
cmp -s "${RUN_ROOT}/archive1/before-rerun.sha256" \
       "${RUN_ROOT}/archive1/after-rerun.sha256" \
  || fail 'collision rejection changed an existing archive member'
pass collision-reject 'existing nIter0 segment rejected; member hashes unchanged'

cp -a "${RUN_ROOT}/archive3" "${RUN_ROOT}/orphan-tail"
python3 "${CASE_DIR}/inject_orphan_tail.py" "${RUN_ROOT}/orphan-tail" \
  > "${RUN_ROOT}/orphan-tail/inject.log"
python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/orphan-tail" \
  --expected-frames 3 --expected-files 11 --frame-dir "${RUN_ROOT}/frame3" \
  > "${RUN_ROOT}/orphan-tail/verify.log"
grep -Eq 'orphan_score=[1-9][0-9]*' "${RUN_ROOT}/orphan-tail/verify.log" \
  || fail 'orphan-tail verifier did not report ignored tail evidence'
if python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/orphan-tail" \
     --expected-frames 3 --expected-files 11 --require-no-orphans \
     > "${RUN_ROOT}/orphan-tail/strict.log" 2>&1; then
  fail 'strict orphan-tail verification unexpectedly passed'
fi
pass orphan-tail 'index commit remains authoritative; tile/index tails ignored'

prepare_run split ARCHIVE 300
sed -i 's/pChkptFreq=0\./pChkptFreq=300./' "${RUN_ROOT}/split/data"
run_normal split
[[ -f "${RUN_ROOT}/split/pickup_bom.0000000005.sig.data" ]] \
  || fail 'split stage did not write BOM pickup 0000000005'
find "${RUN_ROOT}/split" -maxdepth 1 -type f \
  -name 'bom_trajectories.s0000000000*' -print0 \
  | sort -z | xargs -0 sha256sum > "${RUN_ROOT}/split/segment0-before.sha256"
sed -i \
  -e 's/nIter0=0,/nIter0=5,/' \
  -e '/nIter0=5,/a\ startTime=300.,' \
  -e 's/endTime=300\./endTime=480./' \
  -e 's/pChkptFreq=300\./pChkptFreq=0./' \
  "${RUN_ROOT}/split/data"
log 'run split restart nIter0=5'
(cd "${RUN_ROOT}/split"; ./mitgcmuv > restart.log 2>&1)
grep -q 'PROGRAM MAIN: Execution ended Normally' "${RUN_ROOT}/split/restart.log" \
  || fail 'normal-end marker missing: split restart'
grep -q 'BOM_READ_PICKUP: complete suffix=0000000005' \
  "${RUN_ROOT}/split/restart.log" || fail 'BOM restart marker missing'
if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' \
     "${RUN_ROOT}/split/restart.log"; then
  fail 'fatal marker found: split restart'
fi
find "${RUN_ROOT}/split" -maxdepth 1 -type f \
  -name 'bom_trajectories.s0000000000*' -print0 \
  | sort -z | xargs -0 sha256sum > "${RUN_ROOT}/split/segment0-after.sha256"
cmp -s "${RUN_ROOT}/split/segment0-before.sha256" \
       "${RUN_ROOT}/split/segment0-after.sha256" \
  || fail 'restart changed the closed nIter0=0 segment'
python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/split" \
  --segment-iter 0 --expected-frames 2 --expected-files 11 \
  --require-no-orphans > "${RUN_ROOT}/split/segment0-verify.log"
python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/split" \
  --segment-iter 5 --expected-frames 1 --expected-files 11 \
  --require-no-orphans --frame-dir "${RUN_ROOT}/frame3" \
  > "${RUN_ROOT}/split/segment5-verify.log"
pass restart-segment '2+1 frames use two immutable 11-file nIter0 segments'

prepare_run mpi2 ARCHIVE 480 "${BUILD_ROOT}/mpi2-build/mitgcmuv"
log 'run MPI-2 archive'
(cd "${RUN_ROOT}/mpi2"; mpirun -np 2 ./mitgcmuv > mpi-launch.log 2>&1)
collect_logs "${RUN_ROOT}/mpi2" 2 "${RUN_ROOT}/mpi2/combined.log"
grep -q 'PROGRAM MAIN: Execution ended Normally' "${RUN_ROOT}/mpi2/combined.log" \
  || fail 'normal-end marker missing: MPI-2 archive'
if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' \
     "${RUN_ROOT}/mpi2/combined.log"; then
  fail 'fatal marker found: MPI-2 archive'
fi
python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/mpi2" \
  --expected-frames 3 --expected-files 11 --require-no-orphans \
  > "${RUN_ROOT}/mpi2/verify.log"
pass mpi2-append 'two ranks publish four tile streams and one ordered index'

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
cp "${RUN_ROOT}/archive1/verify.log" "${ARTIFACT_ROOT}/archive1-verify.log"
cp "${RUN_ROOT}/archive3/verify.log" "${ARTIFACT_ROOT}/archive3-verify.log"
cp "${RUN_ROOT}/orphan-tail/verify.log" "${ARTIFACT_ROOT}/orphan-tail-verify.log"
cp "${RUN_ROOT}/split/segment0-verify.log" "${ARTIFACT_ROOT}/split-segment0-verify.log"
cp "${RUN_ROOT}/split/segment5-verify.log" "${ARTIFACT_ROOT}/split-segment5-verify.log"
cp "${RUN_ROOT}/mpi2/verify.log" "${ARTIFACT_ROOT}/mpi2-verify.log"
printf 'P5.6 ARCHIVE GATE PASS: %s\n' "${TEST_ID}"
