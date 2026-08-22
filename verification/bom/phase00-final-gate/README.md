# P0.5 Phase-0 final gate

P0.5 closes the executable verification work for Phase 0. It verifies the
locked Julia reference without calling the stale upstream example entry point,
then reruns the complete P0.4 serial/MPI zero-particle gate.

## Coverage

- exact Julia source and custom-registry commits;
- exact locked and checkout `Project.toml`/`Manifest.toml` SHA-256 values;
- offline `Pkg.instantiate` using the dedicated Julia depot;
- package load and deterministic pure-function smoke assertions;
- a fresh P0.4 build/run covering serial, MPI-2, MPI-4, and negative gates;
- unique external result, build, and run directories with no overwrite.

The Julia smoke intentionally excludes environmental interpolants, downloaded
field data, the stale `Examples.generate_rp_example` call, and trajectory
goldens. Those are not required to close Phase 0 and remain explicit Phase 2
work. The Julia reference lock therefore remains `PROVISIONAL` until analytical
inputs and golden trajectories are established.

## Run

From the repository root:

```bash
MITGCM_BOM_TEST_ID=p05-attempt01 \
  verification/bom/phase00-final-gate/run_gate.sh
```

Optional environment variables:

- `MITGCM_BOM_FINAL_RUN_ROOT`: P0.5 result parent;
- `MITGCM_BOM_TEST_BUILD_ROOT`: P0.4 build parent;
- `MITGCM_BOM_TEST_RUN_ROOT`: P0.4 run parent;
- `MITGCM_BOM_JULIA`: Julia executable;
- `MITGCM_BOM_JULIA_DEPOT`: dedicated Julia depot;
- `MITGCM_BOM_JULIA_REFERENCE`: locked source checkout;
- `MITGCM_BOM_JULIA_REGISTRY`: locked custom-registry checkout;
- P0.4 build options such as `MITGCM_BOM_MAKE_JOBS` and
  `MITGCM_BOM_OPTFILE` are forwarded naturally through the environment.

The driver refuses to reuse any P0.5 result directory or derived P0.4
build/run directory. Runtime evidence is kept outside the source repository.
