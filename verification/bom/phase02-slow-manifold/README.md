# MITGCM-BOM Phase 2 slow-manifold verification

Status: **P2.4 CLOSED; P2.5 IS THE UNIQUE NEXT WORK PACKAGE**

This directory is the source-controlled design and verification index for
Phase 2. P2.0 remains the normative frozen contract. P2.1 has runtime
preflight, accepted/scratch endpoint storage, ocean/NONE/NONE transaction
publication, BOM-owned exact-time EXF wind and FILES Stokes, compiled copied
COUPLER Stokes publication, accepted-bracket stage-time interpolation, and
schema-2 field pickup. P2.2 adds accepted C-point SI gradients, spherical
metrics, finite-checked covariant terms, and vorticity operator candidates.
P2.3 adds separate stateless PAPER combined-total and JULIA weighted
per-source RHS paths, stable 27-component diagnostics, explicit/precombined
Stokes policy, and final-drift CFL/rollback checks.
P2.4 adds exact stage-position/time sampling, transactional production RK2
and RK4, live 27-component diagnostic state, B04/B05 analytical convergence,
and locked B16 Julia RHS/fixed-trajectory evidence. Adaptive Tsit5 output is
retained separately as non-gating context.

## P2.0 documents

- [`P2.0_SOURCE_AUDIT.md`](P2.0_SOURCE_AUDIT.md) records the source-backed
  findings from the 2024 eBOMB paper, the locked Julia implementation,
  MITgcm/EXF time loading, the current BOM state, and pickup lifecycle.
- [`P2.0_INTERFACE_FREEZE.md`](P2.0_INTERFACE_FREEZE.md) is the normative
  implementation contract for endpoint fields, Stokes ownership and
  de-duplication, metric derivatives, `PAPER2024`/`JULIA` RHS modes, time
  interpolation, rollback, diagnostics, and pickup schema 2.
- [`REQUIREMENTS_TRACEABILITY.md`](REQUIREMENTS_TRACEABILITY.md) maps every
  Phase-2 requirement to its planned production owner, executable tests, and
  work package.
- [`TEST_PLAN.md`](TEST_PLAN.md) freezes B04, B05, B16, negative, MPI,
  restart, FLT-coexistence, and complete-regression gates before production
  implementation begins.

## Frozen references

| Source | Frozen identity | Role |
|---|---|---|
| MITGCM-BOM baseline | `MITGCM-BOM-v0.2`, commit `1067c21d230e9c9619e89245b97c01e9474c7ed7` | Phase-2 entry baseline |
| Final Phase-1 production code | `3f330b59db76b8d7d0ca0fb2bfd007e567fbd6bc` | regression baseline, 257/257 PASS |
| 2024 eBOMB paper | arXiv `2410.01468v1`, equations (1), (2), (B.7), and (B.10)--(B.11) | default `PAPER2024` equation |
| Julia reference | `SargassumBOMB.jl@156557359185e4413ce82829f3ed26a4eb8c6283` | compatibility mode and B16 |
| Rebuilt Julia environment | Julia 1.10.12; Manifest SHA-256 `86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695` | reproducible Julia execution |

The paper is the scientific authority for `PAPER2024`. The locked Julia
source is the behavioral authority only for `JULIA`. MITgcm remains the
authority for grid metrics, lifecycle ordering, MPI, and I/O.

## Work-package boundaries

| Work package | Allowed production scope | Mandatory gate before the next package |
|---|---|---|
| P2.1 (closed) | old/new endpoint storage, source providers, time interpolation, schema-2 field pickup | P2-E01--E06, P2-N01--N04 and all Phase-1 regressions |
| P2.2 (closed) | C-point SI gradients, covariant terms, vorticity, metric validity | P2-D01--D05 and P2-N05 |
| P2.3 (closed) | stateless `PAPER2024`/`JULIA` component RHS and diagnostics | P2-H01--H06 and P2-N06 |
| P2.4 (closed) | stage-time RK integration, B04/B05, fixed Julia B16 files and checksums | P2-I01--I06 and P2-N07 |
| P2.5 | schema-2 output/restart integration, 1/2/4-rank, FLT coexistence, full regression | P2-P01--P04, P2-M01, P2-K01 and P2-G01 |

A later work package may refine internal implementation details, but it may
not change a frozen formula, source ownership rule, failure meaning, schema,
or acceptance threshold without first updating all four P2.0 documents and
recording a new `P2-Dxxx` decision.

## Evidence layout

Executable work starts in P2.1. All generated content remains outside Git:

```text
/home/wyl/build/mitgcm-bom/phase02-endpoint-state/<test-id>/
/home/wyl/runs/mitgcm-bom/phase02-endpoint-state/<test-id>/
/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/<work-package>/<test-id>/
```

Drivers must reject reuse of a test ID. Compact Markdown results and
manifests may be committed only after execution on a clean exact source head.

## Accepted P2.4 boundary and unique next task

P2.4 functional head `4b2d09d40` passes stage/RK B04/B05 11/11, B16/N07
12/12, P2.3 RHS 18/18, P2.2 derivatives 16/16, accepted P2.1
endpoint/provider and pickup 44/44, and all Phase-1/Phase-0 predecessors
257/257. The independently hashed aggregate is
`p24-closure/p24-closure-4b2d09d40-attempt01`, totaling 358/358. This closes
exact stage-position/time sampling, RK2/RK4 all-or-nothing updates, B04/B05
convergence, fixed checksummed B16 JULIA RHS/trajectories, and complete N07.
It does not change the frozen P2.3 equations or Stokes policy.

The unique next implementation task is P2.5. It must integrate the new live
diagnostic state into the frozen schema-2 output/pickup contract, prove
same-decomposition restart and 1/2/4-rank total-system consistency, preserve
FLT isolation, and execute P2-P01--P04, P2-M01, P2-K01 and final P2-G01.
Merge, release and `MITGCM-BOM-v0.3` remain outside the closed P2.4 scope.
