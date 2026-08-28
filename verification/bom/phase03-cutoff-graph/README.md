# MITGCM-BOM P3.2 cutoff graph

Status: **FUNCTIONAL HEAD VERIFIED; REVIEW/INTEGRATION PENDING**

P3.2 implements the owner-local production cutoff graph frozen by P3.0. It
does not integrate the graph into the live ensemble step; distributed ghost
exchange and synchronous spring RK remain P3.3 work.

## Production owners

- `pkg/bom/BOM_GRAPH_SIZE.h`: compile-time local record, cell and reused
  candidate bounds;
- `pkg/bom/bom_init_cell_geometry.F`: transactional Cartesian/spherical cell
  plan with half-open indexing and conservative per-row spherical reach;
- `pkg/bom/bom_build_cell_list.F`: transactional owner/ghost head-next list;
- `pkg/bom/bom_build_neighbors.F`: ID-sorted duplicate-free exact inclusive
  cutoff graph, symmetry validation, capacity diagnostics and work counters.

Production candidate enumeration is cell-linked. The verification-only
all-pairs oracle lives in this case's `code` directory and is not compiled
into `pkg/bom`.

## Direct gate

Run from the repository root:

```bash
verification/bom/phase03-cutoff-graph/run_cutoff_graph_gate.sh
```

The gate performs debug/IEEE/bounds-check serial and MPI4 builds, exercises
P3-L01, P3-N01, P3-L02, P3-N02, P3-N10 and P3-X01, compares five deterministic
graph/spring records bitwise across decompositions, audits production-source
isolation, freezes exactly 18 PASS rows and writes a hashed external evidence
bundle.

The accepted result and predecessor regressions are recorded in
`TEST_RESULTS.md`. The package decision is in
`../phase03-springs-neighbors/P3.2_CLOSEOUT.md`.

No `MITGCM-BOM-v0.4` tag is created at P3.2.
