# MITGCM-BOM: Maxey–Riley particle tracking for Geophysical Fluid Dynamics

**MITGCM-BOM** is an independent **MITgcm (MITGCM)** package for surface
Lagrangian particle tracking in **Geophysical Fluid Dynamics**. It implements
Maxey–Riley-based **BOM slow-manifold dynamics** to study why floating material
can follow different trajectories from particles advected by ocean currents
alone, including optional windage, Stokes drift and Sargassum raft processes.

[简体中文](README.zh-CN.md) · [User guide](pkg/bom/README.md) ·
[Runnable tutorial](verification/tutorial_MITGCM-BOM/README.md)

**Developed by Dr. Yulin Wang , College of Ocean and Meteorology,
Guangdong Ocean University.**

Contact: [wang111936@outlook.com](mailto:wang111936@outlook.com)

Research pre-release: this is an independently maintained MITgcm extension,
not an upstream-endorsed module or an HPC-qualified v1.0 release.

## What problem does it solve?

Ocean-current advection alone does not describe every surface floating object.
MITGCM-BOM provides a configurable framework for investigating the contribution
of inertial response, direct wind forcing and wave-induced Stokes transport
using fields from a running MITgcm ocean model or its offline configuration.

- **Inertial particle transport:** compare conventional leeway motion with the
  BOM slow-manifold velocity, with separate `PAPER2024` and locked `JULIA`
  equation conventions. This is not a solver for every term of the full
  unreduced Maxey–Riley equation.
- **Floating raft interactions:** optionally add Hooke or nonlinear eBOMB
  springs and connected-component diagnostics for particle aggregates.
- **Sargassum-oriented life-cycle experiments:** optionally enable
  temperature/nutrient-dependent growth, births, deaths and coastal terminal
  events. These capabilities do not by themselves constitute a calibrated
  operational Sargassum forecast.
- **Reproducible numerical experiments:** use RK2/RK4, serial/MPI execution,
  same-decomposition restart and trajectory diagnostics. The optional MDS
  `ARCHIVE` mode keeps trajectory file counts fixed within each startup segment.

## How is BOM different from FLT?

| Question | MITGCM-BOM (`pkg/bom`) | MITgcm FLT (`pkg/flt`) |
|---|---|---|
| Main purpose | Surface floating-material transport with BOM inertial physics and optional raft/life-cycle processes | Ocean float and drifter advection, profiling floats and mooring-like sampling |
| Particle motion | Two-dimensional surface motion; leeway or Maxey–Riley-based slow-manifold dynamics | Model-velocity-driven float motion, including depth/profiling and three-dimensional options |
| Additional processes | Configurable direct wind and Stokes contributions, Hooke/eBOMB interactions and Brooks biology | Does not implement the BOM slow-manifold, spring or Brooks kernels |
| Package dependency | Independent particle state, configuration and lifecycle; does not call or require FLT | Separate native MITgcm package; does not require BOM |
| Typical choice | Investigate surface inertial drift, wind/wave effects or interacting floating rafts | Simulate model floats, surface drifters, depth-dependent float motion or profiling observations |

**BOM is neither an FLT wrapper nor a replacement for every FLT use case.**
The two packages can be compiled and enabled independently, or used together
for controlled comparisons. Matching initial positions does not guarantee
identical trajectories when physics, interpolation or time stepping differs.

## Start with a small, reproducible case

Prerequisites: Linux, a Fortran compiler such as GNU `gfortran`, GNU `make`,
the normal MITgcm build tools, Python 3.9+ and Matplotlib for plotting.
MPI is needed for parallel cases, not for the serial tutorial below.

```bash
git clone --branch MITGCM-BOM/development --single-branch \
  https://github.com/wang111936/MITgcm.git MITGCM-BOM
cd MITGCM-BOM
git rev-parse HEAD
cd verification/tutorial_MITGCM-BOM
./run_tutorial.sh \
  --work-root /tmp/MITGCM-BOM-tutorial-paper2024 \
  --equation PAPER2024
```

Use a new work directory for each run. The tutorial builds `mitgcmuv`,
generates its own small input dataset, integrates three particles for six
hours and produces trajectory CSV, JSON and PNG files. Successful completion
prints `MITGCM-BOM TUTORIAL PASS`. Its plotting path uses `FRAME` output;
ARCHIVE has a separate [validation/decoder tool](verification/bom/phase05-trajectory-archive/README.md).

## Documentation and current support

- [Package guide and physical conventions](pkg/bom/README.md)
- [Runtime parameters and optional switches](pkg/bom/BOM_PARAMETER_REFERENCE.md)
- [Initial files, trajectory output and pickup formats](pkg/bom/BOM_INPUT_OUTPUT_REFERENCE.md)
- [Pre-release scope and known limitations](doc/phys_pkgs/MITGCM-BOM/PRE_RELEASE_2026-09-14.md)
- [Published qualification summaries](doc/phys_pkgs/MITGCM-BOM/PRE_RELEASE_EVIDENCE_2026-09-14/README.md)
- [Development status and remaining work](doc/phys_pkgs/MITGCM-BOM/PROJECT_STATUS.md)

The 2026-09-14 pre-release passed **66/66 targeted qualification rows**;
the earlier scientific baseline passed **754/754**, with a separate **21/21**
exit audit. These results belong to the revisions and test matrices recorded
in the linked evidence; they are not claims of complete HPC or field validation.

Current support is regular Cartesian/spherical-polar grids, one-way surface
particles, one execution thread per MPI rank and same-decomposition restart.
S1 stochastic trajectory diffusion and per-particle extended biological
cold-start input are not implemented. Event-buffer/incremental-I/O hardening,
OpenMP and target-HPC qualification remain open; particle MNC/NetCDF output
is deferred. See the support limits before adapting a regional case.

## Questions and contributions

For scientific questions or collaboration, contact
[Dr. Yulin Wang](mailto:wang111936@outlook.com).
For a reproducible problem, use the [issue tracker](https://github.com/wang111936/MITgcm/issues)
and include the source revision, compiler/MPI versions, grid/rank layout,
relevant namelists and the first error in the run log. Do not attach credentials
or restricted input data. Discuss substantial new physics before implementation.

## Scientific basis, upstream and attribution

The development attribution above refers to the **MITGCM-BOM implementation
and integration**, not authorship of the original MITgcm model or the original
BOM theory and reference software.

- Bonner, Beron-Vera and Olascoaga (2024),
  [Charting the course of Sargassum: Incorporating nonlinear elastic interactions and life cycles in the Maxey–Riley model](https://arxiv.org/html/2410.01468v1).
- [SargassumBOMB.jl reference implementation](https://github.com/70Gage70/SargassumBOMB.jl),
  with the exact comparison baseline documented in the [reference lock](doc/phys_pkgs/MITGCM-BOM/REFERENCE_LOCK.md).
- [MITgcm upstream model](https://mitgcm.org/) and
  [upstream documentation](https://mitgcm.readthedocs.io/en/latest/).
- [License and original copyright notices](LICENSE.txt) remain in place.

Keywords: MITGCM, MITgcm, BOM, Maxey-Riley, Geophysical Fluid Dynamics,
Lagrangian particle tracking, inertial particles, ocean modeling,
oceanography, surface drifters, Sargassum, elastic rafts, windage,
Stokes drift, Fortran, MPI and scientific computing.
