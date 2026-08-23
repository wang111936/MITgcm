# P0.5 Phase-0 final gate results

Date: 2026-08-23

Branch: `MITGCM-BOM/phase-00-final-gate`

Parent commit: `083e4b79d872d091b615cbf05fb9dd031e41b98f`

Test ID: `p05-attempt01`

## Command

```bash
MITGCM_BOM_TEST_ID=p05-attempt01 \
MITGCM_BOM_MAKE_JOBS=4 \
  verification/bom/phase00-final-gate/run_gate.sh
```

P0.5 result root:
`/home/wyl/runs/mitgcm-bom/phase00-final-gate/p05-attempt01`

Fresh P0.4 build root:
`/home/wyl/build/mitgcm-bom/phase00-zero-particle/p05-attempt01-p04`

Fresh P0.4 run root:
`/home/wyl/runs/mitgcm-bom/phase00-zero-particle/p05-attempt01-p04`

## Static checks

- `bash -n run_gate.sh`: passed;
- `shellcheck run_gate.sh`: passed with no findings;
- source line endings: passed;
- driver mode is `100755`; Julia and Markdown files are `100644`.

## Locked reference checks

| Item | Expected | Result |
|---|---|---|
| SargassumBOMB commit | `156557359185e4413ce82829f3ed26a4eb8c6283` | matched |
| SargassumRegistry commit | `02961aced4cfa2b3430ebd4b44cdb7a3056e7175` | matched |
| `Project.toml` SHA-256 | `12cfb1288a21b19216662a719d430bf41b5587dfd8b00e973f8b3c9c25f1f99d` | locked copy and checkout matched |
| `Manifest.toml` SHA-256 | `86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695` | locked copy and checkout matched |
| tracked checkout state | no staged or unstaged source changes | passed |

`Pkg.instantiate` completed with `JULIA_PKG_OFFLINE=true` and the dedicated
depot. No dependency update or network resolution was requested.

## Julia smoke

| Check group | Result |
|---|---|
| package load and version | passed |
| equirectangular coordinate round trip | passed |
| date/time round trip and week arithmetic | passed |
| center of mass and range utility | passed |
| disabled spherical-correction branches | passed |

The Julia `Test` summary reported 8/8 assertions passed with Julia 1.10.12 and
SargassumBOMB 0.7.14. Package initialization reported the previously documented
warning that no default environmental interpolants could be constructed. The
smoke deliberately requires none of those fields and did not request downloads.

This smoke does not call the stale `Examples.generate_rp_example` entry point
and is not a trajectory golden test.

## Fresh P0.4 rerun

| Gate | Result |
|---|---|
| builds | 4/4 passed |
| positive serial/MPI runs | 3/3 passed |
| expected rank normal-end logs | 1/1, 2/2, and 4/4 |
| checkpoint SHA-256 checks | 24/24 matched |
| negative gates | 2/2 expected rejection |

No positive rank log contained an abnormal or fatal marker. The two negative
cases remained log-aware and were not misclassified by their process status 0.

## Non-overwrite safety

Reusing `MITGCM_BOM_TEST_ID=p05-attempt01` was rejected before Julia or P0.4
execution because the P0.5 result root already existed. Historical evidence was
not overwritten.

## Post-merge integrated rerun

After PR #1 through #5 were merged in order, the complete gate was rerun from
the updated `MITGCM-BOM/development` branch.

Verified commit:
`2baea214fe1f898e16df4953892c142a07b82111`

Test ID: `p05-integrated-attempt01`

```bash
MITGCM_BOM_TEST_ID=p05-integrated-attempt01 \
MITGCM_BOM_MAKE_JOBS=4 \
  verification/bom/phase00-final-gate/run_gate.sh
```

| Gate | Integrated result |
|---|---|
| locked references | passed |
| offline Julia instantiate | passed |
| Julia smoke | 8/8 passed |
| P0.4 builds | 4/4 passed |
| positive serial/MPI runs | 3/3 passed |
| rank normal-end logs | 1/1, 2/2, and 4/4 |
| checkpoint SHA-256 | 24/24 matched |
| negative gates | 2/2 expected rejection |
| reused P0.5 test ID | rejected before overwrite |

The integrated result root is
`/home/wyl/runs/mitgcm-bom/phase00-final-gate/p05-integrated-attempt01`.
Its derived P0.4 build and run ID is `p05-integrated-attempt01-p04`.
See `INTEGRATION_RESULTS.md` for the merge-commit map and full integration
decision.

## Verdict

`P0.5 GATE PASS`

All executable Phase-0 exit criteria are satisfied, the stacked PR chain is
integrated, and the post-merge gate passed. Phase 0 is marked `complete`. The
Julia reference remains `PROVISIONAL` for trajectory-golden purposes; that
limitation belongs to later physics validation. No version tag was created as
part of the gate or this record.
