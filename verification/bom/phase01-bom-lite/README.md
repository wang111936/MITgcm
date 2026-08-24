# MITGCM-BOM Phase 1 verification index

This directory is the source-controlled Phase 1 BOM-Lite verification index. It contains the executable P1.1 state gate, accepted P1.2 evidence, the frozen P1.3 single-tile contract, and the P1.3 setup, RHS, RK2, RK4, release, caller-commit, and state-budget records. Build trees, runtime output, and generated binary evidence remain outside Git.

## Executable P1.1 gate scope

- compact per-tile owner SoA and deterministic reset;
- schema 1 MDS initial-particle files;
- exact positive 64-bit IDs encoded as unsigned high/low 32-bit words;
- bounded initial owner selection on regular Cartesian or unrotated spherical-polar grids;
- input finite-value, uniqueness, state, release-time, wet-cell, count, and capacity checks;
- serial, MPI2, MPI4, GNU debug, zero-impact, and negative gates.

BOM-active positive P1.1 runs stop after initialization (`endTime=0`) so this
gate measures schema, owner selection, compact state, and exact IDs without
silently depending on the not-yet-implemented P1.4 owner migration. The
BOM-disabled 1/2/4-rank runs still execute the full ocean baseline and require
all eight checkpoint hashes.

The P1.1 driver does not itself implement environmental fields, interpolation,
particle motion, owner exchange, trajectory output, or pickup. P1.2 evidence
is recorded separately. P1.3 setup, frozen fields, Leeway RHS, RK2/RK4,
release-time integration, authoritative transactional commits, and the compact
global state budget are implemented and tested. Owner exchange remains P1.4;
output, pickup, and FLT coexistence remain P1.5.

## Run

```bash
cd /home/wyl/projects/mitgcm-bom
MITGCM_BOM_TEST_ID=<unique-id> \
  verification/bom/phase01-bom-lite/run_state_gate.sh
```

The driver refuses to reuse build or run roots. Defaults are:

```text
/home/wyl/build/mitgcm-bom/phase01-state/<test-id>
/home/wyl/runs/mitgcm-bom/phase01-state/<test-id>
```

`make_initial.py` writes deterministic big-endian float64 MDS records using only the Python standard library. The authoritative local result is documented in `TEST_RESULTS.md`; raw binaries, executables, and logs remain outside Git.

## Audits

- `P1.1_SCOPE_AUDIT.md` records the accepted P1.1 boundary and evidence.
- `P1.2_INTERFACE_FREEZE.md` is the frozen mapping/environment-field contract.
- `P1.2_SCOPE_AUDIT.md` records the accepted P1.2 final review, including the
  closed production diagnostic-caller and finite-geometry findings.
- `P1.2_INTEGRATION_RESULTS.md` records the PR #10 merge commit and all fresh
  post-merge P1.2, P1.1, Phase 0, and nested P0.4 evidence.
- `P1.2_INTEGRATION_AUDIT.md` records the independent review of Draft PR #11
  and its no-finding PASS decision.
- `P1.2_CLOSEOUT.md` records the PR #11 merge commit and the fresh post-merge
  P1.2, P1.1, Phase 0, and nested P0.4 evidence used to close the work package.
- `P1.2_CLOSEOUT_AUDIT.md` records the independent PR #12 review, the corrected
  immutable merge range, and the final no-open-finding PASS decision.
- `P1.3_INTERFACE_FREEZE.md` freezes the step-end field snapshot, EXF 10 m wind,
  SI Leeway RHS, release-time split, RK2/RK4, single-tile safety boundary, and
  P1-N01b/P1-S04b/P1-N06/P1-N08/P1-I01—I06 acceptance contract. It is not
  execution evidence and introduces no production Fortran in the design increment.
- `P1.3_DESIGN_AUDIT.md` records the independent source-backed review of Draft
  PR #13, closure of its five design findings, and the immutable no-open-finding
  PASS result.
- `../phase01-setup/TEST_RESULTS.md` records the implementation commit, P1.3
  setup component evidence, all predecessor regressions, resolved numerical
  findings, and the explicit boundary of the first production increment.
- `../phase01-rhs/TEST_RESULTS.md` records the stateless RHS implementation
  commit, exact-head serial/MPI4/EXF/Julia evidence, predecessor regressions,
  resolved trap-safety findings, and the remaining RK/release boundary.
- `../phase01-rk2/TEST_RESULTS.md` records the stateless RK2 implementation
  commit, exact-head P1-I05/rollback/Julia evidence, predecessor regressions,
  and the remaining RK4/release/production-commit boundary.
- `../phase01-rk4/TEST_RESULTS.md` records the stateless RK4 implementation
  head, exact-head P1-I06/K1--K4/FINAL/Julia evidence, and every predecessor
  regression through the nested formal P0.4 gate.
- `../phase01-lifecycle/TEST_RESULTS.md` records the complete production
  release/caller/state-budget implementation and its 157-row exact-head
  lifecycle plus predecessor matrix.
- `P1.3_SCOPE_AUDIT.md` closes the final P1.3 scope, numerical, transaction,
  exclusion, and evidence audit while retaining the independent Ready review.

## Input schema 1

The header record contains `schema`, field count, particle count, coordinate code, ID encoding, precision bits, and two reserved fields. Each particle record contains `id_hi`, `id_lo`, native `x/y`, release time, status, age, and one reserved field.

Only `BOM_ALIVE` and `BOM_WAITING` are accepted at initialization. Internal tile boundaries use `[west,east) x [south,north)`; an internal corner therefore belongs to the north-east tile.
