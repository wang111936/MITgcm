# Tutorial: MITGCM-BOM controlled surface drift

This tutorial builds a production MITgcm executable with `pkg/bom`, generates
all binary inputs, integrates three surface particles for six hours, decodes
the tiled schema-2 trajectory, and creates CSV, JSON, and PNG products.

The case is a short, self-contained descendant of the qualified Phase-5
controlled Cartesian experiment:

- grid: `8 x 6 x 2`, 50 km horizontal cells, all wet;
- ocean/particle step: 900 s, 24 steps, 21,600 s total;
- current: time-varying affine C-grid fields from `pkg/offline`;
- wind: exact-time affine EXF fields;
- Stokes drift: exact-time BOM-owned file fields;
- particles: IDs 1001--1003 at three interior locations;
- equation: `JULIA` by default, with a `PAPER2024` alternative; and
- integrator: production RK4 through `FORWARD_STEP -> BOM_MAIN`.

This is an executable user tutorial, not a replacement for the locked Julia
or Phase-5 scientific acceptance gates.

## Prerequisites

- Linux, GNU `make`, `gfortran`, and the normal MITgcm build prerequisites;
- Python 3.9 or newer;
- Matplotlib for the PNG plot;
- a valid `genmake2` option file.

The bundled default option file is
`tools/build_options/linux_amd64_gfortran`. Override it with the
`MITGCM_BOM_OPTFILE` environment variable.

## One-command run

From this directory:

```bash
./run_tutorial.sh \
  --work-root /tmp/MITGCM-BOM-tutorial-julia \
  --equation JULIA
```

The script refuses an existing work root so it cannot silently mix a previous
build or run into the result. Choose a new directory or remove/archive the old
one yourself.

Successful completion prints:

```text
MITGCM-BOM TUTORIAL PASS
```

The products are:

```text
/tmp/MITGCM-BOM-tutorial-julia/
  build/                 genmake, dependency, compiler logs and mitgcmuv
  input/                 generated input bundle, manifest and SHA256SUMS
  run/                   STDOUT.0000, pickups and tiled BOM trajectories
  analysis/
    bom_trajectory.csv
    bom_trajectory_summary.json
    bom_trajectory.png
```

To use the published-equation convention:

```bash
./run_tutorial.sh \
  --work-root /tmp/MITGCM-BOM-tutorial-paper2024 \
  --equation PAPER2024
```

Do not continue a JULIA pickup with a PAPER2024 configuration, or vice versa.
The pickup signature intentionally rejects that change.

## Manual workflow

Generate a complete input bundle:

```bash
python3 input/gendata.py /tmp/MITGCM-BOM-input --equation JULIA
cd /tmp/MITGCM-BOM-input
sha256sum --check SHA256SUMS
```

Build:

```bash
mkdir -p /tmp/MITGCM-BOM-build
cd /tmp/MITGCM-BOM-build
/path/to/MITgcm/tools/genmake2 \
  -rootdir=/path/to/MITgcm \
  -mods=/path/to/MITgcm/verification/tutorial_MITGCM-BOM/code \
  -of=/path/to/MITgcm/tools/build_options/linux_amd64_gfortran
make depend
make -j 4
```

Run from a clean directory containing symlinks to every generated input file:

```bash
/tmp/MITGCM-BOM-build/mitgcmuv > STDOUT.0000 2> STDERR.0000
```

Decode and plot:

```bash
python3 analysis/plot_bom.py \
  --run-dir /tmp/MITGCM-BOM-run \
  --output-dir /tmp/MITGCM-BOM-analysis \
  --expected-frames 24 \
  --expected-particles 3 \
  --expected-final-time 21600
```

## What to inspect

1. `input/input-manifest.json` records dimensions, exact affine coefficients,
   particle records, equation choice, timing, byte counts, and SHA-256 values.
2. `run/STDOUT.0000` must show the selected sources and
   `PROGRAM MAIN: Execution ended Normally`.
3. The trajectory summary must report 24 frames, three unique IDs, final time
   21,600 s, finite values, and one record for every ID in every frame.
4. The PNG should show three smooth, distinct tracks remaining inside the
   400 km by 300 km domain.
5. `pickup_bom.*` members at the half-run checkpoints demonstrate that the
   full package pickup path was exercised even though the tutorial does not
   split the run.

## Extending the case

Change only one interface at a time and regenerate into a new work root:

- increase `endTime` and update the generator's `N_STEPS`;
- set `bomIntegrator='RK2'` for an integrator comparison;
- set wind to `NONE` and `bomAlpha=0` for a current/Stokes-only case;
- set Stokes to `NONE` and `bomSigma=0` for a current/wind-only case; or
- replace `pkg/offline` with an active online ocean while retaining the
  explicit current/Stokes policy.

Springs, land, biology, MPI layout changes, and compile-time capacity changes
should start from their qualified configurations and require additional
feature-specific validation. They are intentionally not hidden inside this
introductory example.
