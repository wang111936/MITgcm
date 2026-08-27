# MITGCM-BOM Phase 3 springs and distributed neighbors

Status: **P3.0 DESIGN / INTERFACE / TEST FREEZE COMPLETE**

Frozen source commit: `e81ddaa521e5f3babe54ba0ac8964c3dae058f88`.
The immutable document/scope audit is 12/12 PASS; see
`P3.0_DESIGN_AUDIT.md`.

Phase 3 adds interacting-particle spring velocity, a production cutoff graph,
distributed ghost exchange, and deterministic raft diagnostics to the accepted
Phase 2 slow-manifold particle integrator. The release target is
`MITGCM-BOM-v0.4`.

P3.0 is documentation-only. It does not add spring or neighbor Fortran, change
`BOM_SIZE.h`, extend an on-disk schema, or alter the accepted v0.3 trajectory.
Production implementation must follow the frozen work-package order and pass
the gates in this directory.

## Frozen documents

- `P3.0_SOURCE_AUDIT.md`: facts and discrepancies found in the locked Julia,
  current MITGCM-BOM, and development-manual sources;
- `P3.0_INTERFACE_FREEZE.md`: runtime parameters, pair geometry, spring laws,
  graph, ghost, ensemble-RK, raft, schema and failure contracts;
- `REQUIREMENTS_TRACEABILITY.md`: P3-R01--P3-R18 forward and reverse map;
- `TEST_PLAN.md`: B07--B09/B17, negative, regression and performance gates;
- `P3.0_DESIGN_AUDIT.md`: executable scope/number/link audit and entry decision.

## Work packages

| Package | Scope | Required closeout |
|---|---|---|
| P3.0 | source audit and immutable contracts | document audit; no production diff |
| P3.1 | canonical pair geometry, KNN oracle and stateless spring laws | P3-K01, P3-D01, B07/B08 direct kernels |
| P3.2 | serial/same-rank cutoff cell-linked list | P3-N01/N02, oracle equality, complexity counters |
| P3.3 | distributed ghost exchange and ensemble RK2/RK4 | B09, B17, rollback and spring stability |
| P3.4 | connected components, raft diagnostics and schema 3 | restart/output/component gates |
| P3.5 | full regression and algorithmic/performance closeout | P3-G01 and no all-pairs production path |

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

The first production task after P3.0 is P3.1. It must not introduce ghost MPI,
ensemble integration, raft I/O, biology, or target-server optimization.
