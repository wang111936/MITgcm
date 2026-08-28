#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly REFERENCE_DIR="${REPO_ROOT}/verification/bom/phase03-springs-neighbors/reference"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"
readonly EXPECTED_HEAD="${MITGCM_BOM_EXPECTED_HEAD:-$(git -C "${REPO_ROOT}" rev-parse HEAD)}"
readonly BASELINE_REF="${MITGCM_BOM_BASELINE_REF:-MITGCM-BOM/development}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly SCOPE_MODE="${MITGCM_BOM_SCOPE_MODE:-p31}"
readonly SHORT_HEAD="${EXPECTED_HEAD:0:10}"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p31-reference-${SHORT_HEAD}-attempt01}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase03-reference-laws}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase03-reference-laws}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p31-reference-laws}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly JULIA_BIN="${MITGCM_BOM_JULIA_BIN:-/home/wyl/opt/mitgcm-bom/juliaup/bin/julia}"
readonly JULIA_DEPOT="${MITGCM_BOM_JULIA_DEPOT:-/home/wyl/opt/mitgcm-bom/julia-depot}"
readonly JULIA_PROJECT="${MITGCM_BOM_JULIA_PROJECT:-/home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl}"
readonly EXPECTED_ROWS=34

fail() { printf 'P3.1 REFERENCE LAW GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P3.1-reference] %s\n' "$*"; }
record_pass() {
  printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"
}

for command_name in awk bash cmp date find gfortran git grep make mpirun \
  nm python3 sed sha256sum shellcheck sort uname; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || fail "missing ${command_name}"
done
[[ -x "${JULIA_BIN}" ]] || fail "missing Julia executable: ${JULIA_BIN}"
[[ -d "${JULIA_DEPOT}" ]] || fail "missing Julia depot: ${JULIA_DEPOT}"
[[ -d "${JULIA_PROJECT}" ]] || fail "missing Julia project: ${JULIA_PROJECT}"
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
python3 -m py_compile "${REFERENCE_DIR}/knn_oracle.py"
python3 -m py_compile "${REFERENCE_DIR}/compare_ebomb.py"
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"

