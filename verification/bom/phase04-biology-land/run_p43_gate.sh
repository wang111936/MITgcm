#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p43-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase04-biology-land}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase04-biology-land}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p43}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXPECTED_ROWS=26
readonly EXPECTED_SOURCE_HEAD="${MITGCM_BOM_EXPECTED_HEAD:-}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-0}"

fail() { printf 'P4.3 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P4.3] %s\n' "$*"; }
record_pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

for command_name in awk bash cmp find gfortran git grep make mpirun nm \
  python3 sed sha256sum shellcheck sort uname uniq wc xargs; do
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
p43-driver-audit
p43-source-audit
build-serial
build-mpi2
build-mpi4
p4-rng01-serial
p4-rng01-mpi2
p4-rng01-mpi4
p4-br01-serial
p4-br01-mpi2
p4-br01-mpi4
b13-serial
b13-mpi2
b13-mpi4
b14-serial
b14-mpi2
b14-mpi4
p4-m01-serial
p4-m01-mpi2
p4-m01-mpi4
b17-serial
b17-mpi2
b17-mpi4
b14-slot-permutation
p43-decomposition
p43-manifest
EOF

bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${BUILD_ROOT}/pycache" \
  python3 -m py_compile "${CASE_DIR}/reference/philox_oracle.py"
record_pass p43-driver-audit 'bash, shellcheck and Python oracle compile'

grep -q 'SUBROUTINE BOM_PHILOX4X32' \
  "${REPO_ROOT}/pkg/bom/bom_philox.F" \
  || fail 'Philox4x32-10 implementation is absent'
grep -q 'SUBROUTINE BOM_BIRTH_PLACE' \
  "${REPO_ROOT}/pkg/bom/bom_birth_place.F" \
  || fail 'birth placement implementation is absent'
grep -q 'SUBROUTINE BOM_BIRTH_PARENT_ORDER' \
  "${REPO_ROOT}/pkg/bom/bom_birth_order.F" \
  || fail 'prospective parent ordering is absent'
grep -q 'SUBROUTINE BOM_BIRTH_ACCEPT_ORDER' \
  "${REPO_ROOT}/pkg/bom/bom_birth_order.F" \
  || fail 'accepted child-ID ordering is absent'
grep -q 'SUBROUTINE BOM_EVENT_TRANSACTION_P43' \
  "${REPO_ROOT}/pkg/bom/bom_event_transaction_p43.F" \
  || fail 'P4.3 atomic event transaction is absent'
grep -q 'SUBROUTINE BOM_OWNER_PACKET_VALIDATE' \
  "${REPO_ROOT}/pkg/bom/bom_owner_packet_validate.F" \
  || fail 'P4.3 owner packet validator is absent'
grep -q 'CALL BOM_OWNER_PACKET_VALIDATE' \
  "${REPO_ROOT}/pkg/bom/bom_particle_exchange.F" \
  || fail 'owner exchange bypasses the packet validator'
grep -q 'CALL BOM_EVENT_TRANSACTION_P43' \
  "${REPO_ROOT}/pkg/bom/bom_main.F" \
  || fail 'biology main path does not call the P4.3 transaction'
if grep -Rni 'random_number' "${REPO_ROOT}/pkg/bom" --include='*.F'; then
  fail 'P4.3 production uses non-counter RNG'
fi
if grep -niE 'bom(NPartTile|Status|Id|X|Y)\(' \
  "${REPO_ROOT}/pkg/bom/bom_birth_order.F"; then
  fail 'birth-order collectives gather live owner state'
fi
grep -Eq 'PARAMETER \( bomPacketSchema[[:space:]]*= 2 \)' \
  "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" || fail 'schema2 ID changed'
grep -Eq 'PARAMETER \( bomPacketInts[[:space:]]*= 10 \)' \
  "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" || fail 'schema2 ints changed'
grep -Eq 'PARAMETER \( bomPacketReals[[:space:]]*= 6 \)' \
  "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" || fail 'schema2 reals changed'
grep -Eq 'PARAMETER \( bomPacketSchema3[[:space:]]*= 3 \)' \
  "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" || fail 'schema3 ID absent'
grep -Eq 'PARAMETER \( bomPacketInts3[[:space:]]*= 13 \)' \
  "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" || fail 'schema3 ints absent'
grep -Eq 'PARAMETER \( bomPacketReals3[[:space:]]*= 7 \)' \
  "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" || fail 'schema3 reals absent'
