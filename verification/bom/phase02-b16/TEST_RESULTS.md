# P2.4 B16 Julia-reference test results

Status: **COMPLETE — EXACT FUNCTIONAL HEAD 12/12 PASS**

## Exact source and evidence

- MITGCM-BOM functional head:
  `4b2d09d40b96cd4408a64e1ee0d4716b7a6255ad`;
- test ID: `p24-closure-4b2d09d40-b16-attempt01`;
- evidence root:
  `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/`
  `p24-b16/p24-closure-4b2d09d40-b16-attempt01`;
- `summary.tsv` SHA-256:
  `1272324f97ceb3ea3ceb8134335d6ecd5eae85be074618ceca823d7a33dbc9c7`;
- `SHA256SUMS` SHA-256:
  `a343516938381af307afffd0d9ebc650fbe2b60e41ae518fab05d4d345c210e3`.

## Gate rows

| Row | Result | Direct meaning |
|---|---|---|
| p2-n07-source | PASS | mutated locked physics source rejected before generation |
| p2-n07-project | PASS | mutated Project rejected before generation |
| p2-n07-manifest | PASS | mutated Manifest rejected before generation |
| p2-n07-input | PASS | mutated B16 field input rejected before generation |
| p2-n07-golden | PASS | mutated golden RHS rejected before comparison |
| p2-n07-commit | PASS | wrong SargassumBOMB commit rejected |
| p2-n07-julia-version | PASS | wrong Julia version rejected |
| p2-i05-lock | PASS | source/environment/input locks and bytewise regeneration |
| build-serial | PASS | production stage/RK and B16 comparator compiled |
| p2-i05-rhs | PASS | native RHS and all 27 JULIA components within tolerance |
| p2-i06-rk2 | PASS | all fixed RK2 positions/path lengths within tolerance |
| p2-i06-rk4 | PASS | all fixed RK4 positions/path lengths within tolerance |

## Frozen artifacts

| Artifact | SHA-256 |
|---|---|
| `golden_rhs_julia_v1.csv` | `505a1f1d39c3223e1697a0d626623ac16e02369d11e726dd6215b3f5e2f6f012` |
| `golden_traj_julia_rk2_v1.csv` | `af62593cca8f2bdd2184cb5c153f4a2cbab154b4e0e3b1ad4e3a6a07be5f5790` |
| `golden_traj_julia_rk4_v1.csv` | `30082f0d47bd1ae406935bb5eab4003a36d83869b52eeaf82f138bc5ae0cde0a` |
| `context_tsit5_julia_v1.csv` | `74c8036bcaf183fb13692de0d1063cfd8d13c5a4615b8206a64feed13755cb1a` |

The adaptive context was generated twice with Julia 1.10.12 and actual
`OrdinaryDiffEqTsit5` at `abstol=reltol=1e-12`; the 292-line files were
bytewise identical. Its 291 data rows carry `gating=false`. It is retained to
show adaptive-reference behavior but is not compared to MITgcm fixed RK2/RK4.

The B16 exact-head rows are included in the 358/358 P2.4 aggregate at
`p24-closure/p24-closure-4b2d09d40-attempt01`.
