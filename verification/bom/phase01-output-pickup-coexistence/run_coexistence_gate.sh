#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p15-coexistence-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase01-output-pickup-coexistence}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase01-output-pickup-coexistence}"
readonly ARTIFACT_PARENT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly ARTIFACT_ROOT="${ARTIFACT_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly EXP4="${REPO_ROOT}/verification/exp4"

fail() {
  printf 'P1.5 COEXISTENCE GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P1.5-coexistence] %s\n' "$*"
}

record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

for command_name in bash cmp date find git gfortran grep make mpif77 \
                    mpirun nm python3 rg sed sha256sum shellcheck sort \
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
  python3 -m py_compile "${CASE_DIR}/make_coexistence_bom.py"
PYTHONPYCACHEPREFIX="${RUN_ROOT}/pycache" \
  python3 -m py_compile "${CASE_DIR}/verify_coexistence_bom.py"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

grep -Fq 'IF (useFLT) THEN' "${REPO_ROOT}/model/src/forward_step.F" \
  || fail 'FLT forward-step guard missing'
grep -Fq 'IF (useBOM) THEN' "${REPO_ROOT}/model/src/forward_step.F" \
  || fail 'BOM forward-step guard missing'
grep -Fq 'IF (useFLT) THEN' "${REPO_ROOT}/model/src/packages_write_pickup.F" \
  || fail 'FLT pickup guard missing'
grep -Eq 'IF \([[:space:]]*useBOM[[:space:]]*\) THEN' \
  "${REPO_ROOT}/model/src/packages_write_pickup.F" \
  || fail 'BOM pickup guard missing'
if rg -n -i -g '*.F' -g '*.h' \
     'FLT\.h|FLT_SIZE\.h|FLT_BUFF\.h|npart_tile|ipart|float_trajectories|pickup_flt|CALL[[:space:]]+FLT_' \
     "${REPO_ROOT}/pkg/bom"; then
  fail 'FLT state/call/prefix leaked into BOM production sources'
fi
if rg -n -i -g '*.F' -g '*.h' \
     'BOM\.h|BOM_SIZE\.h|bom_traj|pickup_bom|CALL[[:space:]]+BOM_' \
     "${REPO_ROOT}/pkg/flt"; then
  fail 'BOM state/call/prefix leaked into FLT production sources'
fi
record_pass source-coexistence-contract \
  'independent guards, state, calls, COMMON blocks, and file prefixes'

build_case() {
  local layout="$1"
  local combination="$2"
  local size_file="$3"
  local mpi_enabled="$4"
  local with_flt="$5"
  local with_bom="$6"
  local case_name="${layout}-${combination}"
  local build_dir="${BUILD_ROOT}/${case_name}"
  local mods_dir="${BUILD_ROOT}/${case_name}-mods"
  local -a genmake_args

  log "build ${case_name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP4}/code/." "${mods_dir}/"
  cp "${size_file}" "${mods_dir}/SIZE.h"
  sed -i '/^flt$/d' "${mods_dir}/packages.conf"
  if [[ "${with_flt}" == yes ]]; then
    printf 'flt\n' >> "${mods_dir}/packages.conf"
  fi
  if [[ "${with_bom}" == yes ]]; then
    printf 'bom\n' >> "${mods_dir}/packages.conf"
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
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing ${case_name} executable"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  if [[ "${with_flt}" == yes ]]; then
    grep -q 'flt_main_' "${build_dir}/symbols.txt" \
      || fail "FLT symbol missing: ${case_name}"
    grep -q 'flt_write_pickup_' "${build_dir}/symbols.txt" \
      || fail "FLT pickup symbol missing: ${case_name}"
  elif grep -q 'flt_main_' "${build_dir}/symbols.txt"; then
    fail "FLT symbol present while disabled at build: ${case_name}"
  fi
  if [[ "${with_bom}" == yes ]]; then
    grep -q 'bom_main_' "${build_dir}/symbols.txt" \
      || fail "BOM symbol missing: ${case_name}"
    grep -q 'bom_write_pickup_' "${build_dir}/symbols.txt" \
      || fail "BOM pickup symbol missing: ${case_name}"
  elif grep -q 'bom_main_' "${build_dir}/symbols.txt"; then
    fail "BOM symbol present while disabled at build: ${case_name}"
  fi
  record_pass "build-${case_name}" \
    "FLT=${with_flt}; BOM=${with_bom}; independent link"
}

