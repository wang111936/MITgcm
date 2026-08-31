# MITGCM-BOM Phase 5 Scientific Acceptance Plan

Status: **FROZEN PLAN ONLY; NO PHASE 5 TEST HAS BEEN EXECUTED**

Freeze date: 2026-08-30

## 1. Authority and purpose

The released starting point is:

- annotated tag: `MITGCM-BOM-v0.5`;
- tag object: `f16e2345cbe596f37fe3434d1b2f23f85ff0ba74`;
- peeled commit: `1f48a75d4865fa6d5235a4db306e8abe31534f3e`;
- integration branch at freeze: `MITGCM-BOM/development` at the same commit;
- locked Julia: `1.10.12`;
- locked SargassumBOMB commit:
  `156557359185e4413ce82829f3ed26a4eb8c6283`;
- locked `physics.jl` SHA-256:
  `1acef9ed3c8d13646c95799565387a4add76e839827cea1c0e745ced73f1885d`.

The purpose is to answer, with reproducible evidence, all of the following:

1. Is `pkg/bom` compiled and linked into a normal MITgcm executable without a
   verification-only replacement of production routines?
2. Can that executable read complete production inputs and advance real BOM
   owner state for nonzero model time through the normal call chain?
3. Are trajectory, component, pickup, event and diagnostic outputs complete,
   finite, internally consistent and independently decodable?
4. Does `bomEquationMode='JULIA'` reproduce the locked Julia fixed-step
   reference when both systems receive the same fields and parameters?
5. Does `bomEquationMode='PAPER2024'` reproduce an independent implementation
   of the frozen paper equations and show the expected RK convergence?
6. Do the released spring, biology, land, birth/death, schema-4, restart and
   MPI semantics remain correct in a normal multi-step MITgcm run?
7. Does enabling BOM leave the one-way ocean solution unchanged?

Compilation success or `NORMAL END` alone answers none of the scientific
questions and is not an acceptance result.

## 2. Relationship to the Phase 5 roadmap

This plan freezes the scientific-acceptance part of Phase 5. Work is ordered:

| Package | Scope | Completion decision |
|---|---|---|
| P5.0 | this source/interface/reference/test freeze | reviewed documentation only |
| P5.1 | production executable and deterministic input pipeline | P5-B01/P5-I01 |
| P5.2 | full production Julia-compatibility simulation | P5-J01 |
| P5.3 | PAPER2024 oracle and temporal convergence | P5-P01/P5-P02 |
| P5.4 | released-feature, dynamic-ocean, restart, MPI and long-run qualification | P5-F01/P5-O01/P5-R01/P5-L01 |
| P5.5 | aggregate scientific gate and independent audit | P5-SA-G99 |
| later Phase 5 HPC packages | OpenMP, target-server scale, performance and changed-decomposition restart design | separate HPC freeze and Phase 5 exit |

P5-SA-G99 is therefore a scientific release gate, not the full Phase 5/v1.0
exit gate. The original target-server obligations remain active and may not be
marked complete from local WSL or four-rank evidence.

## 3. Frozen scope and exclusions

In scope:

- the released regular Cartesian and regular spherical mappings;
- surface, one-way BOM coupling;
- LEEW compatibility only as an inherited regression, not as the BOM oracle;
- BOM equation modes `JULIA` and `PAPER2024`;
- RK4 as the primary scientific integrator;
- standard MITgcm OFFLINE input for deterministic time-varying base current;
- production BOM FILES input for Stokes drift and production EXF wind input;
- spring `NONE` and `EBOMB` production paths;
- Phase 4 biology, land, deterministic events, diagnostics and schema 4;
- serial, MPI2 and MPI4 admission runs;
- same-decomposition pickup/restart;
- one short dynamically evolving MITgcm ocean case;
- one 30-day small-domain endurance run.

Out of scope for P5-SA-G99:

- EXCH2, cubed-sphere, LLC and general curvilinear topology, retained for
  Phase 6;
- two-way particle feedback to ocean momentum or tracers;
- three-dimensional particle motion or sinking;
- validation against observations;
- changed-decomposition restart support, which v0.5 intentionally rejects;
- OpenMP production enablement, target-server scheduler/parallel-filesystem
  tuning, 100,000-particle/256-rank scaling and the less-than-20-percent
  overhead claim; these remain later Phase 5 HPC work;
