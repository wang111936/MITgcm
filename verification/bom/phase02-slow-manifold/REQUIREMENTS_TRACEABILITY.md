# Phase 2 slow-manifold requirements traceability

Status: **P2.0 FROZEN; P2.1--P2.5 CLOSED; PHASE 2 COMPLETE**

A requirement is complete only after its production implementation and the
listed executable evidence are both recorded. P2.0 freezes the mapping.
P2-R03--P2-R05, the field-value portion of P2-R07, and the P2.1 field-state
portion of P2-R16/P2-R18 have exact-commit evidence at `41d0dbc20`.
Derivative/metric/covariant operators have exact-commit evidence at
`5d4b91831`. Stateless RHS mode routing, component diagnostics, Stokes
de-duplication, and P2-H01--H06/P2-N06 have exact-commit evidence at
`fb004faf7`. Exact stage sampling, transactional RK2/RK4, B04/B05, locked B16
and P2-I01--I06/P2-N07 have exact-commit evidence at `4b2d09d40`. Schema-2
output/pickup, total-system MPI, restart, FLT isolation and final P2-G01 have
exact-commit evidence at `d37dccae7`.

## 1. Requirement matrix

| ID | Requirement | Planned production owner | Acceptance | Package | Status |
|---|---|---|---|---|---|
| P2-R01 | Preserve accepted LEEW, owner, output, pickup and FLT coexistence behavior | dispatch plus unchanged Phase-1 paths | P2-Z01, P2-K01, P2-G01 | P2.1--P2.5 | verified: `d37dccae7`, 390/390 |
| P2-R02 | Validate BOM mode, equation mode and SI slow-manifold parameters without aliasing leeway coefficient | `BOM_READPARMS`, `BOM_CHECK` | P2-C01, P2-N01, P2-H05 | P2.1/P2.3 | verified through H05/N06: `fb004faf7` |
| P2-R03 | Publish an exact, transactional two-endpoint environment bracket with stable labels and source codes | `BOM_FIELDS.h`, `BOM_BUILD_ENDPOINTS` | P2-E01, P2-E02, P2-N02 | P2.1 | verified: `b81bb0129` |
| P2-R04 | Evaluate EXF wind at exact model endpoints without mutating or relabeling EXF globals | `BOM_GET_EXF_WIND` | P2-E03, P2-N03 | P2.1 | verified: `43a79d1b1` |
| P2-R05 | Support NONE/FILES/COUPLER Stokes ownership with exact endpoint and availability semantics | `BOM_GET_STOKES` and provider hook | P2-E04, P2-E05, P2-N03 | P2.1 | verified through COUPLER: `6247ee6ba` |
| P2-R06 | Prevent explicit/embedded Stokes double counting and publish an auditable policy | `BOM_CHECK`, field metadata | P2-E05, P2-H04, P2-N04 | P2.1/P2.3 | verified through H04/N06: `fb004faf7` |
| P2-R07 | Interpolate every field and derivative at exact RK stage time with no extrapolation | `BOM_INTERP_ENV_TIME`, `BOM_INTERP_ENV_DERIVATIVES` | P2-E06, P2-I04, P2-N02 | P2.1/P2.4 | integrated through I04: `4b2d09d40` |
| P2-R08 | Compute second-order nonuniform C-point SI derivatives without crossing land | `BOM_BUILD_DERIVATIVES` | P2-D01, P2-D02, P2-D03, P2-N05 | P2.2 | verified `5d4b91831`: D01--D03 and complete N05 |
| P2-R09 | Apply Cartesian/spherical covariant metrics once and use MITgcm `fCori` | metric/derivative helpers | P2-D04, P2-D05, P2-H05, P2-N05 | P2.2/P2.3 | verified through RHS consumer H05: `fb004faf7` |
| P2-R10 | Implement the paper combined-field material derivative, total vorticity and component signs | `BOM_RHS_PAPER2024` | P2-H01, P2-H03, P2-H05, P2-I01 | P2.3/P2.4 | integrated through I01: `4b2d09d40` |
| P2-R11 | Implement the locked Julia per-source derivative and base-vorticity behavior separately | `BOM_RHS_JULIA` | P2-H02, P2-H03, P2-I05 | P2.3/P2.4 | integrated through I05: `4b2d09d40` |
| P2-R12 | Retain stateless RHS, per-stage finite/CFL checks and all-or-nothing particle commit | RHS, RK2/RK4, `BOM_MAIN` | P2-H06, P2-I04, P2-N06 | P2.3/P2.4 | integrated RK transaction verified: `4b2d09d40` |
| P2-R13 | Pass B04 solid-body-rotation analytical component and trajectory gates | derivative/RHS/RK integration | P2-I01, P2-I02 | P2.4 | verified: `4b2d09d40` |
| P2-R14 | Pass B05 time-varying-uniform exact and endpoint-refinement order gates | endpoint/RHS/RK integration | P2-I03, P2-I04 | P2.4 | verified: `4b2d09d40` |
| P2-R15 | Generate and pass locked, checksummed B16 Julia RHS and fixed-step trajectories | Julia generator and MITgcm comparison | P2-I05, P2-I06, P2-N07 | P2.4 | verified: `4b2d09d40` |
| P2-R16 | Restore schema-2 mode, fingerprint and two-endpoint state transactionally; constrain schema-1 migration | pickup read/write | P2-P01, P2-P02, P2-P04 | P2.1/P2.5 | verified: `d37dccae7`; schema-1 LEEW accepted, schema-1 BOM rejected |
| P2-R17 | Preserve 1/2/4-rank decomposition consistency, same-decomposition restart and FLT isolation | migration, pickup, lifecycle | P2-M01, P2-P03, P2-K01 | P2.5 | verified: `d37dccae7` |
| P2-R18 | Append stable failure/stage codes, direct diagnostics and complete predecessor regression | all Phase-2 paths | all negative gates, P2-P04, P2-G01 | P2.1--P2.5 | verified: `d37dccae7`, P2-G01 390/390 |

