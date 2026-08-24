# P1.3 Leeway RHS results

Status: PASS for the stateless RHS production increment. This is component
evidence, not acceptance of RK motion, release transitions, owner migration,
or the complete P1-N08 state budget.

## Immutable implementation

- implementation commit:
  `a185dcae7922827c9b1ceb2b25386cb0da6b124a`;
- author and committer:
  `WangYuLin <wang111936@outlook.com>`;
- branch: `MITGCM-BOM/phase-01-single-tile-integration`;
- locked Julia source:
  `156557359185e4413ce82829f3ed26a4eb8c6283` (SargassumBOMB 0.7.14).

## Exact-head RHS gate

Executed on 2026-08-24 with a clean worktree at the implementation commit:

```text
build:    /home/wyl/build/mitgcm-bom/phase01-single-tile/p13-rhs-20260824T140216Z-388
run:      /home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-rhs-20260824T140216Z-388
artifact: /home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/p13-rhs-20260824T140216Z-388
```

The external `source-head.txt` equals the implementation commit, the Julia head
equals the locked reference above, and `sha256sum -c manifest.sha256` reports:

```text
summary.tsv: OK
source-head.txt: OK
julia-head.txt: OK
```

Summary: 15/15 PASS.

| Group | Result | Evidence |
|---|---:|---|
| source separation and frozen numeric codes | 1/1 | stateless production RHS; fixed fail/stage values |
| locked Julia source contract | 1/1 | clean exact commit; water plus alpha wind in both components |
| GNU debug/IEEE builds | 4/4 | no-EXF and EXF, serial and MPI4 |
| P1-I01 | 2/2 | bitwise zero RHS/CFL in serial and MPI4 |
| P1-I02 | 2/2 | Cartesian SI rates and analytic CFL in serial and MPI4 |
| P1-I03 | 1/1 | nonzero-latitude east/north spherical degree/s conversion |
| P1-I04 | 2/2 | production EXF to frozen field to RHS in serial and MPI4 |
| P1-N08 RHS subset | 1/1 | stable first failure, half-cell tie, CFL, no state commit |
| Julia algebra/unit conversion | 1/1 | SargassumBOMB 0.7.14; `1 m/s = 86.4 km/day` |

## Predecessor regression on the same production changes

The following fresh gates ran after the final production edits. Later changes
before the implementation commit were limited to the new RHS verification
fixture, documentation, and file-mode correction; `pkg/bom` was unchanged.

| Gate | Result | Run/evidence root |
|---|---:|---|
| P1.3 setup/EXF | 17/17 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-setup-20260824T134022Z-385` |
| P1.2 interpolation/lifecycle | 15/15 | `/home/wyl/runs/mitgcm-bom/phase01-interp/p12-interp-20260824T133915Z-397` |
| P1.2 surface fields | 7/7 | `/home/wyl/runs/mitgcm-bom/phase01-fields/p12-field-20260824T134148Z-400` |
| P1.2 mapping | 19/19 | `/home/wyl/runs/mitgcm-bom/phase01-mapping/p12-20260824T134307Z-385` |
| P1.1 state/initial input | 42/42 | `/home/wyl/runs/mitgcm-bom/phase01-state/20260824T134424Z-378` |
| Phase 0 final gate | 4/4 | `/home/wyl/runs/mitgcm-bom/phase00-final-gate/20260824T134712Z-379` |
| nested formal P0.4 | 9/9 | `/home/wyl/runs/mitgcm-bom/phase00-zero-particle/20260824T134712Z-379-p04` |

## Findings resolved during execution

1. A preliminary overflow guard evaluated `HUGE/abs(drift)` for a drift smaller
   than one, so the guard itself trapped. The production fix performs that
   division only when the drift multiplier exceeds one; the analogous stage
   guard only divides by `dtGuard` when it exceeds one.
2. The first Julia fixture passed tuples directly to `isapprox`, which Julia
   1.10 does not support. The final locked test compares both components and
   preserves the same algebra and tolerance.
3. The final P1-I04 fixture was strengthened from a directly populated BOM wind
   array to one production chain: constant EXF 10 m wind, `BOM_BUILD_FIELDS`
   freeze/mask/halo, and `BOM_RHS_LEEWAY` composition in serial and MPI4.

## Remaining boundary

No source in this increment advances or commits `bomX`, `bomY`, `bomAge`, or
`bomStatus`. `BOM_RK2`, `BOM_RK4`, release-time splitting, caller-level stage
diagnostics, transactional substep commit, `BOM_CHECK_STATE`, and owner
migration remain unimplemented. PR #13 must remain Draft and no Phase-1 tag is
permitted on this evidence alone.
