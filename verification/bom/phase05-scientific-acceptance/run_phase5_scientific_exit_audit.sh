#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:?set exact candidate head}"
readonly G99_ROOT="${MITGCM_BOM_P5_SA_G99_ROOT:?set accepted P5-SA-G99 evidence root}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-phase5-scientific-exit-${EXPECTED_HEAD:0:10}-attempt01}"
readonly EVIDENCE_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/scientific-exit-audit}/${TEST_ID}"
readonly PYCACHE_ROOT="${MITGCM_BOM_PYCACHE_ROOT:-/home/wyl/build/mitgcm-bom/phase05-scientific-exit-audit}/${TEST_ID}-pycache"
readonly JULIA_BIN="${MITGCM_BOM_JULIA_BIN:-/home/wyl/tools/julia-1.10.12/bin/julia}"
readonly SARGASSUM_ROOT="${MITGCM_BOM_SARGASSUM_ROOT:-/home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl}"

fail() { printf 'PHASE 5 SCIENTIFIC EXIT AUDIT FAIL: %s\n' "$*" >&2; exit 1; }

for command_name in bash cmp find git grep python3 sha256sum shellcheck sort xargs; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || fail "missing command: ${command_name}"
done
[[ -x "${JULIA_BIN}" ]] || fail "locked Julia missing: ${JULIA_BIN}"
[[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" == "${EXPECTED_HEAD}" ]] \
  || fail 'current HEAD differs from expected candidate'
[[ "$(git -C "${REPO_ROOT}" branch --show-current)" == MITGCM-BOM/* ]] \
  || fail 'MITGCM-BOM candidate branch required'
[[ -z "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]] \
  || fail 'clean exact candidate worktree required'
[[ -d "${G99_ROOT}" ]] || fail "missing G99 root: ${G99_ROOT}"
[[ "$(<"${G99_ROOT}/source-head.txt")" == "${EXPECTED_HEAD}" ]] \
  || fail 'G99 source head differs from candidate'
[[ "$(<"${G99_ROOT}/mode.txt")" == scientific-candidate ]] \
  || fail 'G99 mode differs from scientific-candidate'
grep -q $'^TOTAL\t754\t754\tPASS$' "${G99_ROOT}/row-audit.tsv" \
  || fail 'G99 754/754 marker missing'
(cd "${G99_ROOT}" && sha256sum -c manifest.sha256 >/dev/null)
[[ ! -e "${EVIDENCE_ROOT}" ]] \
  || fail "evidence root exists: ${EVIDENCE_ROOT}"
[[ ! -e "${PYCACHE_ROOT}" ]] \
  || fail "pycache root exists: ${PYCACHE_ROOT}"
mkdir -p "${EVIDENCE_ROOT}" "${PYCACHE_ROOT}"
git -C "${REPO_ROOT}" show-ref --tags | sort \
  > "${EVIDENCE_ROOT}/tags-before.txt"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${PYCACHE_ROOT}" python3 -m py_compile \
  "${CASE_DIR}/audit_phase5_scientific_exit.py"
python3 "${CASE_DIR}/audit_phase5_scientific_exit.py" \
  "${REPO_ROOT}" "${EVIDENCE_ROOT}" "${EXPECTED_HEAD}" "${G99_ROOT}" \
  "${SARGASSUM_ROOT}" "${JULIA_BIN}" \
  > "${EVIDENCE_ROOT}/independent-exit-audit.log"
grep -q '^PHASE 5 SCIENTIFIC INDEPENDENT EXIT AUDIT PASS' \
  "${EVIDENCE_ROOT}/independent-exit-audit.log" \
  || fail 'independent scientific exit marker missing'
printf '%s\n' "${EXPECTED_HEAD}" > "${EVIDENCE_ROOT}/source-head.txt"
printf '%s\n' "${G99_ROOT}" > "${EVIDENCE_ROOT}/p5-sa-g99-root.txt"
printf 'scientific_acceptance\tPASS\n' \
  > "${EVIDENCE_ROOT}/acceptance-boundary.tsv"
printf 'hpc_acceptance\tNOT_EVALUATED\n' \
  >> "${EVIDENCE_ROOT}/acceptance-boundary.tsv"
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${EVIDENCE_ROOT}/git-status.txt"
[[ ! -s "${EVIDENCE_ROOT}/git-status.txt" ]] \
  || fail 'exit audit changed the exact candidate worktree'
git -C "${REPO_ROOT}" show-ref --tags | sort \
  > "${EVIDENCE_ROOT}/tags-after.txt"
cmp "${EVIDENCE_ROOT}/tags-before.txt" "${EVIDENCE_ROOT}/tags-after.txt" \
  || fail 'exit audit changed source tag refs'
sha256sum "${CASE_DIR}/run_p5_sa_g99.sh" \
  "${CASE_DIR}/audit_p5_sa_g99.py" \
  "${CASE_DIR}/run_phase5_scientific_exit_audit.sh" \
  "${CASE_DIR}/audit_phase5_scientific_exit.py" \
  > "${EVIDENCE_ROOT}/driver-files.sha256"
(
  cd "${EVIDENCE_ROOT}"
  find . -type f ! -name manifest.sha256 ! -name manifest-check.log \
    -print0 | sort -z | xargs -0 sha256sum \
    > "${PYCACHE_ROOT}/manifest.sha256"
  cp "${PYCACHE_ROOT}/manifest.sha256" manifest.sha256
  sha256sum -c manifest.sha256 > manifest-check.log
)
printf 'PHASE 5 SCIENTIFIC EXIT AUDIT PASS\n'
printf 'source head: %s\n' "${EXPECTED_HEAD}"
printf 'P5-SA-G99: 754/754\n'
printf 'decisions: 21/21\n'
printf 'HPC acceptance: NOT EVALUATED\n'
printf 'evidence root: %s\n' "${EVIDENCE_ROOT}"
cat "${EVIDENCE_ROOT}/independent-exit-audit.log"
