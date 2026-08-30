#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p45-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase04-biology-land}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase04-biology-land}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p45}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXPECTED_ROWS=19
readonly EXPECTED_SOURCE_HEAD="${MITGCM_BOM_EXPECTED_HEAD:-}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-0}"

fail() { printf 'P4.5 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P4.5] %s\n' "$*"; }
record_pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

for command_name in awk bash cmp find gfortran git grep make mpirun nm \
  sed sha256sum shellcheck sort uname uniq wc xargs; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || fail "missing ${command_name}"
done
for root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${root}" ]] || fail "evidence root exists: ${root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

source_head="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
printf '%s\n' "${source_head}" > "${RUN_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${RUN_ROOT}/git-status-before.txt"
[[ "${REQUIRE_CLEAN}" == 0 || "${REQUIRE_CLEAN}" == 1 ]] \
  || fail 'MITGCM_BOM_REQUIRE_CLEAN must be 0 or 1'
if [[ -n "${EXPECTED_SOURCE_HEAD}" \
   && "${source_head}" != "${EXPECTED_SOURCE_HEAD}" ]]; then
  fail "source head ${source_head}, expected ${EXPECTED_SOURCE_HEAD}"
fi
if [[ "${REQUIRE_CLEAN}" == 1 \
   && -s "${RUN_ROOT}/git-status-before.txt" ]]; then
  fail 'source tree is not clean at gate entry'
fi
{
  git --version
  gfortran --version | sed -n '1p'
  mpirun --version | sed -n '1p'
  uname -a
} > "${RUN_ROOT}/environment.txt"

cat > "${RUN_ROOT}/expected-rows.txt" <<'EOF'
p45-driver-audit
p45-source-audit
build-serial
build-mpi2
build-mpi4
b19-capacity-serial
b19-capacity-mpi2
b19-capacity-mpi4
b19-transaction-serial
b19-transaction-mpi2
b19-transaction-mpi4
b19-graph-serial
b19-graph-mpi2
b19-graph-mpi4
b19-rollback-serial
b19-rollback-mpi2
b19-rollback-mpi4
b19-decomposition
p45-manifest
EOF

bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
record_pass p45-driver-audit 'bash and shellcheck; frozen 19-row budget'

grep -q 'SUBROUTINE BOM_EVENT_PREFLIGHT' \
  "${REPO_ROOT}/pkg/bom/bom_event_preflight.F" \
  || fail 'event capacity preflight is absent'
grep -q 'CALL BOM_EVENT_PREFLIGHT' \
  "${REPO_ROOT}/pkg/bom/bom_event_transaction_p43.F" \
  || fail 'event transaction bypasses common capacity preflight'
[[ "$(grep -c 'CALL BOM_OWNER_EXCHANGE_PREFLIGHT' \
  "${REPO_ROOT}/pkg/bom/bom_particle_exchange.F")" -eq 2 ]] \
  || fail 'owner exchange does not preflight count and target capacities'
grep -Eq 'PARAMETER \( bomMaxPartTile[[:space:]]*= 8 \)' \
  "${CASE_DIR}/code/BOM_SIZE.h.p45" \
  || fail 'P4.5 compact tile limit is not frozen at eight'
grep -Eq 'PARAMETER \( bomMaxExchange[[:space:]]*= 4 \)' \
  "${CASE_DIR}/code/BOM_SIZE.h.p45" \
  || fail 'P4.5 exchange limit is not frozen at four'
grep -Eq 'PARAMETER \( bomMaxEventBuffer[[:space:]]*= 4 \)' \
  "${CASE_DIR}/code/BOM_SIZE.h.p45" \
  || fail 'P4.5 event limit is not frozen at four'
fixed_sources=(
  "${REPO_ROOT}/pkg/bom/bom_birth_order.F"
  "${REPO_ROOT}/pkg/bom/bom_event_preflight.F"
  "${REPO_ROOT}/pkg/bom/bom_event_transaction_p43.F"
  "${REPO_ROOT}/pkg/bom/bom_particle_exchange.F"
  "${REPO_ROOT}/pkg/bom/bom_spring_stage.F"
  "${CASE_DIR}/code/bom_init_varia_p45.F"
  "${CASE_DIR}/code/bom_verify_p45_capacity.F"
  "${CASE_DIR}/code/bom_verify_p45_transaction.F"
)
long_lines="$(awk 'length($0)>72 && $0 !~ /^[Cc*!#]/ {
  print FILENAME ":" FNR ":" length($0)
}' "${fixed_sources[@]}")"
[[ -z "${long_lines}" ]] \
  || fail "fixed-form executable line exceeds 72: ${long_lines}"
