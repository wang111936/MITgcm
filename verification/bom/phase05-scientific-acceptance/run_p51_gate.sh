#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p51-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
readonly BUILD_ROOT="${MITGCM_BOM_TEST_BUILD_ROOT:-/home/wyl/build/mitgcm-bom/phase05-scientific-acceptance}/${TEST_ID}"
readonly RUN_ROOT="${MITGCM_BOM_TEST_RUN_ROOT:-/home/wyl/runs/mitgcm-bom/phase05-scientific-acceptance}/${TEST_ID}"
readonly ARTIFACT_ROOT="${MITGCM_BOM_TEST_ARTIFACT_ROOT:-/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/scientific-acceptance}/${TEST_ID}"
readonly OPTFILE="${MITGCM_BOM_OPTFILE:-${REPO_ROOT}/tools/build_options/linux_amd64_gfortran}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-4}"
readonly REQUIRE_CLEAN="${MITGCM_BOM_REQUIRE_CLEAN:-yes}"
readonly EXP2_CODE="${REPO_ROOT}/verification/exp2/code"

fail() { printf 'P5.1 GATE FAIL: %s\n' "$*" >&2; exit 1; }
log() { printf '[P5.1] %s\n' "$*"; }
record_pass() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${RUN_ROOT}/summary.tsv"; }

readonly -a PREAUDIT_ROWS=(
  p51-driver-audit
  p5-i01-generate
  p5-i01-independent-audit
  p5-i01-config-and-locks
  p5-b01-control-build
  p5-b01-serial-debug-build
  p5-b01-mpi-debug-build
  p5-b01-mpi-optimized-build
  p5-b01-symbols-serial-debug
  p5-b01-symbols-mpi-debug
  p5-b01-symbols-mpi-optimized
  p5-b01-source-isolation
  p5-b01-real8-reference
  p5-b01-control-smoke
  p5-b01-linked-smoke
  p5-b01-bomoff-bitwise
  p5-b01-fingerprints
)
readonly -a FINAL_ROWS=("${PREAUDIT_ROWS[@]}" p51-independent-evidence-audit)

for command_name in awk bash cmp find gfortran git grep make mpirun nm \
  nf-config python3 sed sha256sum shellcheck sort stat uname xargs; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing command: ${command_name}"
done
[[ -x /usr/bin/time ]] || fail 'missing /usr/bin/time'
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
printf 'case\tresult\tdetail\n' > "${RUN_ROOT}/summary.tsv"
printf '%s\n' "${PREAUDIT_ROWS[@]}" > "${RUN_ROOT}/expected-preaudit.txt"
printf '%s\n' "${FINAL_ROWS[@]}" > "${RUN_ROOT}/expected-final.txt"
git -C "${REPO_ROOT}" rev-parse HEAD > "${RUN_ROOT}/source-head.txt"
git -C "${REPO_ROOT}" status --porcelain=v1 > "${RUN_ROOT}/git-status-before.txt"
{
  uname -a
  git --version
  gfortran --version | sed -n '1p'
  mpirun --version | sed -n '1p'
  nf-config --version
  python3 --version
  shellcheck --version | sed -n '1,2p'
  printf 'optfile=%s\n' "${OPTFILE}"
  printf 'make_jobs=%s\n' "${MAKE_JOBS}"
  printf 'stack=%s\n' "$(ulimit -s)"
} > "${RUN_ROOT}/environment.txt"

bash -n "${BASH_SOURCE[0]}"
shellcheck "${BASH_SOURCE[0]}"
PYTHONPYCACHEPREFIX="${BUILD_ROOT}/pycache" python3 -m py_compile \
  "${CASE_DIR}/generate_p51_inputs.py" \
  "${CASE_DIR}/audit_p51_inputs.py" \
  "${CASE_DIR}/audit_p51_evidence.py"
record_pass p51-driver-audit 'bash, shellcheck and independent Python auditors compile'

