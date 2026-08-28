#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:?set integrated development head}"
readonly P34_HEAD="${MITGCM_BOM_P34_PACKAGE_HEAD:-38fd1824ff2ad69ce439f0c144cb3d5ab4d71ba3}"
readonly P35_HEAD="${MITGCM_BOM_P35_PACKAGE_HEAD:?set final P3.5 package head}"
readonly G99_ROOT="${MITGCM_BOM_P3_G99_ROOT:?set final P3-G99 evidence root}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-phase3-exit-${EXPECTED_HEAD:0:10}-attempt01}"
readonly EVIDENCE_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/phase3-exit-audit}/${TEST_ID}"

fail() { printf 'PHASE 3 EXIT AUDIT FAIL: %s\n' "$*" >&2; exit 1; }
for command_name in bash git grep python3 sha256sum shellcheck; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || fail "missing ${command_name}"
done
[[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" == "${EXPECTED_HEAD}" ]] \
  || fail 'current head mismatch'
[[ "$(git -C "${REPO_ROOT}" branch --show-current)" == \
  MITGCM-BOM/development ]] || fail 'development branch required'
[[ -z "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]] \
  || fail 'clean worktree required'
[[ -z "$(git -C "${REPO_ROOT}" tag -l MITGCM-BOM-v0.4)" ]] \
  || fail 'exit audit must precede v0.4 tag creation'
[[ -d "${G99_ROOT}" ]] || fail "missing P3-G99 root: ${G99_ROOT}"
[[ ! -e "${EVIDENCE_ROOT}" ]] \
  || fail "evidence root exists: ${EVIDENCE_ROOT}"
mkdir -p "${EVIDENCE_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
python3 -m py_compile "${CASE_DIR}/audit_phase3_exit.py"
(
  cd "${G99_ROOT}"
  sha256sum -c manifest.sha256 > "${EVIDENCE_ROOT}/g99-manifest-check.log"
)
python3 "${CASE_DIR}/audit_phase3_exit.py" \
  "${REPO_ROOT}" "${G99_ROOT}" "${EXPECTED_HEAD}" \
  "${P34_HEAD}" "${P35_HEAD}" \
  > "${EVIDENCE_ROOT}/independent-audit.log"
grep -q 'PHASE3 INDEPENDENT EXIT AUDIT PASS' \
  "${EVIDENCE_ROOT}/independent-audit.log" \
  || fail 'independent exit marker missing'
printf '%s\n' "${EXPECTED_HEAD}" > "${EVIDENCE_ROOT}/source-head.txt"
printf '%s\n' "${P34_HEAD}" > "${EVIDENCE_ROOT}/p34-package-head.txt"
printf '%s\n' "${P35_HEAD}" > "${EVIDENCE_ROOT}/p35-package-head.txt"
printf '%s\n' "${G99_ROOT}" > "${EVIDENCE_ROOT}/p3-g99-root.txt"
sha256sum "${CASE_DIR}"/*.sh "${CASE_DIR}"/*.py \
  > "${EVIDENCE_ROOT}/driver-files.sha256"
(
  cd "${EVIDENCE_ROOT}"
  # manifest.sha256 is explicitly excluded from the input set below.
  # shellcheck disable=SC2094
  find . -type f ! -name manifest.sha256 ! -name manifest-check.log \
    -print0 | sort -z | xargs -0 sha256sum > manifest.sha256
  sha256sum -c manifest.sha256 > manifest-check.log
)
printf 'PHASE 3 EXIT AUDIT PASS\n'
printf 'source head: %s\n' "${EXPECTED_HEAD}"
printf 'evidence root: %s\n' "${EVIDENCE_ROOT}"
cat "${EVIDENCE_ROOT}/independent-audit.log"
