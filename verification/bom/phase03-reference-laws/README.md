# MITGCM-BOM P3.1 reference geometry and spring laws

This isolated work package implements the first executable increment of the
frozen Phase 3 design in
[`../phase03-springs-neighbors/P3.0_INTERFACE_FREEZE.md`](../phase03-springs-neighbors/P3.0_INTERFACE_FREEZE.md).

## Production scope

- append the frozen spring/neighbor parameters, defaults, stable failures
  16--25 and Phase 3 operation phases 0--9;
- reject invalid spring configurations in `BOM_CHECK` before particle-state
  initialization, including a non-unique periodic cutoff;
- provide canonical low-ID-to-high-ID Cartesian, spherical midpoint-metric and
  periodic-X pair geometry with overflow-safe distance and transactional
  numeric outputs;
- provide stateless Hooke/eBOMB low-endpoint spring velocity and transactional
  finite-checked accumulation;
- preserve the exact Phase 2 production dispatcher when springs are `NONE`.

The eBOMB logistic uses its mathematically equivalent sign-stable branches and
clamps exponential arguments beyond the representable tail to their exact
floating-point limit. This avoids overflow and underflow status flags while
retaining the frozen SI law.

## Verification-only references

The K-nearest-neighbor oracle and locked Julia scripts remain under
`../phase03-springs-neighbors/reference/`. They are never called or linked by
`pkg/bom`.

- K means exactly K non-self neighbors sorted by `(distance,globalId)`;
- K clamps to `N-1`, `N<2` rejects, and odd/even medians are explicit;
- slot permutations must return identical ID-sorted records;
- the literal Julia `DeltaL` self-count convention is retained separately;
- the 200 m eBOMB case executes the locked Julia `BOMBSpring` and compares its
  value with the stable Fortran kernel at the frozen normalized tolerance.

## Direct gate

Run from the repository root:

```bash
MITGCM_BOM_EXPECTED_HEAD="$(git rev-parse HEAD)" \
  verification/bom/phase03-reference-laws/run_reference_law_gate.sh
```

The gate creates unique external build, run and artifact roots and covers:

- serial and MPI4 GNU debug/IEEE builds and required symbols;
- P3-Z01 scope/NONE-dispatch isolation;
- P3-C01 defaults, schema/code stability, two accepted SI namelists and 14
  fail-before-state configurations;
- P3-K01 line, square/clamp, tie, periodic-X, spherical and rejection fixtures;
- P3-D01 canonical geometry plus P3-N03 sentinel rollback;
- B07/P3-S01 Hooke signs, equal/opposite centre and RK2/RK4 convergence;
- B08/P3-S02 stable eBOMB, locked Julia comparison and P3-N05 rollback;
- four bitwise-identical sorted serial/MPI4 records.

The exact Phase 2 390-row closure remains a mandatory predecessor regression
for the accepted P3.1 functional head. Run it through the P3.1 scope wrapper:

```bash
MITGCM_BOM_EXPECTED_HEAD="$(git rev-parse HEAD)" \
  verification/bom/phase03-reference-laws/run_phase2_regression_gate.sh
```

The wrapper reuses the unchanged Phase 2 drivers and expected row counts. It
selects a P3.1-only independent audit whose production whitelist is limited to
the six files listed by the direct gate; the original P2.5 audit remains the
default when the historical closure is invoked directly.

## Deliberate boundary

P3.1 does not introduce the production cell list, cutoff graph, ghost exchange,
spring-aware ensemble RK, components, diagnostics sidecars or schema 3. A live
nonzero-particle spring run therefore fails closed until the P3.3 ensemble path
exists. P3.2 starts only after this package is reviewed and integrated.
