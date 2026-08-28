# Phase 3 requirements traceability

Status: **P3.3 EVIDENCE RECORDED; P3.4--P3.5 PENDING**

Baseline: `MITGCM-BOM-v0.3` at `332a406e958e5005f60267c187fada1f74319fc3`

Every requirement has a named production owner and executable evidence. A
future implementation cannot mark a row complete by citing a document-only
review or a narrower unit test.

P3.1 evidence anchor: clean functional head
`3c1bc5821ea6a7515dafe5b4142140c16a6cec98`, direct gate 34/34 and complete
Phase 2 predecessor regression 390/390. See `P3.1_CLOSEOUT.md` and
`../phase03-reference-laws/TEST_RESULTS.md`.

P3.2 evidence anchor: clean functional head
`5e57bfbfcac2d49d037f7240819082feb32d38d0`, direct gate 18/18, accepted
P3.1 regression 34/34 and complete Phase 2 regression 390/390. See
`P3.2_CLOSEOUT.md` and `../phase03-cutoff-graph/TEST_RESULTS.md`.

P3.3 evidence anchors: complete predecessor functional head
`53f9670ee97e7b793f4a1ac164f46c1ce30c1abf` with Phase 2 regression
390/390, and clean unified direct-verification head
`9b9ea50df28a5ce1e405b903d78fe6dbc9120eb0` with P3.3 34/34,
accepted P3.2 18/18 and accepted P3.1 34/34. See `P3.3_CLOSEOUT.md` and
`../phase03-spring-ensemble/TEST_RESULTS.md`.

## 1. Forward map

| ID | Requirement | Intended production owner | Required evidence | Package | Current evidence state |
|---|---|---|---|---|---|
| P3-R01 | Preserve byte-for-byte accepted v0.3 behavior when springs are `NONE`, including LEEW/BOM schemas and FLT coexistence | `BOM_CHECK`, existing dispatch | P3-Z01 plus full 390-row predecessor gate | P3.1--P3.5 | P3.3 portion PASS: explicit NONE bypass plus 390/390 including FLT coexistence; final P3.5 closure pending |
| P3-R02 | Validate spring/neighbor modes, SI parameters, capacities and stable failure/phase codes without changing existing numeric codes | `BOM_READPARMS`, `BOM_CHECK`, `BOM.h` | P3-C01, P3-N10 | P3.1 | P3.1 parameter/code and P3.2 local capacity/phase portions PASS |
| P3-R03 | Produce one canonical finite pair displacement/distance for Cartesian, spherical and periodic-X geometry | `BOM_PAIR_GEOMETRY` | P3-D01, B09 geometry cases, P3-N03 | P3.1 | P3-D01/N03 and distributed B09 P3.3 geometry PASS |
| P3-R04 | Provide a locked small-system K-non-self-neighbor oracle and deterministic median natural length; keep it out of production | verification oracle/generator | P3-K01, source/link isolation audit | P3.1 | verified at P3.1 |
| P3-R05 | Define an exact symmetric cutoff graph with included radius equality, no self/duplicates and ID-sorted owner lists | `BOM_BUILD_NEIGHBORS` | P3-N01, P3-N02 | P3.2 | verified at P3.2 |
| P3-R06 | Generate production candidates with bounded cell-linked storage and no global all-particle neighbor path | `BOM_INIT_CELL_GEOMETRY`, `BOM_BUILD_CELL_LIST` | P3-L01, P3-L02, P3-X01 | P3.2/P3.5 | P3.2 local path verified; final integrated scaling audit waits for P3.5 |
| P3-R07 | Exchange exact, versioned, one-stage read-only ghosts transactionally and collectively for zero/nonzero ranks | `BOM_GHOST_EXCHANGE` | P3-G01, P3-G02, P3-N04 | P3.3 | verified at P3.3 in serial/MPI2/MPI4 |
| P3-R08 | Make local and remote pair accumulation independent of slot, message and rank ordering | pair/neighbor/spring kernels | B07, B09, B17 permutation records | P3.1--P3.3 | verified through P3.3: local and remote B09/B17 exact-ID records PASS |
| P3-R09 | Implement finite SI Hooke spring velocity with equal/opposite canonical pair contributions | `BOM_SPRING_PAIR`, `BOM_SPRING_STAGE` | B07, P3-S01, P3-N05 | P3.1/P3.3 | verified through P3.3 direct laws and production spring stage |
| P3-R10 | Implement overflow-safe eBOMB stiffness and reproduce the locked Julia 200 m comparison case | `BOM_SPRING_PAIR` | B08, P3-S02, locked Julia fixture, P3-N05 | P3.1 | verified at P3.1 |
| P3-R11 | Add spring velocity to Phase 2 final drift/native rates and enforce combined advective plus spring stability guards | ensemble stage RHS | P3-I01, P3-I03, P3-N06 | P3.3 | verified at P3.3 |
| P3-R12 | Advance all interacting particles from synchronous RK stage snapshots and commit/rollback the complete substep atomically | `BOM_RK2_SPRING_ENSEMBLE`, `BOM_RK4_SPRING_ENSEMBLE` | P3-I01, P3-I02, P3-N06 | P3.3 | verified at P3.3 |
| P3-R13 | Keep owner identity fixed during stages and migrate the complete accepted Phase 3 record only after substep commit | ensemble driver, `BOM_PARTICLE_EXCHANGE` | B09, P3-M01, P3-I02 | P3.3 | verified at P3.3 with migration packet schema 2 |
| P3-R14 | Compute deterministic FINAL connected components with raft ID equal to the minimum global ID and exact size | `BOM_COMPONENTS_FINAL` | P3-RF01, P3-RF02, B17 | P3.4 | frozen |
| P3-R15 | Preserve the schema-2 core while transactionally writing/reading required schema-3 sidecars and rejecting corruption | trajectory/pickup schema-3 owners | P3-P01--P3-P04 | P3.4 | frozen |
| P3-R16 | Preserve bitwise 1/2/4-rank results for graph, spring velocity, RK state and raft fields after ID sorting | ghost/ensemble/component paths | B09, B17 | P3.3/P3.4 | P3.3 graph/spring/RK dynamics are bitwise 1/2/4-rank PASS; computed raft fields wait for P3.4 |
| P3-R17 | Fail closed on pair, cell, ghost, neighbor, component and disk capacity/corruption with no partial publication | all P3 transactional paths | P3-N03--P3-N10 | P3.1--P3.4 | pair/cell/neighbor plus P3.3 ghost/ensemble rollback PASS; component/disk groups wait for P3.4 |
| P3-R18 | Expose work/communication counters, pass fixed-density local scaling bounds and the full predecessor matrix, with no unconditional O(N-squared) production path | counters and closure driver | P3-X01, P3-X02, P3-G99 | P3.5 | P3.3 structural no-gather and complete 390/390 predecessor PASS; fixed-density performance/P3-G99 wait for P3.5 |

