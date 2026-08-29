#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p41-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase04-biology-land}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase04-biology-land}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p41}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXPECTED_ROWS=31
readonly EXPECTED_SOURCE_HEAD="${MITGCM_BOM_EXPECTED_HEAD:-}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-0}"
readonly SCOPE_MODE="${MITGCM_BOM_SCOPE_MODE:-p41}"

fail() { printf 'P4.1 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P4.1] %s\n' "$*"; }
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
[[ "${SCOPE_MODE}" == p41 || "${SCOPE_MODE}" == p42 \
   || "${SCOPE_MODE}" == p43 || "${SCOPE_MODE}" == p44 ]] \
  || fail 'MITGCM_BOM_SCOPE_MODE must be p41, p42, p43 or p44'
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
  python3 --version
  uname -a
} > "${RUN_ROOT}/environment.txt"

cat > "${RUN_ROOT}/expected-rows.txt" <<'EOF'
p41-driver-audit
p41-z01-source
build-serial
build-mpi4
build-no-ptracers
p41-c01-serial
p41-e01-serial
p41-e02-serial
p41-b01-serial
b12-serial
p41-c01-mpi4
p41-e01-mpi4
p41-e02-mpi4
p41-b01-mpi4
b12-mpi4
p41-decomposition
p41-brooks-oracle
p41-e01-files-serial
p41-e01-files-mpi4
p41-files-decomposition
p41-c01-reject-no-compiled-ptracers
p41-c01-reject-leew
p41-c01-reject-no-land
p41-c01-reject-no-temp
p41-c01-reject-no-n
p41-c01-reject-bad-policy
p41-c01-reject-bad-kn
p41-c01-reject-bad-tracer
p41-c01-reject-bad-tries
p41-c01-reject-bad-distance
p41-c01-reject-live-state
EOF

bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${BUILD_ROOT}/pycache" \
  python3 -m py_compile "${CASE_DIR}/input/generate_nutrient_fixture.py"
PYTHONPYCACHEPREFIX="${BUILD_ROOT}/pycache" \
  python3 -m py_compile "${CASE_DIR}/reference/brooks_oracle.py"
record_pass p41-driver-audit 'bash, shellcheck and Python compile checks'

source_scope_audit() {
  local calls biology_calls
  calls="$(grep -Rni 'CALL BOM_TRY_BUILD_BIO_ENDPOINTS' \
    "${REPO_ROOT}/pkg/bom" --include='*.F' || true)"
  [[ "$(printf '%s\n' "${calls}" | grep -c 'bom_build_endpoints.F')" -eq 1 ]] \
    || fail 'biology endpoint builder has an unexpected production caller'
  if grep -RniE 'bom(NPartTile|Status|Id|X|Y).*=' \
    "${REPO_ROOT}/pkg/bom/bom_brooks.F" \
    "${REPO_ROOT}/pkg/bom/bom_interp_bio_time.F" \
    "${REPO_ROOT}/pkg/bom/bom_interp_bio_pair.F"; then
    fail 'P4.1 stateless kernels mutate owner state'
  fi
  biology_calls="$(grep -Rni 'CALL BOM_BIOLOGY_PLAN' \
    "${REPO_ROOT}/pkg/bom" --include='*.F' || true)"
  if [[ "${SCOPE_MODE}" == p41 ]]; then
    [[ -z "${biology_calls}" ]] \
      || fail 'P4.1 biology plan entered the live owner path'
  else
    [[ "$(printf '%s\n' "${biology_calls}" \
      | grep -c 'bom_terminal_plan.F')" -eq 1 ]] \
      || fail 'P4.2 replay lacks the unique event biology caller'
    if [[ "${SCOPE_MODE}" == p42 ]]; then
      if grep -RniE 'random_number|CALL BOM_(PHILOX|BIRTH_|BIRTH_ORDER)' \
        "${REPO_ROOT}/pkg/bom" --include='*.F'; then
        fail 'P4.2 replay leaks P4.3 RNG/birth scope'
      fi
    else
      [[ "$(printf '%s\n' "${biology_calls}" \
        | grep -c 'bom_event_transaction_p43.F')" -eq 1 ]] \
        || fail 'P4.3 replay lacks the atomic biology event caller'
      if grep -Rni 'random_number' \
        "${REPO_ROOT}/pkg/bom" --include='*.F'; then
        fail 'P4.3 replay contains non-counter RNG'
      fi
    fi
  fi
  if grep -niE 'bomIntegrator|bomSpringLaw' \
    "${REPO_ROOT}/pkg/bom/bom_brooks.F"; then
    fail 'stateless biology plan depends on movement/spring selection'
  fi
  record_pass p41-z01-source \
    "P4-off and stateless kernels preserved under ${SCOPE_MODE} scope"
}

