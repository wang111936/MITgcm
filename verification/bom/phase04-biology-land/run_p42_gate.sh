#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p42-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase04-biology-land}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase04-biology-land}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p42}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXPECTED_ROWS=18
readonly EXPECTED_SOURCE_HEAD="${MITGCM_BOM_EXPECTED_HEAD:-}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-0}"

fail() { printf 'P4.2 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P4.2] %s\n' "$*"; }
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
p42-driver-audit
p42-source-audit
build-serial
build-mpi4
p4-l01-serial
p4-f01-serial
p4-t01-serial
b11-serial
b13-death-serial
b11-rk-serial
p4-l01-mpi4
p4-f01-mpi4
p4-t01-mpi4
b11-mpi4
b13-death-mpi4
b11-rk-mpi4
p42-decomposition
p42-manifest
EOF

bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
record_pass p42-driver-audit 'bash and shellcheck'

grep -q 'SUBROUTINE BOM_CLASSIFY_BOUNDARY' \
  "${REPO_ROOT}/pkg/bom/bom_classify_boundary.F" \
  || fail 'boundary classifier is absent'
grep -q 'SUBROUTINE BOM_FREE_INIT' \
  "${REPO_ROOT}/pkg/bom/bom_free_stack.F" \
  || fail 'free-stack initializer is absent'
grep -q 'SUBROUTINE BOM_FREE_REMOVE' \
  "${REPO_ROOT}/pkg/bom/bom_free_stack.F" \
  || fail 'free-stack removal is absent'
grep -q 'SUBROUTINE BOM_FREE_ALLOC' \
  "${REPO_ROOT}/pkg/bom/bom_free_stack.F" \
  || fail 'free-stack allocation is absent'
grep -q 'SUBROUTINE BOM_FREE_VALIDATE' \
  "${REPO_ROOT}/pkg/bom/bom_free_stack.F" \
  || fail 'free-stack validator is absent'
grep -q 'SUBROUTINE BOM_EVENT_TRANSACTION' \
  "${REPO_ROOT}/pkg/bom/bom_terminal_plan.F" \
  || fail 'event transaction is absent'
grep -q 'SUBROUTINE BOM_RK2_SLOW_MIGRATE_P4' \
  "${REPO_ROOT}/pkg/bom/bom_rk2_slow_migrate.F" \
  || fail 'P4 RK2 boundary interface is absent'
grep -q 'SUBROUTINE BOM_RK4_SLOW_MIGRATE_P4' \
  "${REPO_ROOT}/pkg/bom/bom_rk4_slow_migrate.F" \
  || fail 'P4 RK4 boundary interface is absent'
if grep -RniE 'random_number|bomNextId.*=' \
  "${REPO_ROOT}/pkg/bom/bom_classify_boundary.F" \
  "${REPO_ROOT}/pkg/bom/bom_free_stack.F" \
  "${REPO_ROOT}/pkg/bom/bom_terminal_plan.F" \
  "${REPO_ROOT}/pkg/bom/bom_rk2_slow_migrate.F" \
  "${REPO_ROOT}/pkg/bom/bom_rk4_slow_migrate.F" \
  "${REPO_ROOT}/pkg/bom/bom_spring_ensemble.F" \
  "${REPO_ROOT}/pkg/bom/bom_particle_exchange.F"; then
  fail 'P4.2 core leaks P4.3 RNG/ID scope'
fi
grep -Eq 'PARAMETER \( bomPacketSchema[[:space:]]*= 2 \)' \
  "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
  || fail 'released owner packet schema changed'
grep -Eq 'PARAMETER \( bomP3ContainerSchema[[:space:]]*= 3 \)' \
  "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
  || fail 'released P3 container schema changed'
fixed_sources=(
  "${REPO_ROOT}/pkg/bom/bom_classify_boundary.F"
  "${REPO_ROOT}/pkg/bom/bom_free_stack.F"
  "${REPO_ROOT}/pkg/bom/bom_terminal_plan.F"
  "${REPO_ROOT}/pkg/bom/bom_normalize_x.F"
  "${REPO_ROOT}/pkg/bom/bom_rk2_slow_migrate.F"
  "${REPO_ROOT}/pkg/bom/bom_rk4_slow_migrate.F"
  "${REPO_ROOT}/pkg/bom/bom_spring_ensemble.F"
  "${REPO_ROOT}/pkg/bom/bom_particle_exchange.F"
  "${REPO_ROOT}/verification/bom/phase04-biology-land/code/bom_verify_p42_core.F"
)
long_lines="$(awk 'length($0)>72 && $0 !~ /^[Cc*!#]/ {
  print FILENAME ":" FNR ":" length($0)
}' "${fixed_sources[@]}")"
[[ -z "${long_lines}" ]] || fail "fixed-form executable line exceeds 72: ${long_lines}"
record_pass p42-source-audit \
  'P4.2 interfaces, fixed form and released schemas remain in scope'

