#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 RUN_ROOT MPI4_EXE" >&2
  exit 2
fi

readonly RUN_ROOT="$1"
readonly MPI4_EXE="$2"

fail() { printf 'P5-L01 RUN FAIL: %s\n' "$*" >&2; exit 1; }

[[ -d "${RUN_ROOT}" ]] || fail "missing run root ${RUN_ROOT}"
[[ -x "${MPI4_EXE}" ]] || fail "missing executable ${MPI4_EXE}"

run_case() {
  local name="$1" directory="${RUN_ROOT}/$1"
  [[ -d "${directory}" ]] || fail "missing case ${name}"
  [[ ! -e "${directory}/combined.log" ]] || fail "non-fresh case ${name}"
  ln -s "${MPI4_EXE}" "${directory}/mitgcmuv"
  set +e
  (cd "${directory}" && /usr/bin/time -v -o resource.txt \
    mpirun --oversubscribe -np 4 ./mitgcmuv > launch.log 2>&1)
  local status=$?
  set -e
  : > "${directory}/combined.log"
  cat "${directory}"/STDOUT.[0-9][0-9][0-9][0-9] >> "${directory}/combined.log"
  if compgen -G "${directory}/STDERR.*" >/dev/null; then
    cat "${directory}"/STDERR.* >> "${directory}/combined.log"
  fi
  [[ "${status}" -eq 0 ]] || fail "launcher status ${status} in ${name}"
  grep -q 'PROGRAM MAIN: Execution ended Normally' "${directory}/combined.log" \
    || fail "normal end missing ${name}"
  if grep -Eqi 'ABNORMAL END|ALL_PROC_DIE|Fortran runtime error|particle failure|event failure|\bNaN\b|Infinity' \
      "${directory}/combined.log"; then
    fail "fatal marker in ${name}"
  fi
}

copy_day15_boundary() {
  local source="${RUN_ROOT}/part1" destination="${RUN_ROOT}/part2"
  find "${source}" -maxdepth 1 -type f \
    \( -name 'pickup.0000000360*' -o -name 'pickup_bom.0000000360*' \
       -o -name 'p54_events*' \) -exec cp -t "${destination}" {} +
  find "${destination}" -maxdepth 1 -type f -name 'pickup_bom.0000000360*' \
    -print -quit | grep -q . || fail 'day-15 BOM pickup missing'
}

run_case continuous
run_case part1
copy_day15_boundary
run_case part2

echo 'P5-L01 RUN PASS continuous_steps=720 split_steps=360+360 ranks=4'
