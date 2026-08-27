# Phase 3 springs and distributed-neighbor test plan

Status: **FROZEN AT P3.0**

The tests below are required implementation evidence. P3.0 itself runs only
the document/scope audit because no production or executable test code is
introduced.

## 1. Evidence and execution rules

Every authoritative run must:

1. use a unique test ID and refuse to overwrite an existing evidence root;
2. build/run outside the repository;
3. record exact source head, branch, UTC/local time, compiler/MPI/Julia versions
   and an empty Git status;
4. hash all production sources, test drivers, inputs and locked references;
5. write one machine-readable summary row per frozen test row;
6. validate expected row names and counts independently;
7. preserve native manifests and validate every hash with `sha256sum -c`;
8. distinguish authoritative exact-head runs from retained development attempts;
9. require stable failure/stage/P3-phase text for expected failures;
10. prove no authoritative state, graph readiness or schedule publication on
    rollback tests.

MPI positive and negative cases run under 1, 2 and/or 4 ranks as assigned.
Process exit status alone is never sufficient because Fortran `STOP` may return
zero.

## 2. P3.0 document and scope gate

`P3-DOC01` checks:

- P3.0 branch is based exactly on v0.3 peeled commit `332a406e...`;
- changed paths are Markdown under the MITGCM-BOM documentation/verification
  namespaces;
- no `pkg/bom`, `model`, input, script, binary or generated evidence changed;
- P3-R01--P3-R18 occur exactly in the forward map;
- P3-D001--P3-D022 occur exactly in the interface decision table;
- findings P3-A--P3-J all have owners and resolutions;
- B07, B08, B09, B17, P3-Z01 and P3-G99 are assigned;
- every local Markdown link resolves;
- forbidden production-oracle and out-of-scope boundaries are present;
- Git author/committer is `WangYuLin <wang111936@outlook.com>`.

Result is `P3.0_DOC_AUDIT PASS`. It does not claim a compiled spring feature.

## 3. Zero-impact and configuration gates

### P3-Z01 v0.3 preservation

- build BOM-disabled and BOM-enabled serial/MPI4 configurations;
- run `LEEW`, `BOM+spring NONE`, FLT-only and FLT+BOM cases;
- compare trajectory, pickup, checkpoint and diagnostic hashes with accepted
  v0.3 fixtures where deterministic;
- run the full Phase 2 390-row matrix on every P3 work-package exact head;
- source/link audit proves the NONE dispatch bypasses cell, ghost, spring and
  component symbols.

### P3-C01 parameters and codes

Directly assert:

- all defaults preserve NONE/NONE;
- legal Hooke/eBOMB rows parse in SI;
- stable failures 16--25 and P3 phases 0--9 have exact numeric values;
- LEEW+spring, missing cutoff, wrong policy, nonpositive/non-finite L/k/A/Delta,
  invalid pair threshold, bad spring CFL, and non-unique periodic cutoff fail
  before state initialization;
- no old failure/stage code or schema code changes.

## 4. P3.1 reference, geometry and spring-law gates

### P3-K01 KNN oracle

Fixtures include line, square, duplicate-distance/tie, periodic-X and spherical
sets with non-contiguous 64-bit IDs.

- select exactly K non-self neighbors ordered by `(distance,ID)`;
- verify K>N-1 clamps to N-1 and N<2 rejects;
- verify odd/even deterministic median;
- permute input slots and require identical ID-sorted records;
- compare the locked Julia convention separately and record the deliberate
  self-count difference;
- source/link audit proves the oracle cannot enter the MITgcm executable.

### P3-D01 canonical pair geometry

- Cartesian axis, diagonal and large-magnitude overflow-safe norm;
- spherical zonal, meridional and diagonal pairs at multiple latitudes;
- periodic shortest image on each side and exact cell/domain ties;
- swapped call order and swapped owner/rank must return identical canonical
  low-to-high results;
- regional out-of-domain, near-pole, bad radius, non-finite and
  `d<=pairDistanceMin` return failure 17 with no output publication.

### B07 / P3-S01 Hooke

Use two equal particles in zero base flow at equilibrium, compression and
extension. Require:

- exact equal/opposite pair velocity;
- stationary centre of mass to frozen normalized tolerance;
- correct sign and `tau*k0*(L/d-1)` magnitude;
- ID/slot reversal invariance;
- RK2/RK4 relative-separation convergence against
  `d(t)=L+(d0-L)*exp(-2*tau*k0*t)`;
- serial and MPI4 direct-kernel bitwise records.

### B08 / P3-S02 eBOMB

- stiffness at `d=2L` is exactly `A/2` within roundoff;
- `d<<2L`, `d<2L`, `d>2L` and `d>>2L` have the correct monotone values/signs;
- extreme positive/negative logistic arguments remain finite without overflow;
- SI fixture with `Delta=200 m` matches locked Julia `BOMBSpring` after unit
  conversion;
