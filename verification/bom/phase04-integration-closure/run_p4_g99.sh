#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:?set exact development head}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p4-g99-${EXPECTED_HEAD:0:10}-attempt01}"
readonly EVIDENCE_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p4-g99}/${TEST_ID}"
readonly REPLAY_ROOT="${MITGCM_BOM_REPLAY_ROOT:-/home/wyl/build/mitgcm-bom/phase04-integration-closure}/${TEST_ID}"
readonly EXPECTED_TOTAL=689

fail() { printf 'P4-G99 FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P4-G99] %s\n' "$*"; }

for command_name in awk bash cmp find git grep python3 rg sha256sum \
  shellcheck sort wc xargs; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || fail "missing ${command_name}"
done
[[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" == "${EXPECTED_HEAD}" ]] \
  || fail 'current HEAD differs from expected head'
[[ "$(git -C "${REPO_ROOT}" branch --show-current)" == \
  MITGCM-BOM/development ]] || fail 'development branch required'
[[ -z "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]] \
  || fail 'clean worktree required'
[[ "$(git -C "${REPO_ROOT}" rev-parse 'MITGCM-BOM-v0.4^{commit}')" == \
  70c02a277ea7d472ccf6e9a7533b2b41ed7eab5a ]] \
  || fail 'v0.4 release baseline changed'
[[ -z "$(git -C "${REPO_ROOT}" tag -l MITGCM-BOM-v0.5)" ]] \
  || fail 'P4-G99 must precede v0.5'
[[ ! -e "${EVIDENCE_ROOT}" ]] \
  || fail "evidence root exists: ${EVIDENCE_ROOT}"
[[ ! -e "${REPLAY_ROOT}" ]] \
  || fail "replay root exists: ${REPLAY_ROOT}"
mkdir -p "${EVIDENCE_ROOT}/summaries" \
  "${EVIDENCE_ROOT}/native-manifests" "${REPLAY_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${REPLAY_ROOT}/pycache" \
  python3 -m py_compile "${CASE_DIR}/audit_p4_g99.py"
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
      MITGCM_BOM_REQUIRE_CLEAN=1 \
      MITGCM_BOM_SCOPE_MODE=p44 \
      "${driver}" > "${EVIDENCE_ROOT}/${group}.log" 2>&1
  [[ -z "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]] \
    || fail "${group}: source tree changed"
}

register_direct() {
  local group="$1" expected="$2" source="$3" manifest_name="$4"
  local actual source_head artifact_dir
  [[ -f "${source}" ]] || fail "missing ${group} summary: ${source}"
  actual="$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END{print n+0}' \
    "${source}")"
  [[ "${actual}" -eq "${expected}" ]] \
    || fail "${group}: expected ${expected}, got ${actual}"
  artifact_dir="$(dirname "${source}")"
  source_head="${artifact_dir}/source-head.txt"
  [[ -f "${source_head}" && "$(<"${source_head}")" == \
    "${EXPECTED_HEAD}" ]] || fail "${group}: source head mismatch"
  case "${manifest_name}" in
    MANIFEST.sha256|SHA256SUMS)
      (cd "${artifact_dir}" && \
        sha256sum -c "${manifest_name}" >/dev/null)
      ;;
    summary.sha256)
      (cd "${artifact_dir}" && sha256sum -c summary.sha256 >/dev/null)
      ;;
    *) fail "${group}: unsupported native manifest" ;;
  esac
  printf '%s\t%s\t%s\tPASS\n' \
    "${group}" "${expected}" "${actual}" \
    >> "${EVIDENCE_ROOT}/row-audit.tsv"
  printf '%s\t%s\n' "${group}" "${source}" \
    >> "${EVIDENCE_ROOT}/provenance.tsv"
  cp "${source}" "${EVIDENCE_ROOT}/summaries/${group}.tsv"
  cp "${artifact_dir}/${manifest_name}" \
    "${EVIDENCE_ROOT}/native-manifests/${group}.sha256"
  awk -F '\t' -v package="${group}" \
    'NR>1 {print package "\t" package "\t" $0}' "${source}" \
    >> "${EVIDENCE_ROOT}/all-rows.tsv"
}

run_driver p41-direct \
  "${REPO_ROOT}/verification/bom/phase04-biology-land/run_p41_gate.sh"
register_direct p41-direct 31 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p41/${TEST_ID}-p41-direct/summary.tsv" \
  MANIFEST.sha256

run_driver p42-direct \
  "${REPO_ROOT}/verification/bom/phase04-biology-land/run_p42_gate.sh"
register_direct p42-direct 18 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p42/${TEST_ID}-p42-direct/summary.tsv" \
  SHA256SUMS

run_driver p43-direct \
  "${REPO_ROOT}/verification/bom/phase04-biology-land/run_p43_gate.sh"
register_direct p43-direct 26 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p43/${TEST_ID}-p43-direct/summary.tsv" \
  SHA256SUMS

run_driver p44-direct \
  "${REPO_ROOT}/verification/bom/phase04-biology-land/run_p44_gate.sh"
register_direct p44-direct 57 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p44/${TEST_ID}-p44-direct/summary.tsv" \
  summary.sha256

run_driver p45-b19 \
  "${REPO_ROOT}/verification/bom/phase04-biology-land/run_p45_gate.sh"
register_direct p45-b19 19 \
  "/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p45/${TEST_ID}-p45-b19/summary.tsv" \
  SHA256SUMS

log 'run exact 538-row v0.4 predecessor replay in isolated shared clone'
readonly REPLAY_REPO="${REPLAY_ROOT}/repo"
git clone --shared --no-checkout "${REPO_ROOT}" "${REPLAY_REPO}" \
  > "${EVIDENCE_ROOT}/replay-clone.log" 2>&1
git -C "${REPLAY_REPO}" checkout -B \
  MITGCM-BOM/p3.5-performance-closeout "${EXPECTED_HEAD}" \
  >> "${EVIDENCE_ROOT}/replay-clone.log" 2>&1
git -C "${REPLAY_REPO}" branch -f \
  MITGCM-BOM/development "${EXPECTED_HEAD}"
p3_id="${TEST_ID}-phase3-predecessor"
env MITGCM_BOM_EXPECTED_HEAD="${EXPECTED_HEAD}" \
    MITGCM_BOM_TEST_ID="${p3_id}" \
    MITGCM_BOM_INTEGRATION_MODE=predecessor \
    MITGCM_BOM_PREDECESSOR_CLOSURE_SCOPE=P4.4 \
    "${REPLAY_REPO}/verification/bom/phase03-integration-closure/run_p3_g99.sh" \
    > "${EVIDENCE_ROOT}/phase3-predecessor.log" 2>&1
p3_root="/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p3-g99/${p3_id}"
[[ "$(<"${p3_root}/source-head.txt")" == "${EXPECTED_HEAD}" ]] \
  || fail 'Phase 3 predecessor source head mismatch'
[[ "$(<"${p3_root}/mode.txt")" == predecessor ]] \
  || fail 'Phase 3 replay mode mismatch'
(cd "${p3_root}" && sha256sum -c manifest.sha256 >/dev/null)
p3_actual="$(awk -F '\t' 'NR>1 && $4=="PASS" {n++} END{print n+0}' \
  "${p3_root}/all-rows.tsv")"
[[ "${p3_actual}" -eq 538 ]] \
  || fail "Phase 3 predecessor expected 538, got ${p3_actual}"
printf 'phase3-predecessor\t538\t%s\tPASS\n' "${p3_actual}" \
  >> "${EVIDENCE_ROOT}/row-audit.tsv"
printf 'phase3-predecessor\t%s\n' "${p3_root}/all-rows.tsv" \
  >> "${EVIDENCE_ROOT}/provenance.tsv"
cp "${p3_root}/all-rows.tsv" \
  "${EVIDENCE_ROOT}/summaries/phase3-predecessor.tsv"
cp "${p3_root}/manifest.sha256" \
  "${EVIDENCE_ROOT}/native-manifests/phase3-predecessor.sha256"
awk -F '\t' 'NR>1 {print "phase3-predecessor\t" $1 "/" $2 \
  "\t" $3 "\t" $4 "\t" $5}' \
  "${p3_root}/all-rows.tsv" >> "${EVIDENCE_ROOT}/all-rows.tsv"

actual_total="$(awk -F '\t' 'NR>1 {sum+=$3} END{print sum+0}' \
  "${EVIDENCE_ROOT}/row-audit.tsv")"
[[ "${actual_total}" -eq "${EXPECTED_TOTAL}" ]] \
  || fail "aggregate expected ${EXPECTED_TOTAL}, got ${actual_total}"
printf 'TOTAL\t%s\t%s\tPASS\n' \
  "${EXPECTED_TOTAL}" "${actual_total}" \
  >> "${EVIDENCE_ROOT}/row-audit.tsv"
printf '%s\n' "${EXPECTED_HEAD}" > "${EVIDENCE_ROOT}/source-head.txt"
printf 'final\n' > "${EVIDENCE_ROOT}/mode.txt"
printf '%s\n' "${p3_root}" > "${EVIDENCE_ROOT}/p3-root.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${EVIDENCE_ROOT}/git-status.txt"
[[ ! -s "${EVIDENCE_ROOT}/git-status.txt" ]] \
  || fail 'tests changed the exact-head worktree'
git -C "${REPO_ROOT}" ls-files pkg/bom \
  verification/bom/phase04-biology-land \
  verification/bom/phase04-integration-closure \
  | while IFS= read -r path; do \
      sha256sum "${REPO_ROOT}/${path}"
    done > "${EVIDENCE_ROOT}/source-files.sha256"
sha256sum "${CASE_DIR}"/*.sh "${CASE_DIR}"/*.py \
  > "${EVIDENCE_ROOT}/driver-files.sha256"

python3 "${CASE_DIR}/audit_p4_g99.py" \
  "${REPO_ROOT}" "${EVIDENCE_ROOT}" "${EXPECTED_HEAD}" \
  "${EXPECTED_TOTAL}" > "${EVIDENCE_ROOT}/independent-audit.log"
grep -q 'P4-G99 FINAL AUDIT PASS' \
  "${EVIDENCE_ROOT}/independent-audit.log" \
  || fail 'independent P4-G99 marker missing'
(
  cd "${EVIDENCE_ROOT}"
  find . -type f ! -name manifest.sha256 ! -name manifest-check.log \
    -print0 | sort -z | xargs -0 sha256sum \
    > "${REPLAY_ROOT}/manifest.sha256"
  cp "${REPLAY_ROOT}/manifest.sha256" manifest.sha256
  sha256sum -c manifest.sha256 > manifest-check.log
)
log "P4-G99 FINAL PASS (${EXPECTED_TOTAL}/${EXPECTED_TOTAL})"
log "source head: ${EXPECTED_HEAD}"
log "evidence root: ${EVIDENCE_ROOT}"
cat "${EVIDENCE_ROOT}/row-audit.tsv"
