# MITGCM-BOM verification

This directory stores source-controlled test definitions, reference locks, and
compact evidence for MITGCM-BOM. Build trees, executables, runtime output, and
external environmental datasets remain outside the repository.

## Layout

- reference/: locked MITgcm and Julia reference revisions and dependency data;
- phase00-skeleton/: P0.2 compile/link and zero-impact regression evidence;
- phase00-lifecycle/: P0.3 package-switch and lifecycle-hook evidence;
- phase00-zero-particle/: P0.4 formal serial/MPI zero-particle gate,
  negative checks, and requirements traceability;
- phase00-final-gate/: P0.5 locked Julia smoke, fresh P0.4 rerun,
  Phase-0 exit audit, and stacked merge plan;
- phase01-bom-lite/: P1.0 requirements/test baseline plus the P1.1
  state/initial-file generator, serial/MPI/debug gate, compact results,
  and the staged plan for mapping, leeway integration, owner migration,
  trajectory output, pickup restart, FLT coexistence, final integration
  evidence, and the independent Phase 1 exit audit;
- phase01-mapping/: P1.2 regular Cartesian/spherical mapping, 360-degree
  longitude normalization, inverse mapping, and unsupported-grid guards;
- phase01-fields/: P1.2 single-level C-grid surface-field construction,
  east/north rotation, dry masking, and serial/MPI scalar-halo gates;
- phase01-interp/: P1.2 shared-weight wet-pair interpolation, non-moving
  production lifecycle diagnostics, and caller-level collective failure
  contracts in serial and MPI4 layouts;
- phase01-setup/: P1.3 first production increment for trap-safe setup
  preflight, immutable expected-owner initialization, and frozen NONE/EXF
  wind snapshots in serial and MPI4;
- phase01-rhs/: P1.3 stateless SI Leeway RHS, Cartesian/spherical native
  coordinate rates, end-to-end EXF wind composition, stable failure/stage
  codes, stage CFL, and locked Julia algebra in serial and MPI4;
- phase01-rk2/: P1.3 stateless explicit-midpoint RK2, final-position
  diagnostic refresh, overflow-safe trial coordinates, second-order affine
  convergence, and staged rollback in serial and MPI4;
- phase01-rk4/: P1.3 stateless classical RK4, exponent-scaled stage and
  normalized weighted-final coordinate updates, fourth-order affine
  convergence, and K1--K4/FINAL rollback attribution in serial and MPI4;
- phase01-lifecycle/: P1.3 release splitting, transactional production
  caller, compact owner/ID/state budget, and the complete exact-head
  predecessor regression matrix;
- phase01-owner-migration/: P1.4 same-rank tile and MPI-rank owner
  migration, periodic-X transfer, exact two-word 64-bit IDs, bounded
  exchange transactions, and 1/2/4-rank decomposition consistency;
- phase01-output-pickup-coexistence/: P1.5 trajectory scheduling/schema,
  same-decomposition pickup/restart, decomposition-signature rejection,
  and independent FLT+BOM build/runtime consistency;
- phase02-slow-manifold/: P2.0 source audit, exact endpoint/Stokes/equation
  interface freeze, requirements traceability, and B04/B05/B16 plus
  negative/MPI/restart/full-regression test plan;
- phase02-endpoint-state/: P2.1 focused increments for frozen runtime
  parameters, stable source/endpoint/failure/stage codes, deterministic
  state, ocean/NONE/NONE transactional endpoints, rollback, BOM-owned
  exact-time EXF wind, immutable EXF globals, production lifecycle,
  accepted-bracket interpolation, schema-2 field pickup/restart,
  serial/MPI4, policy failures, and LEEW compatibility;
- phase02-derivatives/: P2.2 nonuniform C-point SI gradients, stage-time
  derivative interpolation, Cartesian/spherical metric validity, MITgcm
  fCori, finite-checked covariant/vorticity operators, transactional
  rollback, and serial/MPI4 bitwise decomposition gates;
- phase02-rhs-components/: P2.3 separate stateless PAPER2024 and JULIA
  slow-manifold component operators, 27 diagnostic candidates, explicit/
  precombined Stokes policy, SI/sign/finite/CFL checks, rollback, and
  serial/MPI4 bitwise decomposition gates;
- phase02-stage-rk/: P2.4 exact stage-position/time environment sampling,
  transactional production RK2/RK4, B04/B05 analytical convergence,
  rollback, and serial/MPI4 gates;
- phase02-b16/: P2.4 fail-closed locked Julia preflight, 27-component RHS
  comparison, fixed-step RK2/RK4 trajectory comparison, and N07 mutations;
- phase02-integration-closure/: P2.5 schema-2 output/restart integration,
  1/2/4-rank and FLT/BOM coexistence gates, plus the final 390-row Phase 2
  aggregate and independent manifest audit;
- phase02-slow-manifold/PHASE2_INTEGRATION_RESULTS.md and
  PHASE2_EXIT_AUDIT.md: ordered PR #20--#24 integration evidence, release
  boundary and the independent Phase 2 exit decision;
- phase03-springs-neighbors/: P3.0 source audit and frozen contracts plus
  P3.1--P3.5 closeout ledgers, requirements, B07--B09/B17, final 538-row
  release gate and independent Phase 3 exit decision;
- phase03-reference-laws/: P3.1 parameter/code schema, canonical pair
  geometry, stateless Hooke/eBOMB kernels, verification-only KNN/locked Julia
  references, serial/MPI4 direct gate, and predecessor entry point;
- phase03-cutoff-graph/: P3.2 production cell-linked list and exact cutoff
  graph gates;
- phase03-spring-ensemble/: P3.3 ghost exchange, synchronous ensemble RK and
  post-commit migration gates;
- phase03-components-schema3/: P3.4 components, raft diagnostics, schema-3
  output/pickup and corruption gates;
- phase03-performance-closeout/: P3.5 complexity counters, fixed-density
  local evidence and P3-G99 entry point;
- phase03-integration-closure/: integrated P3-G99 and independent exit-audit
  drivers;
- phase04-biology-land/: P4.0 source/interface/test freeze, accepted P4.1
  T/N/Brooks gates and accepted P4.2 boundary/terminal/compact-tail gates;
  Philox births/IDs, schema 4, B14--B15/B17--B19 and P4-G99 remain staged;
- reference/phase02/: checksummed B16 inputs, fixed-step golden files, and a
  separately marked non-gating adaptive Tsit5 context trajectory;
- later phase directories: analytical, restart, MPI decomposition and
  performance tests as their implementations are added.

The authoritative build and run roots for the local Ubuntu 22.04 environment
are /home/wyl/build/mitgcm-bom and /home/wyl/runs/mitgcm-bom.
