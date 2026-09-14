#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:?set exact candidate head}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p5-sa-g99-${EXPECTED_HEAD:0:10}-attempt01}"
readonly BUILD_BASE="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase05-scientific-acceptance/p5-sa-g99}/${TEST_ID}/children"
readonly RUN_BASE="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase05-scientific-acceptance/p5-sa-g99}/${TEST_ID}/children"
readonly CHILD_ARTIFACT_BASE="${MITGCM_BOM_CHILD_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/scientific-acceptance}"
readonly EVIDENCE_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/scientific-acceptance/p5-sa-g99}/${TEST_ID}"
readonly REPLAY_ROOT="${MITGCM_BOM_REPLAY_ROOT:-/home/wyl/build/mitgcm-bom/phase05-scientific-acceptance/p5-sa-g99}/${TEST_ID}/replay"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-8}"
readonly JULIA_BIN="${MITGCM_BOM_JULIA_BIN:-/home/wyl/tools/julia-1.10.12/bin/julia}"
readonly SARGASSUM_ROOT="${MITGCM_BOM_SARGASSUM_ROOT:-/home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl}"
readonly V05_TAG_OBJECT=f16e2345cbe596f37fe3434d1b2f23f85ff0ba74
readonly V05_COMMIT=1f48a75d4865fa6d5235a4db306e8abe31534f3e
readonly V04_TAG_OBJECT=67ac22063a4860e30c504624f1530f853d29f1a2
readonly V04_COMMIT=70c02a277ea7d472ccf6e9a7533b2b41ed7eab5a
readonly EXPECTED_TOTAL=754
readonly P51_ID="${TEST_ID}-p51"
readonly P52_ID="${TEST_ID}-p52"
readonly P53_ID="${TEST_ID}-p53"
readonly P54_ID="${TEST_ID}-p54"
readonly P4_ID="${TEST_ID}-p4-predecessor"
readonly P51_ROOT="${CHILD_ARTIFACT_BASE}/${P51_ID}"
readonly P52_ROOT="${CHILD_ARTIFACT_BASE}/${P52_ID}"
readonly P53_ROOT="${CHILD_ARTIFACT_BASE}/${P53_ID}"
readonly P54_ROOT="/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/scientific-acceptance/${P54_ID}"
readonly P4_ARTIFACT_BASE="${EVIDENCE_ROOT}/phase4"
readonly P4_ROOT="${P4_ARTIFACT_BASE}/${P4_ID}"
readonly P4_REPLAY_BASE="${REPLAY_ROOT}/phase4-g99"
readonly P4_REPLAY_ROOT="${P4_REPLAY_BASE}/${P4_ID}"

CURRENT_GROUP=admission
CURRENT_CLASS=input/provenance
OUTCOME=FAIL
FINALIZED=0

log() { printf '[P5-SA-G99] %s\n' "$*"; }
fail() { printf 'P5-SA-G99 FAIL: %s\n' "$*" >&2; exit 1; }
block() { OUTCOME=BLOCKED; printf 'P5-SA-G99 BLOCKED: %s\n' "$*" >&2; exit 2; }
record_control() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${EVIDENCE_ROOT}/controls.tsv"
}

freeze_failure_evidence() {
  local root="$1"
  [[ -d "${root}" ]] || return 0
  find "${root}" -type f -exec chmod a-w {} + 2>/dev/null || true
  find "${root}" -depth -type d -exec chmod a-w {} + 2>/dev/null || true
}

