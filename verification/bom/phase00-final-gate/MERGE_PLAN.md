# Phase-0 stacked merge plan

Snapshot date: 2026-08-23

No merge or tag is authorized by this plan. Each merge remains an explicit
review decision.

## Current stack

| Order | PR | Head | Current base | State |
|---:|---|---|---|---|
| 1 | #1 | `MITGCM-BOM/phase-00-reference-lock` | `MITGCM-BOM/development` | open, ready, mergeable |
| 2 | #2 | `MITGCM-BOM/phase-00-skeleton` | P0.1 branch | open, draft, mergeable |
| 3 | #3 | `MITGCM-BOM/phase-00-lifecycle` | P0.2 branch | open, draft, mergeable |
| 4 | #4 | `MITGCM-BOM/phase-00-zero-particle` | P0.3 branch | open, draft, mergeable |
| 5 | #5 | `MITGCM-BOM/phase-00-final-gate` | P0.4 branch | open, draft, mergeable |

## Required sequence

1. Review and merge PR #1 into `MITGCM-BOM/development`.
2. Retarget PR #2 to `MITGCM-BOM/development`, verify that only P0.2 remains,
   rerun required checks, mark it ready, then merge.
3. Retarget PR #3 to `MITGCM-BOM/development`, verify the P0.3-only diff and
   lifecycle evidence, mark it ready, then merge.
4. Retarget PR #4 to `MITGCM-BOM/development`, verify the P0.4-only diff and
   formal zero-particle evidence, mark it ready, then merge.
5. Retarget PR #5 to `MITGCM-BOM/development`, verify the P0.5-only diff and
   final-gate evidence, mark it ready, then merge.

A merge commit is recommended for this phase because it preserves the exact
stage commits and stacked ancestry. Do not force-push, delete phase branches, or
batch-merge the stack. After each merge, verify the next PR's base, changed-file
list, mergeability, and required checks before proceeding.

## Final integration gate

After PR #5 is merged, check out the updated `MITGCM-BOM/development` and run:

```bash
MITGCM_BOM_TEST_ID=p05-integrated-YYYYMMDDTHHMMSSZ \
  verification/bom/phase00-final-gate/run_gate.sh
```

Only after this fresh run passes, the worktree is clean, and all five PRs show
the intended merged commits may Phase 0 be marked `complete`. The
`MITGCM-BOM-v0.1` tag may then be created from the verified development HEAD;
tagging is not part of P0.5 implementation or publication.
