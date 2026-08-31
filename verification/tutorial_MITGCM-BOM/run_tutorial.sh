#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: run_tutorial.sh --work-root PATH [--equation JULIA|PAPER2024] [--jobs N]' \
    '' \
    'Builds and runs the serial MITGCM-BOM controlled tutorial in a new PATH.' \
    'The command refuses an existing work root.'
}

fail() {
  printf 'MITGCM-BOM TUTORIAL FAIL: %s\n' "$*" >&2
  exit 1
}

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_ROOT}/../.." && pwd)"
WORK_ROOT=''
EQUATION='JULIA'
MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"

while (( $# > 0 )); do
  case "$1" in
    --work-root)
      (( $# >= 2 )) || fail '--work-root requires a path'
      WORK_ROOT="$2"
      shift 2
      ;;
    --equation)
      (( $# >= 2 )) || fail '--equation requires JULIA or PAPER2024'
      EQUATION="$2"
      shift 2
      ;;
    --jobs)
      (( $# >= 2 )) || fail '--jobs requires a positive integer'
      MAKE_JOBS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "${WORK_ROOT}" ]] || fail '--work-root is required'
[[ "${EQUATION}" == 'JULIA' || "${EQUATION}" == 'PAPER2024' ]] \
  || fail '--equation must be JULIA or PAPER2024'
[[ "${MAKE_JOBS}" =~ ^[1-9][0-9]*$ ]] || fail '--jobs must be a positive integer'
[[ ! -e "${WORK_ROOT}" ]] || fail "work root already exists: ${WORK_ROOT}"
[[ -x "${REPO_ROOT}/tools/genmake2" ]] || fail 'tools/genmake2 is not executable'
[[ -f "${OPTFILE}" ]] || fail "missing genmake2 option file: ${OPTFILE}"
command -v python3 >/dev/null || fail 'python3 is required'
command -v make >/dev/null || fail 'make is required'
command -v sha256sum >/dev/null || fail 'sha256sum is required'

mkdir -p "${WORK_ROOT}"
WORK_ROOT="$(cd -- "${WORK_ROOT}" && pwd)"
BUILD_DIR="${WORK_ROOT}/build"
INPUT_DIR="${WORK_ROOT}/input"
RUN_DIR="${WORK_ROOT}/run"
ANALYSIS_DIR="${WORK_ROOT}/analysis"
mkdir -p "${BUILD_DIR}" "${RUN_DIR}" "${ANALYSIS_DIR}"

printf 'Generating %s input bundle...\n' "${EQUATION}"
python3 "${SCRIPT_ROOT}/input/gendata.py" "${INPUT_DIR}" --equation "${EQUATION}" \
  > "${WORK_ROOT}/input-generation.log"
(
  cd "${INPUT_DIR}"
  sha256sum --check SHA256SUMS
) > "${WORK_ROOT}/input-checksums.log"

printf 'Building production MITgcm + pkg/bom...\n'
(
  cd "${BUILD_DIR}"
  "${REPO_ROOT}/tools/genmake2" \
    -rootdir="${REPO_ROOT}" \
    -mods="${SCRIPT_ROOT}/code" \
    -of="${OPTFILE}" \
    -ieee -devel > genmake.log 2>&1
  make depend > depend.log 2>&1
  make -j "${MAKE_JOBS}" > build.log 2>&1
)
[[ -x "${BUILD_DIR}/mitgcmuv" ]] || fail 'build did not produce mitgcmuv'

for file in "${INPUT_DIR}"/*; do
  ln -s "${file}" "${RUN_DIR}/$(basename -- "${file}")"
done

printf 'Running 24 production time steps...\n'
(
  cd "${RUN_DIR}"
  ulimit -s unlimited
  "${BUILD_DIR}/mitgcmuv" > STDOUT.0000 2> STDERR.0000
)
grep -Fq 'PROGRAM MAIN: Execution ended Normally' "${RUN_DIR}/STDOUT.0000" \
  || fail 'normal MITgcm completion marker is missing'
find "${RUN_DIR}" -maxdepth 1 -type f -name 'bom_traj.*.data' -print -quit \
  | grep -q . || fail 'no BOM trajectory files were written'
find "${RUN_DIR}" -maxdepth 1 -type f -name 'pickup_bom.*' -print -quit \
  | grep -q . || fail 'no BOM pickup files were written'

printf 'Decoding and plotting schema-2 trajectories...\n'
python3 "${SCRIPT_ROOT}/analysis/plot_bom.py" \
  --run-dir "${RUN_DIR}" \
  --output-dir "${ANALYSIS_DIR}" \
  --expected-frames 24 \
  --expected-particles 3 \
  --expected-final-time 21600 \
  > "${WORK_ROOT}/analysis.log"

{
  printf 'status=PASS\n'
  printf 'equation=%s\n' "${EQUATION}"
  printf 'source_head=%s\n' "$(git -C "${REPO_ROOT}" rev-parse HEAD)"
  printf 'executable_sha256='
  sha256sum "${BUILD_DIR}/mitgcmuv" | awk '{print $1}'
  printf 'work_root=%s\n' "${WORK_ROOT}"
} > "${WORK_ROOT}/tutorial-result.txt"

printf '%s\n' \
  'MITGCM-BOM TUTORIAL PASS' \
  "work root: ${WORK_ROOT}" \
  "trajectory CSV: ${ANALYSIS_DIR}/bom_trajectory.csv" \
  "summary JSON: ${ANALYSIS_DIR}/bom_trajectory_summary.json" \
  "trajectory PNG: ${ANALYSIS_DIR}/bom_trajectory.png"
