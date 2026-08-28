# Phase 3 independent exit audit

Date: 2026-08-29

Audited integrated development head:
`e9eabb0418f0119c747bce3ec13092641f664bfc`

Audit result: **PASS — NO OPEN FINDING**

This audit is separate from P3.5 implementation and PR #31 review. It uses the
ordered merged development tree, a fresh final-mode P3-G99 matrix, the frozen
P3.0 requirements and decisions, and the explicit target-HPC boundary. The
annotated tag `MITGCM-BOM-v0.4` did not exist locally or remotely when this
audit began.

## Exit-criterion decision matrix

| Criterion | Independent evidence | Decision |
|---|---|---|
| P3.0--P3.5 complete and sequentially integrated | PR #26--#31; P3.4 merge `286d1ad59`, then P3.5 merge `e9eabb041` | PASS |
| P3-R01--P3-R18 and P3-D001--P3-D022 remain traceable | frozen requirements/decision maps and accepted P3.1--P3.5 closeouts | PASS |
| complete integrated and predecessor gate passes | final P3-G99 on exact integrated head: 538/538 | PASS |
| B07--B09, B17, negative, restart and 1/2/4-rank matrices pass | P3.1--P3.5 direct groups plus exact Phase 2 390-row predecessor group | PASS |
| no global all-particle production neighbor path | production call/link audit and fixed-density counters | PASS |
| fixed-density work and communication bounds pass | P3-X01/X02; serial/MPI2/MPI4 Cartesian/spherical 16/32/64 | PASS |
| merge topology and commit identities are valid | dedicated P3.4/P3.5 merges, ordered first-parent audit, WangYuLin/GitHub identities | PASS |
| restart and target-server boundaries are explicit | schema-3 same-decomposition restart accepted; target 100k/256-rank retained for Phase 5 | PASS |
| independent exit audit precedes v0.4 | this audit; local and remote tag absence confirmed | PASS |

## Merge and identity audit

P3.4 package head `38fd1824ff2ad69ce439f0c144cb3d5ab4d71ba3` is the
second parent ancestry of merge commit
`286d1ad59dcc826839a3f53a08172c3bf7ea0a73`. P3.5 package head
`4c669cf985599031696e2279126625a0fa150c74` is the second parent of the later
merge commit `e9eabb0418f0119c747bce3ec13092641f664bfc`.

The first-parent walk from `MITGCM-BOM-v0.3` finds the dedicated P3.4 merge
before the dedicated P3.5 merge. Package commits use
`WangYuLin <wang111936@outlook.com>` as author and committer. Hosted merge
commits use the accepted GitHub identity and `Merge PR #...` titles. No
unexpected Phase 3 identity or SKRIPS path is present.

## Executable and integrity audit

The authoritative final P3-G99 evidence root is:

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p3-g99/
  p3-g99-final-e9eabb0418-attempt01
```

It contains 538/538 PASS in the frozen groups 20+42+34+18+34+390. Its
`row-audit.tsv` SHA-256 is
`14bb14aadf48382e169a325d0bd435f1a7f02f36eec0c8e9a3a36ca5ed8f98f2`.
Its `manifest.sha256` SHA-256 is
`4d39d4a086cafdd009446da05fbf143b884a89e47c1952c829998aea5b73a252`.
The independent P3-G99 audit log SHA-256 is
`dc189fb8a84c42963e1203ff9e1193e86a6861ae25fe04bae41855e2b8107213`.
The manifest self-validates, `mode.txt` is `final`, the source head is exact
and the captured Git status is empty.

The separate exit-audit evidence root is:

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/phase3-exit-audit/
  phase3-exit-e9eabb0418-attempt01
```

Its manifest and independent-audit log SHA-256 values are
`d6da6efc85c5339b2eeb7ec6d454637af8ad6effbbe3bbb44a960702e132e975`
and `1857cc468f77f088cfb0b60e7a42697622d76e43ce1d58c9e8db662b084a6eae`.
The independent marker is `PHASE3 INDEPENDENT EXIT AUDIT PASS`; it identifies
the exact P3.4 and P3.5 merges and reports no open finding.

## Physics, restart and performance boundary

Phase 3 accepts exact cutoff graphs, one-stage read-only ghosts, SI Hooke and
overflow-safe eBOMB spring velocities, ensemble RK transactions, deterministic
FINAL connected components/raft diagnostics, schema-3 sidecars and exact
production counters. Same-decomposition trajectory/pickup restart is covered;
corruption, configuration mismatch and changed decomposition fail closed.

The local Linux baseline is Ubuntu 22.04, GNU Fortran 11.4.0 and Open MPI
4.1.2 with serial, MPI2 and MPI4 execution. Timing remains informational on
shared WSL hardware. Target-server compiler/MPI/scheduler/filesystem validation,
100,000 particles, 256 ranks and ocean-model overhead remain assigned to
Phase 5 and are not misrepresented as Phase 3 results.

## Release decision

No implementation, test, evidence, identity, merge-order or scope finding is
open on the audited integrated head. After this exit-record branch is reviewed
and merged with a merge commit, final P3-G99 538/538 and the independent exit
audit must be rerun on that new exact development head. Only if both pass may
the annotated tag `MITGCM-BOM-v0.4` be created on that head and pushed. The
local and remote tag object and peeled commit must then be verified.

## Phase 4 entry decision

Phase 4 may begin only after the exit record is integrated, release-head
revalidation passes, and v0.4 is published and verified. Its first action is a
P4.0 design/interface/test freeze based on the accepted Phase 3 contracts; it
must not silently add production biology, beaching, random-event, OpenMP,
target-HPC or EXCH2/LLC behavior before that scope is explicitly frozen.