scope_audit() {
  local path identity
  local -a allowed_production=(
    pkg/bom/BOM.h
    pkg/bom/bom_check.F
    pkg/bom/bom_pair_geometry.F
    pkg/bom/bom_readparms.F
    pkg/bom/bom_spring_pair.F
    pkg/bom/bom_validate_spring_config.F
  )
  [[ "${SCOPE_MODE}" == p31 || "${SCOPE_MODE}" == p32 ]] \
    || fail "unsupported MITGCM_BOM_SCOPE_MODE: ${SCOPE_MODE}"
  if [[ "${SCOPE_MODE}" == p32 ]]; then
    allowed_production+=(
      pkg/bom/BOM_GRAPH_SIZE.h
      pkg/bom/bom_build_cell_list.F
      pkg/bom/bom_build_neighbors.F
      pkg/bom/bom_init_cell_geometry.F
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
    if [[ "${SCOPE_MODE}" == p31 \
      && "${path}" =~ (^|/)(cell|ghost|component|schema|rk) ]]; then
      fail "P3.2+ path entered P3.1: ${path}"
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
  git -C "${REPO_ROOT}" diff --quiet \
    "${BASELINE_REF}...${EXPECTED_HEAD}" -- pkg/bom/bom_main.F \
    || fail 'NONE production dispatcher changed in P3.1'
  record_pass p3-z01-scope \
    'P3.1 paths bounded; v0.3 dispatcher unchanged; identities exact'
}

source_isolation_audit() {
  local call_hits unexpected_hits
  if grep -RniE 'knn|delta[_ ]?l|all[-_ ]?pairs' \
    "${REPO_ROOT}/pkg/bom" --include='*.F' --include='*.h' \
    > "${RUN_ROOT}/forbidden-oracle-source.txt"; then
    fail 'verification-only KNN/all-pairs text found in pkg/bom'
  fi
  call_hits="$(grep -RniE \
    'CALL[[:space:]]+BOM_(PAIR_GEOMETRY|SPRING_PAIR|SPRING_ACCUMULATE)' \
    "${REPO_ROOT}/pkg/bom" --include='*.F' || true)"
  unexpected_hits="${call_hits}"
  if [[ "${SCOPE_MODE}" == p32 ]]; then
    unexpected_hits="$(printf '%s\n' "${call_hits}" | grep -vE \
      '/pkg/bom/bom_build_neighbors.F:.*CALL[[:space:]]+BOM_PAIR_GEOMETRY' \
      || true)"
  fi
  [[ -z "${unexpected_hits}" ]] \
    || fail 'P3.1 spring kernels entered an unapproved production path'
  record_pass p3-reference-isolation \
    'KNN remains verification-only and live NONE dispatch has no law calls'
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
  cp "${CASE_DIR}/code/bom_verify_reference_laws.F" "${mods_dir}/"
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
  for symbol in bom_validate_spring_config_ bom_pair_geometry_ \
    bom_safe_norm2_rl_ bom_spring_pair_ bom_spring_accumulate_ \
    bom_safe_div_rl_ bom_verify_reference_laws_; do
    grep -q "${symbol}" "${build_dir}/symbols.txt" \
      || fail "missing symbol ${symbol} in ${name}"
  done
  if grep -Eqi 'knn|delta[_]?l' "${build_dir}/symbols.txt"; then
    fail "verification oracle linked into ${name}"
  fi
  record_pass "build-${name}" 'debug/IEEE build and required P3.1 symbols'
}

prepare_run() {
  local run_dir="$1" build="$2" bom_file="$3"
  mkdir -p "${run_dir}"
  cp "${CASE_DIR}/input/data" "${run_dir}/data"
  cp "${CASE_DIR}/input/eedata" "${run_dir}/"
  cp "${CASE_DIR}/input/data.pkg" "${run_dir}/"
  cp "${bom_file}" "${run_dir}/data.bom"
  ln -s "${BUILD_ROOT}/${build}/mitgcmuv" "${run_dir}/mitgcmuv"
}

assert_direct_log() {
  local log_file="$1"
  for marker in 'P3-C01 PASS:' 'P3-D01 PASS:' 'B07 PASS:' \
    'B08 PASS:' 'P3-N03/P3-N05 PASS:' \
    'PROGRAM MAIN: Execution ended Normally'; do
    grep -q "${marker}" "${log_file}" || fail "missing ${marker}: ${log_file}"
  done
  if grep -Eq 'ABNORMAL END|fatal error|S/R ALL_PROC_DIE' "${log_file}"; then
    fail "fatal marker found: ${log_file}"
  fi
}

run_default_serial() {
  local run_dir="${RUN_ROOT}/serial"
  prepare_run "${run_dir}" serial "${CASE_DIR}/input/data.bom"
  (cd "${run_dir}" && ./mitgcmuv > run.log 2>&1)
  assert_direct_log "${run_dir}/run.log"
  grep 'P31-LAW-RECORD' "${run_dir}/run.log" \
    | sed 's/^.*P31-LAW-RECORD/P31-LAW-RECORD/' \
    | sort > "${RUN_ROOT}/serial.records"
  record_pass p3-c01-serial 'inactive defaults and exact stable codes'
  record_pass p3-d01-serial 'canonical Cartesian/spherical/periodic geometry'
  record_pass p3-s01-serial 'Hooke signs, centre and RK2/RK4 convergence'
  record_pass p3-s02-serial 'stable eBOMB logistic and locked SI case'
  record_pass p3-n03-n05-serial 'failure codes and transactional sentinels'
}

run_default_mpi4() {
  local run_dir="${RUN_ROOT}/mpi4" rank
  prepare_run "${run_dir}" mpi4 "${CASE_DIR}/input/data.bom"
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
  grep 'P31-LAW-RECORD' "${run_dir}"/STDOUT.* \
    | sed 's/^.*P31-LAW-RECORD/P31-LAW-RECORD/' \
    | sort > "${RUN_ROOT}/mpi4.records"
  record_pass p3-c01-mpi4 'collective inactive defaults and stable codes'
  record_pass p3-d01-mpi4 'collective canonical geometry'
  record_pass p3-s01-mpi4 'collective Hooke direct kernel'
  record_pass p3-s02-mpi4 'collective eBOMB direct kernel'
  record_pass p3-n03-n05-mpi4 'collective negative kernels'
}

write_config() {
  local file="$1" mode="$2" law="$3" policy="$4"
  local spring_l="$5" hooke_k="$6" spring_a="$7" delta="$8"
  local cutoff="$9" pair_min="${10}" spring_cfl="${11}" raft="${12}"
  {
    printf '%s\n' ' &BOM_PARM01'
    printf " bomMode='%s',\n" "${mode}"
    printf '%s\n' " bomEquationMode='PAPER2024'," " bomIntegrator='RK4',"
    printf '%s\n' ' bomDeltaTTarget=300.,' ' bomMaxParticles=0,'
    printf '%s\n' " bomInitialFile=' ',"
    printf " bomSpringLaw='%s',\n" "${law}"
    printf " bomNeighborPolicy='%s',\n" "${policy}"
    printf '%s\n' ' &'
    printf '%s\n' ' &BOM_PARM02'
    printf '%s\n' " bomCurrentPolicy='EULERIAN'," ' bomAlpha=0.,'
    printf '%s\n' ' bomTauDays=0.0103,' ' bomR=0.823,' ' bomSigma=0.,'
    printf '%s\n' ' bomLeewayWindCoeff=0.,' " bomWindSource='NONE',"
    printf '%s\n' " bomStokesSource='NONE'," ' bomAdvCFL=0.5,'
    printf ' bomSpringL=%s,\n' "${spring_l}"
    printf ' bomHookeK=%s,\n' "${hooke_k}"
    printf ' bomSpringA=%s,\n' "${spring_a}"
    printf ' bomSpringDelta=%s,\n' "${delta}"
    printf ' bomNeighborCutoff=%s,\n' "${cutoff}"
    printf ' bomPairDistanceMin=%s,\n' "${pair_min}"
    printf ' bomSpringCFL=%s,\n' "${spring_cfl}"
    printf ' bomRaftDiagnostics=%s,\n' "${raft}"
    printf '%s\n' ' &'
  } > "${file}"
}

run_config_accept() {
  local name="$1"; shift
  local run_dir="${RUN_ROOT}/config-${name}"
  mkdir -p "${run_dir}"
  write_config "${run_dir}/source.data.bom" "$@"
  prepare_run "${run_dir}/run" serial "${run_dir}/source.data.bom"
  (cd "${run_dir}/run" && ./mitgcmuv > run.log 2>&1)
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${run_dir}/run/run.log" \
    || fail "accepted config did not end normally: ${name}"
  if grep -Eq 'invalid Phase-3 spring configuration|ABNORMAL END|fatal error' \
    "${run_dir}/run/run.log"; then
    fail "accepted config failed: ${name}"
  fi
  record_pass "p3-c01-accept-${name}" 'legal SI namelist parsed before state init'
}

run_config_reject() {
  local name="$1"; shift
  local run_dir="${RUN_ROOT}/config-${name}" status
  mkdir -p "${run_dir}"
  write_config "${run_dir}/source.data.bom" "$@"
  prepare_run "${run_dir}/run" serial "${run_dir}/source.data.bom"
  set +e
  (cd "${run_dir}/run" && ./mitgcmuv > run.log 2>&1)
  status=$?
  set -e
  printf '%s\n' "${status}" > "${run_dir}/exit-status.txt"
  grep -q 'invalid Phase-3 spring configuration' "${run_dir}/run/run.log" \
    || fail "config validator marker missing: ${name}"
  grep -Eq 'failCode= *16' "${run_dir}/run/run.log" \
    || fail "stable failure 16 missing: ${name}"
  grep -q 'ABNORMAL END: S/R BOM_CHECK' "${run_dir}/run/run.log" \
    || fail "BOM_CHECK stop marker missing: ${name}"
  if grep -Eq 'P3-C01 PASS:|PROGRAM MAIN: Execution ended Normally' \
    "${run_dir}/run/run.log"; then
    fail "invalid config reached state/direct kernels: ${name}"
  fi
  record_pass "p3-c01-reject-${name}" 'stable failure 16 before state initialization'
}

run_knn_oracle() {
  python3 "${REFERENCE_DIR}/knn_oracle.py" \
    "${REFERENCE_DIR}/knn_fixtures.json" \
    --output "${RUN_ROOT}/knn-results.json" > "${RUN_ROOT}/knn.log"
  python3 "${REFERENCE_DIR}/knn_oracle.py" \
    "${REFERENCE_DIR}/knn_fixtures.json" \
    --output "${RUN_ROOT}/knn-results-repeat.json" \
    > "${RUN_ROOT}/knn-repeat.log"
  grep -q 'P3-K01 PASS: 5 accepted fixtures' "${RUN_ROOT}/knn.log" \
    || fail 'P3-K01 marker missing'
  cmp -s "${RUN_ROOT}/knn-results.json" \
    "${RUN_ROOT}/knn-results-repeat.json" \
    || fail 'KNN oracle output is not repeatable'
  record_pass p3-k01 'K non-self, clamp, median, ID ties and permutations'
}

run_locked_julia() {
  JULIA_DEPOT_PATH="${JULIA_DEPOT}" "${JULIA_BIN}" --startup-file=no \
    --project="${JULIA_PROJECT}" \
    "${REFERENCE_DIR}/locked_julia_delta_l.jl" \
    > "${RUN_ROOT}/julia-raw.stdout" 2> "${RUN_ROOT}/julia-raw.stderr"
  grep -E '^(fixture|line-even|unit-square)' \
    "${RUN_ROOT}/julia-raw.stdout" > "${RUN_ROOT}/julia-actual.tsv"
  awk -F '\t' 'BEGIN{OFS="\t"}
    NR==1 {print "fixture","julia_k_including_self","literal_delta_l"}
    NR>1 {print $1,$2,$4}' \
    "${REFERENCE_DIR}/locked_julia_delta_l.tsv" \
    > "${RUN_ROOT}/julia-expected.tsv"
  cmp -s "${RUN_ROOT}/julia-actual.tsv" "${RUN_ROOT}/julia-expected.tsv" \
    || fail 'locked Julia DeltaL values changed'
  record_pass p3-k01-julia \
    'literal self-count convention differs from canonical line K=2 as frozen'
  JULIA_DEPOT_PATH="${JULIA_DEPOT}" "${JULIA_BIN}" --startup-file=no \
    --project="${JULIA_PROJECT}" \
    "${REFERENCE_DIR}/locked_julia_ebomb.jl" \
    > "${RUN_ROOT}/julia-ebomb-raw.stdout" \
    2> "${RUN_ROOT}/julia-ebomb-raw.stderr"
  grep -E '^(fixture|ebomb-200m)' \
    "${RUN_ROOT}/julia-ebomb-raw.stdout" \
    > "${RUN_ROOT}/julia-ebomb-actual.tsv"
  cmp -s "${RUN_ROOT}/julia-ebomb-actual.tsv" \
    "${REFERENCE_DIR}/locked_julia_ebomb.tsv" \
    || fail 'locked Julia BOMBSpring 200 m value changed'
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
    printf 'python\t%s\n' "$(python3 --version)"
    printf 'julia\t%s\n' "$(${JULIA_BIN} --version)"
    printf 'require_clean\t%s\n' "${REQUIRE_CLEAN}"
  } > "${ARTIFACT_ROOT}/metadata.tsv"
}

