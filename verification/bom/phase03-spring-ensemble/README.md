# P3.3 versioned ghost and spring ensemble integration

This gate implements the P3.3 work-package frozen in
`verification/bom/phase03-springs-neighbors/P3.0_INTERFACE_FREEZE.md`.

Production scope:

- version-1 transactional ghost exchange with exact IDs and one-stage lifetime;
- exact cross-tile/cross-rank cutoff inputs and ID-ordered spring accumulation;
- synchronized all-owner RK2/RK4 stages with combined Phase-2 RHS/CFL checks;
- nominal-substep rollback and a single post-commit owner migration;
- version-2 migration packets carrying spring, neighbor and reserved raft fields.

P3.4 remains responsible for connected-component computation, raft publication,
and trajectory/pickup schema 3. Spring-enabled output/pickup is therefore
fail-closed until P3.4; `bomSpringLaw='NONE'` retains the accepted v0.3 path.

Run the exact-head gate with:

```bash
MITGCM_BOM_EXPECTED_HEAD="$(git rev-parse HEAD)" \
verification/bom/phase03-spring-ensemble/run_spring_ensemble_gate.sh
```

The gate builds and runs serial, MPI2 and MPI4 layouts, requires 34/34 rows,
and compares canonical B17 dynamics bitwise after sorting by exact particle ID.
