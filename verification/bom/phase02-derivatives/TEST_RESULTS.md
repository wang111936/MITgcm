# P2.2 Cartesian derivative test results

Status: **FIRST INCREMENT PASS; P2.2 REMAINS IN PROGRESS**

## Exact source

- branch: `MITGCM-BOM/p2.2-derivatives`
- commit: `f2c86ddf73d2f0b8dc470ad6abcac68a48accaef`
- author: `WangYuLin <wang111936@outlook.com>`
- test ID: `p22-derivative-f2c86ddf7-attempt01`
- evidence root: `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/`
  `p22-derivatives/p22-derivative-f2c86ddf7-attempt01`

## Results

| Row | Result | Direct meaning |
|---|---|---|
| build-serial | PASS | GNU debug build and production derivative symbols |
| build-mpi4 | PASS | OpenMPI four-rank debug build and symbols |
| p2-d01-serial | PASS | nonuniform constant/affine gradients and exact environment secant |
| p2-d02-serial | PASS | quadratic exactness and cubic centered/one-sided second-order convergence |
| p2-n05-serial | PASS | insufficient stencil invalidity plus zero/NaN metric rollback |
| p2-d01-mpi4 | PASS | same D01 assertions under four ranks |
| p2-d02-mpi4 | PASS | same D02 assertions under four ranks |
| p2-n05-mpi4 | PASS | collective metric failure and rollback |
| p2-d03 | PASS | eight sorted C-point records are bitwise decomposition-equal |

Total: **9/9 PASS**.

The quadratic manufactured field is differentiated exactly by the three-point
Lagrange formulas. A cubic field is therefore used to produce a nonzero error
for the observed-order assertion; both centered and permitted one-sided orders
must lie in `[1.8,2.2]`.

## Evidence integrity

- `summary.tsv` SHA-256:
  `a8ba156e5394634fb699b07ef7c83c6677696c11ae21a76ad7880d5ecd8afc8c`
- `SHA256SUMS` file SHA-256:
  `b4500dfb6d2e8858bb68347c072ec0b3776131c1312d9077e2364c47469efe65`
- serial and MPI4 sorted-record SHA-256:
  `a733a27f4fa609ed691ee6215a90e8587988f7521c590f5f4e2d17b48b1e96f0`

The exact same commit also passed the existing schema-2 pickup regression as
`p22-pickup-f2c86ddf7-attempt01`: **10/10 PASS**, summary SHA-256
`90f92e9ef047433f47f53d993a2a4392258668df3551fc74c17e3ad5db29e132`.
This directly checks deterministic derivative rebuild after endpoint recovery,
nonzero FILES Stokes bitwise restart, LEEW/schema-1 compatibility, fingerprint
rejection, endpoint preflight and MPI4 schema-2 restart.

## Scope and next gate

This result verifies P2-D01--D03 and the Cartesian portion of P2-N05. It does
not claim spherical P2-D04/D05/N05, P2.3 RHS, particle RK wiring, or P2.2
closure. The next exact-head gate must add unrotated spherical-polar
`tauSphere`, MITgcm C-point `fCori`, covariant material derivatives and
vorticity while retaining all nine rows above.
