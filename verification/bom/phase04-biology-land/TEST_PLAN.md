# MITGCM-BOM Phase 4 test plan

Status: **P4.3 EXECUTED; P4.4--P4.5 FROZEN**

P4.0 ran only the document/scope audit. P4.1--P4.3 now have accepted direct
and predecessor evidence recorded in their closeout files; P4.4--P4.5 rows
remain future obligations and may not be reported as executed.

## 1. Common evidence rules

Every production gate:

- runs against one named clean exact commit;
- writes build/run output outside the repository under a unique attempt ID;
- refuses to overwrite an existing evidence root;
- records compiler, MPI, Python and platform versions;
- records source, driver, fixture and reference SHA-256 values;
- captures Git status before and after;
- distinguishes expected-failure STOP text from shell exit status;
- writes expected and actual row lists and rejects missing, duplicate or extra
  rows;
- writes a self-validating manifest and independent row audit;
- never changes a tolerance or expected value inside the production patch
  being evaluated.

Serial, MPI2 and MPI4 mean one, two and four MPI ranks with supported regular
tile layouts. Canonical owner rows are sorted by exact ID. Canonical event rows
are sorted by
(eventTimeIndex,eventType,subjectId,parentId).

## 2. P4.0 document and scope gate

The repository-external read-only P4.0 audit requires:

1. the branch base equals v0.4 peeled commit 70c02a277e;
2. the annotated tag object equals 67ac22063a4860e30c504624f1530f853d29f1a2;
3. the locked Julia checkout is clean at 156557359185e4413ce82829f3ed26a4eb8c6283;
4. only the exact P4 Markdown allowlist differs from v0.4;
5. pkg/bom, model, executable drivers, inputs and reference data have no diff;
6. P4-R01--P4-R20 occur once and in order;
7. P4-D001--P4-D028 occur once and in order;
8. P4-A--P4-L occur once and in order;
9. B11--B15, B17--B19 and P4-G99 are registered;
10. Brooks, compact-tail, Philox, parent-ID ordering, schema 4 and event-budget
    contracts are present;
11. every relative Markdown link resolves;
12. diff whitespace and isolation scans pass;
13. frozen Julia source hashes match;
14. project status/phase record name P4.1 as the unique next production task;
15. the freeze does not claim compiled Phase 4 evidence.

Aggregate result is P4.0_DOC_AUDIT PASS 15/15.

## 3. P4.1 configuration and endpoint gates

### P4-Z01 zero-impact compatibility

Build/run the released v0.4 modes with every P4 switch off:

- LEEW/schema 1;
- BOM spring NONE/schema 2;
- BOM HOOKE/schema 3;
- BOM EBOMB/schema 3;
- FLT+BOM coexistence compatibility cases from the predecessor matrix; these
  prove collision-free simultaneous enablement and do not make BOM depend on
  FLT.

Require the existing dispatch, schemas, output/pickup bytes and registered
predecessor summaries to match v0.4. The source call graph must prove no T/N
field build or biology arithmetic is reachable with P4 disabled.

### P4-C01 parameter and code contract

Directly assert:

- existing status, failure, RK and P3 phase values are unchanged;
- P4 event/failure/phase values equal the freeze;
- all new defaults are inactive;
- valid THETA/PTRACER and THETA/FILES configurations are accepted;
- biology in LEEW, biology without land, NONE required sources, invalid
  missing policy, invalid file time/precision, absent PTRACER, bad tracer
  index, non-finite values, invalid T/S ranges, zero kN, non-positive birth
  tries and non-positive birth distance are rejected before state changes.

### P4-E01 accepted T/N endpoint transaction

Fixtures cover:

- fresh OLD=NEW publication at start;
- normal OLD<-previous NEW, NEW<-current advance;
- surface theta with Nr>1 to prove one-level shape;
- selected PTRACER and FILES endpoints;
- scalar halo equality in serial/MPI4;
- exact source time, iteration, repeat-cycle and scale;
- wet/dry validity;
- failed source, halo, time, non-finite and continuity injection;
- clean retry after failure.

On every failed row, all accepted arrays, validity, source metadata and times
remain bitwise sentinel values.

### P4-E02 exact-time interpolation and missing policy

At OLD time, midpoint and NEW time, verify linear T/N interpolation and common
wet weights. Include nonuniform fields, periodic X, partial-wet allowed
stencils, insufficient wet weight and out-of-bracket time.

STOP must return failure 27 without S mutation. NO_GROWTH must use growth=0,
retain finite mortality, increment only its diagnostic candidate and leave the
accepted endpoint bracket unchanged.

## 4. P4.1 Brooks and B12 gates

### P4-B01 stateless Brooks kernel

Compare an independent high-precision oracle for:

- T below Tmin, equal Tmin, interior lower branch, equal Topt, interior upper
  branch, equal Tmax and above Tmax;
- N negative, zero, small, equal kN, large and near representable extremes;
- zero/nonzero growth and mortality;
- S/dt values near safe arithmetic limits;
- non-finite inputs and forced overflow.