log 'generating deterministic P5-I01 production input bundle'
python3 "${CASE_DIR}/generate_p51_inputs.py" \
  "${RUN_ROOT}/input-bundle" --repo-root "${REPO_ROOT}" \
  > "${RUN_ROOT}/input-generation.log"
grep -q 'P5-I01 INPUT GENERATION PASS' "${RUN_ROOT}/input-generation.log" \
  || fail 'input generation marker missing'
record_pass p5-i01-generate '8x6x2 grid, 97 endpoint records, particles, T/N and configs generated'

python3 "${CASE_DIR}/audit_p51_inputs.py" \
  "${RUN_ROOT}/input-bundle" --repo-root "${REPO_ROOT}" \
  --report "${RUN_ROOT}/input-audit.json" \
  > "${RUN_ROOT}/input-audit.log"
grep -q 'P5-I01 INPUT AUDIT PASS' "${RUN_ROOT}/input-audit.log" \
  || fail 'independent input audit marker missing'
record_pass p5-i01-independent-audit 'independent byte oracle validates dimensions, order, precision and endianness'
record_pass p5-i01-config-and-locks 'all namelists, time metadata and locked B16 hashes validate before model start'

write_fingerprint() {
  local name="$1" build_dir="${BUILD_ROOT}/$1"
  {
    printf 'name=%s\n' "${name}"
    printf 'source_head=%s\n' "$(cat "${RUN_ROOT}/source-head.txt")"
    sha256sum \
      "${build_dir}/mitgcmuv" \
      "${build_dir}/genmake.log" \
      "${build_dir}/depend.log" \
      "${build_dir}/build.log" \
      "${build_dir}/Makefile" \
      "${build_dir}/PACKAGES_CONFIG.h" \
      "${build_dir}/symbols.txt" \
      "${build_dir}-mods/SIZE.h" \
      "${build_dir}-mods/packages.conf" \
      "${OPTFILE}"
  } > "${build_dir}/fingerprint.txt"
}

build_case() {
  local name="$1" packages_file="$2" size_file="$3" mpi_enabled="$4" build_mode="$5"
  local build_dir="${BUILD_ROOT}/${name}"
  local mods_dir="${BUILD_ROOT}/${name}-mods"
  local -a args
  log "building ${name}"
  mkdir -p "${build_dir}" "${mods_dir}"
  cp -a "${EXP2_CODE}/." "${mods_dir}/"
  cp "${CASE_DIR}/code/${size_file}" "${mods_dir}/SIZE.h"
  cp "${CASE_DIR}/code/${packages_file}" "${mods_dir}/packages.conf"
  if find "${mods_dir}" -maxdepth 1 -type f -iname 'bom*.F' -print -quit | grep -q .; then
    fail "production source override found in ${name} mods"
  fi
  args=("${REPO_ROOT}/tools/genmake2" "-rootdir=${REPO_ROOT}" \
    "-mods=${mods_dir}" "-of=${OPTFILE}")
  [[ "${mpi_enabled}" == no ]] || args+=( -mpi )
  [[ "${build_mode}" == optimized ]] || args+=( -ieee -devel )
  printf '%q ' "${args[@]}" > "${build_dir}/command.txt"
  printf '\n' >> "${build_dir}/command.txt"
  (
    cd "${build_dir}"
    "${args[@]}" > genmake.log 2>&1
    /usr/bin/time -v -o depend.time make depend > depend.log 2>&1
    /usr/bin/time -v -o build.time make -j "${MAKE_JOBS}" > build.log 2>&1
  )
  [[ -x "${build_dir}/mitgcmuv" ]] || fail "missing executable: ${name}"
  nm -g "${build_dir}/mitgcmuv" > "${build_dir}/symbols.txt"
  if grep -Eq '(^|[[:space:]])-DLET_RS_BE_REAL4([[:space:]]|$)' "${build_dir}/Makefile"; then
    fail "${name} unexpectedly makes _RS Real*4"
  fi
  write_fingerprint "${name}"
}

