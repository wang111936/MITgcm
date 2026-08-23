# Phase-0 exit audit

Date: 2026-08-23

Pre-merge evidence run: `p05-attempt01`

Post-merge evidence run: `p05-integrated-attempt01`

Verified development commit: `2baea214fe1f898e16df4953892c142a07b82111`

## Exit criteria

| Criterion | Evidence | Result |
|---|---|---|
| BOM disabled preserves MITgcm baseline | P0.2/P0.3 regression plus fresh P0.4 rerun | passed |
| BOM enabled with zero particles runs in serial | P0.4 `serial-on` | passed |
| BOM enabled with zero particles runs on 2 MPI ranks | P0.4 `mpi2-on` | passed |
| BOM enabled with zero particles runs on 4 MPI ranks | P0.4 `mpi4-on`, four normal rank logs | passed |
| all three decompositions preserve checkpoints | fresh P0.4 rerun, 24/24 SHA-256 | passed |
| invalid compile/runtime combinations are rejected | two P0.4 negative gates | passed |
| locked Julia reference loads and runs a basic test | P0.5 offline instantiate and 8/8 smoke | passed |
| requirements traceability is current | P0-R01 through P0-R11 plus integrated rerun | passed |
| Phase-0 changes are integrated | PR #1 through #5 merge commits; final development SHA | passed |

## Scope audit

P0.5 adds only verification and documentation. The subsequent integration
record also changes documentation only. Neither adds particle arrays, particle
motion, environmental interpolation, Stokes drift, inertia, springs, biology,
pickup, or MPI particle exchange. The P0.5 Julia test validates the reference
toolchain and deterministic pure functions; it is not evidence for any
unimplemented physics.

## Reference-lock decision

The source commit, registry commit, package project, resolved Manifest, package
version, and basic pure behavior are reproducible. The lock remains
`PROVISIONAL` because the upstream project did not provide a historical
Manifest and MITGCM-BOM has not yet frozen analytical inputs or Julia trajectory
goldens. Those limitations do not block the empty-package Phase-0 gate, but they
must be closed before a Julia trajectory becomes a physics oracle.

## Conclusion

The executable, traceability, and integration portions of Phase 0 are complete.
PR #1 through #5 were merged in order with merge commits, and the fresh
post-merge final gate passed at
`2baea214fe1f898e16df4953892c142a07b82111`. Phase 0 is therefore marked
`complete`.

No version tag was created. Review and integration of this documentation-only
record, followed by the `MITGCM-BOM-v0.1` tag decision, are separate repository
administration tasks and do not reopen the completed Phase-0 technical gate.
