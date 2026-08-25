# P2.1 endpoint-state and transaction test plan

| ID | Configuration | Expected result |
|---|---|---|
| P21-C01 | GNU debug, serial, no EXF | compile and link |
| P21-C02 | GNU debug, MPI, no EXF | compile and link |
| P21-C03 | GNU debug production lifecycle, serial | compile and link without test override |
| P21-C04 | GNU debug, serial, EXF+BOM | compile/link with exact-time provider symbols |
| P21-C05 | GNU debug, MPI4, EXF+BOM | compile/link with exact-time provider symbols |
| P21-C06 | GNU debug EXF+BOM production lifecycle | compile/link without test override |
| P21-S01 | `BOM`, ocean/NONE/NONE, serial | fresh and normal transaction pass |
| P21-S02 | same as S01, four MPI ranks | endpoint, halo and rollback assertions pass |
| P21-S03 | production fresh plus one normal step | normal end; both lifecycle hooks execute |
| P21-R01 | broken time/iteration continuity | `FIELD_TIME/FIELD_OLD`; accepted state unchanged |
| P21-R02 | unavailable wind component | `FIELD_SOURCE/FIELD_NEW`; accepted state unchanged |
| P2-E03 | 1800 s EXF records, 1200 s endpoints, serial/MPI4 | independent exact values; globals bitwise unchanged |
| P2-N03 | missing/unpaired/partial/future/stale/NaN EXF wind | `FIELD_SOURCE/FIELD_NEW`; accepted bracket bitwise unchanged |
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
checks an independent exact-time oracle, and proves both EXF global immutability
and accepted-state rollback for every P2-N03 EXF failure row.

This increment intentionally does not claim P2.1 completion. Nonzero
`bomMode='BOM'` remains rejected until the inertial RHS is connected. EXF
wind is accepted only through the exact-time provider; FILES/COUPLER Stokes,
stage-time interpolation and field pickup remain later P2.1 work. No
derivative or slow-manifold RHS test belongs in this gate.
