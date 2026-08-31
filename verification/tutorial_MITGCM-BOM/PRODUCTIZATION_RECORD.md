# MITGCM-BOM user productization record

Status: **COMPLETE — fresh production build/run and user products pass**

## Scope

This increment turns the Phase-5-qualified package into a usable source-tree
product without changing production Fortran:

- package overview, build/run quick start, supported-scope boundary and
  troubleshooting guide;
- exhaustive `data.bom` parameter reference;
- initial, environmental, trajectory, sidecar, event and pickup/restart
  interface reference;
- self-contained six-hour controlled tutorial with readable namelists;
- deterministic standard-library input generator and SHA-256 manifest;
- safe fresh-root build/run driver; and
- independent tiled schema-2 decoder producing CSV, JSON and a two-panel PNG.

No external-project source, build, run, or artifact is used. No HPC,
changed-decomposition, OpenMP, EXCH2, two-way-coupling, or observation
validation claim is added.

## Validation environment

| Item | Value |
|---|---|
| Production Fortran parent | `2447777a3412a184de7dcdcd00aef3b7a1a2ed13` |
| OS | Ubuntu 22.04 under the local WSL development environment |
| Option file | `tools/build_options/linux_amd64_gfortran` |
| Build mode | GNU serial, `genmake2 -ieee -devel`, four make jobs |
| Tutorial equation | `JULIA` |
| Test ID | `tutorial_MITGCM-BOM-julia-20260831-attempt01` |
| Work root | `/home/wyl/runs/mitgcm-bom/tutorial_MITGCM-BOM-julia-20260831-attempt01` |
| Executable SHA-256 | `55ed8337fe5839bcd4368a461cd81819820235af1ada1b5ece9a4e77f5b8401b` |

## Results

| Check | Result |
|---|---|
| Bash/Python entry-point syntax | PASS |
| JULIA input generation | PASS; 97 files, 26 forcing records |
| Complete input `SHA256SUMS` | PASS |
| Independent decoder on prior P5.4 O01 output | PASS; 10 frames, 3 IDs, 30 records |
| Fresh `genmake2`, dependency and compiler build | PASS |
| Production `FORWARD_STEP -> BOM_MAIN` run | PASS; 24/24 steps, normal MITgcm completion |
| Trajectory structure | PASS; schema 2, width 48, 24 frames, 96 tile files |
| Owner budget | PASS; 3 IDs in every frame, 72 records, no duplicate/missing ID |
| Numeric/status checks | PASS; every decoded value finite, all final statuses `ALIVE` |
| Pickup publication | PASS; half-run and final scheduled BOM pickups present |
| CSV/JSON/PNG generation | PASS |
| Visual inspection | PASS; full-domain positions and resolved relative displacements |

The exact local endpoints and path lengths are recorded in
`results/expected_julia_summary.json`. They are a same-toolchain regression
reference; portable tutorial acceptance is structural. The Phase-5 locked
Julia/PAPER2024 oracles remain the scientific source of truth.

## Boundaries after this increment

The tutorial proves that a new user can generate inputs, compile the package,
run a real MITgcm integration and inspect BOM output from the source tree.
It does not close P5.5/P5-SA-G99 or the later HPC acceptance work. No release
tag is created by this increment.
