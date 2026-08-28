# P3.2 cutoff graph test results

Decision: **PASS; READY FOR DRAFT REVIEW**

Unified clean functional source head:
`5e57bfbfcac2d49d037f7240819082feb32d38d0`

Branch: `MITGCM-BOM/p3.2-cutoff-graph`

Environment: Ubuntu 22.04, GNU Fortran debug/IEEE/bounds builds, Open MPI
MPI4. Evidence is stored outside the source repository.

## Gate results

| Gate | Result | Evidence root |
|---|---:|---|
| P3.2 cutoff graph direct gate | 18/18 PASS | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p32-cutoff-graph/p32-cutoff-5e57bfbfca-attempt01` |
| Accepted P3.1 reference-law regression | 34/34 PASS | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p31-reference-laws/p31-reference-5e57bfbfca-attempt01` |
| Complete Phase 2 predecessor regression | 390/390 PASS | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-closure/p25-closure-5e57bfbfca-attempt01` |

Each evidence root contains metadata, source-head and baseline records, captured
Git status, source hashes, logs, summary rows and a verified SHA-256 manifest.
The authoritative runs captured an empty worktree status.

## Direct P3.2 coverage

The frozen 18-row matrix contains:

- serial and MPI4 debug/IEEE/bounds builds with required production symbols;
- P3-L01 half-open Cartesian indexing, exact-face behavior, traversal,
  inactive exclusion and same-rank cross-tile flattened owners;
- P3-N01 exact inclusive cutoff, self exclusion, ID sorting, owner/ghost
  duplicate suppression and reverse-edge symmetry;
- P3-L02 conservative latitude-dependent spherical reach, exact false-positive
  removal, periodic longitude seam and pole-singularity rollback;
- P3-N02 five deterministic randomized production-cell-list versus
  verification-all-pairs comparisons, including IDs, geometry, distance,
  Hooke stiffness and accumulated owner velocity;
- P3-N10 exact cell, link, candidate and neighbor capacity need/capacity pairs,
  stable phase codes and unchanged output sentinels;
- P3-X01 a 48-owner fixed-density lattice with 82 undirected edges, 164
  directed edges, maximum degree four and bounded candidate comparisons;
- five sorted `P32-GRAPH-RECORD` lines that are bitwise identical between
  serial and MPI4 runs;
- structural proof that production contains no all-pairs or global gather path
  and that the new kernels remain outside the live dispatcher until P3.3.

## Defects detected during development

Bounds-check testing exposed and fixed a candidate insertion-sort loop that
relied on non-guaranteed Fortran logical short-circuit evaluation. Spherical
testing exposed and fixed three input/output aliases in finite-safe arithmetic
calls. Both corrections are in the verified functional head.

## Reproduction

```bash
verification/bom/phase03-cutoff-graph/run_cutoff_graph_gate.sh
MITGCM_BOM_SCOPE_MODE=p32 \
  verification/bom/phase03-reference-laws/run_reference_law_gate.sh
MITGCM_BOM_EXPECTED_HEAD=5e57bfbfcac2d49d037f7240819082feb32d38d0 \
  verification/bom/phase03-reference-laws/run_phase2_regression_gate.sh
```

P3.2 does not authorize merge, live spring integration or a
`MITGCM-BOM-v0.4` tag. Those remain later package decisions.
