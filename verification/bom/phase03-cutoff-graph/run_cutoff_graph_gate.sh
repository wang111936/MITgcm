#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly P31_CASE="${REPO_ROOT}/verification/bom/phase03-reference-laws"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:-$(git -C "${REPO_ROOT}" rev-parse HEAD)}"
readonly BASELINE_REF="${MITGCM_BOM_BASELINE_REF:-MITGCM-BOM/development}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly SCOPE_MODE="${MITGCM_BOM_SCOPE_MODE:-p32}"
readonly SHORT_HEAD="${EXPECTED_HEAD:0:10}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p32-cutoff-${SHORT_HEAD}-attempt01}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase03-cutoff-graph}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase03-cutoff-graph}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p32-cutoff-graph}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly EXPECTED_ROWS=18

fail() { printf 'P3.2 CUTOFF GRAPH GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P3.2-cutoff] %s\n' "$*"; }
record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

for command_name in awk bash cmp date find gfortran git grep make mpirun \
  nm sed sha256sum shellcheck sort uname; do
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
[[ -z "$(git -C "${REPO_ROOT}" tag -l MITGCM-BOM-v0.4)" ]] \
  || fail 'forbidden Phase-3 tag already exists'
for root in "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"; do
  [[ ! -e "${root}" ]] || fail "evidence root already exists: ${root}"
done
mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${ARTIFACT_ROOT}"
bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

