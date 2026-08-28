#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:-$(git -C "${REPO_ROOT}" rev-parse HEAD)}"
readonly BASELINE_REF="${MITGCM_BOM_BASELINE_REF:-MITGCM-BOM/development}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p34-components-${EXPECTED_HEAD:0:10}-attempt01}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase03-components-schema3}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase03-components-schema3}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p34-components-schema3}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXPECTED_ROWS=42

fail() { printf 'P3.4 COMPONENT/SCHEMA3 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P3.4-components] %s\n' "$*"; }
record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

for command_name in awk bash cmp date find gfortran git grep make mpirun \
  nm python3 rg sed sha256sum shellcheck sort uname wc; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || fail "missing ${command_name}"
done
[[ "$(git -C "${REPO_ROOT}" rev-parse HEAD)" == "${EXPECTED_HEAD}" ]] \
  || fail 'current HEAD differs from MITGCM_BOM_EXPECTED_HEAD'
if [[ "${REQUIRE_CLEAN}" == yes ]]; then
  [[ -z "$(git -C "${REPO_ROOT}" status --porcelain=v1)" ]] \
    || fail 'authoritative run requires a clean worktree'
fi
git -C "${REPO_ROOT}" rev-parse --verify "${BASELINE_REF}^{commit}" \
  >/dev/null || fail "missing baseline ref ${BASELINE_REF}"
