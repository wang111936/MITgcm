#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly RESULT_PARENT="${MITGCM_BOM_FINAL_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase00-final-gate}"
readonly RESULT_ROOT="${RESULT_PARENT}/${TEST_ID}"
readonly P04_TEST_ID="${TEST_ID}-p04"
readonly P04_BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase00-zero-particle}"
readonly P04_RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase00-zero-particle}"
readonly P04_BUILD_ROOT="${P04_BUILD_PARENT}/${P04_TEST_ID}"
readonly P04_RUN_ROOT="${P04_RUN_PARENT}/${P04_TEST_ID}"
readonly P04_DRIVER="${REPO_ROOT}/verification/bom/phase00-zero-particle/run_gate.sh"
readonly JULIA_BIN="${MITGCM_BOM_JULIA:-/home/wyl/opt/mitgcm-bom/juliaup/bin/julia}"
readonly JULIA_DEPOT="${MITGCM_BOM_JULIA_DEPOT:-/home/wyl/opt/mitgcm-bom/julia-depot}"
readonly JULIA_REFERENCE="${MITGCM_BOM_JULIA_REFERENCE:-/home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl}"
readonly JULIA_REGISTRY="${MITGCM_BOM_JULIA_REGISTRY:-/home/wyl/projects/mitgcm-bom-reference/SargassumRegistry}"
readonly EXPECTED_JULIA_COMMIT="156557359185e4413ce82829f3ed26a4eb8c6283"
readonly EXPECTED_REGISTRY_COMMIT="02961aced4cfa2b3430ebd4b44cdb7a3056e7175"
readonly EXPECTED_PROJECT_SHA="12cfb1288a21b19216662a719d430bf41b5587dfd8b00e973f8b3c9c25f1f99d"
readonly EXPECTED_MANIFEST_SHA="86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695"

fail() {
  printf 'P0.5 GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P0.5] %s\n' "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

assert_equal() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  [[ "${actual}" == "${expected}" ]] \
    || fail "${label}: expected ${expected}, got ${actual}"
}

for required_command in bash git grep sha256sum awk; do
  require_command "${required_command}"
done

[[ -x "${JULIA_BIN}" ]] || fail "Julia executable not found: ${JULIA_BIN}"
[[ -x "${P04_DRIVER}" ]] || fail "P0.4 driver not executable: ${P04_DRIVER}"
[[ -f "${CASE_DIR}/julia_smoke.jl" ]] || fail "Julia smoke file not found"
[[ -d "${JULIA_REFERENCE}/.git" ]] || fail "Julia reference checkout not found"
[[ -d "${JULIA_REGISTRY}/.git" ]] || fail "Julia registry checkout not found"
[[ ! -e "${RESULT_ROOT}" ]] || fail "result root already exists: ${RESULT_ROOT}"
[[ ! -e "${P04_BUILD_ROOT}" ]] || fail "P0.4 build root already exists: ${P04_BUILD_ROOT}"
[[ ! -e "${P04_RUN_ROOT}" ]] || fail "P0.4 run root already exists: ${P04_RUN_ROOT}"

mkdir -p "${RESULT_ROOT}"
printf 'check\tresult\tdetail\n' > "${RESULT_ROOT}/summary.tsv"

log "verify locked references"
julia_commit="$(git -C "${JULIA_REFERENCE}" rev-parse HEAD)"
registry_commit="$(git -C "${JULIA_REGISTRY}" rev-parse HEAD)"
assert_equal "${julia_commit}" "${EXPECTED_JULIA_COMMIT}" "Julia source commit"
assert_equal "${registry_commit}" "${EXPECTED_REGISTRY_COMMIT}" "Julia registry commit"
git -C "${JULIA_REFERENCE}" diff --quiet \
  || fail "Julia reference checkout has tracked modifications"
git -C "${JULIA_REFERENCE}" diff --cached --quiet \
  || fail "Julia reference checkout has staged modifications"
git -C "${JULIA_REGISTRY}" diff --quiet \
  || fail "Julia registry checkout has tracked modifications"
git -C "${JULIA_REGISTRY}" diff --cached --quiet \
  || fail "Julia registry checkout has staged modifications"

