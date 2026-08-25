# P1.3 Leeway RHS test plan

## Scope

The gate closes the component-level portion of P1-R08, the RHS portion of
P1-R09, and the RHS numerical-safety subset of P1-R16. It does not claim that
P1.3 particle integration or the full P1-N08 state/release budget is complete.

## Functional matrix

| Test | Grid/build | Assertion |
|---|---|---|
| P1-I01 | Cartesian serial/MPI4, no EXF | zero ocean and wind return bitwise-zero rates and CFL |
| P1-I02 | Cartesian serial/MPI4, no EXF | constant SI ocean velocity equals native m/s rate; analytic CFL agrees |
| P1-I03 | spherical serial, no EXF | pure east and pure north m/s convert to degree/s using runtime `rSphere`, `deg2rad`, and nonzero latitude |
| P1-I04 | Cartesian serial/MPI4 with EXF | constant EXF wind passes through production `BOM_BUILD_FIELDS`; RHS returns water plus `bomLeewayWindCoeff*wind`; locked Julia algebra and km/day conversion agree |
| P1-N08 RHS | Cartesian serial debug | stable first-failure codes for bad `dtGuard`, global map, owner departure, unpublished/non-finite fields, drift overflow, invalid metric, exact half-cell metric tie, and CFL excess; particle sentinels remain unchanged |

## Structural assertions

- `BOM_RHS_LEEWAY` contains no assignment to authoritative particle state;
- numeric `BOM_FAIL_*` and `BOM_STAGE_*` values match the frozen interface;
- production code contains no verification routine or test marker;
- serial/MPI4 executables link the production RHS and interpolation symbols;
- the Julia source checkout is clean and exactly at commit
  `156557359185e4413ce82829f3ed26a4eb8c6283`;
- the locked Julia `Leeway!` source still uses water plus alpha times wind in
  both components.

## Numerical safety

All Fortran builds use `genmake2 -ieee -devel`, GNU bounds checking, initialized
real traps, and invalid/zero/overflow floating-point traps. Expected failures
are returned as component results rather than process signals. The caller-level
collective abort and transactional particle commit remain a later P1.3 gate.
