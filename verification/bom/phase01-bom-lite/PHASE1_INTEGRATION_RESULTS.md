# Phase 1 post-merge integration results

Date: 2026-08-25

Integration branch: `MITGCM-BOM/development`

Verified production code head: `3f330b59db76b8d7d0ca0fb2bfd007e567fbd6bc`

Result: **PASS — 257/257**

## Ordered integration record

P1.3—P1.5 were independently reviewed and merged in dependency order with
merge commits. Earlier P1.0—P1.2 integration was already complete.

| Order | Work package | PR | Merge commit |
|---:|---|---:|---|
| 1 | P1.3 single-tile integration | #13 | `41fb093866ef4c2dbda778696892457cfca160f9` |
| 2 | P1.4 owner migration | #14 | `9d258da4ff43d84f4877ba11d894af0e96b3177b` |
| 3 | P1.5 output, pickup and FLT coexistence | #15 | `3f330b59db76b8d7d0ca0fb2bfd007e567fbd6bc` |

## Final exact-head matrix

Every driver used a new test ID and external build/run/artifact root. The
repository was clean before and after execution.

| Gate | Rows | Result |
|---|---:|---|
| P1.5 output/pickup | 25 | PASS |
| P1.5 migration I/O | 12 | PASS |
| P1.5 FLT/BOM coexistence | 25 | PASS |
| P1.4 owner migration | 36 | PASS |
| P1.3 lifecycle | 13 | PASS |
| P1.3 setup | 17 | PASS |
| P1.3 Leeway RHS | 15 | PASS |
| P1.3 RK2 | 12 | PASS |
| P1.3 RK4 | 12 | PASS |
| P1.2 interpolation | 9 | PASS |
| P1.2 surface fields | 7 | PASS |
| P1.2 mapping | 19 | PASS |
| P1.1 state | 42 | PASS |
| Phase 0 final gate | 4 | PASS |
| nested P0.4 formal gate | 9 | PASS |
| **Total** | **257** | **PASS** |

The matrix covers analytical displacement, RK2/RK4 convergence, lifecycle and
transaction rollback, owner migration, exact 64-bit IDs, trajectory output,
same-layout pickup/restart, changed-layout rejection, and independent FLT/BOM
coexistence. Phase 0 reference and zero-particle behavior were rerun without
regression.

## Compact evidence

Aggregate root:

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/
  p1-integrated-g01-3f330b59-attempt01
```

| File | SHA-256 |
|---|---|
| `manifest.sha256` | `d5a83b7d0e1033bfc105aaab52f688aec38ac2de871ab7824d9135f864290af7` |
| `audit.tsv` | `737c489957c7dbe65a8665955090dd2cbb76afc6e3f4fe463367b7414ad28fce` |
| `phase1-exit-audit.tsv` | `dfaac4a9f07bddcafbae83a527f6b7cc9ddde827511590c28bbe3364df93397e` |

The aggregate contains fifteen copied summaries, nine native manifests and
their validation logs, one exact `source-head.txt`, an empty `git-status.txt`,
environment versions, and hashes of all fifteen gate drivers. `sha256sum -c`
validated every aggregate and native-manifest entry.

## Environment

The recorded local baseline is Ubuntu 22.04 WSL2, GNU Fortran 11.4.0,
Open MPI 4.1.2 and Julia 1.10.12. MPI matrices include 1, 2 and 4 ranks;
production and debug/bounds variants are exercised by their owning gates.

## Scope

This final run used the already merged production code. It introduced no
source, input or test-driver change. Generated evidence remained outside the
repository. Stokes drift, inertia, springs, biology, beaching, stochastic
physics, EXCH2 and changed-decomposition restart remain outside Phase 1.

## Conclusion

The final integrated production code head satisfies the executable Phase 1
gate. No failing row, manifest mismatch, dirty-source condition or open
execution finding remains.
