# P3.4 components and schema-3 test results

Decision: **FUNCTIONAL IMPLEMENTATION COMPLETE; CLEAN-HEAD EVIDENCE PENDING**

Branch: `MITGCM-BOM/p3.4-components-schema3`

Environment: Ubuntu 22.04 under WSL2, GNU Fortran 11.4.0 debug/IEEE/bounds
builds and Open MPI 4.1.2. Evidence is stored outside the source repository.

## Development verification

- connected-component direct fixtures passed in serial, MPI2 and MPI4;
- Hooke/eBOMB schema-3 write, same-decomposition restart and bitwise comparison
  passed in serial, MPI2 and MPI4;
- canonical component and schema sidecar records matched bitwise across 1/2/4
  ranks;
- all 14 signature/header/field/length/order corruption cases failed with code
  25 before accepted-state publication;
- spring-law mismatch failed with code 25 and changed decomposition failed in
  the preserved Phase-2 signature check with code 15.

The final clean committed-head P3.4 42/42 gate and mandatory accepted P3.3,
P3.2, P3.1 and Phase-2 regressions will be recorded here after execution.

## Reproduction

```bash
MITGCM_BOM_EXPECTED_HEAD="$(git rev-parse HEAD)" \
  verification/bom/phase03-components-schema3/run_components_schema3_gate.sh
```

This work package does not authorize Phase 3 exit, merge, or creation of the
`MITGCM-BOM-v0.4` tag.