on_exit() {
  local code="$?" manifest_tmp
  if [[ "${code}" -eq 0 || "${FINALIZED}" -eq 1 ]]; then
    return
  fi
  set +e
  mkdir -p "${EVIDENCE_ROOT}" "${REPLAY_ROOT}"
  printf 'outcome\tgroup\tclassification\texit_code\tsource_head\n' \
    > "${EVIDENCE_ROOT}/failure.tsv"
  printf '%s\t%s\t%s\t%s\t%s\n' "${OUTCOME}" "${CURRENT_GROUP}" \
    "${CURRENT_CLASS}" "${code}" "${EXPECTED_HEAD}" \
    >> "${EVIDENCE_ROOT}/failure.tsv"
  git -C "${REPO_ROOT}" status --porcelain=v1 \
    > "${EVIDENCE_ROOT}/git-status-at-failure.txt" 2>&1
  git -C "${REPO_ROOT}" show-ref --tags \
    > "${EVIDENCE_ROOT}/tags-at-failure.txt" 2>&1
  printf 'role\tpath\texists\n' > "${EVIDENCE_ROOT}/failure-roots.tsv"
  for entry in \
    "build-base:${BUILD_BASE}" "run-base:${RUN_BASE}" \
    "p51:${P51_ROOT}" "p52:${P52_ROOT}" "p53:${P53_ROOT}" \
    "p54:${P54_ROOT}" "p4:${P4_ROOT}" "replay:${REPLAY_ROOT}"; do
    local role="${entry%%:*}" path="${entry#*:}" exists=no
    [[ -e "${path}" ]] && exists=yes
    printf '%s\t%s\t%s\n' "${role}" "${path}" "${exists}" \
      >> "${EVIDENCE_ROOT}/failure-roots.tsv"
  done
  manifest_tmp="${REPLAY_ROOT}/failure-manifest.sha256"
  (
    cd "${EVIDENCE_ROOT}" || exit 0
    find . -type f ! -name failure-manifest.sha256 \
      ! -name failure-manifest-check.log -print0 \
      | sort -z | xargs -0 sha256sum > "${manifest_tmp}"
    cp "${manifest_tmp}" failure-manifest.sha256
    sha256sum -c failure-manifest.sha256 > failure-manifest-check.log
  )
  freeze_failure_evidence "${EVIDENCE_ROOT}"
  printf 'P5-SA-G99 %s: group=%s class=%s evidence=%s\n' \
    "${OUTCOME}" "${CURRENT_GROUP}" "${CURRENT_CLASS}" \
    "${EVIDENCE_ROOT}" >&2
}
trap on_exit EXIT

for command_name in awk bash chmod cmp find gfortran git grep make mpirun \
  nf-config python3 rg sed sha256sum shellcheck sort uname wc xargs; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || block "missing required command: ${command_name}"
done
[[ -x /usr/bin/time ]] || block 'missing /usr/bin/time'
[[ -x "${JULIA_BIN}" ]] || block "missing locked Julia: ${JULIA_BIN}"
[[ -d "${SARGASSUM_ROOT}/.git" || -f "${SARGASSUM_ROOT}/.git" ]] \
  || block "missing SargassumBOMB checkout: ${SARGASSUM_ROOT}"