build_case() {
  local name="$1" size_file="$2" mpi_enabled="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args symbols
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/packages.conf"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/"bom_verify_p41_*.F "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_p42_core.F" "${mods_dir}/"
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
  symbols=(bom_classify_boundary_ bom_free_init_ bom_free_validate_ \
    bom_free_remove_ bom_free_alloc_ bom_event_transaction_ \
    bom_rk2_slow_migrate_p4_ bom_rk4_slow_migrate_p4_ \
    bom_verify_p42_boundary_ bom_verify_p42_free_stack_)
  for symbol in "${symbols[@]}"; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${name}"
  done
  record_pass "build-${name}" 'debug/IEEE compile and P4.2 symbols'
}

prepare_run() {
  local name="$1" build="$2"
  local run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  sed -i 's/P41-PTRACER/P42-CORE/' "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/data.bom.ptracer" "${run_dir}/data.bom"
  cp "${CASE_DIR}/input/data.ptracers" "${run_dir}/data.ptracers"
  ln -s "${BUILD_ROOT}/${build}/mitgcmuv" "${run_dir}/mitgcmuv"
}

run_case() {
  local name="$1" build="$2" ranks="$3"
  local run_dir="${RUN_ROOT}/${name}"
  local combined="${run_dir}/combined.log"
  local rank rank_log
  prepare_run "${name}" "${build}"
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
  grep -q 'P4-L01 PASS:' "${combined}" || fail "P4-L01 absent: ${name}"
  grep -q 'P4-F01 PASS:' "${combined}" || fail "P4-F01 absent: ${name}"
  grep -q 'P4-T01/B11/B13 PASS:' "${combined}" \
    || fail "P4-T01/B11/B13 absent: ${name}"
  grep -q 'B11-RK PASS:' "${combined}" || fail "B11-RK absent: ${name}"
  record_pass "p4-l01-${name}" 'boundary classifier matrix'
  record_pass "p4-f01-${name}" 'compact-tail free-stack matrix'
  record_pass "p4-t01-${name}" 'event-phase rollback and canonical failure'
  record_pass "b11-${name}" 'distinct beached/outside terminal commit'
  record_pass "b13-death-${name}" 'biological death and immediate free reuse'
  record_pass "b11-rk-${name}" 'RK2/RK4 and spring rank-seam terminal path'
}

log 'building serial and MPI4 P4.2 direct fixtures'
build_case serial SIZE.h.serial no
build_case mpi4 SIZE.h.mpi4 yes
run_case serial serial 1
run_case mpi4 mpi4 4
record_pass p42-decomposition 'serial and MPI4 canonical P4.2 outcomes'

actual_rows="$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END {print n+0}' \
  "${RUN_ROOT}/summary.tsv")"
[[ "${actual_rows}" -eq $((EXPECTED_ROWS-1)) ]] \
  || fail "pre-manifest row count ${actual_rows}, expected $((EXPECTED_ROWS-1))"
record_pass p42-manifest 'evidence manifest and row budget'

sort "${RUN_ROOT}/expected-rows.txt" > "${RUN_ROOT}/expected-rows.sorted"
awk -F '\t' 'NR>1 {print $1}' "${RUN_ROOT}/summary.tsv" \
  | sort > "${RUN_ROOT}/actual-rows.sorted"
cmp "${RUN_ROOT}/expected-rows.sorted" "${RUN_ROOT}/actual-rows.sorted" \
  || fail 'summary row names differ from the frozen list'
[[ "$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END {print n+0}' \
  "${RUN_ROOT}/summary.tsv")" -eq "${EXPECTED_ROWS}" ]] \
  || fail 'final PASS row count differs from expected'

git -C "${REPO_ROOT}" diff --binary > "${RUN_ROOT}/source.diff"
cp -a "${RUN_ROOT}/." "${ARTIFACT_ROOT}/"
find "${ARTIFACT_ROOT}" -type f ! -name SHA256SUMS -print0 \
  | sort -z | xargs -0 sha256sum > "${ARTIFACT_ROOT}/SHA256SUMS"
printf 'P4.2 DIRECT GATE PASS: %s/%s\n' "${EXPECTED_ROWS}" "${EXPECTED_ROWS}"
printf 'artifact: %s\n' "${ARTIFACT_ROOT}"
