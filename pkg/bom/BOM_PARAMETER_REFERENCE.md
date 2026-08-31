# MITGCM-BOM parameter reference

All run-time controls are read from `data.bom`. Character values are
case-sensitive and should be written exactly as shown. Defaults are safe but
inactive; a positive-particle BOM run must explicitly choose its sources and
initial file.

## `BOM_PARM01`: formulation, schedule, and initial state

| Parameter | Default | Accepted value or meaning |
|---|---:|---|
| `bomMode` | `'LEEW'` | `'LEEW'` or `'BOM'`. Springs and Phase-4 functions require BOM. |
| `bomEquationMode` | `'PAPER2024'` | `'PAPER2024'` or `'JULIA'`; used by BOM mode and stored in pickup/output signatures. |
| `bomIntegrator` | `'RK4'` | `'RK2'` or `'RK4'`. |
| `bomDeltaTTarget` | `deltaTClock` | Positive finite target particle step in seconds. The actual substep divides the ocean step exactly. |
| `bomOutputFreq` | `0` | Seconds between trajectory frames; zero disables output. A positive value must be at least `deltaTClock`. |
| `bomPickupFreq` | `0` | Reserved compatibility control; must remain zero. Use MITgcm checkpoint scheduling. |
| `bomSeed` | `20240801` | Deterministic Phase-4 random seed. |
| `bomMaxParticles` | `0` | Nonnegative global owner/birth ceiling, bounded by compiled initial and tile capacity. |
| `bomInitialIter` | `0` | Nonnegative iteration at which the initial particle file is admitted; cannot exceed `nIter0`. |
| `bomInitialFile` | blank | MDS prefix for the schema-1 initial particle file. Required for a positive count at `bomInitialIter`; blank in zero-particle mode. |
| `bomSpringLaw` | `'NONE'` | `'NONE'`, `'HOOKE'`, or `'EBOMB'`. |
| `bomNeighborPolicy` | `'NONE'` | `'NONE'` for no springs; `'CUTOFF'` for either active spring law. |

## `BOM_PARM02`: environmental sources and motion

| Parameter | Default | Accepted value or meaning |
|---|---:|---|
| `bomLeewayWindCoeff` | `0` | Finite `[0,0.1]`; active in LEEW mode. Must be zero when wind source is `NONE`. |
| `bomWindSource` | `'NONE'` | `'NONE'` or `'EXF'`. EXF requires compiled/active EXF and atmospheric wind. |
| `bomStokesSource` | `'NONE'` | In BOM mode: `'NONE'`, `'FILES'`, or compiled `'COUPLER'`. LEEW requires `NONE`. |
| `bomWetWeightMin` | `0.5` | Finite `(0,1]` minimum valid wet interpolation weight. |
| `bomAdvCFL` | `0.5` | Finite `(0,1]` particle-advection CFL limit. |
| `bomCurrentPolicy` | `'UNSET'` | BOM requires `'EULERIAN'` or `'PRECOMBINED'`; the latter rejects explicit Stokes input. |
| `bomAlpha` | `0` | Finite `[0,1]` BOM windage coefficient. Must be zero when wind source is `NONE`. |
| `bomTauDays` | `0` | Finite nonnegative response time in days; converted to seconds after validation. |
| `bomR` | `1` | Finite `(0,1]` buoyancy/geometric ratio. |
| `bomSigma` | `0` | Finite nonnegative Stokes weight. Must be zero with `bomStokesSource='NONE'`. |
| `bomUStokesFile` | blank | Zonal/east Stokes binary filename; required with `FILES`. |
| `bomVStokesFile` | blank | Meridional/north Stokes binary filename; required with `FILES`. |
| `bomStokesStartTime` | `0` | Finite time of the first file record in seconds. |
| `bomStokesPeriod` | `0` | Positive finite record period with `FILES`. |
| `bomStokesRepCycle` | `0` | Finite nonnegative repeat cycle; zero means no repeat and a positive cycle cannot be shorter than the record period. |
| `bomStokesInScale` | `1` | Finite multiplier applied while reading Stokes records. |
| `bomStokesFilePrec` | `64` | `32` or `64` bits. |
| `bomMaxHop` | `8` | Positive maximum owner-migration hops permitted during a committed step. |
| `bomInitGlobalLimit` | compiled limit | Integer in `[1,bomMaxInitRecords]`; run-level initial-record cap. |
| `bomCheckEverySubstep` | `.TRUE.` | Run the full accepted-state budget after every particle substep. Recommended for qualification and development. |
| `bomSpringL` | `0` | Positive equilibrium length when springs or biology are active. |
| `bomHookeK` | `0` | Positive finite Hooke coefficient when `bomSpringLaw='HOOKE'`. |
| `bomSpringA` | `0` | Positive finite eBOMB amplitude when `bomSpringLaw='EBOMB'`. |
| `bomSpringDelta` | `0` | Positive finite eBOMB shape/scale parameter. |
| `bomNeighborCutoff` | `0` | Positive cutoff greater than `bomPairDistanceMin`; for periodic X it must be smaller than half the physical period. |
| `bomPairDistanceMin` | `0` | Positive minimum admitted pair distance for an active spring law. |
| `bomSpringCFL` | `0.5` | Positive finite spring stability limit. |
| `bomRaftDiagnostics` | `.FALSE.` | Enable connected-component/raft diagnostics; requires an active spring graph. |