Endpoint cases must never execute a zero denominator. Negative N equals N=0.
All valid outputs are finite.

### B12 constant-field analytical growth

For constant valid T/N and no threshold crossing:

    S(n) = S(0) + n*dt*(growth-mortality)

Require roundoff-level agreement for serial/MPI4, RK2/RK4 movement selections
and spring NONE/HOOKE. Also cover:

- still-WAITING owner receives no update;
- mid-substep release uses dtActive only;
- exact Smin/Smax equality creates no event;
- first strict lower/upper crossing occurs at the expected fixed substep;
- NO_GROWTH analytical mortality line.

P4.1 stops before committing births/deaths; threshold rows inspect immutable
event-plan candidates only.

## 5. P4.2 boundary, state and free-stack gates

Execution status: accepted on one clean exact head by the 18/18 serial/MPI4
direct gate, the complete P4.1 31/31 replay and exact v0.4 predecessor
538/538 replay recorded in `P4.2_CLOSEOUT.md`.

### P4-L01 boundary classifier

Direct fixtures cover:

- interior wet;
- containing-cell dry;
- non-periodic west/east/south/north outside;
- exact half-open global faces;
- periodic-X normalization and seam wet/dry cells;
- mixed coastal stencil with wet containing cell;
- insufficient required interpolation support;
- NaN/Inf, ambiguous owner, bad metric and unsupported grid.

Only finite dry and supported-domain outside results are terminal candidates.
All other invalid conditions are fatal failure 29 or the earlier stable
mapping/metric code.

### B11 no-land-penetration

Run straight and curved trajectories that first encounter land/outside at
K1, K2, K3, K4 or FINAL for RK2/RK4 as applicable. Cover spring NONE and one
spring ensemble case across a rank boundary.

Require:

- authoritative event X/Y equals last accepted substep-start wet X/Y;
- attempted X/Y and first stage are preserved in event scratch/record;
- no dry owner enters output, pickup, graph or next substep;
- BEACHED and OUTSIDE codes/events are distinct;
- other owners see a deterministic scratch graph after the encounter;
- serial/MPI layouts produce identical canonical outcomes.

### P4-F01 compact-tail free stack

Initialize empty, partial and full tile prefixes. Delete first, middle, last
and several owners; allocate replacements; migrate and reconstruct; then
restart reconstruction.

Check O(1) operation counters, exact swapped records, UNUSED zero tails,
pop=next-prefix-slot, no duplicate/missing IDs and identical logical records
under slot permutations.

### P4-T01 event transaction rollback

Inject failure at boundary collection, biology plan, terminal removal,
event capacity, post-event graph and budget. Test no-spring and spring
ensemble paths in serial/MPI4.

Require bitwise unchanged owners, free stacks, bomNextId, eventTimeIndex,
counters, event buffer, graph/components, T/N brackets and schedules. The
reported first-failure tuple must be canonical.

### B13 death/free-stack portion

Create several lower-threshold deaths on one/multiple tiles with interleaved
survivors. Require correct Sbefore/Strial, DEAD_BIO event type, descending-slot
deletion plan, exact alive budget and immediate reuse eligibility without ID
reuse.

## 6. P4.3 RNG, birth, IDs and distributed integration

### P4-RNG01 exact Philox oracle

A verification-only independent oracle stores exact unsigned output words and
angles for:

- all-zero and maximum 32-bit words;
- parent IDs crossing low/high-word boundaries;
- birth count zero and large values;
- event index low-word wrap;
- every retry endpoint;
- distinct seed/parent/birth/event/attempt sensitivity.

Fortran serial/MPI2/MPI4 words must match exactly. The source/link audit rejects
random_number and other stateful RNG calls from the birth path.

### P4-BR01 placement retry

Fixtures force:

- success on attempt 0;
- land then success;
- outside then success;
- periodic seam success;
- all attempts invalid by land/outside and cancellation;
- fatal mapping/non-finite attempt;
- parent near spherical metric limits.

Success resets parent/child to S0 and increments parentBirthCount once.
Cancellation restores Sbefore, leaves birth count/next ID unchanged and emits
one cancellation event. Fatal cases publish nothing.

### P4-ID01 global parent order

Distribute the same parents in different rank/tile/slot orders. Accept subsets
whose local rank order conflicts with exact parent-ID order. Require:

- identical global sorted parent list;
- contiguous child IDs from the same bomNextIdBefore;
- identical bomNextIdAfter;
- duplicate-parent and signed-64-bit overflow rejection;
- no live-owner gather symbol in the event call path.

### B13 complete birth/death/free-stack

Combine deaths, successful births, cancelled births and swaps in one event
phase. Check:

- aliveAfter equation;
- simultaneous owner limit rather than ever-created limit;
- exact lineage and birth counts;
- child destination tile/rank;
- parent/child amount semantics;
- compact-tail reuse and never-reused exact IDs;
- post-event graph/component rebuild.

### B14 deterministic RNG and births

