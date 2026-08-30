#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:?set exact development head}"
readonly P45_HEAD="${MITGCM_BOM_P45_PACKAGE_HEAD:?set exact P4.5 package head}"
readonly G99_ROOT="${MITGCM_BOM_P4_G99_ROOT:?set accepted P4-G99 evidence root}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-phase4-exit-${EXPECTED_HEAD:0:10}-attempt01}"
readonly EVIDENCE_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/exit-audit}/${TEST_ID}"
readonly PYCACHE_ROOT="${MITGCM_BOM_PYCACHE_ROOT:-/home/wyl/build/mitgcm-bom/phase04-integration-closure/${TEST_ID}-pycache}"

fail() { printf 'PHASE 4 EXIT AUDIT FAIL: %s\n' "$*" >&2; exit 1; }

for command_name in bash find git grep python3 sha256sum shellcheck sort xargs; do
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
  || fail 'exit audit must precede v0.5'
[[ -d "${G99_ROOT}" ]] || fail "missing P4-G99 root: ${G99_ROOT}"
[[ "$(<"${G99_ROOT}/source-head.txt")" == "${EXPECTED_HEAD}" ]] \
  || fail 'P4-G99 source head mismatch'
[[ "$(<"${G99_ROOT}/mode.txt")" == final ]] \
  || fail 'P4-G99 mode is not final'
(cd "${G99_ROOT}" && sha256sum -c manifest.sha256 >/dev/null)
grep -q $'^TOTAL\t689\t689\tPASS$' "${G99_ROOT}/row-audit.tsv" \
  || fail 'P4-G99 689/689 marker missing'
[[ ! -e "${EVIDENCE_ROOT}" ]] \
  || fail "evidence root exists: ${EVIDENCE_ROOT}"
[[ ! -e "${PYCACHE_ROOT}" ]] \
  || fail "pycache root exists: ${PYCACHE_ROOT}"
mkdir -p "${EVIDENCE_ROOT}"
mkdir -p "${PYCACHE_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${PYCACHE_ROOT}" \
  python3 -m py_compile "${CASE_DIR}/audit_phase4_exit.py"
python3 "${CASE_DIR}/audit_phase4_exit.py" \
  "${REPO_ROOT}" "${EVIDENCE_ROOT}" "${EXPECTED_HEAD}" \
  "${G99_ROOT}" "${P45_HEAD}" \
  > "${EVIDENCE_ROOT}/independent-exit-audit.log"
grep -q 'PHASE 4 INDEPENDENT EXIT AUDIT PASS' \
  "${EVIDENCE_ROOT}/independent-exit-audit.log" \
  || fail 'independent exit marker missing'
printf '%s\n' "${EXPECTED_HEAD}" > "${EVIDENCE_ROOT}/source-head.txt"
printf '%s\n' "${P45_HEAD}" > "${EVIDENCE_ROOT}/p45-package-head.txt"
printf '%s\n' "${G99_ROOT}" > "${EVIDENCE_ROOT}/p4-g99-root.txt"
printf 'final\n' > "${EVIDENCE_ROOT}/mode.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${EVIDENCE_ROOT}/git-status.txt"
[[ ! -s "${EVIDENCE_ROOT}/git-status.txt" ]] \
  || fail 'audit changed the exact-head worktree'
sha256sum "${CASE_DIR}"/*.sh "${CASE_DIR}"/*.py \
  > "${EVIDENCE_ROOT}/driver-files.sha256"
(
  cd "${EVIDENCE_ROOT}"
  find . -type f ! -name manifest.sha256 \
    ! -name manifest-check.log -print0 \
    | sort -z | xargs -0 sha256sum \
    > "${PYCACHE_ROOT}/manifest.sha256"
  cp "${PYCACHE_ROOT}/manifest.sha256" manifest.sha256
  sha256sum -c manifest.sha256 > manifest-check.log
)
printf 'PHASE 4 EXIT AUDIT PASS\n'
printf 'source head: %s\n' "${EXPECTED_HEAD}"
printf 'P4-G99: 689/689\n'
printf 'evidence root: %s\n' "${EVIDENCE_ROOT}"
cat "${EVIDENCE_ROOT}/independent-exit-audit.log"
