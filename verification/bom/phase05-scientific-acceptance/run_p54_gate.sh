#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="${MITGCM_BOM_REPO_ROOT:-/home/wyl/projects/mitgcm-bom}"
readonly CASE_DIR="${REPO_ROOT}/verification/bom/phase05-scientific-acceptance"
readonly TEST_ID="${MITGCM_BOM_TEST_ID:-p54-exact-$(git -C "${REPO_ROOT}" rev-parse --short=9 HEAD)-attempt01}"
readonly BUILD_ROOT="/home/wyl/build/mitgcm-bom/phase05-scientific-acceptance/${TEST_ID}"
readonly RUN_ROOT="/home/wyl/runs/mitgcm-bom/phase05-scientific-acceptance/${TEST_ID}"
readonly EVIDENCE_ROOT="/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/scientific-acceptance/${TEST_ID}"
readonly MAKE_JOBS="${MITGCM_BOM_MAKE_JOBS:-8}"
readonly OPTFILE="${REPO_ROOT}/tools/build_options/linux_amd64_gfortran"

fail() { printf 'P5.4 GATE FAIL: %s\n' "$*" >&2; exit 1; }
record() { printf '%s\tPASS\t%s\n' "$1" "$2" >> "${EVIDENCE_ROOT}/summary.tsv"; }

for path in "${BUILD_ROOT}" "${RUN_ROOT}" "${EVIDENCE_ROOT}"; do
  [[ ! -e "${path}" ]] || fail "refusing existing root ${path}"
done

cd "${REPO_ROOT}"
[[ -z "$(git status --porcelain)" ]] || fail 'source tree is not clean'
git merge-base --is-ancestor MITGCM-BOM-v0.5 HEAD \
  || fail 'HEAD does not descend from MITGCM-BOM-v0.5'

mkdir -p "${BUILD_ROOT}" "${RUN_ROOT}" "${EVIDENCE_ROOT}"
git rev-parse HEAD > "${EVIDENCE_ROOT}/source-head.txt"
git status --porcelain > "${EVIDENCE_ROOT}/git-status.txt"
git describe --tags --always --dirty > "${EVIDENCE_ROOT}/source-describe.txt"
git merge-base MITGCM-BOM-v0.5 HEAD > "${EVIDENCE_ROOT}/v0.5-merge-base.txt"
printf 'test_id\t%s\nsource_head\t%s\ntag_baseline\tMITGCM-BOM-v0.5\n' \
  "${TEST_ID}" "$(git rev-parse HEAD)" > "${EVIDENCE_ROOT}/identity.tsv"
printf 'gate\tresult\tdetail\n' > "${EVIDENCE_ROOT}/summary.tsv"
record p5.4-source-admission 'clean exact head descends from MITGCM-BOM-v0.5'

{
  uname -a
  lsb_release -a 2>/dev/null || true
  lscpu
  gfortran --version
  mpirun --version
  python3 --version
  git --version
  sha256sum --version
} > "${EVIDENCE_ROOT}/environment.txt" 2>&1

prepare_common_mods() {
  local mods="$1" size_file="$2"
  mkdir "${mods}"
  cp "${REPO_ROOT}/verification/exp2/code/CPP_OPTIONS.h" "${mods}/"
  cp "${REPO_ROOT}/verification/exp2/code/CD_CODE_OPTIONS.h" "${mods}/"
  cp "${CASE_DIR}/code/CPP_EEOPTIONS.h" "${mods}/"
  cp "${CASE_DIR}/code/packages.conf" "${mods}/packages.conf"
  cp "${size_file}" "${mods}/SIZE.h"
}

prepare_gyre_mods() {
  local mods="$1" size_file="$2"
  mkdir "${mods}"
  cp "${REPO_ROOT}/verification/tutorial_baroclinic_gyre/code/DIAGNOSTICS_SIZE.h" "${mods}/"
  cp "${CASE_DIR}/code/packages.gyre.conf" "${mods}/packages.conf"
  cp "${size_file}" "${mods}/SIZE.h"
}

