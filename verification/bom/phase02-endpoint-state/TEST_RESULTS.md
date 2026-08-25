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
