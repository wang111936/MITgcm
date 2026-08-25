# P2.1 environmental endpoint state gate

This verification case covers the first four focused P2.1 production
increments. It validates parameter/state initialization and transactional
exact-time ocean, `NONE`, EXF-wind, and BOM-owned FILES Stokes endpoint
publication without activating the slow-manifold RHS. It verifies:

- the frozen Phase-2 runtime parameter contract and safe defaults;
- overflow-safe conversion of `bomTauDays` to `bomTau` seconds;
- stable source, endpoint, failure, and diagnostic-stage codes;
- deterministic initialization of both accepted environmental endpoints;
- fresh duplicated and normal OLD/NEW endpoint publication;
- surface-ocean rotation, mask, halo and source-validity behavior;
- exact zero `NONE` wind and Stokes providers;
- accepted-state preservation after time-continuity and source failures;
- BOM-owned EXF current/record work arrays and exact endpoint evaluation;
- EXF records spaced at 1800 s against 1200 s ocean endpoints;
- independent wind interpolation/rotation oracles in serial and MPI4;
- bitwise preservation of EXF `uwind/vwind` current and record globals;
- transactional rejection of missing, partial, stale, future and NaN records;
- BOM-owned Stokes record/work arrays with no EXF package dependency;
- 1800 s FILES interpolation, input scaling, C-mask and 5400 s repeat cycle;
- independent Stokes interpolation/rotation oracles in serial and MPI4;
- bitwise rollback for missing, partial, stale, future, NaN and bad-cycle
  Stokes sources;
- production fresh initialization and one normal zero-particle step;
- serial and four-rank MPI compilation/runtime behavior;
- fail-fast current/Stokes policy and file-metadata checks;
- no change to the accepted Phase-1 `LEEW` field state.

Run from any directory:

```bash
verification/bom/phase02-endpoint-state/run_endpoint_state_gate.sh
```

Builds, runs, and evidence are written outside the source tree under the
configured `MITGCM_BOM_TEST_*_ROOT` locations. The production package does
not contain verification markers or test-only assertion routines.

P2.1 remains open. COUPLER Stokes, stage-time interpolation, and schema-2
field pickup are not claimed here. Spatial derivatives and the slow-manifold
RHS remain outside this verification directory.
