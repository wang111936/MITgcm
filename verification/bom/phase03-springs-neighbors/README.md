# MITGCM-BOM Phase 3 springs and distributed neighbors

Status: **P3.0 INTEGRATED; P3.1 FUNCTIONAL HEAD VERIFIED, REVIEW PENDING**

Frozen source commit: `e81ddaa521e5f3babe54ba0ac8964c3dae058f88`.
The immutable document/scope audit is 12/12 PASS; see
`P3.0_DESIGN_AUDIT.md`. PR #26 was integrated into
`MITGCM-BOM/development` by merge commit
`96b38052c5444c995bc9e88078066a6ba9899ead`.

Phase 3 adds interacting-particle spring velocity, a production cutoff graph,
distributed ghost exchange, and deterministic raft diagnostics to the accepted
Phase 2 slow-manifold particle integrator. The release target is
`MITGCM-BOM-v0.4`.

P3.0 remains documentation-only. P3.1 adds only the frozen parameter/code
schema, canonical pair geometry, stateless Hooke/eBOMB reference laws, and
verification-only KNN/locked Julia references. It does not add the production
cell list, ghost exchange, ensemble RK, raft diagnostics, or schema 3.

## Current progress

| Package | State | Evidence |
|---|---|---|
| P3.0 | integrated | PR #26 merge `96b38052c5`; document audit 12/12 |
| P3.1 | exact functional head verified; review/integration pending | `3c1bc5821e`; direct 34/34; predecessor 390/390 |
| P3.2 | not started | waits for accepted P3.1 |
| P3.3 | not started | waits for accepted P3.1/P3.2 |
| P3.4 | not started | waits for accepted P3.1--P3.3 |
| P3.5 | not started | waits for accepted P3.1--P3.4 |

The detailed P3.1 decision is in `P3.1_CLOSEOUT.md`; executable evidence and
manifest hashes are in `../phase03-reference-laws/TEST_RESULTS.md`.

## Frozen documents

- `P3.0_SOURCE_AUDIT.md`: facts and discrepancies found in the locked Julia,
  current MITGCM-BOM, and development-manual sources;
- `P3.0_INTERFACE_FREEZE.md`: runtime parameters, pair geometry, spring laws,
  graph, ghost, ensemble-RK, raft, schema and failure contracts;
- `REQUIREMENTS_TRACEABILITY.md`: P3-R01--P3-R18 forward and reverse map;
- `TEST_PLAN.md`: B07--B09/B17, negative, regression and performance gates;
- `P3.0_DESIGN_AUDIT.md`: executable scope/number/link audit and entry decision.

## Work packages

| Package | Scope | Required closeout | State |
|---|---|---|---|
| P3.0 | source audit and immutable contracts | document audit; no production diff | integrated |
| P3.1 | canonical pair geometry, KNN oracle and stateless spring laws | P3-K01, P3-D01, B07/B08 direct kernels | 34/34 + 390/390 PASS; review pending |
| P3.2 | serial/same-rank cutoff cell-linked list | P3-N01/N02, oracle equality, complexity counters | not started |
| P3.3 | distributed ghost exchange and ensemble RK2/RK4 | B09, B17, rollback and spring stability | not started |
| P3.4 | connected components, raft diagnostics and schema 3 | restart/output/component gates | not started |
| P3.5 | full regression and algorithmic/performance closeout | P3-G01 and no all-pairs production path | not started |

The packages may contain multiple implementation commits, but the dependency
order may not be bypassed. Each package needs an exact-head evidence root,
source/driver hashes, row-count audit, and an empty captured Git status.

## Compatibility boundary

- `bomSpringLaw='NONE'` is the default and must preserve the exact v0.3 path.
- `LEEW` remains non-interacting and retains schema 1.
- Phase 2 `BOM` without springs retains container schema 2.
- Spring-enabled `BOM` uses container schema 3 with a required P3 sidecar;
  the 48-field schema-2 core record is not widened.
- Same-decomposition restart remains the accepted contract.
- General grids, biology, beaching, births/deaths, OpenMP production support,
  changed-decomposition restart, and target-server scaling stay out of Phase 3.

## Production complexity boundary

The K-nearest/all-particle oracle is verification-only and is never compiled
into `pkg/bom`. Production uses a cutoff cell-linked list and exchanges only
ghost candidates needed by spatially adjacent tiles. There may be no root
gather, global particle allgather, or unconditional all-particle nested loop in
the production path.

The production work model is `O(N_owner + N_ghost + N_candidate + N_edge)`.
Dense pathological cells can still make `N_candidate` quadratic; capacity
checks and counters must expose that condition rather than hiding it behind an
incorrect universal linear-complexity claim.

## Baseline

- base tag: `MITGCM-BOM-v0.3`;
- tag object: `9360a06d0379051aced0601b25aa814dda6330fb`;
- peeled commit: `332a406e958e5005f60267c187fada1f74319fc3`;
- Phase 2 release gate: 390/390 PASS;
- local environment: Ubuntu 22.04, GNU Fortran 11.4.0, Open MPI 4.1.2,
  Julia 1.10.12.

P3.1 must be reviewed and integrated before P3.2 starts. No
`MITGCM-BOM-v0.4` tag is authorized at this boundary; the tag remains a P3.5
exit action after the full Phase 3 integration and independent audit.
