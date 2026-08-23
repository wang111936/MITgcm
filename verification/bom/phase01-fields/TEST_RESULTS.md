# P1.2 surface-field construction results

Status: **PASS**

## Authoritative field gate

- functional commit:
  `50dd6a6ab7e92ac5ca26ab4666ce2e45d7495899`;
- test ID: `p12-field-20260824-a`;
- build root:
  `/home/wyl/build/mitgcm-bom/phase01-fields/p12-field-20260824-a`;
- run root:
  `/home/wyl/runs/mitgcm-bom/phase01-fields/p12-field-20260824-a`;
- result: 7/7 summary rows passed;
- summary SHA-256:
  `97d21381200a8c8314de96302d790bb4aa995092a100bb9b83e42f27840d4492`;
- production builder SHA-256:
  `4cfe19de780785b7a513d6b4295e418ec8d2324e15a6f736b38aec80c85e25ce`;
- gate-driver SHA-256:
  `187ea983f1a17e252ed73f43c73cc1beb720ce63e58dd9d219db4a79c6281eda`;
- verification-routine SHA-256:
  `9225664b2ca72f9f009e9cb5f8589ba551a34b832fb9a44a5c7ada8ddb776a6e`.

| Evidence | Result |
|---|---|
| production/test source separation | PASS |
| real `ROTATE_UV2EN_RL`, exactly two scalar exchanges | PASS |
| serial `Nr=2` debug build and symbols | PASS |
| MPI4 `Nr=2` debug build and symbols | PASS |
| P1-F01 serial, four local tiles | PASS |
| P1-F01 MPI4, one tile per rank | PASS |
| P1-F02 serial, rotation/mask/local halos | PASS |
| P1-F02 MPI4, rotation/mask/rank halos | PASS |

Both builds use `Nr=2`, while the production rotation receives true
single-level arrays and `kSize=1`.  P1-F02 uses analytic face values, a
90-degree artificial rotation, one dry C point, and deliberately conflicting
non-owner halo angles.  The exchanged east/north halos equal owner values,
which proves that the geographic components are exchanged as scalars after
rotation.  `BOM_MAIN` also returns without publishing fields when
`bomMaxParticles=0`.

## Regressions after the field increment

| Gate | Test ID | Result | Summary SHA-256 |
|---|---|---|---|
| P1.2 mapping/locator | `p12-20260823T214951Z-501860` | 15/15 PASS | `24ee80deb67395b9a8c14662d26e1da66be30b76ffc284ba409f15fc66c725d7` |
| P1.1 state/initial file | `20260823T215044Z-548609` | 8 builds, 14 positive, 20 negative, 104/104 checkpoint PASS | `93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7` |
| Phase 0 final gate | `20260823T215320Z-668561` | 4/4 PASS | `e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2` |
| nested P0.4 gate | `20260823T215320Z-668561-p04` | 4 builds, 3 positive, 2 negative, 24/24 checkpoint PASS | `af87c782d2f7b1016677c32de98512e3430bb3fafab6ba2c6c2e18eba384f97d` |

All raw build and run evidence remains outside the repository below the
stated `/home/wyl/{build,runs}/mitgcm-bom` roots.  The field gate passed on
its first execution.  Two manually chosen mapping regression IDs were
already present and were rejected before build output was written; the
successful mapping rerun used the automatic unique ID recorded above, and
no existing evidence directory was overwritten.

## Scope boundary

P1-R06 and P1-F01/P1-F02 are complete.  This increment does not implement
`BOM_INTERP_WET_PAIR`, P1-F03/P1-N05, wind or Stokes fields, particle motion,
owner migration, trajectory output, or pickup.  PR #10 remains Draft; no
`MITGCM-BOM-v0.2` tag is authorized.
