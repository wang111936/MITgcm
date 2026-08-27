# P2.4 B16 locked reference files

This directory contains the source-controlled, fail-closed Phase-2 B16
fixture. Generated build trees, Julia depots, and the external reference
checkout remain outside Git.

## Files

- `input_fields_v1.csv`: affine base-current, Stokes and wind coefficients;
- `input_particles_v1.csv`: three stable particle IDs and initial positions;
- `input_parameters_v1.toml`: domain, time grid and frozen JULIA parameters;
- `golden_rhs_julia_v1.csv`: 3 particles at 3 times, native RHS and all 27
  component diagnostics;
- `golden_traj_julia_rk2_v1.csv` and
  `golden_traj_julia_rk4_v1.csv`: 97 output times per particle and path
  length for the two accepted fixed-step methods;
- `context_tsit5_julia_v1.csv`: actual adaptive Tsit5 output at the same 97
  reporting times, explicitly marked `gating=false`;
- `input_checksums.sha256`, `golden_checksums.sha256`, and
  `context_checksums.sha256`: separate provenance domains.

The fixed-step generator reproduces the locked Julia compatibility algebra,
including per-source self material derivatives and base-current vorticity.
The Tsit5 generator imports the locked project's declared
`OrdinaryDiffEqTsit5` dependency and uses the same frozen RHS.

## Reproduction

With the locked source checkout and Julia runtime in their documented local
locations:

```bash
python3 verification/bom/reference/phase02/verify_b16_preflight.py \
  --mode input \
  --phase-dir verification/bom/reference/phase02 \
  --source-root /home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl \
  --julia-bin /home/wyl/tools/julia-1.10.12/bin/julia \
  --project-file verification/bom/reference/julia_env/Project.toml \
  --manifest-file verification/bom/reference/julia_env/Manifest.toml

/home/wyl/tools/julia-1.10.12/bin/julia --startup-file=no \
  --project=verification/bom/reference/julia_env \
  verification/bom/reference/phase02/generate_b16_golden.jl \
  OUTPUT_DIR verification/bom/reference/phase02 \
  /home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl \
  verification/bom/reference/julia_env/Project.toml \
  verification/bom/reference/julia_env/Manifest.toml

/home/wyl/tools/julia-1.10.12/bin/julia --startup-file=no \
  --project=verification/bom/reference/julia_env \
  verification/bom/reference/phase02/generate_b16_tsit5_context.jl \
  OUTPUT.csv verification/bom/reference/phase02 \
  /home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl \
  verification/bom/reference/julia_env/Project.toml \
  verification/bom/reference/julia_env/Manifest.toml
```

`verify_b16_preflight.py --mode full` additionally checks the fixed golden
and non-gating context manifests. Any source, environment, input or artifact
change requires an explicit new version and design decision; the preflight
must never silently update the lock.
