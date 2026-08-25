# P1.3 stateless RK2 results

Status: PASS for the stateless explicit-midpoint RK2 production increment.
This is component evidence, not acceptance of release transitions,
authoritative particle motion, RK4, or owner migration.

## Immutable implementation

- implementation commit:
  `48fe7fa2e342eddb2fc62fa4db3a956ccc16f207`;
- author and committer:
  `WangYuLin <wang111936@outlook.com>`;
- branch: `MITGCM-BOM/phase-01-single-tile-integration`;
- locked Julia source:
  `156557359185e4413ce82829f3ed26a4eb8c6283`
  (SargassumBOMB 0.7.14).

## Exact-head RK2 gate

Executed on 2026-08-24 with a clean worktree at the implementation commit:

```text
build:    /home/wyl/build/mitgcm-bom/phase01-single-tile/p13-rk2-20260824T152035Z-379
run:      /home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-rk2-20260824T152035Z-379
artifact: /home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/p13-rk2-20260824T152035Z-379
```

The external `source-head.txt` equals the implementation commit, the Julia
head equals the locked reference above, and
`sha256sum -c manifest.sha256` reports:

```text
summary.tsv: OK
source-head.txt: OK
julia-head.txt: OK
```

Summary: 11/11 PASS.

| Group | Result | Evidence |
|---|---:|---|
| source separation and frozen RK2 contract | 1/1 | exactly K1/K2/FINAL full RHS calls; four safe coordinate updates; no particle writes |
| locked Julia source contract | 1/1 | clean exact commit; water plus alpha wind in both components |
| GNU debug/IEEE builds | 2/2 | serial and MPI4 link RK2, safe-update, RHS, and verifier symbols |
| zero field | 2/2 | serial/MPI4 bitwise stationary position and zero final diagnostics |
| constant field | 2/2 | serial/MPI4 analytic Cartesian displacement and final-position diagnostics |
| P1-I05 | 1/1 | affine frozen C-grid field; finest observed orders `1.9885` and `1.9942` |
| P1-N08 RK2 subset | 1/1 | NONE/K1/K2/FINAL failure attribution, overflow guard, rollback, and no particle commit |
| Julia affine oracle | 1/1 | Julia 1.10.12, SargassumBOMB 0.7.14 environment, four oracle assertions |

## Predecessor regression on the implementation commit

| Gate | Result | Run/evidence root |
|---|---:|---|
| P1.3 Leeway RHS | 15/15 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-rhs-20260824T152234Z-387` |
| P1.3 setup/EXF | 17/17 | `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-setup-20260824T152437Z-391` |
| P1.2 interpolation/lifecycle | 15/15 | `/home/wyl/runs/mitgcm-bom/phase01-interp/p12-interp-20260824T152555Z-409` |
| P1.2 surface fields | 7/7 | `/home/wyl/runs/mitgcm-bom/phase01-fields/p12-field-20260824T152709Z-383` |
| P1.2 mapping | 19/19 | `/home/wyl/runs/mitgcm-bom/phase01-mapping/p12-20260824T152811Z-400` |
| P1.1 state/initial input | 42/42 | `/home/wyl/runs/mitgcm-bom/phase01-state/20260824T152927Z-409` |
| Phase 0 final gate | 4/4 | `/home/wyl/runs/mitgcm-bom/phase00-final-gate/20260824T153215Z-384` |
| nested formal P0.4 | 9/9 | `/home/wyl/runs/mitgcm-bom/phase00-zero-particle/20260824T153215Z-384-p04` |

## Findings resolved during execution

1. New production files initially lacked the standard `BOM_OPTIONS.h`
   preprocessing header; the final files use the package precision macros and
   compile in all serial/MPI debug variants.
2. The first P1-I05 fixture inherited a deliberately nonuniform mapping grid.
   Physical-coordinate affine samples are not bilinear in that grid's
   fractional index. The final frozen convergence fixture uses a uniform
   Cartesian grid, so native C-coordinate samples are represented exactly by
   bilinear interpolation as required by P1-I05.
3. The safe midpoint update originally multiplied the rate by `0.5` before
   multiplying by the time step. The final implementation guards and forms
   `dt*rate` first, then applies the bounded stage factor, avoiding premature
   underflow while retaining overflow safety.

## Ready-review P1-I03 remediation

Commit `0458910a9bb484aab8901d1a17046e3804e82165` adds a direct spherical-polar
production-RK2 acceptance at nonzero latitude. Pure east and pure north SI
velocities are advanced for 300 seconds and compared with analytic longitude
and latitude displacement using the same `rSphere` and `deg2rad` as production.

The clean exact-head gate passed **12/12**:

```text
run:      /home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-ready-i03-rk2-0458910a-attempt01
artifact: /home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/p13-ready-i03-rk2-0458910a-attempt01
summary:  1d1800b750eda15d04a39c34c38341178bd427425b77d2f5520ce707ffd0fcc4
```

This remediation changes verification code and input only; production Fortran
is unchanged.

## Remaining boundary

`BOM_RK2` is a stateless trial kernel: it returns a locally accepted
candidate or rolls back `x1/y1`, but never writes an authoritative particle
slot. `BOM_RK4`, exact release splitting, `BOM_MAIN` particle motion,
transactional state/age/diagnostic commit, `BOM_CHECK_STATE`, and owner
migration remain later increments. PR #13 remains Draft, and no Phase-1 tag is
permitted on this evidence alone.
