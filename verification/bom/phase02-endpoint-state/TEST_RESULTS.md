# P2.1 endpoint-state and transaction test results

Status: **P2.1 COMPLETE ON EXACT FUNCTIONAL COMMIT; 301/301 CLOSURE PASS**

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

## Environmental stage-time interpolation authoritative increment

- source commit: `83913ce594158f3c5e52907f56e5f69881ad9791`;
- branch: `MITGCM-BOM/p2.1-environment-endpoints`;
- environment: Ubuntu 22.04, GNU debug/IEEE build, OpenMPI;
- test ID: `p21-envtime-83913ce59-attempt02`;
- command:

```bash
MITGCM_BOM_TEST_ID=p21-envtime-83913ce59-attempt02 \
verification/bom/phase02-endpoint-state/run_endpoint_state_gate.sh
```

The exact committed source adds the stateless, read-only
`BOM_INTERP_ENV_TIME` production interface. For a normal accepted bracket it
copies exact or tolerance-snapped endpoint values, linearly interpolates
interior stage values, and returns one constant OLD/NEW secant. It neither
clamps nor extrapolates and never writes accepted COMMON state. A fresh
duplicated publication is treated as a legal single-time bracket: only its
endpoint is accepted and its time derivative is exactly zero.

| Case | Result | Evidence |
|---|---|---|
| build-serial | PASS | production and test interpolation symbols linked |
| build-mpi4 | PASS | four-rank production and test symbols linked |
| build-production-serial | PASS | production interface without test override |
| bom-env-time-serial | PASS | snap, midpoint/split, secant and dry validity |
| bom-env-time-mpi4 | PASS | identical assertions on four ranks |
| previous 29 cases | PASS | endpoint providers, policy, production and negative regressions |

All 34 summary rows are `PASS`. P2-N02 directly rejects non-finite stage or
endpoint times, reversed brackets, wrong interval or iteration continuity,
unpublished state, and stage times outside the accepted range. Failures carry
OLD/NEW endpoint context, return zero invalid candidates, and leave the full
accepted bracket bitwise unchanged. Exact endpoint outputs are also checked
bitwise; dry points remain invalid exact zero values.

