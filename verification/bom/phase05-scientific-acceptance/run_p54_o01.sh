#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -eq 3 ]] || { echo "usage: $0 RUN_ROOT SERIAL_EXE MPI4_EXE" >&2; exit 2; }
readonly RUN_ROOT="$1"
readonly SERIAL_EXE="$2"
readonly MPI4_EXE="$3"

fail() { printf 'P5-O01 RUN FAIL: %s\n' "$*" >&2; exit 1; }
for path in "${RUN_ROOT}" "${SERIAL_EXE}" "${MPI4_EXE}"; do
  [[ -e "${path}" ]] || fail "missing ${path}"
done

run_case() {
  local name="$1" executable="$2" ranks="$3" directory="${RUN_ROOT}/$1"
  [[ -d "${directory}" && ! -e "${directory}/combined.log" ]] \
    || fail "non-fresh case ${name}"
  ln -s "${executable}" "${directory}/mitgcmuv"
  set +e
  if [[ "${ranks}" -eq 1 ]]; then
    (cd "${directory}" && /usr/bin/time -v -o resource.txt ./mitgcmuv > run.log 2>&1)
  else
    (cd "${directory}" && /usr/bin/time -v -o resource.txt \
      mpirun --oversubscribe -np "${ranks}" ./mitgcmuv > launch.log 2>&1)
  fi
  local status=$?
  set -e
  : > "${directory}/combined.log"
  if compgen -G "${directory}/STDOUT.*" >/dev/null; then
    cat "${directory}"/STDOUT.* >> "${directory}/combined.log"
  else
    cat "${directory}/run.log" >> "${directory}/combined.log"
  fi
  if compgen -G "${directory}/STDERR.*" >/dev/null; then
    cat "${directory}"/STDERR.* >> "${directory}/combined.log"
  fi
  [[ "${status}" -eq 0 ]] || fail "launcher status ${status} in ${name}"
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${directory}/combined.log" \
    || fail "normal end missing ${name}"
  if grep -Eqi 'ABNORMAL END|ALL_PROC_DIE|Fortran runtime error|particle failure' \
      "${directory}/combined.log"; then
    fail "fatal marker ${name}"
  fi
}

run_case mpi4-off "${MPI4_EXE}" 4
run_case mpi4-on "${MPI4_EXE}" 4
run_case serial-on "${SERIAL_EXE}" 1

echo 'P5-O01 RUN PASS cases=3 layouts=serial+mpi4'
