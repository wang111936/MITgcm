# MITGCM-BOM P2.2 derivative verification

This isolated verification case covers the first P2.2 production increment:

- P2-D01 Cartesian constant and affine gradients on the actual nonuniform C grid;
- P2-D02 centered and permitted one-sided three-point second-order formulas;
- P2-D03 bitwise-equal sorted interior gradients for serial four-tile and four-rank decompositions;
- Cartesian P2-N05 insufficient stencil, zero metric, NaN metric, and rollback.

The convergence oracle also checks quadratic exactness conceptually and uses a cubic manufactured field to produce a nonzero second-order truncation error; a quadratic polynomial alone is exactly differentiated by a three-point Lagrange formula and therefore cannot yield a meaningful observed order.

Run with:

```bash
verification/bom/phase02-derivatives/run_derivative_gate.sh
```