check_production_symbols() {
  local name="$1" symbols="${BUILD_ROOT}/$1/symbols.txt" symbol count
  local -a required=(
    bom_init_fixed_ bom_init_varia_ bom_check_ bom_main_
    bom_build_endpoints_ bom_build_fields_
    bom_rhs_julia_ bom_rhs_paper2024_ bom_rk4_
    bom_particle_exchange_ bom_write_trajectory_
    bom_write_pickup_ bom_read_pickup_
    bom_event_flush_impl_ bom_event_budget_check_
  )
  for symbol in "${required[@]}"; do
    count="$(grep -Ec "[[:space:]]${symbol}$" "${symbols}")"
    [[ "${count}" -eq 1 ]] || fail "${name} symbol ${symbol} count=${count}"
  done
  if grep -Eqi '[[:space:]]bom_verify[^[:space:]]*_$' "${symbols}"; then
    fail "verification-only BOM symbol linked into ${name}"
  fi
  for macro in ALLOW_GENERIC_ADVDIFF ALLOW_MOM_COMMON ALLOW_MOM_FLUXFORM \
    ALLOW_MOM_VECINV ALLOW_CD_CODE ALLOW_OFFLINE ALLOW_EXF \
    ALLOW_DIAGNOSTICS ALLOW_MNC ALLOW_BOM; do
    grep -Eq "^#define[[:space:]]+${macro}([[:space:]]|$)" \
      "${BUILD_ROOT}/${name}/PACKAGES_CONFIG.h" \
      || fail "${name} lacks ${macro}"
  done
  for object in gad_advection.o mom_fluxform.o mom_vecinv.o \
    cd_code_scheme.o offline_fields_load.o exf_wind.o \
    diagnostics_fill.o mnc_init.o bom_main.o; do
    [[ -f "${BUILD_ROOT}/${name}/${object}" ]] \
      || fail "${name} lacks package object ${object}"
  done
}

build_case control-serial-debug packages.no-bom.conf SIZE.h.serial no debug
record_pass p5-b01-control-build 'serial debug/IEEE control built with identical packages except BOM'
build_case serial-debug packages.conf SIZE.h.serial no debug
record_pass p5-b01-serial-debug-build 'GNU serial debug/IEEE production executable built'
build_case mpi-debug packages.conf SIZE.h.mpi4 yes debug
record_pass p5-b01-mpi-debug-build 'GNU OpenMPI debug/IEEE production executable built'
build_case mpi-optimized packages.conf SIZE.h.mpi4 yes optimized
record_pass p5-b01-mpi-optimized-build 'GNU OpenMPI optimized production executable built'

for name in serial-debug mpi-debug mpi-optimized; do
  check_production_symbols "${name}"
  record_pass "p5-b01-symbols-${name}" 'all production setup/RHS/RK/migration/I/O symbols linked exactly once'
done
if grep -Eq '[[:space:]]bom_main_$' "${BUILD_ROOT}/control-serial-debug/symbols.txt"; then
  fail 'BOM symbol leaked into no-BOM control executable'
fi
record_pass p5-b01-source-isolation 'no production override, bom_verify object, duplicate symbol or BOM control leak'
record_pass p5-b01-real8-reference 'reference builds retain REAL4_IS_SLOW and no LET_RS_BE_REAL4'

prepare_smoke() {
  local name="$1" build="$2" run_dir="${RUN_ROOT}/$1"
  mkdir "${run_dir}"
  cp "${RUN_ROOT}/input-bundle/data.smoke" "${run_dir}/data"
  cp "${RUN_ROOT}/input-bundle/data.pkg.bomoff" "${run_dir}/data.pkg"
  cp "${RUN_ROOT}/input-bundle/eedata" "${run_dir}/eedata"
  cp "${RUN_ROOT}/input-bundle/bathy.bin" "${run_dir}/bathy.bin"
  cp "${RUN_ROOT}/input-bundle/uvel_init.bin" "${run_dir}/uvel_init.bin"
  cp "${RUN_ROOT}/input-bundle/vvel_init.bin" "${run_dir}/vvel_init.bin"
  ln -s "${BUILD_ROOT}/${build}/mitgcmuv" "${run_dir}/mitgcmuv"
}

