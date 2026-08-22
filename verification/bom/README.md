# MITGCM-BOM verification

This directory stores source-controlled test definitions, reference locks, and
compact evidence for MITGCM-BOM.  Build trees, executables, runtime output, and
external environmental datasets remain outside the repository.

## Layout

- `reference/`: locked MITgcm and Julia reference revisions and dependency data;
- `phase00-skeleton/`: P0.2 compile/link and zero-impact regression evidence;
- `phase00-lifecycle/`: P0.3 package-switch and lifecycle-hook evidence;
- `phase00-zero-particle/`: P0.4 formal serial/MPI zero-particle gate,
  negative checks, and requirements traceability;
- later phase directories: analytical, golden-trajectory, restart, MPI
  decomposition, and performance tests as their implementations are added.

The authoritative build and run roots for the local Ubuntu 22.04 environment
are `/home/wyl/build/mitgcm-bom` and `/home/wyl/runs/mitgcm-bom`.