record_pass p45-source-audit \
  'common preflights, stable schemas, fixed form and bounded metadata'

build_case() {
  local name="$1" size_file="$2" mpi_enabled="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args symbols
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/BOM_SIZE.h.p45" "${mods_dir}/BOM_SIZE.h"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/packages.conf"
  cp "${CASE_DIR}/code/bom_init_varia_p45.F" \
    "${mods_dir}/bom_init_varia.F"
  cp "${CASE_DIR}/code/"bom_verify_p45_*.F "${mods_dir}/"
  args=("${REPO_ROOT}/tools/genmake2" "-rootdir=${REPO_ROOT}" \
    "-mods=${mods_dir}" "-of=${OPTFILE}" -ieee -devel)
  [[ "${mpi_enabled}" == yes ]] && args+=( -mpi )
  (
    cd "${build_dir}"
    "${args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable ${name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  symbols=(bom_event_preflight_ bom_owner_exchange_preflight_ \
    bom_verify_p45_capacity_ bom_verify_p45_transaction_ \
    bom_verify_p45_graph_)
  for symbol in "${symbols[@]}"; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${name}"
  done
  record_pass "build-${name}" \
    'debug/IEEE compile with production and B19 verifier symbols'
}

prepare_run() {
  local name="$1" build="$2" run_name="$3"
  local run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  sed -i "s/P41-PTRACER/${run_name}/" "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/data.bom.ptracer" "${run_dir}/data.bom"
  cp "${CASE_DIR}/input/data.ptracers" "${run_dir}/data.ptracers"
  ln -s "${BUILD_ROOT}/${build}/mitgcmuv" "${run_dir}/mitgcmuv"
}

run_case() {
  local name="$1" build="$2" ranks="$3" run_name="$4" marker="$5"
  local run_dir="${RUN_ROOT}/${name}"
  local combined="${run_dir}/combined.log"
  local rank rank_log
  prepare_run "${name}" "${build}" "${run_name}"
  if [[ "${ranks}" -eq 1 ]]; then
    (cd "${run_dir}" && ./mitgcmuv > run.log 2>&1)
    cp "${run_dir}/run.log" "${combined}"
  else
    (cd "${run_dir}" && mpirun -np "${ranks}" ./mitgcmuv \
      > mpi-launch.log 2>&1)
    : > "${combined}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      cat "${rank_log}" >> "${combined}"
    done
  fi
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${combined}" \
    || fail "normal end absent: ${name}"
  grep -q "${marker}" "${combined}" || fail "marker absent: ${name}"
  if grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE|P4.5 ASSERT FAIL' \
    "${combined}"; then
    fail "failure marker in positive verifier run: ${name}"
  fi
}

check_rollback() {
  local name="$1"
  local combined="${RUN_ROOT}/${name}/combined.log"
  local tag before after
  for tag in GLOBAL TILE BUFFER GRAPH; do
    before="${RUN_ROOT}/${name}/${tag}.before"
    after="${RUN_ROOT}/${name}/${tag}.after"
    sed -n 's/^.*P45-SNAP-/P45-SNAP-/p' "${combined}" \
      | awk -v tag="${tag}" '$2==tag && $3=="BEFORE" {$3="STATE"; print}' \
      | sort > "${before}"
    sed -n 's/^.*P45-SNAP-/P45-SNAP-/p' "${combined}" \
      | awk -v tag="${tag}" '$2==tag && $3=="AFTER" {$3="STATE"; print}' \
      | sort > "${after}"
    if [[ -s "${before}" || -s "${after}" ]]; then
      [[ -s "${before}" && -s "${after}" ]] \
        || fail "incomplete ${tag} snapshots: ${name}"
      cmp "${before}" "${after}" \
        || fail "${tag} authoritative rollback differs: ${name}"
    fi
  done
}

log 'building serial, MPI2 and MPI4 P4.5 B19 fixtures'
build_case serial SIZE.h.serial no
build_case mpi2 SIZE.h.mpi2 yes
build_case mpi4 SIZE.h.mpi4 yes

for spec in 'serial 1' 'mpi2 2' 'mpi4 4'; do
  read -r build ranks <<< "${spec}"
  run_case "capacity-${build}" "${build}" "${ranks}" \
    P45-CAPACITY 'B19-CAPACITY PASS:'
  record_pass "b19-capacity-${build}" \
    'global/tile/event/allgather/exchange/ID equality and overflow'
  run_case "transaction-${build}" "${build}" "${ranks}" \
    P45-TRANSACTION 'B19-ROLLBACK PASS:'
  record_pass "b19-transaction-${build}" \
    'global live, destination tile and full event-buffer fail closed'
  run_case "graph-${build}" "${build}" "${ranks}" \
    P45-GRAPH 'B19-GRAPH PASS:'
  grep -q 'B19-CANDIDATE PASS: equality 4/4 overflow 4/3 rollback' \
    "${RUN_ROOT}/graph-${build}/combined.log" \
    || fail "candidate equality/overflow marker absent: ${build}"
  grep -q 'B19-NEIGHBOR PASS: equality 3/3 overflow 3/2 rollback' \
    "${RUN_ROOT}/graph-${build}/combined.log" \
    || fail "neighbor equality/overflow marker absent: ${build}"
  grep -q 'B19-GHOST PASS: equality 4/4 overflow 5/4 rollback' \
    "${RUN_ROOT}/graph-${build}/combined.log" \
    || fail "ghost equality/overflow marker absent: ${build}"
  grep -Eq 'B19-GRAPH-OVERFLOW.*20[[:space:]]+8[[:space:]]+0' \
    "${RUN_ROOT}/graph-${build}/combined.log" \
    || fail "canonical neighbor graph failure absent: ${build}"
  record_pass "b19-graph-${build}" \
    'post-birth candidate, neighbor and ghost equality/overflow isolated'
  check_rollback "transaction-${build}"
  check_rollback "graph-${build}"
  record_pass "b19-rollback-${build}" \
    'owner/free/event/counter bit patterns are byte-identical on failure'
done

for build in serial mpi2 mpi4; do
  grep -h 'B19-.* PASS:' "${RUN_ROOT}"/*-${build}/combined.log \
    | sed 's/^.*B19-/B19-/' | sort \
    > "${RUN_ROOT}/${build}-markers.txt"
done
cmp "${RUN_ROOT}/serial-markers.txt" "${RUN_ROOT}/mpi2-markers.txt" \
  || fail 'serial and MPI2 B19 completion markers differ'
cmp "${RUN_ROOT}/serial-markers.txt" "${RUN_ROOT}/mpi4-markers.txt" \
  || fail 'serial and MPI4 B19 completion markers differ'
record_pass b19-decomposition \
  'serial, MPI2 and MPI4 execute the identical frozen B19 groups'

actual_rows="$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END {print n+0}' \
  "${RUN_ROOT}/summary.tsv")"
[[ "${actual_rows}" -eq $((EXPECTED_ROWS-1)) ]] \
  || fail "pre-manifest row count ${actual_rows}, expected $((EXPECTED_ROWS-1))"
record_pass p45-manifest 'evidence manifest and frozen row budget'

sort "${RUN_ROOT}/expected-rows.txt" > "${RUN_ROOT}/expected-rows.sorted"
awk -F '\t' 'NR>1 {print $1}' "${RUN_ROOT}/summary.tsv" \
  | sort > "${RUN_ROOT}/actual-rows.sorted"
cmp "${RUN_ROOT}/expected-rows.sorted" "${RUN_ROOT}/actual-rows.sorted" \
  || fail 'summary row names differ from the frozen list'
[[ "$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END {print n+0}' \
  "${RUN_ROOT}/summary.tsv")" -eq "${EXPECTED_ROWS}" ]] \
  || fail 'final PASS row count differs from expected'

git -C "${REPO_ROOT}" diff --check
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${RUN_ROOT}/git-status-after.txt"
if [[ "${REQUIRE_CLEAN}" == 1 ]]; then
  cmp "${RUN_ROOT}/git-status-before.txt" \
    "${RUN_ROOT}/git-status-after.txt" \
    || fail 'source tree changed while the gate ran'
fi
git -C "${REPO_ROOT}" diff --binary > "${RUN_ROOT}/source.diff"
cp -a "${RUN_ROOT}/." "${ARTIFACT_ROOT}/"
find "${ARTIFACT_ROOT}" -type f ! -name SHA256SUMS -print0 \
  | sort -z | xargs -0 sha256sum > "${ARTIFACT_ROOT}/SHA256SUMS"
printf 'P4.5 B19 GATE PASS: %s/%s\n' \
  "${EXPECTED_ROWS}" "${EXPECTED_ROWS}"
printf 'artifact: %s\n' "${ARTIFACT_ROOT}"