run_smoke() {
  local name="$1" run_dir="${RUN_ROOT}/$1"
  log "running ${name}"
  (
    cd "${run_dir}"
    /usr/bin/time -v -o resource.txt ./mitgcmuv > stdout.log 2> stderr.log
  )
  cat "${run_dir}/stdout.log" "${run_dir}/stderr.log" > "${run_dir}/combined.log"
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${run_dir}/combined.log" \
    || fail "normal end missing: ${name}"
  if grep -Eq 'ABNORMAL END|S/R ALL_PROC_DIE|fatal error|Fortran runtime error' \
      "${run_dir}/combined.log"; then
    fail "fatal marker in smoke: ${name}"
  fi
  find "${run_dir}" -maxdepth 1 -type f \
    -name 'pickup.0000000002*.data' -print -quit | grep -q . \
    || fail "main pickup data family missing: ${name}"
  find "${run_dir}" -maxdepth 1 -type f \
    -name 'pickup.0000000002*.meta' -print -quit | grep -q . \
    || fail "main pickup metadata family missing: ${name}"
  if find "${run_dir}" -maxdepth 1 -name 'pickup_bom*' -print -quit | grep -q .; then
    fail "BOM pickup emitted while useBOM is false: ${name}"
  fi
}

prepare_smoke smoke-control control-serial-debug
run_smoke smoke-control
record_pass p5-b01-control-smoke 'BOM-absent control executes two ocean steps and writes main pickup'
prepare_smoke smoke-linked serial-debug
run_smoke smoke-linked
record_pass p5-b01-linked-smoke 'BOM-linked/useBOM false executes the identical two-step ocean smoke'

control_names="$(cd "${RUN_ROOT}/smoke-control" && find . -maxdepth 1 -type f -name 'pickup.0000000002*' -printf '%f\n' | sort)"
linked_names="$(cd "${RUN_ROOT}/smoke-linked" && find . -maxdepth 1 -type f -name 'pickup.0000000002*' -printf '%f\n' | sort)"
[[ -n "${control_names}" && "${control_names}" == "${linked_names}" ]] \
  || fail 'BOM-off pickup inventories differ'
while IFS= read -r pickup_name; do
  cmp -s "${RUN_ROOT}/smoke-control/${pickup_name}" \
         "${RUN_ROOT}/smoke-linked/${pickup_name}" \
    || fail "BOM-off pickup differs: ${pickup_name}"
done <<< "${control_names}"
{
  printf 'result=PASS\n'
  printf 'files=%s\n' "$(printf '%s\n' "${control_names}" | wc -l)"
  while IFS= read -r pickup_name; do
    sha256sum "${RUN_ROOT}/smoke-control/${pickup_name}"
  done <<< "${control_names}"
} > "${RUN_ROOT}/smoke-comparison.txt"
record_pass p5-b01-bomoff-bitwise 'main ocean pickup family is byte-identical with BOM absent versus linked/off'

for name in control-serial-debug serial-debug mpi-debug mpi-optimized; do
  [[ -s "${BUILD_ROOT}/${name}/fingerprint.txt" ]] || fail "fingerprint missing: ${name}"
done
record_pass p5-b01-fingerprints 'source/build/options/executable/log/symbol SHA-256 fingerprints recorded'

git -C "${REPO_ROOT}" status --porcelain=v1 > "${RUN_ROOT}/git-status-after.txt"
if [[ "${REQUIRE_CLEAN}" == yes && -s "${RUN_ROOT}/git-status-after.txt" ]]; then
  fail 'source worktree changed during exact-head gate'
fi

