# P1.3 production lifecycle results

Status: **PASS** for the complete P1.3 single-owner production implementation
and its exact-head regression matrix. Owner migration remains P1.4 scope.

## Immutable implementation

- exact tested head:
  `8e906173543159ce677e58155cde02c99774d4ef`;
- production lifecycle commit:
  `8d259e6231f052e382dfce5001dc0f05406471ae`;
- P1-I01 lifecycle-coverage commit:
  `8e906173543159ce677e58155cde02c99774d4ef`;
- author and committer:
  `WangYuLin <wang111936@outlook.com>`;
- branch: `MITGCM-BOM/phase-01-single-tile-integration`;
- base:
  `MITGCM-BOM/development@eefca92fe53f1b144bbfca7fcf00dc949a22afb3`;
- locked Julia source:
  `156557359185e4413ce82829f3ed26a4eb8c6283`
  (SargassumBOMB 0.7.14).

The repository was clean before every exact-head gate. All builds used
Ubuntu 22.04, GNU Fortran 11.4, OpenMPI 4.1.2 where applicable, and the
repository `linux_amd64_gfortran` options. Julia reference gates used
Julia 1.10.12 and the locked offline depot.

## Production result

The accepted caller now provides:

- trap-safe equal-substep setup with a forced authoritative final endpoint;
- scaled release-time comparisons and exact start/interior/end/future
  WAITING transitions;
- stateless status, active-duration, and age candidates with overflow guards;
- RK2/RK4 advancement and zero-duration FINAL diagnostic refresh;
- one authoritative per-particle commit only after every candidate succeeds;
- step-start, optional substep, and unconditional step-end compact-state
  budgets;
- exact global owner count and 64-bit ID uniqueness using gathered high/low
  integer words;
- compact-tail, status, age, finite-field, owner, stencil, and stored-index
  validation with collective failure context.

No owner migration, Stokes term, trajectory output, pickup, or FLT call was
added by this increment.

## Exact-head lifecycle gate

Executed on 2026-08-25 from a clean worktree:

```text
build:    /home/wyl/build/mitgcm-bom/phase01-single-tile/p13-lifecycle-20260824T191547Z-402
run:      /home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-lifecycle-20260824T191547Z-402
artifact: /home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/p13-lifecycle-20260824T191547Z-402
```

`source-head.txt` equals the exact tested head. The external checksum audit
reports:

```text
summary.tsv: OK
source-head.txt: OK
```

Summary: **13/13 PASS**.

| Group | Result | Evidence |
|---|---:|---|
| source contract | 1/1 | equal substeps, final endpoint, release/age transaction, global compact-state budget, and no P1.4 migration call |
| GNU debug/IEEE builds | 2/2 | serial and MPI4 link the complete production caller, release, substep, state-budget, RK2/RK4, and verifier symbols |
| P1-S04b | 2/2 | RK2 and RK4 produce exact ALIVE/future/start/interior/final-end release displacement, status, age, and diagnostics |
| P1-I01 caller | 1/1 | zero frozen RHS preserves four ALIVE/WAITING positions bitwise and advances status/age exactly |
| MPI4 budget | 1/1 | one stationary owner per rank; IDs span signed-low-word boundary; exact ID and owner budget at every substep |
| P1-N08 lifecycle | 6/6 | age overflow, duplicate ID, owner-count mismatch, corrupt tail, invalid status, and RK4 K4 owner departure terminate before invalid commit |

The release helper additionally passed direct start/interior/end/future,
invalid-status, future-ALIVE release, WAITING nonzero-age, final-endpoint, and
age-overflow assertions.

## Exact-head full regression

Every row below ran after the P1-I01 coverage commit on the same clean exact
head. Total recorded matrix: **157/157 PASS**.

| Gate | Result | Run/evidence root |
|---|---:|---|
| P1.3 lifecycle | 13/13 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-lifecycle-20260824T191547Z-402` |
| P1.3 setup/EXF | 17/17 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-setup-20260824T191644Z-395` |
| P1.3 Leeway RHS | 15/15 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-rhs-20260824T191807Z-378` |
| P1.3 stateless RK2 | 11/11 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-rk2-20260824T192113Z-404` |
| P1.3 stateless RK4 | 11/11 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-rk4-20260824T192225Z-31252` |
| P1.2 wet-pair component | 9/9 | `/home/wyl/runs/mitgcm-bom/phase01-interp/p12-interp-20260824T192329Z-397` |
| P1.2 surface fields | 7/7 | `/home/wyl/runs/mitgcm-bom/phase01-fields/p12-field-20260824T192428Z-401` |
| P1.2 mapping | 19/19 | `/home/wyl/runs/mitgcm-bom/phase01-mapping/p12-20260824T192533Z-396` |
| P1.1 state/initial input | 42/42 | `/home/wyl/runs/mitgcm-bom/phase01-state/20260824T192646Z-392` |
| Phase 0 final gate | 4/4 | `/home/wyl/runs/mitgcm-bom/phase00-final-gate/20260824T192936Z-397` |
| nested formal P0.4 | 9/9 | `/home/wyl/runs/mitgcm-bom/phase00-zero-particle/20260824T192936Z-397-p04` |

The affine convergence evidence remained inside the frozen ranges:

- RK2 finest orders: `1.9885`, `1.9942`;
- RK4 finest orders: `3.9858`, `3.9931`.

## Ready-review acceptance completion

The independent Ready review found that the original P1-I03 row checked the
spherical native rate but not direct displacement. Verification commit
`0458910a9bb484aab8901d1a17046e3804e82165` adds one analytic spherical
displacement row to each full RK gate. RK2 and RK4 both pass 12/12 on that
clean exact head. The cumulative P1.3 and predecessor record is therefore
**159/159 PASS**; production source is unchanged from the original lifecycle
matrix.

## Compatibility decisions recorded during execution

1. MITgcm string `STOP` can return process status 0. Negative lifecycle
   acceptance therefore requires the exact production diagnostic, an
   abnormal/collective-stop marker, and absence of the normal-end marker;
   process status alone is never used as the verdict.
2. The historical P1.2 15-row result included a diagnostic-only, non-moving
   `BOM_MAIN`. P1.3 intentionally replaces that caller. The current P1.2
   regression retains nine direct/source wet-pair checks; the 13-row P1.3
   lifecycle gate now owns caller motion and failure coverage. Historical
   P1.2 results remain immutable.
3. P1.1 BOM-active positives now stop after initialization so an initial-state
   gate does not depend on P1.4 owner migration. BOM-disabled serial/MPI2/MPI4
   runs still execute the complete ocean baseline and pass all eight hashes.
4. Runtime substep/time preflight is performed before field publication. This
   safety refinement ensures P1-N01b invalid time or integer-range input cannot
   publish a new snapshot; it does not write particle state and leaves the
   frozen field labels and integration interval unchanged.

## Remaining boundary

P1.3 retains a deliberate hard stop whenever an RK stage or accepted
candidate leaves its current owner tile. P1.4 must replace that boundary with
deterministic same-rank and cross-rank owner migration, capacity checks, hop
limits, and decomposition-consistency evidence. P1.5 must still implement
trajectory output, pickup/restart, and FLT coexistence.

PR #13 remains Draft. This evidence does not authorize a Ready transition,
merge, or `MITGCM-BOM-v0.2` tag; the independent readiness review remains a
separate gate.
