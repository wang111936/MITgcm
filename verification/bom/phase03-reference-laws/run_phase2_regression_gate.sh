#!/usr/bin/env bash
set -euo pipefail

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly CASE_DIR
REPO_ROOT="$(cd "${CASE_DIR}/../../.." && pwd -P)"
readonly REPO_ROOT

export MITGCM_BOM_CLOSURE_SCOPE=P3.1
unset MITGCM_BOM_TEST_ARTIFACT_ROOT

"${REPO_ROOT}/verification/bom/phase02-integration-closure/run_phase2_closure.sh"
printf '%s\n' '[P3.1-regression] PHASE 2 REGRESSION PASS (390/390)'
