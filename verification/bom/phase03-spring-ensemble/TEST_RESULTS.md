# P3.3 ghost and spring ensemble test results

Decision: **PASS; FUNCTIONALLY COMPLETE; READY FOR DRAFT REVIEW**

Production and complete predecessor functional head:
`53f9670ee97e7b793f4a1ac164f46c1ce30c1abf`

Unified direct-verification head:
`9b9ea50df28a5ce1e405b903d78fe6dbc9120eb0`

Branch: `MITGCM-BOM/p3.3-spring-ensemble`

Environment: Ubuntu 22.04 under WSL2, GNU Fortran 11.4.0 debug/IEEE/bounds
builds, Open MPI 4.1.2, and Julia 1.10.12 for the accepted P3.1 reference
gate. Evidence is stored outside the source repository.

## Gate results

| Gate | Result | Source head | Evidence root |
|---|---:|---|---|
| P3.3 ghost/ensemble direct gate | 34/34 PASS | `9b9ea50df2` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p33-spring-ensemble/p33-spring-9b9ea50df2-attempt01` |
| Accepted P3.2 cutoff-graph regression | 18/18 PASS | `9b9ea50df2` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p32-cutoff-graph/p32-cutoff-9b9ea50df2-attempt01` |
| Accepted P3.1 reference-law regression | 34/34 PASS | `9b9ea50df2` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p31-reference-laws/p31-reference-9b9ea50df2-attempt01` |
| Complete Phase 2 predecessor regression | 390/390 PASS | `53f9670ee9` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-closure/p33-phase2-53f9670ee-attempt01` |

Manifest-file SHA-256 values are:

- P3.3: `eb9bdf2702b216844a63774a63834ee0b74e276112d3e67ebea07c2f14b67316`;
- P3.2: `cdf16710771b0e6464c9f644a8647b1f60010cd2b5c13d8789c8e8f952054436`;
- P3.1: `3ec9a9d05cc0988a26f3f12d2120c280c4dc4a10b5e905f352e9ae468b75b159`;
- Phase 2: `0945fe9d9f3dc1118dc9271451b28317c409c38fb72639aad090152251a51241`.

The authoritative direct runs captured an empty Git status. The Phase 2 run
also performed its independent row, provenance, source-hash and evidence
audit before reporting 390/390.

## Direct P3.3 coverage

The frozen 34-row matrix contains:

- serial, MPI2 and MPI4 debug/IEEE/bounds builds with the P3.3 production
  symbols linked;
- P3-G01 version-1 exact-ID ghost exchange, same-rank and cross-rank routes,
  sorted per-tile publication, zero-count collective participation and
  one-stage lifetime;
- P3-G02 schema/stage/epoch/source/duplicate/capacity fault handling with no
  partial ghost publication;
- P3-I01 synchronized all-owner RK2/RK4 stage snapshots with the accepted
  Phase 2 RHS plus spring contribution;
- P3-I02 nominal-substep rollback of owner state, diagnostics, graph readiness
  and schedules after injected stage failures;
- P3-I03 spring-number and combined advective-CFL acceptance/rejection paths;
- B09 same-tile, cross-tile and cross-rank canonical spring interaction;
- P3-M01 one post-commit owner migration using packet schema 2, including
  spring, neighbor and reserved raft fields without ghost promotion;
- B17 canonical exact-ID dynamics records that are bitwise equal for
  serial/MPI2/MPI4;
- structural rejection of gather/allgather neighbor construction and a
  fixed-form line-length audit.

## Development findings closed

1. The version-2 owner packet invalidated P1.4's schema-1 source expectations
   and its reduced `BOM_SIZE.h` headers. The predecessor gate was made
   schema-aware without changing its small capacity limits; all 36 P1.4 rows
   then passed inside the 390-row closure.
2. The accepted P3.1 eBOMB configuration originally enabled raft diagnostics.
   In `p33` mode that is now disabled because component/raft computation is a
   frozen P3.4 responsibility. Hooke/eBOMB laws, SI values, Julia comparison
   and negative configuration tests remain unchanged and pass 34/34.

Neither finding required a scientific formula, tolerance, graph definition or
P3.0 interface amendment.

## Reproduction

```bash
MITGCM_BOM_EXPECTED_HEAD=9b9ea50df28a5ce1e405b903d78fe6dbc9120eb0 \
  verification/bom/phase03-spring-ensemble/run_spring_ensemble_gate.sh

MITGCM_BOM_EXPECTED_HEAD=9b9ea50df28a5ce1e405b903d78fe6dbc9120eb0 \
MITGCM_BOM_SCOPE_MODE=p33 \
  verification/bom/phase03-cutoff-graph/run_cutoff_graph_gate.sh

MITGCM_BOM_EXPECTED_HEAD=9b9ea50df28a5ce1e405b903d78fe6dbc9120eb0 \
MITGCM_BOM_SCOPE_MODE=p33 \
  verification/bom/phase03-reference-laws/run_reference_law_gate.sh
```

P3.3 does not authorize merge, connected-component/raft publication,
schema-3 trajectory/pickup support, Phase 3 exit, or a
`MITGCM-BOM-v0.4` tag.