Run the same input in serial/MPI2/MPI4 and with permuted owner slots. Compare
exact Philox words, retry winners, angles, child coordinates, parent/child
IDs, lineage, S and event records bitwise.

### P4-M01 packet schema 3

Cross tile and rank with nonzero parent high/low words, S, birth count,
spring/raft fields and release state. Require a complete exact record after
migration. Mutate schema, words, count, destination, real fields and packet
length; require rollback before any owner replacement.

### B17 Phase 4 decomposition invariance

Compare all owners and event state after multiple movement/biology event
phases, including spring graph split/merge after births/deaths. Serial/MPI2/
MPI4 canonical owner, graph, event and counter records must be bitwise equal.

P4.3 executes this section through `run_p43_gate.sh`: 26/26 rows cover three
debug/IEEE builds, serial/MPI2/MPI4 exact Philox, retry/order/ID fixtures,
schema-3 positive migration and packet mutation, atomic B13/B14/B17 event
transactions, reversed owner slots and byte-identical canonical owner/event
records. Exact evidence and accepted predecessor roots are recorded in
`P4.3_CLOSEOUT.md`.

## 7. P4.4 schema, event, diagnostic and restart gates

### P4-S01 schema-4 trajectory/P4 sidecar

Require:

- schema-2 48-field core bytes unchanged;
- conditional P3 sidecar bytes unchanged;
- required four-field P4 sidecar aligned by time/tile/ID/count;
- manifest mode/sidecar flags exact;
- empty/nonempty tile framing;
- checksummed complete frame publication.

Mutate every header/signature class, parent word, S, birth count, record
order/count and file length. Missing, partial, extra or corrupt sidecars are
rejected before state publication.

### P4-EV01 event schema and shard manifest

Write every event type across multiple flushes and ranks. Verify exact ID
words, times, stages, source/destination, amount triplet and retry count.
Canonical merged records must be independent of shard/rank order.

Test an existing-buffer flush followed by a substep event burst, empty flush,
manifest corruption, truncated/appended shard and write-failure injection.
No accepted event is duplicated or omitted.

### B15 same-decomposition restart

For spring NONE and EBOMB, run continuous and split serial/MPI2/MPI4 cases
through T/N endpoint advance, deaths, successful/cancelled births and an
unflushed event boundary.

Compare bitwise:

- all owner/P4/P3 fields;
- bomNextId, eventTimeIndex and cumulative counters;
- accepted T/N bracket and source metadata;
- reconstructed compact-tail stack;
- subsequent Philox words, IDs and events;
- trajectory/P4 sidecar/event shards after canonicalization.

Changed decomposition remains a clear pre-publication rejection.

### B18 diagnostic and event budget

Use a manufactured schedule with known alive, amount, birth, death, beach,
outside, cancel and missing-growth totals. Check every successful substep,
output window and restart boundary. Failed transactions add zero.

Grid BOMCOUNT/BOMMASS sums and scalar/event counters must match canonical owner
and event records. Terminal owners contribute their final event but not
post-event live mass.

## 8. P4.5 capacity and final integration

### B19 capacity matrix

Independently exceed:

- global bomMaxParticles;
- destination bomMaxPartTile;
- event candidate/allgather capacity;
- unflushed event buffer;
- owner packet/exchange capacity;
- exact ID signed range;
- candidate graph/neighbor/ghost capacity after births.

Each row requires the stable failure/phase, required and compile/runtime
capacity, canonical first-failure context and bitwise rollback. Exact equality
at every limit must succeed.

### P4-G99 final integration gate

On the ordered merged production tree, run:

- every accepted P4.1--P4.5 direct/negative/MPI/restart/schema row;
- B11--B15 and B17--B19 in their complete matrices;
- the exact Phase 3 release matrix of 538 predecessor rows;
- P4 disabled schema/core compatibility and the compatibility-only FLT+BOM
  coexistence regression;
- Julia/reference and Philox fixture integrity;
- production source/link isolation;
- clean source, expected/actual row audit and self-validating manifest.

Before the exact-head run, P4.5 freezes the complete ordered group names and
row counts. A group may not be removed because it is slow or fails. P4-G99
does not create a tag.

An independent exit audit must then prove P4-R01--P4-R20 closure, exact
package ancestry, no open finding, no released-schema drift, no live-owner
event gather and no Phase 5/6 claim. Only a later explicitly authorized
release action may create annotated tag MITGCM-BOM-v0.5.

## 9. Tolerance and fixture-change rule

- integer words, IDs, event/status decisions, counts, schemas and canonical
  serial/MPI records are exact;
- B12 analytical simple fields use a frozen roundoff-scaled bound;
- angles compare exact RNG words first; trigonometric coordinates use a
  frozen compiler/math-mode bound unless bitwise output is demonstrated;
- B15 same-environment restart is bitwise;
- no implementation PR may weaken a bound or regenerate a fixture.

Any formula, fixture, tolerance, RNG word, ordering key, expected group or row
count change requires a reviewed P4 decision amendment before production code.
