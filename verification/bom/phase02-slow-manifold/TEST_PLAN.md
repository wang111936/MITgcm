# Phase 2 slow-manifold test plan

Status: **FROZEN BEFORE IMPLEMENTATION; NO RESULTS CLAIMED**

## 1. Evidence and execution rules

All builds, runs, generated inputs, and logs remain outside Git:

```text
/home/wyl/build/mitgcm-bom/phase02-slow-manifold/<test-id>/
/home/wyl/runs/mitgcm-bom/phase02-slow-manifold/<test-id>/
/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/<package>/<test-id>/
```

Every driver must reject an existing test ID and record:

- exact source SHA, branch, and dirty status;
- Phase-1 production baseline and v0.2 identities;
- paper version, Julia source/Project/Manifest hashes, and Julia version when
  applicable;
- compiler, MPI, optfile, `SIZE.h`, package list, and decomposition;
- all namelist, field, particle, golden, and script SHA-256 values;
- command, exit status, normal/abnormal markers, assertion counts, and errors;
- compact summary, row count, and a self-validating manifest.

Fortran `STOP` status alone never decides a negative gate. Expected error text
and absence of normal completion are both required. P2.0 itself runs only
Markdown scope, link, ID, and consistency audits.

## 2. Compile, scope, and zero-impact gates

| ID | Configuration | Requirements | Pass criterion |
|---|---|---|---|
| P2-C01 | BOM off/on; serial/MPI; EXF off/on; provider stubs off/on | P2-R02, P2-R18 | all planned combinations compile/link; unavailable source is rejected at runtime, not by unresolved symbols |
| P2-C02 | GNU debug with bounds, uninitialized and IEEE traps | P2-R12, P2-R18 | clean compile/link and no warning promoted by new code |
| P2-C03 | work-package diff audit | all | only the package's frozen paths change; no generated output or unrelated project file |
| P2-Z01 | LEEW, BOM disabled/zero particle, Phase-1 full matrix | P2-R01 | accepted Phase-1 results and hashes unchanged |

## 3. Parameter and endpoint gates

| ID | Scenario | Requirements | Pass criterion |
|---|---|---|---|
| P2-E01 | fresh single-time initialization then first complete bracket | P2-R03 | initial endpoints equal exactly; first step publishes exact `(t0,iter0)/(t1,iter1)` and finite source arrays |
| P2-E02 | consecutive steps with nonuniform values | P2-R03 | previous endpoint 1 becomes next endpoint 0 bitwise; no stale or skipped label |
| P2-E03 | EXF wind records not aligned with ocean steps | P2-R04 | BOM endpoint values equal independent EXF time evaluation at exact t0/t1; EXF globals unchanged bitwise |
| P2-E04 | Stokes NONE and FILES with time interpolation/repeat cycle | P2-R05 | zeros are exact for NONE; FILES endpoints, scale, mask and labels match independent reader oracle |
| P2-E05 | COUPLER publication and source/de-dup matrix | P2-R05, P2-R06 | exact copied endpoints when available; every legal/illegal matrix row has direct evidence |
| P2-E06 | stage times at endpoints, midpoints and release split | P2-R07 | exact endpoint snap, exact linear interpolation, constant secant derivative, no extrapolation |

Negative gates:

| ID | Scenario | Requirements | Expected failure |
|---|---|---|---|
| P2-N01 | NaN/range/overflow in alpha, tauDays, R, sigma, period/scale; invalid equation/source/current policy or file precision | P2-R02 | named parameter and value before conversion/RHS; no state commit |
| P2-N02 | reversed/nonfinite bracket, broken iteration continuity, stage outside bracket | P2-R03, P2-R07 | `BOM_FAIL_FIELD_TIME`, endpoint context, accepted bracket unchanged |
| P2-N03 | EXF/file/coupler missing, partial, stale, future, nonfinite or uncovered endpoint | P2-R04, P2-R05 | `BOM_FAIL_FIELD_SOURCE`, exact source/endpoint context |
| P2-N04 | embedded plus explicit Stokes, nonzero sigma with NONE, missing declaration metadata | P2-R06 | `BOM_FAIL_STOKES_DUPLICATE` or setup source failure before fields/RHS |

## 4. Derivative and metric gates

