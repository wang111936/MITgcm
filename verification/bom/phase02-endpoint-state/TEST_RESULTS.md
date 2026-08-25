# P2.1 first-increment test results

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

## Scope conclusion

This result accepts the first P2.1 increment only: runtime parameters,
stable codes, and deterministic accepted endpoint storage. Nonzero `BOM`
particles remain explicitly unavailable. Exact-time ocean/wind/Stokes
providers, transactional publication, interpolation, and field pickup are
still required before P2.1 can close. No P2.2 derivative or P2.3 RHS code is
present, and no `MITGCM-BOM-v0.3` tag was created.
