# MITGCM-BOM P1.2 wet-pair interpolation gate

This directory verifies the final P1.2 environmental-field operation:
deterministic, mask-aware interpolation of a C-point east/north pair with one
shared normalized set of wet weights.

Coverage:

- `P1-F03 FULL`: constant preservation in a negative fractional overlap and
  analytic interpolation of fully wet affine fields;
- `P1-F03 PARTIAL`: exact-threshold acceptance, dry-value exclusion, and one
  normalized weight set shared by east and north;
- `P1-N05`: unpublished fields, missing low/high stencils, non-finite
  coordinates or pair fields, insufficient wet weight, and invalid tile
  indices return invalid with zero velocity values.

The driver reuses the already verified P1-F01/P1-F02 zero-step inputs and
serial/MPI4 layouts.  Production state is restored after every focused test.

Run from any directory:

```bash
verification/bom/phase01-interp/run_interp_gate.sh
```

Fresh evidence is written outside the repository under
`/home/wyl/{build,runs}/mitgcm-bom/phase01-interp/<test-id>`.