| ID | Scenario | Requirements | Pass criterion |
|---|---|---|---|
| P2-D01 | Cartesian uniform/nonuniform grid, constant and affine vector fields | P2-R08, P2-R13 | constant derivative exact zero; affine derivatives meet scaled roundoff threshold |
| P2-D02 | Cartesian quadratic fields with grid spacing halved | P2-R08 | centered and permitted one-sided gradients show order in `[1.8,2.2]` |
| P2-D03 | all-wet MPI halo/tile boundary affine fields, 1/2/4 ranks | P2-R08 | sorted C-point gradients and validity masks bitwise equal across decompositions |
| P2-D04 | spherical zonal/meridional analytic fields at multiple latitudes | P2-R09, P2-R13 | physical gradients, `tauSphere` and covariant terms match analytic SI values |
| P2-D05 | vorticity and `fCori` at C points, with/without explicit Stokes | P2-R09, P2-R10, P2-R11 | PAPER total and JULIA base-only vorticity match their separate oracles |
| P2-N05 | zero/NaN metric, near pole, insufficient all-wet derivative stencil | P2-R08, P2-R09 | stable metric/gradient failure; no zero fill, cross-land derivative or partial publish |

For affine derivatives the component threshold is

```text
abs(error) <= 512*epsilon(_RL)*max(1 s^-1, abs(expected), fieldScale/metricScale)
```

with dimensional terms evaluated consistently in the test driver. Quadratic
tests decide convergence order rather than using this roundoff threshold.

## 5. RHS component gates

| ID | Scenario | Requirements | Pass criterion |
|---|---|---|---|
| P2-H01 | PAPER2024 analytic component table | P2-R10 | v, u, Dv, Du, omega, f/tauSphere, four rotation terms, inertia and drift all match independently computed values |
| P2-H02 | locked JULIA analytic component table | P2-R11 | per-source derivatives, base vorticity and final components match locked source algebra after SI conversion |
| P2-H03 | discriminating nonparallel-gradient field | P2-R10, P2-R11 | each mode matches its oracle and their difference exceeds 1000 times combined tolerance |
| P2-H04 | explicit/precombined Stokes A/B cases | P2-R06 | legal equivalent inputs agree when mathematically equivalent; illegal duplicate never reaches RHS |
| P2-H05 | Cartesian/spherical SI and `fCori` sign cases | P2-R02, P2-R09, P2-R10 | no day/degree leakage; north/south and cyclonic/anticyclonic signs are direct assertions |
| P2-H06 | injected failure at every component and final CFL | P2-R12, P2-R18 | first stable code/stage retained and all authoritative particle fields unchanged |
| P2-N06 | nonfinite/overflow in combined fields, covariant terms, inertia or drift; per-stage CFL rejection | P2-R12, P2-R18 | `BOM_FAIL_EQUATION` or the preserved CFL code at the exact stage; no particle commit |

Finite analytic RHS values use

```text
abs(error_q) <= 1024*epsilon(_RL)
                *max(qUnitScale, abs(expected_q), componentScale_q)
```

where every term has the units of component `q`; unless the cross-language
B16 threshold below is larger.

## 6. B04, B05, RK, and B16 gates

### B04 solid-body rotation

For Cartesian `v=(-Omega*y,Omega*x)`, zero wind/Stokes, alpha zero, constant
`f`, and no springs:

- P2-I01 checks the exact gradient matrix, `omega=2*Omega`, material
  acceleration, rotation signs, inertia, and drift at fixed points;
- P2-I02 advances particles with RK2/RK4 at four step sizes, checks the
  analytic/local high-accuracy trajectory, and requires observed RK2 order
  `[1.8,2.2]` and RK4 order `[3.5,4.5]` while endpoint fields are exact.

### B05 time-varying uniform flow

- P2-I03 uses `v(t)=a+b*t`, optional affine wind/Stokes in time, zero spatial
  gradients, and checks exact endpoint interpolation, exact secant derivative,
  component RHS, and analytic displacement;
- P2-I04 uses a smooth quadratic-in-time field sampled only at ocean
  endpoints. Halving ocean and particle step together must show the frozen
  endpoint-representation order `[1.8,2.2]` for both RK2 and RK4. A separate
  fixed exact stage-field fixture retains the integrator orders above.

Thus a passing RK4 B04 test does not authorize a fourth-order claim for
real forcing sampled only at old/new ocean endpoints.

### B16 locked Julia fixture

P2-I05 generates and validates the frozen files from
`P2.0_INTERFACE_FREEZE.md` using:

