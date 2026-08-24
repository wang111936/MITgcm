# P1.3 stateless RK2 component gate

This directory verifies the third P1.3 production increment: the stateless
explicit-midpoint `BOM_RK2` kernel and its overflow-safe coordinate helper.
Every K1, K2, and FINAL evaluation uses the accepted production
`BOM_RHS_LEEWAY`.

This increment does not implement RK4, release-time transitions,
`BOM_MAIN` particle motion, authoritative particle commits, or owner
migration.

## Gate structure

- `code/bom_verify_rk2.F` runs zero-field, constant-field, affine
  convergence, stage/final failure, and rollback assertions;
- `julia_rk2_smoke.jl` supplies an independent explicit-midpoint oracle in
  the locked SargassumBOMB 0.7.14 environment;
- `run_rk2_gate.sh` creates fresh serial/MPI4 GNU debug/IEEE builds and
  checksummed evidence outside the source repository.

Run from the repository root:

```bash
bash verification/bom/phase01-rk2/run_rk2_gate.sh
```

The gate is expected to report 11 PASS rows: two source/reference contracts,
two builds, six Fortran runs, and one Julia oracle.