for size_header in \
  "${REPO_ROOT}/verification/bom/phase01-owner-migration/code/BOM_SIZE.h.small" \
  "${REPO_ROOT}/verification/bom/phase01-owner-migration/code/BOM_SIZE.h.tile-small" \
  "${REPO_ROOT}/verification/bom/phase03-performance-closeout/code/BOM_SIZE.h.performance"; do
  grep -Eq 'PARAMETER \( bomPacketSchema3[[:space:]]*= 3 \)' \
    "${size_header}" || fail "schema3 ID absent from ${size_header}"
  grep -Eq 'PARAMETER \( bomPacketInts3[[:space:]]*= 13 \)' \
    "${size_header}" || fail "schema3 ints absent from ${size_header}"
  grep -Eq 'PARAMETER \( bomPacketReals3[[:space:]]*= 7 \)' \
    "${size_header}" || fail "schema3 reals absent from ${size_header}"
done
fixed_sources=(
  "${REPO_ROOT}/pkg/bom/bom_philox.F"
  "${REPO_ROOT}/pkg/bom/bom_birth_place.F"
  "${REPO_ROOT}/pkg/bom/bom_birth_order.F"
  "${REPO_ROOT}/pkg/bom/bom_event_transaction_p43.F"
  "${REPO_ROOT}/pkg/bom/bom_owner_packet_validate.F"
  "${REPO_ROOT}/pkg/bom/bom_particle_exchange.F"
  "${REPO_ROOT}/pkg/bom/bom_main.F"
  "${CASE_DIR}/code/bom_init_varia_p43.F"
  "${CASE_DIR}/code/bom_verify_p43_rng.F"
  "${CASE_DIR}/code/bom_verify_p43_birth.F"
  "${CASE_DIR}/code/bom_verify_p43_event.F"
  "${CASE_DIR}/code/bom_verify_p43_packet.F"
)
long_lines="$(awk 'length($0)>72 && $0 !~ /^[Cc*!#]/ {
  print FILENAME ":" FNR ":" length($0)
}' "${fixed_sources[@]}")"
[[ -z "${long_lines}" ]] \
  || fail "fixed-form executable line exceeds 72: ${long_lines}"
record_pass p43-source-audit \
  'counter RNG, event-only collectives, schema2 freeze and fixed form'

build_case() {
  local name="$1" size_file="$2" mpi_enabled="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args symbols
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/packages.conf"
  cp "${CASE_DIR}/code/bom_init_varia_p43.F" \
    "${mods_dir}/bom_init_varia.F"
  cp "${CASE_DIR}/code/"bom_verify_p43_*.F "${mods_dir}/"
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
  symbols=(bom_philox4x32_ bom_birth_random_ bom_birth_place_ \
    bom_birth_parent_order_ bom_birth_accept_order_ \
    bom_event_transaction_p43_ bom_owner_packet_validate_ \
    bom_verify_p43_rng_ \
    bom_verify_p43_birth_ bom_verify_p43_event_ \
    bom_verify_p43_packet_)
  for symbol in "${symbols[@]}"; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${name}"
  done
  record_pass "build-${name}" 'debug/IEEE compile and P4.3 symbols'
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
  local name="$1" build="$2" ranks="$3" run_name="$4"
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
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${combined}"; then
    fail "fatal marker in positive run: ${name}"
  fi
}

log 'building serial, MPI2 and MPI4 P4.3 direct fixtures'
build_case serial SIZE.h.serial no
build_case mpi2 SIZE.h.mpi2 yes
build_case mpi4 SIZE.h.mpi4 yes

log 'running exact Philox oracle and Fortran fixtures'
python3 "${CASE_DIR}/reference/philox_oracle.py" \
  > "${RUN_ROOT}/philox-oracle.tsv"
[[ "$(wc -l < "${RUN_ROOT}/philox-oracle.tsv")" -eq 16 ]] \
  || fail 'independent Philox oracle row count differs from 16'
run_rng_case() {
  local name="$1" build="$2" ranks="$3"
  local combined="${RUN_ROOT}/${name}/combined.log"
  local canonical="${RUN_ROOT}/${name}/rng-canonical.txt"
  run_case "${name}" "${build}" "${ranks}" P43-RNG
  grep -q 'P4-RNG01 PASS: exact Philox words and angles' "${combined}" \
    || fail "P4-RNG01 exact fixture pass absent: ${name}"
  sed -n 's/^.*P43-RNG /P43-RNG /p' "${combined}" > "${canonical}"
  [[ "$(wc -l < "${canonical}")" -eq 13 ]] \
    || fail "Fortran Philox birth fixture count differs from 13: ${name}"
  record_pass "p4-rng01-${build}" \
    'independent oracle and exact Fortran words/angle bits'
}
run_rng_case rng-serial serial 1
run_rng_case rng-mpi2 mpi2 2
run_rng_case rng-mpi4 mpi4 4
cmp "${RUN_ROOT}/rng-serial/rng-canonical.txt" \
  "${RUN_ROOT}/rng-mpi2/rng-canonical.txt" \
  || fail 'serial and MPI2 exact Philox fixtures differ'
cmp "${RUN_ROOT}/rng-serial/rng-canonical.txt" \
  "${RUN_ROOT}/rng-mpi4/rng-canonical.txt" \
  || fail 'serial and MPI4 exact Philox fixtures differ'

