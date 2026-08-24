# P1.3 production lifecycle test plan

## Scope

This gate closes P1-S04b and the caller/state-budget portion of P1-N08. It
tests the production `BOM_MAIN`, `BOM_RELEASE_STEP`, `BOM_SUBSTEP_SETUP`,
`BOM_SUBSTEP_BOUNDS`, and `BOM_CHECK_STATE` path. P1.4 migration, Phase-1
output, and pickup/restart are not claimed here.

## Positive matrix

| Test | Build | Assertion |
|---|---|---|
| P1-S04b RK2 | serial | `[0,1200]` is split into four equal substeps; ALIVE, future WAITING, release-at-boundary, release-inside, and release-at-final-end records have exact displacement, status, age, and final diagnostics |
| P1-S04b RK4 | serial | same frozen release matrix through the RK4 caller path |
| P1-I01 lifecycle | serial | exactly zero frozen RHS preserves ALIVE and WAITING positions bitwise while status and age follow the release contract |
| lifecycle MPI4 | four ranks | one stationary ALIVE owner per rank preserves position and ID, advances age exactly, and passes the owner/ID budget at start and every substep |

The serial verifier also calls the stateless helper directly for release at
start, inside, at end, and after an interval; it checks the forced final
endpoint and the age-overflow guard.

## P1-N08 negative matrix

| Test | Build | Required first failure |
|---|---|---|
| age overflow | serial | `BOM_FAIL_NONFINITE`, stage NONE, before slot commit |
| duplicate ID | MPI4 | exact duplicate high/low 32-bit word pair |
| owner count | serial | global owner count differs from immutable expected budget |
| compact tail | serial | a slot above `bomNPartTile` is not `UNUSED/id=0` |
| invalid status | serial | status is outside ALIVE/WAITING |
| owner departure | serial RK4 | K4 trial returns `BOM_STAGE_K4/BOM_FAIL_OWNER` |

## Structural assertions

- substep count is `ceil(deltaTClock/bomDeltaTTarget)` and the last endpoint
  is forced to the authoritative step end;
- `BOM_MAIN` invokes the stateless release helper and budgets the state at
  step start, optional substeps, and step end;
- waiting releases and zero-active-time endpoint releases remain distinct;
- age addition is overflow guarded;
- global IDs are gathered as two integer words, sorted, and compared exactly;
- compact tails and immutable owner count are checked;
- no verifier marker or P1.4 migration call appears in production P1.3 code.

All builds use `genmake2 -ieee -devel` with the repository GNU Fortran debug
options. Evidence is written outside the source repository with SHA-256
checksums.