for layout in serial mpi2; do
  if [[ "${layout}" == serial ]]; then
    size_file="${EXP4}/code/SIZE.h"
    mpi_enabled=no
  else
    size_file="${CASE_DIR}/code/SIZE.h.exp4-mpi2"
    mpi_enabled=yes
  fi
  build_case "${layout}" neither "${size_file}" "${mpi_enabled}" no no
  build_case "${layout}" flt "${size_file}" "${mpi_enabled}" yes no
  build_case "${layout}" bom "${size_file}" "${mpi_enabled}" no yes
  build_case "${layout}" both "${size_file}" "${mpi_enabled}" yes yes
done

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

run_case() {
  local layout="$1"
  local combination="$2"
  local with_flt="$3"
  local with_bom="$4"
  local ranks=1
  local case_name="${layout}-${combination}"
  local run_dir="${RUN_ROOT}/${case_name}"
  local rank
  local rank_log

  [[ "${layout}" == serial ]] || ranks=2
  log "run ${case_name}"
  mkdir -p "${run_dir}"
  cp -a "${EXP4}/input.with_flt/." "${run_dir}/"
  sed -i \
    -e 's/nTimeSteps=18,/nTimeSteps=12,/' \
    -e '/nTimeSteps=12,/a\ pChkptFreq=7200.,' \
    "${run_dir}/data"
  if [[ "${with_flt}" == yes ]]; then
    sed -i 's/useFLT=.FALSE./useFLT=.TRUE./' "${run_dir}/data.pkg"
  else
    sed -i 's/useFLT=.TRUE./useFLT=.FALSE./' "${run_dir}/data.pkg"
  fi
  if [[ "${with_bom}" == yes ]]; then
    sed -i '/useFLT=/a\ useBOM=.TRUE.,' "${run_dir}/data.pkg"
  fi
  cp "${CASE_DIR}/input/data.bom.coexistence" "${run_dir}/data.bom"
  python3 "${CASE_DIR}/make_coexistence_bom.py" "${run_dir}" \
    > "${run_dir}/bom-input.log"
  ln -s "${BUILD_ROOT}/${case_name}/mitgcmuv" "${run_dir}/mitgcmuv"
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
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      assert_normal "${rank_log}"
    done
  fi
  record_pass "run-${case_name}" \
    "FLT=${with_flt}; BOM=${with_bom}; 12 steps; normal end"
}

for layout in serial mpi2; do
  run_case "${layout}" neither no no
  run_case "${layout}" flt yes no
  run_case "${layout}" bom no yes
  run_case "${layout}" both yes yes
done

has_files() {
  local run_dir="$1"
  local pattern="$2"
  find "${run_dir}" -maxdepth 1 -type f -name "${pattern}" \
    -print -quit | grep -q .
}

manifest_flt() {
  local run_dir="$1"
  local output="$2"
  (
    cd "${run_dir}"
    find . -maxdepth 1 -type f \
      \( -name 'float_trajectories*' -o -name 'float_profiles*' \
         -o -name 'pickup_flt*' \) \
      -print0 | sort -z | xargs -0 sha256sum
  ) > "${output}"
}

manifest_core() {
  local run_dir="$1"
  local output="$2"
  (
    cd "${run_dir}"
    find . -maxdepth 1 -type f -name 'pickup.0000000012*' \
      -print0 | sort -z | xargs -0 sha256sum
  ) > "${output}"
}

verify_bom_pair() {
  local layout="$1"
  local npx="$2"
  local npy="$3"
  local nsx="$4"
  local nsy="$5"
  local combination
  local run_dir

  for combination in bom both; do
    run_dir="${RUN_ROOT}/${layout}-${combination}"
    python3 "${CASE_DIR}/verify_coexistence_bom.py" \
      "${run_dir}" "${run_dir}/bom-trajectory.tsv" \
      "${run_dir}/bom-pickup.tsv" \
      --npx "${npx}" --npy "${npy}" --nsx "${nsx}" --nsy "${nsy}" \
      > "${run_dir}/bom-verify.log"
    grep -q 'P1.5 COEXISTENCE BOM VERIFY PASS' \
      "${run_dir}/bom-verify.log" \
      || fail "BOM coexistence verifier marker missing: ${layout}-${combination}"
  done
  cmp -s "${RUN_ROOT}/${layout}-bom/bom-trajectory.tsv" \
         "${RUN_ROOT}/${layout}-both/bom-trajectory.tsv" \
    || fail "BOM trajectory changed with FLT enabled: ${layout}"
  cmp -s "${RUN_ROOT}/${layout}-bom/bom-pickup.tsv" \
         "${RUN_ROOT}/${layout}-both/bom-pickup.tsv" \
    || fail "BOM pickup changed with FLT enabled: ${layout}"
  record_pass "p1-k02-bom-${layout}" \
    'BOM-only/BOM+FLT canonical trajectory and pickup bitwise identical'
}

