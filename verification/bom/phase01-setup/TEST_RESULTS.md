# P1.3 first production increment results

Date: 2026-08-24

Source branch: `MITGCM-BOM/phase-01-single-tile-integration`

Source commit: `dd0cf58adf2c3b7f3dbb4e2d4a7fa684a0bd062b`

Author and committer: `WangYuLin <wang111936@outlook.com>`

## Result

The first frozen P1.3 implementation increment is **PASS**.  It implements
only setup numerical preflight, the immutable expected initial-owner count,
and BOM-owned `NONE`/EXF wind snapshots.  The dedicated component gate and
all required predecessor regressions passed on the source commit above.

| Gate | Test ID | Result | `summary.tsv` SHA-256 |
|---|---|---:|---|
| P1.3 setup component | `p13-setup-final-component-20260824-a` | 17/17 PASS | `e1e9cebc8907d67eaaeeceb762e2593b1c2542f59e226c6896172233a6c5312f` |
| P1.1 state/initial input | `p13-setup-final-state-20260824-a` | 42/42 PASS | `93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7` |
| P1.2 field construction | `p13-setup-final-field-20260824-a` | 7/7 PASS | `d60d74a5539bc42351e4efbd995c2d8ca337bb33af5d9e1998b174170a92b768` |
| P1.2 mapping/locator | `p13-setup-final-mapping-20260824-a` | 19/19 PASS | `926575f1093bb7353f09e9835e175289a309c13e653ded5a96871e06b3810c02` |
| P1.2 interpolation/lifecycle | `p13-setup-final-interp-20260824-a` | 15/15 PASS | `aaff9205a4f5faa580d06fe55b18720bbcd42a72667caae7b5f27fd4632c13d4` |
| Phase-0 final gate | `p13-setup-final-phase0-20260824-a` | 4/4 PASS | `e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2` |
| nested P0.4 formal gate | `p13-setup-final-phase0-20260824-a-p04` | 9/9 PASS | `af87c782d2f7b1016677c32de98512e3430bb3fafab6ba2c6c2e18eba384f97d` |

The compact P1.3 artifact manifest records the same source commit.  Its
`source-head.txt` SHA-256 is
`576ceae9b5a81fab9eead431e0a98a6c7eeb0536b779c4c7315ef727cf479c97`.

## External evidence roots

- component build:
  `/home/wyl/build/mitgcm-bom/phase01-single-tile/p13-setup-final-component-20260824-a`;
- component run:
  `/home/wyl/runs/mitgcm-bom/phase01-single-tile/p13-setup-final-component-20260824-a`;
- compact component artifact:
  `/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/p13-setup-final-component-20260824-a`;
- P1.1 state run:
  `/home/wyl/runs/mitgcm-bom/phase01-state/p13-setup-final-state-20260824-a`;
- P1.2 field, mapping, and interpolation runs:
  `/home/wyl/runs/mitgcm-bom/phase01-{fields,mapping,interp}/p13-setup-final-*-20260824-a`;
- Phase-0 result:
  `/home/wyl/runs/mitgcm-bom/phase00-final-gate/p13-setup-final-phase0-20260824-a`;
- nested P0.4 result:
  `/home/wyl/runs/mitgcm-bom/phase00-zero-particle/p13-setup-final-phase0-20260824-a-p04`.

Build trees, executables, full logs, generated MDS input, and runtime output
remain outside the repository.

## Verified behavior

- `BOM_CHECK` uses standard IEEE finite classification under GNU invalid,
  zero, and overflow traps; NaN target step, wind coefficient, and CFL produce
  controlled BOM failures rather than process-level floating-point traps.
- The substep ratio is bounded against the host integer range before division
  and before `CEILING`; the accepted `1200/300` case reports `nSub=4` and
  `dtSub=300 s`.
- `bomNPartExpected` resets to zero and publishes only after complete initial
  input/owner validation; P1.1 serial/MPI logs show it equals the accepted
  global owner count.
- `bomWindSource='NONE'` publishes deterministic zero arrays with request-time
  metadata.  EXF copies constant 10 m east/north wind to BOM-owned arrays,
  masks dry cells, exchanges both components as scalars, and leaves the EXF
  source arrays unchanged in serial and MPI4.
- EXF not compiled, EXF disabled, atmospheric wind disabled, nonzero
  coefficient with `NONE`, unsupported source, lower time endpoint, and
  excessive substep ratio are all rejected before field publication.

## Findings closed during the increment

1. Constant EXF test values were moved from `EXF_NML_02` to their declared
   `EXF_NML_03` group.
2. The lower wind-time guard now includes the IEEE-rounded endpoint.
3. Equality-based NaN checks were replaced with `IEEE_IS_FINITE`, and
   compound conditions were split so correctness does not depend on Fortran
   short-circuit evaluation.
4. Integer-range rejection now occurs before ratio division, preventing the
   debug floating-point trap from pre-empting the BOM diagnostic.

## Boundary

This result does not complete P1.3.  `BOM_RHS_LEEWAY`, Cartesian/spherical
coordinate rates, stage CFL and state validation, release splitting, RK2,
RK4, motion, `BOM_CHECK_STATE`, owner migration, trajectory output,
pickup/restart, and FLT coexistence remain later increments.  Draft PR #13
must remain Draft; this record does not authorize Ready state, merge, or a
version tag.
