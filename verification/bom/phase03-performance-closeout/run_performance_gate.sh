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
readonly REPLAY_SCOPE="${MITGCM_BOM_REPLAY_SCOPE:-none}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p35-performance-${EXPECTED_HEAD:0:10}-attempt01}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase03-performance-closeout}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase03-performance-closeout}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p35-performance-closeout}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-2}"
readonly EXPECTED_ROWS=20

fail() { printf 'P3.5 PERFORMANCE GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P3.5-performance] %s\n' "$*"; }
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
[[ "${REPLAY_SCOPE}" == none || "${REPLAY_SCOPE}" == predecessor ]] \
  || fail "unsupported MITGCM_BOM_REPLAY_SCOPE: ${REPLAY_SCOPE}"
git -C "${REPO_ROOT}" rev-parse --verify "${BASELINE_REF}^{commit}" \
  >/dev/null || fail "missing baseline ref ${BASELINE_REF}"
[[ -z "$(git -C "${REPO_ROOT}" tag -l MITGCM-BOM-v0.4)" ]] \
  || fail 'forbidden Phase-3 tag already exists'
for root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${root}" ]] || fail "evidence root already exists: ${root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
python3 -m py_compile "${CASE_DIR}/analyze_fixed_density.py"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

source_audit() {
  local source_file identity
  local -a collective_files expected_collective_files
  git -C "${REPO_ROOT}" diff --name-only \
    "${BASELINE_REF}...${EXPECTED_HEAD}" > "${RUN_ROOT}/changed-paths.txt"
  if rg -i 'skrips|codex' "${RUN_ROOT}/changed-paths.txt"; then
    fail 'forbidden project identity in changed path'
  fi
  while IFS= read -r identity; do
    [[ "${identity}" == \
      'WangYuLin <wang111936@outlook.com>|WangYuLin <wang111936@outlook.com>' ]] \
      || fail "unexpected author/committer identity: ${identity}"
  done < <(git -C "${REPO_ROOT}" log --format='%an <%ae>|%cn <%ce>' \
    "${BASELINE_REF}..${EXPECTED_HEAD}")
  record_pass p35-source-scope \
    'stacked P3.4/P3.5 paths only; exact identity; no forbidden tag'

  mapfile -t collective_files < <(
    rg -l 'CALL[[:space:]]+MPI_(Gather|Gatherv|Allgather|Allgatherv)' \
      "${REPO_ROOT}/pkg/bom" -g '*.F' | sort
  )
  expected_collective_files=(
    "${REPO_ROOT}/pkg/bom/bom_check_state.F"
    "${REPO_ROOT}/pkg/bom/bom_read_pickup.F"
  )
  if [[ "${REPLAY_SCOPE}" == predecessor ]]; then
    expected_collective_files+=(
      "${REPO_ROOT}/pkg/bom/bom_terminal_plan.F"
    )
    grep -Fq 'INTEGER localMeta(9),allMeta(9,nPx*nPy)' \
      "${REPO_ROOT}/pkg/bom/bom_terminal_plan.F" \
      || fail 'P4 failure metadata shape changed'
    grep -Fq 'localMeta,9,MPI_INTEGER' \
      "${REPO_ROOT}/pkg/bom/bom_terminal_plan.F" \
      || fail 'P4 failure gather send width changed'
    grep -Fq 'allMeta,9,MPI_INTEGER' \
      "${REPO_ROOT}/pkg/bom/bom_terminal_plan.F" \
      || fail 'P4 failure gather receive width changed'
    if [[ -f "${REPO_ROOT}/pkg/bom/bom_birth_order.F" ]] \
       && rg -q 'CALL[[:space:]]+MPI_(Allgather|Allgatherv)' \
         "${REPO_ROOT}/pkg/bom/bom_birth_order.F"; then
      expected_collective_files+=(
        "${REPO_ROOT}/pkg/bom/bom_birth_order.F"
      )
      grep -Fq 'PARAMETER ( metaInts=6 )' \
        "${REPO_ROOT}/pkg/bom/bom_birth_order.F" \
        || fail 'P4 parent-order metadata width changed'
      grep -Fq 'PARAMETER ( metaInts=13,metaReals=2 )' \
        "${REPO_ROOT}/pkg/bom/bom_birth_order.F" \
        || fail 'P4 accepted-birth metadata width changed'
      if rg -n 'bom(NPartTile|Status|Id|X|Y)[[:space:]]*\(' \
        "${REPO_ROOT}/pkg/bom/bom_birth_order.F"; then
        fail 'P4 birth-order collective references live owner arrays'
      fi
    fi
    if [[ -f "${REPO_ROOT}/pkg/bom/bom_p4_schema.F" ]] \
       && rg -q 'CALL[[:space:]]+MPI_Allgather' \
         "${REPO_ROOT}/pkg/bom/bom_p4_schema.F"; then
      expected_collective_files+=(
        "${REPO_ROOT}/pkg/bom/bom_p4_schema.F"
      )
      grep -Fq 'INTEGER hiAll(nCounts*nPx*nPy),loAll(nCounts*nPx*nPy)' \
        "${REPO_ROOT}/pkg/bom/bom_p4_schema.F" \
        || fail 'P4 exact-count gather shape changed'
      [[ "$(grep -c 'CALL MPI_Allgather' \
        "${REPO_ROOT}/pkg/bom/bom_p4_schema.F")" -eq 2 ]] \
        || fail 'P4 exact-count gather call count changed'
    fi
  fi
  mapfile -t expected_collective_files < <(
    printf '%s\n' "${expected_collective_files[@]}" | sort
  )
  [[ "${collective_files[*]}" == "${expected_collective_files[*]}" ]] \
    || fail 'unexpected global particle collective call path'
  grep -Fq 'CALL BOM_BUILD_CELL_LIST' \
    "${REPO_ROOT}/pkg/bom/bom_spring_stage.F" \
    || fail 'spring driver does not use production cell list'
  grep -Fq 'CALL BOM_BUILD_NEIGHBORS' \
    "${REPO_ROOT}/pkg/bom/bom_spring_stage.F" \
    || fail 'spring driver does not use production cutoff graph'
  if rg -i 'CALL[[:space:]]+BOM_P3[12]_.*ORACLE' \
    "${REPO_ROOT}/pkg/bom" -g '*.F'; then
    fail 'verification all-pairs oracle is reachable from production'
  fi
  record_pass p35-x01-source \
    'no spring/component gather; global-ID validation paths distinguished'

  grep -Fq 'PARAMETER ( bomP3CounterFields = 14 )' \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    || fail 'P3 counter width changed'
  grep -Fq 'SUBROUTINE BOM_P3_COUNTER_SNAPSHOT' \
    "${REPO_ROOT}/pkg/bom/bom_p3_counters.F" \
    || fail 'counter snapshot routine missing'
  if rg -n 'MPI_INTEGER8[[:space:]]*[,)]' \
    "${REPO_ROOT}/pkg/bom" -g '*.F' -g '*.h'; then
    fail 'non-portable MPI_INTEGER8 leaked into production'
  fi
  record_pass p35-counter-contract \
    '14 overflow-checked int64 counters; exact portable sum/max reduction'

  : > "${RUN_ROOT}/fixed-line-overflow.txt"
  for source_file in \
    "${REPO_ROOT}/pkg/bom/BOM_SIZE.h" \
    "${REPO_ROOT}/pkg/bom/BOM.h" \
    "${REPO_ROOT}/pkg/bom/bom_components_final.F" \
    "${REPO_ROOT}/pkg/bom/bom_init_state.F" \
    "${REPO_ROOT}/pkg/bom/bom_p3_counters.F" \
    "${REPO_ROOT}/pkg/bom/bom_p3_sidecar.F" \
    "${REPO_ROOT}/pkg/bom/bom_spring_ensemble.F" \
    "${REPO_ROOT}/pkg/bom/bom_spring_stage.F" \
    "${CASE_DIR}"/code/*.F \
    "${CASE_DIR}"/code/BOM_SIZE.h.performance; do
    awk 'length($0)>72 && substr($0,1,1)!="C" {print FNR ":" $0}' \
      "${source_file}" | sed "s#^#${source_file}:#" \
      >> "${RUN_ROOT}/fixed-line-overflow.txt"
  done
  [[ ! -s "${RUN_ROOT}/fixed-line-overflow.txt" ]] \
    || fail 'non-comment fixed-form source exceeds column 72'
  record_pass p35-fixed-line \
    'P3.5 production and direct-driver fixed-form lines are bounded'
}

build_case() {
  local name="$1" size="$2" mpi="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/BOM_SIZE.h.performance" \
    "${mods_dir}/BOM_SIZE.h"
  cp "${CASE_DIR}/code/packages.conf" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_init_varia.F" "${mods_dir}/"
  cp "${CASE_DIR}/code/bom_verify_performance.F" "${mods_dir}/"
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
  for symbol in bom_p3_counter_snapshot_ bom_p3_reduce_counters_ \
    bom_ghost_exchange_ bom_build_cell_list_ bom_build_neighbors_ \
    bom_verify_performance_closeout_; do
    grep -qi "${symbol}" "${build_dir}/symbols.txt" \
      || fail "${name} missing ${symbol}"
  done
  if grep -qiE 'bom_p3[12]_.*oracle|bom_p32_check_oracle' \
    "${build_dir}/symbols.txt"; then
    fail "${name} links a verification all-pairs oracle"
  fi
  record_pass "build-${name}" \
    "debug/IEEE build, production counters/ghost/cell/neighbor symbols (${mpi})"
}

prepare_run() {
  local run_dir="$1"
  mkdir -p "${run_dir}"
  cp -a "${CASE_DIR}/input/." "${run_dir}/"
}

run_case() {
  local name="$1" np="$2" rank
  local run_dir="${RUN_ROOT}/${name}"
  prepare_run "${run_dir}"
  (
    ulimit -s unlimited
    cd "${run_dir}"
    if (( np == 1 )); then
      "${BUILD_ROOT}/${name}/mitgcmuv" > output.txt 2>&1
      cp output.txt combined.log
    else
      mpirun -np "${np}" "${BUILD_ROOT}/${name}/mitgcmuv" \
        > mpi-launch.log 2>&1
      : > combined.log
      for ((rank=0; rank<np; rank++)); do
        cat "STDOUT.$(printf '%04d' "${rank}")" >> combined.log
        cat "STDERR.$(printf '%04d' "${rank}")" >> combined.log
      done
    fi
  )
  for marker in 'P3-X01 PASS:' 'P3-X02 PASS:' \
    'P3-X02-DENSE PASS:' 'PROGRAM MAIN: Execution ended Normally'; do
    grep -q "${marker}" "${run_dir}/combined.log" \
      || fail "${name} missing ${marker}"
  done
  [[ "$(grep -c 'P35METRIC' "${run_dir}/combined.log")" -eq $((6*np)) ]] \
    || fail "${name} metric record count"
  if grep -Eq 'P3.5 PERFORMANCE FAIL|ABNORMAL END|S/R ALL_PROC_DIE' \
    "${run_dir}/combined.log"; then
    fail "${name} contains fatal marker"
  fi
  record_pass "run-${name}-x01" \
    "portable exact >32-bit sum/max and overflow rollback np=${np}"
  record_pass "run-${name}-x02" \
    "16/32/64 Cartesian+spherical graph/communication bounds np=${np}"
  record_pass "run-${name}-dense" \
    "five-neighbor dense cell fails closed at capacity four np=${np}"
}

analyze_case() {
  local name="$1" np="$2"
  python3 "${CASE_DIR}/analyze_fixed_density.py" \
    "${RUN_ROOT}/${name}/combined.log" \
    --expected-ranks "${np}" \
    --output "${RUN_ROOT}/${name}-scaling.tsv" \
    > "${RUN_ROOT}/${name}-analysis.txt"
  grep -q 'P3_FIXED_DENSITY_ANALYSIS_PASS' \
    "${RUN_ROOT}/${name}-analysis.txt" \
    || fail "${name} fixed-density analysis did not pass"
  [[ "$(wc -l < "${RUN_ROOT}/${name}-scaling.tsv")" -eq 7 ]] \
    || fail "${name} scaling summary row count"
  record_pass "analysis-${name}" \
    "counter-gated scaling and informational timing statistics np=${np}"
}

write_metadata() {
  {
    printf 'test_id\t%s\n' "${TEST_ID}"
    printf 'source_head\t%s\n' "${EXPECTED_HEAD}"
    printf 'branch\t%s\n' "$(git -C "${REPO_ROOT}" branch --show-current)"
    printf 'baseline\t%s\n' "$(git -C "${REPO_ROOT}" rev-parse "${BASELINE_REF}")"
    printf 'utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'local\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)"
    printf 'uname\t%s\n' "$(uname -a)"
    printf 'gfortran\t%s\n' "$(gfortran --version | head -n 1)"
    printf 'mpi\t%s\n' "$(mpirun --version | head -n 1)"
    printf 'make_jobs\t%s\n' "${MAKE_JOBS}"
    printf 'timing_policy\tinformational-only\n'
  } > "${ARTIFACT_ROOT}/metadata.tsv"
}

log 'source, call-path and counter-contract audits'
source_audit
log 'build serial, MPI2 and MPI4 fixed-density executables'
build_case serial SIZE.h.serial no
build_case mpi2 SIZE.h.mpi2 yes
build_case mpi4 SIZE.h.mpi4 yes
log 'run counter, fixed-density and dense-cell groups'
run_case serial 1
run_case mpi2 2
run_case mpi4 4
analyze_case serial 1
analyze_case mpi2 2
analyze_case mpi4 4
record_pass p35-x02-matrix \
  'six fixtures each in serial/MPI2/MPI4; counters gate, timing informs'

expected_cases=(
  analysis-mpi2
  analysis-mpi4
  analysis-serial
  build-mpi2
  build-mpi4
  build-serial
  p35-counter-contract
  p35-fixed-line
  p35-source-scope
  p35-x01-source
  p35-x02-matrix
  run-mpi2-dense
  run-mpi2-x01
  run-mpi2-x02
  run-mpi4-dense
  run-mpi4-x01
  run-mpi4-x02
  run-serial-dense
  run-serial-x01
  run-serial-x02
)
printf '%s\n' "${expected_cases[@]}" | sort \
  > "${RUN_ROOT}/expected-cases.txt"
awk -F '\t' 'NR>1 {print $1}' "${RUN_ROOT}/summary.tsv" | sort \
  > "${RUN_ROOT}/actual-cases.txt"
cmp -s "${RUN_ROOT}/expected-cases.txt" "${RUN_ROOT}/actual-cases.txt" \
  || fail 'summary case names differ from P3.5 matrix'
actual_rows="$(awk -F '\t' 'NR>1 {n++} END{print n+0}' \
  "${RUN_ROOT}/summary.tsv")"
[[ "${actual_rows}" -eq "${EXPECTED_ROWS}" ]] \
  || fail "expected ${EXPECTED_ROWS} rows, got ${actual_rows}"
awk -F '\t' 'NR>1 && $2!="PASS" {bad=1} END{exit bad}' \
  "${RUN_ROOT}/summary.tsv" || fail 'summary contains a non-PASS row'

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
cp "${RUN_ROOT}"/*-scaling.tsv "${ARTIFACT_ROOT}/"
cp "${RUN_ROOT}"/*-analysis.txt "${ARTIFACT_ROOT}/"
cp "${RUN_ROOT}/changed-paths.txt" "${ARTIFACT_ROOT}/"
cp "${RUN_ROOT}/fixed-line-overflow.txt" "${ARTIFACT_ROOT}/"
for name in serial mpi2 mpi4; do
  cp "${BUILD_ROOT}/${name}/build.log" \
    "${ARTIFACT_ROOT}/${name}-build.log"
  cp "${BUILD_ROOT}/${name}/symbols.txt" \
    "${ARTIFACT_ROOT}/${name}-symbols.txt"
  cp "${RUN_ROOT}/${name}/combined.log" \
    "${ARTIFACT_ROOT}/${name}-run.log"
done
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${ARTIFACT_ROOT}/git-status.txt"
if [[ "${REQUIRE_CLEAN}" == yes \
  && -s "${ARTIFACT_ROOT}/git-status.txt" ]]; then
  fail 'tests changed the exact-head worktree'
fi
git -C "${REPO_ROOT}" ls-files pkg/bom \
  verification/bom/phase03-performance-closeout \
  | while IFS= read -r path; do
      sha256sum "${REPO_ROOT}/${path}"
    done > "${ARTIFACT_ROOT}/source-files.sha256"
write_metadata
(
  cd "${ARTIFACT_ROOT}"
  find . -type f ! -name manifest.sha256 ! -name manifest-check.log \
    -print0 | sort -z | xargs -0 sha256sum
) > "${RUN_ROOT}/manifest.sha256.tmp"
mv "${RUN_ROOT}/manifest.sha256.tmp" \
  "${ARTIFACT_ROOT}/manifest.sha256"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum -c manifest.sha256 > manifest-check.log
)
log "P3.5 PERFORMANCE GATE PASS (${EXPECTED_ROWS}/${EXPECTED_ROWS})"
log "source head: ${EXPECTED_HEAD}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
