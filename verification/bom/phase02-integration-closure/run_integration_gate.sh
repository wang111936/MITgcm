#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p25-integration-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase02-integration-closure}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase02-integration-closure}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-integration}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly P11_CASE="${REPO_ROOT}/verification/bom/phase01-bom-lite"
readonly P14_CASE="${REPO_ROOT}/verification/bom/phase01-owner-migration"
readonly P15_CASE="${REPO_ROOT}/verification/bom/phase01-output-pickup-coexistence"

fail() { printf 'P2.5 INTEGRATION GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P2.5-integration] %s\n' "$*"; }
record_pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

for command_name in bash cmp git grep make mpirun nm python3 sed sha256sum shellcheck; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing ${command_name}"
done
[[ -x "${REPO_ROOT}/tools/genmake2" ]] || fail 'genmake2 is not executable'
[[ -f "${OPTFILE}" ]] || fail "missing optfile: ${OPTFILE}"
[[ "${REQUIRE_CLEAN}" == yes || "${REQUIRE_CLEAN}" == no ]] || fail 'bad REQUIRE_CLEAN'
if [[ "${REQUIRE_CLEAN}" == yes && -n "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]]; then
  fail 'exact-head evidence requires a clean worktree'
fi
for fresh_root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${fresh_root}" ]] || fail "evidence root already exists: ${fresh_root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${RUN_ROOT}/pycache" python3 -m py_compile \
  "${CASE_DIR}/verify_schema2.py" "${CASE_DIR}/mutate_schema2.py" \
  "${CASE_DIR}/make_velocity.py"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

grep -Fq 'PARAMETER ( bomOutputFields2  = 48 )' "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
  || fail 'trajectory schema-2 field count is not frozen at 48'
grep -Fq 'PARAMETER ( bomPickupFields2  = 45 )' "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
  || fail 'pickup schema-2 field count is not frozen at 45'
grep -Fq 'scratchDiag(' "${REPO_ROOT}/pkg/bom/bom_read_pickup.F" \
  || fail 'transactional diagnostic scratch is missing'
grep -Fq 'bomRhsDiag(iDiag,ip,bi,bj) =' "${REPO_ROOT}/pkg/bom/bom_read_pickup.F" \
  || fail 'diagnostic commit is missing'
record_pass p2-p01-source \
  'versioned 48-field trajectory, 45-field pickup, scratch-before-commit reader'

build_case() {
  local name="$1" size_file="$2" mpi_enabled="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  log "build ${name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${size_file}" "${mods_dir}/SIZE.h"
  cp "${P14_CASE}/code/packages.conf" "${mods_dir}/packages.conf"
  args=("${REPO_ROOT}/tools/genmake2" "-rootdir=${REPO_ROOT}" "-mods=${mods_dir}" "-of=${OPTFILE}" -ieee -devel)
  [[ "${mpi_enabled}" == no ]] || args+=( -mpi )
  (
    cd "${build_dir}"
    "${args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable: ${name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_write_trajectory_ bom_write_pickup_ bom_read_pickup_ \
                bom_particle_exchange_ bom_rhs_slow_manifold_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" || fail "missing ${symbol}: ${name}"
  done
  record_pass "build-${name}" 'debug/IEEE production schema-2 integration build'
}

build_case serial "${P14_CASE}/code/SIZE.h.serial" no
build_case mpi2 "${P14_CASE}/code/SIZE.h.mpi2" yes
build_case mpi4 "${P14_CASE}/code/SIZE.h.mpi4" yes

prepare_fresh() {
  local name="$1" build="$2" end_time="$3" pickup_frequency="$4"
  local run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${P14_CASE}/input/data.cartesian" "${run_dir}/data"
  cp "${P14_CASE}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${P14_CASE}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/data.bom" "${run_dir}/data.bom"
  sed -i \
    -e "s/endTime=0\./endTime=${end_time}./" \
    -e 's/deltaTmom=1200\./deltaTmom=60./' \
    -e 's/deltaTtracer=1200\./deltaTtracer=60./' \
    -e 's/deltaTClock=1200\./deltaTClock=60./' \
    -e "s/pChkptFreq=0\./pChkptFreq=${pickup_frequency}./" \
    -e "/the_run_name=/i\\ uVelInitFile='uvel.bin'," \
    -e "s/the_run_name='[^']*'/the_run_name='${name}'/" \
    "${run_dir}/data"
  python3 "${P11_CASE}/make_initial.py" valid "${run_dir}/bom_particles"
  python3 "${CASE_DIR}/make_velocity.py" "${run_dir}/uvel.bin" > "${run_dir}/velocity.log"
  ln -s "${BUILD_ROOT}/${build}/mitgcmuv" "${run_dir}/mitgcmuv"
}

collect_logs() {
  local run_dir="$1" ranks="$2" output="$3" rank rank_file
  : > "${output}"
  [[ ! -f "${run_dir}/mpi-launch.log" ]] || cat "${run_dir}/mpi-launch.log" >> "${output}"
  for ((rank=0; rank<ranks; rank++)); do
    printf -v rank_file '%s/STDOUT.%04d' "${run_dir}" "${rank}"
    [[ ! -f "${rank_file}" ]] || cat "${rank_file}" >> "${output}"
    printf -v rank_file '%s/STDERR.%04d' "${run_dir}" "${rank}"
    [[ ! -f "${rank_file}" ]] || cat "${rank_file}" >> "${output}"
  done
}

run_positive() {
  local name="$1" ranks="$2" phase="$3"
  local run_dir="${RUN_ROOT}/${name}" log_file
  log "run ${name} ${phase}"
  if [[ "${ranks}" -eq 1 ]]; then
    (cd "${run_dir}"; ./mitgcmuv > "${phase}.log" 2>&1)
    log_file="${run_dir}/${phase}.log"
  else
    (cd "${run_dir}"; mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1)
    log_file="${run_dir}/${phase}-combined.log"
    collect_logs "${run_dir}" "${ranks}" "${log_file}"
  fi
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${log_file}" || fail "normal end missing: ${name}/${phase}"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE|particle failure' "${log_file}"; then
    fail "fatal marker: ${name}/${phase}"
  fi
}

verify_case() {
  local name="$1" tag="$2" suffix="$3" iteration="$4" time="$5" next_time="$6"
  local npx="$7" npy="$8" nsx="$9" nsy="${10}"
  local run_dir="${RUN_ROOT}/${name}"
  python3 "${CASE_DIR}/verify_schema2.py" "${run_dir}" \
    --trajectory-suffix "${suffix}" \
    --trajectory-output "${run_dir}/${tag}-trajectory.tsv" \
    --trajectory-invariant "${run_dir}/${tag}-trajectory-invariant.tsv" \
    --pickup-suffix "${suffix}" \
    --pickup-output "${run_dir}/${tag}-pickup.tsv" \
    --pickup-invariant "${run_dir}/${tag}-pickup-invariant.tsv" \
    --endpoint-invariant "${run_dir}/${tag}-endpoint-invariant.tsv" \
    --iteration "${iteration}" --time "${time}" --frequency 150 --next-time "${next_time}" \
    --npx "${npx}" --npy "${npy}" --nsx "${nsx}" --nsy "${nsy}" \
    > "${run_dir}/${tag}-verify.log"
  grep -q 'P2.5 SCHEMA-2 VERIFY PASS' "${run_dir}/${tag}-verify.log" \
    || fail "schema-2 verifier marker missing: ${name}/${tag}"
}

compare_pickup_family() {
  local left="$1" right="$2" suffix="$3" file base
  for file in "${left}/pickup_bom.${suffix}"*; do
    [[ "${file}" == *.data ]] || continue
    base="$(basename "${file}")"
    [[ -f "${right}/${base}" ]] || fail "missing split pickup component: ${base}"
    cmp -s "${file}" "${right}/${base}" || fail "pickup component differs: ${base}"
  done
}

run_layout() {
  local layout="$1" ranks="$2" npx="$3" npy="$4" nsx="$5" nsy="$6"
  local continuous="continuous-${layout}" split="split-${layout}"
  local split_dir="${RUN_ROOT}/${split}"
  prepare_fresh "${continuous}" "${layout}" 480 480
  run_positive "${continuous}" "${ranks}" continuous
  verify_case "${continuous}" final 0000000008 8 480 600 "${npx}" "${npy}" "${nsx}" "${nsy}"

  prepare_fresh "${split}" "${layout}" 300 300
  run_positive "${split}" "${ranks}" segment
  verify_case "${split}" segment 0000000005 5 300 450 "${npx}" "${npy}" "${nsx}" "${nsy}"
  mkdir "${split_dir}/segment-logs"
  find "${split_dir}" -maxdepth 1 -type f \
    \( -name 'STDOUT.*' -o -name 'STDERR.*' -o -name 'mpi-launch.log' \) \
    -exec mv -t "${split_dir}/segment-logs" {} +
  sed -i \
    -e 's/nIter0=0,/nIter0=5,/' \
    -e '/nIter0=5,/a\ startTime=300.,' \
    -e 's/endTime=300\./endTime=480./' \
    -e 's/pChkptFreq=300\./pChkptFreq=480./' \
    "${split_dir}/data"
  run_positive "${split}" "${ranks}" restart
  grep -q 'BOM_READ_PICKUP: complete suffix=0000000005' \
    "${split_dir}/restart${ranks:+-combined}.log" 2>/dev/null || \
    grep -q 'BOM_READ_PICKUP: complete suffix=0000000005' "${split_dir}/restart.log" \
    || fail "restart completion marker missing: ${layout}"
  verify_case "${split}" final 0000000008 8 480 600 "${npx}" "${npy}" "${nsx}" "${nsy}"

  cmp -s "${RUN_ROOT}/${continuous}/final-trajectory.tsv" "${split_dir}/final-trajectory.tsv" \
    || fail "continuous/split trajectory differs: ${layout}"
  cmp -s "${RUN_ROOT}/${continuous}/final-pickup.tsv" "${split_dir}/final-pickup.tsv" \
    || fail "continuous/split pickup differs: ${layout}"
  cmp -s "${RUN_ROOT}/${continuous}/final-endpoint-invariant.tsv" "${split_dir}/final-endpoint-invariant.tsv" \
    || fail "continuous/split endpoints differ: ${layout}"
  compare_pickup_family "${RUN_ROOT}/${continuous}" "${split_dir}" 0000000008
  record_pass "p2-p03-${layout}" \
    'continuous/split final state, 27 diagnostics, endpoints and schedule bitwise identical'
  record_pass "p2-m01-${layout}" \
    'three exact IDs, 3 m/s field, owner-tile crossing and schema-2 diagnostics verified'
  if [[ "${layout}" == serial ]]; then
    record_pass p2-p01-schema2 \
      'write/read preflight, signature, endpoint sidecar, particles and one commit exercised'
  fi
}

run_layout serial 1 1 1 2 2
run_layout mpi2 2 2 1 1 2
run_layout mpi4 4 2 2 1 1

for field in trajectory pickup endpoint; do
  cmp -s "${RUN_ROOT}/continuous-serial/final-${field}-invariant.tsv" \
         "${RUN_ROOT}/continuous-mpi2/final-${field}-invariant.tsv" \
    || fail "serial/MPI2 ${field} invariant differs"
  cmp -s "${RUN_ROOT}/continuous-serial/final-${field}-invariant.tsv" \
         "${RUN_ROOT}/continuous-mpi4/final-${field}-invariant.tsv" \
    || fail "serial/MPI4 ${field} invariant differs"
done
record_pass p2-m01-layout-invariant \
  'serial/MPI2/MPI4 sorted particle diagnostics and endpoint interiors bitwise identical'

prepare_leew() {
  local name="$1" bom_file="$2"
  local run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${P14_CASE}/input/data.cartesian" "${run_dir}/data"
  cp "${P14_CASE}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${P14_CASE}/input/eedata" "${run_dir}/eedata"
  cp "${bom_file}" "${run_dir}/data.bom"
  sed -i \
    -e 's/endTime=0\./endTime=60./' \
    -e 's/deltaTmom=1200\./deltaTmom=60./' \
    -e 's/deltaTtracer=1200\./deltaTtracer=60./' \
    -e 's/deltaTClock=1200\./deltaTClock=60./' \
    -e 's/pChkptFreq=0\./pChkptFreq=60./' \
    "${run_dir}/data"
  python3 "${P11_CASE}/make_initial.py" valid "${run_dir}/bom_particles"
  ln -s "${BUILD_ROOT}/serial/mitgcmuv" "${run_dir}/mitgcmuv"
}

prepare_leew leew-write "${P15_CASE}/input/data.bom.output"
run_positive leew-write 1 fresh
[[ "$(stat -c '%s' "${RUN_ROOT}/leew-write/pickup_bom.0000000001.sig.data")" -eq 128 ]] \
  || fail 'LEEW schema-1 signature changed'
mkdir "${RUN_ROOT}/leew-read"
cp "${RUN_ROOT}/leew-write/data" "${RUN_ROOT}/leew-read/data"
cp "${RUN_ROOT}/leew-write/data.pkg" "${RUN_ROOT}/leew-read/data.pkg"
cp "${RUN_ROOT}/leew-write/eedata" "${RUN_ROOT}/leew-read/eedata"
cp "${RUN_ROOT}/leew-write/data.bom" "${RUN_ROOT}/leew-read/data.bom"
cp "${RUN_ROOT}/leew-write"/pickup.0000000001* "${RUN_ROOT}/leew-read/"
cp "${RUN_ROOT}/leew-write"/pickup_bom.0000000001* "${RUN_ROOT}/leew-read/"
sed -i -e 's/nIter0=0,/nIter0=1,/' -e '/nIter0=1,/a\ startTime=60.,' \
  "${RUN_ROOT}/leew-read/data"
ln -s "${BUILD_ROOT}/serial/mitgcmuv" "${RUN_ROOT}/leew-read/mitgcmuv"
run_positive leew-read 1 restart
grep -q 'BOM_READ_PICKUP: complete suffix=0000000001' "${RUN_ROOT}/leew-read/restart.log" \
  || fail 'LEEW schema-1 read marker missing'
record_pass p2-p02-leew 'unchanged schema-1 LEEW write/read accepted'

cp -a "${RUN_ROOT}/leew-read" "${RUN_ROOT}/schema1-bom"
cp "${CASE_DIR}/input/data.bom" "${RUN_ROOT}/schema1-bom/data.bom"
(cd "${RUN_ROOT}/schema1-bom"; ./mitgcmuv > negative.log 2>&1) || true
grep -q 'signature preflight' "${RUN_ROOT}/schema1-bom/negative.log" \
  || fail 'schema-1 BOM rejection marker missing'
if grep -q 'BOM_READ_PICKUP: complete' "${RUN_ROOT}/schema1-bom/negative.log"; then
  fail 'schema-1 BOM pickup committed'
fi
record_pass p2-p02-bom-reject 'schema-1 BOM rejected before particle/environment commit'

prepare_negative() {
  local name="$1" mutation="$2"
  local source="${RUN_ROOT}/continuous-serial" run_dir="${RUN_ROOT}/${name}"
  mkdir -p "${run_dir}"
  cp "${source}/data" "${run_dir}/data"
  cp "${source}/data.pkg" "${run_dir}/data.pkg"
  cp "${source}/eedata" "${run_dir}/eedata"
  cp "${source}/data.bom" "${run_dir}/data.bom"
  cp "${source}"/pickup.0000000008* "${run_dir}/"
  cp "${source}"/pickup_bom.0000000008* "${run_dir}/"
  sed -i \
    -e 's/nIter0=0,/nIter0=8,/' \
    -e '/nIter0=8,/a\ startTime=480.,' \
    -e 's/pChkptFreq=480\./pChkptFreq=0./' \
    "${run_dir}/data"
  ln -s "${BUILD_ROOT}/serial/mitgcmuv" "${run_dir}/mitgcmuv"
  python3 "${CASE_DIR}/mutate_schema2.py" "${run_dir}" 0000000008 "${mutation}" \
    > "${run_dir}/mutation.log"
}

run_negative() {
  local mutation="$1" marker="$2" name run_dir
  name="p04-${mutation}"
  prepare_negative "${name}" "${mutation}"
  run_dir="${RUN_ROOT}/${name}"
  (cd "${run_dir}"; ./mitgcmuv > negative.log 2>&1) || true
  grep -q "${marker}" "${run_dir}/negative.log" || fail "P04 marker missing: ${mutation}"
  grep -Eq 'code= *15|BOM_FAIL_PICKUP_SCHEMA' "${run_dir}/negative.log" \
    || fail "P04 failure code missing: ${mutation}"
  if grep -q 'BOM_READ_PICKUP: complete' "${run_dir}/negative.log"; then
    fail "P04 corruption committed: ${mutation}"
  fi
  record_pass "p2-p04-${mutation}" 'specific schema failure before accepted-state commit'
}

run_negative mode 'signature mismatch'
run_negative source 'signature mismatch'
run_negative parameter 'signature mismatch'
run_negative decomposition 'signature mismatch'
run_negative particle-diag 'scratch validation failed'
run_negative field-block 'endpoint sidecar'

pass_count="$(grep -c $'\tPASS\t' "${RUN_ROOT}/summary.tsv")"
[[ "${pass_count}" -eq 20 ]] || fail "expected 20 PASS rows, found ${pass_count}"
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${ARTIFACT_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 > "${ARTIFACT_ROOT}/git-status.txt"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv source-head.txt git-status.txt > manifest.sha256
)
log "P2.5 INTEGRATION GATE PASS (${pass_count}/${pass_count})"
log "build root: ${BUILD_ROOT}"
log "run root: ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
