#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:?set MITGCM_BOM_EXPECTED_HEAD to the full functional commit}"
readonly SHORT_HEAD="${EXPECTED_HEAD:0:10}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p25-closure-${SHORT_HEAD}-attempt01}"
readonly EVIDENCE_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-closure}/${TEST_ID}"
readonly EXPECTED_TOTAL=390

fail() { printf 'P2-G01 CLOSURE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P2-G01] %s\n' "$*"; }

for command_name in awk bash git grep python3 sha256sum shellcheck; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing ${command_name}"
done
[[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" == "${EXPECTED_HEAD}" ]] \
  || fail 'current HEAD differs from MITGCM_BOM_EXPECTED_HEAD'
[[ -z "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]] \
  || fail 'exact-head closure requires a clean worktree'
[[ ! -e "${EVIDENCE_ROOT}" ]] || fail "evidence root exists: ${EVIDENCE_ROOT}"
mkdir -p "${EVIDENCE_ROOT}/summaries" "${EVIDENCE_ROOT}/native-manifests"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
python3 -m py_compile "${CASE_DIR}/audit_closure.py"
printf 'group\tsource\n' > "${EVIDENCE_ROOT}/provenance.tsv"
printf 'group\texpected\tactual\tresult\n' > "${EVIDENCE_ROOT}/row-audit.tsv"
printf 'group\tcase\tresult\tdetail\n' > "${EVIDENCE_ROOT}/all-rows.tsv"

register_summary() {
  local group="$1" expected="$2" source="$3" actual result native
  [[ -f "${source}" ]] || fail "missing summary for ${group}: ${source}"
  actual="$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END {print n+0}' "${source}")"
  result=FAIL
  [[ "${actual}" -eq "${expected}" ]] && result=PASS
  printf '%s\t%s\t%s\t%s\n' "${group}" "${expected}" "${actual}" "${result}" \
    >> "${EVIDENCE_ROOT}/row-audit.tsv"
  [[ "${result}" == PASS ]] || fail "${group}: expected ${expected}, got ${actual}"
  cp "${source}" "${EVIDENCE_ROOT}/summaries/${group}.tsv"
  printf '%s\t%s\n' "${group}" "${source}" >> "${EVIDENCE_ROOT}/provenance.tsv"
  awk -F '\t' -v group="${group}" 'NR>1 {print group "\t" $0}' "${source}" \
    >> "${EVIDENCE_ROOT}/all-rows.tsv"
  native="$(dirname "${source}")/manifest.sha256"
  if [[ -f "${native}" ]]; then
    cp "${native}" "${EVIDENCE_ROOT}/native-manifests/${group}.sha256"
  else
    sha256sum "${source}" > "${EVIDENCE_ROOT}/native-manifests/${group}.sha256"
  fi
}

run_driver() {
  local group="$1" driver="$2" id="${TEST_ID}-$1"
  log "run ${group}"
  env MITGCM_BOM_TEST_ID="${id}" \
      MITGCM_BOM_REQUIRE_CLEAN=yes \
      MITGCM_BOM_ALLOW_OWNER_MIGRATION=yes \
      "${driver}" > "${EVIDENCE_ROOT}/${group}.log" 2>&1
}

run_driver p05-final "${REPO_ROOT}/verification/bom/phase00-final-gate/run_gate.sh"
register_summary p05-final 4 \
  "/home/wyl/runs/mitgcm-bom/phase00-final-gate/${TEST_ID}-p05-final/summary.tsv"

run_driver p04-zero "${REPO_ROOT}/verification/bom/phase00-zero-particle/run_gate.sh"
register_summary p04-zero 9 \
  "/home/wyl/runs/mitgcm-bom/phase00-zero-particle/${TEST_ID}-p04-zero/summary.tsv"

run_driver p11-state "${REPO_ROOT}/verification/bom/phase01-bom-lite/run_state_gate.sh"
register_summary p11-state 42 \
  "/home/wyl/runs/mitgcm-bom/phase01-state/${TEST_ID}-p11-state/summary.tsv"

run_driver p12-mapping "${REPO_ROOT}/verification/bom/phase01-mapping/run_mapping_gate.sh"
register_summary p12-mapping 19 \
  "/home/wyl/runs/mitgcm-bom/phase01-mapping/${TEST_ID}-p12-mapping/summary.tsv"

run_driver p12-fields "${REPO_ROOT}/verification/bom/phase01-fields/run_field_gate.sh"
register_summary p12-fields 7 \
  "/home/wyl/runs/mitgcm-bom/phase01-fields/${TEST_ID}-p12-fields/summary.tsv"

run_driver p12-interp "${REPO_ROOT}/verification/bom/phase01-interp/run_interp_gate.sh"
register_summary p12-interp 9 \
  "/home/wyl/runs/mitgcm-bom/phase01-interp/${TEST_ID}-p12-interp/summary.tsv"

run_driver p13-setup "${REPO_ROOT}/verification/bom/phase01-setup/run_setup_gate.sh"
register_summary p13-setup 17 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/${TEST_ID}-p13-setup/summary.tsv"

run_driver p13-rhs "${REPO_ROOT}/verification/bom/phase01-rhs/run_rhs_gate.sh"
register_summary p13-rhs 15 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/${TEST_ID}-p13-rhs/summary.tsv"

run_driver p13-rk2 "${REPO_ROOT}/verification/bom/phase01-rk2/run_rk2_gate.sh"
register_summary p13-rk2 12 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/${TEST_ID}-p13-rk2/summary.tsv"

run_driver p13-rk4 "${REPO_ROOT}/verification/bom/phase01-rk4/run_rk4_gate.sh"
register_summary p13-rk4 12 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/${TEST_ID}-p13-rk4/summary.tsv"

run_driver p13-lifecycle "${REPO_ROOT}/verification/bom/phase01-lifecycle/run_lifecycle_gate.sh"
register_summary p13-lifecycle 13 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/${TEST_ID}-p13-lifecycle/summary.tsv"

run_driver p14-owner "${REPO_ROOT}/verification/bom/phase01-owner-migration/run_owner_gate.sh"
register_summary p14-owner 36 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p14/${TEST_ID}-p14-owner/summary.tsv"

run_driver p15-output "${REPO_ROOT}/verification/bom/phase01-output-pickup-coexistence/run_output_gate.sh"
register_summary p15-output 25 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/${TEST_ID}-p15-output/summary.tsv"

run_driver p15-migration "${REPO_ROOT}/verification/bom/phase01-output-pickup-coexistence/run_migration_gate.sh"
register_summary p15-migration 12 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/${TEST_ID}-p15-migration/summary.tsv"

run_driver p15-coexistence "${REPO_ROOT}/verification/bom/phase01-output-pickup-coexistence/run_coexistence_gate.sh"
register_summary p15-coexistence 25 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/${TEST_ID}-p15-coexistence/summary.tsv"

run_driver p21-endpoint "${REPO_ROOT}/verification/bom/phase02-endpoint-state/run_endpoint_state_gate.sh"
register_summary p21-endpoint 34 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state/${TEST_ID}-p21-endpoint/summary.tsv"

run_driver p21-pickup "${REPO_ROOT}/verification/bom/phase02-endpoint-state/run_pickup_gate.sh"
register_summary p21-pickup 10 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-pickup/${TEST_ID}-p21-pickup/summary.tsv"

run_driver p22-derivative "${REPO_ROOT}/verification/bom/phase02-derivatives/run_derivative_gate.sh"
register_summary p22-derivative 16 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p22-derivatives/${TEST_ID}-p22-derivative/summary.tsv"

run_driver p23-rhs "${REPO_ROOT}/verification/bom/phase02-rhs-components/run_rhs_component_gate.sh"
register_summary p23-rhs 18 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p23-rhs-components/${TEST_ID}-p23-rhs/summary.tsv"

run_driver p24-stage-rk "${REPO_ROOT}/verification/bom/phase02-stage-rk/run_stage_rk_gate.sh"
register_summary p24-stage-rk 11 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p24-stage-rk/${TEST_ID}-p24-stage-rk/summary.tsv"

run_driver p24-b16 "${REPO_ROOT}/verification/bom/phase02-b16/run_b16_gate.sh"
register_summary p24-b16 12 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p24-b16/${TEST_ID}-p24-b16/summary.tsv"

run_driver p25-integration "${CASE_DIR}/run_integration_gate.sh"
register_summary p25-integration 20 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-integration/${TEST_ID}-p25-integration/summary.tsv"

log 'run p25-k01 using the exact p15 coexistence build'
env MITGCM_BOM_TEST_ID="${TEST_ID}-p25-k01" \
    MITGCM_BOM_REQUIRE_CLEAN=yes \
    MITGCM_BOM_K01_REUSE_BASE_ID="${TEST_ID}-p15-coexistence" \
    "${CASE_DIR}/run_coexistence_bom_gate.sh" \
    > "${EVIDENCE_ROOT}/p25-k01.log" 2>&1
register_summary p25-k01 12 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-k01/${TEST_ID}-p25-k01/summary.tsv"

actual_total="$(awk -F '\t' 'NR>1 {sum+=$3} END {print sum+0}' "${EVIDENCE_ROOT}/row-audit.tsv")"
[[ "${actual_total}" -eq "${EXPECTED_TOTAL}" ]] \
  || fail "aggregate expected ${EXPECTED_TOTAL}, got ${actual_total}"
printf 'TOTAL\t%s\t%s\tPASS\n' "${EXPECTED_TOTAL}" "${actual_total}" \
  >> "${EVIDENCE_ROOT}/row-audit.tsv"

git -C "${REPO_ROOT}" rev-parse HEAD > "${EVIDENCE_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 > "${EVIDENCE_ROOT}/git-status.txt"
[[ ! -s "${EVIDENCE_ROOT}/git-status.txt" ]] || fail 'tests changed the worktree'
git -C "${REPO_ROOT}" diff --name-only HEAD^ HEAD > "${EVIDENCE_ROOT}/patch-files.txt"
if grep -Eqi 'skrips|codex' "${EVIDENCE_ROOT}/patch-files.txt"; then
  fail 'forbidden project path in functional patch'
fi
git -C "${REPO_ROOT}" ls-files pkg/bom verification/bom/phase02-integration-closure \
  | while IFS= read -r path; do sha256sum "${REPO_ROOT}/${path}"; done \
  > "${EVIDENCE_ROOT}/source-files.sha256"
sha256sum "${CASE_DIR}"/*.sh "${CASE_DIR}"/*.py \
  > "${EVIDENCE_ROOT}/driver-files.sha256"

python3 "${CASE_DIR}/audit_closure.py" "${REPO_ROOT}" "${EVIDENCE_ROOT}" \
  "${EXPECTED_HEAD}" "${EXPECTED_TOTAL}" > "${EVIDENCE_ROOT}/independent-audit.log"
grep -q 'P2.5 INDEPENDENT AUDIT PASS' "${EVIDENCE_ROOT}/independent-audit.log" \
  || fail 'independent audit marker missing'

(
  cd "${EVIDENCE_ROOT}"
  sha256sum all-rows.tsv driver-files.sha256 git-status.txt \
    independent-audit.log patch-files.txt provenance.tsv row-audit.tsv \
    source-files.sha256 source-head.txt > manifest.sha256
)
(
  cd "${EVIDENCE_ROOT}"
  sha256sum -c manifest.sha256 > manifest-check.log
)
log "P2-G01 CLOSURE PASS (${EXPECTED_TOTAL}/${EXPECTED_TOTAL})"
log "source head: ${EXPECTED_HEAD}"
log "evidence root: ${EVIDENCE_ROOT}"
cat "${EVIDENCE_ROOT}/row-audit.tsv"
