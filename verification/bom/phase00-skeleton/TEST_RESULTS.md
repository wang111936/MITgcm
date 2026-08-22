# P0.2 compile-only skeleton test results

Date: 2026-08-23

Branch: `MITGCM-BOM/phase-00-skeleton`

Parent commit: `348ffcd2ca6c0eb901d0f5529713a3d1689fb2d2`

## Scope under test

The test compiles `pkg/bom` into MITgcm without adding core lifecycle calls.
The package therefore has zero runtime behavior in P0.2.  The test checks that
the new Fortran interface compiles and links in both serial and MPI builds and
that merely compiling the package does not change the frozen exp2 result.

## Toolchain

- Ubuntu 22.04 under WSL2;
- GNU Fortran 11.4.0;
- OpenMPI 4.1.2;
- MITgcm optfile: `tools/build_options/linux_amd64_gfortran`;
- base experiment: `verification/exp2`.

## Build results

| Configuration | Build directory | Result |
|---|---|---|
| serial | `/home/wyl/build/mitgcm-bom/phase00-skeleton-serial` | `genmake2`, `make depend`, compile, link passed |
| MPI | `/home/wyl/build/mitgcm-bom/phase00-skeleton-mpi` | `genmake2 -mpi`, `make depend`, compile, link passed |

Both package lists contain `bom`, `mdsio`, and `mom_common`.  Both linked
executables contain these symbols:

```text
bom_check_
bom_init_fixed_
bom_init_varia_
bom_main_
bom_readparms_
```

## Runtime regression

| Configuration | Run directory | Result |
|---|---|---|
| serial | `/home/wyl/runs/mitgcm-bom/phase00-skeleton-serial` | normal end |
| MPI, 2 ranks | `/home/wyl/runs/mitgcm-bom/phase00-skeleton-mpi` | both ranks normal end |

For each run, SHA-256 was computed for four `pickup.ckptA` and four
`pickup_cd.ckptA` data files.  All eight files match the P0.1 frozen baseline;
the serial and MPI manifests also match each other.  The authoritative manifest
is stored in `exp2_checkpoint.sha256`.

## Commands

Equivalent build commands:

```bash
tools/genmake2 -rootdir=/home/wyl/projects/mitgcm-bom \
  -mods=/home/wyl/build/mitgcm-bom/phase00-skeleton-serial-mods \
  -of=tools/build_options/linux_amd64_gfortran
make depend
make -j4

tools/genmake2 -rootdir=/home/wyl/projects/mitgcm-bom -mpi \
  -mods=/home/wyl/build/mitgcm-bom/phase00-skeleton-mpi-mods \
  -of=tools/build_options/linux_amd64_gfortran
make depend
make -j4
```

Runtime commands were `./mitgcmuv` and `mpirun -np 2 ./mitgcmuv` in separate
copies of `verification/exp2/input`.

## Scope audit

- no files under `model/src` or `model/inc` changed;
- no `useBOM` or `data.pkg` registration exists yet;
- no particle state, motion, interpolation, Stokes drift, inertia, springs,
  biology, pickup, or particle exchange is implemented;
- all source and test-record files are regular mode `100644` files.

Lifecycle registration and a true BOM-enabled zero-particle run belong to P0.3
and P0.4.  This result must not be described as a working particle model.