log 'scope and isolation audits'
scope_audit
source_isolation_audit
log 'build serial and MPI4'
build_case serial SIZE.h.serial no
build_case mpi4 SIZE.h.mpi4 yes
log 'run verification-only KNN and locked Julia references'
run_knn_oracle
run_locked_julia
log 'run direct law kernels in serial and MPI4'
run_default_serial
run_default_mpi4
[[ "$(wc -l < "${RUN_ROOT}/serial.records")" -eq 4 ]] \
  || fail 'serial direct record count is not 4'
[[ "$(wc -l < "${RUN_ROOT}/mpi4.records")" -eq 4 ]] \
  || fail 'MPI4 direct record count is not 4'
cmp -s "${RUN_ROOT}/serial.records" "${RUN_ROOT}/mpi4.records" \
  || fail 'serial/MPI4 direct records differ'
record_pass p3-reference-decomposition \
  'four sorted direct records are bitwise serial/MPI4 equal'
python3 "${REFERENCE_DIR}/compare_ebomb.py" \
  "${RUN_ROOT}/serial.records" "${RUN_ROOT}/julia-ebomb-actual.tsv" \
  > "${RUN_ROOT}/ebomb-julia-comparison.log"
grep -q 'P3-S02-JULIA PASS:' "${RUN_ROOT}/ebomb-julia-comparison.log" \
  || fail 'Fortran/Julia eBOMB comparison marker missing'