build_case() {
  local name="$1" size_file="$2" mpi_enabled="$3" packages_file="$4"
  local with_driver="$5"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args symbols
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/${packages_file}" "${mods_dir}/packages.conf"
  if [[ "${with_driver}" == yes ]]; then
    cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
    cp "${CASE_DIR}/code/bom_verify_p41_codes.F" "${mods_dir}/"
    cp "${CASE_DIR}/code/bom_verify_p41_endpoints.F" "${mods_dir}/"
    cp "${CASE_DIR}/code/bom_verify_p41_interp.F" "${mods_dir}/"
    cp "${CASE_DIR}/code/bom_verify_p41_brooks.F" "${mods_dir}/"
    if [[ "${SCOPE_MODE}" == p42 || "${SCOPE_MODE}" == p43 \
       || "${SCOPE_MODE}" == p44 ]]; then
      cp "${CASE_DIR}/code/bom_verify_p42_core.F" "${mods_dir}/"
    fi
  fi
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
  symbols=(bom_validate_biology_config_ bom_try_build_bio_endpoints_ \
    bom_get_nutrient_ bom_interp_bio_time_ bom_interp_bio_pair_ \
    bom_brooks_rate_ bom_biology_plan_)
  for symbol in "${symbols[@]}"; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${name}"
  done
  record_pass "build-${name}" 'debug/IEEE compile and P4.1 symbols'
}

prepare_run() {
  local name="$1" build="$2" bom_input="$3" packages_input="$4"
  local run_name="$5"
  local run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  sed -i "s/P41-PTRACER/${run_name}/" "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/${packages_input}" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/${bom_input}" "${run_dir}/data.bom"
  if [[ "${packages_input}" == data.pkg ]]; then
    cp "${CASE_DIR}/input/data.ptracers" "${run_dir}/data.ptracers"
  fi
  ln -s "${BUILD_ROOT}/${build}/mitgcmuv" "${run_dir}/mitgcmuv"
}