- Hooke/eBOMB parameter fingerprint differences are visible in schema metadata.

### P3-N03/P3-N05 negative kernels

Inject equal IDs, zero/coincident positions, NaN/Inf, overflow-scale distance,
bad metric, bad law code, nonpositive parameters and accumulation overflow.
Require exact failure 17 or 22 and unchanged sentinels.

## 5. P3.2 cutoff and cell-linked-list gates

### P3-N01 exact graph

For small fixtures compare canonical edge records against a direct all-pairs
oracle. Include distance just below/equal/above cutoff, self copies, duplicate
owner/ghost candidates, ID ties, empty/singleton tiles and periodic images.

### P3-L01 Cartesian cell list

- half-open cell assignment at every face/corner;
- exact graph equality under shuffled owner/ghost insertion order;
- all candidates come only from enumerated cells;
- empty cells and boundary cells do not read invalid links;
- head/next traversal terminates and visits each stored record exactly once.

### P3-L02 spherical/periodic cell list

- several latitude rows with different conservative X reach;
- longitude seam and regional X boundaries;
- exhaustive points near cell/stencil limits prove no within-cutoff pair is
  missed;
- exact pair filtering removes conservative false positives;
- unsupported near-pole/topology configurations fail at setup.

### P3-N02 oracle equality

For randomized deterministic seeds and N up to the frozen oracle limit, compare
the entire owner-neighbor ID list, pair geometry, distance, stiffness and
accumulated velocity between all-pairs and production candidate paths.

### P3-N10 capacity

Deliberately overflow cell-link, candidate and per-owner neighbor storage one at
a time. Require failures 18/20, exact need/capacity diagnostics and no truncated
graph publication.

## 6. P3.3 ghost and ensemble integration gates

### P3-G01 ghost exchange

- serial same-tile, same-rank cross-tile, MPI2 and MPI4 cross-rank layouts;
- zero-owner/zero-send ranks enter the same collective sequence;
- exact high/low ID reconstruction, source rank/tile and stage/epoch labels;
- one destination and multiple relevant destinations;
- per-tile sorted ghosts and one-stage lifetime;
- byte/count counters agree with the manifest.

### P3-G02 ghost fault matrix

Mutate schema, stage, epoch, ID word, status, source, coordinate, count,
duplicate ID, spatial relevance, send/receive capacity and MPI return path.
Require failure 19 or 21 and no ghost-ready publication.

### P3-I01 ensemble RK

- all owners use the same K1--K4 stage snapshot;
- B07 analytic relative-separation convergence for RK2 and RK4;
- Phase 2 base flow plus spring has the expected centre-of-mass advection;
- diagnostics 1--25 remain the Phase 2 base values, 26/27 are total drift and
  the sidecar spring values recover the base drift;
- every stage uses its exact environment time and exact graph position;
- NONE branch remains bytewise v0.3.

### P3-I02 global rollback

For each K stage and P3 phase, inject one failure on a non-first particle and a
non-root rank. Hash all owner fields, diagnostics, graph/readiness state and
output/pickup schedules before/after. Every hash must be unchanged.

### P3-I03 stability

- accept and reject values immediately below/equal/above `bomSpringCFL`;
- repeat combined-drift advective CFL checks with spring cancellation and
  reinforcement;
- overflow injection must report finite/spring-law failure before CFL when the
  mathematical quantity cannot be formed;
- time-step refinement, not the empirical guard alone, closes accuracy.

### B09 cross-tile/cross-rank spring

The same canonical pair is placed within one tile, across two local tiles,
across MPI2 and across a four-rank corner. Compare graph, pair record, spring
velocity, every RK stage, final position and component label by exact ID.

### P3-M01 owner migration

Move interacting particles across tile/rank boundaries after a successful
substep. Require unique owners, complete P3 diagnostic/raft packet transfer,
no ghost promotion, and the same next-stage graph as a stationary-owner oracle.

### B17 decomposition invariance

Use multi-edge line, ring, two-component and periodic-seam fixtures. After
sorting by exact ID, require bitwise equality across serial/MPI2/MPI4 for:

- neighbor IDs/counts and canonical pair records;
- spring and total drift;
- K1--K4/FINAL positions and diagnostics;
- raft ID/size;
- trajectory/pickup core and canonicalized sidecar.

If bitwise equality fails, P3.3 remains open; a tolerance downgrade requires a
new reviewed design decision, not an ad hoc test relaxation.

## 7. P3.4 component and schema-3 gates

### P3-RF01 connected components

