# MITGCM-BOM user guide

MITGCM-BOM is an independent MITgcm package for one-way, surface Lagrangian
tracking. It can run a conventional leeway model (`LEEW`) or the BOM
slow-manifold equations (`BOM`) with the `PAPER2024` and `JULIA` conventions.
It does not call, wrap, or require `pkg/flt`; `ALLOW_BOM`/`useBOM` and
`ALLOW_FLT`/`useFLT` are separate compile-time and run-time switches.

This guide describes the released production interface. For an executable,
self-contained example, start with
[`verification/tutorial_MITGCM-BOM`](../../verification/tutorial_MITGCM-BOM/README.md).
The complete namelist and file contracts are in
[`BOM_PARAMETER_REFERENCE.md`](BOM_PARAMETER_REFERENCE.md) and
[`BOM_INPUT_OUTPUT_REFERENCE.md`](BOM_INPUT_OUTPUT_REFERENCE.md).

## 1. Supported production scope

The current package supports:

- regular Cartesian and spherical-polar grids;
- surface current fields from the active MITgcm state, including `pkg/offline`;
- no wind or exact-time EXF wind;
- no explicit Stokes drift, BOM-owned time-varying Stokes files, or a
  compile-time external coupler provider;
- `LEEW`, `PAPER2024`, and `JULIA` drift equations with RK2 or RK4;
- deterministic particle release, tile/rank migration, and periodic-X motion;
- Hooke and eBOMB pair laws on an exact cutoff neighbor graph;
- optional land termination, Brooks growth/mortality/birth events, event
  shards, component diagnostics, and schema-4 persistence;
- serial and MPI execution with one execution thread per rank; and
- same-decomposition pickup/restart.

The package is one-way: particles read the ocean/environment fields but do not
feed momentum, tracers, or biological state back to MITgcm. The following are
deliberately rejected rather than silently approximated:

- EXCH2, cubed-sphere, LLC, rotated, or otherwise unsupported topology;
- OpenMP/nontrivial `nTx*nTy` particle execution;
- restart with a different rank/tile decomposition;
- three-dimensional particle motion, sinking, or vertical mixing; and
- EXF wind without `ALLOW_EXF`, `useEXF=.TRUE.`, and `useAtmWind=.TRUE.`.

## 2. Build the package

Add `bom` to the experiment's `code/packages.conf`. Include `exf` when EXF
wind is selected, `offline` when the ocean state is supplied by `pkg/offline`,
and `ptracers` when biology reads nutrient from a passive tracer. For example:

```text
gfd
cd_code
offline
exf
bom
```

Then run the normal MITgcm build sequence:

```bash
mkdir -p build
cd build
../../../tools/genmake2 -mods ../code \
  -of ../../../tools/build_options/linux_amd64_gfortran
make depend
make -j 4
```

Add `-mpi` to `genmake2` for an MPI executable. Production BOM source files
must come from `pkg/bom`; do not copy them into an experiment's `code/`
directory. `BOM_SIZE.h` may be overridden only when a case has explicitly
audited larger compile-time capacities.

The default source deliberately leaves `ALLOW_BOM_STOKES_COUPLER` undefined.
An external system that supplies both geographic C-point Stokes components
before every endpoint transaction may define it in the experiment's
`CPP_OPTIONS.h`. Selecting `bomStokesSource='COUPLER'` without that capability
is a fatal configuration error.

## 3. Enable BOM at run time

Set the package switch in `data.pkg`:

```fortran
 &PACKAGES
 useOffLine=.TRUE.,
 useEXF=.TRUE.,
 useBOM=.TRUE.,
 &
```

`useBOM=.FALSE.` is the default. A BOM-linked executable with the switch off
does not read `data.bom`, does not allocate active particles, and does not
write BOM output.

A minimal BOM slow-manifold configuration is:

```fortran
 &BOM_PARM01
 bomMode='BOM',
 bomEquationMode='JULIA',
 bomIntegrator='RK4',
 bomDeltaTTarget=900.,
 bomOutputFreq=900.,
 bomPickupFreq=0.,
 bomMaxParticles=3,
 bomInitialIter=0,
 bomInitialFile='bom_particles',
 bomSpringLaw='NONE',
 bomNeighborPolicy='NONE',
 &
 &BOM_PARM02
 bomCurrentPolicy='EULERIAN',
 bomAlpha=0.00337,
 bomTauDays=0.0103,
 bomR=0.823,
 bomSigma=1.2,
 bomLeewayWindCoeff=0.,
 bomWindSource='EXF',
 bomStokesSource='FILES',
 bomUStokesFile='ustokes.bin',
 bomVStokesFile='vstokes.bin',
 bomStokesStartTime=0.,
 bomStokesPeriod=900.,
 bomStokesRepCycle=0.,
 bomStokesInScale=1.,
 bomStokesFilePrec=64,
 bomWetWeightMin=0.999999,
 bomAdvCFL=0.5,
 bomMaxHop=8,
 bomInitGlobalLimit=1000,
 bomCheckEverySubstep=.TRUE.,
 &
 &BOM_PARM03
 bomUseBiology=.FALSE.,
 bomUseLand=.FALSE.,
 bomTempSource='NONE',
 bomNSource='NONE',
 &
```

`BOM_PARM01` is required. Keep `BOM_PARM02` and `BOM_PARM03`, even when their
features are inactive, so the case documents every source choice explicitly.

## 4. Choose the physical convention

`bomMode='LEEW'` integrates surface current plus
`bomLeewayWindCoeff * wind`; Stokes drift and Phase-3/4 functions are not
available in that mode.

`bomMode='BOM'` evaluates the inertial slow-manifold velocity. The two
equation conventions are separate, stateless implementations:

- `PAPER2024` follows the published 2024 notation and sign convention;
- `JULIA` follows the locked Julian reference implementation used by the
  scientific comparison cases.

Both consume the same accepted endpoint state and expose the same 27-component
diagnostic vector. They are not aliases and should not be mixed inside a
restart chain. `RK4` is the recommended general-purpose integrator; `RK2` is
available for lower cost and controlled convergence studies.

The current and Stokes policy must be unambiguous:

- `EULERIAN`: the base current excludes Stokes drift; choose `FILES` or
  `COUPLER` to add explicit Stokes drift, or `NONE` with `bomSigma=0`;
- `PRECOMBINED`: the supplied current already contains the desired Stokes
  contribution; explicit Stokes input is rejected to prevent double counting.

EXF wind is sampled at every RK endpoint. In BOM mode `bomAlpha` controls the
wind contribution; `bomLeewayWindCoeff` remains zero. In LEEW mode the leeway
coefficient is active and must lie in `[0,0.1]`.

## 5. Particle time stepping

`BOM_MAIN` is called once from `FORWARD_STEP` after the ocean/environment
fields for the step are available. For each ocean step it:

1. admits scheduled releases and builds transactional OLD/NEW environmental
   endpoints;
2. computes a particle substep count from `bomDeltaTTarget`;
3. samples fields and derivatives at the actual RK stage position and time;
4. evaluates the selected leeway or slow-manifold right-hand side;
5. applies optional spring/neighbor forces;
6. checks wet interpolation, CFL, finite values, owner migration, and global
   state budgets before committing the step;
7. applies optional land/biology events atomically; and
8. publishes scheduled trajectory output.

The effective particle step is
`deltaTClock / ceil(deltaTClock / bomDeltaTTarget)`. A failed stage leaves the
accepted particle state unchanged and terminates the run with a stable failure
and stage code.

## 6. Initial particles

`bomInitialFile` is an MDS prefix, normally `bom_particles`, with matching
`.data` and `.meta` files. The binary is big-endian float64 and begins with an
eight-value schema header, followed by one eight-value record per particle.
Use the tutorial generator rather than constructing the file by hand:

```bash
python3 verification/tutorial_MITGCM-BOM/input/gendata.py /tmp/bom-input
```

Particle IDs are positive 64-bit integers encoded as exact unsigned high and
low 32-bit words. Initial positions use physical Cartesian metres or spherical
degrees according to the active grid. An `ALIVE` record must have a release
time no later than the model start; a future record must use `WAITING` with
zero age.

## 7. Output and restart

