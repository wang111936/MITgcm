# Phase 2 post-merge integration results

Date: 2026-08-27

Integration branch: `MITGCM-BOM/development`

Merged production head: `f71e76e89864ab3c6f32de3770efca39f5f819e5`

Verified audit head: `db41805cda3a10fe9b96889c87069c6347788cbc`

Result: **PASS — 390/390**

## Ordered integration record

P2.1--P2.5 were independently reviewed and merged in dependency order with
merge commits. P2.0 interface freeze was already integrated through PR #19.

| Order | Work package | PR | Merge commit |
|---:|---|---:|---|
| 1 | P2.1 exact environmental endpoints and schema-2 field pickup | #20 | `4771bdb97f254cfcc9f3cc30024b807c72f05d4e` |
| 2 | P2.2 derivatives, metrics and covariant operators | #21 | `6c9d94e5a3ea9b9f903ac690aa9148be8cde377b` |
| 3 | P2.3 dual-mode slow-manifold RHS | #22 | `8730fe900d9d147f099a8c06ea02948cdc67bb7e` |
| 4 | P2.4 exact-stage RK and locked Julia golden | #23 | `bb641b9d1c29efac9935e056cddd1e6b903005fe` |
| 5 | P2.5 output, restart and coexistence closure | #24 | `f71e76e89864ab3c6f32de3770efca39f5f819e5` |

The final development tree is identical to the reviewed P2.5 branch tree at
`560577dfac0ca52195102e7e0ae6f25bc1cde4ea`. The audit head adds only the two
exact P2.4 closure-record paths to the independent audit allowlist. It changes
no `pkg/bom`, MITgcm model source, verification driver, input or reference
artifact. Therefore the production tree verified by the gate is the tree
merged at `f71e76e89864ab3c6f32de3770efca39f5f819e5`.

## Final exact-head matrix

Every driver used external build, run and evidence roots. The source worktree
was clean when the authoritative aggregate was captured.

| Gate group | Rows | Result |
|---|---:|---|
| Phase 0 final | 4 | PASS |
| Phase 0 zero-particle | 9 | PASS |
| P1.1 state | 42 | PASS |
| P1.2 mapping, fields and interpolation | 35 | PASS |
| P1.3 setup, RHS, RK2, RK4 and lifecycle | 69 | PASS |
| P1.4 owner migration | 36 | PASS |
| P1.5 output, migration I/O and FLT coexistence | 62 | PASS |
| P2.1 endpoint/provider and pickup | 44 | PASS |
| P2.2 derivatives, metrics and operators | 16 | PASS |
| P2.3 RHS components | 18 | PASS |
| P2.4 stage-aware RK and B16 | 23 | PASS |
| P2.5 integration and coexistence | 32 | PASS |
| **Total** | **390** | **PASS** |

The matrix covers exact transactional old/new endpoints, stage-time sampling,
Cartesian and spherical derivatives, both equation modes, Stokes de-duplication,
B04/B05 analytical convergence, checksummed B16 fixed-step Julia comparison,
rollback, live schema-2 diagnostics, 1/2/4-rank behavior, same-decomposition
restart and independent FLT/BOM coexistence.

## Compact evidence

Authoritative aggregate root:

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-closure/
  p2-integrated-g01-db41805cd-attempt02
```

| File | SHA-256 |
|---|---|
| `row-audit.tsv` | `d29712970d8de8db828c0611384de38f7680047c001494b3917cce4fc04e677a` |
| `manifest.sha256` | `ce29af66b0a3b925cce2bc8c70a1a937aff94a621d3f6bc10b314e26b5a5b85c` |

The independent audit reports one allowed changed file and 390 rows. The
aggregate manifest validates all registered aggregate files, `source-head.txt`
contains the exact audit head, and `git-status.txt` is empty.

`p2-integrated-g01-db41805cd-attempt01` is retained as non-authoritative
diagnostic evidence. A global artifact-root override was inherited by nested
drivers, so the aggregator could not find their summaries at its frozen paths.
The corrected attempt02 removed that configuration error and is the only
authoritative final result.

## Environment and scope

The recorded local acceptance baseline is Ubuntu 22.04 WSL2, GNU Fortran
11.4.0, Open MPI 4.1.2 and Julia 1.10.12. Target-server compiler/MPI, scheduler,
parallel-filesystem and scale/performance validation remain assigned to Phase 5.

Changed-decomposition restart remains explicitly rejected. The accepted
contract is same-decomposition restart; this is a deliberate staged boundary,
not a skipped Phase 2 test.

## Conclusion

The ordered merged production tree satisfies the executable Phase 2 gate. No
failing row, manifest mismatch, dirty-source condition or open execution
finding remains. The Phase 2 exit audit may proceed without another numerical
rerun for documentation-only changes.
