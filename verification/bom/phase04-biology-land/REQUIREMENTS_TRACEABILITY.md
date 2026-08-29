# Phase 4 requirements traceability

Status: **FROZEN AT P4.0; PRODUCTION IMPLEMENTATION NOT STARTED**

Baseline: MITGCM-BOM-v0.4 at
70c02a277ea7d472ccf6e9a7533b2b41ed7eab5a

The word frozen means the behavior, owner and evidence are fixed. It does not
mean a production feature is implemented or tested.

## 1. Forward map

| ID | Requirement | Intended production owner | Required evidence | Package | P4.0 state |
|---|---|---|---|---|---|
| P4-R01 | Preserve the exact v0.4 path, schemas, arithmetic and collectives when P4 switches are off | BOM_READPARMS, BOM_CHECK, existing BOM_MAIN dispatch | P4-Z01 plus exact 538-row predecessor gate | P4.1--P4.5 | frozen |
| P4-R02 | Validate biology/land/source parameters, units and appended stable codes without renumbering 0--25 | BOM_READPARMS, BOM_CHECK, BOM.h | P4-C01 and configuration negatives | P4.1 | frozen |
| P4-R03 | Publish complete accepted OLD/NEW T/N endpoints transactionally with exact source time and validity | BOM_BUILD_BIO_ENDPOINTS and source providers | P4-E01, source rollback, MPI4 | P4.1 | frozen |
| P4-R04 | Sample T/N at exact completed-substep time with common wet weights and explicit missing policy | BOM_INTERP_BIO_TIME | P4-E02, STOP/NO_GROWTH negatives | P4.1 | frozen |
| P4-R05 | Evaluate finite SI Brooks temperature/nutrient factors and strict amount thresholds | BOM_BROOKS_RATE, BOM_BIOLOGY_PLAN | P4-B01 and B12 analytical rows | P4.1 | frozen |
| P4-R06 | Classify wet, dry and outside attempts without relabelling numerical failures | BOM_CLASSIFY_BOUNDARY | P4-L01, B11 and failure injection | P4.2 | frozen |
| P4-R07 | Prevent dry/exterior publication and retain last accepted wet plus attempted event position | RK boundary scratch and event planner | B11 serial/MPI, stage cases | P4.2 | frozen |
| P4-R08 | Keep every owner/event mutation outside RK stages and rollback the complete event phase on failure | BOM_EVENT_TRANSACTION | P4-T01, spring/non-spring rollback | P4.2--P4.4 | frozen |
| P4-R09 | Implement distinct death/beached/outside transitions and event records | BOM_TERMINAL_PLAN, event buffer | B11, death B13 and B18 | P4.2/P4.4 | frozen |
| P4-R10 | Preserve compact owner prefixes while providing O(1) deletion/allocation and deterministic free-tail reconstruction | BOM_FREE_INIT, BOM_FREE/ALLOC/REMOVE | P4-F01 and free-list B13 | P4.2 | frozen |
| P4-R11 | Generate exact portable Philox words and angles solely from the frozen counter key and retry | BOM_PHILOX4X32, BOM_BIRTH_ANGLE | P4-RNG01, locked word fixtures, B14 | P4.3 | frozen |
| P4-R12 | Retry wet placement deterministically, cancel after the bound and restore parent Sbefore | BOM_BIRTH_PLACE | P4-BR01, B13/B14 land/outside cases | P4.3 | frozen |
| P4-R13 | Globally sort accepted parents by exact ID and assign contiguous decomposition-independent child IDs | BOM_BIRTH_ORDER, BOM_BIRTH_IDS | P4-ID01, B13/B14/B17 | P4.3 | frozen |
| P4-R14 | Preflight global/live/tile/packet/event capacity and fail closed without truncation | BOM_EVENT_PREFLIGHT | B19 and rollback sentinels | P4.3/P4.5 | frozen |
| P4-R15 | Migrate complete parent/S/birth state with packet schema 3 and rebuild post-event graph/components atomically | BOM_PARTICLE_EXCHANGE, event graph integration | P4-M01, B13/B17 | P4.3 | frozen |
| P4-R16 | Preserve released core/P3 bytes while transactionally writing and validating the required P4 sidecar and event schema | schema-4 output/event owners | P4-S01, corruption matrix | P4.4 | frozen |
| P4-R17 | Restart same-decomposition runs bitwise with P4 owners, counters, T/N brackets, event buffers and schedules | schema-4 pickup owners | B15 continuous/split serial/MPI | P4.4 | frozen |
| P4-R18 | Close live/event/ID/free-stack/mass diagnostics exactly once per successful substep | BOM_EVENT_BUDGET and diagnostics | B18 plus failure rollback | P4.4 | frozen |
| P4-R19 | Produce bitwise-equivalent canonical biology, births, terminal events, IDs and records in serial/MPI2/MPI4 | all P4 collective paths | B14, B17 and schema/event comparisons | P4.1--P4.5 | frozen |
| P4-R20 | Close Phase 4 only with all direct gates, exact v0.4 predecessor matrix, independent audit and no Phase 5/6 scope leakage | P4-G99 and exit-audit drivers | B11--B15, B17--B19, P4-G99 | P4.5 | frozen |