record_pass p3-s02-julia \
  'stable SI kernel agrees with locked Julia BOMBSpring 200 m case'

log 'run accepted SI configurations'
run_config_accept hooke BOM HOOKE CUTOFF \
  1000. 2.E-4 0. 0. 3000. 1.E-6 0.5 .FALSE.
run_config_accept ebomb BOM EBOMB CUTOFF \
  1000. 0. 3.E-4 200. 3600. 1.E-6 0.4 .TRUE.

log 'run fail-before-state configuration matrix'
run_config_reject leew-spring LEEW HOOKE CUTOFF \
  1000. 2.E-4 0. 0. 3000. 1.E-6 0.5 .FALSE.
run_config_reject missing-cutoff BOM HOOKE CUTOFF \
  1000. 2.E-4 0. 0. 0. 1.E-6 0.5 .FALSE.
run_config_reject wrong-policy BOM HOOKE NONE \
  1000. 2.E-4 0. 0. 3000. 1.E-6 0.5 .FALSE.
run_config_reject nonpositive-l BOM HOOKE CUTOFF \
  0. 2.E-4 0. 0. 3000. 1.E-6 0.5 .FALSE.
run_config_reject nonpositive-hooke BOM HOOKE CUTOFF \
  1000. 0. 0. 0. 3000. 1.E-6 0.5 .FALSE.
