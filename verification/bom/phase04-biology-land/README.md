# MITGCM-BOM Phase 4 biology, land and events

Status: **P4.4 LOCALLY COMPLETE; P4.5 NOT STARTED**

Phase 4 adds temperature/nutrient-driven Brooks amount, distinct terminal
events, deterministic births, reusable compact owner slots, event diagnostics
and schema-4 restart to the released Phase 3 particle/spring system. The target
release is MITGCM-BOM-v0.5.

## Baseline

- annotated base tag: MITGCM-BOM-v0.4;
- tag object: 67ac22063a4860e30c504624f1530f853d29f1a2;
- peeled commit: 70c02a277ea7d472ccf6e9a7533b2b41ed7eab5a;
- final predecessor gate: 538/538 PASS;
- locked Julia commit: 156557359185e4413ce82829f3ed26a4eb8c6283;
- local admission platform: Ubuntu 22.04, GNU Fortran 11.4.0,
  Open MPI 4.1.2 and Julia 1.10.12.

## Frozen documents

- [P4.0 source audit](P4.0_SOURCE_AUDIT.md) records v0.4 and locked-Julia
  behavior, discrepancies and their required resolution;
- [P4.0 interface freeze](P4.0_INTERFACE_FREEZE.md) fixes parameters, fields,
  Brooks law, boundary/event transactions, compact-tail reuse, Philox,
  birth IDs, schemas, MPI semantics and package boundaries;
- [requirements traceability](REQUIREMENTS_TRACEABILITY.md) maps
  P4-R01--P4-R20 to production owners and executable evidence;
- [test plan](TEST_PLAN.md) freezes B11--B15/B17--B19 and P4-G99 gates;
- [P4.0 design audit](P4.0_DESIGN_AUDIT.md) records the immutable 15/15
  executable document/scope/reference audit.
- [P4.1 closeout](P4.1_CLOSEOUT.md) records the accepted field/Brooks scope,
  exact 31/31 direct gate and exact 538/538 predecessor replay.
- [P4.2 closeout](P4.2_CLOSEOUT.md) records the accepted boundary/terminal/
  free-stack scope, exact 18/18 direct gate, P4.1 31/31 replay and exact
  538/538 predecessor replay.
- [P4.3 closeout](P4.3_CLOSEOUT.md) records exact Philox/retry/global-ID,
  packet schema 3 and atomic post-event graph integration, the 26/26 direct
  gate and all accepted predecessor replays.
- [P4.4 closeout](P4.4_CLOSEOUT.md) records schema-4 framing, transactional
  event shards, diagnostics, same-decomposition restart, the 57/57 direct
  gate and all accepted predecessor replays.

## Work packages

| Package | Scope | Required closeout | State |
|---|---|---|---|
| P4.0 | source/design/interface/test freeze | 15/15 document/scope audit; no production diff | locally complete |
| P4.1 | parameters/codes, accepted T/N endpoints, stateless Brooks | P4-Z01/C01/E01/E02/B01 and B12; exact 538 predecessor | locally complete |
| P4.2 | boundary scratch, terminal state machine, compact-tail free stack | P4-L01/F01/T01, B11 and death/free-stack B13 | locally complete |
| P4.3 | Philox, retry, global birth order/IDs, packet schema 3, graph integration | P4-RNG01/BR01/ID01/M01, B13/B14/B17 | locally complete |
| P4.4 | schema 4, event shards, diagnostics and pickup | P4-S01/EV01, B15/B18 | locally complete |
| P4.5 | capacity and full integration closeout | B19, P4-G99 and independent exit audit | not started |

Packages are sequential. Each completed implementation package needs a clean
exact-head evidence root, immutable source/driver/reference hashes,
expected/actual row audit, self-validating manifest and complete accepted
predecessor gates.

## Compatibility boundary

- BOM is an independent MITgcm package with its own state, integration,
  migration and I/O; `FLT+BOM` names only a coexistence compatibility
  regression and creates no FLT runtime dependency.
- P4 switches default off and must preserve the exact v0.4 path.
- LEEW remains non-biological schema 1.
- BOM without springs/P4 remains schema 2.
- spring-enabled BOM without P4 remains schema 3.
- any land/biology event path uses container schema 4.
- the schema-2 core and conditional released P3 sidecar are not widened.
- changed-decomposition restart remains rejected.
- Phase 4 is one-way and regular-grid; OpenMP/target scaling and general grids
  remain later phases.

## Unique next production task

After P4.4 is reviewed and integrated, the only next production package is
P4.5:

1. close the complete B19 equality/overflow capacity matrix;
2. rerun all accepted Phase 4 direct groups at the final exact head;
3. execute P4-G99 with the exact 538-row v0.4 predecessor matrix;
4. perform the independent Phase 4 exit audit;
5. integrate the exit record before considering annotated v0.5.

P4.4 does not claim the final B19 capacity matrix, P4-G99, Phase 4 exit or
target-server scaling; those remain P4.5/Phase 5 work.

P4.4 executes `run_p44_gate.sh`: 57/57 rows cover pure-Fortran SHA-256,
transactional multi/empty/failure event flushes, independent canonical event
audits, schema-2 pickup/trajectory preservation, schema-4 manifests and P4
owner/T/N sidecars, NONE/EBOMB continuous/split restart in serial/MPI2/MPI4,
bitwise P3/P4/Philox/ID continuity, 16 corruption classes and changed-
decomposition rejection. Exact-head and predecessor evidence are recorded in
`P4.4_CLOSEOUT.md`.
