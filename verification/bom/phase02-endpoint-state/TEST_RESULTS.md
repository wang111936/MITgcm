# P2.1 endpoint-state and transaction test results

Status: **PASS ON EXACT FUNCTIONAL COMMIT; P2.1 REMAINS IN PROGRESS**

## Authoritative source and command

- source commit: `920e22fbdcdf7ceb59f2bd795cad86d116ac21af`;
- branch: `MITGCM-BOM/p2.1-environment-endpoints`;
- environment: Ubuntu 22.04, GNU debug/IEEE build, OpenMPI;
- test ID: `p21-endpoint-920e22fbd-attempt01`;
- command:

```bash
MITGCM_BOM_TEST_ID=p21-endpoint-920e22fbd-attempt01 \
MITGCM_BOM_MAKE_JOBS=4 \
verification/bom/phase02-endpoint-state/run_endpoint_state_gate.sh
```

The worktree was clean at the recorded source commit. Builds, runs, and
generated evidence were created outside the repository.

## Result matrix

| Case | Result | Evidence |
|---|---|---|
| source-contract | PASS | frozen production names present; test symbols absent from `pkg/bom` |
| build-serial | PASS | GNU debug compile/link and endpoint symbols |
| build-mpi4 | PASS | MPI debug compile/link and endpoint symbols |
| bom-serial | PASS | converted parameters and all endpoint/source cells initialized deterministically |
| bom-mpi4 | PASS | same assertions after global four-rank reduction |
| leew-compat | PASS | Phase-1 defaults retain `UNSET`, no BOM-only rejection, normal end |
| current-unset | PASS | rejected before initialization |
| nan-alpha | PASS | non-finite parameter rejected |
| tau-overflow | PASS | days-to-seconds overflow rejected before multiplication |
| none-sigma | PASS | `NONE` plus nonzero sigma rejected |
| duplicate-files | PASS | `PRECOMBINED` plus explicit FILES rejected |
| bad-files | PASS | invalid FILES precision and metadata rejected |
| coupler-unavailable | PASS | unavailable provider hook rejected |

All 13 summary rows are `PASS`. The negative cases use expected log text and
fatal markers because an MITgcm Fortran `STOP` may return process status 0.

## Evidence locations and hashes

```text
build:
  /home/wyl/build/mitgcm-bom/phase02-endpoint-state/
  p21-endpoint-920e22fbd-attempt01
run:
  /home/wyl/runs/mitgcm-bom/phase02-endpoint-state/
  p21-endpoint-920e22fbd-attempt01
artifact:
  /home/wyl/projects/mitgcm-bom-test-artifacts/phase02/
  p21-endpoint-state/p21-endpoint-920e22fbd-attempt01
```

| File | SHA-256 |
|---|---|
| `summary.tsv` | `29453e3305d6d6a43bb8b055995417109644e3a53dbf5a5f93b38e1969440293` |
| `source-head.txt` | `b1b6a573fd73c7b5020fe5c1db08ec23f3721236f6c15c3232e78c26c8a7ae07` |
| `manifest.sha256` | `41594903587b8848901bfd1dc0dac823c74c013c9681d38f868dd95fac72043a` |

## Development attempts retained outside Git

- attempt `a` exposed a repeated-include declaration issue and two fixed-form
  strings beyond column 72;
- attempts `b` and `c` exposed invalid new-test `eedata` and `data.pkg`
  entries; production checks had already compiled;
- attempts `d` and `e` passed before the functional commit, with `e` adding
  the reproducible `LEEW` compatibility run;
- no failed directory was reused or overwritten.

## First-increment scope conclusion

This result accepts the first P2.1 increment only: runtime parameters,
stable codes, and deterministic accepted endpoint storage. Nonzero `BOM`
particles remain explicitly unavailable. Exact-time ocean/wind/Stokes
providers, transactional publication, interpolation, and field pickup are
still required before P2.1 can close. No P2.2 derivative or P2.3 RHS code is
present, and no `MITGCM-BOM-v0.3` tag was created.

## Transactional publisher authoritative increment

- source commit: `b81bb01293dbc4279db544174efe9558382115a3`;
- branch: `MITGCM-BOM/p2.1-environment-endpoints`;
- environment: Ubuntu 22.04, GNU debug/IEEE build, OpenMPI;
- test ID: `p21-transaction-b81bb0129-attempt01`;
- command:

```bash
MITGCM_BOM_TEST_ID=p21-transaction-b81bb0129-attempt01 \
verification/bom/phase02-endpoint-state/run_endpoint_state_gate.sh
```