## 2. Reverse implementation map

| Interface or state | Requirements | Minimum evidence |
|---|---|---|
| Phase 3 parameter/code additions | P3-R01, P3-R02, P3-R17 | P3-C01, P3-N10, P3-Z01 |
| `BOM_PAIR_GEOMETRY` | P3-R03, P3-R08, P3-R17 | P3-D01, B09, P3-N03 |
| verification KNN oracle | P3-R04 | P3-K01, isolation audit |
| `BOM_INIT_CELL_GEOMETRY` / `BOM_BUILD_CELL_LIST` | P3-R05, P3-R06, P3-R18 | P3-N01/N02, P3-L01/L02, P3-X01 |
| `BOM_GHOST_EXCHANGE` and ghost state | P3-R07, P3-R08, P3-R16, P3-R17 | P3-G01/G02, B09/B17, P3-N04 |
| `BOM_SPRING_PAIR` / `BOM_SPRING_STAGE` | P3-R08--P3-R11 | B07/B08, P3-S01/S02, P3-N05 |
| ensemble RK2/RK4 | P3-R11--P3-R13, P3-R16--P3-R17 | P3-I01--I03, P3-M01, B09/B17, P3-N06 |
| `BOM_COMPONENTS_FINAL` | P3-R14, P3-R16--P3-R17 | P3-RF01/RF02, B17, P3-N07 |
| Phase 3 owner state and migration packet | P3-R13--P3-R17 | P3-M01, P3-P01/P02, B17 |
| schema-3 trajectory/pickup sidecar | P3-R01, P3-R15--P3-R17 | P3-P01--P3-P04, P3-N08/N09 |
| performance/work counters | P3-R06, P3-R18 | P3-X01/X02 |
| P3-G99 closure driver | P3-R01--P3-R18 | all direct rows plus exact predecessor groups |

## 3. Evidence semantics

- `frozen` means P3.0 has fixed the contract; it does not mean production is
  implemented.
- `P3.1/P3.2/P3.3 portion PASS` records bounded evidence without closing later package
  obligations named in the same requirement.
- `verified` may be written only with an immutable source head, external
  evidence root, expected/actual row audit and manifest hash.
- Expected failures require the stable failure, RK stage and P3 phase code,
  plus proof that authoritative state and schedules did not change.
- A serial result cannot close an MPI/decomposition requirement.
- A pair-law unit test cannot close ensemble-RK transaction or schema work.
- Timing without work counters cannot close P3-R18.

## 4. Work-package closure map

| Package | Requirements that may close | Required accepted predecessor |
|---|---|---|
| P3.1 | P3-R02--P3-R04, P3-R09--P3-R10 portions; P3-R01 focused zero-impact | v0.3 390-row release evidence |
| P3.2 | P3-R05--P3-R06 and local portions of P3-R08/R17/R18 | accepted P3.1 |
| P3.3 | P3-R07--P3-R13 and distributed portions of P3-R16/R17 | accepted P3.1/P3.2 |
| P3.4 | P3-R14--P3-R17 | accepted P3.1--P3.3 |
| P3.5 | P3-R01 and P3-R18 final; complete P3-R01--P3-R18 audit | accepted P3.1--P3.4 |

## 5. Phase 3 exit requirement

Phase 3 cannot close until every P3-R01--P3-R18 row is `verified`, B07--B09
and B17 pass in their full required matrix, P3-G99 reruns every registered
predecessor group, schema-3 restart is accepted, and the production source/link
audit proves that no verification all-pairs oracle is reachable from the
MITgcm executable.