run_model() {
  local name="$1" ranks="$2"
  local run_dir="${RUN_ROOT}/${name}"
  local combined="${run_dir}/combined.log"
  local rank rank_log
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

run_ptracer_positive() {
  local name="$1" build="$2" ranks="$3"
  local combined="${RUN_ROOT}/${name}/combined.log"
  prepare_run "${name}" "${build}" data.bom.ptracer data.pkg P41-PTRACER
  run_model "${name}" "${ranks}"
  grep -q 'P4-C01 PASS:' "${combined}" || fail "P4-C01 missing: ${name}"
  grep -q 'P4-E01 PTRACER PASS:' "${combined}" \
    || fail "P4-E01 PTRACER missing: ${name}"
  grep -q 'P4-E02 PASS:' "${combined}" || fail "P4-E02 missing: ${name}"
  grep -q 'P4-B01/B12 PASS:' "${combined}" \
    || fail "P4-B01/B12 missing: ${name}"
  grep 'P41-BROOKS-RECORD' "${combined}" \
    | sed 's/^.*P41-BROOKS-RECORD/P41-BROOKS-RECORD/' \
    > "${RUN_ROOT}/${name}.brooks"
  [[ "$(wc -l < "${RUN_ROOT}/${name}.brooks")" -eq 13 ]] \
    || fail "wrong Brooks row count: ${name}"
  record_pass "p41-c01-${name}" 'stable codes and configuration matrix'
  record_pass "p41-e01-${name}" 'PTRACER fresh/advance/rollback/retry'
  record_pass "p41-e02-${name}" 'time/common-wet interpolation and policy'
  record_pass "p41-b01-${name}" 'finite Brooks reference and negative rows'
  record_pass "b12-${name}" 'analytical amount plans and strict thresholds'
}

run_files_positive() {
  local name="$1" build="$2" ranks="$3"
  local combined="${RUN_ROOT}/${name}/combined.log"
  prepare_run "${name}" "${build}" data.bom.files data.pkg P41-FILES
  python3 "${CASE_DIR}/input/generate_nutrient_fixture.py" \
    --output-dir "${RUN_ROOT}/${name}"
  run_model "${name}" "${ranks}"
  grep -q 'P4-E01 FILES PASS:' "${combined}" \
    || fail "P4-E01 FILES missing: ${name}"
  record_pass "p41-e01-${name}" 'FILES exact scale/cycle/rollback/retry'
}

run_negative() {
  local name="$1" build="$2" packages_input="$3" transform="$4"
  local run_dir="${RUN_ROOT}/${name}"
  prepare_run "${name}" "${build}" data.bom.ptracer \
    "${packages_input}" P41-PTRACER
  case "${transform}" in
    none) ;;
    leew) sed -i "s/bomMode='BOM'/bomMode='LEEW'/" "${run_dir}/data.bom" ;;
    no-land) sed -i 's/bomUseLand=.TRUE./bomUseLand=.FALSE./' "${run_dir}/data.bom" ;;
    no-temp) sed -i "s/bomTempSource='THETA'/bomTempSource='NONE'/" "${run_dir}/data.bom" ;;
    no-n) sed -i "s/bomNSource='PTRACER'/bomNSource='NONE'/" "${run_dir}/data.bom" ;;
    bad-policy) sed -i "s/bomBiologyMissingPolicy='STOP'/bomBiologyMissingPolicy='BAD'/" "${run_dir}/data.bom" ;;
    bad-kn) sed -i 's/bomKN=2./bomKN=0./' "${run_dir}/data.bom" ;;
    bad-tracer) sed -i 's/bomNTracerIndex=1/bomNTracerIndex=2/' "${run_dir}/data.bom" ;;
    bad-tries) sed -i 's/bomBirthMaxTry=8/bomBirthMaxTry=0/' "${run_dir}/data.bom" ;;
    bad-distance) sed -i 's/bomSpringL=100./bomSpringL=0./' "${run_dir}/data.bom" ;;
    live-state) sed -i 's/bomMaxParticles=0/bomMaxParticles=1/' "${run_dir}/data.bom" ;;
    *) fail "unknown negative transform ${transform}" ;;
  esac
  set +e
  (cd "${run_dir}" && ./mitgcmuv > run.log 2>&1)
  local rc=$?
  set -e
  if grep -q 'PROGRAM MAIN: Execution ended Normally' "${run_dir}/run.log"; then
    fail "negative reached normal end: ${name} (rc=${rc})"
  fi
  grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE' "${run_dir}/run.log" \
    || fail "negative fatal marker missing: ${name} (rc=${rc})"
  [[ "$(grep -c 'P4-C01 PASS:' "${run_dir}/run.log" || true)" -eq 0 ]] \
    || fail "state initialization reached: ${name}"
  if [[ "${transform}" == live-state && "${SCOPE_MODE}" == p44 ]]; then
    grep -q 'positive particle count requires input file' \
      "${run_dir}/run.log" \
      || fail "P4.4 missing-initial-state marker absent: ${name}"
    record_pass "p41-c01-${name}" \
      'P4.4 capacity accepted; missing initial state rejected'
  else
    grep -q 'invalid P4.1 biology configuration' "${run_dir}/run.log" \
      || fail "P4.1 config marker missing: ${name}"
    grep -q 'failCode=.*26' "${run_dir}/run.log" \
      || fail "failure 26 missing: ${name}"
    record_pass "p41-c01-${name}" 'failure 26 before state initialization'
  fi
}

log 'source-scope audit and serial/MPI builds'
source_scope_audit
build_case serial SIZE.h.serial no packages.conf yes
build_case mpi4 SIZE.h.mpi4 yes packages.conf yes
build_case no-ptracers SIZE.h.serial no packages.no-ptracers.conf no

