# P2.1 environmental endpoint state gate

This verification case covers the complete P2.1 production scope. It validates
parameter/state initialization and transactional exact-time ocean, `NONE`,
EXF-wind, FILES Stokes, and compiled COUPLER
Stokes endpoint publication without activating the slow-manifold RHS. It verifies:

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
- a compile-time `ALLOW_BOM_STOKES_COUPLER` capability boundary;
- per-component geographic C-point publication through
  `BOM_SET_COUPLER_STOKES`, with BOM-owned copies and no producer alias;
- exact component time/iteration labels and complete east/north availability;
- serial/MPI4 fresh, normal, OLD/NEW and clean-retry COUPLER transactions;
- rollback for missing, partial, stale, future, mixed-label, wrong-iteration,
  non-finite and invalid dry-point COUPLER publications;
- legal EULERIAN COUPLER rows with nonzero or zero sigma, legal
  PRECOMBINED/NONE, and duplicate PRECOMBINED/COUPLER rejection;
- exact/tolerance endpoint snapping, interior linear stage-time values,
  and a constant OLD/NEW time secant for every environmental source;
- legal fresh single-time brackets and fatal non-finite, reversed,
  discontinuous, interval-mismatched, or out-of-bracket requests;
- production fresh initialization and one normal zero-particle step;
- serial and four-rank MPI compilation/runtime behavior;
- fail-fast current/Stokes policy and file-metadata checks;
- no change to the accepted Phase-1 `LEEW` field state.
- schema-2 exact mode, parameter, schedule, decomposition and provider
  fingerprint validation;
- OLD/NEW Eulerian, wind and Stokes endpoint sidecars with exact labels,
  masks and fresh-duplicate checks;
- scratch-only read preflight followed by one field/particle metadata commit;
- nonzero FILES Stokes continuous/split pickup bitwise identity;
- unchanged LEEW schema-1 128-byte signature and no endpoint sidecar;
- schema-1-to-BOM, changed-parameter and truncated-sidecar early rejection;
- serial and MPI4 schema-2 write/read behavior;
- complete Phase-1/Phase-0 257/257 predecessor regression.

Run from any directory:

```bash
verification/bom/phase02-endpoint-state/run_endpoint_state_gate.sh
verification/bom/phase02-endpoint-state/run_pickup_gate.sh
```

Builds, runs, and evidence are written outside the source tree under the
configured `MITGCM_BOM_TEST_*_ROOT` locations. The production package does
not contain verification markers or test-only assertion routines.

P2.1 is complete on its recorded exact functional commit. Spatial derivatives
and the slow-manifold RHS remain outside this verification directory; P2.2 is
the next work package.