run_config_reject nonpositive-a BOM EBOMB CUTOFF \
  1000. 0. 0. 200. 3600. 1.E-6 0.5 .FALSE.
run_config_reject nonpositive-delta BOM EBOMB CUTOFF \
  1000. 0. 3.E-4 0. 3600. 1.E-6 0.5 .FALSE.
run_config_reject bad-pair-min BOM HOOKE CUTOFF \
  1000. 2.E-4 0. 0. 3000. 0. 0.5 .FALSE.
run_config_reject cutoff-not-above-pair BOM HOOKE CUTOFF \
  1000. 2.E-4 0. 0. 100. 100. 0.5 .FALSE.
run_config_reject bad-cfl BOM HOOKE CUTOFF \
  1000. 2.E-4 0. 0. 3000. 1.E-6 0. .FALSE.
run_config_reject half-period BOM HOOKE CUTOFF \
  1000. 2.E-4 0. 0. 4250. 1.E-6 0.5 .FALSE.
run_config_reject none-cutoff BOM NONE CUTOFF \
  0. 0. 0. 0. 0. 0. 0.5 .FALSE.
run_config_reject none-raft BOM NONE NONE \
  0. 0. 0. 0. 0. 0. 0.5 .TRUE.
run_config_reject bad-law BOM BAD NONE \
  0. 0. 0. 0. 0. 0. 0.5 .FALSE.

expected_cases=(
  build-mpi4
  build-serial
  p3-c01-accept-ebomb
  p3-c01-accept-hooke
  p3-c01-mpi4
  p3-c01-reject-bad-cfl
  p3-c01-reject-bad-law
  p3-c01-reject-bad-pair-min
  p3-c01-reject-cutoff-not-above-pair
  p3-c01-reject-half-period
  p3-c01-reject-leew-spring
  p3-c01-reject-missing-cutoff
  p3-c01-reject-none-cutoff
  p3-c01-reject-none-raft
  p3-c01-reject-nonpositive-a
  p3-c01-reject-nonpositive-delta
  p3-c01-reject-nonpositive-hooke
  p3-c01-reject-nonpositive-l
  p3-c01-reject-wrong-policy
  p3-c01-serial
  p3-d01-mpi4
  p3-d01-serial
  p3-k01
  p3-k01-julia
  p3-n03-n05-mpi4
  p3-n03-n05-serial
  p3-reference-decomposition
  p3-reference-isolation
  p3-s01-mpi4
  p3-s01-serial
  p3-s02-mpi4
  p3-s02-julia
  p3-s02-serial
  p3-z01-scope
)
printf '%s\n' "${expected_cases[@]}" | sort \
  > "${RUN_ROOT}/expected-cases.txt"
