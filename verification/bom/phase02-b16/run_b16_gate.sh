#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p24-b16-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase02-b16}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase02-b16}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p24-b16}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly JULIA_BIN="${MITGCM_BOM_JULIA_BIN:-/home/wyl/tools/julia-1.10.12/bin/julia}"
readonly SOURCE_ROOT="${MITGCM_BOM_JULIA_SOURCE:-/home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl}"
readonly REF_ROOT="${REPO_ROOT}/verification/bom/reference"
readonly PHASE_ROOT="${REF_ROOT}/phase02"
readonly PREFLIGHT="${PHASE_ROOT}/verify_b16_preflight.py"
readonly PROJECT_FILE="${REF_ROOT}/julia_env/Project.toml"
readonly MANIFEST_FILE="${REF_ROOT}/julia_env/Manifest.toml"
readonly GENERATOR="${PHASE_ROOT}/generate_b16_golden.jl"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly P22_CODE="${REPO_ROOT}/verification/bom/phase02-derivatives/code"

fail() { printf 'P2.4 B16 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P2.4-b16] %s\n' "$*"; }
for required in bash make nm grep cmp sed sha256sum shellcheck python3 git; do
  command -v "${required}" >/dev/null 2>&1 || fail "missing ${required}"
done
[[ -x "${JULIA_BIN}" ]] || fail "missing Julia runtime: ${JULIA_BIN}"
for root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${root}" ]] || fail "evidence root already exists: ${root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}" "${RUN_ROOT}/n07"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${RUN_ROOT}/pycache" python3 -m py_compile "${PREFLIGHT}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"
record_pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

preflight_args=(
  --phase-dir "${PHASE_ROOT}"
  --source-root "${SOURCE_ROOT}"
  --julia-bin "${JULIA_BIN}"
  --project-file "${PROJECT_FILE}"
  --manifest-file "${MANIFEST_FILE}"
)

expect_reject() {
  local label="$1"
  shift
  if "$@" > "${RUN_ROOT}/n07/${label}.log" 2>&1; then
    fail "N07 mutation unexpectedly passed: ${label}"
  fi
  grep -q 'B16 PREFLIGHT FAIL:' "${RUN_ROOT}/n07/${label}.log" || fail "N07 fail marker missing: ${label}"
  record_pass "p2-n07-${label}" 'rejected before generation/comparison'
}

run_n07() {
  local mutation
  mutation="${RUN_ROOT}/n07/physics.jl"
  cp "${SOURCE_ROOT}/src/physics.jl" "${mutation}"
  printf '# N07 mutation\n' >> "${mutation}"
  expect_reject source python3 "${PREFLIGHT}" --mode input "${preflight_args[@]}" --physics-file "${mutation}"

  mutation="${RUN_ROOT}/n07/Project.toml"
  cp "${PROJECT_FILE}" "${mutation}"
  printf '# N07 mutation\n' >> "${mutation}"
  expect_reject project python3 "${PREFLIGHT}" --mode input "${preflight_args[@]}" --project-file "${mutation}"

  mutation="${RUN_ROOT}/n07/Manifest.toml"
  cp "${MANIFEST_FILE}" "${mutation}"
  printf '# N07 mutation\n' >> "${mutation}"
  expect_reject manifest python3 "${PREFLIGHT}" --mode input "${preflight_args[@]}" --manifest-file "${mutation}"

  mutation="${RUN_ROOT}/n07/input_fields_v1.csv"
  cp "${PHASE_ROOT}/input_fields_v1.csv" "${mutation}"
  printf '# N07 mutation\n' >> "${mutation}"
  expect_reject input python3 "${PREFLIGHT}" --mode input "${preflight_args[@]}" --override "input_fields_v1.csv=${mutation}"

  mutation="${RUN_ROOT}/n07/golden_rhs_julia_v1.csv"
  cp "${PHASE_ROOT}/golden_rhs_julia_v1.csv" "${mutation}"
  printf '# N07 mutation\n' >> "${mutation}"
  expect_reject golden python3 "${PREFLIGHT}" --mode full "${preflight_args[@]}" --override "golden_rhs_julia_v1.csv=${mutation}"

  expect_reject commit python3 "${PREFLIGHT}" --mode input "${preflight_args[@]}" --source-head 0000000000000000000000000000000000000000
  expect_reject julia-version python3 "${PREFLIGHT}" --mode input "${preflight_args[@]}" --julia-bin /bin/echo
}

