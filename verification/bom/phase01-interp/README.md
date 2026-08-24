# MITGCM-BOM P1.2 wet-pair interpolation gate

This directory verifies the final P1.2 environmental-field operation:
deterministic, mask-aware interpolation of a C-point east/north pair with one
shared normalized set of wet weights.

Current component-regression coverage:

- `P1-F03 FULL`: constant preservation in a negative fractional overlap and
  analytic interpolation of fully wet affine fields;
- `P1-F03 PARTIAL`: exact-threshold acceptance, dry-value exclusion, and one
  normalized weight set shared by east and north;
- `P1-N05`: unpublished fields, missing low/high stencils, non-finite
  coordinates or pair fields, insufficient wet weight, and invalid tile
  indices return invalid with zero velocity values;
- the P1.3 state-budget consumer still maps every compact owner record and
  validates the same shared wet-pair interpolation before commit.

The original P1.2 `BOM_MAIN` fixture froze a diagnostic-only, non-moving
caller. P1.3 deliberately replaces that caller with release-aware motion and
transactional state updates. Those superseded caller cases are preserved in
the immutable P1.2 results, while current caller behavior and its negative
matrix are verified by `phase01-lifecycle`.

The driver reuses the already verified P1-F01/P1-F02 zero-step inputs and
serial/MPI4 layouts.  Production state is restored after every focused test.

Run from any directory:

```bash
verification/bom/phase01-interp/run_interp_gate.sh
```

The current gate reports 9 PASS rows: one source contract, two builds, and
six direct serial/MPI4 component runs. Fresh evidence is written under
`/home/wyl/{build,runs}/mitgcm-bom/phase01-interp/<test-id>`.
