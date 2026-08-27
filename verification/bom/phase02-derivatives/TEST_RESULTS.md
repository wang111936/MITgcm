# P2.2 derivative, metric and covariant-operator test results

Status: **COMPLETE — EXACT FUNCTIONAL HEAD 317/317 PASS**

## Exact source

- branch: `MITGCM-BOM/p2.2-derivatives`
- Cartesian increment: `f2c86ddf73d2f0b8dc470ad6abcac68a48accaef`
- P2.2 functional head: `5d4b918318682bee99b871684f781fa0ceefa482`
- author: `WangYuLin <wang111936@outlook.com>`
- derivative test ID: `p22-derivative-5d4b91831-attempt01`
- evidence root: `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/`
  `p22-derivatives/p22-derivative-5d4b91831-attempt01`

## Derivative gate

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
| p2-d04-serial | PASS | spherical physical gradients and `tauSphere` |
| p2-d05-serial | PASS | `fCori`, PAPER-total and JULIA-base vorticity candidates |
| p2-n05-sphere-serial | PASS | radius, pole and `fCori` rejection with rollback |
| p2-d04-mpi4 | PASS | same D04 assertions under four ranks |
| p2-d05-mpi4 | PASS | same D05 assertions under four ranks |
| p2-n05-sphere-mpi4 | PASS | collective spherical metric failure and rollback |
| p2-d04-decomposition | PASS | eight spherical metric/operator records are bitwise equal |
| p2-d03 | PASS | eight sorted C-point records are bitwise decomposition-equal |

Total: **16/16 PASS**.

The production transaction now publishes C-point gradients, validity,
`tauSphere`, and the unmodified MITgcm `fCori` together. Cartesian grids use
exact zero `tauSphere`; supported unrotated spherical-polar grids use
`tan(latitude)/rSphere`. Dry points remain invalid zeros. Bad geometry,
nonfinite inputs, near-pole coordinates, or protected arithmetic overflow
leave accepted derived state unchanged.

The stateless covariant helper implements the frozen physical east/north
material derivative and vorticity equations after stage-time interpolation.
D05 directly forms a PAPER total-field candidate and a JULIA base-only
candidate and compares each vorticity with its separate analytic oracle.
Actual equation-mode dispatch, component accelerations, and diagnostics remain
P2.3 work and are not claimed here.

## Evidence integrity

- `summary.tsv` SHA-256:
  `3515a500fb69c692c7df5517df13a49ead461775d572fedc06f65f69690bb8cd`
- `SHA256SUMS` file SHA-256:
  `83fed1ff97c9059a70c83167ab567b898e61cbbc3f22b57b7654a5b9c72620b7`

## Accepted regressions and closure audit

The same exact functional head passed:

| Gate | Rows | Result |
|---|---:|---|
| P2.2 derivative/metric/operator | 16 | PASS |
| P2.1 endpoint/provider transaction | 34 | PASS |
| P2.1 schema-2 pickup/restart | 10 | PASS |
| Phase-1/Phase-0 predecessor matrix | 257 | PASS |
| **Total** | **317** | **PASS** |

Exact IDs are `p22-endpoint-5d4b91831-attempt01`,
`p22-pickup-5d4b91831-attempt01`, and the 15
`p22-predecessor-5d4b91831-*` groups. The aggregate audit is:

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p22-closure/
  p22-closure-5d4b91831-attempt02
```

- aggregate `row-audit.tsv` SHA-256:
  `8074e632d887e2e23bdb6233c2c1f8896ef098522b3dbc10a72a3b42e96ca163`
- aggregate `manifest.sha256` SHA-256:
  `1d4d4409a47e729d713066245f2942179ee04995452c931d87c46782ffdc2a40`
- endpoint summary SHA-256:
  `af80775a11cf86fb999e1707898c6c837d8732f9925eb6d1adfda7045c0d0201`
- pickup summary SHA-256:
  `90f92e9ef047433f47f53d993a2a4392258668df3551fc74c17e3ad5db29e132`

The aggregate independently verifies 18 summaries, 12 native manifests,
the exact source head, tracked source hashes, driver hashes, environment, and
an empty Git status. The first aggregate attempt stopped only because Julia's
locked executable was not on the ordinary PATH; attempt02 records the same
Julia 1.10.12 path used by the formal Phase-0 gate. A lifecycle runner attempt
without the already-integrated P1.4 migration flag was also retained; the
correct frozen integration configuration passed 13/13 without production
changes.

## Closure and next package

P2-D01--D05, complete P2-N05, all accepted P2.1 gates, and all predecessor
regressions are accepted on one clean functional head. P2.2 is therefore
closed. The next package is P2.3 stateless `PAPER2024`/`JULIA` RHS components
and P2-H01--H06/P2-N06. No particle RK-stage wiring, P2.4 golden trajectory,
merge, release, or `MITGCM-BOM-v0.3` tag is claimed.