With `bomOutputFreq>0`, each scheduled frame writes tiled
`bom_traj.<suffix>.*.data` files. BOM mode uses a 48-field schema-2 core that
contains particle position, velocity, ownership, and all 27 slow-manifold
diagnostics. Spring runs add `.p3` and `.p3sig` sidecars. Land/biology runs add
`.p4`, `.p4sig`, `.p4bio`, and `.p4manifest` members plus append-only event
shards.

MITgcm checkpoint scheduling (`pChkptFreq`, `chkptFreq`, or the normal package
pickup call) writes `pickup_bom.<suffix>*`. Keep `bomPickupFreq=0`; it is a
reserved compatibility field and the configuration checker currently requires
zero. BOM pickup contains particles, accepted environmental endpoints, output
schedule, equation/source fingerprint, and conditional Phase-3/4 state.

A restart must use the same `SIZE.h`, rank/tile decomposition, equation mode,
source policy, and relevant package configuration. The reader validates every
member into scratch state and commits only after all ranks agree. A missing,
truncated, corrupt, or incompatible member is fatal before any restarted
trajectory frame is published.

Use `analysis/plot_bom.py` from the tutorial to combine tiled trajectory
records into CSV and a plan-view figure.

## 8. Springs, rafts, land, and biology

Spring dynamics are enabled only in BOM mode. A non-`NONE` spring law requires
`bomNeighborPolicy='CUTOFF'`, positive length/cutoff/minimum-distance/CFL
parameters, and a cutoff larger than the minimum distance. `HOOKE` uses
`bomHookeK`; `EBOMB` uses `bomSpringA` and `bomSpringDelta`.

Land-only termination sets `bomUseLand=.TRUE.` and keeps biology disabled.
Full biology additionally requires land handling, temperature from `THETA`,
nutrient from `PTRACER` or time-varying `FILES`, valid Brooks parameters, and
a positive spring equilibrium length for child placement. Birth IDs, random
draws, graph updates, terminal state, events, and budgets are deterministic
across the admitted MPI decompositions.

These advanced paths are intentionally absent from the introductory tutorial.
Start from a qualified Phase-4 configuration and change one feature at a time.

## 9. Capacity and parallel layout

The stock `BOM_SIZE.h` provides:

- 64 owner slots per local tile;
- 10,000 initial records;
- 10,000 ghost, exchange, neighbor, and event-buffer records.

`bomMaxParticles` cannot exceed the global initial-record limit or the sum of
tile owner slots. A dense case may therefore require a reviewed `BOM_SIZE.h`
override and a new build. Runtime checks stop before buffer overflow; they do
not truncate owners, neighbors, births, or events.

MPI owner migration is supported at the admitted decomposition. Set
`nTx=1,nTy=1` in `eedata`. OpenMP safety and large-HPC capacity/performance are
separate acceptance work and are not claimed by this guide.

## 10. Diagnose a failed start or step

Inspect `STDOUT.0000` and search for `BOM_CHECK`, `BOM_MAIN`, or
`BOM_FAIL_`. Common causes are:

- `bomCurrentPolicy` left at the default `UNSET` in BOM mode;
- nonzero `bomAlpha` with `bomWindSource='NONE'`;
- nonzero `bomSigma` with `bomStokesSource='NONE'`;
- explicit Stokes combined with `PRECOMBINED` current;
- EXF selected but not compiled or activated;
- output frequency shorter than `deltaTClock`;
- initial count, tile capacity, wet-weight, or CFL rejection;
- spring or biology parameters partly enabled; or
- pickup members from a different decomposition or configuration.

The checker prints the accepted mode, sources, substep ratio, and compile-time
limits before the first step. Preserve those lines with the executable hash,
input manifest, and run command when archiving a simulation.

## 11. Scientific qualification boundary

The production package has passed real MITgcm build/run, direct Julian and
PAPER2024 trajectory comparisons, released-feature/schema-4 qualification,
dynamic-ocean one-way coupling, same-decomposition restart/MPI checks, and a
30-day endurance run. These results do not constitute field-observation
validation, changed-decomposition restart acceptance, OpenMP acceptance, or
large-HPC performance acceptance.