log 'PTRACER direct gates'
run_ptracer_positive serial serial 1
run_ptracer_positive mpi4 mpi4 4
cmp "${RUN_ROOT}/serial.brooks" "${RUN_ROOT}/mpi4.brooks" \
  || fail 'Brooks records differ between serial and MPI4'
record_pass p41-decomposition '13 Brooks records bitwise serial/MPI4 equal'
python3 "${CASE_DIR}/reference/brooks_oracle.py" "${RUN_ROOT}/serial.brooks"
python3 "${CASE_DIR}/reference/brooks_oracle.py" "${RUN_ROOT}/mpi4.brooks"
record_pass p41-brooks-oracle '13 rows agree with 90-digit Decimal oracle'

log 'FILES provider gates'
run_files_positive files-serial serial 1
run_files_positive files-mpi4 mpi4 4
record_pass p41-files-decomposition 'internal accepted-field assertions pass both decompositions'

log 'configuration fail-before-state matrix'
run_negative reject-no-compiled-ptracers no-ptracers data.pkg.no-ptracers none
run_negative reject-leew serial data.pkg leew
run_negative reject-no-land serial data.pkg no-land
run_negative reject-no-temp serial data.pkg no-temp
run_negative reject-no-n serial data.pkg no-n
run_negative reject-bad-policy serial data.pkg bad-policy
run_negative reject-bad-kn serial data.pkg bad-kn
run_negative reject-bad-tracer serial data.pkg bad-tracer
run_negative reject-bad-tries serial data.pkg bad-tries
run_negative reject-bad-distance serial data.pkg bad-distance
run_negative reject-live-state serial data.pkg live-state

actual_rows="$(( $(wc -l < "${RUN_ROOT}/summary.tsv") - 1 ))"
[[ "${actual_rows}" -eq "${EXPECTED_ROWS}" ]] \
  || fail "summary rows ${actual_rows}, expected ${EXPECTED_ROWS}"
awk -F '\t' 'NR>1 && $2!="PASS" { bad=1 } END { exit bad }' \
  "${RUN_ROOT}/summary.tsv" || fail 'non-PASS summary row'
awk -F '\t' 'NR>1 { print $1 }' "${RUN_ROOT}/summary.tsv" \
  > "${RUN_ROOT}/actual-rows.txt"
[[ "$(sort "${RUN_ROOT}/actual-rows.txt" | uniq -d | wc -l)" -eq 0 ]] \
  || fail 'duplicate summary row'
sort "${RUN_ROOT}/expected-rows.txt" \
  > "${RUN_ROOT}/expected-rows.sorted.txt"
sort "${RUN_ROOT}/actual-rows.txt" \
  > "${RUN_ROOT}/actual-rows.sorted.txt"
cmp "${RUN_ROOT}/expected-rows.sorted.txt" \
  "${RUN_ROOT}/actual-rows.sorted.txt" \
  || fail 'expected/actual row names differ'

git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${RUN_ROOT}/git-status-after.txt"
if [[ "${REQUIRE_CLEAN}" == 1 \
   && -s "${RUN_ROOT}/git-status-after.txt" ]]; then
  fail 'source tree is not clean at gate exit'
fi
git -C "${REPO_ROOT}" diff --check
(
  cd "${REPO_ROOT}"
  {
    find pkg/bom -maxdepth 1 -type f -print0
    find verification/bom/phase04-biology-land -type f -print0
  } | sort -z | xargs -0 sha256sum
) > "${RUN_ROOT}/sha256.txt"
cp -a "${RUN_ROOT}/." "${ARTIFACT_ROOT}/"
(
  cd "${ARTIFACT_ROOT}"
  find . -type f ! -name MANIFEST.sha256 \
    ! -name manifest-check.txt -print0 \
    | sort -z | xargs -0 sha256sum \
    > "${BUILD_ROOT}/MANIFEST.sha256"
  mv "${BUILD_ROOT}/MANIFEST.sha256" MANIFEST.sha256
  sha256sum -c MANIFEST.sha256 > manifest-check.txt
)

log "P4.1 DIRECT GATE PASS (${EXPECTED_ROWS}/${EXPECTED_ROWS})"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