### Source combinations

| Current policy | Wind | Stokes | Result |
|---|---|---|---|
| `EULERIAN` | `NONE` | `NONE` | Ocean current only; `bomAlpha=0`, `bomSigma=0`. |
| `EULERIAN` | `EXF` | `NONE` | Current plus BOM wind contribution; `bomSigma=0`. |
| `EULERIAN` | `NONE`/`EXF` | `FILES` | Explicit Stokes sampled from paired time-varying files. |
| `EULERIAN` | `NONE`/`EXF` | `COUPLER` | Explicit Stokes supplied transactionally by a compiled external producer. |
| `PRECOMBINED` | `NONE`/`EXF` | `NONE` | Supplied base current already contains the intended Stokes contribution. |
| `PRECOMBINED` | any | `FILES`/`COUPLER` | Fatal: would double count Stokes drift. |

## `BOM_PARM03`: land and biology

| Parameter | Default | Accepted value or meaning |
|---|---:|---|
| `bomUseBiology` | `.FALSE.` | Enable Brooks growth, mortality, deterministic births, and biological death. Requires `bomUseLand=.TRUE.` and BOM mode. |
| `bomUseLand` | `.FALSE.` | Enable transactional beach/outside termination and schema-4 persistence. Requires BOM mode. |
| `bomTempSource` | `'NONE'` | Biology requires `'THETA'`; otherwise `NONE`. |
| `bomNSource` | `'NONE'` | Biology requires `'PTRACER'` or `'FILES'`; otherwise `NONE`. |
| `bomBiologyMissingPolicy` | `'STOP'` | `'STOP'` or `'NO_GROWTH'` when a biological field is unavailable. |
| `bomMuMaxDay` | `0` | Finite nonnegative maximum growth rate per day. |
| `bomMortDay` | `0` | Finite nonnegative mortality rate per day. |
| `bomKN` | `0` | Positive finite nutrient half-saturation when biology is active. |
| `bomTMin`, `bomTMax` | `0`, `0` | Finite temperature bounds with `bomTMin < bomTMax`. |
| `bomS0` | `0` | Initial/parent amount; must lie strictly between `bomSMin` and `bomSMax`. |
| `bomSMin`, `bomSMax` | `0`, `0` | Finite lower/upper biological amount bounds. |
| `bomBirthMaxTry` | `0` | Positive deterministic placement-attempt cap. |
| `bomNTracerIndex` | `0` | One-based active PTRACERS index when nutrient source is `PTRACER`. |
| `bomNFile` | blank | Scalar nutrient filename when nutrient source is `FILES`. |
| `bomNStartTime` | `0` | Finite first nutrient-record time. |
| `bomNPeriod` | `0` | Positive finite nutrient-record period. |
| `bomNRepCycle` | `0` | Nonnegative repeat cycle; a positive cycle must be an exact integer number of periods. |
| `bomNInScale` | `0` | Positive finite input multiplier for file nutrient. |
| `bomNFilePrec` | `0` | `32` or `64` bits with file nutrient. |
| `bomEventFile` | `'bom_events'` | Nonblank event-shard prefix when land or biology is active. |
| `bomP4SourceHead` | 40 zeros | Exactly 40 lowercase hexadecimal characters identifying the source boundary stored in schema-4 output/pickup. |

Biology-enabled capacity must satisfy both
`bomMaxParticles <= bomMaxInitRecords` and
`bomMaxParticles <= nPx*nPy*nSx*nSy*bomMaxPartTile`.

## Compile-time capacities

The stock values in `BOM_SIZE.h` are part of the executable fingerprint:

| Symbol | Stock value | Meaning |
|---|---:|---|
| `bomMaxPartTile` | 64 | Owner slots per local tile. |
| `bomMaxInitRecords` | 10000 | Global initial-record and ID scratch capacity. |
| `bomMaxGhostTile` | 10000 | Ghost storage bound. |
| `bomMaxExchange` | 10000 | Owner-migration packet bound. |
| `bomMaxNeighbor` | 10000 | Neighbor/cell-graph bound. |
| `bomMaxEventBuffer` | 10000 | Unflushed event bound. |

Changing these values requires rebuilding every restart-compatible executable.
Do not use a changed-capacity binary to continue an archived run unless its
complete pickup compatibility has been requalified.
