# P1.2 wet-pair interpolation results

Status: **PASS — COMPONENT, PRODUCTION LIFECYCLE, AND CALLER FAILURE GATES**

## Authoritative interpolation gate

- functional commit:
  `2f346d98cf978922cae53bff67fc32088cbb8941`;
- test ID: `p12-interp-auditfix-20260824-c`;
- build root:
  `/home/wyl/build/mitgcm-bom/phase01-interp/p12-interp-auditfix-20260824-c`;
- run root:
  `/home/wyl/runs/mitgcm-bom/phase01-interp/p12-interp-auditfix-20260824-c`;
- result: 15/15 summary rows passed;
- summary SHA-256:
  `aaff9205a4f5faa580d06fe55b18720bbcd42a72667caae7b5f27fd4632c13d4`;
- production caller SHA-256:
  `51c04d341ae74480838534fa231cb64a2c3373b5247d55ca42a6382a8d16eb8f`;
- production interpolation SHA-256:
  `40397acf41c45e9cce2d903838b4ced35e424c75cecf105bde4cc1624b3ddb20`;
- gate-driver SHA-256:
  `60a3750543130f3080d0fa3c81a5eae7059e87be0cbdb0545b9197c92f114f08`;
- verification-routine SHA-256:
  `7b3914ebca1a0a5d0d0d09361d7cb5abbb41af4bc30874c77ebe03eaef521fd3`.

| Evidence | Result |
|---|---|
| production/test source separation and interface contract | PASS |
| serial debug/bounds build and symbols | PASS |
| MPI4 debug/bounds build and symbols | PASS |
| P1-F03 FULL serial/MPI4 | 2/2 PASS |
| P1-F03 PARTIAL serial/MPI4 | 2/2 PASS |
| P1-N05 invalid contracts serial/MPI4 | 2/2 PASS |
| production `BOM_MAIN` lifecycle serial/MPI4 | 2/2 PASS |
| caller outside-domain termination serial/MPI4 | 2/2 PASS |
| caller low-wet-weight termination serial/MPI4 | 2/2 PASS |

P1-F03 proves constant preservation at negative fractional overlap indices,
fully wet affine-field exactness, exact-threshold acceptance, dry-value
exclusion, and one normalized weight set shared by east and north.  P1-N05
proves safe invalid returns for unpublished fields, incomplete low/high
stencils, infinite and huge finite coordinates, non-finite pair fields,
insufficient wet weight, and invalid tile indices.  Invalid calls return zero
velocity values; an insufficient wet stencil retains its actual weight for a
caller diagnostic.  The production lifecycle cases additionally prove exact
preservation of owner counts, ID, status, position, release time, and age while
the mapping and velocity diagnostic fields are updated.  Caller negatives
prove contextual collective termination for an outside position and an
insufficiently wet stencil.

## Regressions after the interpolation increment

| Gate | Test ID | Result | Summary SHA-256 |
|---|---|---|---|
| P1.2 field construction | `p12-field-auditfix-20260824-a` | 7/7 PASS | `97d21381200a8c8314de96302d790bb4aa995092a100bb9b83e42f27840d4492` |
| P1.2 mapping/locator | `p12-map-auditfix-20260824-b` | 19/19 PASS | `926575f1093bb7353f09e9835e175289a309c13e653ded5a96871e06b3810c02` |
| P1.1 state/initial file | `p12-auditfix-p11-20260824-a` | 8 builds, 14 positive, 20 negative, 104/104 checkpoint PASS | `93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7` |
| Phase 0 final gate | `p12-auditfix-phase0-20260824-a` | 4/4 PASS | `e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2` |
| nested P0.4 gate | `p12-auditfix-phase0-20260824-a-p04` | 4 builds, 3 positive, 2 negative, 24/24 checkpoint PASS | `af87c782d2f7b1016677c32de98512e3430bb3fafab6ba2c6c2e18eba384f97d` |

All build and run evidence remains outside the repository under the stated
`/home/wyl/{build,runs}/mitgcm-bom` roots.  No evidence directory was reused or
overwritten.  Two earlier correction attempts are retained as
non-authoritative: `p12-interp-auditfix-20260824-a` exposed an inconsistent
lifecycle fixture, while `-b` exposed missing MPI stderr aggregation in the
driver.  Both test-infrastructure defects were corrected before the
authoritative `-c` run.

## Scope boundary

The wet-pair component and production `BOM_MAIN` caller have executable
P1-F03/P1-N05 evidence, and the final review in
`../phase01-bom-lite/P1.2_SCOPE_AUDIT.md` is PASS.  No particle RHS, position
update, owner migration, wind or Stokes field, trajectory, pickup, P1.3 code,
or v0.2 tag is included.