for root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${root}" ]] || fail "evidence root already exists: ${root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

source_audit() {
  local source_file sidecar_line graph_line commit_line
  git -C "${REPO_ROOT}" diff --name-only \
    "${BASELINE_REF}" > "${RUN_ROOT}/changed-paths.txt"
  if rg -i 'skrips|codex' "${RUN_ROOT}/changed-paths.txt"; then
    fail 'forbidden project identity in changed path'
  fi
  record_pass p34-source-scope \
    'P3.4 production/test paths only; independent project identity'

  grep -Fq 'PARAMETER ( bomComponentLabelSchema = 1 )' \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    || fail 'component label packet schema is not version 1'
  grep -Fq 'PARAMETER ( bomComponentLabelPacketInts = 10 )' \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    || fail 'component label packet width changed'
  grep -Fq 'PARAMETER ( bomComponentSizePacketInts = 5 )' \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    || fail 'component size packet width changed'
  grep -Fq 'CALL BOM_COMPONENTS_FINAL' \
    "${REPO_ROOT}/pkg/bom/bom_spring_stage.F" \
    || fail 'FINAL graph does not dispatch component solver'
  record_pass p34-component-contract \
    'versioned exact-ID packets and successful FINAL graph dispatch'

  grep -Fq 'PARAMETER ( bomOutputFields2  = 48 )' \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    || fail 'schema-2 trajectory width changed'
  grep -Fq 'PARAMETER ( bomPickupFields2  = 45 )' \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    || fail 'schema-2 pickup width changed'
  grep -Fq 'CALL BOM_WRITE_P3_SIDECAR' \
    "${REPO_ROOT}/pkg/bom/bom_write_trajectory.F" \
    "${REPO_ROOT}/pkg/bom/bom_write_pickup.F" \
    || fail 'schema-3 sidecar writer is not connected'
  grep -Fq 'CALL BOM_VALIDATE_P3_RESTART_GRAPH' \
    "${REPO_ROOT}/pkg/bom/bom_read_pickup.F" \
    || fail 'schema-3 restart graph validation is not connected'
  record_pass p34-schema-contract \
    'schema-2 cores retained with required P3 metadata/sidecar transaction'

  sidecar_line="$(grep -n 'CALL BOM_READ_P3_SIDECAR' \
    "${REPO_ROOT}/pkg/bom/bom_read_pickup.F" | cut -d: -f1)"
  graph_line="$(grep -n 'CALL BOM_VALIDATE_P3_RESTART_GRAPH' \
    "${REPO_ROOT}/pkg/bom/bom_read_pickup.F" | cut -d: -f1)"
  commit_line="$(grep -n 'One commit publishes' \
    "${REPO_ROOT}/pkg/bom/bom_read_pickup.F" | cut -d: -f1)"
  [[ "${sidecar_line}" -lt "${graph_line}" \
    && "${graph_line}" -lt "${commit_line}" ]] \
    || fail 'schema-3 validation does not precede authoritative commit'
  record_pass p34-schema-rollback-order \
    'sidecar and rebuilt FINAL graph validate before the single state commit'

  if rg -i 'MPI_(Gather|Gatherv|Allgather|Allgatherv)' \
    "${REPO_ROOT}/pkg/bom/bom_component_exchange.F" \
    "${REPO_ROOT}/pkg/bom/bom_components_final.F"; then
    fail 'prohibited global owner gather in component path'
  fi
  record_pass p34-no-global-gather \
    'label routes and hashed size rendezvous avoid global owner gather'

  : > "${RUN_ROOT}/fixed-line-overflow.txt"
  while IFS= read -r source_file; do
    awk 'length($0)>72 && substr($0,1,1)!="C" {print FNR ":" $0}' \
      "${source_file}" | sed "s#^#${source_file}:#" \
      >> "${RUN_ROOT}/fixed-line-overflow.txt"
  done < <(find "${REPO_ROOT}/pkg/bom" "${CASE_DIR}/code" \
    -maxdepth 1 -type f \( -name '*.F' -o -name '*.h' \) | sort)
  [[ ! -s "${RUN_ROOT}/fixed-line-overflow.txt" ]] \
    || fail 'non-comment fixed-form source exceeds column 72'
  record_pass p34-fixed-line \
    'P3.4 production and direct-driver fixed-form lines are bounded'
}

build_case() {
  local name="$1" size="$2" mpi="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_components_schema3.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_schema3_io.F" "${mods_dir}/"
  args=(
    "${REPO_ROOT}/tools/genmake2"
    "-rootdir=${REPO_ROOT}"
    "-mods=${mods_dir}"
    "-of=${OPTFILE}"
    -ieee
    -devel
  )
  [[ "${mpi}" == yes ]] && args+=( -mpi )
  (
    cd "${build_dir}"
    "${args[@]}" > genmake.log 2>&1
    make depend > build.log 2>&1
    make -j "${MAKE_JOBS}" >> build.log 2>&1
    nm mitgcmuv > symbols.txt
  )
  grep -qi 'bom_components_final' "${build_dir}/symbols.txt" \
    || fail "${name} missing component symbol"
  record_pass "build-${name}" \
    "genmake2/depend/compile/link and P3.4 symbols (${mpi})"
}

run_case() {
  local name="$1" np="$2"
  local case_run="${RUN_ROOT}/${name}"
  local -a outputs
  mkdir -p "${case_run}"
  cp -a "${CASE_DIR}/input/." "${case_run}/"
  (
    cd "${case_run}"
    if (( np == 1 )); then
      "${BUILD_ROOT}/${name}/mitgcmuv" > output.txt 2>&1
    else
      mpirun -np "${np}" "${BUILD_ROOT}/${name}/mitgcmuv" \
        > output.txt 2>&1
    fi
  )
  if (( np == 1 )); then
    outputs=( "${case_run}/output.txt" )
  else
    outputs=( "${case_run}"/STDOUT.* )
  fi
  rg -q 'P3-RF01 PASS' "${outputs[@]}" \
    || fail "${name} missing P3-RF01 PASS"
  rg -q 'P3-RF02 PASS' "${outputs[@]}" \
    || fail "${name} missing P3-RF02 PASS"
  rg -q 'P3-N07 PASS' "${outputs[@]}" \
    || fail "${name} missing P3-N07 PASS"
  rg --no-filename '^P34CANON ' "${outputs[@]}" | sort \
    > "${case_run}/canonical.txt"
  [[ "$(wc -l < "${case_run}/canonical.txt")" -eq 4 ]] \
    || fail "${name} canonical record count"
  record_pass "run-${name}-rf01" \
    "singleton/chain/ring/two-component FINAL labels np=${np}"
  record_pass "run-${name}-rf02" \
    "instantaneous merge/split without hysteresis np=${np}"
  record_pass "run-${name}-n07" \
    "component failure 24 leaves output sentinels unchanged np=${np}"
}

run_schema_case() {
  local name="$1" np="$2" law="$3"
  local initial_run="${RUN_ROOT}/${name}-${law}-initial"
  local restart_run="${RUN_ROOT}/${name}-${law}-restart"
  local canonical="${RUN_ROOT}/${name}-${law}-canonical.bin"
  local -a initial_outputs restart_outputs
  mkdir -p "${initial_run}" "${restart_run}"
  cp "${CASE_DIR}/input/data.pkg" "${initial_run}/data.pkg"
  cp "${CASE_DIR}/input/eedata" "${initial_run}/eedata"
  cp "${CASE_DIR}/input/data.schema.initial" "${initial_run}/data"
  cp "${CASE_DIR}/input/data.bom.${law}" "${initial_run}/data.bom"
  (
    cd "${initial_run}"
    if (( np == 1 )); then
      "${BUILD_ROOT}/${name}/mitgcmuv" > output.txt 2>&1
    else
      mpirun -np "${np}" "${BUILD_ROOT}/${name}/mitgcmuv" \
        > output.txt 2>&1
    fi
  )
  if (( np == 1 )); then
    initial_outputs=( "${initial_run}/output.txt" )
  else
    initial_outputs=( "${initial_run}"/STDOUT.* )
  fi
  rg -q 'P3-P01 PASS' "${initial_outputs[@]}" \
    || fail "${name}-${law} missing P3-P01 PASS"
  record_pass "schema-${name}-${law}-write" \
    "P3-P01 schema-3 core/sidecar writer np=${np}"

  cp "${CASE_DIR}/input/data.pkg" "${restart_run}/data.pkg"
  cp "${CASE_DIR}/input/eedata" "${restart_run}/eedata"
  cp "${CASE_DIR}/input/data.schema.restart" "${restart_run}/data"
  cp "${CASE_DIR}/input/data.bom.${law}" "${restart_run}/data.bom"
  cp "${initial_run}"/pickup_bom.p34schema3* "${restart_run}/"
  (
    cd "${restart_run}"
    if (( np == 1 )); then
      "${BUILD_ROOT}/${name}/mitgcmuv" > output.txt 2>&1
    else
      mpirun -np "${np}" "${BUILD_ROOT}/${name}/mitgcmuv" \
        > output.txt 2>&1
    fi
  )
  if (( np == 1 )); then
    restart_outputs=( "${restart_run}/output.txt" )
  else
    restart_outputs=( "${restart_run}"/STDOUT.* )
  fi
  rg -q 'P3-P02 PASS' "${restart_outputs[@]}" \
    || fail "${name}-${law} missing P3-P02 PASS"
  record_pass "schema-${name}-${law}-restart" \
    "P3-P02 continuous/split same-decomposition restart np=${np}"
  python3 "${CASE_DIR}/verify_schema3.py" \
    "${initial_run}" "${restart_run}" \
    --canonical-out "${canonical}" \
    > "${RUN_ROOT}/${name}-${law}-verify.txt"
  grep -q 'P3_SCHEMA3_VERIFY_PASS' \
    "${RUN_ROOT}/${name}-${law}-verify.txt" \
    || fail "${name}-${law} schema verifier did not pass"
  record_pass "schema-${name}-${law}-contract" \
    "P3-P01/P02/P03 widths, exact IDs, embedded P2 and bitwise files"
}

run_corruption_matrix() {
  local mutation corrupt_run status
  local valid_run="${RUN_ROOT}/serial-hooke-initial"
  local -a mutations=(
    missing-p3sig missing-sidecar signature-header signature-p2
    side-header particle-id raft-id neighbor raft-size spring-east
    spring-north truncate append reorder
  )
  for mutation in "${mutations[@]}"; do
    corrupt_run="${RUN_ROOT}/corrupt-${mutation}"
    mkdir -p "${corrupt_run}"
    cp "${CASE_DIR}/input/data.pkg" "${corrupt_run}/data.pkg"
    cp "${CASE_DIR}/input/eedata" "${corrupt_run}/eedata"
    cp "${CASE_DIR}/input/data.schema.restart" "${corrupt_run}/data"
    cp "${CASE_DIR}/input/data.bom.hooke" "${corrupt_run}/data.bom"
    cp "${valid_run}"/pickup_bom.p34schema3* "${corrupt_run}/"
    python3 "${CASE_DIR}/corrupt_schema3.py" \
      "${corrupt_run}" "${mutation}" \
      > "${corrupt_run}/mutation.txt"
    set +e
    (
      cd "${corrupt_run}"
      "${BUILD_ROOT}/serial/mitgcmuv" > output.txt 2>&1
    )
    status=$?
    set -e
    grep -aEq 'code=[[:space:]]*25' "${corrupt_run}/output.txt" \
      || fail "${mutation} did not fail with code 25 (status=${status})"
    if grep -aq 'P3-P02 PASS' "${corrupt_run}/output.txt"; then
      fail "${mutation} reached accepted restart publication"
    fi
  done
  record_pass p34-p04-corruption-matrix \
    '14 signature/header/field/length/order corruptions fail 25 pre-commit'
}

run_schema_mismatch() {
  local mismatch_run status
  local valid_run="${RUN_ROOT}/serial-hooke-initial"
  mismatch_run="${RUN_ROOT}/mismatch-law"
  mkdir -p "${mismatch_run}"
  cp "${CASE_DIR}/input/data.pkg" "${mismatch_run}/data.pkg"
  cp "${CASE_DIR}/input/eedata" "${mismatch_run}/eedata"
  cp "${CASE_DIR}/input/data.schema.restart" "${mismatch_run}/data"
  cp "${CASE_DIR}/input/data.bom.ebomb" "${mismatch_run}/data.bom"
  cp "${valid_run}"/pickup_bom.p34schema3* "${mismatch_run}/"
  set +e
  (
    cd "${mismatch_run}"
    "${BUILD_ROOT}/serial/mitgcmuv" > output.txt 2>&1
  )
  status=$?
  set -e
  grep -aEq 'code=[[:space:]]*25' "${mismatch_run}/output.txt" \
    || fail "spring-law mismatch did not fail 25 (status=${status})"
  record_pass p34-p03-law-mismatch \
    'valid eBOMB runtime rejects Hooke schema-3 pickup before publication'

  mismatch_run="${RUN_ROOT}/mismatch-decomposition"
  mkdir -p "${mismatch_run}"
  cp "${CASE_DIR}/input/data.pkg" "${mismatch_run}/data.pkg"
  cp "${CASE_DIR}/input/eedata" "${mismatch_run}/eedata"
  cp "${CASE_DIR}/input/data.schema.restart" "${mismatch_run}/data"
  cp "${CASE_DIR}/input/data.bom.hooke" "${mismatch_run}/data.bom"
  cp "${valid_run}"/pickup_bom.p34schema3* "${mismatch_run}/"
  set +e
  (
    cd "${mismatch_run}"
    mpirun -np 2 "${BUILD_ROOT}/mpi2/mitgcmuv" > output.txt 2>&1
  )
  status=$?
  set -e
  grep -aEq 'code=[[:space:]]*15' \
    "${mismatch_run}"/STDERR.* \
    || fail "decomposition mismatch did not fail 15 (status=${status})"
  if rg -q 'P3-P02 PASS' "${mismatch_run}"/STDOUT.* \
      "${mismatch_run}"/STDERR.*; then
    fail 'decomposition mismatch reached accepted restart publication'
  fi
  record_pass p34-p03-decomposition-mismatch \
    'schema-3 pickup rejects a changed process/tile decomposition'
}

source_audit
build_case serial SIZE.h.serial no
build_case mpi2 SIZE.h.mpi2 yes
build_case mpi4 SIZE.h.mpi4 yes
run_case serial 1
run_case mpi2 2
run_case mpi4 4
cmp -s "${RUN_ROOT}/serial/canonical.txt" \
  "${RUN_ROOT}/mpi2/canonical.txt" \
  || fail 'serial/MPI2 canonical component mismatch'
cmp -s "${RUN_ROOT}/serial/canonical.txt" \
  "${RUN_ROOT}/mpi4/canonical.txt" \
  || fail 'serial/MPI4 canonical component mismatch'
record_pass p34-component-bitwise \
  'canonical exact-ID/raft/neighbor records match serial, MPI2 and MPI4'

run_schema_case serial 1 hooke
run_schema_case mpi2 2 hooke
run_schema_case mpi4 4 hooke
run_schema_case serial 1 ebomb
run_schema_case mpi2 2 ebomb
run_schema_case mpi4 4 ebomb
cmp -s "${RUN_ROOT}/serial-hooke-canonical.bin" \
  "${RUN_ROOT}/mpi2-hooke-canonical.bin" \
  || fail 'Hooke serial/MPI2 schema sidecar mismatch'
cmp -s "${RUN_ROOT}/serial-hooke-canonical.bin" \
  "${RUN_ROOT}/mpi4-hooke-canonical.bin" \
  || fail 'Hooke serial/MPI4 schema sidecar mismatch'
record_pass p34-hooke-schema-bitwise \
  'Hooke canonical schema-3 diagnostics match serial, MPI2 and MPI4'
cmp -s "${RUN_ROOT}/serial-ebomb-canonical.bin" \
  "${RUN_ROOT}/mpi2-ebomb-canonical.bin" \
  || fail 'eBOMB serial/MPI2 schema sidecar mismatch'
cmp -s "${RUN_ROOT}/serial-ebomb-canonical.bin" \
  "${RUN_ROOT}/mpi4-ebomb-canonical.bin" \
  || fail 'eBOMB serial/MPI4 schema sidecar mismatch'
record_pass p34-ebomb-schema-bitwise \
  'eBOMB canonical schema-3 diagnostics match serial, MPI2 and MPI4'
run_corruption_matrix
run_schema_mismatch

actual_rows="$(awk -F '\t' 'NR>1 && $2=="PASS" {n++} END {print n+0}' \
  "${RUN_ROOT}/summary.tsv")"
[[ "${actual_rows}" -eq "${EXPECTED_ROWS}" ]] \
  || fail "summary rows ${actual_rows}/${EXPECTED_ROWS}"
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
cp "${RUN_ROOT}/fixed-line-overflow.txt" \
  "${ARTIFACT_ROOT}/fixed-line-overflow.txt"
cp "${RUN_ROOT}/changed-paths.txt" \
  "${ARTIFACT_ROOT}/changed-paths.txt"
cp "${RUN_ROOT}/serial/canonical.txt" \
  "${ARTIFACT_ROOT}/canonical-components.txt"
cp "${RUN_ROOT}/serial-hooke-canonical.bin" \
  "${ARTIFACT_ROOT}/canonical-hooke-schema3.bin"
cp "${RUN_ROOT}/serial-ebomb-canonical.bin" \
  "${ARTIFACT_ROOT}/canonical-ebomb-schema3.bin"
git -C "${REPO_ROOT}" status --short --branch \
  > "${ARTIFACT_ROOT}/git-status.txt"
git -C "${REPO_ROOT}" rev-parse HEAD \
  > "${ARTIFACT_ROOT}/source-head.txt"
(
  cd "${ARTIFACT_ROOT}"
  # shellcheck disable=SC2094
  find . -maxdepth 1 -type f ! -name manifest.sha256 -print0 \
    | sort -z | xargs -0 sha256sum > manifest.sha256
)
log "P3.4 COMPONENT/SCHEMA3 GATE PASS (${actual_rows}/${EXPECTED_ROWS})"
log "source head: ${EXPECTED_HEAD}"
log "evidence root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