- Julia 1.10.12;
- locked source commit `156557359185e4413ce82829f3ed26a4eb8c6283`;
- Manifest SHA-256
  `86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695`;
- Cartesian all-wet 400 km by 300 km domain;
- three particles, 0--86400 s, fixed 900 s RK2/RK4;
- `alpha=0.00337`, `tau=0.0103 d`, `R=0.823`, `sigma=1.2`,
  `f=2.18213 d^-1` converted once to SI;
- distinct affine base/Stokes/wind fields with nonparallel gradients.

P2-I06 compares MITgcm `JULIA` results after checksum validation:

```text
RHS: abs <= 2e-12 m/s + 5e-12*abs(reference)
trajectory physical error:
     <= max(1e-6 m, 5e-11*accumulated path length)
```

Every recorded RHS component is compared, not only final speed. Adaptive
Tsit5 output is informational and cannot replace the fixed-step oracle.
`PAPER2024` is tested against independent analytic component oracles, not
redefined by the Julia compatibility output.

P2-N07 changes one source, Project/Manifest, input, or golden checksum at a
time and requires rejection before Julia generation or MITgcm comparison.
A mismatched source commit or Julia version is also a hard preflight failure.

## 7. Pickup, MPI, and coexistence gates

| ID | Scenario | Requirements | Pass criterion |
|---|---|---|---|
| P2-P01 | schema-2 write/read preflight and transaction | P2-R16 | mode/fingerprint/bracket/fields/particles validate in scratch and commit once |
| P2-P02 | schema-1 migration | P2-R16 | unchanged LEEW accepted; BOM rejected before particle/field commit |
| P2-P03 | N continuous vs K+pickup+(N-K), 1/2/4 ranks | P2-R16, P2-R17 | final authoritative state, bracket, diagnostics and schedule bitwise equal for same decomposition |
| P2-P04 | corrupted field block, mode/source/fingerprint/decomposition mismatch | P2-R16, P2-R18 | specific early failure; accepted state unchanged in component driver |
| P2-M01 | B04/B05/B16 across 1/2/4 ranks and tile crossings | P2-R17 | sorted state/trajectory and endpoint fields meet exact or frozen numeric criteria |
| P2-K01 | neither/FLT/BOM/both, LEEW and BOM cases | P2-R01, P2-R17 | no symbol/file/state conflict; FLT and BOM independent results unchanged |

Changed-decomposition pickup is still a required rejection, not a Phase-2
feature. COUPLER runtime evidence may use a deterministic provider harness;
a site-specific wave model is not required for the interface gate.

## 8. Work-package gates

| Package | Must pass before merge |
|---|---|
| P2.0 | Markdown-only diff, links, stable IDs, formulas, source references and no production/test-input changes |
| P2.1 | P2-C01/C02, P2-Z01, P2-E01--E06, P2-N01--N04, schema-2 field component preflight, all Phase-1 regressions |
| P2.2 | P2-D01--D05, P2-N05, all accepted P2.1 and predecessor regressions |
| P2.3 | P2-H01--H06, P2-N06, all accepted P2.1/P2.2 and predecessor regressions |
| P2.4 | P2-I01--I06, P2-N07, B16 checksum/reproducibility, all accepted predecessor regressions |
| P2.5 | P2-P01--P04, P2-M01, P2-K01, P2-G01 |

## 9. P2-G01 final integration gate

From new build/run/evidence roots on one clean exact Phase-2 production head:

1. verify source, paper version, Julia source/environment, inputs and scripts;
2. run all P2-C/Z/E/N/D/H/I/P/M/K gates;
3. run serial plus 1/2/4-rank and same-decomposition restart matrices;
4. rerun all 257 Phase-1 gates and the Phase-0/nested P0.4 gates;
5. verify FLT/BOM coexistence in LEEW and BOM modes;
6. generate a row-complete aggregate manifest and requirements coverage;
7. independently audit the immutable PR patch and exact evidence head;
8. reject tag `MITGCM-BOM-v0.3` until every Phase-2 exit condition is closed.

## 10. Tolerance-change rule

A failed gate cannot be fixed only by increasing tolerance. Any change must
retain the original failure evidence, identify whether the cause is analytic
scaling, discretization, cross-language arithmetic, or implementation error,
and update this plan plus the corresponding requirement and design decision
before rerun. Exact ID, status, count, source code, time/iteration labels,
availability masks, and same-decomposition restart fields are never
tolerance-based.
