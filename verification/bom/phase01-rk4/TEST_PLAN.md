# P1.3 stateless RK4 test plan

## Scope

This gate closes the RK4 component portion of P1-R09, P1-I06, and the
K1--K4/final rollback subset of P1-N08. It does not claim acceptance of
release handling, caller-level commit, or cross-owner migration.

## Functional matrix

| Test | Grid/build | Assertion |
|---|---|---|
| RK4 zero | Cartesian serial/MPI4 | zero RHS preserves position bitwise; normalized extreme-rate cancellation remains finite; final diagnostics are zero |
| RK4 constant | Cartesian serial/MPI4 | classical RK4 reproduces analytic constant displacement and FINAL-position diagnostics |
| P1-I06 | Cartesian serial | frozen affine C-grid field, `T/4` through `T/32`; the two finest observed orders are each in `[3.5,4.5]` |
| P1-N08 RK4 | Cartesian serial debug | invalid input, K1 field failure, K2/K3/K4/FINAL owner departure, and K2 coordinate overflow return stable first-failure stage/code, roll back `x1/y1`, and do not modify particle sentinels |

## Structural assertions

- production RK4 performs exactly five full RHS calls: K1--K4 and FINAL;
- all K2--K4 stage coordinates and both weighted final coordinates use
  overflow-safe updates;
- RK4 and both helpers contain no authoritative particle-state assignment;
- production code contains no verification routine or test marker;
- serial/MPI4 executables link production RK4, both helpers, RHS, and verifier;
- the Julia reference is clean and exactly at commit
  `156557359185e4413ce82829f3ed26a4eb8c6283`.

All Fortran builds use `genmake2 -ieee -devel`, bounds checking, initialized
real traps, and invalid/zero/overflow floating-point traps.
