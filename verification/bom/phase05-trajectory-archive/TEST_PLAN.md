# P5.6 trajectory archive test plan

| Gate | Evidence | Acceptance |
|---|---|---|
| P5.6-A01 | Source contract plus serial/MPI-2 debug/IEEE builds | Explicit dispatch, 64-word owner mapping, atomic claim and index commit are present; both executables link the production writer. |
| P5.6-A02 | 180 s base ARCHIVE run | One committed frame and exactly 11 files for four tiles. |
| P5.6-A03 | 480 s base ARCHIVE run | Three committed frames and still exactly 11 files. |
| P5.6-A04 | 480 s FRAME control | All 64 normalized owner words match by `(iteration, ID)`. |
| P5.6-A05 | Independent decoder | Index, tile blocks, exact ID words, times, effective counts, offsets, commits and reserves validate. |
| P5.6-A06 | Claim and dirty-directory rerun | One persistent claim exists; an existing segment is rejected and every member checksum remains unchanged. |
| P5.6-A07 | Injected base orphan tail | Index `.meta` remains authoritative; injected index/tile tails are ignored normally and rejected in strict mode. |
| P5.6-A08 | Split restart | `nIter0=0` and `nIter0=5` produce immutable 2+1-frame segments, each with 11 files. |
| P5.6-A09 | Base MPI-2 | Two ranks publish four tile streams through one ordered index. |
| P5.6-A10 | P3 serial and MPI-2 | Exactly 13 files; all owner words and every full P3 signature chunk match FRAME. |
| P5.6-A11 | P4-only serial | Exactly 13 files; `initial=4/live=2`, owner words and full P4 signature match FRAME. |
| P5.6-A12 | P4 count-growth contract | A test-only `initial=1/live=2` state is accepted below global capacity and the complete archive matches FRAME; this is not an end-to-end birth transaction. |
| P5.6-A13 | P3+P4 serial | Exactly 15 files; complete owner extensions and both provenance signatures match FRAME. |

Final local results:

- `p56-archive-dev-attempt08`: 10/10 rows PASS;
- `p56-archive-active-dev-attempt04`: 6/6 rows PASS.

The production increment deliberately leaves these contracts unchanged:

- default `FRAME` output;
- BOM pickup/restart files and manifests;
- P4 append-only event shards and manifests;
- MNC behavior.

Remaining HPC acceptance extends, rather than changes, this archive contract:
MPI-4 and target-scale rank counts, OpenMP, a long frame-count/file-system
stress run, target parallel-file-system behavior, and performance/resource
qualification. A true concurrent-start race test and active-signature orphan
injection are also retained as hardening tests; the current gates validate the
atomic mechanism and active high-water contract but do not claim those two
fault-injection scenarios.