- adaptive Julia `Tsit5` as a fixed-step MITgcm oracle.

A controlled prescribed-field run is still a real MITgcm production
simulation: it uses the standard time loop, standard packages and production
I/O. The additional dynamic-ocean case prevents scientific acceptance from
resting only on prescribed fields.

## 4. Frozen decisions

| ID | Decision |
|---|---|
| P5-D001 | Every positive case has `endTime>0`, `bomMaxParticles>0`, real initial-particle input and at least two committed BOM steps. |
| P5-D002 | Every particle advance must enter through `FORWARD_STEP -> BOM_MAIN`; direct calls to RHS/RK verifiers are predecessor evidence only. |
| P5-D003 | No case may replace `BOM_INIT_VARIA`, `BOM_MAIN`, a BOM RHS/RK routine, publisher, event routine, pickup routine or writer. |
| P5-D004 | Standard verification build files such as `SIZE.h`, package options and package lists are allowed; production source overrides are forbidden. |
| P5-D005 | One executable configuration contains all packages needed by the controlled cases; serial/MPI and debug/optimized variants come from the same exact source commit. |
| P5-D006 | OFFLINE is a standard fixture provider for time-varying base U/V and does not become a BOM runtime dependency outside the scientific case. |
| P5-D007 | Affine fields are evaluated at their native C-grid staggered locations and exact record times, then independently decoded before model execution. |
| P5-D008 | Locked Julia fixed-step RK4 is authoritative only for `bomEquationMode='JULIA'`. |
| P5-D009 | `PAPER2024` uses a separately implemented oracle that imports no `pkg/bom` code or generated values. |
| P5-D010 | Direct equality of PAPER2024 and JULIA trajectories is not expected; at least one discriminating component must differ by more than roundoff. |
| P5-D011 | Complete saved trajectories are compared; endpoint-only comparisons are insufficient. |
| P5-D012 | Exact integers, IDs, states, decisions, event ordering, schemas and checksums use exact comparison. |
| P5-D013 | Floating tolerances are frozen before the production implementation is evaluated and cannot be weakened in a fix PR. |
| P5-D014 | Same-build continuous/split restart is bitwise after canonicalization; changed-decomposition restart must fail before publication. |
| P5-D015 | MPI comparisons use canonical exact-ID owner ordering and canonical event ordering `(eventTimeIndex,eventType,subjectId,parentId)`. |
| P5-D016 | A production run is accepted only when its output can be decoded independently of the production Fortran reader. |
| P5-D017 | BOM-on and BOM-off dynamic-ocean runs must preserve the one-way ocean solution. |
| P5-D018 | Any failed run retains its immutable evidence and is reported as FAIL; reference regeneration cannot turn it into PASS. |
| P5-D019 | A required unavailable external platform is BLOCKED, never PASS or SKIP. |
| P5-D020 | No P5-SA result changes or reads SKRIPS source, inputs, builds, runs or artifacts. |
| P5-D021 | P5-J01/P5-P01 reference builds keep MITgcm `_RS` as `Real*8` (`REAL4_IS_SLOW`; no `LET_RS_BE_REAL4`) so standard OFFLINE storage cannot silently weaken the frozen double-precision oracle. |

## 5. Evidence and reproducibility contract

Each production gate must:

- use one named clean exact commit descended from the v0.5 peeled commit;
- record the branch, full commit, `git status`, tag ancestry and source diff;
- refuse to overwrite an existing build, run or evidence root;
- use repository-external roots with unique attempt IDs:
  `/home/wyl/build/mitgcm-bom/phase05-scientific-acceptance`,
  `/home/wyl/runs/mitgcm-bom/phase05-scientific-acceptance`, and
  `/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/scientific-acceptance`;
- record OS, CPU, compiler, compiler flags, MPI, Julia, Python and coreutils
  versions and relevant runtime environment;
- checksum source, executable, build options, inputs, references, scripts,
  raw outputs and normalized comparison products;
- capture stdout/stderr and require a normal MITgcm termination marker in
  addition to a successful shell status;
- preserve expected and actual case inventories and reject missing, duplicate
  or extra required records;
- create a self-validating SHA-256 manifest and a second independent audit;
- record wall time and peak memory as context even when they are not gating;
- never write build, executable, runtime output or large generated fields into
  the source tree.

