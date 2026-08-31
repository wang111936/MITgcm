#!/usr/bin/env bash
set -euo pipefail

[[ "$#" -eq 2 ]] || { echo "usage: $0 RUN_ROOT MPI4_EXE" >&2; exit 2; }
readonly RUN_ROOT="$1"
readonly MPI4_EXE="$2"

fail() { printf 'P5-F01 RUN FAIL: %s\n' "$*" >&2; exit 1; }
[[ -d "${RUN_ROOT}" && -x "${MPI4_EXE}" ]] || fail 'missing root or executable'

for case_name in spring birth cancel death coast combined; do
  directory="${RUN_ROOT}/${case_name}"
  [[ -d "${directory}" && ! -e "${directory}/combined.log" ]] \
    || fail "non-fresh case ${case_name}"
  ln -s "${MPI4_EXE}" "${directory}/mitgcmuv"
  set +e
  (cd "${directory}" && /usr/bin/time -v -o resource.txt \
    mpirun --oversubscribe -np 4 ./mitgcmuv > launch.log 2>&1)
  status=$?
  set -e
  : > "${directory}/combined.log"
  cat "${directory}"/STDOUT.[0-9][0-9][0-9][0-9] >> "${directory}/combined.log"
  if compgen -G "${directory}/STDERR.*" >/dev/null; then
    cat "${directory}"/STDERR.* >> "${directory}/combined.log"
  fi
  [[ "${status}" -eq 0 ]] || fail "launcher status ${status} in ${case_name}"
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${directory}/combined.log" \
    || fail "normal end missing ${case_name}"
  if grep -Eqi 'ABNORMAL END|ALL_PROC_DIE|Fortran runtime error|particle failure|event failure' \
      "${directory}/combined.log"; then
    fail "fatal marker ${case_name}"
  fi
done

echo 'P5-F01 RUN PASS cases=6 ranks=4'
