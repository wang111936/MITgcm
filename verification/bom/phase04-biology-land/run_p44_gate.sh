#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p44-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase04-biology-land}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase04-biology-land}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p44}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXPECTED_ROWS=57

fail() { printf 'P4.4 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P4.4] %s\n' "$*"; }
record_pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

for command_name in bash cmp find gfortran git grep make mpirun nm \
  python3 sed sha256sum shellcheck sort wc; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing ${command_name}"
done
for root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${root}" ]] || fail "evidence root exists: ${root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"
git -C "${REPO_ROOT}" rev-parse HEAD > "${RUN_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 > "${RUN_ROOT}/git-status-before.txt"
{
  git --version
  gfortran --version | sed -n '1p'
  mpirun --version | sed -n '1p'
  uname -a
} > "${RUN_ROOT}/environment.txt"

bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${BUILD_ROOT}/pycache" \
  python3 -m py_compile "${CASE_DIR}/reference/p44_artifact_audit.py"
record_pass p44-driver-audit 'bash, shellcheck and Python artifact audit compile'

for symbol in BOM_WRITE_P4_MANIFEST BOM_VALIDATE_P4_MANIFEST \
  BOM_EVENT_FLUSH_IMPL BOM_LOAD_EVENT_SHARD_STATE BOM_READ_P4_SIGNATURE \
  BOM_READ_P4_SIDECAR BOM_READ_P4_BIO_PICKUP BOM_EVENT_BUDGET_CHECK; do
  grep -Rqs "SUBROUTINE ${symbol}" "${REPO_ROOT}/pkg/bom" \
    || fail "missing ${symbol}"
done
for diagnostic in BOMCOUNT BOMMASS BOMBIRTH BOMDEAD BOMBEACH; do
  grep -qs "${diagnostic}" "${REPO_ROOT}/pkg/bom/bom_event_budget.F" \
    || fail "missing ${diagnostic} diagnostic"
done
if grep -Rni 'MPI_INTEGER8' "${REPO_ROOT}/pkg/bom" --include='*.F' --include='*.F90'; then
  fail 'non-portable MPI_INTEGER8 leaked into P4.4'
fi
fixed_sources=(
  "${REPO_ROOT}/pkg/bom/bom_p4_schema.F"
  "${REPO_ROOT}/pkg/bom/bom_p4_sidecar.F"
  "${REPO_ROOT}/pkg/bom/bom_p4_manifest.F"
  "${REPO_ROOT}/pkg/bom/bom_p4_bio_pickup.F"
  "${REPO_ROOT}/pkg/bom/bom_event_io.F"
  "${REPO_ROOT}/pkg/bom/bom_event_budget.F"
  "${CASE_DIR}/code/bom_init_varia_p44.F"
  "${CASE_DIR}/code/bom_verify_p44.F"
)
long_lines="$(awk 'length($0)>72 && $0 !~ /^[Cc*!#]/ {
  print FILENAME ":" FNR ":" length($0)
}' "${fixed_sources[@]}")"
[[ -z "${long_lines}" ]] || fail "fixed-form executable line exceeds 72: ${long_lines}"
record_pass p44-source-audit 'schema4/event/budget entry points, portable MPI and fixed form'