[[ -f "${OPTFILE}" ]] || block "missing build optfile: ${OPTFILE}"
[[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" == "${EXPECTED_HEAD}" ]] \
  || fail 'current HEAD differs from expected candidate'
[[ "$(git -C "${REPO_ROOT}" branch --show-current)" == MITGCM-BOM/* ]] \
  || fail 'MITGCM-BOM candidate branch required'
[[ -z "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]] \
  || fail 'clean exact candidate worktree required'
[[ "$(git -C "${REPO_ROOT}" rev-parse MITGCM-BOM-v0.5)" == \
  "${V05_TAG_OBJECT}" ]] || fail 'v0.5 annotated tag object changed'
[[ "$(git -C "${REPO_ROOT}" rev-parse 'MITGCM-BOM-v0.5^{commit}')" == \
  "${V05_COMMIT}" ]] || fail 'v0.5 peeled commit changed'
git -C "${REPO_ROOT}" merge-base --is-ancestor "${V05_COMMIT}" \
  "${EXPECTED_HEAD}" || fail 'candidate does not descend from exact v0.5'

for fresh_root in "${BUILD_BASE}" "${RUN_BASE}" "${EVIDENCE_ROOT}" \
  "${REPLAY_ROOT}" "${P51_ROOT}" "${P52_ROOT}" "${P53_ROOT}" \
  "${P54_ROOT}"; do
  [[ ! -e "${fresh_root}" ]] || fail "fresh root exists: ${fresh_root}"
done
mkdir -p "${BUILD_BASE}" "${RUN_BASE}" "${EVIDENCE_ROOT}/summaries" \
  "${EVIDENCE_ROOT}/native-manifests" "${EVIDENCE_ROOT}/native-audits" \
  "${REPLAY_ROOT}"
printf 'control\tresult\tdetail\n' > "${EVIDENCE_ROOT}/controls.tsv"
printf 'group\texpected\tactual\tresult\n' \
  > "${EVIDENCE_ROOT}/row-audit-candidate.tsv"
printf 'group\texpected_head\tevidence_root\tsummary\tmanifest\tmode\n' \
  > "${EVIDENCE_ROOT}/provenance.tsv"
printf 'package\tgroup\tcase\tresult\tdetail\n' \
  > "${EVIDENCE_ROOT}/all-rows.tsv"
printf 'kind\tname\texpected\tactual\tresult\n' \
  > "${EVIDENCE_ROOT}/expected-actual-inventory.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${EVIDENCE_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" branch --show-current \
  > "${EVIDENCE_ROOT}/candidate-branch.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${EVIDENCE_ROOT}/git-status-before.txt"
git -C "${REPO_ROOT}" show-ref --tags | sort \
  > "${EVIDENCE_ROOT}/tags-before.txt"
git -C "${REPO_ROOT}" diff --name-status "${V05_COMMIT}...${EXPECTED_HEAD}" \
  > "${EVIDENCE_ROOT}/candidate-diff-from-v05.tsv"
printf '%s\n' scientific-candidate > "${EVIDENCE_ROOT}/mode.txt"
{
  uname -a
  git --version
  gfortran --version | sed -n '1p'
  mpirun --version | sed -n '1p'
  nf-config --version
  python3 --version
  "${JULIA_BIN}" --startup-file=no --version
  shellcheck --version | sed -n '1,2p'
  printf 'make_jobs=%s\noptfile=%s\nstack=%s\n' \
    "${MAKE_JOBS}" "${OPTFILE}" "$(ulimit -s)"
} > "${EVIDENCE_ROOT}/environment.txt"

bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${REPLAY_ROOT}/pycache" python3 -m py_compile \
  "${CASE_DIR}/audit_p5_sa_g99.py" \
  "${CASE_DIR}/audit_phase5_scientific_exit.py"
record_control driver-static 'aggregate/exit shell and Python drivers pass static checks'
record_control candidate-admission 'clean exact candidate and v0.5 tag/ancestry admitted'

register_direct() {
  local group="$1" expected="$2" root="$3" actual source_head
  [[ -d "${root}" ]] || fail "${group}: missing evidence root ${root}"
  (cd "${root}" && sha256sum -c manifest.sha256 >/dev/null)
  source_head="$(<"${root}/source-head.txt")"
  [[ "${source_head}" == "${EXPECTED_HEAD}" ]] \
    || fail "${group}: source head mismatch"
  actual="$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END{print n+0}' \
    "${root}/summary.tsv")"
  [[ "${actual}" -eq "${expected}" ]] \
    || fail "${group}: expected ${expected}, got ${actual}"
  python3 - "${root}/independent-audit.json" "${EXPECTED_HEAD}" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["result"] == "PASS"
assert report["source_head"] == sys.argv[2]
PY
  printf '%s\t%s\t%s\tPASS\n' "${group}" "${expected}" "${actual}" \
    >> "${EVIDENCE_ROOT}/row-audit-candidate.tsv"
  printf 'group\t%s\t%s\t%s\tPASS\n' "${group}" "${expected}" "${actual}" \
    >> "${EVIDENCE_ROOT}/expected-actual-inventory.tsv"
  printf '%s\t%s\t%s\t%s\t%s\tcandidate\n' \
    "${group}" "${EXPECTED_HEAD}" "${root}" "${root}/summary.tsv" \
    "${root}/manifest.sha256" >> "${EVIDENCE_ROOT}/provenance.tsv"
  cp "${root}/summary.tsv" "${EVIDENCE_ROOT}/summaries/${group}.tsv"
  cp "${root}/manifest.sha256" \
    "${EVIDENCE_ROOT}/native-manifests/${group}.sha256"
  cp "${root}/independent-audit.json" \
    "${EVIDENCE_ROOT}/native-audits/${group}.json"
  if [[ -f "${root}/independent-audit.log" ]]; then
    cp "${root}/independent-audit.log" \
      "${EVIDENCE_ROOT}/native-audits/${group}.log"
  fi
  awk -F '\t' -v package="${group}" \
    'NR>1 {print package "\t" package "\t" $0}' "${root}/summary.tsv" \
    >> "${EVIDENCE_ROOT}/all-rows.tsv"
  record_control "${group}" "fresh native gate ${actual}/${expected} and manifest pass"
}

CURRENT_GROUP=p5.1
CURRENT_CLASS=build/package
log 'run fresh P5.1 production build/input gate'
env MITGCM_BOM_TEST_ID="${P51_ID}" \
    MITGCM_BOM_TEST_BUILD_ROOT="${BUILD_BASE}" \
    MITGCM_BOM_TEST_RUN_ROOT="${RUN_BASE}" \
    MITGCM_BOM_TEST_ARTIFACT_ROOT="${CHILD_ARTIFACT_BASE}" \
    MITGCM_BOM_OPTFILE="${OPTFILE}" \
    MITGCM_BOM_MAKE_JOBS="${MAKE_JOBS}" \
    MITGCM_BOM_REQUIRE_CLEAN=yes \
    "${CASE_DIR}/run_p51_gate.sh" > "${EVIDENCE_ROOT}/p5.1.log" 2>&1
register_direct p5.1 18 "${P51_ROOT}"

CURRENT_GROUP=p5.2
CURRENT_CLASS='JULIA physics'
log 'run fresh P5.2 locked-Julia production gate'
env MITGCM_BOM_TEST_ID="${P52_ID}" \
    MITGCM_BOM_TEST_BUILD_ROOT="${BUILD_BASE}" \
    MITGCM_BOM_TEST_RUN_ROOT="${RUN_BASE}" \
    MITGCM_BOM_TEST_ARTIFACT_ROOT="${CHILD_ARTIFACT_BASE}" \
    MITGCM_BOM_OPTFILE="${OPTFILE}" \
    MITGCM_BOM_MAKE_JOBS="${MAKE_JOBS}" \
    MITGCM_BOM_REQUIRE_CLEAN=yes \
    MITGCM_BOM_JULIA_BIN="${JULIA_BIN}" \
    MITGCM_BOM_SARGASSUM_ROOT="${SARGASSUM_ROOT}" \
    "${CASE_DIR}/run_p52_gate.sh" > "${EVIDENCE_ROOT}/p5.2.log" 2>&1
register_direct p5.2 17 "${P52_ROOT}"

CURRENT_GROUP=p5.3
CURRENT_CLASS='PAPER2024 physics'
log 'run fresh P5.3 independent PAPER2024 gate'
env MITGCM_BOM_TEST_ID="${P53_ID}" \
    MITGCM_BOM_TEST_BUILD_ROOT="${BUILD_BASE}" \
    MITGCM_BOM_TEST_RUN_ROOT="${RUN_BASE}" \
    MITGCM_BOM_TEST_ARTIFACT_ROOT="${CHILD_ARTIFACT_BASE}" \
    MITGCM_BOM_OPTFILE="${OPTFILE}" \
    MITGCM_BOM_MAKE_JOBS="${MAKE_JOBS}" \
    MITGCM_BOM_REQUIRE_CLEAN=yes \
    MITGCM_BOM_JULIA_BIN="${JULIA_BIN}" \
    MITGCM_BOM_SARGASSUM_ROOT="${SARGASSUM_ROOT}" \
    "${CASE_DIR}/run_p53_gate.sh" > "${EVIDENCE_ROOT}/p5.3.log" 2>&1
register_direct p5.3 22 "${P53_ROOT}"

CURRENT_GROUP=p5.4
CURRENT_CLASS='restart/MPI'
log 'run fresh P5.4 released-feature/restart/endurance gate'
env MITGCM_BOM_REPO_ROOT="${REPO_ROOT}" \
    MITGCM_BOM_TEST_ID="${P54_ID}" \
    MITGCM_BOM_MAKE_JOBS="${MAKE_JOBS}" \
    "${CASE_DIR}/run_p54_gate.sh" > "${EVIDENCE_ROOT}/p5.4.log" 2>&1
register_direct p5.4 8 "${P54_ROOT}"

CURRENT_GROUP=phase4-predecessor
CURRENT_CLASS='integration/I/O'
log 'run exact 689-row Phase 4 predecessor on current candidate in a fresh clone'
readonly P4_REPO="${REPLAY_ROOT}/phase4-repo"
git clone --shared --no-checkout --no-tags "${REPO_ROOT}" "${P4_REPO}" \
  > "${EVIDENCE_ROOT}/phase4-clone.log" 2>&1
git -C "${P4_REPO}" checkout -B MITGCM-BOM/p4.5-capacity-exit \
  "${EXPECTED_HEAD}" >> "${EVIDENCE_ROOT}/phase4-clone.log" 2>&1
git -C "${P4_REPO}" branch -f MITGCM-BOM/development "${EXPECTED_HEAD}"
git -C "${P4_REPO}" fetch --no-tags "${REPO_ROOT}" \
  refs/tags/MITGCM-BOM-v0.4:refs/tags/MITGCM-BOM-v0.4 \
  >> "${EVIDENCE_ROOT}/phase4-clone.log" 2>&1
[[ "$(git -C "${P4_REPO}" rev-parse MITGCM-BOM-v0.4)" == \
  "${V04_TAG_OBJECT}" ]] || fail 'replay v0.4 tag object mismatch'
[[ "$(git -C "${P4_REPO}" rev-parse 'MITGCM-BOM-v0.4^{commit}')" == \
  "${V04_COMMIT}" ]] || fail 'replay v0.4 peeled commit mismatch'
[[ -z "$(git -C "${P4_REPO}" tag -l MITGCM-BOM-v0.5)" ]] \
  || fail 'isolated Phase 4 replay must not install v0.5 tag ref'
env MITGCM_BOM_EXPECTED_HEAD="${EXPECTED_HEAD}" \
    MITGCM_BOM_TEST_ID="${P4_ID}" \
    MITGCM_BOM_INTEGRATION_MODE=predecessor \
    MITGCM_BOM_PREDECESSOR_CLOSURE_SCOPE=P5.5 \
    MITGCM_BOM_TEST_ARTIFACT_ROOT="${P4_ARTIFACT_BASE}" \
    MITGCM_BOM_REPLAY_ROOT="${P4_REPLAY_BASE}" \
    "${P4_REPO}/verification/bom/phase04-integration-closure/run_p4_g99.sh" \
    > "${EVIDENCE_ROOT}/phase4-predecessor.log" 2>&1
(cd "${P4_ROOT}" && sha256sum -c manifest.sha256 >/dev/null)
[[ "$(<"${P4_ROOT}/source-head.txt")" == "${EXPECTED_HEAD}" ]] \
  || fail 'Phase 4 predecessor source head mismatch'
[[ "$(<"${P4_ROOT}/mode.txt")" == predecessor ]] \
  || fail 'Phase 4 predecessor mode mismatch'
p4_actual="$(awk -F '\t' 'NR>1 && $4=="PASS" {n++} END{print n+0}' \
  "${P4_ROOT}/all-rows.tsv")"
[[ "${p4_actual}" -eq 689 ]] \
  || fail "Phase 4 predecessor expected 689, got ${p4_actual}"
grep -q '^P4-G99 PREDECESSOR AUDIT PASS' \
  "${P4_ROOT}/independent-audit.log" \
  || fail 'Phase 4 predecessor independent marker missing'
printf 'phase4-predecessor\t689\t%s\tPASS\n' "${p4_actual}" \
  >> "${EVIDENCE_ROOT}/row-audit-candidate.tsv"
printf 'group\tphase4-predecessor\t689\t%s\tPASS\n' "${p4_actual}" \
  >> "${EVIDENCE_ROOT}/expected-actual-inventory.tsv"
printf 'phase4-predecessor\t%s\t%s\t%s\t%s\tpredecessor\n' \
  "${EXPECTED_HEAD}" "${P4_ROOT}" "${P4_ROOT}/all-rows.tsv" \
  "${P4_ROOT}/manifest.sha256" >> "${EVIDENCE_ROOT}/provenance.tsv"
cp "${P4_ROOT}/row-audit.tsv" \
  "${EVIDENCE_ROOT}/summaries/phase4-predecessor.tsv"
cp "${P4_ROOT}/manifest.sha256" \
  "${EVIDENCE_ROOT}/native-manifests/phase4-predecessor.sha256"
cp "${P4_ROOT}/independent-audit.log" \
  "${EVIDENCE_ROOT}/native-audits/phase4-predecessor.log"
awk -F '\t' 'NR>1 {print "phase4-predecessor\t" $1 "/" $2 \
  "\t" $3 "\t" $4 "\t" $5}' "${P4_ROOT}/all-rows.tsv" \
  >> "${EVIDENCE_ROOT}/all-rows.tsv"
record_control phase4-predecessor 'fresh current-head predecessor gate 689/689 and manifest pass'

actual_total="$(awk -F '\t' 'NR>1 {sum+=$3} END{print sum+0}' \
  "${EVIDENCE_ROOT}/row-audit-candidate.tsv")"
[[ "${actual_total}" -eq "${EXPECTED_TOTAL}" ]] \
  || fail "aggregate expected ${EXPECTED_TOTAL}, got ${actual_total}"
all_row_count="$(awk 'NR>1 {n++} END{print n+0}' \
  "${EVIDENCE_ROOT}/all-rows.tsv")"
[[ "${all_row_count}" -eq "${EXPECTED_TOTAL}" ]] \
  || fail "aggregate all-row count is ${all_row_count}"
printf 'TOTAL\t%s\t%s\tPASS\n' "${EXPECTED_TOTAL}" "${actual_total}" \
  >> "${EVIDENCE_ROOT}/row-audit-candidate.tsv"
printf 'aggregate\tall-rows\t%s\t%s\tPASS\n' \
  "${EXPECTED_TOTAL}" "${all_row_count}" \
  >> "${EVIDENCE_ROOT}/expected-actual-inventory.tsv"

{
  printf 'group\tartifact_root\tbuild_root\trun_root\n'
  printf 'p5.1\t%s\t%s\t%s\n' "${P51_ROOT}" \
    "${BUILD_BASE}/${P51_ID}" "${RUN_BASE}/${P51_ID}"
  printf 'p5.2\t%s\t%s\t%s\n' "${P52_ROOT}" \
    "${BUILD_BASE}/${P52_ID}" "${RUN_BASE}/${P52_ID}"
  printf 'p5.3\t%s\t%s\t%s\n' "${P53_ROOT}" \
    "${BUILD_BASE}/${P53_ID}" "${RUN_BASE}/${P53_ID}"
  printf 'p5.4\t%s\t%s\t%s\n' "${P54_ROOT}" \
    "/home/wyl/build/mitgcm-bom/phase05-scientific-acceptance/${P54_ID}" \
    "/home/wyl/runs/mitgcm-bom/phase05-scientific-acceptance/${P54_ID}"
  printf 'phase4-predecessor\t%s\t%s\t%s\n' "${P4_ROOT}" \
    "${P4_REPLAY_ROOT}" "${P4_REPLAY_ROOT}"
} > "${EVIDENCE_ROOT}/roots.tsv"

cat > "${EVIDENCE_ROOT}/acceptance-inventory.tsv" <<'EOF'
decision	case	group	locator	authority	result
P5-B01	production-packaging	p5.1	p5-b01-production-build	PRODUCTION	PASS
P5-I01	deterministic-input	p5.1	p5-i01-independent-audit	PRODUCTION	PASS
P5-J01	locked-julia	p5.2	p5-j01-julia-trajectory	JULIA	PASS
P5-P01	paper2024-parity	p5.3	p5-p01-paper-oracle	PAPER2024	PASS
P5-P02	paper2024-convergence	p5.3	p5-p02-temporal-convergence	PAPER2024	PASS
P5-F01	spring	p5.4	p5-f01-audit.json	PRODUCTION	PASS
P5-F01	birth	p5.4	p5-f01-audit.json	PRODUCTION	PASS
P5-F01	cancel	p5.4	p5-f01-audit.json	PRODUCTION	PASS
P5-F01	death	p5.4	p5-f01-audit.json	PRODUCTION	PASS
P5-F01	coast	p5.4	p5-f01-audit.json	PRODUCTION	PASS
P5-F01	combined	p5.4	p5-f01-audit.json	PRODUCTION	PASS
P5-O01	dynamic-ocean	p5.4	p5-o01-audit.json	PRODUCTION	PASS
P5-R01	restart-mpi	p5.4	p5-r01-audit.json	PRODUCTION	PASS
P5-L01	endurance	p5.4	p5-l01-audit.json	PRODUCTION	PASS
EOF
while IFS=$'\t' read -r decision case _group _locator _authority result; do
  [[ "${decision}" == decision ]] && continue
  printf 'case\t%s/%s\t1\t1\t%s\n' "${decision}" "${case}" "${result}" \
    >> "${EVIDENCE_ROOT}/expected-actual-inventory.tsv"
done < "${EVIDENCE_ROOT}/acceptance-inventory.tsv"

CURRENT_GROUP=source-package-isolation
CURRENT_CLASS=input/provenance
if find "${CASE_DIR}" -path '*/code/*' -type f -iname 'bom_*.F' \
  -print -quit | grep -q .; then
  fail 'production BOM source override found under Phase 5 code mods'
fi
if git -C "${REPO_ROOT}" diff --name-only "${V05_COMMIT}...${EXPECTED_HEAD}" \
  | grep -Eiq '(^|/)(skrips|codex)(/|$)'; then
  fail 'foreign project path present in candidate diff'
fi
record_control source-package-isolation 'no production override, foreign path or source-tree mutation'

printf 'item\texpected\tactual\tresult\n' > "${EVIDENCE_ROOT}/reference-locks.tsv"
record_lock() {
  local item="$1" expected="$2" actual="$3" result=FAIL
  [[ "${actual}" == "${expected}" ]] && result=PASS
  printf '%s\t%s\t%s\t%s\n' "${item}" "${expected}" "${actual}" \
    "${result}" >> "${EVIDENCE_ROOT}/reference-locks.tsv"
  [[ "${result}" == PASS ]] || fail "reference lock changed: ${item}"
}
record_lock scientific-plan \
  c9d2372d132e48d55b213db293c84cfe67006cf29fa6d7aa2fdfb4b545aefafe \
  "$(sha256sum "${CASE_DIR}/SCIENTIFIC_ACCEPTANCE_PLAN.md" | awk '{print $1}')"
record_lock p53-contract \
  c321e9ac8edce06ec7371520e95df77b59bfc805f082a0263ed18ac9b8509275 \
  "$(sha256sum "${CASE_DIR}/P5.3_TEST_CONTRACT.md" | awk '{print $1}')"
record_lock p53-fixture-lock \
  078ec8ffb0846463d81e2f75e0312f9e5d36bc002a7ea4983c5a38373dcb404b \
  "$(sha256sum "${CASE_DIR}/P5.3_P02_FIXTURE_LOCK.md" | awk '{print $1}')"
record_lock p53-affine-fixture \
  39191181950409246d793257f8f58e63106ed2e9657733018103b9c46d46ce4e \
  "$(sha256sum "${CASE_DIR}/p53_p02_affine_fields.csv" | awk '{print $1}')"
record_lock p54-contract \
  40febed4351dcd592732e4236801b1829cbc92ba422a5e4800afde7dac200f83 \
  "$(sha256sum "${CASE_DIR}/P5.4_TEST_CONTRACT.md" | awk '{print $1}')"
record_lock julia-project \
  12cfb1288a21b19216662a719d430bf41b5587dfd8b00e973f8b3c9c25f1f99d \
  "$(sha256sum "${REPO_ROOT}/verification/bom/reference/julia_env/Project.toml" | awk '{print $1}')"
record_lock julia-manifest \
  86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695 \
  "$(sha256sum "${REPO_ROOT}/verification/bom/reference/julia_env/Manifest.toml" | awk '{print $1}')"
record_lock phase2-golden-inventory \
  040a001482247088195f8db11538312ba8dbe5a972a1f14f78799b7800d2ab03 \
  "$(sha256sum "${REPO_ROOT}/verification/bom/reference/phase02/golden_checksums.sha256" | awk '{print $1}')"
record_lock sargassum-head \
  156557359185e4413ce82829f3ed26a4eb8c6283 \
  "$(git -C "${SARGASSUM_ROOT}" rev-parse HEAD)"
record_lock sargassum-physics \
  1acef9ed3c8d13646c95799565387a4add76e839827cea1c0e745ced73f1885d \
  "$(sha256sum "${SARGASSUM_ROOT}/src/physics.jl" | awk '{print $1}')"
record_lock julia-version 'julia version 1.10.12' \
  "$("${JULIA_BIN}" --startup-file=no --version)"
record_control reference-locks 'plan, fixtures, Julia, PAPER2024 and golden authorities match frozen hashes'
record_control expected-actual-inventory 'five groups, 754 rows and fourteen required case entries agree exactly'

git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${EVIDENCE_ROOT}/git-status-after.txt"
[[ ! -s "${EVIDENCE_ROOT}/git-status-after.txt" ]] \
  || fail 'P5-SA-G99 changed the exact candidate worktree'
git -C "${REPO_ROOT}" show-ref --tags | sort \
  > "${EVIDENCE_ROOT}/tags-after.txt"
cmp "${EVIDENCE_ROOT}/tags-before.txt" "${EVIDENCE_ROOT}/tags-after.txt" \
  || fail 'P5-SA-G99 changed source tag refs'
record_control tag-invariance 'source tag refs unchanged; gate created no tag'
(
  cd "${REPO_ROOT}"
  git ls-files -z pkg/bom eesupp/src/ini_procs.F \
    verification/bom/reference \
    verification/bom/phase02-integration-closure \
    verification/bom/phase03-integration-closure \
    verification/bom/phase04-integration-closure \
    verification/bom/phase05-scientific-acceptance \
    | sort -z | xargs -0 sha256sum \
    > "${EVIDENCE_ROOT}/source-files.sha256"
)
sha256sum "${CASE_DIR}"/run_p5_sa_g99.sh \
  "${CASE_DIR}"/audit_p5_sa_g99.py \
  "${CASE_DIR}"/run_phase5_scientific_exit_audit.sh \
  "${CASE_DIR}"/audit_phase5_scientific_exit.py \
  > "${EVIDENCE_ROOT}/driver-files.sha256"

CURRENT_GROUP=independent-G99-evidence-audit
CURRENT_CLASS=input/provenance
python3 "${CASE_DIR}/audit_p5_sa_g99.py" \
  "${REPO_ROOT}" "${EVIDENCE_ROOT}" "${EXPECTED_HEAD}" \
  "${EXPECTED_TOTAL}" "${SARGASSUM_ROOT}" "${JULIA_BIN}" \
  > "${EVIDENCE_ROOT}/independent-audit.log"
grep -q '^P5-SA-G99 INDEPENDENT AUDIT PASS' \
  "${EVIDENCE_ROOT}/independent-audit.log" \
  || fail 'independent P5-SA-G99 marker missing'
cp "${EVIDENCE_ROOT}/row-audit-candidate.tsv" \
  "${EVIDENCE_ROOT}/row-audit.tsv"
record_control independent-G99-evidence-audit 'independent exact-row, case, authority and provenance audit passes'
(
  cd "${EVIDENCE_ROOT}"
  find . -type f ! -name manifest.sha256 ! -name manifest-check.log \
    -print0 | sort -z | xargs -0 sha256sum \
    > "${REPLAY_ROOT}/manifest.sha256"
  cp "${REPLAY_ROOT}/manifest.sha256" manifest.sha256
  sha256sum -c manifest.sha256 > manifest-check.log
)
FINALIZED=1
OUTCOME=PASS
log "P5-SA-G99 PASS (${EXPECTED_TOTAL}/${EXPECTED_TOTAL})"
log "source head: ${EXPECTED_HEAD}"
log "evidence root: ${EVIDENCE_ROOT}"
cat "${EVIDENCE_ROOT}/row-audit.tsv"