The source-controlled directory contains only definitions, small reference
files, deterministic generators, comparison tools and compact reports.

## 6. P5.1 production build and input gates

### P5-B01 production packaging

Build three variants from one clean exact head:

1. GNU serial debug/IEEE;
2. GNU OpenMPI debug/IEEE;
3. GNU OpenMPI optimized production.

The scientific-reference variants retain the MITgcm default
`REAL4_IS_SLOW`, so both `_RS` OFFLINE endpoint storage and `_RL` BOM state are
eight-byte. A performance-oriented `_RS=Real*4` build may be measured later,
but it cannot be substituted into the frozen P5-J01/P5-P01 tolerance gates.

The controlled executable includes at least `gfd`, `cd_code`, `offline`,
`exf`, `diagnostics`, `mnc` and `bom`. Runtime switches activate only the
packages required by a case. `data.pkg` must contain `useBOM=.TRUE.` for BOM
cases.

The gate requires:

- complete `genmake2`, dependency and compiler logs;
- no unresolved or duplicate BOM symbols;
- linked symbols for setup, `BOM_MAIN`, endpoint publication, field build,
  JULIA/PAPER2024 RHS, RK4, owner migration, trajectory/schema-4 output,
  event output and pickup read/write;
- a source/link isolation scan proving no `bom_verify_*` object or substituted
  production routine is present;
- executable SHA-256 and an exact source/build fingerprint;
- a BOM-off smoke proving the compiled package does not alter the inherited
  ocean baseline merely by being linked.

Compilation is necessary but cannot by itself pass any P5-J/P/F/O gate.

### P5-I01 deterministic production input

The input generator must create and independently validate:

- grid, bathymetry, vertical geometry and masks;
- `data`, `data.pkg`, `data.bom`, `data.off`, `data.exf` and `eedata`;
- C-grid U/V records at exact endpoint times;
- BOM Stokes OLD/NEW FILES records;
- EXF wind records;
- initial particle MDS data/meta;
- Phase 4 T/N or PTRACER/FILES data where enabled;
- every input dimension, precision, endianness, record count, time stamp and
  SHA-256 value.

The generator evaluates the frozen affine expression
`c0 + cx*x + cy*y + ct*t` at each field's native staggered coordinate.
Reading back the binary files and comparing them with the analytical values is
a gate and occurs before `mitgcmuv` starts.

## 7. P5.2 Case J: locked-Julia production parity

### P5-J01 configuration

Use the frozen B16 physical reference in a normal production run:

- Cartesian 400 km by 300 km domain, 8 by 6 horizontal cells, two fully wet
  levels and non-periodic outer boundaries;
- particles `1001`, `1002`, `1003` at the locked B16 positions;
- `startTime=0`, `endTime=86400 s`, ocean step and BOM RK4 step `900 s`;
- initial record plus 96 committed steps, giving 97 trajectory times per
  particle;
- standard OFFLINE U/V records every 900 s from the frozen affine base field;
- BOM Stokes source `FILES` and EXF wind from the frozen affine records;
- `bomMode='BOM'`, `bomEquationMode='JULIA'`,
  `bomCurrentPolicy='EULERIAN'`, `bomIntegrator='RK4'`;
- `bomAlpha=0.00337`, `bomTauDays=0.0103`, `bomR=0.823` and
  `bomSigma=1.2` in `data.bom`;
- constant Cartesian MITgcm Coriolis parameter
  `f0=2.18213/86400=2.52561342592593e-5 s^-1` and `beta=0` in `data`;
- springs, biology and land events disabled to isolate the slow-manifold
  trajectory;
- production trajectory output at every RK step and pickup at the frozen
  split point.

No initialization verifier or direct RHS/RK driver is allowed. The gate must
prove from logs and linked/source manifests that all 96 advances entered
`BOM_MAIN`.

### P5-J01 reference and pass criteria

Before comparison, rerun the locked Julia fixed-step generator in the locked
environment and require byte equality with the checked-in B16 RHS/RK4 files.
The adaptive Tsit5 context is checked only for provenance and remains
non-gating.

Require:

- the locked 27 RHS components plus native coordinate rates at all frozen
  particle/time samples satisfy
  `abs(error) <= 2e-12 + 5e-12*abs(reference)`;
