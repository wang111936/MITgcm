# P2.4 stage-time RK and closure test results

Status: **COMPLETE — EXACT FUNCTIONAL HEAD 358/358 PASS**

## Exact source

- branch: `MITGCM-BOM/p2.4-stage-rk-golden`;
- functional head: `4b2d09d40b96cd4408a64e1ee0d4716b7a6255ad`;
- author: `WangYuLin <wang111936@outlook.com>`;
- direct test ID: `p24-closure-4b2d09d40-stage-rk-attempt01`;
- direct evidence root:
  `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/`
  `p24-stage-rk/p24-closure-4b2d09d40-stage-rk-attempt01`.

## Direct stage/RK gate

| Row | Result | Direct meaning |
|---|---|---|
| p2-i-static | PASS | exact-time sampler, BOM dispatch and one-point commit boundary |
| build-serial | PASS | GNU IEEE/development compile and production P2.4 symbols |
| build-mpi4 | PASS | OpenMPI four-rank compile and production P2.4 symbols |
| p2-i01-serial | PASS | B04 analytic gradients, components, signs, inertia and drift |
| p2-i02-serial | PASS | B04 RK2/RK4 trajectory convergence |
| p2-i03-serial | PASS | B05 affine-time three-source stage/secant and displacement |
| p2-i04-serial | PASS | B05 endpoint refinement and full K2 rollback |
| p2-i01-mpi4 | PASS | I01 under four ranks |
| p2-i02-mpi4 | PASS | I02 under four ranks |
| p2-i03-mpi4 | PASS | I03 under four ranks |
| p2-i04-mpi4 | PASS | I04 under four ranks |

Total: **11/11 PASS**. The K1 owner is strict, later trial positions use the
accepted overlap, and the FINAL exact-time refresh publishes position,
mapping, sampled fields, drift and all 27 diagnostics only after success.

## Complete accepted-regression audit

| Gate group | Rows | Result |
|---|---:|---|
| P2.4 stage/RK B04/B05 | 11 | PASS |
| P2.4 B16/N07 | 12 | PASS |
| P2.3 RHS components | 18 | PASS |
| P2.2 derivative/metric/operator | 16 | PASS |
| P2.1 endpoint/provider and pickup | 44 | PASS |
| Phase-1/Phase-0 predecessor matrix | 257 | PASS |
| **Total** | **358** | **PASS** |

The aggregate audit is:

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p24-closure/
  p24-closure-4b2d09d40-attempt01
```

It verifies 21 summaries, the exact source head, an empty Git status, all 57
`pkg/bom` source hashes, 30 P2.4 driver/reference hashes, and 66 entries from
15 native evidence manifests. Its own manifest covers 44 files and passes
44/44 checks.

## Evidence integrity

- direct `summary.tsv` SHA-256:
  `64220583016abbc42da5c92c4108f8cbe2fef12dfa2884b32ff4767ac4f36221`;
- direct `SHA256SUMS` SHA-256:
  `29c265cae3b190bcfe47207c5c0f38ddf4674aedb33eb993fc200ea6bbcf1a63`;
- aggregate `row-audit.tsv` SHA-256:
  `1e2ea3401e43a5e4bee74ff0362ee5a23907b707a35509122c04f80123b62a23`;
- aggregate `manifest.sha256` SHA-256:
  `157e4ad4d960097f408ebd751abdea36a7f21f95d302f84bd229cccfc7cd7cb0`.

## Closure and next package

P2-I01--I06 and complete P2-N07 are accepted together with every predecessor.
P2.4 is closed. P2.5 owns schema-2 output/pickup integration for the new live
diagnostics, same-decomposition restart, 1/2/4-rank total-system consistency,
FLT coexistence and Phase-2 final P2-G01. No merge, tag, or release is claimed.