scope_audit() {
  local path identity
  local -a allowed_production=(
    pkg/bom/BOM_GRAPH_SIZE.h
    pkg/bom/bom_build_cell_list.F
    pkg/bom/bom_build_neighbors.F
    pkg/bom/bom_init_cell_geometry.F
  )
  [[ "${SCOPE_MODE}" == p32 || "${SCOPE_MODE}" == p33 ]] \
    || fail "unsupported MITGCM_BOM_SCOPE_MODE: ${SCOPE_MODE}"
  if [[ "${SCOPE_MODE}" == p33 ]]; then
    allowed_production+=(
      pkg/bom/BOM.h
      pkg/bom/BOM_SIZE.h
      pkg/bom/bom_check.F
      pkg/bom/bom_check_state.F
      pkg/bom/bom_ghost_exchange.F
      pkg/bom/bom_init_state.F
      pkg/bom/bom_main.F
      pkg/bom/bom_particle_exchange.F
      pkg/bom/bom_spring_ensemble.F
      pkg/bom/bom_spring_rhs_stage.F
      pkg/bom/bom_spring_stage.F
    )
  fi
  git -C "${REPO_ROOT}" diff --name-only \
    "${BASELINE_REF}...${EXPECTED_HEAD}" > "${RUN_ROOT}/changed-paths.txt"
  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    if [[ "${path}" == pkg/bom/* ]]; then
      printf '%s\n' "${allowed_production[@]}" | grep -Fxq "${path}" \
        || fail "out-of-scope production path: ${path}"
    fi
    if [[ "${path,,}" =~ skrips|codex ]]; then
      fail "forbidden project path: ${path}"
    fi
  done < "${RUN_ROOT}/changed-paths.txt"
  while IFS= read -r identity; do
    [[ "${identity}" == \
      'WangYuLin <wang111936@outlook.com>|WangYuLin <wang111936@outlook.com>' ]] \
      || fail "unexpected author/committer identity: ${identity}"
  done < <(git -C "${REPO_ROOT}" log --format='%an <%ae>|%cn <%ce>' \
    "${BASELINE_REF}..${EXPECTED_HEAD}")
  if [[ "${SCOPE_MODE}" == p33 ]]; then
    grep -q 'CALL BOM_BUILD_CELL_LIST' \
      "${REPO_ROOT}/pkg/bom/bom_spring_stage.F" \
      || fail 'P3.3 cell-list integration is missing'
    grep -q 'CALL BOM_BUILD_NEIGHBORS' \
      "${REPO_ROOT}/pkg/bom/bom_spring_stage.F" \
      || fail 'P3.3 neighbor integration is missing'
  else
    git -C "${REPO_ROOT}" diff --quiet \
      "${BASELINE_REF}...${EXPECTED_HEAD}" -- pkg/bom/bom_main.F \
      || fail 'live dispatcher changed during P3.2 kernel work'
  fi
  record_pass p3-z01-scope \
    "P3.2 predecessor paths valid in ${SCOPE_MODE}; identities exact; no tag"
}

source_isolation_audit() {
  local source_file
  local -a production=(
    "${REPO_ROOT}/pkg/bom/bom_init_cell_geometry.F"
    "${REPO_ROOT}/pkg/bom/bom_build_cell_list.F"
    "${REPO_ROOT}/pkg/bom/bom_build_neighbors.F"
  )
  if grep -niE 'all[-_ ]?pairs|MPI_(Gather|Gatherv|Allgather|Allgatherv)' \
    "${production[@]}" > "${RUN_ROOT}/forbidden-production-source.txt"; then
    fail 'global gather or all-pairs path found in P3.2 production kernels'
  fi
  grep -q 'CALL BOM_APPEND_CELL_CANDIDATES' \
    "${REPO_ROOT}/pkg/bom/bom_build_neighbors.F" \
    || fail 'production graph does not use the bounded cell candidate path'
  grep -q 'CALL BOM_PAIR_GEOMETRY' \
    "${REPO_ROOT}/pkg/bom/bom_build_neighbors.F" \
    || fail 'production graph does not use canonical P3.1 geometry'
  if grep -qiE 'CALL[[:space:]]+BOM_(INIT_CELL_GEOMETRY|BUILD_CELL_LIST|BUILD_NEIGHBORS)' \
    "${REPO_ROOT}/pkg/bom/bom_main.F"; then
    fail 'P3.2 kernels entered live integration before P3.3'
  fi
  : > "${RUN_ROOT}/fixed-line-overflow.txt"
  for source_file in "${production[@]}" "${CASE_DIR}"/code/*.F \
    "${CASE_DIR}"/code/*.h; do
    awk 'length($0)>72 && substr($0,1,1)!="C" {print FNR ":" $0}' \
      "${source_file}" | sed "s#^#${source_file}:#" \
      >> "${RUN_ROOT}/fixed-line-overflow.txt"
  done
  [[ ! -s "${RUN_ROOT}/fixed-line-overflow.txt" ]] \
    || fail 'non-comment fixed-form source exceeds column 72'
  record_pass p3-r06-isolation \
    'owner-local bounded cell candidates; no production all-pairs/gather'
  record_pass p3-fixed-line \
    'all P3.2 production and direct-gate fixed-form lines are bounded'
}

build_case() {
  local name="$1" size="$2" mpi="$3"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${P31_CASE}/code/${size}" "${mods_dir}/SIZE.h"
  cp "${P31_CASE}/code/packages.conf" "${mods_dir}/"
  cp -a "${CASE_DIR}/code/." "${mods_dir}/"
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
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable ${name}"
  nm "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  for symbol in bom_init_cell_geometry_ bom_cell_axis_count_ \
    bom_cell_reach_ bom_cell_index_ bom_build_cell_list_ \
    bom_build_neighbors_ bom_append_cell_candidates_ \
    bom_candidate_after_ bom_find_neighbor_id_ \
    bom_verify_cutoff_graph_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing symbol ${symbol} in ${name}"
  done
  record_pass "build-${name}" \
    'debug/IEEE/bounds build and required P3.2 symbols'
}

prepare_run() {
  local run_dir="$1" build="$2"
  mkdir -p "${run_dir}"
  cp "${P31_CASE}/input/data" "${run_dir}/"
  cp "${P31_CASE}/input/eedata" "${run_dir}/"
  cp "${P31_CASE}/input/data.pkg" "${run_dir}/"
  cp "${P31_CASE}/input/data.bom" "${run_dir}/"
  ln -s "${BUILD_ROOT}/${build}/mitgcmuv" "${run_dir}/mitgcmuv"
}

assert_direct_log() {
  local log_file="$1"
  for marker in 'P3-L01 PASS:' 'P3-N01 PASS:' 'P3-L02 PASS:' \
    'P3-N02 PASS:' 'P3-N10 PASS:' 'P3-X01 PASS:' \
    'PROGRAM MAIN: Execution ended Normally'; do
    grep -q "${marker}" "${log_file}" \
      || fail "missing ${marker}: ${log_file}"
  done
  if grep -Eq 'P3.2 ASSERT FAIL|ABNORMAL END|fatal error|S/R ALL_PROC_DIE' \
    "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

run_serial() {
  local run_dir="${RUN_ROOT}/serial"
  prepare_run "${run_dir}" serial
  (cd "${run_dir}" && ./mitgcmuv > run.log 2>&1)
  [[ -f "${run_dir}/STDERR.0000" ]] \
    && cat "${run_dir}/STDERR.0000" >> "${run_dir}/run.log"
  assert_direct_log "${run_dir}/run.log"
  grep 'P32-GRAPH-RECORD' "${run_dir}/run.log" \
    | sed 's/^.*P32-GRAPH-RECORD/P32-GRAPH-RECORD/' \
    > "${RUN_ROOT}/serial.records"
  record_pass p3-l01-serial 'Cartesian faces, traversal and cross-tile owners'
  record_pass p3-n01-serial 'inclusive exact graph, sort, dedup and symmetry'
  record_pass p3-l02-serial 'spherical row reach, false positive and seam'
  record_pass p3-n02-serial 'five deterministic graph/spring oracle fixtures'
  record_pass p3-n10-serial 'cell/link/candidate/neighbor rollback accounting'
  record_pass p3-x01-serial '82-edge fixed-density graph with bounded work'
}

run_mpi4() {
  local run_dir="${RUN_ROOT}/mpi4" rank
  prepare_run "${run_dir}" mpi4
  (
    cd "${run_dir}"
    mpirun -np 4 ./mitgcmuv > mpi-launch.log 2>&1
    : > combined.log
    for rank in 0 1 2 3; do
      cat "STDOUT.$(printf '%04d' "${rank}")" >> combined.log
      cat "STDERR.$(printf '%04d' "${rank}")" >> combined.log
    done
  )
  assert_direct_log "${run_dir}/combined.log"
  grep 'P32-GRAPH-RECORD' "${run_dir}/STDOUT.0000" \
    | sed 's/^.*P32-GRAPH-RECORD/P32-GRAPH-RECORD/' \
    > "${RUN_ROOT}/mpi4.records"
  record_pass p3-l01-mpi4 'Cartesian cell list direct group under MPI4'
  record_pass p3-n01-mpi4 'exact symmetric cutoff graph under MPI4'
  record_pass p3-l02-mpi4 'spherical and periodic direct group under MPI4'
  record_pass p3-n02-mpi4 'deterministic all-pairs oracle under MPI4'
  record_pass p3-n10-mpi4 'transactional capacity failures under MPI4'
  record_pass p3-x01-mpi4 'balanced counters and bounded work under MPI4'
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
    printf 'require_clean\t%s\n' "${REQUIRE_CLEAN}"
  } > "${ARTIFACT_ROOT}/metadata.tsv"
}

log 'scope and production-isolation audits'
scope_audit
source_isolation_audit
log 'build serial and MPI4 direct gates'
build_case serial SIZE.h.serial no
build_case mpi4 SIZE.h.mpi4 yes
log 'run serial and MPI4 direct groups'
run_serial
run_mpi4
[[ "$(wc -l < "${RUN_ROOT}/serial.records")" -eq 5 ]] \
  || fail 'serial oracle record count is not 5'
[[ "$(wc -l < "${RUN_ROOT}/mpi4.records")" -eq 5 ]] \
  || fail 'MPI4 oracle record count is not 5'
cmp -s "${RUN_ROOT}/serial.records" "${RUN_ROOT}/mpi4.records" \
  || fail 'serial/MPI4 oracle records differ'
record_pass p3-decomposition \
  'five ID-sorted graph/spring records are bitwise serial/MPI4 equal'

expected_cases=(
  build-mpi4
  build-serial
  p3-decomposition
  p3-fixed-line
  p3-l01-mpi4
  p3-l01-serial
  p3-l02-mpi4
  p3-l02-serial
  p3-n01-mpi4
  p3-n01-serial
  p3-n02-mpi4
  p3-n02-serial
  p3-n10-mpi4
  p3-n10-serial
  p3-r06-isolation
  p3-x01-mpi4
  p3-x01-serial
  p3-z01-scope
)
printf '%s\n' "${expected_cases[@]}" | sort \
  > "${RUN_ROOT}/expected-cases.txt"
awk -F '\t' 'NR>1 {print $1}' "${RUN_ROOT}/summary.tsv" | sort \
  > "${RUN_ROOT}/actual-cases.txt"
cmp -s "${RUN_ROOT}/expected-cases.txt" "${RUN_ROOT}/actual-cases.txt" \
  || fail 'summary case names differ from the frozen P3.2 matrix'
actual_rows="$(awk -F '\t' 'NR>1 {n++} END{print n+0}' \
  "${RUN_ROOT}/summary.tsv")"
[[ "${actual_rows}" -eq "${EXPECTED_ROWS}" ]] \
  || fail "expected ${EXPECTED_ROWS} rows, got ${actual_rows}"
awk -F '\t' 'NR>1 && $2!="PASS" {bad=1} END{exit bad}' \
  "${RUN_ROOT}/summary.tsv" || fail 'summary contains a non-PASS row'
duplicates="$(awk -F '\t' 'NR>1 {count[$1]++}
  END{for(name in count) if(count[name]!=1) print name}' \
  "${RUN_ROOT}/summary.tsv")"
[[ -z "${duplicates}" ]] || fail "duplicate summary rows: ${duplicates}"

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
cp "${RUN_ROOT}/serial.records" "${ARTIFACT_ROOT}/serial.records"
cp "${RUN_ROOT}/mpi4.records" "${ARTIFACT_ROOT}/mpi4.records"
cp "${RUN_ROOT}/changed-paths.txt" "${ARTIFACT_ROOT}/changed-paths.txt"
cp "${RUN_ROOT}/fixed-line-overflow.txt" \
  "${ARTIFACT_ROOT}/fixed-line-overflow.txt"
cp "${BUILD_ROOT}/serial/build.log" "${ARTIFACT_ROOT}/serial-build.log"
cp "${BUILD_ROOT}/mpi4/build.log" "${ARTIFACT_ROOT}/mpi4-build.log"
cp "${RUN_ROOT}/serial/run.log" "${ARTIFACT_ROOT}/serial-run.log"
cp "${RUN_ROOT}/mpi4/combined.log" "${ARTIFACT_ROOT}/mpi4-run.log"
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${ARTIFACT_ROOT}/git-status.txt"
if [[ "${REQUIRE_CLEAN}" == yes \
  && -s "${ARTIFACT_ROOT}/git-status.txt" ]]; then
  fail 'tests changed the exact-head worktree'
fi
git -C "${REPO_ROOT}" ls-files pkg/bom \
  verification/bom/phase03-cutoff-graph \
  verification/bom/phase03-reference-laws \
  | while IFS= read -r path; do
      sha256sum "${REPO_ROOT}/${path}"
    done > "${ARTIFACT_ROOT}/source-files.sha256"
write_metadata
(
  cd "${ARTIFACT_ROOT}"
  find . -type f ! -name manifest.sha256 ! -name manifest-check.log \
    -print0 | sort -z | xargs -0 sha256sum
) > "${RUN_ROOT}/manifest.sha256.tmp"
mv "${RUN_ROOT}/manifest.sha256.tmp" "${ARTIFACT_ROOT}/manifest.sha256"
(
  cd "${ARTIFACT_ROOT}"
  sha256sum -c manifest.sha256 > manifest-check.log
)
log "P3.2 CUTOFF GRAPH GATE PASS (${EXPECTED_ROWS}/${EXPECTED_ROWS})"
log "source head: ${EXPECTED_HEAD}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
