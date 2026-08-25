# P2.1 environmental endpoint state gate

This verification case covers the first P2.1 production increment without
activating the not-yet-connected environmental providers or slow-manifold
RHS. It verifies:

- the frozen Phase-2 runtime parameter contract and safe defaults;
- overflow-safe conversion of `bomTauDays` to `bomTau` seconds;
- stable source, endpoint, failure, and diagnostic-stage codes;
- deterministic initialization of both accepted environmental endpoints;
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
