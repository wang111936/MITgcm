# P1.3 stateless RK4 component gate

This directory verifies the fourth P1.3 production increment: the stateless
classical `BOM_RK4` kernel, its exponent-scaled stage-coordinate helper, and
its normalized weighted-final-coordinate helper. Every K1, K2, K3, K4, and
FINAL evaluation uses the accepted production `BOM_RHS_LEEWAY`.

This increment does not implement release-time transitions, `BOM_MAIN`
particle motion, authoritative particle commits, or owner migration.

## Gate structure

- `code/bom_verify_rk4.F` runs zero-field, constant-field, affine
  convergence, stage/final failure, and rollback assertions;
- `julia_rk4_smoke.jl` supplies an independent classical-RK4 oracle in
  the locked SargassumBOMB 0.7.14 environment;
- `run_rk4_gate.sh` creates fresh serial/MPI4 GNU debug/IEEE builds and
  checksummed evidence outside the source repository.

Run from the repository root:

```bash
bash verification/bom/phase01-rk4/run_rk4_gate.sh
```

The gate is expected to report 11 PASS rows: two source/reference contracts,
two builds, six Fortran runs, and one Julia oracle.
