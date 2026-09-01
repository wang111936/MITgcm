# MITGCM-BOM input, output, and restart reference

All BOM binary values are IEEE-754 big-endian float64 unless a time-varying
environmental file explicitly selects 32-bit precision. Particle IDs are
positive signed 64-bit integers represented on disk as two exactly
representable unsigned 32-bit words:

```text
id = id_hi * 4294967296 + id_lo
```

## 1. Initial particle MDS file

`bomInitialFile='bom_particles'` resolves to `bom_particles.meta` and
`bom_particles.data`. The metadata contract is:

```text
nDims       = 3
dimList     = 1 x 1 x 8
dataprec    = float64
nrecords    = N + 1
nFlds       = 1
fldList[1]  = BOMV0001
```

The first eight-value record is:

| Field | Value | Meaning |
|---:|---:|---|
| 1 | `1` | Initial schema. |
| 2 | `8` | Values per record. |
| 3 | `N` | Positive particle count. |
| 4 | `1` | Physical coordinate encoding. |
| 5 | `1` | Two-word exact ID encoding. |
| 6 | `64` | Precision bits. |
| 7--8 | `0` | Reserved. |

Each following particle record is:

| Field | Quantity | Constraint |
|---:|---|---|
| 1 | ID high word | Exact unsigned 32-bit word. |
| 2 | ID low word | Exact unsigned 32-bit word; combined ID is positive and unique. |
| 3 | x | Finite physical position inside exactly one supported owner domain. |
| 4 | y | Finite physical position inside exactly one supported owner domain. |
| 5 | release time (s) | Nonnegative. |
| 6 | status | `1` (`ALIVE`) or `6` (`WAITING`). |
| 7 | age (s) | Nonnegative; exactly zero for `WAITING`. |
| 8 | reserved | Exactly zero. |

At initial admission, `ALIVE` release time cannot be in the future and
`WAITING` release time must be later than the model start. The data file must
be exactly `(N + 1) * 8 * 8` bytes; trailing and truncated data are rejected.

## 2. Environmental inputs

### Ocean current

BOM reads the accepted MITgcm surface C-grid velocity. The source can be the
online ocean or `pkg/offline`; BOM does not define a separate current file
namelist. The current is rotated to east/north on supported spherical grids,
wet-masked, halo-filled, and sampled with one shared wet-weight stencil.

### EXF wind

`bomWindSource='EXF'` reads the normal EXF `uwind`/`vwind` fields and their EXF
time metadata. BOM snapshots exact OLD/NEW endpoint values; it does not mutate
the EXF global arrays. EXF file precision, period, cycle, and scaling remain
configured in `data.exf`.

### Stokes files

With `bomStokesSource='FILES'`, `bomUStokesFile` and `bomVStokesFile` are
stacked scalar C-point records with x/i fastest, then y/j, then time. Their
common timing is:

```text
t(record) = bomStokesStartTime + record * bomStokesPeriod
```

`bomStokesRepCycle=0` disables repetition. The reader publishes a bracket only
after both components, metadata, finite checks, and record bounds succeed.

### Biology nutrient files

With `bomNSource='FILES'`, `bomNFile` is a stacked scalar C-point field with
the same i-fastest/j/time ordering. `bomNRepCycle>0` must be an exact integer
multiple of `bomNPeriod`.

## 3. Trajectory files

`bomTrajectoryMode` selects `FRAME` or `ARCHIVE`. Both are MDS float64 output;
neither path is MNC/NetCDF output.

In the default `FRAME` mode every scheduled output time writes a tiled family with
prefix `bom_traj.<suffix>`. With the default iteration suffix, a member looks
like:

```text
bom_traj.0000000024.001.001.data
```

Each tile member begins with one header record and then contains its owner
records. Empty tiles still publish a header. The core BOM schema is version 2
with 48 float64 values per record.

### Schema-2 tile header

| Fields | Meaning |
|---:|---|
| 1--2 | Schema `2`, record width `48`. |
| 3--4 | Tile owner count, global expected count. |
| 5--7 | Coordinate code `1`, ID code `1`, precision `64`. |
| 8--11 | Iteration, sample time, scheduled time, next scheduled time. |
| 12--18 | `nPx`, `nPy`, global tile origin i/j, rank, local tile bi/bj. |
| 19--24 | Mode, equation, current, wind, Stokes, and integrator codes. |
| 25--27 | Diagnostic count `27`, first field `22`, last field `48`. |
| 28--48 | Reserved zeros. |

### Schema-2 particle core

| Field | Quantity | Units |
|---:|---|---|
| 1--2 | ID high/low words | exact words |
| 3 | status | code |
| 4 | sample time | s |
| 5 | iteration | step |
| 6--7 | x, y | m or degrees |
| 8--9 | release time, age | s |
| 10--11 | fractional local i, j | grid index |
| 12--13 | base-current east/north | m s-1 |
| 14--15 | wind east/north | m s-1 |
| 16--17 | final drift east/north | m s-1 |
| 18--20 | rank, local bi, local bj | integer-valued |
| 21 | active-record marker (`1`) | code |
| 22--48 | 27-component BOM diagnostic vector | mixed; below |