(
  cd "${BUILD_ROOT}"
  find . -type f \( -name 'mitgcmuv' -o -name '*.log' -o -name '*.time' \
    -o -name 'symbols.txt' -o -name 'fingerprint.txt' -o -name 'command.txt' \
    -o -name 'PACKAGES_CONFIG.h' -o -name 'Makefile' -o -name 'SIZE.h' \
    -o -name 'packages.conf' \) -print0 \
    | sort -z | xargs -0 sha256sum > SHA256SUMS
)
(
  cd "${RUN_ROOT}"
  find . -type f ! -path './input-bundle/*' ! -name 'SHA256SUMS' \
    ! -name 'summary.tsv' -print0 \
    | sort -z | xargs -0 sha256sum > SHA256SUMS
)

cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary-preaudit.tsv"
cp "${RUN_ROOT}/expected-preaudit.txt" "${ARTIFACT_ROOT}/expected-preaudit.txt"
cp "${RUN_ROOT}/expected-final.txt" "${ARTIFACT_ROOT}/expected-final.txt"
cp "${RUN_ROOT}/source-head.txt" "${ARTIFACT_ROOT}/source-head.txt"
cp "${RUN_ROOT}/git-status-before.txt" "${ARTIFACT_ROOT}/git-status-before.txt"
cp "${RUN_ROOT}/git-status-after.txt" "${ARTIFACT_ROOT}/git-status-after.txt"
cp "${RUN_ROOT}/environment.txt" "${ARTIFACT_ROOT}/environment.txt"
cp "${RUN_ROOT}/input-audit.json" "${ARTIFACT_ROOT}/input-audit.json"
cp "${RUN_ROOT}/input-audit.log" "${ARTIFACT_ROOT}/input-audit.log"
cp "${RUN_ROOT}/input-generation.log" "${ARTIFACT_ROOT}/input-generation.log"
cp "${RUN_ROOT}/smoke-comparison.txt" "${ARTIFACT_ROOT}/smoke-comparison.txt"
cp "${BUILD_ROOT}/SHA256SUMS" "${ARTIFACT_ROOT}/build-SHA256SUMS"
cp "${RUN_ROOT}/SHA256SUMS" "${ARTIFACT_ROOT}/run-SHA256SUMS"
for name in control-serial-debug serial-debug mpi-debug mpi-optimized; do
  cp "${BUILD_ROOT}/${name}/fingerprint.txt" \
    "${ARTIFACT_ROOT}/${name}-fingerprint.txt"
done

python3 "${CASE_DIR}/audit_p51_evidence.py" \
  "${ARTIFACT_ROOT}" --build-root "${BUILD_ROOT}" --run-root "${RUN_ROOT}" \
  --report "${ARTIFACT_ROOT}/independent-audit.json" \
  > "${ARTIFACT_ROOT}/independent-audit.log"
grep -q 'P5.1 INDEPENDENT EVIDENCE AUDIT PASS' \
  "${ARTIFACT_ROOT}/independent-audit.log" \
  || fail 'independent evidence audit marker missing'
record_pass p51-independent-evidence-audit 'independent inventory/hash/build/input/smoke audit passes'

actual_rows="$(awk 'NR>1 {print $1}' "${RUN_ROOT}/summary.tsv")"
expected_rows="$(printf '%s\n' "${FINAL_ROWS[@]}")"
[[ "${actual_rows}" == "${expected_rows}" ]] || fail 'final row order/inventory differs'
cp "${RUN_ROOT}/summary.tsv" "${ARTIFACT_ROOT}/summary.tsv"
(
  cd "${ARTIFACT_ROOT}"
  find . -maxdepth 1 -type f ! -name 'manifest.sha256' -print0 \
    | sort -z | xargs -0 sha256sum > manifest.sha256
  sha256sum -c manifest.sha256 >/dev/null
)

log "P5.1 GATE PASS (${#FINAL_ROWS[@]}/${#FINAL_ROWS[@]})"
log "build root: ${BUILD_ROOT}"
log "run root: ${RUN_ROOT}"
log "artifact root: ${ARTIFACT_ROOT}"
cat "${RUN_ROOT}/summary.tsv"