- every particle position at all 97 saved times and accumulated path satisfy
  `abs(error) <= max(1e-6 m, 5e-11*reference_path)`;
- IDs, time indices, status, counts and schema records are exact;
- all values are finite and every particle has nonzero displacement;
- no record is missing, duplicated or silently reordered.

Failure of any intermediate saved time fails P5-J01 even when the final
position is within tolerance.

## 8. P5.3 Case P: independent PAPER2024 acceptance

### P5-P01 component and trajectory oracle

Reuse the Case J grid, particles, time-varying input fields and parameters but
set `bomEquationMode='PAPER2024'`. The reference implementation must:

- transcribe the frozen PAPER2024 equations independently;
- combine the required fields before the nonlinear material derivative and
  use the frozen total-vorticity definition;
- import neither `pkg/bom` source nor MITgcm-generated expected values;
- evaluate the analytical affine fields directly rather than decoding BOM
  diagnostic candidates;
- emit all 27 component values, native coordinate rates and full fixed-step
  RK4 trajectories in a checksummed open format.

Component and trajectory tolerances are the same frozen B16 bounds used by
P5-J01. In addition, at least one predeclared discriminating component and one
trajectory sample must differ from the JULIA-mode answer by more than ten
times the applicable roundoff bound. This proves that the equation-mode
switch is exercised rather than aliased.

### P5-P02 temporal convergence

Run the same smooth PAPER2024 problem with `dt=900`, `450` and `225 s`, using
identical physical input functions and outputting at common times. Compare
against an independent 256-bit reference integrated with fixed-step RK4 at
`900/32 s`.

For each particle, endpoint and full-trajectory norms must decrease on both
refinements. While the coarse error exceeds fifty times the floating
comparison floor, each observed RK4 error ratio must be at least 12. A ratio
is reported but not interpreted after the roundoff floor is reached. No
unstable particle, non-finite component or stage rejection is permitted.

The reference step, precision, norm and ratio criterion are immutable. A
pilot failure is investigated; the production patch may not relax them.

## 9. P5.4 released-feature production qualification

### P5-F01 manufactured schema-4 system cases

Use one production executable and three small deterministic scenarios:

1. **F-SPRING**: fully wet EBOMB ensemble with an independently computed
   initial graph, pair forces, center-of-mass budget and several real RK4
   advances;
2. **F-EVENT**: constant T/N and manufactured amounts/thresholds producing
   known successful birth, cancelled birth and biological death records;
3. **F-COAST**: deterministic flow toward a dry coastal cell and a supported
   non-periodic outside boundary, producing distinct BEACHED and OUTSIDE
   records at known first-crossing stages.

A final short combined run enables EBOMB, biology, land, births/deaths,
diagnostics, schema 4 and event shards together. Exact acceptance covers:

- event type, time index, subject/parent IDs, retry, source/destination and
  amount triplet;
- live/free/next-ID and mass/event budget equations at each committed step;
- deterministic Philox decisions and never-reused exact IDs;
- last-wet accepted positions for terminal particles;
- graph/component reconstruction after births and deaths;
- schema-4 core, P3/P4 sidecars, frame checksums, event shards/manifests and
  pickup contents decoded by an independent reader;
- no owner in a dry or unsupported cell after a commit.

The oracle is the frozen analytical/budget/event definition, not legacy Julia
behavior where Julia lacks the released distributed transaction semantics.

### P5-O01 dynamically evolving ocean case

Copy, never modify in place, MITgcm's standard
`verification/tutorial_baroclinic_gyre` configuration. Add BOM-specific
build/input files under the Phase 5 directory and seed a frozen set of wet,
interior particles. Run the existing ten 1200-second ocean steps on the
regular spherical 62 by 62 by 15-level grid.

Required comparisons are:

- stock BOM-off ocean control versus BOM-on: ocean state/pickup and selected
  diagnostics are exact under the same build and layout, proving one-way
  coupling;
- BOM owners execute ten nonzero production advances with finite nonzero
  paths and valid wet owners;
- archived surface endpoint fields and particle records pass an independent
  sparse-step replay of the frozen `PAPER2024` mode;
- serial and MPI4 IDs, states and decisions agree exactly; continuous
  coordinates and paths satisfy
  `abs(error) <= max(1e-6 m, 5e-11*reference_path)`.