## 2. Reverse traceability by planned interface

| Interface | Requirements | Direct tests |
|---|---|---|
| `BOM_FIELDS.h` endpoint/source codes and state | P2-R03, P2-R16, P2-R18 | P2-E01/E02, P2-P01 |
| `BOM_BUILD_ENDPOINTS` | P2-R03--R07 | P2-E01--E06, P2-N02--N04 |
| `BOM_GET_EXF_WIND` | P2-R04 | P2-E03, P2-N03 |
| `BOM_GET_STOKES` FILES provider | P2-R05, P2-R06 | P2-E04, P2-N03 |
| COUPLER Stokes provider | P2-R05, P2-R06 | P2-E05, P2-N03/N04 |
| `BOM_INTERP_ENV_TIME` | P2-R07 | P2-E06, P2-N02, P2-I04 |
| `BOM_INTERP_ENV_DERIVATIVES` | P2-R07, P2-R08 | P2-D01, P2-N02, P2-I04 |
| `BOM_BUILD_DERIVATIVES` | P2-R08, P2-R09 | P2-D01--D05, P2-N05 |
| covariant operator helper | P2-R09--R11 | P2-D04/D05, P2-H01/H02/H05 |
| `BOM_RHS_PAPER2024` | P2-R10, P2-R12 | P2-H01/H03/H05/H06 |
| `BOM_RHS_JULIA` | P2-R11, P2-R12 | P2-H02/H03/H06, P2-I05 |
| stage-time RK2/RK4 | P2-R07, P2-R12--R15 | P2-I01--I06, P2-N06 |
| B16 generator/comparator | P2-R15, P2-R18 | P2-I05/I06, P2-N07 |
| schema-2 pickup | P2-R03, P2-R06, P2-R16--R18 | P2-P01--P04 |
| dispatch and FLT coexistence | P2-R01, P2-R17 | P2-Z01, P2-K01, P2-G01 |

## 3. Development-manual B-test mapping

| Manual test | Phase-2 tests | Frozen meaning |
|---|---|---|
| B04 solid-body rotation | P2-D01, P2-D04, P2-H01, P2-I01/I02 | gradient, vorticity, inertial signs and trajectory |
| B05 time-varying uniform flow | P2-E02/E06, P2-I03/I04 | exact derivative plus overall endpoint-sampling order |
| B06 RK convergence | P2-I02/I04 | fixed smooth RHS method order versus sampled-field order |
| B15 pickup | P2-P01--P03 | bracket/fingerprint restart and migration policy |
| B16 Julia comparison | P2-H02/H03, P2-I05/I06 | discriminating RHS and fixed-step trajectories |
| B03 wind/Stokes composition | P2-E03--E05, P2-H04 | source values, sigma and no duplicate counting |