The exact committed source adds independent transaction scratch storage,
fresh duplicated endpoints, normal accepted-NEW to scratch-OLD advancement,
ocean rotation/colocation, exact `NONE` wind/Stokes fields, and atomic commit.

| Case | Result | Evidence |
|---|---|---|
| source-contract | PASS | production lifecycle hooks present; test markers isolated |
| build-serial | PASS | GNU debug transaction build |
| build-mpi4 | PASS | MPI4 debug transaction build |
| build-production-serial | PASS | unmodified production lifecycle build |
| bom-serial | PASS | fresh, two normal advances, continuity/source rollback |
| bom-mpi4 | PASS | same endpoint, halo, validity and rollback assertions on four ranks |
| production-one-step | PASS | production fresh hook and one normal zero-particle step |
| leew-compat | PASS | accepted Phase-1 defaults and normal end preserved |
| current-unset | PASS | missing current policy rejected |
| nan-alpha | PASS | non-finite parameter rejected |
| tau-overflow | PASS | seconds conversion overflow rejected |
| none-sigma | PASS | invalid NONE/sigma policy rejected |
| duplicate-files | PASS | duplicate explicit Stokes rejected |
| bad-files | PASS | invalid FILES metadata rejected |
| coupler-unavailable | PASS | unavailable provider rejected |

All 15 summary rows are `PASS`. Direct component checks prove that accepted
metadata, all Eulerian values, auxiliary zero fields, and all validity masks
remain unchanged after continuity and source failures.

| File | SHA-256 |
|---|---|
| `summary.tsv` | `7f6bd0426866908bd83a79ae29cf9c11a96940ff795a1e6fe8ceedf76ddd8ee5` |
| `source-head.txt` | `251bc886149c104b1f2a60d08a19bba5de6af1314e46845a0d7be5fc66dc4380` |
| `manifest.sha256` | `8d5b36b33e884f19029c5e11613a31a9fdc88279caae28bee472e1761a05877c` |

Evidence root:
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state/p21-transaction-b81bb0129-attempt01`.
The interrupted `p21-transaction-dev-gate02` and passing pre-commit
`p21-transaction-dev-gate03` remain outside Git and were not reused.

This increment accepts the ocean/`NONE`/`NONE` transaction only. P2.1 still
required exact-time EXF wind, explicit Stokes providers, stage interpolation,
and field pickup at that recorded commit.

## Exact-time EXF wind authoritative increment

- source commit: `43a79d1b14761cc355861e11b76a4d702c78cc80`;
- branch: `MITGCM-BOM/p2.1-environment-endpoints`;
- environment: Ubuntu 22.04, GNU debug/IEEE build, OpenMPI;
- test ID: `p21-exf-43a79d1b1-attempt01`;
- command:

```bash
MITGCM_BOM_TEST_ID=p21-exf-43a79d1b1-attempt01 \
verification/bom/phase02-endpoint-state/run_endpoint_state_gate.sh
```

The exact committed source adds a BOM-owned `BOM_GET_EXF_WIND` provider.
It resolves paired regular EXF records for the requested endpoint, proves
physical record coverage before EXF I/O, evaluates both components in
BOM-owned current/record arrays, rotates and masks the result, and returns
source failure without publishing accepted state. It never aliases or writes
the EXF `uwind`, `vwind`, `uwind0/1`, or `vwind0/1` arrays.

| Case | Result | Evidence |
|---|---|---|
| build-exf-serial | PASS | EXF+BOM GNU debug compile/link and provider symbols |
| build-exf-mpi4 | PASS | EXF+BOM MPI4 debug compile/link and provider symbols |
| build-production-exf-serial | PASS | unmodified production EXF lifecycle build |
| bom-exf-serial | PASS | P2-E03 exact values, immutable globals, six P2-N03 rollbacks |
| bom-exf-mpi4 | PASS | identical assertions after four-rank global reductions |
| production-exf-one-step | PASS | production fresh endpoint and one normal EXF step |
| previous 15 cases | PASS | ocean/NONE/NONE transaction, production, LEEW and policy regressions |

All 21 summary rows are `PASS`. The P2-E03 records are spaced by 1800 s
while ocean endpoints advance by 1200 s. Independent expectations are
`(1,-2)` at 0 s, `(3,0)` at 1200 s, and `(5,2)` at 2400 s. The test
sets all six EXF global wind arrays to deterministic sentinels and compares
their transferred 64-bit representations after every successful and failed
transaction. P2-N03 covers missing, unpaired, physically partial, future
uncovered, stale/short, and non-finite files; every row returns
`BOM_FAIL_FIELD_SOURCE/BOM_STAGE_FIELD_NEW` with the complete accepted
bracket bitwise unchanged.

Evidence locations:

```text
build:
  /home/wyl/build/mitgcm-bom/phase02-endpoint-state/
  p21-exf-43a79d1b1-attempt01
