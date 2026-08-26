#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p25-k01-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase02-coexistence-bom}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-k01}/${TEST_ID}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly P15_CASE="${REPO_ROOT}/verification/bom/phase01-output-pickup-coexistence"
readonly EXP4_INPUT="${REPO_ROOT}/verification/exp4/input.with_flt"
readonly BASE_ID="${MITGCM_BOM_K01_REUSE_BASE_ID:-${TEST_ID}-leew}"
readonly BASE_BUILD="/home/wyl/build/mitgcm-bom/phase01-output-pickup-coexistence/${BASE_ID}"
readonly BASE_RUN="/home/wyl/runs/mitgcm-bom/phase01-output-pickup-coexistence/${BASE_ID}"
readonly BASE_ARTIFACT="/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/${BASE_ID}"

fail() { printf 'P2.5 K01 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P2.5-k01] %s\n' "$*"; }
record_pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

for command_name in bash cmp find git grep mpirun python3 sed sha256sum shellcheck sort xargs; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing ${command_name}"
done
for fresh_root in "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${fresh_root}" ]] || fail "evidence root already exists: ${fresh_root}"
done
mkdir -p "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

if [[ -z "${MITGCM_BOM_K01_REUSE_BASE_ID:-}" ]]; then
  log "run self-contained LEEW coexistence matrix ${BASE_ID}"
  MITGCM_BOM_REQUIRE_CLEAN="${REQUIRE_CLEAN}" MITGCM_BOM_TEST_ID="${BASE_ID}" \
    "${P15_CASE}/run_coexistence_gate.sh" > "${RUN_ROOT}/leew-gate.log" 2>&1
fi
[[ -x "${BASE_BUILD}/serial-bom/mitgcmuv" ]] || fail 'missing LEEW serial BOM build'
[[ -x "${BASE_BUILD}/serial-both/mitgcmuv" ]] || fail 'missing LEEW serial both build'
[[ -x "${BASE_BUILD}/mpi2-bom/mitgcmuv" ]] || fail 'missing LEEW MPI2 BOM build'
[[ -x "${BASE_BUILD}/mpi2-both/mitgcmuv" ]] || fail 'missing LEEW MPI2 both build'
[[ "$(grep -c $'\tPASS\t' "${BASE_RUN}/summary.tsv")" -eq 25 ]] \
  || fail 'LEEW coexistence matrix is not 25/25'
record_pass p2-k01-leew \
  'neither/FLT/BOM/both serial/MPI2 LEEW matrix inherited at 25/25'

collect_logs() {
  local run_dir="$1" ranks="$2" rank rank_file
  : > "${run_dir}/combined.log"
  [[ ! -f "${run_dir}/mpi-launch.log" ]] || cat "${run_dir}/mpi-launch.log" >> "${run_dir}/combined.log"
  for ((rank=0; rank<ranks; rank++)); do
    printf -v rank_file '%s/STDOUT.%04d' "${run_dir}" "${rank}"
    cat "${rank_file}" >> "${run_dir}/combined.log"
    printf -v rank_file '%s/STDERR.%04d' "${run_dir}" "${rank}"
    cat "${rank_file}" >> "${run_dir}/combined.log"
  done
}

prepare_and_run() {
  local layout="$1" combination="$2" ranks="$3"
  local run_dir="${RUN_ROOT}/${layout}-${combination}" log_file
  log "run BOM mode ${layout}-${combination}"
  mkdir -p "${run_dir}"
  cp -a "${EXP4_INPUT}/." "${run_dir}/"
  sed -i -e 's/nTimeSteps=18,/nTimeSteps=12,/' \
    -e '/nTimeSteps=12,/a\ pChkptFreq=7200.,' "${run_dir}/data"
  if [[ "${combination}" == both ]]; then
    sed -i 's/useFLT=.FALSE./useFLT=.TRUE./' "${run_dir}/data.pkg"
  else
    sed -i 's/useFLT=.TRUE./useFLT=.FALSE./' "${run_dir}/data.pkg"
  fi
  sed -i '/useFLT=/a\ useBOM=.TRUE.,' "${run_dir}/data.pkg"
  cp "${P15_CASE}/input/data.bom.coexistence" "${run_dir}/data.bom"
  sed -i -e "s/bomMode='LEEW'/bomMode='BOM'/" \
    -e "/bomAdvCFL=/i\\ bomCurrentPolicy='EULERIAN',\\n bomAlpha=0.,\\n bomTauDays=0.0103,\\n bomR=0.823,\\n bomSigma=0.," \
    "${run_dir}/data.bom"
  python3 "${P15_CASE}/make_coexistence_bom.py" "${run_dir}" > "${run_dir}/bom-input.log"
  ln -s "${BASE_BUILD}/${layout}-${combination}/mitgcmuv" "${run_dir}/mitgcmuv"
  if [[ "${ranks}" -eq 1 ]]; then
    (cd "${run_dir}"; ./mitgcmuv > run.log 2>&1)
    log_file="${run_dir}/run.log"
  else
    (cd "${run_dir}"; mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1)
    collect_logs "${run_dir}" "${ranks}"
    log_file="${run_dir}/combined.log"
  fi
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" \
    || fail "normal end missing: ${layout}-${combination}"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE|particle failure' "${log_file}"; then
    fail "fatal marker: ${layout}-${combination}"
  fi
  record_pass "run-${layout}-${combination}" \
    'BOM schema 2; 12 steps; three exact IDs; normal end'
}