Direct fixtures: singleton, chain, ring, two components, periodic seam,
cross-tile and cross-rank chain. Require minimum-ID label and exact size for
every owner independent of edge, slot and message order.

### P3-RF02 dynamic graph

Move edges just across cutoff so components merge and split on successive
successful FINAL stages. Labels must reflect the instantaneous graph with no
bond hysteresis or stale ghost label.

### P3-P01 trajectory schema 3

- schema-2 48-field core is unchanged;
- required 8-field sidecar has exact ID alignment, time/iteration/tile count,
  spring/neighbor/raft values and checksummed metadata;
- partial core/sidecar frames are rejected by the verifier;
- LEEW schema 1 and spring-NONE BOM schema 2 remain bytewise compatible.

### P3-P02 pickup/restart

Run continuous and split same-decomposition Hooke/eBOMB cases in serial/MPI2/
MPI4. Canonicalized owner, graph, spring, raft, output and subsequent pickup
files must match bitwise.

### P3-P03 schema compatibility

- LEEW reads schema 1 only under its accepted contract;
- spring-NONE BOM reads schema 2;
- spring-enabled BOM requires schema 3;
- schema-1/2-to-spring, spring-law/parameter/decomposition changes and missing
  P3 sidecar fail before publication.

### P3-P04 corruption matrix

Mutate each header/signature code and every P3 sidecar field class; truncate,
append and reorder records. Rebuilt scratch graph/spring/components must catch
semantic corruption even when file lengths are valid. Require failure 25 and
unchanged state/schedules.

## 8. P3.5 complexity and local performance gates

### P3-X01 structural complexity

- inspect new production call graph and linked symbols;
- reject `MPI_Gather`, `MPI_Gatherv`, `MPI_Allgather`, `MPI_Allgatherv`, root
  particle lists and unconditional all-owner pair loops reachable from the
  spring-enabled driver;
- require cell/ghost/candidate/edge counters to balance;
- explicitly distinguish existing global-ID debug validation outside the
  neighbor path from prohibited neighbor construction.

### P3-X02 fixed-density baseline

Use square Cartesian lattices of `16x16`, `32x32` and `64x64` particles,
spacing `s=1000 m`, cutoff `1.01*s`, and growing domain size. The exact interior
degree is four.

- run serial, MPI2 and MPI4 where capacity permits;
- accepted degree may not exceed four except for a separately named periodic
  variant;
- candidate comparisons per owner must remain at or below the fixture bound
  frozen by the P3.2 cell geometry (target <=16);
- candidate comparisons per owner may not grow with global N;
- record wall time, rebuilds, ghost counts/bytes, min/mean/P95/max per rank and
  load imbalance;
- timing is informational on WSL; counter/graph bounds are gating.

A dense-cell fixture separately proves bounded failure rather than truncation.
Phase 5 owns 100,000-particle/256-rank target-server claims.

## 9. Work-package closeout gates

| Package | Direct groups | Mandatory regressions |
|---|---|---|
| P3.1 | Z01, C01, K01, D01, S01, S02, kernel negatives | exact Phase 2 390 rows |
| P3.2 | N01, L01, L02, N02, N10, X01 partial | accepted P3.1 and 390 rows |
| P3.3 | G01/G02, I01--I03, B09, M01, B17 dynamics | accepted P3.1/P3.2 and 390 rows |
| P3.4 | RF01/RF02, P01--P04, schema negatives | accepted P3.1--P3.3 and 390 rows |
| P3.5 | X01/X02 and P3-G99 | every accepted Phase 3 and predecessor group |

Every closeout aggregator freezes its group names and expected row counts before
the exact-head run. A group cannot be silently dropped because its driver is
slow or its result is inconvenient.

## 10. P3-G99 final integration gate

The final Phase 3 gate runs on the ordered merged production tree and includes:

- all P3.1--P3.5 direct/negative/MPI/restart/performance-counter rows;
- B07, B08, B09 and B17 in their full assigned matrices;
- the exact Phase 2 release matrix of 390 predecessor rows;
- source/link isolation for the verification oracle;
- clean source, driver/reference hashes, row audit and self-validating manifest;
- same-decomposition restart and independent FLT/BOM coexistence;
- an independent exit audit before `MITGCM-BOM-v0.4` is created.

P3-G99 may not create a tag. Tagging is authorized only after ordered work-
package integration, an exact-head PASS and a separately reviewed exit audit.

## 11. Tolerance and fixture-change rule

Analytical/bitwise assertions may not be weakened in an implementation PR. A
change to a formula, geometry, fixture, tolerance, candidate bound or expected
row count requires:

1. a named P3 decision amendment;
2. scientific/numerical justification;
3. affected requirement and test IDs;
4. regenerated reference hashes where applicable;
5. review before the production change is accepted.
