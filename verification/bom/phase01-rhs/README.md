# P1.3 Leeway RHS component gate

This directory verifies the second P1.3 production increment: the stateless
`BOM_RHS_LEEWAY` kernel, stable failure/stage codes, SI Leeway composition,
native-coordinate rate conversion, nearest-C metric selection, and stage CFL.

The increment deliberately does not implement Runge--Kutta integration,
release-time transitions, authoritative particle motion, state-budget checks,
or owner migration. Those remain later P1.3/P1.4 increments.

## Gate structure

- `code/bom_verify_rhs.F` runs component assertions after grid and package
  initialization without replacing the production RHS, mapping, interpolation,
  field builder, or EXF routines;
- `code/packages.conf` builds the no-EXF component variants;
- `code/packages.exf.conf` builds the end-to-end EXF variants;
- `input/data.cartesian` and `input/data.spherical` exercise native-coordinate
  conversions on the validated P1.2 regular grids;
- `julia_rhs_smoke.jl` checks the locked SargassumBOMB 0.7.14 algebra and the
  `1 m/s = 86.4 km/day` conversion;
- `run_rhs_gate.sh` creates fresh serial/MPI4 debug builds, executes the matrix,
  and writes checksummed evidence outside the source repository.

Run from the repository root:

```bash
bash verification/bom/phase01-rhs/run_rhs_gate.sh
```

The default external roots are:

```text
/home/wyl/build/mitgcm-bom/phase01-single-tile/<test-id>/
/home/wyl/runs/mitgcm-bom/phase01-single-tile/<test-id>/
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/<test-id>/
```

The gate is expected to report 15 PASS rows: two source/reference contracts,
four builds, eight Fortran runs, and one locked Julia run.
