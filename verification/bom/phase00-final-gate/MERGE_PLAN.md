# Phase-0 stacked merge plan and execution record

Plan date: 2026-08-23

Execution date: 2026-08-23

The original plan required explicit authorization, ordered merge commits, an
independent diff review before every merge, and a fresh P0.5 run after the
stack reached `MITGCM-BOM/development`. The user authorized that operation; the
sequence below records the actual result.

## Executed stack

| Order | PR | Head | Merge commit | Result |
|---:|---|---|---|---|
| 1 | #1 | `MITGCM-BOM/phase-00-reference-lock` | `ccaf4f81243ae7ded8d09be0bd2074aced4600d8` | merged |
| 2 | #2 | `MITGCM-BOM/phase-00-skeleton` | `db9610264b21c7c55c4cce7a94fb6d357fbe9459` | merged |
| 3 | #3 | `MITGCM-BOM/phase-00-lifecycle` | `81b53387d6c941b23177f23774e705dd200d940e` | merged |
| 4 | #4 | `MITGCM-BOM/phase-00-zero-particle` | `d5e18cec22ed1be9c300bdd79ff908b6bd452e0c` | merged |
| 5 | #5 | `MITGCM-BOM/phase-00-final-gate` | `2baea214fe1f898e16df4953892c142a07b82111` | merged |

All five PRs were retargeted to `MITGCM-BOM/development` as their predecessor
was integrated. Before each merge, the PR was checked for its intended
stage-only changed-file list, a mergeable state, a non-draft state, and the
expected immutable head SHA. GitHub created a merge commit for every PR. No
phase branch was force-pushed or deleted.

## Final integration gate

The updated development branch was fetched and checked out at:

```text
2baea214fe1f898e16df4953892c142a07b82111
```

The fresh post-merge gate used a unique result ID:

```bash
MITGCM_BOM_TEST_ID=p05-integrated-attempt01 \
MITGCM_BOM_MAKE_JOBS=4 \
  verification/bom/phase00-final-gate/run_gate.sh
```

The gate passed the locked-reference checks, offline Julia instantiate, 8/8
Julia smoke assertions, four P0.4 builds, three serial/MPI positive runs, 24/24
checkpoint hashes, and two negative gates. A second invocation with the same
ID was rejected before overwrite. Full evidence is recorded in
`INTEGRATION_RESULTS.md`.

## Completion and tag state

The final gate passed, all five PRs report the intended merge commits, and the
local development worktree was clean. Phase 0 therefore satisfies its recorded
exit conditions.

No `MITGCM-BOM-v0.1` tag was created during merge or integration testing.
Tagging remains a separate explicit decision after this documentation-only
integration record is reviewed.