run:
  /home/wyl/runs/mitgcm-bom/phase02-endpoint-state/
  p21-exf-43a79d1b1-attempt01
artifact:
  /home/wyl/projects/mitgcm-bom-test-artifacts/phase02/
  p21-endpoint-state/p21-exf-43a79d1b1-attempt01
```

| File | SHA-256 |
|---|---|
| `summary.tsv` | `5cb541c823e3f6bfa57064627c063970d9f85f548ceedd8b4838da4cb4e39c86` |
| `source-head.txt` | `918832c76fe8904bc1cfdeea44af0a7dc076980b65c4a8e793964bf1db4e3a42` |
| `manifest.sha256` | `18f85fb2675d19d1403c88fa468c4307ba3f2822dd1716ba4d9aaf959e02f7b0` |

Development evidence remains outside Git and no test ID was reused:

- `p21-exf-dev-noexf01/02` exposed malformed preprocessor/file termination
  in the initial local patch; `p21-exf-dev-noexf03` restored 15/15;
- `p21-exf-dev01` exposed one fixed-form marker beyond column 72;
- `p21-exf-dev02` passed all 21 cases before the functional commit.

This increment accepts P2-R04/P2-E03 and the EXF-owned rows of P2-N03.
P2.1 remains in progress: FILES then COUPLER Stokes providers, stage-time
interpolation, and schema-2 field pickup remain. No P2.2 derivative, P2.3
RHS, `MITGCM-BOM-v0.3` tag, merge, or release is claimed.

## Exact-time FILES Stokes authoritative increment

- source commit: `16ab457e321ba6751488e7dda861b25be1626252`;
- branch: `MITGCM-BOM/p2.1-environment-endpoints`;
- environment: Ubuntu 22.04, GNU debug/IEEE build, OpenMPI;
- test ID: `p21-stokes-16ab457e3-attempt01`;
- command:

```bash
MITGCM_BOM_TEST_ID=p21-stokes-16ab457e3-attempt01 \
MITGCM_BOM_MAKE_JOBS=4 \
verification/bom/phase02-endpoint-state/run_endpoint_state_gate.sh
```

The exact committed source adds a BOM-owned `BOM_GET_STOKES` FILES
provider without an EXF package dependency. It preflights paired global
two-dimensional MITgcm records, resolves the exact requested time bracket,
interpolates and applies `bomStokesInScale` in BOM-owned arrays, rotates
model-grid U/V to geographic east/north, applies the C mask, exchanges
halos, and returns source failure without publishing accepted state.

| Case | Result | Evidence |
|---|---|---|
| build-serial | PASS | no-EXF GNU debug compile/link with Stokes provider symbol |
| build-mpi4 | PASS | no-EXF MPI4 debug compile/link with provider symbol |
| build-production-serial | PASS | unmodified production lifecycle build |
| bom-stokes-serial | PASS | P2-E04 exact values/repeat cycle plus seven P2-N03 rollbacks |
| bom-stokes-mpi4 | PASS | identical assertions after four-rank reductions |
| production-stokes-one-step | PASS | production fresh endpoint and one normal FILES step |
| previous 18 cases | PASS | ocean/NONE, EXF, production, LEEW and policy regressions |

All 24 summary rows are `PASS`. Three big-endian 64-bit records are spaced
by 1800 s and repeat every 5400 s while model endpoints advance by 1200 s.
After input scale 2, the independent Stokes U/V expectations are `(2,-4)`
at 0 s, `(6,0)` at 1200 s, `(10,4)` at 2400 s, `(14,8)` at 3600 s,
`(6,0)` at 4800 s across the periodic seam, and `(4,-2)` at 6000 s.
The test independently rotates those values with `angleCosC/angleSinC`,
forces deterministic dry C points, and verifies exact-zero invalid dry state.

P2-N03 covers missing, unpaired, physically partial, future-uncovered,
stale/short, non-finite, and non-integral repeat-cycle sources. Every case
returns `BOM_FAIL_FIELD_SOURCE/BOM_STAGE_FIELD_NEW`, and transferred 64-bit
comparisons prove that all accepted fields, masks, labels, iterations and
readiness remain unchanged. A clean retry then crosses the repeat seam.

Evidence locations:

```text
build:
  /home/wyl/build/mitgcm-bom/phase02-endpoint-state/
  p21-stokes-16ab457e3-attempt01
