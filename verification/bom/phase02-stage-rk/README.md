# MITGCM-BOM P2.4 stage-time RK verification

Status: **P2.4 functional gate implemented; exact-head closure pending**

This case verifies the production slow-manifold stage sampler and the
transactional explicit midpoint RK2/classical RK4 integrators. The
implementation maps each trial position to its C-point stencil, evaluates
all accepted old/new values and derivatives at the exact stage time, uses one
common wet bilinear weight, calls the P2.3 stateless RHS dispatcher, and
publishes authoritative particle state only after the FINAL refresh succeeds.

## Production interfaces

- `BOM_RHS_SLOW_MANIFOLD`: stage-position/time sampling, source policy,
  metric data, P2.3 component dispatch, and native coordinate rate;
- `BOM_RK2_SLOW_MIGRATE`: stages at `t` and `t+h/2`, then FINAL at `t+h`;
- `BOM_RK4_SLOW_MIGRATE`: stages at `t`, `t+h/2`, `t+h/2`, and `t+h`,
  then FINAL at `t+h`;
- `BOM_MAIN`: BOM/LEEW dispatch and one-point commit of position, status,
  age, mapping, sampled fields, drift, and all 27 diagnostics;
- `BOM_PARTICLE_EXCHANGE`: diagnostic-preserving reorder/migration and
  target-owner final diagnostic refresh.

No failed stage may update authoritative position or diagnostics. K1 runs on
the strict current owner; later trial positions may use the accepted halo.
Failure and stage codes remain the frozen P2.0 codes.

## Direct gates

| ID | Coverage |
|---|---|
| P2-I01 | B04 exact gradients, vorticity, material acceleration, rotation signs, inertia and drift through production sampling |
| P2-I02 | B04 RK2 second-order and RK4 fourth-order trajectory convergence over four step sizes |
| P2-I03 | B05 affine-time ocean, Stokes and wind values/secants/components and analytic displacement |
| P2-I04 | B05 quadratic-time accepted-endpoint refinement plus injected K2 failure rollback of the full authoritative state |

The driver builds GNU IEEE/development serial and MPI4 executables and runs
all four assertions in both layouts. Its summary contains 11 required PASS
rows:

```bash
verification/bom/phase02-stage-rk/run_stage_rk_gate.sh
```

## Boundary

P2.4 stores the stable 27-component diagnostic vector in live particle
state, but does not extend trajectory output or pickup schemas. Schema-2
particle output/restart integration, 1/2/4-rank total-system comparison and
FLT coexistence remain P2.5 scope.
