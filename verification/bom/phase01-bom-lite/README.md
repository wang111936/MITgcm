# MITGCM-BOM Phase 1.1 state gate

This directory contains the source-controlled P1.1 state and initial-file verification. It is deliberately independent of build trees and runtime output.

## Scope

- compact per-tile owner SoA and deterministic reset;
- schema 1 MDS initial-particle files;
- exact positive 64-bit IDs encoded as unsigned high/low 32-bit words;
- bounded initial owner selection on regular Cartesian or unrotated spherical-polar grids;
- input finite-value, uniqueness, state, release-time, wet-cell, count, and capacity checks;
- serial, MPI2, MPI4, GNU debug, zero-impact, and negative gates.

It does not implement environmental-field construction, general stage-time mapping, interpolation, particle motion, owner exchange, trajectory output, or pickup.

## Run

```bash
cd /home/wyl/projects/mitgcm-bom
MITGCM_BOM_TEST_ID=<unique-id> \
  verification/bom/phase01-bom-lite/run_state_gate.sh
```

The driver refuses to reuse build or run roots. Defaults are:

```text
/home/wyl/build/mitgcm-bom/phase01-state/<test-id>
/home/wyl/runs/mitgcm-bom/phase01-state/<test-id>
```

`make_initial.py` writes deterministic big-endian float64 MDS records using only the Python standard library. The authoritative local result is documented in `TEST_RESULTS.md`; raw binaries, executables, and logs remain outside Git.

## Audits

- `P1.1_SCOPE_AUDIT.md` records the accepted P1.1 boundary and evidence.
- `P1.2_INTERFACE_FREEZE.md` is the frozen mapping/environment-field contract.
- `P1.2_SCOPE_AUDIT.md` records the accepted P1.2 final review, including the
  closed production diagnostic-caller and finite-geometry findings.
- `P1.2_INTEGRATION_RESULTS.md` records the PR #10 merge commit and all fresh
  post-merge P1.2, P1.1, Phase 0, and nested P0.4 evidence.
- `P1.2_INTEGRATION_AUDIT.md` records the independent review of Draft PR #11
  and its no-finding PASS decision.
- `P1.2_CLOSEOUT.md` records the PR #11 merge commit and the fresh post-merge
  P1.2, P1.1, Phase 0, and nested P0.4 evidence used to close the work package.

## Input schema 1

The header record contains `schema`, field count, particle count, coordinate code, ID encoding, precision bits, and two reserved fields. Each particle record contains `id_hi`, `id_lo`, native `x/y`, release time, status, age, and one reserved field.

Only `BOM_ALIVE` and `BOM_WAITING` are accepted at initialization. Internal tile boundaries use `[west,east) x [south,north)`; an internal corner therefore belongs to the north-east tile.