### Diagnostic vector in fields 22--48

| Vector index | Quantity | Units |
|---:|---|---|
| 1--2 | base velocity `vBaseE`, `vBaseN` | m s-1 |
| 3--4 | Stokes velocity `vSE`, `vSN` | m s-1 |
| 5--6 | wind velocity `vWE`, `vWN` | m s-1 |
| 7--8 | combined water-side `vE`, `vN` | m s-1 |
| 9--10 | air-side/intermediate `uE`, `uN` | m s-1 |
| 11--12 | material tendency `DvE`, `DvN` | m s-2 |
| 13--14 | material tendency `DuE`, `DuN` | m s-2 |
| 15 | vorticity `omega` | s-1 |
| 16 | Coriolis `f` | s-1 |
| 17 | spherical metric `tauSphere` | m-1 |
| 18--19 | coefficients `cV`, `cU` | s-1 |
| 20--23 | rotational v/u east/north components | m s-2 |
| 24--25 | inertial east/north components | m s-2 |
| 26--27 | accepted final drift east/north | m s-1 |

Diagnostics are evaluated at the accepted final particle position and exact
sample time. The duplicated base current, wind, and drift values are checked
for exact consistency when a pickup is read.

### Continuous `ARCHIVE` mode

Set these controls in `BOM_PARM01` when a long simulation must avoid one file
family per output time:

```fortran
 bomTrajectoryMode='ARCHIVE',
 bomTrajectoryFile='bom_trajectories',
```

One model startup creates the segment
`bom_trajectories.s<10-digit-nIter0>`. A restart has a different `nIter0` and
therefore creates a new segment instead of overwriting or truncating the old
one. Before the first MDS member is written, rank 0 atomically creates the
persistent text member `<segment>.claim` with Fortran `STATUS='NEW'`. An
existing member or claim makes a same-`nIter0` startup fail closed; the claim
prevents two concurrent startups from both passing a read-only collision
preflight.

The member count is independent of the number of frames:

```text
2 * (global tile count + 1) + 1
  + 2 when P3 is active
  + 2 when P4 is active
```

The first term is one `.data/.meta` pair per tile plus the global index pair;
`+1` is the claim. The conditional pairs are fixed, append-only `.p3sig` and
`.p4sig` signature streams. Thus a four-tile segment has 11 files with neither
extension, 13 with P3 only or P4 only, and 15 with both P3 and P4.

Each tile is a sequence of variable-length frame blocks:

```text
64-word frame header
N x 64-word owner record
64-word tile commit
```

Empty tiles still append a header and commit. The header contract is:

| Fields | Meaning |
|---:|---|
| 1--3 | Archive schema `1`, width `64`, header kind `1`. |
| 4--9 | Frame ordinal, startup `nIter0`, iteration, sample/scheduled/next times. |
| 10--14 | Tile owners, initial/historical owner budget, effective live owners, active core schema and width. Before P4 the effective count is the admitted owner count; P4 uses its maintained live-owner count. |
| 15--20 | Mode, equation, current, wind, Stokes and integrator codes. |
| 21--30 | P3/P4 presence flags, schemas and fixed owner ranges 49--56/57--60. |
| 31--38 | Core/reserve/diagnostic ranges and precision. |
| 39--51 | Decomposition, domain, global tile origin, rank and local tile. |
| 52--59 | Previous high-water and block/owner/end record offsets as exact high/low words. |
| 60--62 | Tile capacity and P3/P4 extension widths. |
| 63--64 | Reserved zeros. |

The unified owner record is:

| Fields | Meaning |
|---:|---|
| 1--48 | Byte-identical normalized schema-2 core mapping described above. LEEW uses its schema-1 fields and zero-fills the remainder. |
| 49--56 | P3 ID, raft ID, neighbor count, raft size and spring east/north fields; zero when P3 is inactive. |
| 57--60 | P4 parent ID, amount and birth count; zero when P4 is inactive. |
| 61--64 | Reserved zeros. |

A tile commit repeats the frame identity, times, counts and exact block offsets;
its field 28 is the complete marker `1`. Tile `.meta` `nrecords` is the local
high-water after the last complete block.

The global index uses the same 64-word width. Record 1 is the segment
descriptor: archive/core/extension schemas, feature and source codes,
decomposition, capacity, initial counts, schedule, and conditional signature
stream dimensions. Record `frame+1` is the ordered frame commit and contains
iteration, three times, global counts, feature codes, complete marker `1` in
field 28, and per-frame/cumulative P3/P4 signature records in fields 33--36.
Field 37 confirms signature publication is complete. When P3 or P4 is active,
rank 0 appends the complete legacy signature bytes for that frame to the one
fixed `.p3sig.data/.meta` or `.p4sig.data/.meta` pair before advancing the
index.

