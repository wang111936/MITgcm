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
- `phase00-final-gate/`: P0.5 locked Julia smoke, fresh P0.4 rerun,
  Phase-0 exit audit, and stacked merge plan;
- `phase01-bom-lite/`: P1.0 requirements/test baseline plus the P1.1
  state/initial-file generator, serial/MPI/debug gate, compact results,
  and the staged plan for mapping, leeway integration, owner migration,
  trajectory output, pickup restart, and FLT coexistence;
- `phase01-mapping/`: P1.2 regular Cartesian/spherical mapping, 360-degree
  longitude normalization, inverse mapping, and unsupported-grid guards;
- `phase01-fields/`: P1.2 single-level C-grid surface-field construction,
  east/north rotation, dry masking, and serial/MPI scalar-halo gates;
- `phase01-interp/`: P1.2 shared-weight wet-pair interpolation, non-moving
  production lifecycle diagnostics, and caller-level collective failure
  contracts in serial and MPI4 layouts;
- `phase01-setup/`: P1.3 first production increment for trap-safe setup
  preflight, immutable expected-owner initialization, and frozen `NONE`/EXF
  wind snapshots in serial and MPI4;
- `phase01-rhs/`: P1.3 stateless SI Leeway RHS, Cartesian/spherical native
  coordinate rates, end-to-end EXF wind composition, stable failure/stage
  codes, stage CFL, and locked Julia algebra in serial and MPI4;
- later phase directories: analytical, golden-trajectory, restart, MPI
  decomposition, and performance tests as their implementations are added.

The authoritative build and run roots for the local Ubuntu 22.04 environment
are `/home/wyl/build/mitgcm-bom` and `/home/wyl/runs/mitgcm-bom`.
