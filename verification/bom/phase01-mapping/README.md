# MITGCM-BOM P1.2 mapping gate

This directory owns the first executable increment of the P1.2 mapping and
environment-field work package.  It tests production mapping routines before
the P1.1 initial locator is changed.

Current coverage:

- `P1-M01`: regular Cartesian interior, face, shared corner, negative
  fractional overlap, mathematical-floor stencil logic, and inverse mapping;
- `P1-M02`: complete 360-degree spherical normalization, equivalent
  longitudes, regional non-wrapping behavior, nonzero latitude, half-open
  upper bounds, unique owner, and inverse mapping;
- `P1-N04`: explicit rejection of rotated, curvilinear, pressure-coordinate,
  non-positive-spacing, inconsistent-bound, OpenMP, and actual EXCH2 builds.

The test-only `bom_init_fixed.F` is a verification mod.  It injects named
invalid states only after MITgcm has constructed a valid grid.  The gate
audits that no verification symbol or scenario marker appears in production
`pkg/bom`.

Run from any directory:

```bash
verification/bom/phase01-mapping/run_mapping_gate.sh
```

Build and run evidence is written outside the repository under new test-ID
directories in `/home/wyl/build/mitgcm-bom/phase01-mapping` and
`/home/wyl/runs/mitgcm-bom/phase01-mapping`.
