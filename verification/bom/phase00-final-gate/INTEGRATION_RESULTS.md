# Phase-0 post-merge integration results

Date: 2026-08-23

Integration branch: `MITGCM-BOM/development`

Verified commit: `2baea214fe1f898e16df4953892c142a07b82111`

Test ID: `p05-integrated-attempt01`

## Ordered merge record

Each PR was retargeted to `MITGCM-BOM/development` after its predecessor was
merged. Its stage-only changed-file list, mergeability, draft state, and fixed
head SHA were checked immediately before a merge commit was requested.

| Order | PR | Verified head | Merge commit |
|---:|---|---|---|
| 1 | #1 | `348ffcd2ca6c0eb901d0f5529713a3d1689fb2d2` | `ccaf4f81243ae7ded8d09be0bd2074aced4600d8` |
| 2 | #2 | `71a26b2bf6afef7512295728878d6f671f14992e` | `db9610264b21c7c55c4cce7a94fb6d357fbe9459` |
| 3 | #3 | `d716e0278c0a35363e8e4338663517d3aa940794` | `81b53387d6c941b23177f23774e705dd200d940e` |
| 4 | #4 | `083e4b79d872d091b615cbf05fb9dd031e41b98f` | `d5e18cec22ed1be9c300bdd79ff908b6bd452e0c` |
| 5 | #5 | `1813be15afeae8370eaa5effb5f1d9820886e5be` | `2baea214fe1f898e16df4953892c142a07b82111` |

GitHub reported all five PRs closed and merged, with the merge commits shown
above. The final local development branch was fast-forwarded to the same commit
after the gate passed.

## Command and evidence roots

```bash
MITGCM_BOM_TEST_ID=p05-integrated-attempt01 \
MITGCM_BOM_MAKE_JOBS=4 \
  verification/bom/phase00-final-gate/run_gate.sh
```

P0.5 result root:
`/home/wyl/runs/mitgcm-bom/phase00-final-gate/p05-integrated-attempt01`

Derived P0.4 build root:
`/home/wyl/build/mitgcm-bom/phase00-zero-particle/p05-integrated-attempt01-p04`

Derived P0.4 run root:
`/home/wyl/runs/mitgcm-bom/phase00-zero-particle/p05-integrated-attempt01-p04`

## P0.5 result

| Check | Result | Detail |
|---|---|---|
| locked references | PASS | source, custom registry, Project, and Manifest matched |
| Julia instantiate | PASS | locked environment instantiated offline |
| Julia smoke | PASS | 8/8 deterministic assertions |
| P0.4 formal gate | PASS | four builds, three positive runs, two negative gates |

The Julia evidence reports Julia 1.10.12 and SargassumBOMB 0.7.14. Package
initialization retained the documented warning that default interpolants could
not be constructed. The smoke does not require those fields and is not a
trajectory-golden validation.

## Derived P0.4 result

| Case | Result | Detail |
|---|---|---|
| serial-on build | PASS | build and link |
| MPI-2-on build | PASS | build and link |
| MPI-4-on build | PASS | build and link |
| serial-off build | PASS | build and link |
| serial-on run | PASS | normal end; 8/8 hashes |
| MPI-2-on run | PASS | both ranks normal; 8/8 hashes |
| MPI-4-on run | PASS | all four ranks normal; 8/8 hashes |
| uncompiled activation | PASS | rejected by the expected package check |
| nonzero particles | PASS | rejected by the expected BOM check |

The three positive decompositions matched 24/24 frozen checkpoint SHA-256
values. Both negative cases remained log-aware because the tested Fortran
toolchain returned process status 0 after its fatal `STOP` path.

## Non-overwrite and repository checks

A second invocation with `MITGCM_BOM_TEST_ID=p05-integrated-attempt01` failed
before Julia or P0.4 execution because the P0.5 result root already existed.
The existing evidence was not overwritten.

After the gate, the source worktree was clean and the local
`MITGCM-BOM/development` branch matched
`origin/MITGCM-BOM/development` at the verified commit.

## Scope and decision

The merged Phase-0 stack provides only the reproducible reference lock, empty
`pkg/bom` boundary, MITgcm lifecycle registration, zero-particle regression
gate, and final verification assets. It does not provide particle state,
particle motion, environmental interpolation, Stokes drift, inertia, springs,
biology, pickup, or MPI particle exchange.

All recorded Phase-0 exit criteria are satisfied. Phase 0 is marked
`complete`. The Julia reference remains `PROVISIONAL` for trajectory-golden
use, which is a later physics-validation requirement and does not invalidate
the empty-package integration gate.

No `MITGCM-BOM-v0.1` tag was created during merging, testing, or preparation of
this record. Tagging is a separate explicit repository decision.
