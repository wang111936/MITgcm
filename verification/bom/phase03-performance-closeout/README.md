# P3.5 performance and Phase 3 closure gate

This directory closes the local Phase 3 complexity and fixed-density
obligations frozen by P3.0. It does not claim target-server scale; the
100,000-particle/256-rank target and ocean-model overhead remain Phase 5 work.

## Production coverage

`BOM_P3_COUNTER_SNAPSHOT` and `BOM_P3_REDUCE_COUNTERS` expose 14 accepted
per-rank counters and exact global sums/maxima:

1. owner records;
2. ghost records;
3. non-empty cells;
4. candidate comparisons;
5. directed accepted neighbors;
6. undirected edges;
7. maximum neighbors per owner;
8. rebuild count;
9. ghost packets sent;
10. ghost packets received;
11. ghost bytes sent;
12. ghost bytes received;
13. maximum component size;
14. component iterations.

The authoritative counters change only after successful production
transactions. Failed validation or reduction leaves caller output sentinels
unchanged. The global reduction represents signed non-negative 64-bit values
as five base-32768 digits and uses portable integer MPI reductions; it does not
depend on a compiler-specific 64-bit MPI datatype.

The P3-X02 run found that tile-routed ghost copies could be repeated in a
rank-wide cell list. `BOM_SPRING_STAGE` now sorts routed ghosts by exact ID,
validates repeated copies, omits same-rank owner copies and compacts the remote
set before building the cell list. This preserves the frozen graph while
keeping work proportional to local density rather than the number of tiles.

## Direct gate

`run_performance_gate.sh` builds GNU debug/IEEE serial, MPI2 and MPI4 cases and
runs 20 registered rows:

- source scope, linked-symbol and production-call-path audits;
- the 14-counter publication/reduction/overflow contract;
- exact values above 32-bit range and rollback on invalid reduction input;
- Cartesian and spherical 16x16, 32x32 and 64x64 fixed-density lattices;
- 1000 m spacing, 1.01-spacing cutoff and a growing physical domain;
- comparison-per-owner bound at or below 16 and non-growing with global N;
- ghost-per-boundary-owner bounds for MPI2/MPI4;
- a five-neighbor dense fixture that must fail at the verification-only
  capacity of four without publishing a truncated graph;
- wall-clock min/mean/P95/max and imbalance as informational WSL metadata.

Production `bomMaxNeighbor` remains 10000. Only the test override sets it to
four for the dense negative case.

## P3-G99 modes

`../phase03-integration-closure/run_p3_g99.sh` freezes six groups and 538 rows:

| Group | Rows |
|---|---:|
| P3.5 performance/complexity | 20 |
| P3.4 components/schema 3 | 42 |
| P3.3 ghost/ensemble | 34 |
| P3.2 cutoff graph | 18 |
| P3.1 reference laws | 34 |
| Phase 2 release predecessor | 390 |
| Total | 538 |

Candidate mode runs on the local P3.5 package branch and is evidence for
review. Final mode is intentionally restricted to the ordered merged
`MITGCM-BOM/development` head and requires the P3.5 package head to be an
ancestor. Neither mode creates a tag.

`run_phase3_exit_audit.sh` is a separate post-integration action. It checks the
P3.4/P3.5 merge order, exact final P3-G99 evidence, known commit identities and
the absence of `MITGCM-BOM-v0.4`. It must not be used to approve a candidate
branch.

See `TEST_RESULTS.md` and `../phase03-springs-neighbors/P3.5_CLOSEOUT.md` for
the accepted local-candidate evidence and remaining integration boundary.
