# MITGCM-BOM P1.2 surface-field gate

This directory verifies the P1.2 construction of frozen step-end surface
velocity fields before wet-pair interpolation is implemented.

Current coverage:

- `P1-F01`: uniform surface C-grid U/V, deterministic zero initialization,
  zero-particle `BOM_MAIN`, single-level publication metadata, and serial/MPI4
  scalar halos;
- `P1-F02`: nonuniform face fields, explicit C-grid colocation, a 90-degree
  artificial rotation, dry-cell masking, deliberately inconsistent local
  halo angles, and serial/MPI4 scalar exchange.

Both builds use `Nr=2` while `BOM_BUILD_FIELDS` passes `kSize=1` to the real
`ROTATE_UV2EN_RL`.  This catches accidental use of the model vertical stride
for the frozen single-level arrays.

The verification-only `bom_init_varia.F` injects synthetic fields after the
MITgcm grid and dynamic state exist.  It calls production `BOM_MAIN` and
`BOM_BUILD_FIELDS`, restores the zero-step model state, and never enters the
repository's production package.

Run from any directory:

```bash
verification/bom/phase01-fields/run_field_gate.sh
```

Fresh build and run evidence is written outside the repository under
`/home/wyl/{build,runs}/mitgcm-bom/phase01-fields/<test-id>`.