## 4. Work-package closure requirements

| Package | Requirements eligible to close | Mandatory predecessors |
|---|---|---|
| P2.1 | P2-R02--R07 and field-state part of P2-R16/R18 | complete Phase 1 |
| P2.2 | P2-R08--R09 | accepted P2.1 exact endpoint state |
| P2.3 | P2-R10--R12 and de-dup diagnostics | accepted P2.2 derivatives |
| P2.4 | P2-R13--R15 | accepted P2.3 stateless RHS |
| P2.5 | P2-R01, P2-R16--R18 and remaining integration evidence | accepted P2.1--P2.4 |

P2.1 closure evidence is
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-closure/`
`p21-closure-41d0dbc20-attempt02` with 301/301 PASS. This closes the work
package boundary without claiming the P2.5 full-particle integration rows.

P2.2 closure evidence is
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p22-closure/`
`p22-closure-5d4b91831-attempt02` at exact functional commit `5d4b91831`.
It audits P2-D01--D05/complete N05 16/16, accepted endpoint 34/34,
schema-2 pickup 10/10, and 15 predecessor groups 257/257: 317/317 total.
This closes the P2.2 production boundary for P2-R08 and the metric/operator
portion of P2-R09. D05 verifies separate PAPER-total and JULIA-base vorticity
operator candidates; binding them into full mode-specific RHS components and
the P2-H05 consumer remains P2.3, not an implicit P2.2 claim.

P2.3 closure evidence is
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p23-closure/`
`p23-closure-fb004faf7-attempt01` at exact functional commit `fb004faf7`.
It audits P2-H01--H06/complete N06 18/18, P2.2 derivatives 16/16,
accepted endpoint/provider 34/34, schema-2 pickup 10/10, and 15 predecessor
groups 257/257: 335/335 total. This closes the P2.3 production boundary for
the stateless portions of P2-R10--R12 and completes the P2.3 consumer evidence
for P2-R02, P2-R06, and P2-R09. P2-I01/I04/I05 and authoritative particle
commit were assigned to P2.4 and are closed below.

P2.4 closure evidence is
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p24-closure/`
`p24-closure-4b2d09d40-attempt01` at exact functional commit `4b2d09d40`.
It audits P2-I01--I04 stage/RK 11/11, B16 I05/I06 and complete N07 12/12,
accepted P2.1--P2.3 gates 78/78, and 15 Phase-1/Phase-0 predecessor groups
257/257: 358/358 total. This closes P2-R13--R15 and the integrated-stage/
transaction portions of P2-R07 and P2-R10--R12. New live diagnostics are
finite-checked and migration-safe; output/pickup schema integration and final
P2-R01/P2-R16--R18 closure were assigned to P2.5 and are closed below.

P2.5 closure evidence is
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-closure/`
`p25-closure-d37dccae7-attempt01` at exact functional commit `d37dccae7`.
It audits P2-P01--P04/P2-M01 20/20, P2-K01 12/12, accepted P2.1--P2.4
gates 101/101, and 15 Phase-1/Phase-0 predecessor groups 257/257: 390/390
total. This closes P2-R01 and P2-R16--R18, including transactional schema-2
restart with all 27 diagnostics, 1/2/4-rank invariance, same-decomposition
restart, corruption rollback and FLT isolation. Changed-decomposition restart
remains explicitly unsupported and rejected.

A work package must not mark a later requirement complete by using a test-only
stub in place of the planned production owner. Component tests may inject
fields, times, or failures, but the final P2-G01 must exercise the production
lifecycle and all source policies that are claimed as supported.

## 5. Traceability rules

- every new production `BOM_` routine maps to at least one P2 requirement;
- every executable P2 test names at least one P2 requirement;
- stable IDs are never renumbered or reused;
- a deferred capability stays planned and is not described as implemented;
- `TEST_RESULTS.md` records only actual exact-head runs;
- P2-G01 covers every requirement and all Phase-1/Phase-0 predecessors; its
  390/390 closure satisfies the Phase-2 exit gate, while merge, release and
  `MITGCM-BOM-v0.3` creation require separate authorization.