awk -F '\t' 'NR>1 {print $1}' "${RUN_ROOT}/summary.tsv" | sort \
  > "${RUN_ROOT}/actual-cases.txt"
cmp -s "${RUN_ROOT}/expected-cases.txt" "${RUN_ROOT}/actual-cases.txt" \
  || fail 'summary case names differ from the frozen P3.1 matrix'
actual_rows="$(awk -F '\t' 'NR>1 {n++} END{print n+0}' \
  "${RUN_ROOT}/summary.tsv")"
[[ "${actual_rows}" -eq "${EXPECTED_ROWS}" ]] \
  || fail "expected ${EXPECTED_ROWS} rows, got ${actual_rows}"
awk -F '\t' 'NR>1 && $2!="PASS" {bad=1}
  END{exit bad}' "${RUN_ROOT}/summary.tsv" \
  || fail 'summary contains a non-PASS row'
duplicates="$(awk -F '\t' 'NR>1 {count[$1]++}
  END{for(name in count) if(count[name]!=1) print name}' \
  "${RUN_ROOT}/summary.tsv")"
[[ -z "${duplicates}" ]] || fail "duplicate summary rows: ${duplicates}"

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
cp "${RUN_ROOT}/serial.records" "${ARTIFACT_ROOT}/serial.records"
cp "${RUN_ROOT}/mpi4.records" "${ARTIFACT_ROOT}/mpi4.records"
cp "${RUN_ROOT}/changed-paths.txt" "${ARTIFACT_ROOT}/changed-paths.txt"
cp "${RUN_ROOT}/knn-results.json" "${ARTIFACT_ROOT}/knn-results.json"
cp "${RUN_ROOT}/julia-actual.tsv" "${ARTIFACT_ROOT}/julia-actual.tsv"
cp "${RUN_ROOT}/julia-ebomb-actual.tsv" \
  "${ARTIFACT_ROOT}/julia-ebomb-actual.tsv"
cp "${RUN_ROOT}/ebomb-julia-comparison.log" \
  "${ARTIFACT_ROOT}/ebomb-julia-comparison.log"
cp "${BUILD_ROOT}/serial/build.log" "${ARTIFACT_ROOT}/serial-build.log"
cp "${BUILD_ROOT}/mpi4/build.log" "${ARTIFACT_ROOT}/mpi4-build.log"
cp "${RUN_ROOT}/serial/run.log" "${ARTIFACT_ROOT}/serial-run.log"
cp "${RUN_ROOT}/mpi4/combined.log" "${ARTIFACT_ROOT}/mpi4-run.log"
git -C "${REPO_ROOT}" status --porcelain=v1 \
  > "${ARTIFACT_ROOT}/git-status.txt"
if [[ "${REQUIRE_CLEAN}" == yes && -s "${ARTIFACT_ROOT}/git-status.txt" ]]; then
  fail 'tests changed the exact-head worktree'
fi
git -C "${REPO_ROOT}" ls-files pkg/bom \
  verification/bom/phase03-reference-laws \
  verification/bom/phase03-springs-neighbors \
  | while IFS= read -r path; do
      sha256sum "${REPO_ROOT}/${path}"
    done > "${ARTIFACT_ROOT}/source-files.sha256"
find "${RUN_ROOT}" -type f -name 'source.data.bom' -print0 \
  | sort -z | xargs -0 sha256sum > "${ARTIFACT_ROOT}/generated-inputs.sha256"
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
log "P3.1 REFERENCE LAW GATE PASS (${EXPECTED_ROWS}/${EXPECTED_ROWS})"
log "source head: ${EXPECTED_HEAD}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
