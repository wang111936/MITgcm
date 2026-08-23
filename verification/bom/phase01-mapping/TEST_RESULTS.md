# P1.2 first mapping increment results

Status: **PASS**

## Authoritative mapping gate

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

## Regressions after the mapping increment

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

This increment publishes mapping state, longitude normalization, and forward
and inverse regular-grid mapping.  It does not replace `BOM_LOCATE_INITIAL`,
construct or interpolate environmental fields, move particles, start P1.3,
or authorize a `MITGCM-BOM-v0.2` tag.