build_case() {
  local name="$1" size_file="$2" mpi_enabled="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args symbols
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/packages.conf"
  cp "${CASE_DIR}/code/bom_init_varia_p44.F" "${mods_dir}/bom_init_varia.F"
  cp "${CASE_DIR}/code/"bom_verify_p43_*.F "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_p44.F" "${mods_dir}/"
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
  symbols=(bom_sha256_file_ bom_write_p4_manifest_ \
    bom_validate_p4_manifest_ bom_event_flush_impl_ \
    bom_read_p4_signature_ bom_read_p4_sidecar_ \
    bom_event_budget_check_ bom_verify_p44_io_)
  for symbol in "${symbols[@]}"; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing ${symbol} in ${name}"
  done
  record_pass "build-${name}" 'debug/IEEE build and P4.4 production symbols'
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

run_model() {
  local name="$1" build="$2" ranks="$3" run_name="$4"
  local run_dir="${RUN_ROOT}/${name}"
  local combined="${run_dir}/combined.log"
  local rank rank_log
  prepare_run "${name}" "${build}" "${run_name}"
  if [[ "${ranks}" -eq 1 ]]; then
    (cd "${run_dir}" && ./mitgcmuv > run.log 2>&1)
    cp "${run_dir}/run.log" "${combined}"
  else
    (cd "${run_dir}" && mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1)
    : > "${combined}"
    for ((rank=0; rank<ranks; rank++)); do
      printf -v rank_log '%s/STDOUT.%04d' "${run_dir}" "${rank}"
      cat "${rank_log}" >> "${combined}"
    done
  fi
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${combined}" \
    || fail "normal end absent: ${name}"
  if grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE' "${combined}"; then
    fail "fatal marker in positive run: ${name}"
  fi
}

copy_boundary() {
  local source="$1" destination="$2"
  find "${source}" -maxdepth 1 -type f \
    \( -name 'pickup_bom*' -o -name 'p44_restart_events*' \) \
    -exec cp -t "${destination}" {} +
}

log 'building serial, MPI2 and MPI4 P4.4 fixtures'
build_case serial SIZE.h.serial no
build_case mpi2 SIZE.h.mpi2 yes
build_case mpi4 SIZE.h.mpi4 yes

for spec in 'serial 1' 'mpi2 2' 'mpi4 4'; do
  read -r build ranks <<< "${spec}"
  name="io-${build}"
  run_model "${name}" "${build}" "${ranks}" P44-IO
  grep -q 'P4-EV01 PASS' "${RUN_ROOT}/${name}/combined.log" \
    || fail "event IO pass absent: ${build}"
  record_pass "p4-ev01-${build}" 'two flushes, empty flush, SHA manifest and injected rollback'
  reported_sha="$(sed -n 's/^.*P44-SHA DATA //p' "${RUN_ROOT}/${name}/combined.log" | sort -u)"
  expected_sha="$(sha256sum "${RUN_ROOT}/${name}/data" | awk '{print $1}')"
  [[ "${reported_sha}" == "${expected_sha}" ]] \
    || fail "Fortran SHA-256 differs from sha256sum: ${build}"
  record_pass "p44-sha-${build}" 'pure Fortran SHA-256 equals coreutils oracle'
  python3 "${CASE_DIR}/reference/p44_artifact_audit.py" \
    "${RUN_ROOT}/${name}" --events --expected-ranks "${ranks}" \
    --expected-records "$((5*ranks))" \
    > "${RUN_ROOT}/${name}/event-audit.txt"
  record_pass "p4-ev01-audit-${build}" \
    'canonical records independent of shard/rank traversal order'
done

for law_spec in 'none N' 'ebomb E'; do
  read -r law law_code <<< "${law_spec}"
  for spec in 'serial 1' 'mpi2 2' 'mpi4 4'; do
    read -r build ranks <<< "${spec}"
    writer="write-${law}-${build}"
    reader="read-${law}-${build}"
    run_model "${writer}" "${build}" "${ranks}" "P44-WRITE-${law_code}"
    grep -q 'P4-S01/B15 WRITE PASS' "${RUN_ROOT}/${writer}/combined.log" \
      || fail "schema4 writer pass absent: ${law}/${build}"
    record_pass "p44-write-${law}-${build}" \
      'pickup, trajectory, P3/P4 sidecars, event shards and manifests'
    prepare_run "${reader}" "${build}" "P44-READ-${law_code}"
    copy_boundary "${RUN_ROOT}/${writer}" "${RUN_ROOT}/${reader}"
    if [[ "${ranks}" -eq 1 ]]; then
      (cd "${RUN_ROOT}/${reader}" && ./mitgcmuv > run.log 2>&1)
      cp "${RUN_ROOT}/${reader}/run.log" "${RUN_ROOT}/${reader}/combined.log"
    else
      (cd "${RUN_ROOT}/${reader}" && mpirun -np "${ranks}" ./mitgcmuv > mpi-launch.log 2>&1)
      : > "${RUN_ROOT}/${reader}/combined.log"
      for ((rank=0; rank<ranks; rank++)); do
        cat "${RUN_ROOT}/${reader}/STDOUT.$(printf '%04d' "${rank}")" \
          >> "${RUN_ROOT}/${reader}/combined.log"
      done
    fi
    grep -q 'PROGRAM MAIN: Execution ended Normally' "${RUN_ROOT}/${reader}/combined.log" \
      || fail "restart normal end absent: ${law}/${build}"
    grep -q 'B15/B18 READ PASS' "${RUN_ROOT}/${reader}/combined.log" \
      || fail "restart pass absent: ${law}/${build}"
    record_pass "b15-read-${law}-${build}" \
      'same-decomposition schema4 restart, T/N bracket and budget'
    sed -n 's/^.*P44-NEXT /P44-NEXT /p' "${RUN_ROOT}/${writer}/combined.log" | sort -u \
      > "${RUN_ROOT}/${writer}/next.txt"
    sed -n 's/^.*P44-NEXT /P44-NEXT /p' "${RUN_ROOT}/${reader}/combined.log" | sort -u \
      > "${RUN_ROOT}/${reader}/next.txt"
    cmp "${RUN_ROOT}/${writer}/next.txt" "${RUN_ROOT}/${reader}/next.txt" \
      || fail "subsequent Philox/ID state differs: ${law}/${build}"
    sed -n 's/^.*P44-STATE CONT /P44-STATE /p' "${RUN_ROOT}/${writer}/combined.log" | sort \
      > "${RUN_ROOT}/${writer}/state.txt"
    sed -n 's/^.*P44-STATE SPLIT /P44-STATE /p' "${RUN_ROOT}/${reader}/combined.log" | sort \
      > "${RUN_ROOT}/${reader}/state.txt"
    cmp "${RUN_ROOT}/${writer}/state.txt" "${RUN_ROOT}/${reader}/state.txt" \
      || fail "continuous/split owner state differs: ${law}/${build}"
    record_pass "b15-bitwise-${law}-${build}" \
      'P3/P4 owner state and next Philox/ID state are bitwise equal'
    python3 "${CASE_DIR}/reference/p44_artifact_audit.py" \
      "${RUN_ROOT}/${writer}" > "${RUN_ROOT}/${writer}/artifact-audit.txt"
    record_pass "p4-s01-audit-${law}-${build}" \
      'manifest SHA, released cores, sidecars and event provenance'
  done
done

for mutation in manifest p4-header parent-hi parent-lo amount-s birth-count \
  record-order sidecar-count sidecar-truncate sidecar-append sidecar-missing \
  signature p4bio-byte event-manifest event-truncate event-append; do
  name="negative-${mutation}"
  prepare_run "${name}" serial P44-READ-N
  copy_boundary "${RUN_ROOT}/write-none-serial" "${RUN_ROOT}/${name}"
  python3 "${CASE_DIR}/reference/p44_artifact_audit.py" \
    "${RUN_ROOT}/${name}" --mutate "${mutation}"
  set +e
  (cd "${RUN_ROOT}/${name}" && ./mitgcmuv > run.log 2>&1)
  status=$?
  set -e
  if grep -q 'PROGRAM MAIN: Execution ended Normally' \
    "${RUN_ROOT}/${name}/run.log"; then
    fail "mutation accepted: ${mutation} (status ${status})"
  fi
  grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE' \
    "${RUN_ROOT}/${name}/run.log" \
    || fail "fatal rejection marker absent: ${mutation} (status ${status})"
  grep -q 'schema-4 preflight' "${RUN_ROOT}/${name}/run.log" \
    || fail "schema4 pre-publication rejection absent: ${mutation}"
  record_pass "p4-s01-${mutation}" 'rejected before owner-sidecar publication'
done

for law_spec in 'none N' 'ebomb E'; do
  read -r law law_code <<< "${law_spec}"
  name="changed-decomposition-${law}"
  prepare_run "${name}" mpi2 "P44-READ-${law_code}"
  copy_boundary "${RUN_ROOT}/write-${law}-serial" "${RUN_ROOT}/${name}"
  set +e
  (cd "${RUN_ROOT}/${name}" && mpirun -np 2 ./mitgcmuv > mpi-launch.log 2>&1)
  status=$?
  set -e
  cat "${RUN_ROOT}/${name}/mpi-launch.log" \
    "${RUN_ROOT}/${name}"/STDOUT.* "${RUN_ROOT}/${name}"/STDERR.* \
    > "${RUN_ROOT}/${name}/combined.log"
  if grep -q 'PROGRAM MAIN: Execution ended Normally' \
    "${RUN_ROOT}/${name}/combined.log"; then
    fail "changed decomposition accepted: ${law} (status ${status})"
  fi
  grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE' \
    "${RUN_ROOT}/${name}/combined.log" \
    || fail "changed-decomposition fatal marker absent: ${law}"
  grep -Eq 'schema-4 preflight|signature mismatch' \
    "${RUN_ROOT}/${name}/combined.log" \
    || fail "changed-decomposition rejection marker absent: ${law}"
  record_pass "b15-changed-decomposition-${law}" \
    'rejected before state publication'
done
record_pass p44-manifest '57/57 rows and checksummed evidence copied'
rows="$(tail -n +2 "${RUN_ROOT}/summary.tsv" | wc -l)"
[[ "${rows}" -eq "${EXPECTED_ROWS}" ]] \
  || fail "summary row count ${rows}, expected ${EXPECTED_ROWS}"
if grep -v $'\tPASS\t' "${RUN_ROOT}/summary.tsv" | tail -n +2 | grep -q .; then
  fail 'non-PASS result in summary'
fi
sha256sum "${RUN_ROOT}/summary.tsv" > "${RUN_ROOT}/summary.sha256"
cp -a "${RUN_ROOT}/." "${ARTIFACT_ROOT}/"

printf 'P4.4 DIRECT GATE PASS: 57/57\n'
printf 'artifact: %s\n' "${ARTIFACT_ROOT}"
