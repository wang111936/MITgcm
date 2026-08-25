#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p21-pickup-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_PARENT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase02-pickup}"
readonly RUN_PARENT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase02-pickup}"
readonly ARTIFACT_PARENT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-pickup}"
readonly BUILD_ROOT="${BUILD_PARENT}/${TEST_ID}"
readonly RUN_ROOT="${RUN_PARENT}/${TEST_ID}"
readonly ARTIFACT_ROOT="${ARTIFACT_PARENT}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"

fail() {
  printf 'P2.1 PICKUP GATE FAIL: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[P2.1-pickup] %s\n' "$*"
}

for required in bash make nm grep shellcheck mpirun sha256sum python3; do
  command -v "${required}" >/dev/null 2>&1 \
    || fail "required command not found: ${required}"
done
[[ -x "${REPO_ROOT}/tools/genmake2" ]] || fail 'genmake2 not executable'
[[ -f "${OPTFILE}" ]] || fail "optfile not found: ${OPTFILE}"
for root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${root}" ]] || fail "evidence root already exists: ${root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

build_case() {
  local name="$1"
  local size_file="$2"
  local mpi_enabled="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args

  log "build ${name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/packages.conf"
  args=(
    "${REPO_ROOT}/tools/genmake2"
    "-rootdir=${REPO_ROOT}"
    "-mods=${mods_dir}"
    "-of=${OPTFILE}"
    -ieee
    -devel
  )
  if [[ "${mpi_enabled}" == yes ]]; then
    args+=( -mpi )
  fi
  (
    cd "${build_dir}"
    "${args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable: ${name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_write_pickup_ bom_read_pickup_ \
                bom_write_pickup_env_ bom_read_pickup_env_ \
                bom_build_pickup2_signature_ \
                bom_validate_pickup2_signature_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${name}"
  done
  record_pass "build-${name}" 'debug compile and schema-2 pickup symbols'
}

prepare_fresh() {
  local name="$1"
  local build_name="$2"
  local bom_input="$3"
  local end_time="$4"
  local run_name="$5"
  local run_dir="${RUN_ROOT}/${name}"

  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/eedata"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/data.pkg"
  cp "${CASE_DIR}/input/${bom_input}" "${run_dir}/data.bom"
  sed -i \
    -e "s/endTime=0\./endTime=${end_time}./" \
    -e 's/pChkptFreq=0\./pChkptFreq=1200./' \
    -e "s/P21-ENDPOINT-STATE/${run_name}/" \
    "${run_dir}/data"
  if [[ "${bom_input}" == data.bom.stokes-files ]]; then
    python3 "${CASE_DIR}/input/generate_stokes_fixture.py" \
      --output-dir "${run_dir}"
  fi
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" "${run_dir}/mitgcmuv"
}

prepare_restart() {
  local name="$1"
  local source="$2"
  local build_name="$3"
  local end_time="$4"
  local run_dir="${RUN_ROOT}/${name}"
  local source_dir="${RUN_ROOT}/${source}"

  mkdir -p "${run_dir}"
  cp "${source_dir}/data" "${run_dir}/data"
  cp "${source_dir}/eedata" "${run_dir}/eedata"
  cp "${source_dir}/data.pkg" "${run_dir}/data.pkg"
  cp "${source_dir}/data.bom" "${run_dir}/data.bom"
  for optional in ustokes.bin vstokes.bin; do
    if [[ -f "${source_dir}/${optional}" ]]; then
      cp "${source_dir}/${optional}" "${run_dir}/${optional}"
    fi
  done
  cp "${source_dir}"/pickup.0000000001* "${run_dir}/"
  cp "${source_dir}"/pickup_bom.0000000001* "${run_dir}/"
  sed -i \
    -e 's/nIter0=0/nIter0=1/' \
    -e "s/endTime=[0-9][0-9]*\./endTime=${end_time}./" \
    -e 's/pChkptFreq=1200\./pChkptFreq=0./' \
    "${run_dir}/data"
  ln -s "${BUILD_ROOT}/${build_name}/mitgcmuv" "${run_dir}/mitgcmuv"
}

combined_log() {
  local run_dir="$1"
  local ranks="$2"
  local combined="${run_dir}/combined.log"
  local rank
  local rank_log

  if [[ "${ranks}" -eq 1 ]]; then
    cp "${run_dir}/run.log" "${combined}"
  else
    : > "${combined}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      [[ -f "${rank_log}" ]] || fail "missing rank log: ${rank_log}"
      cat "${rank_log}" >> "${combined}"
    done
  fi
}

run_positive() {
  local name="$1"
  local ranks="$2"
  local run_dir="${RUN_ROOT}/${name}"

  log "run ${name}"
  if [[ "${ranks}" -eq 1 ]]; then
    ( cd "${run_dir}" && ./mitgcmuv > run.log 2>&1 )
  else
    ( cd "${run_dir}" && mpirun -np "${ranks}" ./mitgcmuv \
        > mpi-launch.log 2>&1 )
  fi
  combined_log "${run_dir}" "${ranks}"
  grep -q 'PROGRAM MAIN: Execution ended Normally' \
    "${run_dir}/combined.log" || fail "normal end missing: ${name}"
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' \
       "${run_dir}/combined.log"; then
    fail "fatal marker in positive case: ${name}"
  fi
}

run_negative() {
  local name="$1"
  local marker="$2"
  local run_dir="${RUN_ROOT}/${name}"

  log "run negative ${name}"
  ( cd "${run_dir}" && ./mitgcmuv > run.log 2>&1 ) || true
  grep -Eq "${marker}" "${run_dir}/run.log" \
    || fail "negative marker missing: ${name}"
  grep -Eq 'code= *15|BOM_FAIL_PICKUP_SCHEMA' "${run_dir}/run.log" \
    || fail "schema failure code missing: ${name}"
  if grep -q 'BOM_READ_PICKUP: complete' "${run_dir}/run.log"; then
    fail "negative case committed pickup: ${name}"
  fi
}

build_case serial SIZE.h.serial no
build_case mpi4 SIZE.h.mpi4 yes

prepare_fresh bom-write serial data.bom.valid 1200 P21-PICKUP-WRITE
run_positive bom-write 1
grep -q 'BOM_WRITE_PICKUP: suffix=0000000001' \
  "${RUN_ROOT}/bom-write/combined.log" || fail 'schema-2 write marker missing'
[[ "$(stat -c '%s' "${RUN_ROOT}/bom-write/pickup_bom.0000000001.sig.data")" \
    -gt 128 ]] || fail 'schema-2 signature did not exceed schema-1 size'
[[ -f "${RUN_ROOT}/bom-write/pickup_bom.0000000001.env.001.001.data" ]] \
  || fail 'schema-2 endpoint sidecar missing'
record_pass schema2-write 'BOM schema 2 signature, particles, and sidecars'

prepare_restart bom-read bom-write serial 1200
run_positive bom-read 1
grep -q 'BOM_READ_PICKUP: complete suffix=0000000001' \
  "${RUN_ROOT}/bom-read/combined.log" || fail 'schema-2 read marker missing'
record_pass schema2-read 'transactional zero-particle schema-2 restart'

prepare_fresh stokes-cont serial data.bom.stokes-files 2400 P21-PICKUP-STOKES
run_positive stokes-cont 1
prepare_restart stokes-split stokes-cont serial 2400
sed -i 's/pChkptFreq=0\./pChkptFreq=1200./' \
  "${RUN_ROOT}/stokes-split/data"
run_positive stokes-split 1
(
  cd "${RUN_ROOT}/stokes-cont"
  sha256sum pickup_bom.0000000002* > "${RUN_ROOT}/stokes-cont.sha256"
)
(
  cd "${RUN_ROOT}/stokes-split"
  sha256sum pickup_bom.0000000002* > "${RUN_ROOT}/stokes-split.sha256"
)
cmp "${RUN_ROOT}/stokes-cont.sha256" "${RUN_ROOT}/stokes-split.sha256" \
  || fail 'continuous/split schema-2 pickup is not bitwise identical'
record_pass stokes-bitwise \
  'nonzero FILES Stokes continuous/split endpoint pickup bitwise identical'

prepare_fresh leew-write serial data.bom.leew 1200 P21-LEEW-WRITE
run_positive leew-write 1
[[ "$(stat -c '%s' "${RUN_ROOT}/leew-write/pickup_bom.0000000001.sig.data")" \
    -eq 128 ]] || fail 'LEEW schema-1 signature size changed'
if compgen -G "${RUN_ROOT}/leew-write/pickup_bom.0000000001.env*" \
     >/dev/null; then
  fail 'LEEW unexpectedly wrote endpoint sidecar'
fi
prepare_restart leew-read leew-write serial 1200
run_positive leew-read 1
grep -q 'BOM_READ_PICKUP: complete suffix=0000000001' \
  "${RUN_ROOT}/leew-read/combined.log" || fail 'LEEW schema-1 read missing'
record_pass leew-schema1 'schema-1 layout and restart compatibility'

prepare_restart schema1-bom leew-write serial 1200
cp "${CASE_DIR}/input/data.bom.valid" "${RUN_ROOT}/schema1-bom/data.bom"
run_negative schema1-bom 'signature preflight'
record_pass schema1-bom-reject 'schema 1 rejected before BOM particle commit'

prepare_restart bad-tau bom-write serial 1200
sed -i 's/bomTauDays=0.0103/bomTauDays=0.0104/' \
  "${RUN_ROOT}/bad-tau/data.bom"
run_negative bad-tau 'signature mismatch'
record_pass parameter-fingerprint 'legal changed SI tau rejected exactly'

prepare_restart bad-env bom-write serial 1200
truncate -s 8000 \
  "${RUN_ROOT}/bad-env/pickup_bom.0000000001.env.001.001.data"
run_negative bad-env 'endpoint sidecar'
record_pass endpoint-preflight 'truncated sidecar rejected before commit'

prepare_fresh mpi4-write mpi4 data.bom.valid 1200 P21-PICKUP-MPI4
run_positive mpi4-write 4
prepare_restart mpi4-read mpi4-write mpi4 1200
run_positive mpi4-read 4
grep -q 'BOM_READ_PICKUP: complete suffix=0000000001' \
  "${RUN_ROOT}/mpi4-read/combined.log" || fail 'MPI4 read marker missing'
record_pass mpi4-schema2 'four-rank schema-2 write and transactional restart'

pass_count="$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END {print n+0}' \
  "${RUN_ROOT}/summary.tsv")"
[[ "${pass_count}" -eq 10 ]] || fail "expected 10 PASS rows, got ${pass_count}"
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${ARTIFACT_ROOT}/source-head.txt"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum summary.tsv source-head.txt > manifest.sha256
)
log "P2.1 PICKUP GATE PASS (${pass_count}/${pass_count})"
log "build root:    ${BUILD_ROOT}"
log "run root:      ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
