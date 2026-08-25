# P2.1 first-increment test plan

| ID | Configuration | Expected result |
|---|---|---|
| P21-C01 | GNU debug, serial, no EXF | compile and link |
| P21-C02 | GNU debug, MPI, no EXF | compile and link |
| P21-S01 | `BOM`, Eulerian current, no Stokes, serial | parameter conversion and endpoint initialization pass |
| P21-S02 | same as S01, four MPI ranks | identical global assertion result |
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
source. It also checks the immutable integer values frozen in P2.0.

This increment intentionally does not claim P2.1 completion. Nonzero
`bomMode='BOM'` remains rejected until exact-time ocean, wind, and Stokes
providers and the no-partial-commit transaction are connected later in
P2.1. No derivative or slow-manifold RHS test belongs in this gate.
