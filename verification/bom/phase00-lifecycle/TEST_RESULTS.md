# P0.3 lifecycle registration test results

Date: 2026-08-23

Branch: `MITGCM-BOM/phase-00-lifecycle`

Parent commit: `71a26b2bf6afef7512295728878d6f671f14992e`

## Scope under test

P0.3 registers the compile-time and runtime package boundary and calls the
existing Phase-0 BOM routines. It does not add particle state or physics.

## Lifecycle map

| MITgcm location | P0.3 behavior |
|---|---|
| `PARAMS.h` | declares `useBOM` in `PARM_PACKAGES` |
| `PACKAGES_BOOT` | reads `useBOM`, defaults it to false, reports status |
| `PACKAGES_READPARMS` | calls `BOM_READPARMS` when BOM is compiled |
| `BOM_READPARMS` | returns without opening `data.bom` when BOM is disabled |
| `PACKAGES_CHECK` | rejects uncompiled activation or calls `BOM_CHECK` |
| `PACKAGES_INIT_FIXED` | calls empty `BOM_INIT_FIXED` when enabled |
| `PACKAGES_INIT_VARIABLES` | calls empty `BOM_INIT_VARIA` when enabled |
| `FORWARD_STEP` | calls empty `BOM_MAIN` after FLT and before monitor/output |

## Build matrix

| BOM compiled | Configuration | Build directory | Result |
|---|---|---|---|
| no | serial | `/home/wyl/build/mitgcm-bom/phase00-lifecycle-serial-off` | passed |
| no | MPI | `/home/wyl/build/mitgcm-bom/phase00-lifecycle-mpi-off` | passed |
| yes | serial | `/home/wyl/build/mitgcm-bom/phase00-lifecycle-serial-on` | passed |
| yes | MPI | `/home/wyl/build/mitgcm-bom/phase00-lifecycle-mpi-on` | passed |

All four completed `genmake2`, `make depend`, compilation, and linking. The
BOM-enabled executables contain all five `bom_*` routine symbols.

## Positive runtime matrix

| BOM compiled | `useBOM` | Configuration | Run directory | Result |
|---|---|---|---|---|
| no | false | serial | `/home/wyl/runs/mitgcm-bom/phase00-lifecycle-off-serial` | normal end, 8/8 hashes match |
| no | false | 2-rank MPI | `/home/wyl/runs/mitgcm-bom/phase00-lifecycle-off-mpi` | both ranks normal, 8/8 match |
| yes | false | serial | `/home/wyl/runs/mitgcm-bom/phase00-lifecycle-compiled-off-serial` | normal end, 8/8 match |
| yes | false | 2-rank MPI | `/home/wyl/runs/mitgcm-bom/phase00-lifecycle-compiled-off-mpi` | both ranks normal, 8/8 match |
| yes | true, zero particles | serial | `/home/wyl/runs/mitgcm-bom/phase00-lifecycle-enabled-serial` | normal end, 8/8 match |
| yes | true, zero particles | 2-rank MPI | `/home/wyl/runs/mitgcm-bom/phase00-lifecycle-enabled-mpi` | both ranks normal, 8/8 match |

The six runs provide 48 successful SHA-256 checks against
`verification/bom/phase00-skeleton/exp2_checkpoint.sha256`.

The enabled logs show, in order, package activation, `BOM_READPARMS`,
`BOM_CHECK`, and a `BOM [FORWARD_STEP]` timer section.

The temporary enabled namelist used the following safety-critical values:

```text
useBOM=.TRUE.
bomMode='LEEW'
bomEquationMode='PAPER2024'
bomIntegrator='RK4'
bomDeltaTTarget=108000.0
bomMaxParticles=0
bomInitialFile=' '
```

P0.4 will promote a reviewed form of this input into a formal verification
experiment; P0.3 intentionally records evidence only.

## Negative gates

| Test | Run directory | Expected result | Observed result |
|---|---|---|---|
| `useBOM=true`, package not compiled | `/home/wyl/runs/mitgcm-bom/phase00-lifecycle-misconfig-serial` | reject before time stepping | `PACKAGES_CHECK` reports `ALLOW_BOM undef` |
| `bomMaxParticles=1` | `/home/wyl/runs/mitgcm-bom/phase00-lifecycle-nonzero-rejected` | reject unavailable state | `BOM_CHECK` reports Phase-0 particle state unavailable |

Neither negative run contains the normal-end marker. On this toolchain the
Fortran `STOP` paths returned process status 0, so future automation must require
the normal-end marker and scan for `ABNORMAL END` and fatal-error text in
addition to checking the process status.

## Scope audit

- no particle arrays or particle I/O were added;
- no environmental field interface or interpolation was added;
- no Stokes drift, windage, inertia, springs, biology, pickup, or MPI particle
  exchange was added;
- the only main-loop behavior is a call to an empty `BOM_MAIN` guarded by both
  `ALLOW_BOM` and `useBOM`;
- all runtime outputs remain outside the source repository.
