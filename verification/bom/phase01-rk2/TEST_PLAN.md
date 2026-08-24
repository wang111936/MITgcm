# P1.3 stateless RK2 test plan

## Scope

This gate closes the RK2 component portion of P1-R09, P1-I05, and the
stage/final rollback subset of P1-N08. It does not claim acceptance of
release handling, caller-level commit, RK4, or cross-owner migration.

## Functional matrix

| Test | Grid/build | Assertion |
|---|---|---|
| RK2 zero | Cartesian serial/MPI4 | zero RHS preserves position bitwise; final diagnostics are zero |
| RK2 constant | Cartesian serial/MPI4 | explicit midpoint reproduces analytic constant displacement and FINAL-position diagnostics |
| P1-I05 | Cartesian serial | frozen affine C-grid field, `T/4` through `T/32`; the two finest observed orders are each in `[1.8,2.2]` |
| P1-N08 RK2 | Cartesian serial debug | invalid input, K1 failure, K2 owner departure, FINAL owner departure, and midpoint overflow return stable first-failure stage/code, roll back `x1/y1`, and do not modify particle sentinels |

## Structural assertions

- production RK2 performs exactly three full RHS calls: K1, K2, and FINAL;
- midpoint and final coordinates each use overflow-safe updates in both
  components;
- RK2 and its helper contain no authoritative particle-state assignment;
- production code contains no verification routine or test marker;
- serial/MPI4 executables link the production RK2, helper, RHS, and verifier;
- the Julia reference is clean and exactly at commit
  `156557359185e4413ce82829f3ed26a4eb8c6283`.

All Fortran builds use `genmake2 -ieee -devel`, bounds checking, initialized
real traps, and invalid/zero/overflow floating-point traps.