Evidence root:
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state/p21-envtime-83913ce59-attempt02`.

| File | SHA-256 |
|---|---|
| `summary.tsv` | `af80775a11cf86fb999e1707898c6c837d8732f9925eb6d1adfda7045c0d0201` |
| `source-head.txt` | `6681aadaea3bd24c28456aa4fd1390eaa28498fae20c2793d5886b4faecf0554` |
| `manifest.sha256` | `5ce71d924c6c23d8262c71c3bbd377e81d74e103143baf3e1b199f6c2b09cf5b` |

The non-authoritative `p21-envtime-8bcaf4f64-attempt01` stopped during the
first serial test-driver compile because two helper routines lacked size
includes and one fixed-form string exceeded the column limit. Those test-only
issues were corrected before the authoritative commit and no failed test ID
was reused.

This increment closes the P2.1 field-value portion of P2-R07 and accepts
P2-E06/P2-N02 for endpoint time interpolation. P2.1 remains open only for the
schema-2 field pickup increment. It adds no endpoint spatial derivatives,
slow-manifold RHS, particle RK-stage wiring, merge, tag, or release.

## Schema-2 endpoint pickup authoritative increment

- exact functional head: `41d0dbc20404df1759a7a5d1b274bc85d5c415fd`;
- principal production commit: `df67380a803a7c675ee8c4456f693ecbbd88a022`;
- compatibility commits: `c603fc706` and `41d0dbc20`;
- branch: `MITGCM-BOM/p2.1-environment-endpoints`;
- environment: Ubuntu 22.04, GNU debug/IEEE build, OpenMPI;
- pickup test ID: `p21-pickup-41d0dbc20-attempt01`;
- endpoint regression ID: `p21-endpoint-41d0dbc20-attempt01`.

Schema 2 adds an exact fingerprint for mode, equation/current/Stokes/wind
policy, SI parameters, schedule, forcing configuration, endpoint metadata,
decomposition and compiled provider capabilities. In the current build its
logical signature has 1332 values and is written as fixed 24-value MDS
records, avoiding dependence on the model-grid MDS buffer size.

Each globally numbered tile has a separate endpoint sidecar containing OLD
and NEW Eulerian, Stokes and wind east/north fields, validity masks and exact
time/iteration/readiness metadata, including halos. Reads validate signature,
sidecars and particle tiles in scratch storage; accepted fields, particle
state, labels and readiness are published only after the global preflight.
Spatial derivatives are intentionally rebuilt deterministically from restored
endpoints in P2.2 rather than persisted as independent authoritative state.

LEEW retains the exact schema-1 signature and particle layout: its signature
is 128 bytes and it writes no endpoint sidecar. A schema-1 pickup requested in
BOM mode is rejected before particle or field commit. Coupler identity is
represented by the explicit source selection and compiled capability because
the current runtime API has no stable external producer identifier; a future
provider-ID extension requires a new schema rather than silent reinterpretation.

| Case | Result | Evidence |
|---|---|---|
| build-serial | PASS | production debug build and schema-2 symbols |
| build-mpi4 | PASS | four-rank production debug build |
| schema2-write | PASS | fingerprint, particle files and endpoint sidecars |
| schema2-read | PASS | scratch preflight and zero-particle atomic restore |
| stokes-bitwise | PASS | nonzero FILES Stokes continuous/split step-2 pickup identity |
| leew-schema1 | PASS | unchanged 128-byte signature and restart |
| schema1-bom-reject | PASS | early stable schema failure |
| parameter-fingerprint | PASS | legal changed SI tau rejected exactly |
| endpoint-preflight | PASS | truncated sidecar rejected before commit |
| mpi4-schema2 | PASS | globally tiled four-rank write and restart |

All 10 pickup rows are `PASS`. Development attempt 01 exposed an invalid
close on MPI ranks that do not open the global signature; the production fix
closes only a positive file unit. The next exact run passed MPI4 write/read.
The P1.4 regression then exposed two verification-only `BOM_SIZE.h` overrides
that lacked the new constants; both were synchronized and P1.4 passed 36/36.
P1.1 retained the same pre-initialization LEEW/FILES rejection while its
diagnostic matcher was made stable across the more precise Phase-2 wording.

Evidence roots:

```text
pickup:
  /home/wyl/projects/mitgcm-bom-test-artifacts/phase02/
  p21-pickup/p21-pickup-41d0dbc20-attempt01
endpoint:
  /home/wyl/projects/mitgcm-bom-test-artifacts/phase02/
  p21-endpoint-state/p21-endpoint-41d0dbc20-attempt01
closure:
  /home/wyl/projects/mitgcm-bom-test-artifacts/phase02/
  p21-closure/p21-closure-41d0dbc20-attempt02
```

| File | SHA-256 |
|---|---|
| pickup `summary.tsv` | `90f92e9ef047433f47f53d993a2a4392258668df3551fc74c17e3ad5db29e132` |
| pickup `manifest.sha256` | `9f3446ec0a48fc09f59139641a367488abc6e7672b67e7dee495869d2bdf330f` |
| endpoint `summary.tsv` | `af80775a11cf86fb999e1707898c6c837d8732f9925eb6d1adfda7045c0d0201` |
| endpoint `manifest.sha256` | `e607f9eb47d79cbe7a377bf2f6bc4d418d06a1568bfd8a8159012357e563c8e7` |
| closure `row-audit.tsv` | `7b15d0540f5d1228760e93e879ce8e8b9b45d47a0307865ebd4d55a1fa442559` |
| closure `manifest.sha256` | `423c679704876f68a4962f56c43bfe02f66a38f6088ef4914228170d61774d9c` |

## P2.1 closure decision

The exact functional head passed 15 predecessor groups (257/257), the full
endpoint/provider gate (34/34), and the schema-2 pickup gate (10/10), for an
aggregate 301/301. Eleven native manifests, every summary row, the exact
source head and an empty Git status were independently revalidated by the
closure artifact.

P2.1 therefore closes P2-R03--P2-R05, the field-value portion of P2-R07, and
the field-state/schema-preflight portion of P2-R16/P2-R18. P2-R02 and P2-R06
retain their RHS diagnostic consumers, while full nonzero-particle restart,
same-decomposition P2-P03, coexistence and final integration remain P2.5.
P2.2 derivatives are the only next implementation scope. No P2.3 RHS,
P2.4 stage integration, PR merge, release or `MITGCM-BOM-v0.3` tag is claimed.
