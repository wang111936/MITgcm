# P2.1 endpoint-state and transaction test plan

| ID | Configuration | Expected result |
|---|---|---|
| P21-C01 | GNU debug, serial, no EXF | compile and link |
| P21-C02 | GNU debug, MPI, no EXF | compile and link |
| P21-C03 | GNU debug production lifecycle, serial | compile and link without test override |
| P21-C04 | GNU debug, serial, EXF+BOM | compile/link with exact-time provider symbols |
| P21-C05 | GNU debug, MPI4, EXF+BOM | compile/link with exact-time provider symbols |
| P21-C06 | GNU debug EXF+BOM production lifecycle | compile/link without test override |
| P21-C07 | GNU debug, serial, compiled COUPLER+BOM | compile/link with setter/provider symbols |
| P21-C08 | GNU debug, MPI4, compiled COUPLER+BOM | compile/link with setter/provider symbols |
| P21-C09 | GNU debug compiled COUPLER production lifecycle | compile/link without test override |
| P21-S01 | `BOM`, ocean/NONE/NONE, serial | fresh and normal transaction pass |
| P21-S02 | same as S01, four MPI ranks | endpoint, halo and rollback assertions pass |
| P21-S03 | production fresh plus one normal step | normal end; both lifecycle hooks execute |
| P21-R01 | broken time/iteration continuity | `FIELD_TIME/FIELD_OLD`; accepted state unchanged |
| P21-R02 | unavailable wind component | `FIELD_SOURCE/FIELD_NEW`; accepted state unchanged |
| P2-E03 | 1800 s EXF records, 1200 s endpoints, serial/MPI4 | independent exact values; globals bitwise unchanged |
| P2-E04 | FILES Stokes exact/repeat endpoints, serial/MPI4 | independent scaled/rotated values and exact dry mask |
| P2-E05 | compiled COUPLER fresh/normal pairs, serial/MPI4 | copied values, exact labels, no alias and sigma policy rows |
| P2-E06 | accepted OLD/NEW stage-time interpolation, serial/MPI4 | exact snaps, linear interior values and constant secants |
| P2-N02 | non-finite/reversed/discontinuous brackets or outside stage | endpoint-specific `FIELD_TIME`; no clamp or extrapolation |
| P2-N03 | EXF/FILES/COUPLER missing, partial, future, stale or non-finite | `FIELD_SOURCE/FIELD_NEW`; accepted bracket bitwise unchanged |
| P2-N04 | NONE/sigma and PRECOMBINED/explicit source matrix | illegal rows rejected before endpoint publication |
| P21-Z01 | Phase-1 `LEEW` defaults with new state present | normal end; no BOM-only policy rejection |
| P21-N01 | `bomCurrentPolicy='UNSET'` | fatal before state initialization |
| P21-N02 | non-finite `bomAlpha` | fatal finite-value check |
| P21-N03 | overflowing `bomTauDays` | fatal before multiplication |
| P21-N04 | `NONE` Stokes with nonzero sigma | fatal de-dup/source-policy check |
| P21-N05 | `PRECOMBINED` plus `FILES` | fatal duplicate-Stokes declaration |
| P21-N06 | invalid FILES precision/metadata | fatal metadata preflight |
| P21-N07 | unavailable `COUPLER` hook | fatal provider-availability check |

The positive test-only initialization hook calls the production
`BOM_INIT_STATE`, then checks every local tile, halo point, endpoint, and
source. It then calls the production try-transaction for fresh, consecutive
normal, continuity failure, source failure, and successful recovery. A
separate build runs the unmodified production lifecycle for one ocean step.
The EXF variant evaluates paired model-grid wind records in BOM-owned arrays,
The FILES variant preflights paired records and checks exact interpolation,
repeat-cycle, scaling, rotation and rollback. The compiled COUPLER variant
publishes components independently, mutates producer buffers after the setter,
and tests exact labels, component completeness, invalid-field rejection and
transactional recovery.
checks an independent exact-time oracle, and proves both EXF global immutability
and accepted-state rollback for every P2-N03 EXF failure row.

This increment intentionally does not claim P2.1 completion. Nonzero
`bomMode='BOM'` remains rejected until the inertial RHS is connected. EXF
wind and explicit Stokes use exact-time endpoint providers; schema-2 field
pickup remains later P2.1 work. No spatial-derivative
or slow-manifold RHS test belongs in this gate.
