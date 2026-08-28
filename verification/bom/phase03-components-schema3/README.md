# P3.4 distributed components and container schema 3

Status: **FUNCTIONAL IMPLEMENTATION COMPLETE; CLEAN-HEAD EVIDENCE PENDING**

This verification case implements the P3.4 work package frozen by
`../phase03-springs-neighbors/P3.0_INTERFACE_FREEZE.md`.

Production scope:

- deterministic connected components on the instantaneous FINAL cutoff graph;
- raft ID equal to the minimum exact global particle ID and exact raft size;
- distributed label/size rendezvous without a global all-particle gather;
- container schema 3 while retaining the schema-2 core and Phase-2 files;
- required 8-field P3 trajectory/pickup sidecars and a P3 signature that embeds
  the accepted Phase-2 fingerprint unchanged;
- transactional same-decomposition restart that rebuilds and validates graph,
  spring, neighbor and raft diagnostics before its single authoritative commit.

Run the exact-head gate with:

```bash
MITGCM_BOM_EXPECTED_HEAD="$(git rev-parse HEAD)" \
verification/bom/phase03-components-schema3/run_components_schema3_gate.sh
```

The gate builds serial, MPI2 and MPI4 debug/IEEE/bounds executables, requires
42/42 rows, compares canonical records and schema-3 artifacts bitwise, runs
Hooke/eBOMB continuous-versus-restart cases, and rejects 14 deterministic
corruptions before publication.

P3.5 remains responsible for fixed-density scaling, final work/communication
counters, P3-G99, the complete Phase 3 exit audit and the v0.4 tag decision.