run:
  /home/wyl/runs/mitgcm-bom/phase02-endpoint-state/
  p21-stokes-16ab457e3-attempt01
artifact:
  /home/wyl/projects/mitgcm-bom-test-artifacts/phase02/
  p21-endpoint-state/p21-stokes-16ab457e3-attempt01
```

| File | SHA-256 |
|---|---|
| `summary.tsv` | `7303b90e046d3baf66a123684f22518671354d4b47e7bcd0972154ebb6c94fbc` |
| `source-head.txt` | `53e3d2dabb7c8f75fc383d80908dba92dbcb98bf26635b0827f51e765672ce21` |
| `manifest.sha256` | `c9323e66e324cc214c4834b725e20e3f2c28ec9952c3836532ce26bc678f1cfc` |

Development evidence remains outside Git and no test ID was reused:

- `p21-stokes-files-dev01` exposed two missing `SIZE.h` includes in test-only
  helpers;
- `p21-stokes-files-dev02` built all configurations and exposed a stale
  nonzero wind coefficient in the `wind=NONE` test input;
- a targeted serial rerun then passed, and `p21-stokes-files-dev03` passed
  all 24 cases before the functional commit.

This increment accepts P2-E04 and the FILES portion of P2-R05/P2-N03.
P2.1 remains in progress: COUPLER Stokes, P2-E05 policy/provider coverage,
stage-time interpolation, and schema-2 field pickup remain. No P2.2
derivative, P2.3 RHS, `MITGCM-BOM-v0.3` tag, merge, or release is claimed.

## Compiled COUPLER Stokes authoritative increment

- source commit: `6247ee6ba0fd1e796047bff944558c8e80c3511f`;
- branch: `MITGCM-BOM/p2.1-environment-endpoints`;
- environment: Ubuntu 22.04, GNU debug/IEEE build, OpenMPI;
- test ID: `p21-coupler-6247ee6ba-attempt01`;
- command:

```bash
MITGCM_BOM_TEST_ID=p21-coupler-6247ee6ba-attempt01 \
MITGCM_BOM_MAKE_JOBS=4 \
verification/bom/phase02-endpoint-state/run_endpoint_state_gate.sh
```

The exact committed source adds an explicitly compiled COUPLER Stokes API.
`BOM_SET_COUPLER_STOKES` validates and copies geographic east/north C-point
components separately into BOM-owned storage. Component readiness, time, and
iteration labels become visible only after a complete valid copy. The provider
requires both components at the exact requested endpoint, exchanges BOM work
halos, validates the mask, and enters the existing atomic endpoint transaction.

| Case | Result | Evidence |
|---|---|---|
| build-coupler-serial | PASS | setter/provider compile and link |
| build-coupler-mpi4 | PASS | MPI4 setter/provider compile and link |
| build-production-coupler-serial | PASS | no test lifecycle override |
| bom-coupler-serial | PASS | copied fresh/normal endpoints and rollback |
| bom-coupler-mpi4 | PASS | identical four-rank assertions |
| bom-coupler-sigma-zero | PASS | active COUPLER with zero sigma is legal |
| production-precombined-none | PASS | legal embedded-current/NONE row |
| duplicate-coupler | PASS | illegal explicit plus embedded Stokes rejected |
| previous 24 cases | PASS | ocean/NONE, EXF, FILES, production and policy regressions |

All 32 summary rows are `PASS`. Producer arrays are overwritten with sentinels
after each setter call and the copied endpoint values remain exact, directly
proving no alias. P2-N03 covers missing, partial, stale, future, mixed labels,
wrong iteration, non-finite wet values, and nonzero dry values. Every failed
transaction returns `BOM_FAIL_FIELD_SOURCE/BOM_STAGE_FIELD_NEW` and preserves
the complete accepted bracket bitwise; an exact clean pair then retries.

Evidence root:
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state/p21-coupler-6247ee6ba-attempt01`.

| File | SHA-256 |
|---|---|
| `summary.tsv` | `87375f0d0003f240854e4c5738982c007b7b84e422d9d00c195933a2d7314dec` |
| `source-head.txt` | `1ab5c214e74ccc2a014f636af2f25d107822111493200731f2e14fbec4a58d40` |
| `manifest.sha256` | `d6d4b47e276b2e684aaa254dc63defa586526e01f886cf3c4cec43fa47bbce49` |

This increment closes the P2-R05 NONE/FILES/COUPLER endpoint-provider scope
and the endpoint policy-matrix part of P2-R06. P2.1 remains open for P2-E06
stage-time interpolation and schema-2 field pickup. It adds no spatial
derivative, slow-manifold RHS, particle stage wiring, merge, or v0.3 tag.