verify_case() {
  local layout="$1" combination="$2" npx="$3" nsx="$4"
  local run_dir="${RUN_ROOT}/${layout}-${combination}"
  python3 "${CASE_DIR}/verify_schema2.py" "${run_dir}" \
    --trajectory-suffix 0000000012 \
    --trajectory-output "${run_dir}/trajectory.tsv" \
    --trajectory-invariant "${run_dir}/trajectory-invariant.tsv" \
    --pickup-suffix 0000000012 \
    --pickup-output "${run_dir}/pickup.tsv" \
    --pickup-invariant "${run_dir}/pickup-invariant.tsv" \
    --endpoint-invariant "${run_dir}/endpoint.tsv" \
    --iteration 12 --time 7200 --frequency 3600 --next-time 10800 \
    --npx "${npx}" --npy 1 --nsx "${nsx}" --nsy 2 \
    --snx 40 --sny 21 --olx 3 --oly 3 \
    > "${run_dir}/verify.log"
  grep -q 'P2.5 SCHEMA-2 VERIFY PASS' "${run_dir}/verify.log" \
    || fail "schema-2 verifier marker missing: ${layout}-${combination}"
}

prepare_and_run serial bom 1
prepare_and_run serial both 1
prepare_and_run mpi2 bom 2
prepare_and_run mpi2 both 2
verify_case serial bom 1 2
verify_case serial both 1 2
verify_case mpi2 bom 2 1
verify_case mpi2 both 2 1

manifest_flt() {
  local run_dir="$1" output="$2"
  (
    cd "${run_dir}"
    find . -maxdepth 1 -type f \
      \( -name 'float_trajectories*' -o -name 'float_profiles*' -o -name 'pickup_flt*' \) \
      -print0 | sort -z | xargs -0 sha256sum
  ) > "${output}"
}

manifest_core() {
  local run_dir="$1" output="$2"
  (
    cd "${run_dir}"
    find . -maxdepth 1 -type f -name 'pickup.0000000012*' \
      -print0 | sort -z | xargs -0 sha256sum
  ) > "${output}"
}

for layout in serial mpi2; do
  for field in trajectory pickup endpoint; do
    cmp -s "${RUN_ROOT}/${layout}-bom/${field}.tsv" \
           "${RUN_ROOT}/${layout}-both/${field}.tsv" \
      || fail "BOM result changed with FLT enabled: ${layout}/${field}"
  done
  record_pass "p2-k01-bom-${layout}" \
    'BOM-only and FLT+BOM state, diagnostics, endpoints and schedule bitwise identical'

  manifest_flt "${BASE_RUN}/${layout}-flt" "${RUN_ROOT}/${layout}-flt-base.sha256"
  manifest_flt "${RUN_ROOT}/${layout}-both" "${RUN_ROOT}/${layout}-flt-bom.sha256"
  [[ -s "${RUN_ROOT}/${layout}-flt-base.sha256" ]] || fail "empty FLT baseline: ${layout}"
  cmp -s "${RUN_ROOT}/${layout}-flt-base.sha256" "${RUN_ROOT}/${layout}-flt-bom.sha256" \
    || fail "FLT output changed in BOM mode: ${layout}"
  record_pass "p2-k01-flt-${layout}" \
    'FLT-only and FLT+BOM(BOM mode) trajectory/pickup SHA-256 identical'

  manifest_core "${BASE_RUN}/${layout}-neither" "${RUN_ROOT}/${layout}-core-base.sha256"
  for combination in bom both; do
    manifest_core "${RUN_ROOT}/${layout}-${combination}" \
      "${RUN_ROOT}/${layout}-core-${combination}.sha256"
    cmp -s "${RUN_ROOT}/${layout}-core-base.sha256" \
           "${RUN_ROOT}/${layout}-core-${combination}.sha256" \
      || fail "core pickup changed: ${layout}-${combination}"
  done
  record_pass "p2-k01-core-${layout}" \
    'core permanent pickup unchanged by BOM mode or FLT coexistence'
done

for field in trajectory pickup; do
  cmp -s "${RUN_ROOT}/serial-bom/${field}-invariant.tsv" \
         "${RUN_ROOT}/mpi2-bom/${field}-invariant.tsv" \
    || fail "BOM serial/MPI2 invariant differs: ${field}"
done
cmp -s "${RUN_ROOT}/serial-bom/endpoint.tsv" \
       "${RUN_ROOT}/mpi2-bom/endpoint.tsv" \
  || fail 'BOM serial/MPI2 invariant differs: endpoint'
record_pass p2-k01-layout \
  'BOM-mode sorted state, diagnostics and endpoint interiors serial/MPI2 identical'

pass_count="$(grep -c $'\tPASS\t' "${RUN_ROOT}/summary.tsv")"
[[ "${pass_count}" -eq 12 ]] || fail "expected 12 PASS rows, found ${pass_count}"
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
cp "${BASE_RUN}/summary.tsv" "${ARTIFACT_ROOT}/leew-summary.tsv"
cp "${BASE_ARTIFACT}/manifest.sha256" "${ARTIFACT_ROOT}/leew-manifest.sha256"
git -C "${REPO_ROOT}" rev-parse HEAD > "${ARTIFACT_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 > "${ARTIFACT_ROOT}/git-status.txt"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv leew-summary.tsv leew-manifest.sha256 \
    source-head.txt git-status.txt > manifest.sha256
)
log "P2.5 K01 GATE PASS (${pass_count}/${pass_count})"
log "base build: ${BASE_BUILD}"
log "run root: ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