build_model() {
  local name="$1" family="$2" size_file="$3" mpi="$4"
  local build="${BUILD_ROOT}/${name}" mods="${BUILD_ROOT}/${name}-mods"
  mkdir "${build}"
  if [[ "${family}" == common ]]; then
    prepare_common_mods "${mods}" "${size_file}"
  else
    prepare_gyre_mods "${mods}" "${size_file}"
  fi
  if find "${mods}" -maxdepth 1 -type f -name 'bom_*.F' -print -quit | grep -q .; then
    fail "production BOM override in ${mods}"
  fi
  local command=("${REPO_ROOT}/tools/genmake2" "-rootdir=${REPO_ROOT}"
                 "-mods=${mods}" "-of=${OPTFILE}" -ieee -devel)
  if [[ "${mpi}" == yes ]]; then command+=(-mpi); fi
  printf '%q ' "${command[@]}" > "${build}/command.txt"
  printf '\n' >> "${build}/command.txt"
  (
    cd "${build}"
    "${command[@]}" > genmake.log 2>&1
    /usr/bin/time -v -o depend.time make depend > depend.log 2>&1
    /usr/bin/time -v -o build.time make -j "${MAKE_JOBS}" > build.log 2>&1
    nm -g mitgcmuv > symbols.txt
  )
  [[ -x "${build}/mitgcmuv" ]] || fail "missing executable ${name}"
  if rg -q -- '-DLET_RS_BE_REAL4' "${build}/Makefile"; then
    fail "${name} weakens scientific _RS precision"
  fi
  for symbol in bom_init_fixed_ bom_init_varia_ bom_main_ bom_build_endpoints_ \
                bom_rhs_paper2024_ bom_event_transaction_ bom_write_pickup_; do
    rg -q "[[:space:]]${symbol}$" "${build}/symbols.txt" \
      || fail "${name} missing symbol ${symbol}"
  done
}

build_model common-mpi1 common "${CASE_DIR}/code/SIZE.h.serial" yes
build_model common-mpi2 common "${CASE_DIR}/code/SIZE.h.mpi2" yes
build_model common-mpi4 common "${CASE_DIR}/code/SIZE.h.mpi4" yes
build_model gyre-serial gyre "${CASE_DIR}/code/SIZE.h.gyre.serial" no
build_model gyre-mpi4 gyre "${CASE_DIR}/code/SIZE.h.gyre.mpi4" yes
record p5.4-production-builds '5 GNU debug/IEEE production executables; common MPI1/2/4 and gyre serial/MPI4'

cd "${CASE_DIR}"
python3 generate_p54_inputs.py --case all "${RUN_ROOT}/f01" \
  > "${RUN_ROOT}/f01-input.log"
python3 generate_p54_inputs.py --case all "${RUN_ROOT}/fbase" \
  > "${RUN_ROOT}/fbase-input.log"
python3 generate_p53_inputs.py --repo-root "${REPO_ROOT}" --case p01 --dt-s 900 \
  "${RUN_ROOT}/casej-base" > "${RUN_ROOT}/casej-input.log"
python3 generate_p54_gyre.py \
  "${REPO_ROOT}/verification/tutorial_baroclinic_gyre/input" "${RUN_ROOT}/o01" \
  > "${RUN_ROOT}/o01-input.log"
python3 prepare_p54_restart.py --case-j "${RUN_ROOT}/casej-base" \
  --combined "${RUN_ROOT}/fbase/combined" "${RUN_ROOT}/r01" \
  > "${RUN_ROOT}/r01-input.log"
python3 generate_p54_longrun.py --repo-root "${REPO_ROOT}" "${RUN_ROOT}/l01" \
  > "${RUN_ROOT}/l01-input.log"

./run_p54_f01.sh "${RUN_ROOT}/f01" "${BUILD_ROOT}/common-mpi4/mitgcmuv" \
  > "${RUN_ROOT}/f01-run.log"
python3 audit_p54_f01.py "${RUN_ROOT}/f01" --report "${RUN_ROOT}/p5-f01-audit.json" \
  > "${RUN_ROOT}/f01-audit.log"
