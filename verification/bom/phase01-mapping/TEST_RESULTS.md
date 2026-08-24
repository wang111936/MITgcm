# P1.2 mapping and locator-wrapper results

Status: **PASS**

## Current authoritative audit-fix mapping and locator gate

- functional commit:
  `2f346d98cf978922cae53bff67fc32088cbb8941`;
- test ID: `p12-map-auditfix-20260824-b`;
- build root:
  `/home/wyl/build/mitgcm-bom/phase01-mapping/p12-map-auditfix-20260824-b`;
- run root:
  `/home/wyl/runs/mitgcm-bom/phase01-mapping/p12-map-auditfix-20260824-b`;
- result: 19/19 summary rows passed;
- summary SHA-256:
  `926575f1093bb7353f09e9835e175289a309c13e653ded5a96871e06b3810c02`;
- production initializer SHA-256:
  `97b5b66fdce6dc3b7219630188fe369dd4997d1e79a000aab6c23022a1c2acde`;
- production normalizer SHA-256:
  `8a9499a06fab020320e81f5e976f17dbbb6b9a803fb11c09a2c6cefe357baa1a`;
- gate-driver SHA-256:
  `2f39902f40a45e497f0f5fd1c4246f94a28d1af94ae44bdf8010e30618876bb7`;
- verification-routine SHA-256:
  `e5b1d4119c3a428d7468f0be777f95f79193ceacdcccc19a44cdd961e7b90eca`.

The 19 rows cover production/test separation, the locator wrapper, regular,
actual OpenMP and actual EXCH2 builds, all P1-M01/P1-M02 cases, the seven prior
P1-N04 rejection cases, and four new rejection cases for infinite origin,
infinite spacing, accumulated span overflow, and an infinite terminal stored
face.  The global spherical case also normalizes both `HUGE(oneRL)` and
`-HUGE(oneRL)` to the canonical half-open longitude interval.  Initialization
failure leaves mapping state unpublished.

The non-authoritative `p12-map-auditfix-20260824-a` directory is preserved.  It
used a NaN fixture that triggered the compiler's floating-point trap before the
production diagnostic could be observed; the replacement uses positive
infinity to exercise the same non-finite contract explicitly.  No directory
was overwritten.

## Prior authoritative mapping and locator gate

- test ID: `p12-locator-20260824-a`;
- build root:
  `/home/wyl/build/mitgcm-bom/phase01-mapping/p12-locator-20260824-a`;
- run root:
  `/home/wyl/runs/mitgcm-bom/phase01-mapping/p12-locator-20260824-a`;
- result: 15/15 summary rows passed;
- summary SHA-256:
  `24ee80deb67395b9a8c14662d26e1da66be30b76ffc284ba409f15fc66c725d7`;
- locator-source SHA-256:
  `65b5810a06ebe649d39675e33115fb8af133ea9cd3b38131afaabd4c1b43a084`;
- gate-driver SHA-256:
  `282f9091c595cd963454cb976c76af2ae93ff18c23530691c25043718b2e85dd`.

The gate passed production/test separation, the locator-wrapper audit, three
fresh debug builds, three positive mapping cases, and seven P1-N04 rejection
cases.  The wrapper audit proves that the public `BOM_LOCATE_INITIAL` symbol
calls `BOM_MAP_XY2IJLOCAL`, retains `NINT(ix/jy)` center selection and the
P1.1 `maskC` center-wet test, performs no direct `xG/yG` search, and does not
use the future wet-pair interpolator.

## Regressions after the prior locator wrapper

| Gate | Test ID | Result | Summary SHA-256 |
|---|---|---|---|
| P1.1 state/initial-file gate | `p12-locator-regression-p11-20260824` | 8/8 builds, 14/14 positive, 20/20 negative, 104/104 applicable checkpoint hashes PASS | `93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7` |
| Phase 0 final gate | `p12-locator-regression-p05-20260824` | locked references, offline Julia smoke, and formal P0.4 gate PASS | `e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2` |
| nested P0.4 gate | `p12-locator-regression-p05-20260824-p04` | 4 builds, 3 positive, 2 negative, 24/24 checkpoint hashes PASS | `af87c782d2f7b1016677c32de98512e3430bb3fafab6ba2c6c2e18eba384f97d` |

