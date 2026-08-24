# MITGCM-BOM P1.3 setup increment gate

This directory verifies the first production increment in the frozen P1.3
single-tile implementation order.  The increment is deliberately limited to:

- trap-safe numerical preflight for the model clock, target particle step,
  derived fixed-substep count and size, output controls, wind coefficient,
  wet-weight threshold, and CFL control;
- deterministic initialization and successful-input publication of the
  immutable `bomNPartExpected` owner budget;
- BOM-owned frozen wind arrays plus their independent request-time metadata;
- `NONE` and EXF 10 m east/north wind snapshots, including compile/runtime
  dependency rejection and read-only treatment of the EXF source fields.

The verification-only `code/bom_init_varia.F` initializes constant EXF wind,
calls the production field builder, and checks publication order, masks,
halos, metadata, and source immutability.  It is injected through the case
mods directory and does not add a production runtime test hook.

Run from any directory with a fresh test identifier:

```bash
MITGCM_BOM_TEST_ID=<unique-p13-id> \
  verification/bom/phase01-setup/run_setup_gate.sh
```

Builds, runs, and compact evidence remain outside Git under:

- `/home/wyl/build/mitgcm-bom/phase01-single-tile/<test-id>`;
- `/home/wyl/runs/mitgcm-bom/phase01-single-tile/<test-id>`;
- `/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/<test-id>`.

This increment does not implement the Leeway RHS, coordinate-rate conversion,
stage validation, release-time splitting, RK2/RK4 motion, owner migration,
trajectory output, pickup/restart, or FLT coexistence.  The PR remains Draft
until the later P1.3 increments, full lifecycle budget check, complete
regression matrix, and final review are finished.
