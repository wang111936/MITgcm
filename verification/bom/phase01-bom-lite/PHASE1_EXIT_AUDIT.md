# Phase 1 independent exit audit

Date: 2026-08-25

Audited production code head: `3f330b59db76b8d7d0ca0fb2bfd007e567fbd6bc`

Audit result: **PASS — NO OPEN FINDING**

This audit is separate from the P1.5 implementation and Ready review. It uses
the final merged development code, the complete fresh P1-G01 matrix, the
requirements map, reference lock and environment/HPC boundary records. The
`MITGCM-BOM-v0.2` tag did not exist locally or remotely when this audit was
performed.

## Exit-criterion decision matrix

| Criterion | Independent evidence | Decision |
|---|---|---|
| P1.1—P1.5 complete and sequentially integrated | Phase records; PR #13/#14/#15 merge commits `41fb0938`, `9d258da4`, `3f330b59` plus earlier P1.0—P1.2 integrations | PASS |
| analytical, convergence, migration, restart and FLT coexistence gates pass | final exact-head P1-G01: 257/257; P1.5 62 and predecessors 195 | PASS |
| Phase 0 full gate rerun without regression | Phase 0 final 4/4 and nested P0.4 9/9 on `3f330b59` | PASS |
| Julia RHS/golden limitations have an explicit conclusion | locked Julia source/RHS/unit checks and independent RK oracles pass; adaptive whole-trajectory golden is explicitly deferred to Phase 2 | PASS |
| target-server-only conditions are separately recorded | `ENVIRONMENT_READINESS.md` section 6, project risk R-004 and development manual section 11 separate site optfile, scheduler and parallel-filesystem validation into Phase 5 | PASS |
| independent exit audit precedes v0.2 tag | this audit; local/remote tag absence confirmed before the audit record | PASS |

## Executable and traceability audit

All P1-R01—P1-R16 entries are complete and map in both directions to production
interfaces and executed tests. The final 257 rows include positive, negative,
transactional and decomposition checks rather than process-status-only smoke.
Expected failure paths require their frozen diagnostic markers and absence of
partial state publication.

The aggregate evidence root is:

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/
  p1-integrated-g01-3f330b59-attempt01
```

The aggregate manifest SHA-256 is
`d5a83b7d0e1033bfc105aaab52f688aec38ac2de871ab7824d9135f864290af7`.
Its row audit SHA-256 is
`737c489957c7dbe65a8665955090dd2cbb76afc6e3f4fe463367b7414ad28fce`.
Nine native manifests and the aggregate manifest validate, all native source
heads equal the audited code head, and the captured Git status is empty.

## Julia reference and golden decision

The fixed SargassumBOMB 0.7.14 checkout has no historical root Manifest and
its upstream test calls a missing example function. MITGCM-BOM does not patch
that reference or silently update dependencies. The reproducible local lock
uses Julia 1.10.12 and the stored Project/Manifest.

For Phase 1, the locked source directly checks the implemented Leeway algebra
`water+alpha*wind` and the exact m/s-to-km/day conversion. Independent Julia
fixtures check the explicit-midpoint RK2 and classical RK4 algorithms and
their observed convergence. The reference package's adaptive Tsit5 trajectory
is not treated as a step-by-step oracle for MITgcm fixed-step integration.

A whole-trajectory golden requires Phase 2 to freeze common SI inputs,
geometry, fixed time stepping, old/new fields, Stokes handling and the explicit
`PAPER2024` versus `JULIA` equation modes. The trajectory-golden reference
therefore remains `PROVISIONAL`. This is a recorded Phase 2 obligation, not an
unmet Phase 1 requirement.

## Target-server boundary

The local acceptance baseline is Ubuntu 22.04 WSL2 with GNU Fortran 11.4,
Open MPI 4.1.2, NetCDF and Julia 1.10.12. It proves portable Linux builds,
serial/MPI execution, restart and decomposition behavior required before
Phase 2.

The target server is not yet specified. Site compiler/MPI combinations,
NetCDF/HDF5 linkage, scheduler submission, site optfile, filesystem paths,
thread affinity and scale/performance validation cannot be honestly tested
locally. They are explicitly tracked as R-004 and Phase 5 HPC hardening. They
do not block Phase 2 physics development, which continues on the recorded GNU
and MPI baseline.

## Scope and release decision

No Phase 2 physics was included in the audited code. Phase 1 keeps Stokes
disabled, freezes the ocean/wind field inside each ocean step, supports only
the frozen regular-grid boundary, and limits pickup to the same decomposition.
Those are deliberate interfaces with explicit later owners, not hidden
failures.

No implementation, test or evidence finding remains open. Phase 1 is
technically complete. After this documentation-only audit is reviewed and
merged, `MITGCM-BOM-v0.2` may be created as an annotated tag on that merge
commit. No numerical rerun is required solely because the audit merge changes
Markdown; the tag must still be verified locally and remotely.

## Phase 2 entry decision

Phase 2 may begin after the audit record is integrated and v0.2 is published.
Its first increment should freeze the old/new environment snapshots, Stokes
source and no-double-counting rule, derivative/metric interfaces, and
`PAPER2024`/`JULIA` equation-mode acceptance tests before production physics
is added. Springs, biology and HPC site optimization remain out of that first
increment.
