# P2.3 dual-mode slow-manifold RHS test results

Status: **COMPLETE — EXACT FUNCTIONAL HEAD 335/335 PASS**

## Exact source

- branch: `MITGCM-BOM/p2.3-rhs-components`
- functional head: `fb004faf735e638c9248beabc49422b05aa09eb7`
- author: `WangYuLin <wang111936@outlook.com>`
- component test ID: `p23-rhs-fb004faf7-attempt01`
- component evidence root:
  `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/`
  `p23-rhs-components/p23-rhs-fb004faf7-attempt01`

## Component gate

| Row | Result | Direct meaning |
|---|---|---|
| p2-h-static | PASS | separate named modes, PAPER2024 default, stateless/P2.4 boundary |
| build-serial | PASS | GNU debug/IEEE compile and all production RHS symbols |
| build-mpi4 | PASS | OpenMPI four-rank debug/IEEE compile and symbols |
| p2-h01-serial | PASS | PAPER2024 analytic component oracle |
| p2-h02-serial | PASS | JULIA analytic component oracle |
| p2-h03-serial | PASS | nonparallel gradients discriminate the equations |
| p2-h04-serial | PASS | legal explicit/precombined equivalence and duplicate priority |
| p2-h05-serial | PASS | Cartesian/spherical sign and SI unit matrix |
| p2-h06-serial | PASS | 27 diagnostics, final-drift CFL, and rollback |
| p2-n06-serial | PASS | 17 negative injections, stable context, no commit |
| p2-h01-mpi4 | PASS | same H01 assertions under four ranks |
| p2-h02-mpi4 | PASS | same H02 assertions under four ranks |
| p2-h03-mpi4 | PASS | same H03 assertions under four ranks |
| p2-h04-mpi4 | PASS | same H04 assertions under four ranks |
| p2-h05-mpi4 | PASS | same H05 assertions under four ranks |
| p2-h06-mpi4 | PASS | same H06 assertions under four ranks |
| p2-n06-mpi4 | PASS | same N06 assertions under four ranks |
| p2-h-decomposition | PASS | eight sorted serial/MPI4 records are bitwise equal |

Total: **18/18 PASS**.

The independent oracles check all 27 published components rather than only
the final coordinate rate. H03 uses nonparallel source gradients so the
combined-total PAPER derivative and weighted per-source JULIA derivative
cannot accidentally agree. H05 checks north/south metric signs,
cyclonic/anticyclonic vorticity, and converts the locked Julia relaxation
time from days to SI seconds exactly once.

N06 injects duplicate Stokes policy, nonfinite sources and parameters,
invalid mode/source selections, combined/covariant/vorticity/rotation/
inertia/drift overflow, final CFL threshold and overflow, and absent-Stokes
NaN. Each failure leaves all 27 candidate diagnostics unpublished, preserves
particle sentinels bitwise, and returns stable failure/stage context.

## Evidence integrity

- `summary.tsv` SHA-256:
  `0d2ab16a2775b6fe63b883f656474e3ca486c21c76ab894da8b17e83cd14ba6b`
- `SHA256SUMS` file SHA-256:
  `d31de763f4cb5e3f415e589de3acf10904e9059e3369481435e147113a2dfe59`
- serial and MPI4 eight-record files have the same SHA-256:
  `c408f3f89696f702e37cd496772266281a01d36744574cc0ae66318d8f8b6b7d`

## Accepted regressions and closure audit

The same clean exact functional head passed:

| Gate | Rows | Result |
|---|---:|---|
| P2.3 RHS components | 18 | PASS |
| P2.2 derivative/metric/operator | 16 | PASS |
| P2.1 endpoint/provider transaction | 34 | PASS |
| P2.1 schema-2 pickup/restart | 10 | PASS |
| Phase-1/Phase-0 predecessor matrix | 257 | PASS |
| **Total** | **335** | **PASS** |

The aggregate audit is:

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p23-closure/
  p23-closure-fb004faf7-attempt01
```

- aggregate `row-audit.tsv` SHA-256:
  `290b3626e8343ae389f2227425ddf4b3591b4fa2f3e8ed54a08090c7b418c13e`
- aggregate `manifest.sha256` SHA-256:
  `9feacb71d499c8327b9d2b6ba5c61d6e53ffa7c521dd4e7aba93bc4b32a8fb42`

The aggregate independently verifies 19 summaries, 13 native manifests,
the exact source head, all tracked `pkg/bom` source hashes, P2.3 driver
hashes, environment, and an empty Git status. Its own manifest contains 40
files and passes 40/40 checks; the native manifests pass 55/55 checks.

## Development-attempt provenance

Before the exact functional-head run, three isolated driver attempts exposed
a fixed-form line-width issue and two negative-fixture assumptions whose
chosen `alpha=0` did not exercise the intended terms. No production defect
was hidden by those fixtures. Working attempts 04/05 then passed while the
negative matrix was expanded and absent-Stokes finite checking was hardened.
The committed exact-head attempt above is the only closure authority.

The first predecessor P1.1 invocation used its historical pre-P1.4 lifecycle
expectation. Re-running with the already integrated
`MITGCM_BOM_ALLOW_OWNER_MIGRATION=yes` contract passed 42/42 without any
production modification. All remaining predecessor groups passed on their
first exact-head invocation.

## Closure and next package

P2-H01--H06 and complete P2-N06 are accepted on one clean functional head,
together with every accepted predecessor. P2.3 is closed. The unique next
package is P2.4 stage-time RK integration and B04/B05/B16 trajectory,
convergence, Julia-golden, and rollback gates. No merge, release, or
`MITGCM-BOM-v0.3` tag is claimed here.