for layout in serial mpi2; do
  for combination in neither flt bom both; do
    run_dir="${RUN_ROOT}/${layout}-${combination}"
    case "${combination}" in
      neither)
        has_files "${run_dir}" 'float_trajectories*' \
          && fail "FLT file in neither run: ${layout}"
        has_files "${run_dir}" 'pickup_flt*' \
          && fail "FLT pickup in neither run: ${layout}"
        has_files "${run_dir}" 'bom_traj*' \
          && fail "BOM file in neither run: ${layout}"
        has_files "${run_dir}" 'pickup_bom*' \
          && fail "BOM pickup in neither run: ${layout}"
        ;;
      flt)
        has_files "${run_dir}" 'float_trajectories*' \
          || fail "FLT trajectory missing: ${layout}"
        has_files "${run_dir}" 'pickup_flt*' \
          || fail "FLT pickup missing: ${layout}"
        has_files "${run_dir}" 'bom_traj*' \
          && fail "BOM trajectory in FLT-only run: ${layout}"
        ;;
      bom)
        has_files "${run_dir}" 'bom_traj*' \
          || fail "BOM trajectory missing: ${layout}"
        has_files "${run_dir}" 'pickup_bom.0000000012*' \
          || fail "BOM pickup missing: ${layout}"
        has_files "${run_dir}" 'float_trajectories*' \
          && fail "FLT trajectory in BOM-only run: ${layout}"
        ;;
      both)
        has_files "${run_dir}" 'float_trajectories*' \
          || fail "FLT trajectory missing in both run: ${layout}"
        has_files "${run_dir}" 'pickup_flt*' \
          || fail "FLT pickup missing in both run: ${layout}"
        has_files "${run_dir}" 'bom_traj*' \
          || fail "BOM trajectory missing in both run: ${layout}"
        has_files "${run_dir}" 'pickup_bom.0000000012*' \
          || fail "BOM pickup missing in both run: ${layout}"
        ;;
    esac
  done
  record_pass "p1-k01-files-${layout}" \
    'four runtime combinations create only enabled package files'

  for combination in neither flt bom both; do
    manifest_core "${RUN_ROOT}/${layout}-${combination}" \
      "${RUN_ROOT}/${layout}-${combination}/core.sha256"
    [[ -s "${RUN_ROOT}/${layout}-${combination}/core.sha256" ]] \
      || fail "core permanent pickup manifest empty: ${layout}-${combination}"
  done
  for combination in flt bom both; do
    cmp -s "${RUN_ROOT}/${layout}-neither/core.sha256" \
           "${RUN_ROOT}/${layout}-${combination}/core.sha256" \
      || fail "core pickup changed: ${layout}-${combination}"
  done
  record_pass "p1-k01-core-${layout}" \
    'neither/FLT/BOM/both core permanent pickup SHA-256 identical'

  manifest_flt "${RUN_ROOT}/${layout}-flt" \
    "${RUN_ROOT}/${layout}-flt/flt.sha256"
  manifest_flt "${RUN_ROOT}/${layout}-both" \
    "${RUN_ROOT}/${layout}-both/flt.sha256"
  [[ -s "${RUN_ROOT}/${layout}-flt/flt.sha256" ]] \
    || fail "FLT output manifest empty: ${layout}"
  cmp -s "${RUN_ROOT}/${layout}-flt/flt.sha256" \
         "${RUN_ROOT}/${layout}-both/flt.sha256" \
    || fail "FLT byte output changed with BOM enabled: ${layout}"
  record_pass "p1-k02-flt-${layout}" \
    'FLT-only/FLT+BOM trajectory and pickup files SHA-256 identical'
done

verify_bom_pair serial 1 1 2 2
verify_bom_pair mpi2 2 1 1 2

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
    verification/bom/phase01-output-pickup-coexistence/code/SIZE.h.exp4-mpi2 \
    verification/bom/phase01-output-pickup-coexistence/input/data.bom.coexistence \
    verification/bom/phase01-output-pickup-coexistence/make_coexistence_bom.py \
    verification/bom/phase01-output-pickup-coexistence/verify_coexistence_bom.py
) > "${ARTIFACT_ROOT}/config.sha256"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum config.sha256 environment.txt git-status.txt \
    source-head.txt summary.tsv > manifest.sha256
)

pass_count="$(grep -c $'\tPASS\t' "${RUN_ROOT}/summary.tsv")"
[[ "${pass_count}" -eq 25 ]] \
  || fail "expected 25 PASS rows, found ${pass_count}"
log 'P1.5 FLT/BOM COEXISTENCE GATE PASS (25/25)'
log "source head:    $(cat "${ARTIFACT_ROOT}/source-head.txt")"
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
