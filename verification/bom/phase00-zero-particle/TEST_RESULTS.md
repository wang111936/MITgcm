# P0.4 formal zero-particle gate results

Date: 2026-08-23

Branch: `MITGCM-BOM/phase-00-zero-particle`

Parent commit: `d716e0278c0a35363e8e4338663517d3aa940794`

Test ID: `p04-attempt01`

## Command

```bash
MITGCM_BOM_TEST_ID=p04-attempt01 \
MITGCM_BOM_MAKE_JOBS=4 \
verification/bom/phase00-zero-particle/run_gate.sh
```

Build root:
`/home/wyl/build/mitgcm-bom/phase00-zero-particle/p04-attempt01`

Run root:
`/home/wyl/runs/mitgcm-bom/phase00-zero-particle/p04-attempt01`

## Static checks

- `bash -n run_gate.sh`: passed;
- `shellcheck run_gate.sh`: passed with no findings;
- source line-ending check: passed;
- script mode is `100755`; configuration and documentation are `100644`.

## Build results

| Case | Compiler mode | Result |
|---|---|---|
| `serial-on` | GNU Fortran, BOM compiled | passed |
| `mpi2-on` | OpenMPI, 2 x 1 process layout, BOM compiled | passed |
| `mpi4-on` | OpenMPI, 2 x 2 process layout, BOM compiled | passed |
| `serial-off` | GNU Fortran, BOM not compiled | passed |

All cases completed `genmake2`, dependency generation, compilation, and linking.
No compiler/linker fatal marker was found in the build logs.

## Positive gates

| Case | Expected rank logs | Normal-end logs | Checkpoint result |
|---|---:|---:|---|
| serial | 1 | 1 | 8/8 SHA-256 match |
| MPI-2 | 2 | 2 | 8/8 SHA-256 match |
| MPI-4 | 4 | 4 | 8/8 SHA-256 match |

All positive cases contain package activation, completed `BOM_READPARMS`,
completed `BOM_CHECK`, and the `BOM [FORWARD_STEP]` timer section. No positive
rank log contains an abnormal or fatal marker. The three decompositions provide
24/24 successful checkpoint checks against the frozen exp2 manifest.

## Negative gates

| Case | Process status | Required rejection | Result |
|---|---:|---|---|
| uncompiled activation | 0 | `ALLOW_BOM undef` plus `ABNORMAL END` | passed |
| nonzero particles | 0 | particle state unavailable plus `ABNORMAL END` | passed |

Neither negative log contains the normal-end marker. This confirms the driver
does not mistake the toolchain's zero process status for a successful MITgcm run.

## Non-overwrite safety

Running the driver again with `MITGCM_BOM_TEST_ID=p04-attempt01` was rejected
before any build or run step because the dedicated build root already existed.
Historical evidence was not overwritten.

## Verdict

`P0.4 GATE PASS`

The formal zero-particle lifecycle is decomposition invariant for serial,
2-rank MPI, and 4-rank MPI under the frozen exp2 baseline. This result does not
validate particle motion; `bomMaxParticles` remains zero by design.
