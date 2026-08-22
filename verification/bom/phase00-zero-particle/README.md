# P0.4 zero-particle verification gate

This case promotes the Phase-0 BOM lifecycle test to a repeatable gate. It uses
the existing `verification/exp2` ocean input and compiles `pkg/bom` without
adding particle state or physics.

## Coverage

- BOM enabled with zero particles in serial, 2-rank MPI, and 4-rank MPI;
- identical checkpoint SHA-256 values for all three decompositions;
- package activation, parameter read, parameter check, and `BOM_MAIN` timer
  evidence in runtime logs;
- expected rejection when `useBOM=true` but BOM is not compiled;
- expected rejection when a nonzero particle count is requested;
- log-aware verdicts that do not trust process status alone.

The global exp2 grid has four 45 x 20 tiles:

| Case | MPI layout | Tiles per process |
|---|---|---|
| serial | 1 x 1 | 2 x 2 |
| MPI-2 | 2 x 1 | 1 x 2 |
| MPI-4 | 2 x 2 | 1 x 1 |

## Run

From the repository root:

```bash
MITGCM_BOM_TEST_ID=p04-attempt01 \
  verification/bom/phase00-zero-particle/run_gate.sh
```

Optional environment variables:

- `MITGCM_BOM_TEST_BUILD_ROOT`: parent for unique build output;
- `MITGCM_BOM_TEST_RUN_ROOT`: parent for unique runtime output;
- `MITGCM_BOM_OPTFILE`: MITgcm build option file;
- `MITGCM_BOM_MAKE_JOBS`: parallel make job count;
- `MITGCM_BOM_TEST_ID`: unique leaf name for this attempt.

The driver refuses to reuse an existing attempt directory. It never deletes or
overwrites prior build/run evidence. The result summary is written to
`<run-root>/<test-id>/summary.tsv`.

## Pass criteria

A positive case passes only when every expected rank log contains the normal-end
marker, no fatal marker is present, lifecycle evidence is present, and all eight
checkpoint hashes match. A negative case passes only when the normal-end marker
is absent and the expected rejection plus `ABNORMAL END` are present.
