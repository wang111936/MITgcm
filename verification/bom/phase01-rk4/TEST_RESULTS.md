# P1.3 stateless RK4 results

Status: PASS for the stateless classical-RK4 production increment. This is
component evidence, not acceptance of release transitions, authoritative
particle motion, state-budget checks, or owner migration.

## Immutable implementation

- implementation head:
  `8493b45b06937ace6a10b17b649d9fbf191d6922`;
- production RK4 commit:
  `4ca494f8c3a8509da3d488d371eece7cb8ed0f85`;
- RK2 guard-audit compatibility correction:
  `8493b45b06937ace6a10b17b649d9fbf191d6922`;
- author and committer:
  `WangYuLin <wang111936@outlook.com>`;
- branch: `MITGCM-BOM/phase-01-single-tile-integration`;
- locked Julia source:
  `156557359185e4413ce82829f3ed26a4eb8c6283`
  (SargassumBOMB 0.7.14).

## Exact-head RK4 gate

Executed on 2026-08-25 with a clean worktree at the implementation head:

```text
build:    /home/wyl/build/mitgcm-bom/phase01-single-tile/p13-rk4-20260824T163220Z-406
run:      /home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-rk4-20260824T163220Z-406
artifact: /home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/p13-rk4-20260824T163220Z-406
```

The external `source-head.txt` equals the implementation head, the Julia head
equals the locked reference above, and `sha256sum -c manifest.sha256` reports:

```text
summary.tsv: OK
source-head.txt: OK
julia-head.txt: OK
```

Summary: 11/11 PASS.

| Group | Result | Evidence |
|---|---:|---|
| source separation and frozen RK4 contract | 1/1 | exactly K1--K4/FINAL full RHS calls; six guarded stage-coordinate and two guarded weighted-final updates; no particle writes |
| locked Julia source contract | 1/1 | clean exact commit; water plus alpha wind in both components |
| GNU debug/IEEE builds | 2/2 | serial and MPI4 link RK4, both coordinate helpers, RHS, and verifier symbols |
| zero field | 2/2 | serial/MPI4 bitwise stationary position, exact extreme-rate cancellation, and zero final diagnostics |
| constant field | 2/2 | serial/MPI4 analytic Cartesian displacement and final-position diagnostics |
| P1-I06 | 1/1 | affine frozen C-grid field; finest observed orders `3.9858` and `3.9931` |
| P1-N08 RK4 subset | 1/1 | NONE/K1/K2/K3/K4/FINAL first-failure attribution, overflow guard, rollback, and no particle commit |
| Julia affine oracle | 1/1 | Julia 1.10.12, SargassumBOMB 0.7.14 environment, four oracle assertions |

## Predecessor regression on the implementation head

| Gate | Result | Run/evidence root |
|---|---:|---|
| P1.3 stateless RK2 | 11/11 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-rk2-20260824T163412Z-390` |
| P1.3 Leeway RHS | 15/15 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-rhs-20260824T163605Z-407` |
| P1.3 setup/EXF | 17/17 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-setup-20260824T163605Z-412` |
| P1.2 interpolation/lifecycle | 15/15 | `/home/wyl/runs/mitgcm-bom/phase01-interp/p12-interp-20260824T163843Z-398` |
| P1.2 surface fields | 7/7 | `/home/wyl/runs/mitgcm-bom/phase01-fields/p12-field-20260824T163843Z-403` |
| P1.2 mapping | 19/19 | `/home/wyl/runs/mitgcm-bom/phase01-mapping/p12-20260824T163843Z-407` |
| P1.1 state/initial input | 42/42 | `/home/wyl/runs/mitgcm-bom/phase01-state/20260824T164013Z-507` |
| Phase 0 final gate | 4/4 | `/home/wyl/runs/mitgcm-bom/phase00-final-gate/20260824T164012Z-384` |
| nested formal P0.4 | 9/9 | `/home/wyl/runs/mitgcm-bom/phase00-zero-particle/20260824T164012Z-384-p04` |

## Findings resolved during execution

1. The generic RK coordinate helper was generalized from ordered products to
   exponent-decomposed multiplication. This allows a bounded stage factor to
   rescue an otherwise overflowing partial product while retaining guarded
   addition and bitwise zero preservation.
2. The weighted final-coordinate helper normalizes all four rates before
   applying classical RK4 weights, preventing intermediate weighted-sum
   overflow. The extreme-cancellation fixture uses pairwise exact normalized
   terms so it tests the intended cancellation contract under IEEE traps.
3. The predecessor RK2 gate still recognized the former division-based guard
   expression. Its structural audit now recognizes the exponent-scaled guard;
   the full RK2 numerical, rollback, MPI4, and Julia matrix then passed 11/11
   on the same implementation head.

## Remaining boundary

`BOM_RK4` is a stateless trial kernel: it returns a locally accepted candidate
or rolls back `x1/y1`, but never writes an authoritative particle slot. Exact
release splitting, `BOM_MAIN` particle motion, transactional
state/age/diagnostic commit, `BOM_CHECK_STATE`, and owner migration remain
later increments. PR #13 remains Draft, and no Phase-1 tag is permitted on
this component evidence alone.