All ranks finish tile data, and rank 0 finishes active signature chunks, before
rank 0 advances the index. Index `.meta` is the sole committed-frame ledger.
Readers expose only its committed records and ignore: index data beyond index
meta; tile data or tile meta beyond blocks named by committed index records;
and signature data or meta beyond the fields 34/36 cumulative high-water.
The `.claim` reserves the segment name but is not a frame publication marker.
The MDS meta rewrite is ordered but is not a filesystem-level atomic rename;
a strict node-failure workflow should validate/copy a closed segment before
publication outside the run directory.

`ARCHIVE` changes analysis output only. Pickup/restart, P4 event shards and
their manifests retain their existing formats. The archive segment identity is
not pickup state: restart continuity is represented explicitly by the new
`nIter0` segment.

### Status codes

| Code | Name | Meaning |
|---:|---|---|
| 0 | `UNUSED` | Free storage slot; not an output owner. |
| 1 | `ALIVE` | Active owner. |
| 2 | `DEAD_BIO` | Terminal biological death. |
| 3 | `BEACHED` | Terminal land event. |
| 4 | `OUTSIDE` | Terminal domain exit. |
| 5 | `INVALID` | Rejected/internal invalid state; never an admitted initial status. |
| 6 | `WAITING` | Valid owner awaiting release. |

The introductory `analysis/plot_bom.py` decoder reads `FRAME` schema-2 core
families and therefore works for plain, spring, and Phase-4 FRAME containers.
It does not recognize `ARCHIVE` segments. The independent archive contract
decoder is `verification/bom/phase05-trajectory-archive/verify_archive.py`;
terminal/event detail remains in the Phase-4 sidecars and event shards.

## 4. Conditional sidecars

The following per-frame members apply to `FRAME`. The core schema remains
stable as features are added:

| Active path | Container | Additional members |
|---|---:|---|
| LEEW | schema 1 | none |
| BOM without springs/land/biology | schema 2 | none |
| BOM with springs | schema 3 | `.p3`, `.p3sig` |
| BOM with land or biology | schema 4 | `.p4`, `.p4sig`, optional `.p3`/`.p3sig`, `.p4bio`, `.p4manifest` |

The `.p3` owner-aligned sidecar stores parent/component and spring state. The
`.p4` owner-aligned sidecar stores lineage and biological amount. `.p4bio`
persists accepted temperature/nutrient brackets and counters. The manifest is
the publication point and records exact member names, sizes, hashes, source
fingerprint, schema, and decomposition.

In `ARCHIVE`, the owner-aligned P3/P4 trajectory fields are embedded in words
49--60 of the unified owner record, so they do not create per-time owner
sidecars. Complete P3/P4 provenance is retained in the fixed, append-only
`.p3sig`/`.p4sig` stream pairs described above. Therefore no trajectory
sidecar, signature, or manifest *file family* is created per output time.
Pickup sidecars and manifests are unchanged.

Event output uses append-only per-rank shards derived from `bomEventFile`, for
example `bom_events.r000000...`, with a matching per-rank `.manifest`.
Consumers must validate the manifest before treating a shard as published.

## 5. Pickup/restart

The package pickup prefix is `pickup_bom.<suffix>`. A BOM schema-2 particle
record has 45 values; its signature and endpoint sidecars preserve:

- exact particle IDs, state, positions, diagnostics, and owner mapping;
- equation, integrator, current, wind, and Stokes choices;
- physical parameters and compile/decomposition fingerprint;
- accepted OLD/NEW environmental values, times, and source iterations; and
- next trajectory output time.

Schema 3 adds spring graph, component, and diagnostic counters. Schema 4 adds
global ID/event counters, biology/lineage state, accepted T/N brackets, event
publication state, and required manifests.

Restart is transactional. The reader validates, in order, signature and
decomposition, manifests and sidecars, physical file lengths and MDS metadata,
headers, finite values, owners, exact IDs, counters, and duplicated diagnostic
fields. Only after every MPI rank passes is accepted state replaced.

Supported restart contract:

- same `SIZE.h` and BOM compile-time capacities;
- same `nPx/nPy/nSx/nSy/sNx/sNy` decomposition and MPI rank layout;
- same equation/source/feature configuration; and
- complete, unmodified member set from one suffix.

Changed-decomposition restart is intentionally unsupported. To change the
layout, convert an archived trajectory/state through a separately reviewed
offline remapping workflow; do not rename pickup members or bypass the
signature check.

## 6. Recommended archive contents

For a reproducible simulation archive, retain:

- source commit and executable SHA-256;
- `SIZE.h`, `packages.conf`, build option file, `genmake2` command, and compiler
  version;
- all text namelists and generated-input `SHA256SUMS`/manifest;
- `STDOUT.0000`, MPI launch command, rank/thread settings, and scheduler job;
- the complete trajectory/sidecar/manifest family; and
- the complete checkpoint suffix used for every restart boundary.
