# MITGCM-BOM P2.2 derivative verification

This isolated verification case covers the complete P2.2 production operator:

- P2-D01 Cartesian constant and affine gradients on the actual nonuniform C
  grid;
- P2-D02 quadratic exactness plus centered and permitted one-sided cubic
  second-order convergence;
- P2-D03 bitwise-equal sorted Cartesian interior records for serial four-tile
  and four-rank decompositions;
- P2-D04 spherical physical east/north gradients and
  `tauSphere=tan(latitude)/rSphere` at multiple latitudes;
- P2-D05 MITgcm C-point `fCori`, finite-checked covariant terms, and separate
  PAPER total-field and JULIA base-only vorticity candidates;
- complete P2-N05 insufficient stencil, zero/NaN metric, invalid radius,
  near-pole, nonfinite `fCori`, arithmetic overflow, and transactional
  rollback.

A three-point Lagrange derivative is exact for a quadratic polynomial, so the
convergence oracle uses a cubic manufactured field to produce the nonzero
truncation error needed for an observed-order assertion.

Run with:

```bash
verification/bom/phase02-derivatives/run_derivative_gate.sh
```

The exact-head closure result is recorded in `TEST_RESULTS.md`. P2.2 provides
the stateless operator candidates; selecting those candidates inside the full
`PAPER2024` and `JULIA` RHS paths remains P2.3 scope.
