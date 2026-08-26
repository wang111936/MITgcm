# MITGCM-BOM P2.3 dual-mode RHS verification

Status: **P2.3 CLOSED; P2.4 IS THE UNIQUE NEXT WORK PACKAGE**

This isolated case verifies the stateless Phase-2 slow-manifold component
operator. It consumes one stage-position/time snapshot after field and
derivative interpolation and dispatches two deliberately separate equations:

- `BOM_RHS_PAPER2024` first combines the base current and scaled Stokes
  drift, forms total carrying velocity with wind, and then evaluates the
  nonlinear covariant material derivatives and total-field vorticity;
- `BOM_RHS_JULIA` evaluates the base-current, Stokes, and wind material
  derivatives separately before weighting them, while retaining the locked
  Julia base-current vorticity behavior;
- `BOM_RHS_COMPONENTS` validates the equation/current/Stokes policy, shared
  SI parameters, `fCori`, `tauSphere`, source values and derivatives, then
  publishes all 27 diagnostics only after every component and the final
  total-drift CFL check succeeds.

The stable diagnostic indices live in `pkg/bom/BOM.h`. They cover combined
water/carrying velocities, material derivatives, vorticity, rotation,
inertial response, final drift, and native coordinate rates. The dispatcher
returns stable failure and stage context, whether explicit Stokes was applied,
and the final drift CFL. It never writes authoritative particle COMMON state.

## Direct gates

- P2-H01: PAPER2024 analytic component oracle;
- P2-H02: locked JULIA analytic component oracle;
- P2-H03: a nonparallel-gradient field that distinguishes the two equations;
- P2-H04: explicit versus legal precombined Stokes equivalence and duplicate
  policy priority;
- P2-H05: Cartesian/spherical signs, northern/southern `fCori` and
  `tauSphere`, cyclonic/anticyclonic vorticity, and days-to-seconds conversion
  exactly once;
- P2-H06: complete 27-component publication, final-drift CFL, rollback, and
  unchanged particle sentinels;
- P2-N06: 17 invalid/policy/nonfinite/overflow injections with stable
  failure/stage attribution and zero unpublished diagnostics;
- serial/MPI4: eight sorted records are bitwise equal.

Run with:

```bash
verification/bom/phase02-rhs-components/run_rhs_component_gate.sh
```

The driver compiles the production sources with GNU IEEE/development checks
and traps for invalid, divide-by-zero, and overflow arithmetic. Ordinary
finite arithmetic in the independent test oracle is intentionally separate
from the production protected helpers.

## Frozen ownership and policy

`EULERIAN` current accepts explicit Stokes and applies `sigma` exactly once.
`PRECOMBINED` current rejects any explicit Stokes source before inspecting
source values. An absent Stokes source must be finite exact zero; therefore a
NaN cannot bypass the policy under floating-point traps. `PAPER2024` remains
the default production equation mode.

## Boundary

P2.3 adds no call from `BOM_MAIN` or the particle RK kernels, makes no pickup
schema change, and does not claim B04, B05, or B16 trajectories. Stage-time
RK2/RK4 wiring, integrated trajectory/convergence tests, and fixed Julia
golden files belong exclusively to P2.4. P2.5 retains final output/restart,
1/2/4-rank, FLT coexistence, and complete integration closure.

Exact-head results, hashes, regressions, and attempt provenance are recorded
in `TEST_RESULTS.md`.
