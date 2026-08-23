# P1.2 surface-field construction test plan

| Gate | Decomposition | Acceptance rule |
|---|---|---|
| source contract | source audit | production `BOM_MAIN` calls `BOM_BUILD_FIELDS`; the builder calls the real rotation once and scalar exchange exactly twice; verification markers remain outside `pkg/bom` |
| P1-F01 serial | four local tiles, `Nr=2` | uniform surface U/V remains exact after C-grid colocation; work arrays copy only `k=1`; metadata is published last; zero particles return without building |
| P1-F01 MPI4 | 2 x 2 ranks, one tile/rank, `Nr=2` | uniform east/north values and two-layer internal scalar halos agree across rank boundaries |
| P1-F02 serial | four local tiles, `Nr=2` | analytic nonuniform face averages, 90-degree rotation signs, dry-cell zeros, and local-tile scalar halos match |
| P1-F02 MPI4 | 2 x 2 ranks, one tile/rank, `Nr=2` | the same analytic field and deliberately conflicting local halo rotations are replaced by owner values across rank boundaries |

All builds use fresh external directories, GNU bounds checking,
floating-point traps, Bash syntax checking, ShellCheck, symbol audits, and
normal/abnormal log markers.

This increment does not implement `BOM_INTERP_WET_PAIR`, P1-F03/P1-N05,
wind or Stokes fields, particle motion, owner exchange, trajectory, or pickup.
