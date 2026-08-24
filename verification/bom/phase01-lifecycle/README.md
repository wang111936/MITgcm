# P1.3 production lifecycle gate

This directory verifies the fifth P1.3 production increment: equal nominal
substeps, exact release-time splitting, stateless status/age candidates,
per-particle transactional `BOM_MAIN` commits, and the complete compact-state
budget enforced by `BOM_CHECK_STATE`.

The gate exercises both accepted integrators. It also uses an MPI4 layout to
verify exact 64-bit ID uniqueness across ranks, including low words on both
sides of the signed 32-bit boundary. Expected-failure runs prove that age
overflow, duplicate IDs, owner-budget mismatch, non-compact tails, invalid
statuses, and owner departure terminate before an invalid authoritative
commit.

Owner migration is deliberately outside this gate and remains P1.4 scope.

Run from the repository root:

```bash
bash verification/bom/phase01-lifecycle/run_lifecycle_gate.sh
```

The gate is expected to report 13 PASS rows: one source contract, two
GNU debug/IEEE builds, four positive production runs, and six negative
production runs.
