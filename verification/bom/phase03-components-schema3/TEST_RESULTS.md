# P3.4 components and schema-3 test results

Decision: **PASS; P3.4 COMPLETE; READY FOR LOCAL REVIEW**

Functional head:
`718bf351de9b896a4a496a0a9d582808006e2acd`

Unified P3 predecessor-verification head:
`990feb6ee3367a7ff679860faa27654de144497a`

Complete Phase-2 verification head:
`eeb5f0705a0e6dcad62bd058809faf4b763232cd`

Branch: `MITGCM-BOM/p3.4-components-schema3`

Environment: Ubuntu 22.04 under WSL2, GNU Fortran 11.4.0 debug/IEEE/bounds
builds and Open MPI 4.1.2. Evidence is stored outside the source repository.

## Gate results

| Gate | Result | Source head | Evidence root |
|---|---:|---|---|
| P3.4 components/schema3 direct gate | 42/42 PASS | `718bf351d` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p34-components-schema3/p34-schema3-718bf351d-attempt02` |
| Accepted P3.3 ghost/ensemble regression | 34/34 PASS | `990feb6ee` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p33-spring-ensemble/p34-p33-990feb6ee-attempt02` |
| Accepted P3.2 cutoff-graph regression | 18/18 PASS | `990feb6ee` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p32-cutoff-graph/p34-p32-990feb6ee-attempt01` |
| Accepted P3.1 reference-law regression | 34/34 PASS | `990feb6ee` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p31-reference-laws/p34-p31-990feb6ee-attempt01` |
| Complete Phase 2 predecessor regression | 390/390 PASS | `eeb5f0705` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-closure/p34-phase2-eeb5f0705-attempt02` |

Manifest-file SHA-256 values are:

- P3.4: `6fced285fe76550ca72d632428f648d311bc718e1e803b079b8a4e878f9d055d`;
- P3.3: `2eb833ed0ba657dec3c5d0cf30d95382362a800abd397367c28a93b92942cbd0`;
- P3.2: `27d4f7a8c4648837a34ea47073ae671237e42f41fd8cb178fc52b3a9e0e7ce58`;
- P3.1: `48e8d77a194c37355d72e5938af2c18e045ec7d7deab13e29d0e72158f4d3e18`;
- Phase 2: `f08f207f03b16cc1879b074392dbc5c190413e87a877f88c8b405ce02c556ec5`.

All authoritative runs captured a clean worktree. The P3.4 manifest self-check
passed for all eight recorded files; the Phase-2 independent audit confirmed
23 groups and 390/390 rows.

## Direct P3.4 coverage

- RF01 singleton, chain, reverse-order chain, ring and two-component labels;
- RF02 successive merge/split graphs with no stale label or hysteresis;
- N07 component candidate failure code 24 with unchanged output sentinels;
- serial/MPI2/MPI4 exact-ID component and raft records bitwise equal;
- Hooke/eBOMB schema-3 trajectory/pickup continuous-versus-split restart in
  serial/MPI2/MPI4, with 48/45-field schema-2 cores retained;
- exact 8-field P3 sidecar, 44-field P3 header and unchanged embedded Phase-2
  fingerprint;
- 14 missing/header/ID/raft/neighbor/spring/length/order corruptions rejected
  with code 25 before publication;
- spring-law mismatch rejected with code 25 and changed decomposition rejected
  by the retained Phase-2 signature with code 15;
- structural proof that component labels and size rendezvous do not gather a
  global all-particle list.

## Development findings closed

1. The changed-decomposition negative case initially searched `STDOUT.*`, but
   MITgcm correctly emitted failure code 15 in `STDERR.0000`. The assertion was
   corrected without changing production behavior.
2. Accepted P3.1--P3.3 gates lacked a `p34` changed-path scope. Their allowlists
   now admit the exact P3.4 files while retaining every predecessor assertion.
3. P1.4 capacity fixtures override `BOM_SIZE.h`; both reduced headers now carry
   the P3.4 component/schema constants while preserving their small capacities.

No finding changed a scientific formula, tolerance, graph definition, schema
width, exact-ID representation or restart transaction.

## Reproduction

```bash
MITGCM_BOM_EXPECTED_HEAD=718bf351de9b896a4a496a0a9d582808006e2acd \
  verification/bom/phase03-components-schema3/run_components_schema3_gate.sh

MITGCM_BOM_EXPECTED_HEAD=990feb6ee3367a7ff679860faa27654de144497a \
MITGCM_BOM_SCOPE_MODE=p34 \
  verification/bom/phase03-spring-ensemble/run_spring_ensemble_gate.sh

MITGCM_BOM_EXPECTED_HEAD=990feb6ee3367a7ff679860faa27654de144497a \
MITGCM_BOM_SCOPE_MODE=p34 \
  verification/bom/phase03-cutoff-graph/run_cutoff_graph_gate.sh

MITGCM_BOM_EXPECTED_HEAD=990feb6ee3367a7ff679860faa27654de144497a \
MITGCM_BOM_SCOPE_MODE=p34 \
  verification/bom/phase03-reference-laws/run_reference_law_gate.sh

MITGCM_BOM_EXPECTED_HEAD=eeb5f0705a0e6dcad62bd058809faf4b763232cd \
MITGCM_BOM_SCOPE_MODE=p34 \
  verification/bom/phase02-integration-closure/run_phase2_closure.sh
```

This work package does not authorize Phase 3 exit, merge, or creation of the
`MITGCM-BOM-v0.4` tag.