run_birth_case() {
  local name="$1" build="$2" ranks="$3"
  run_case "${name}" "${build}" "${ranks}" P43-BIRTH
  grep -q 'P4-BR01/P4-ID01 PASS: retry, order and IDs' \
    "${RUN_ROOT}/${name}/combined.log" \
    || fail "P4-BR01/P4-ID01 pass absent: ${name}"
  record_pass "p4-br01-${build}" \
    'deterministic retry/cancel, global parent order and child IDs'
}

log 'running deterministic placement and global-ID fixtures'
run_birth_case birth-serial serial 1
run_birth_case birth-mpi2 mpi2 2
run_birth_case birth-mpi4 mpi4 4

run_event_case() {
  local name="$1" build="$2" ranks="$3"
  local combined="${RUN_ROOT}/${name}/combined.log"
  local canonical="${RUN_ROOT}/${name}/canonical.txt"
  run_case "${name}" "${build}" "${ranks}" P43-EVENT
  grep -q 'B13/B14/P4-M01/B17 PASS: atomic birth graph schema3' \
    "${combined}" || fail "P4.3 event pass absent: ${name}"
  sed -n -e 's/^.*P43-CANON /P43-CANON /p' \
    -e 's/^.*P43-EVENT-I /P43-EVENT-I /p' \
    -e 's/^.*P43-EVENT-R /P43-EVENT-R /p' "${combined}" \
    | sort > "${canonical}"
  [[ "$(wc -l < "${canonical}")" -eq 16 ]] \
    || fail "canonical owner/event row count differs from 16: ${name}"
  [[ "$(awk '$1=="P43-CANON" {print $2}' "${canonical}" \
      | sort -u | wc -l)" -eq 8 ]] \
    || fail "canonical IDs are not unique: ${name}"
  record_pass "b13-${build}" \
    'atomic death/birth/free-stack commit and injected rollback'
  record_pass "b14-${build}" \
    'accepted births use contiguous globally ordered child IDs'
  record_pass "p4-m01-${build}" \
    'schema3 migration preserves parent, birth count and S'
  record_pass "b17-${build}" \
    'post-event spring graph and component metadata are rebuilt'
}

log 'running atomic event, schema3 migration and graph fixtures'
run_event_case event-serial serial 1
run_event_case event-mpi2 mpi2 2
run_event_case event-mpi4 mpi4 4
run_case event-permuted serial 1 P43-EVENT-PERM
grep -q 'B13/B14/P4-M01/B17 PASS: atomic birth graph schema3' \
  "${RUN_ROOT}/event-permuted/combined.log" \
  || fail 'P4.3 permuted event pass absent'
sed -n -e 's/^.*P43-CANON /P43-CANON /p' \
  -e 's/^.*P43-EVENT-I /P43-EVENT-I /p' \
  -e 's/^.*P43-EVENT-R /P43-EVENT-R /p' \
  "${RUN_ROOT}/event-permuted/combined.log" \
  | sort > "${RUN_ROOT}/event-permuted/canonical.txt"
cmp "${RUN_ROOT}/event-serial/canonical.txt" \
  "${RUN_ROOT}/event-permuted/canonical.txt" \
  || fail 'canonical event result depends on owner slot order'
record_pass b14-slot-permutation \
  'permuted owner slots preserve exact owners and event records'
cmp "${RUN_ROOT}/event-serial/canonical.txt" \
  "${RUN_ROOT}/event-mpi2/canonical.txt" \
  || fail 'serial and MPI2 canonical post-event owners differ'
cmp "${RUN_ROOT}/event-serial/canonical.txt" \
  "${RUN_ROOT}/event-mpi4/canonical.txt" \
  || fail 'serial and MPI4 canonical post-event owners differ'
sha256sum "${RUN_ROOT}/event-serial/canonical.txt" \
  "${RUN_ROOT}/event-mpi2/canonical.txt" \
  "${RUN_ROOT}/event-mpi4/canonical.txt" \
  "${RUN_ROOT}/event-permuted/canonical.txt" \
  > "${RUN_ROOT}/canonical.sha256"
record_pass p43-decomposition \
  'serial, MPI2 and MPI4 canonical post-event owners are byte-identical'

actual_rows="$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END {print n+0}' \
  "${RUN_ROOT}/summary.tsv")"
[[ "${actual_rows}" -eq $((EXPECTED_ROWS-1)) ]] \
  || fail "pre-manifest row count ${actual_rows}, expected $((EXPECTED_ROWS-1))"
record_pass p43-manifest 'evidence manifest and frozen row budget'

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
printf 'P4.3 DIRECT GATE PASS: %s/%s\n' \
  "${EXPECTED_ROWS}" "${EXPECTED_ROWS}"
printf 'artifact: %s\n' "${ARTIFACT_ROOT}"