The P1.1 matrix supplies runtime evidence for unique owner selection, the
MPI4 north-east internal-corner owner, owner-center wet/dry rejection,
outside-domain rejection, and overlap-one GNU bounds checking.  Evidence is
under `/home/wyl/{build,runs}/mitgcm-bom/phase01-state/` using the stated test
ID.  Phase 0 evidence is under the corresponding `phase00-final-gate` and
`phase00-zero-particle` roots.

## Prior mapping-only authoritative gate

- test ID: `p12-map-20260824-b`;
- build root:
  `/home/wyl/build/mitgcm-bom/phase01-mapping/p12-map-20260824-b`;
- run root:
  `/home/wyl/runs/mitgcm-bom/phase01-mapping/p12-map-20260824-b`;
- result: 14/14 summary rows passed;
- summary SHA-256:
  `52d3e2b26c043d870bcb1c21169dd307b1f96d449bdcba0c76327e258f6d9bde`;
- gate-driver SHA-256:
  `543889d8a30bda3e2b36fb7044fe480a53287b75588202286f1f5f9a3d0e178a`;
- verification-routine SHA-256:
  `affee26b2513a6e8dca34e8931ab463ee8e552986d352304ef9d7a577fc9ce9f`.

| Evidence | Result |
|---|---|
| production/test source separation | PASS |
| fresh regular debug/bounds build | PASS |
| actual OpenMP build | PASS |
| actual EXCH2 build | PASS |
| P1-M01 Cartesian mapping and inverse | PASS |
| P1-M02 global spherical normalization | PASS |
| P1-M02 regional spherical non-wrapping | PASS |
| P1-N04 rotated-grid rejection | PASS |
| P1-N04 curvilinear-grid rejection | PASS |
| P1-N04 pressure-coordinate rejection | PASS |
| P1-N04 non-positive-spacing rejection | PASS |
| P1-N04 inconsistent-bound rejection | PASS |
| P1-N04 actual two-thread OpenMP rejection | PASS |
| P1-N04 actual EXCH2 rejection | PASS |

The regular build used `genmake2 -ieee -devel`; its effective flags include
GNU bounds checking, floating-point traps, debug initialization, and no
optimization.  P1-M01 explicitly distinguishes mathematical floor from
Fortran truncation: local index `-0.25` retains a valid overlap stencil while
`-1.25` does not.  P1-M02 proves that only complete 360-degree spherical
domains canonicalize equivalent longitudes; the regional case neither wraps
nor clips them.

## Prior regressions after the first mapping increment

| Gate | Test ID | Result | Summary SHA-256 |
|---|---|---|---|
| P1.1 state/initial-file gate | `p12-regression-p11-20260824` | 8/8 builds, 14/14 positive, 20/20 negative, 104/104 applicable checkpoint hashes PASS | `93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7` |
| Phase 0 final gate | `p12-regression-p05-20260824` | locked references, offline Julia smoke, and formal P0.4 gate PASS | `e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2` |
| nested P0.4 gate | `p12-regression-p05-20260824-p04` | 4 builds, 3 positive, 2 negative, 24/24 checkpoint hashes PASS | `af87c782d2f7b1016677c32de98512e3430bb3fafab6ba2c6c2e18eba384f97d` |

The P1.1 regression evidence is under
`/home/wyl/{build,runs}/mitgcm-bom/phase01-state/p12-regression-p11-20260824`.
The Phase 0 result is under
`/home/wyl/runs/mitgcm-bom/phase00-final-gate/p12-regression-p05-20260824`;
its nested P0.4 build and run roots use the test ID suffix `-p04`.

## Preserved non-authoritative attempt

`p12-map-20260824-a` stopped during the regular build because a new fixed-form
character literal extended beyond column 72.  The source was corrected by
splitting the literal, and the driver was tightened to pass `-ieee -devel`
directly to `genmake2`.  The failed directory is retained and was not
overwritten; `p12-map-20260824-b` is the authoritative result.

## Scope boundary

The completed mapping portion now publishes mapping state, longitude
normalization, forward/inverse regular-grid mapping, and a P1.1-compatible
initial locator wrapper.  It does not construct or interpolate environmental
fields, move particles, start P1.3, or authorize a `MITGCM-BOM-v0.2` tag.