This case is a production qualification, not a replacement for the analytical
oracles in P5-J01 and P5-P01.

### P5-R01 restart and decomposition

For Cases J and the combined F case:

- compare a continuous run with a split run whose pickup occurs at a
  non-final time and, for F, across an unflushed event boundary;
- require bitwise state and subsequent output equality within serial, MPI2
  and MPI4 after canonicalization;
- require exact semantic equality of canonical owners/events across
  decompositions;
- verify no lost/duplicate IDs, times, fields or event records;
- mutate the decomposition signature and require a clear pre-publication
  rejection, because v0.5 does not claim changed-decomposition restart.

### P5-L01 30-day endurance

Extend the small controlled PAPER2024 case to 30 days with a frozen periodic
forcing cycle, hourly trajectory output and daily pickups. Compare continuous
and day-15 restart paths in one fixed MPI layout. Require:

- normal completion and finite state at every output;
- exact ID/state/event and declared mass budgets;
- continuous/split equality;
- no monotonic leak in live slots, free stack, event buffering or file
  manifests;
- reported wall time, peak resident memory, output volume and per-step BOM
  timers.

Timing and memory are diagnostic here. Target-server performance claims belong
to the later HPC gate.

## 10. Comparison products

Every scientific case produces:

- a normalized trajectory CSV keyed by exact `(timeIndex,particleId)`;
- normalized component, owner, event and budget CSV files as applicable;
- expected-minus-actual absolute/relative error tables;
- per-particle x/y/path time-series plots and a plan-view trajectory plot;
- maximum-error location, component, particle and time;
- missing/duplicate/extra-record audit;
- input/output/reference/executable manifest;
- a concise machine-readable PASS/FAIL result and a human review report.

Plots are diagnostic. Only the frozen numerical and exact-record criteria make
the decision.

## 11. Aggregate gate and independent audit

P5-SA-G99 runs, on one clean exact candidate head and fresh roots:

1. P5-B01 and P5-I01;
2. P5-J01;
3. P5-P01 and P5-P02;
4. P5-F01, P5-O01, P5-R01 and P5-L01;
5. the exact released Phase 4 predecessor gate, not a selected subset;
6. source/package isolation, reference hashes, expected/actual inventory and
   manifest validation.

An independent exit audit then verifies:

- every P5 decision and required case is represented once;
- the tested commit descends from the exact v0.5 baseline;
- no production-source override, SKRIPS dependency or hidden reference
  regeneration exists;
- equation modes used their correct independent authorities;
- no tolerance, fixture, formula or expected result changed after seeing the
  candidate output;
- all required evidence roots and hashes exist and self-validate;
- the report distinguishes scientific acceptance from later HPC acceptance.

P5-SA-G99 passes only if every required group and the independent audit pass.
There is no partial scientific-acceptance release and no tag is created by the
gate itself.

## 12. Failure, correction and amendment rules

A failure is first classified as build/package, input/provenance, runtime,
JULIA physics, PAPER2024 physics, integration/I/O, restart/MPI, or reference
tooling. The failed root is made read-only and retained.

If production code needs correction:

1. open a narrowly scoped implementation branch/PR;
2. do not alter this plan, reference or tolerance in that PR;
3. rerun the failed direct gate and all previously accepted P5 scientific
   gates on the corrected exact head;
4. run a fresh P5-SA-G99 and independent audit before acceptance.

A plan amendment is allowed only before evaluating a new production candidate
or when the frozen requirement is proven impossible or mathematically wrong.
It requires a separate documentation-only review containing the reason,
impact, old/new wording and invalidated evidence. Convenience, runtime or a
failed candidate is not sufficient justification.

## 13. Frozen go/no-go decision

The current v0.5 package is scientifically accepted for the released regular
grid, one-way, surface scope only when P5-SA-G99 and its independent audit both
pass. Until then the status is **NOT YET SCIENTIFICALLY ACCEPTED**, regardless
of predecessor unit/integration gate count.

After scientific acceptance, Phase 5 may proceed to its separate HPC freeze:
OpenMP-safe production execution, target-server toolchain and scheduler,
parallel filesystem, changed-decomposition restart design, 100,000 particles,
up to 256 MPI ranks, communication/memory scaling, and less than 20% measured
ocean-model overhead under a separately frozen benchmark protocol. None of
those future results is claimed by this document.
