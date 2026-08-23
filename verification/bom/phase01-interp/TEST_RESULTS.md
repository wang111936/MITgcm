# P1.2 wet-pair interpolation results

Status: **PASS**

## Authoritative interpolation gate

- functional commit:
  `597d1a706de2ca388d1312dd6bb667421ae9adc7`;
- test ID: `p12-interp-20260824-a`;
- build root:
  `/home/wyl/build/mitgcm-bom/phase01-interp/p12-interp-20260824-a`;
- run root:
  `/home/wyl/runs/mitgcm-bom/phase01-interp/p12-interp-20260824-a`;
- result: 9/9 summary rows passed;
- summary SHA-256:
  `75fcde1ce34ceb1b43cb2ef8dcc6e323948db1edb6df2d4fb90329d8395be81a`;
- production interpolation SHA-256:
  `40397acf41c45e9cce2d903838b4ced35e424c75cecf105bde4cc1624b3ddb20`;
- gate-driver SHA-256:
  `773d9d7cc421aedaf45fbf7bad345483f37059b7ca404f5d2c42faa7f1e8fd32`;
- verification-routine SHA-256:
  `6844e27f383145c7100989bedfc4519f51d5f934d4795c083c77a61c203e3ade`.

| Evidence | Result |
|---|---|
| production/test source separation and interface contract | PASS |
| serial debug/bounds build and symbols | PASS |
| MPI4 debug/bounds build and symbols | PASS |
| P1-F03 FULL serial/MPI4 | 2/2 PASS |
| P1-F03 PARTIAL serial/MPI4 | 2/2 PASS |
| P1-N05 invalid contracts serial/MPI4 | 2/2 PASS |

P1-F03 proves constant preservation at negative fractional overlap indices,
fully wet affine-field exactness, exact-threshold acceptance, dry-value
exclusion, and one normalized weight set shared by east and north.  P1-N05
proves safe invalid returns for unpublished fields, incomplete low/high
stencils, infinite and huge finite coordinates, non-finite pair fields,
insufficient wet weight, and invalid tile indices.  Invalid calls return zero
velocity values; an insufficient wet stencil retains its actual weight for a
future caller diagnostic.

## Regressions after the interpolation increment

| Gate | Test ID | Result | Summary SHA-256 |
|---|---|---|---|
| P1.2 field construction | `p12-field-20260823T222525Z-392` | 7/7 PASS | `97d21381200a8c8314de96302d790bb4aa995092a100bb9b83e42f27840d4492` |
| P1.2 mapping/locator | `p12-20260823T222622Z-390` | 15/15 PASS | `24ee80deb67395b9a8c14662d26e1da66be30b76ffc284ba409f15fc66c725d7` |
| P1.1 state/initial file | `20260823T222731Z-385` | 8 builds, 14 positive, 20 negative, 104/104 checkpoint PASS | `93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7` |
| Phase 0 final gate | `20260823T223014Z-381` | 4/4 PASS | `e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2` |
| nested P0.4 gate | `20260823T223014Z-381-p04` | 4 builds, 3 positive, 2 negative, 24/24 checkpoint PASS | `af87c782d2f7b1016677c32de98512e3430bb3fafab6ba2c6c2e18eba384f97d` |

All build and run evidence remains outside the repository under the stated
`/home/wyl/{build,runs}/mitgcm-bom` roots.  The interpolation gate and every
regression passed on the first execution; no evidence directory was reused or
overwritten.

## Scope boundary

P1-R05, P1-R06, and P1-R07 now have production implementations and executable
evidence.  P1.2 still requires its final scope audit and independent review
before PR #10 can leave Draft.  No particle RHS, position update, owner
migration, wind or Stokes field, trajectory, pickup, P1.3 code, or v0.2 tag is
included.
