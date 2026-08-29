#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:?set full exact head}"
readonly MODE="${MITGCM_BOM_INTEGRATION_MODE:-candidate}"
P4_REPLAY_SCOPE=none
if [[ "${MODE}" == predecessor ]]; then
  P4_REPLAY_SCOPE=predecessor
fi
readonly P4_REPLAY_SCOPE
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p3-g99-${MODE}-${EXPECTED_HEAD:0:10}-attempt01}"
readonly EVIDENCE_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p3-g99}/${TEST_ID}"
readonly EXPECTED_TOTAL=538

fail() { printf 'P3-G99 FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P3-G99] %s\n' "$*"; }

for command_name in awk bash git grep python3 rg sha256sum shellcheck; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || fail "missing ${command_name}"
done
[[ "${MODE}" == candidate || "${MODE}" == final \
   || "${MODE}" == predecessor ]] \
  || fail "invalid MITGCM_BOM_INTEGRATION_MODE=${MODE}"
[[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" == "${EXPECTED_HEAD}" ]] \
  || fail 'current HEAD differs from expected head'
[[ -z "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]] \
  || fail 'P3-G99 requires a clean worktree'
[[ -z "$(git -C "${REPO_ROOT}" tag -l MITGCM-BOM-v0.4)" ]] \
  || fail 'P3-G99 cannot run after the v0.4 tag exists'
if [[ "${MODE}" == candidate ]]; then
  [[ "$(git -C "${REPO_ROOT}" branch --show-current)" == \
    MITGCM-BOM/p3.5-performance-closeout ]] \
    || fail 'candidate mode requires the P3.5 package branch'
  git -C "${REPO_ROOT}" merge-base --is-ancestor \
    MITGCM-BOM/development "${EXPECTED_HEAD}" \
    || fail 'development is not an ancestor of the package head'
elif [[ "${MODE}" == final ]]; then
  [[ "$(git -C "${REPO_ROOT}" branch --show-current)" == \
    MITGCM-BOM/development ]] \
    || fail 'final mode requires the development branch'
  [[ -n "${MITGCM_BOM_P35_PACKAGE_HEAD:-}" ]] \
    || fail 'final mode requires MITGCM_BOM_P35_PACKAGE_HEAD'
  git -C "${REPO_ROOT}" merge-base --is-ancestor \
    "${MITGCM_BOM_P35_PACKAGE_HEAD}" "${EXPECTED_HEAD}" \
    || fail 'P3.5 package head is not integrated'
else
  [[ "$(git -C "${REPO_ROOT}" branch --show-current)" == \
    MITGCM-BOM/p3.5-performance-closeout ]] \
    || fail 'predecessor mode requires an isolated P3.5 replay branch'
  [[ "$(git -C "${REPO_ROOT}" rev-parse MITGCM-BOM/development)" == \
    "${EXPECTED_HEAD}" ]] \
    || fail 'predecessor replay baseline must equal the exact head'
  git -C "${REPO_ROOT}" merge-base --is-ancestor \
    70c02a277ea7d472ccf6e9a7533b2b41ed7eab5a "${EXPECTED_HEAD}" \
    || fail 'v0.4 release commit is not an ancestor of replay head'
fi
[[ ! -e "${EVIDENCE_ROOT}" ]] \
  || fail "evidence root exists: ${EVIDENCE_ROOT}"
mkdir -p "${EVIDENCE_ROOT}/summaries" \
  "${EVIDENCE_ROOT}/native-manifests"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
python3 -m py_compile "${CASE_DIR}/audit_p3_g99.py"
printf 'group\texpected\tactual\tresult\n' \
  > "${EVIDENCE_ROOT}/row-audit.tsv"
printf 'group\tsource\n' > "${EVIDENCE_ROOT}/provenance.tsv"
printf 'package\tgroup\tcase\tresult\tdetail\n' \
  > "${EVIDENCE_ROOT}/all-rows.tsv"

run_driver() {
  local group="$1" driver="$2" id="${TEST_ID}-$1"
  log "run ${group}"
  env MITGCM_BOM_EXPECTED_HEAD="${EXPECTED_HEAD}" \
      MITGCM_BOM_TEST_ID="${id}" \
      MITGCM_BOM_REQUIRE_CLEAN=yes \
      MITGCM_BOM_SCOPE_MODE=p35 \
      MITGCM_BOM_REPLAY_SCOPE="${P4_REPLAY_SCOPE}" \
      "${driver}" > "${EVIDENCE_ROOT}/${group}.log" 2>&1
}

register_direct() {
  local group="$1" expected="$2" source="$3"
  local actual native source_head
  [[ -f "${source}" ]] || fail "missing ${group} summary: ${source}"
  actual="$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END{print n+0}' \
    "${source}")"
  [[ "${actual}" -eq "${expected}" ]] \
    || fail "${group}: expected ${expected}, got ${actual}"
  printf '%s\t%s\t%s\tPASS\n' "${group}" "${expected}" "${actual}" \
    >> "${EVIDENCE_ROOT}/row-audit.tsv"
  printf '%s\t%s\n' "${group}" "${source}" \
    >> "${EVIDENCE_ROOT}/provenance.tsv"
  cp "${source}" "${EVIDENCE_ROOT}/summaries/${group}.tsv"
  awk -F '\t' -v package="${group}" \
    'NR>1 {print package "\t" package "\t" $0}' "${source}" \
    >> "${EVIDENCE_ROOT}/all-rows.tsv"
  native="$(dirname "${source}")/manifest.sha256"
  [[ -f "${native}" ]] || fail "${group}: native manifest missing"
  (cd "$(dirname "${source}")" && sha256sum -c manifest.sha256 >/dev/null)
  cp "${native}" "${EVIDENCE_ROOT}/native-manifests/${group}.sha256"
  source_head="$(dirname "${source}")/source-head.txt"
  if [[ -f "${source_head}" ]]; then
    [[ "$(<"${source_head}")" == "${EXPECTED_HEAD}" ]] \
      || fail "${group}: source head mismatch"
  else
    grep -Fq $'source_head\t'"${EXPECTED_HEAD}" \
      "$(dirname "${source}")/metadata.tsv" \
      || fail "${group}: metadata source head mismatch"
  fi
}

register_phase2() {
  local group=phase2 expected=390 source="$1"
  local actual native
  [[ -f "${source}" ]] || fail "missing Phase 2 all-rows: ${source}"
  actual="$(awk -F '\t' 'NR>1 && $3=="PASS" {n++} END{print n+0}' \
    "${source}")"
  [[ "${actual}" -eq "${expected}" ]] \
    || fail "Phase 2: expected ${expected}, got ${actual}"
  printf '%s\t%s\t%s\tPASS\n' "${group}" "${expected}" "${actual}" \
    >> "${EVIDENCE_ROOT}/row-audit.tsv"
  printf '%s\t%s\n' "${group}" "${source}" \
    >> "${EVIDENCE_ROOT}/provenance.tsv"
  cp "${source}" "${EVIDENCE_ROOT}/summaries/${group}.tsv"
  awk -F '\t' 'NR>1 {print "phase2\t" $0}' "${source}" \
    >> "${EVIDENCE_ROOT}/all-rows.tsv"
  native="$(dirname "${source}")/manifest.sha256"
  [[ -f "${native}" ]] || fail 'Phase 2 native manifest missing'
  (cd "$(dirname "${source}")" && sha256sum -c manifest.sha256 >/dev/null)
  cp "${native}" "${EVIDENCE_ROOT}/native-manifests/${group}.sha256"
  [[ "$(<"$(dirname "${source}")/source-head.txt")" == \
    "${EXPECTED_HEAD}" ]] || fail 'Phase 2 source head mismatch'
}

run_driver p35-performance \
  "${REPO_ROOT}/verification/bom/phase03-performance-closeout/run_performance_gate.sh"
register_direct p35-performance 20 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p35-performance-closeout/${TEST_ID}-p35-performance/summary.tsv"

run_driver p34-components \
  "${REPO_ROOT}/verification/bom/phase03-components-schema3/run_components_schema3_gate.sh"
register_direct p34-components 42 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p34-components-schema3/${TEST_ID}-p34-components/summary.tsv"

run_driver p33-ensemble \
  "${REPO_ROOT}/verification/bom/phase03-spring-ensemble/run_spring_ensemble_gate.sh"
register_direct p33-ensemble 34 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p33-spring-ensemble/${TEST_ID}-p33-ensemble/summary.tsv"

run_driver p32-cutoff \
  "${REPO_ROOT}/verification/bom/phase03-cutoff-graph/run_cutoff_graph_gate.sh"
register_direct p32-cutoff 18 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p32-cutoff-graph/${TEST_ID}-p32-cutoff/summary.tsv"

run_driver p31-reference \
  "${REPO_ROOT}/verification/bom/phase03-reference-laws/run_reference_law_gate.sh"
register_direct p31-reference 34 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p31-reference-laws/${TEST_ID}-p31-reference/summary.tsv"

log 'run exact Phase 2 predecessor closure'
closure_scope=P3.5
if [[ "${MODE}" == predecessor ]]; then
  closure_scope="${MITGCM_BOM_PREDECESSOR_CLOSURE_SCOPE:-P4.1}"
  [[ "${closure_scope}" == P4.1 || "${closure_scope}" == P4.2 ]] \
    || fail 'predecessor closure scope must be P4.1 or P4.2'
fi
env MITGCM_BOM_EXPECTED_HEAD="${EXPECTED_HEAD}" \
    MITGCM_BOM_TEST_ID="${TEST_ID}-phase2" \
    MITGCM_BOM_SCOPE_MODE=p35 \
    MITGCM_BOM_CLOSURE_SCOPE="${closure_scope}" \
    "${REPO_ROOT}/verification/bom/phase02-integration-closure/run_phase2_closure.sh" \
    > "${EVIDENCE_ROOT}/phase2.log" 2>&1
register_phase2 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-closure/${TEST_ID}-phase2/all-rows.tsv"

actual_total="$(awk -F '\t' 'NR>1 {sum+=$3} END{print sum+0}' \
  "${EVIDENCE_ROOT}/row-audit.tsv")"
[[ "${actual_total}" -eq "${EXPECTED_TOTAL}" ]] \
  || fail "aggregate expected ${EXPECTED_TOTAL}, got ${actual_total}"
printf 'TOTAL\t%s\t%s\tPASS\n' "${EXPECTED_TOTAL}" "${actual_total}" \
  >> "${EVIDENCE_ROOT}/row-audit.tsv"
printf '%s\n' "${EXPECTED_HEAD}" > "${EVIDENCE_ROOT}/source-head.txt"
printf '%s\n' "${MODE}" > "${EVIDENCE_ROOT}/mode.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${EVIDENCE_ROOT}/git-status.txt"
[[ ! -s "${EVIDENCE_ROOT}/git-status.txt" ]] \
  || fail 'tests changed the exact-head worktree'
git -C "${REPO_ROOT}" ls-files pkg/bom verification/bom/phase03-* \
  | while IFS= read -r path; do sha256sum "${REPO_ROOT}/${path}"; done \
  > "${EVIDENCE_ROOT}/source-files.sha256"
sha256sum "${CASE_DIR}"/*.sh "${CASE_DIR}"/*.py \
  > "${EVIDENCE_ROOT}/driver-files.sha256"

python3 "${CASE_DIR}/audit_p3_g99.py" \
  "${REPO_ROOT}" "${EVIDENCE_ROOT}" "${EXPECTED_HEAD}" \
  "${MODE}" "${EXPECTED_TOTAL}" \
  > "${EVIDENCE_ROOT}/independent-audit.log"
grep -q "P3-G99 ${MODE^^} AUDIT PASS" \
  "${EVIDENCE_ROOT}/independent-audit.log" \
  || fail 'independent audit marker missing'
(
  cd "${EVIDENCE_ROOT}"
  # manifest.sha256 is explicitly excluded from the input set below.
  # shellcheck disable=SC2094
  find . -type f ! -name manifest.sha256 ! -name manifest-check.log \
    -print0 | sort -z | xargs -0 sha256sum > manifest.sha256
  sha256sum -c manifest.sha256 > manifest-check.log
)
log "P3-G99 ${MODE^^} PASS (${EXPECTED_TOTAL}/${EXPECTED_TOTAL})"
log "source head: ${EXPECTED_HEAD}"
log "evidence root: ${EVIDENCE_ROOT}"
cat "${EVIDENCE_ROOT}/row-audit.tsv"
