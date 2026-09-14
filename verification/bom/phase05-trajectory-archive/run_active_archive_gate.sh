#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly P34_CASE="${REPO_ROOT}/verification/bom/phase03-components-schema3"
readonly P44_CASE="${REPO_ROOT}/verification/bom/phase04-biology-land"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p56-active-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase05-trajectory-archive-active}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase05-trajectory-archive-active}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/p56-archive-active}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"

fail() { printf 'P5.6 ACTIVE ARCHIVE GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P5.6-active] %s\n' "$*"; }
pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

for command_name in bash cp date git grep make mpirun nm python3 rg sed \
                    shellcheck; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || fail "required command not found: ${command_name}"
done
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

build_p3() {
  local name="$1" size_file="$2" mpi_enabled="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  log "build ${name} P3 fixture"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${P34_CASE}/code/${size_file}" "${mods_dir}/SIZE.h"
  cp "${P34_CASE}/code/packages.conf" "${mods_dir}/"
  cp "${P34_CASE}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${P34_CASE}/code/bom_verify_components_schema3.F" "${mods_dir}/"
  cp "${P34_CASE}/code/bom_verify_schema3_io.F" "${mods_dir}/"
  args=("${REPO_ROOT}/tools/genmake2" "-rootdir=${REPO_ROOT}" \
    "-mods=${mods_dir}" "-of=${OPTFILE}" -ieee -devel)
  [[ "${mpi_enabled}" == no ]] || args+=( -mpi )
  (
    cd "${build_dir}"
    "${args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing ${name} executable"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  grep -q 'bom_write_trajectory_archive_' "${build_dir}/symbols.txt" \
    || fail "archive writer missing from ${name}"
}

build_p4() {
  local build_dir="${BUILD_ROOT}/p4-serial"
  local mods_dir="${BUILD_ROOT}/p4-serial-mods"
  log 'build serial P4 fixture'
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${P44_CASE}/code/SIZE.h.serial" "${mods_dir}/SIZE.h"
  cp "${P44_CASE}/code/packages.conf" "${mods_dir}/"
  cp "${P44_CASE}/code/bom_init_varia_p44.F" "${mods_dir}/bom_init_varia.F"
  cp "${P44_CASE}/code/"bom_verify_p43_*.F "${mods_dir}/"
  cp "${P44_CASE}/code/bom_verify_p44.F" "${mods_dir}/"
  sed -i 's/CALL BOM_WRITE_TRAJECTORY(/CALL BOM_VERIFY_P56_TRAJECTORY(/' \
    "${mods_dir}/bom_verify_p44.F"
  cp "${CASE_DIR}/code/bom_verify_p56_archive.F" "${mods_dir}/"
  (
    cd "${build_dir}"
    "${REPO_ROOT}/tools/genmake2" \
      "-rootdir=${REPO_ROOT}" "-mods=${mods_dir}" "-of=${OPTFILE}" \
      -ieee -devel > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail 'missing P4 executable'
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  grep -q 'bom_verify_p56_trajectory_' "${build_dir}/symbols.txt" \
    || fail 'P4 dispatch wrapper is not linked'
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

run_p3() {
  local name="$1" build="$2" ranks="$3" mode="$4"
  local run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${P34_CASE}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${P34_CASE}/input/eedata" "${run_dir}/eedata"
  cp "${P34_CASE}/input/data.schema.initial" "${run_dir}/data"
  cp "${P34_CASE}/input/data.bom.hooke" "${run_dir}/data.bom"
  sed -i "/bomInitialFile=/a\\ bomTrajectoryMode='${mode}',\\n bomTrajectoryFile='bom_trajectories'," \
    "${run_dir}/data.bom"
  log "run ${name}"
  if [[ "${ranks}" -eq 1 ]]; then
    (cd "${run_dir}"; "${BUILD_ROOT}/${build}/mitgcmuv" > combined.log 2>&1)
  else
    (cd "${run_dir}"; mpirun -np "${ranks}" \
      "${BUILD_ROOT}/${build}/mitgcmuv" > mpi-launch.log 2>&1)
    collect_logs "${run_dir}" "${ranks}" "${run_dir}/combined.log"
  fi
  rg -q 'P3-P01 PASS' "${run_dir}/combined.log" \
    || fail "P3 writer pass missing: ${name}"
  if rg -q 'ABNORMAL END|S/R ALL_PROC_DIE' "${run_dir}/combined.log"; then
    fail "fatal marker in ${name}"
  fi
}

run_p4() {
  local name="$1" run_name="$2" mode="$3"
  local prefix="${4:-bom_trajectories}"
  local run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${P44_CASE}/input/data" "${run_dir}/data"
  sed -i "s/P41-PTRACER/${run_name}/" "${run_dir}/data"
  cp "${P44_CASE}/input/eedata" "${run_dir}/eedata"
  cp "${P44_CASE}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${P44_CASE}/input/data.bom.ptracer" "${run_dir}/data.bom"
  cp "${P44_CASE}/input/data.ptracers" "${run_dir}/data.ptracers"
  sed -i "/bomInitialFile=/a\\ bomTrajectoryMode='${mode}',\\n bomTrajectoryFile='${prefix}'," \
    "${run_dir}/data.bom"
  log "run ${name}"
  (cd "${run_dir}"; "${BUILD_ROOT}/p4-serial/mitgcmuv" > combined.log 2>&1)
  rg -q 'P4-S01/B15 WRITE PASS' "${run_dir}/combined.log" \
    || fail "P4 writer pass missing: ${name}"
  if rg -q 'ABNORMAL END|S/R ALL_PROC_DIE' "${run_dir}/combined.log"; then
    fail "fatal marker in ${name}"
  fi
}

build_p3 p3-serial SIZE.h.serial no
build_p3 p3-mpi2 SIZE.h.mpi2 yes
build_p4
pass active-builds 'P3 serial/MPI-2 and P4 serial debug/IEEE fixtures linked'

run_p3 p3-frame p3-serial 1 FRAME
run_p3 p3-archive p3-serial 1 ARCHIVE
python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/p3-archive" \
  --expected-frames 2 --expected-files 13 --require-no-orphans \
  --frame-dir "${RUN_ROOT}/p3-frame" \
  > "${RUN_ROOT}/p3-archive/verify.log"
pass p3-serial 'P3 owner words and every full signature chunk match FRAME exactly'

run_p3 p3-mpi2-archive p3-mpi2 2 ARCHIVE
python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/p3-mpi2-archive" \
  --expected-frames 2 --expected-files 13 --require-no-orphans \
  > "${RUN_ROOT}/p3-mpi2-archive/verify.log"
pass p3-mpi2 'two ranks publish P3 owner/signature streams through one index'

run_p4 p4-none-frame P44-WRITE-N FRAME
run_p4 p4-none-archive P44-WRITE-N ARCHIVE
python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/p4-none-archive" \
  --expected-frames 1 --expected-files 13 --require-no-orphans \
  --frame-dir "${RUN_ROOT}/p4-none-frame" \
  > "${RUN_ROOT}/p4-none-archive/verify.log"
pass p4-only 'live=2/initial=4 index counts, owner words and P4 signature match'

run_p4 p4-growth-frame P44-WRITE-N FRAME bom_growth
run_p4 p4-growth-archive P44-WRITE-N ARCHIVE bom_growth
python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/p4-growth-archive" \
  --prefix bom_growth --expected-frames 1 --expected-files 13 \
  --require-no-orphans --frame-dir "${RUN_ROOT}/p4-growth-frame" \
  > "${RUN_ROOT}/p4-growth-archive/verify.log"
pass p4-growth 'live=2/initial=1 is valid below capacity and matches FRAME'

run_p4 p4-ebomb-frame P44-WRITE-E FRAME
run_p4 p4-ebomb-archive P44-WRITE-E ARCHIVE
python3 "${CASE_DIR}/verify_archive.py" "${RUN_ROOT}/p4-ebomb-archive" \
  --expected-frames 1 --expected-files 15 --require-no-orphans \
  --frame-dir "${RUN_ROOT}/p4-ebomb-frame" \
  > "${RUN_ROOT}/p4-ebomb-archive/verify.log"
pass p3-p4-combined 'P3/P4 owner words and complete provenance signatures match'

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
cp "${RUN_ROOT}/p3-archive/verify.log" "${ARTIFACT_ROOT}/p3-serial-verify.log"
cp "${RUN_ROOT}/p3-mpi2-archive/verify.log" "${ARTIFACT_ROOT}/p3-mpi2-verify.log"
cp "${RUN_ROOT}/p4-none-archive/verify.log" "${ARTIFACT_ROOT}/p4-only-verify.log"
cp "${RUN_ROOT}/p4-growth-archive/verify.log" \
  "${ARTIFACT_ROOT}/p4-growth-verify.log"
cp "${RUN_ROOT}/p4-ebomb-archive/verify.log" "${ARTIFACT_ROOT}/p3-p4-verify.log"
printf 'P5.6 ACTIVE ARCHIVE GATE PASS: %s\n' "${TEST_ID}"