reproduce_golden() {
  local output="${RUN_ROOT}/generated"
  python3 "${PREFLIGHT}" --mode input "${preflight_args[@]}" > "${RUN_ROOT}/preflight-input.log"
  "${JULIA_BIN}" --startup-file=no --project="${REF_ROOT}/julia_env" \
    "${GENERATOR}" "${output}" "${PHASE_ROOT}" "${SOURCE_ROOT}" \
    "${PROJECT_FILE}" "${MANIFEST_FILE}" > "${RUN_ROOT}/generator.log" 2>&1
  for name in golden_rhs_julia_v1.csv golden_traj_julia_rk2_v1.csv golden_traj_julia_rk4_v1.csv; do
    cmp "${PHASE_ROOT}/${name}" "${output}/${name}" || fail "golden is not reproducible: ${name}"
  done
  python3 "${PREFLIGHT}" --mode full "${preflight_args[@]}" > "${RUN_ROOT}/preflight-full.log"
  record_pass p2-i05-lock 'Julia/source/environment/input checks and bytewise regeneration'
}

build_case() {
  local build_dir="${BUILD_ROOT}/serial"
  local mods_dir="${BUILD_ROOT}/serial-mods"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${P22_CODE}/SIZE.h.serial" "${mods_dir}/SIZE.h"
  cp "${P22_CODE}/packages.conf" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_b16.F" "${mods_dir}/"
  (
    cd "${build_dir}"
    "${REPO_ROOT}/tools/genmake2" -rootdir="${REPO_ROOT}" -mods="${mods_dir}" -of="${OPTFILE}" -ieee -devel > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail 'missing B16 executable'
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_verify_b16_ bom_rhs_slow_manifold_ bom_rk2_slow_migrate_ bom_rk4_slow_migrate_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" || fail "missing ${symbol}"
  done
  record_pass build-serial 'debug compile with B16 and production stage/RK symbols'
}

run_case() {
  local run_dir="${RUN_ROOT}/serial"
  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/"
  cp "${CASE_DIR}/input/data.bom" "${run_dir}/"
  cp "${PHASE_ROOT}/input_fields_v1.csv" "${run_dir}/"
  cp "${PHASE_ROOT}/input_particles_v1.csv" "${run_dir}/"
  cp "${PHASE_ROOT}/golden_rhs_julia_v1.csv" "${run_dir}/"
  cp "${PHASE_ROOT}/golden_traj_julia_rk2_v1.csv" "${run_dir}/"
  cp "${PHASE_ROOT}/golden_traj_julia_rk4_v1.csv" "${run_dir}/"
  ln -s "${BUILD_ROOT}/serial/mitgcmuv" "${run_dir}/mitgcmuv"
  (cd "${run_dir}"; ./mitgcmuv > run.log 2>&1)
  grep -q 'P2-I05 PASS:' "${run_dir}/run.log" || fail 'P2-I05 marker missing'
  grep -q 'P2-I06 PASS:' "${run_dir}/run.log" || fail 'P2-I06 marker missing'
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${run_dir}/run.log" || fail 'normal end missing'
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${run_dir}/run.log"; then
    fail 'fatal marker found in B16 run'
  fi
  record_pass p2-i05-rhs 'all 27 JULIA RHS components meet frozen tolerance'
  record_pass p2-i06-rk2 'fixed RK2 trajectory meets physical tolerance'
  record_pass p2-i06-rk4 'fixed RK4 trajectory meets physical tolerance'
}

log 'run fail-closed N07 mutations'
run_n07
log 'regenerate locked golden files'
reproduce_golden
log 'build serial B16 comparator'
build_case
log 'run serial B16 comparator'
run_case
if tail -n +2 "${RUN_ROOT}/summary.tsv" | grep -v $'PASS\t' | grep -q .; then
  fail 'summary contains a non-PASS row'
fi
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/"
cp "${RUN_ROOT}/preflight-input.log" "${ARTIFACT_ROOT}/"
cp "${RUN_ROOT}/preflight-full.log" "${ARTIFACT_ROOT}/"
cp "${RUN_ROOT}/generator.log" "${ARTIFACT_ROOT}/"
cp "${BUILD_ROOT}/serial/build.log" "${ARTIFACT_ROOT}/serial-build.log"
cp "${RUN_ROOT}/serial/run.log" "${ARTIFACT_ROOT}/serial-run.log"
cp -a "${RUN_ROOT}/n07" "${ARTIFACT_ROOT}/"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv preflight-input.log preflight-full.log generator.log serial-build.log serial-run.log > SHA256SUMS
)
log 'P2.4 B16 GATE PASS'
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