## 2. Reverse implementation map

| Interface or state | Requirements | Minimum evidence |
|---|---|---|
| Phase 4 parameters and codes | P4-R01--P4-R02 | P4-Z01, P4-C01, configuration negatives |
| accepted T/N endpoints and interpolation | P4-R03--P4-R04 | P4-E01/E02, MPI4 and rollback |
| Brooks law and biology plan | P4-R05, P4-R08 | P4-B01, B12, arithmetic negatives |
| boundary classifier and RK terminal scratch | P4-R06--P4-R09 | P4-L01, B11, P4-T01 |
| compact-tail free stack | P4-R08--P4-R10 | P4-F01, B13 removal/reuse |
| Philox and placement retry | P4-R11--P4-R12, P4-R19 | P4-RNG01, P4-BR01, B14 |
| global event order and IDs | P4-R13--P4-R14, P4-R19 | P4-ID01, B13/B14/B17/B19 |
| owner packet schema 3 and post-event graph | P4-R15, P4-R19 | P4-M01, B13/B17 |
| schema-4 trajectory/P4 sidecar/event shards | P4-R16, P4-R18 | P4-S01, B18, corruption matrix |
| pickup schema 4 | P4-R16--P4-R17 | B15 serial/MPI and corruption matrix |
| event budgets and diagnostics | P4-R09, P4-R18--P4-R19 | B18 and canonical records |
| P4-G99 and exit audit | P4-R01--P4-R20 | all registered P4 and exact 538 predecessor rows |

## 3. Evidence semantics

- A document-only audit can close P4.0 scope, but cannot verify P4-R01--P4-R20
  production behavior.
- A serial law test cannot close MPI ordering, event transaction, migration or
  restart requirements.
- An expected failure must prove the stable failure, RK/P4 phase, first-failure
  tuple and unchanged authoritative state.
- An event proposal is not an accepted event and may not increment a counter.
- Timing is informational in Phase 4. Phase 5 owns target-server performance.
- Verified status requires an immutable exact source head, external evidence
  root, row-count audit, source/driver/reference hashes and empty captured Git
  status.

## 4. Work-package closure map

| Package | Requirements that may close | Accepted predecessor |
|---|---|---|
| P4.0 | design/scope closure only | annotated v0.4 and Phase 3 exit evidence |
| P4.1 | P4-R02--P4-R05 and focused P4-R01/P4-R19 portions | exact 538 v0.4 gate |
| P4.2 | P4-R06--P4-R10 and transaction portions | accepted P4.1 |
| P4.3 | P4-R11--P4-R15 and distributed P4-R19 portions | accepted P4.1/P4.2 |
| P4.4 | P4-R16--P4-R18 and restart/output P4-R19 portions | accepted P4.1--P4.3 |
| P4.5 | final P4-R01/P4-R14/P4-R19/P4-R20 and complete audit | accepted P4.1--P4.4 |

## 5. Phase 4 exit requirement

Phase 4 cannot close until every P4-R01--P4-R20 row is verified, B11--B15 and
B17--B19 pass in their full serial/MPI/restart/corruption matrices, P4-G99
reruns the exact 538-row v0.4 predecessor matrix, and an independent audit
finds no production-path gather of live owners, no partial event publication,
no released-schema change and no unrecorded scope amendment.