record p5-f01 '6 released-feature production cases; independent spring/event/schema-4 audit'

./run_p54_o01.sh "${RUN_ROOT}/o01" "${BUILD_ROOT}/gyre-serial/mitgcmuv" \
  "${BUILD_ROOT}/gyre-mpi4/mitgcmuv" > "${RUN_ROOT}/o01-run.log"
python3 audit_p54_o01.py "${RUN_ROOT}/o01" --report "${RUN_ROOT}/p5-o01-audit.json" \
  --normalized "${RUN_ROOT}/p5-o01-normalized.csv" > "${RUN_ROOT}/o01-audit.log"
record p5-o01 'stock gyre ocean invariance, serial/MPI4 trajectories and endpoint replay'

./run_p54_restart_matrix.sh "${RUN_ROOT}/r01" \
  "${BUILD_ROOT}/common-mpi1/mitgcmuv" "${BUILD_ROOT}/common-mpi2/mitgcmuv" \
  "${BUILD_ROOT}/common-mpi4/mitgcmuv" > "${RUN_ROOT}/r01-run.log"
python3 audit_p54_r01.py "${RUN_ROOT}/r01" --report "${RUN_ROOT}/p5-r01-audit.json" \
  > "${RUN_ROOT}/r01-audit.log"
record p5-r01 '18 positive restart/decomposition runs and 2 prepublication rejections'

./run_p54_longrun.sh "${RUN_ROOT}/l01" "${BUILD_ROOT}/common-mpi4/mitgcmuv" \
  > "${RUN_ROOT}/l01-run.log"
python3 audit_p54_l01.py "${RUN_ROOT}/l01" --report "${RUN_ROOT}/p5-l01-audit.json" \
  > "${RUN_ROOT}/l01-audit.log"
record p5-l01 '30 days, hourly output, daily pickups, day-15 exact restart and no leak'

cp "${RUN_ROOT}"/p5-*-audit.json "${EVIDENCE_ROOT}/"
cp "${RUN_ROOT}/p5-o01-normalized.csv" "${EVIDENCE_ROOT}/"
sha256sum "${BUILD_ROOT}"/*/mitgcmuv > "${EVIDENCE_ROOT}/executables.sha256"
(
  cd "${REPO_ROOT}"
  git ls-files -z pkg/bom verification/bom/phase05-scientific-acceptance \
    | sort -z | xargs -0 sha256sum > "${EVIDENCE_ROOT}/source-files.sha256"
)
find "${BUILD_ROOT}" -type f -print0 | sort -z | xargs -0 sha256sum \
  > "${EVIDENCE_ROOT}/build-files.sha256"
find "${RUN_ROOT}" -type f -print0 | sort -z | xargs -0 sha256sum \
  > "${EVIDENCE_ROOT}/run-files.sha256"
record p5.4-evidence-inventory 'source, executable, build, input, output and comparison SHA-256 inventories'

make_manifest() {
  (
    cd "${EVIDENCE_ROOT}"
    find . -type f ! -name manifest.sha256 ! -name independent-audit.json -print0 \
      | sort -z | xargs -0 sha256sum > manifest.sha256
  )
}

make_manifest
python3 "${CASE_DIR}/audit_p54_evidence.py" "${EVIDENCE_ROOT}" \
  --build-root "${BUILD_ROOT}" --run-root "${RUN_ROOT}" \
  --report "${EVIDENCE_ROOT}/independent-audit.json"
record p5.4-independent-audit 'second reader validated exact head, reports, inventories and self-manifest'
make_manifest
python3 "${CASE_DIR}/audit_p54_evidence.py" "${EVIDENCE_ROOT}" \
  --build-root "${BUILD_ROOT}" --run-root "${RUN_ROOT}" \
  --report "${EVIDENCE_ROOT}/independent-audit.json"

[[ -z "$(git -C "${REPO_ROOT}" status --porcelain)" ]] || fail 'gate changed source tree'
echo "P5.4 GATE PASS 8/8 test_id=${TEST_ID}"
