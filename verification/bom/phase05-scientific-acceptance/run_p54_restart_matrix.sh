#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 4 ]]; then
  echo "usage: $0 RUN_ROOT MPI1_EXE MPI2_EXE MPI4_EXE" >&2
  exit 2
fi

readonly RUN_ROOT="$1"
readonly MPI1_EXE="$2"
readonly MPI2_EXE="$3"
readonly MPI4_EXE="$4"

fail() { printf 'P5-R01 MATRIX FAIL: %s\n' "$*" >&2; exit 1; }

for path in "${RUN_ROOT}" "${MPI1_EXE}" "${MPI2_EXE}" "${MPI4_EXE}"; do
  [[ -e "${path}" ]] || fail "missing path ${path}"
done

run_positive() {
  local name="$1" executable="$2" ranks="$3" directory="${RUN_ROOT}/$1"
  [[ -d "${directory}" ]] || fail "missing run directory ${name}"
  [[ ! -e "${directory}/combined.log" ]] || fail "non-fresh run directory ${name}"
  ln -s "${executable}" "${directory}/mitgcmuv"
  # Keep one compiler/communication backend across the decomposition matrix:
  # the serial lane is an MPI-enabled executable run with exactly one rank.
  (cd "${directory}" && /usr/bin/time -v -o resource.txt \
    mpirun --oversubscribe -np "${ranks}" ./mitgcmuv > launch.log 2>&1)
  : > "${directory}/combined.log"
  cat "${directory}"/STDOUT.[0-9][0-9][0-9][0-9] >> "${directory}/combined.log"
  if compgen -G "${directory}/STDERR.*" >/dev/null; then
    cat "${directory}"/STDERR.* >> "${directory}/combined.log"
  fi
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${directory}/combined.log" \
    || fail "normal end missing ${name}"
  if grep -Eqi 'ABNORMAL END|ALL_PROC_DIE|Fortran runtime error|\bNaN\b|Infinity' \
      "${directory}/combined.log"; then
    fail "fatal marker in ${name}"
  fi
}

copy_boundary() {
  local source="$1" destination="$2" suffix="$3"
  find "${source}" -maxdepth 1 -type f \
    \( -name "pickup.${suffix}*" -o -name "pickup_bom.${suffix}*" \
       -o -name 'p54_events*' \) -exec cp -t "${destination}" {} +
  find "${destination}" -maxdepth 1 -type f -name "pickup_bom.${suffix}*" \
    -print -quit | grep -q . || fail "BOM boundary pickup missing ${source}"
}

run_layout() {
  local layout="$1" executable="$2" ranks="$3"
  run_positive "casej-${layout}-continuous" "${executable}" "${ranks}"
  run_positive "casej-${layout}-part1" "${executable}" "${ranks}"
  copy_boundary "${RUN_ROOT}/casej-${layout}-part1" \
    "${RUN_ROOT}/casej-${layout}-part2" 0000000048
  run_positive "casej-${layout}-part2" "${executable}" "${ranks}"

  run_positive "combined-${layout}-continuous" "${executable}" "${ranks}"
  run_positive "combined-${layout}-part1" "${executable}" "${ranks}"
  copy_boundary "${RUN_ROOT}/combined-${layout}-part1" \
    "${RUN_ROOT}/combined-${layout}-part2" 0000000001
  run_positive "combined-${layout}-part2" "${executable}" "${ranks}"
}

cp -a "${RUN_ROOT}/casej-mpi2-part2" "${RUN_ROOT}/negative-casej-serial-to-mpi2"
cp -a "${RUN_ROOT}/combined-mpi2-part2" "${RUN_ROOT}/negative-combined-serial-to-mpi2"

run_layout serial "${MPI1_EXE}" 1
run_layout mpi2 "${MPI2_EXE}" 2
run_layout mpi4 "${MPI4_EXE}" 4

run_negative() {
  local case_name="$1" suffix="$2"
  local source="${RUN_ROOT}/${case_name}-serial-part1"
  local directory="${RUN_ROOT}/negative-${case_name}-serial-to-mpi2"
  copy_boundary "${source}" "${directory}" "${suffix}"
  ln -s "${MPI2_EXE}" "${directory}/mitgcmuv"
  set +e
  (cd "${directory}" && mpirun --oversubscribe -np 2 ./mitgcmuv > launch.log 2>&1)
  local status=$?
  set -e
  cat "${directory}"/launch.log "${directory}"/STDOUT.* "${directory}"/STDERR.* \
    > "${directory}/combined.log"
  if grep -q 'PROGRAM MAIN: Execution ended Normally' "${directory}/combined.log"; then
    fail "changed decomposition accepted ${case_name} status=${status}"
  fi
  grep -Eqi 'decomposition|schema-2|schema-4|signature' "${directory}/combined.log" \
    || fail "changed-decomposition reason missing ${case_name}"
  grep -Eqi 'ABNORMAL END|ALL_PROC_DIE' "${directory}/combined.log" \
    || fail "changed-decomposition fatal marker missing ${case_name}"
  if grep -q 'BOM_READ_PICKUP: complete' "${directory}/combined.log"; then
    fail "changed decomposition published owner state ${case_name}"
  fi
}

run_negative casej 0000000048
run_negative combined 0000000001

echo 'P5-R01 MATRIX RUN PASS positive=18 changed_decomposition=2'