locked_project_sha="$(sha256sum "${REPO_ROOT}/verification/bom/reference/julia_env/Project.toml" | awk '{print $1}')"
locked_manifest_sha="$(sha256sum "${REPO_ROOT}/verification/bom/reference/julia_env/Manifest.toml" | awk '{print $1}')"
checkout_project_sha="$(sha256sum "${JULIA_REFERENCE}/Project.toml" | awk '{print $1}')"
checkout_manifest_sha="$(sha256sum "${JULIA_REFERENCE}/Manifest.toml" | awk '{print $1}')"
assert_equal "${locked_project_sha}" "${EXPECTED_PROJECT_SHA}" "locked Project.toml SHA-256"
assert_equal "${checkout_project_sha}" "${EXPECTED_PROJECT_SHA}" "checkout Project.toml SHA-256"
assert_equal "${locked_manifest_sha}" "${EXPECTED_MANIFEST_SHA}" "locked Manifest.toml SHA-256"
assert_equal "${checkout_manifest_sha}" "${EXPECTED_MANIFEST_SHA}" "checkout Manifest.toml SHA-256"
printf 'locked-references\tPASS\tsource, registry, Project, and Manifest match\n' \
  >> "${RESULT_ROOT}/summary.tsv"

log "instantiate locked Julia environment in offline mode"
env JULIA_DEPOT_PATH="${JULIA_DEPOT}" JULIA_PKG_OFFLINE=true \
  "${JULIA_BIN}" --startup-file=no --history-file=no \
  --project="${JULIA_REFERENCE}" \
  -e 'using Pkg; Pkg.offline(true); Pkg.instantiate(; allow_autoprecomp=false); println("P0.5 JULIA INSTANTIATE PASS")' \
  > "${RESULT_ROOT}/julia-instantiate.log" 2>&1
grep -q 'P0.5 JULIA INSTANTIATE PASS' "${RESULT_ROOT}/julia-instantiate.log" \
  || fail "Julia instantiate pass marker missing"
printf 'julia-instantiate\tPASS\toffline locked environment\n' \
  >> "${RESULT_ROOT}/summary.tsv"

log "run BOM-specific Julia smoke"
env JULIA_DEPOT_PATH="${JULIA_DEPOT}" JULIA_PKG_OFFLINE=true \
  "${JULIA_BIN}" --startup-file=no --history-file=no \
  --project="${JULIA_REFERENCE}" "${CASE_DIR}/julia_smoke.jl" \
  > "${RESULT_ROOT}/julia-smoke.log" 2>&1
grep -q 'P0.5 JULIA SMOKE PASS' "${RESULT_ROOT}/julia-smoke.log" \
  || fail "Julia smoke pass marker missing"
grep -q 'sargassumbomb_version=0.7.14' "${RESULT_ROOT}/julia-smoke.log" \
  || fail "Julia package version evidence missing"
printf 'julia-smoke\tPASS\tload, coordinate/time round trips, pure utilities\n' \
  >> "${RESULT_ROOT}/summary.tsv"

log "rerun formal P0.4 gate"
MITGCM_BOM_TEST_ID="${P04_TEST_ID}" \
MITGCM_BOM_TEST_BUILD_ROOT="${P04_BUILD_PARENT}" \
MITGCM_BOM_TEST_RUN_ROOT="${P04_RUN_PARENT}" \
  "${P04_DRIVER}" > "${RESULT_ROOT}/p04-gate.log" 2>&1
grep -q 'P0.4 GATE PASS' "${RESULT_ROOT}/p04-gate.log" \
  || fail "P0.4 pass marker missing"
[[ -f "${P04_RUN_ROOT}/summary.tsv" ]] || fail "P0.4 summary missing"
p04_pass_count="$(awk -F '\t' 'NR > 1 && $2 == "PASS" {count++} END {print count+0}' "${P04_RUN_ROOT}/summary.tsv")"
assert_equal "${p04_pass_count}" "9" "P0.4 passed check count"
cp "${P04_RUN_ROOT}/summary.tsv" "${RESULT_ROOT}/p04-summary.tsv"
printf 'p04-formal-gate\tPASS\t4 builds, 3 positive runs, 2 negative gates\n' \
  >> "${RESULT_ROOT}/summary.tsv"

sha256sum "${CASE_DIR}/julia_smoke.jl" "${P04_DRIVER}" \
  > "${RESULT_ROOT}/driver-inputs.sha256"

log "P0.5 GATE PASS"
log "result root: ${RESULT_ROOT}"
log "P0.4 build root: ${P04_BUILD_ROOT}"
log "P0.4 run root:   ${P04_RUN_ROOT}"
cat "${RESULT_ROOT}/summary.tsv"
