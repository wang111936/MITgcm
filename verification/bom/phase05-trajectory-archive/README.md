# BOM continuous trajectory archive gate

This gate verifies the MDS trajectory archive added to prevent one BOM file
family per output time. It does not enable MNC and it does not change BOM
pickup or P4 event formats.

Run both gates from the repository root with unique test IDs:

```bash
MITGCM_BOM_REQUIRE_CLEAN=no \
MITGCM_BOM_TEST_ID=p56-archive-dev-attemptXX \
bash verification/bom/phase05-trajectory-archive/run_archive_gate.sh

MITGCM_BOM_REQUIRE_CLEAN=no \
MITGCM_BOM_TEST_ID=p56-archive-active-dev-attemptXX \
bash verification/bom/phase05-trajectory-archive/run_active_archive_gate.sh
```

Production input selects the archive explicitly in `BOM_PARM01`:

```fortran
 bomTrajectoryMode='ARCHIVE',
 bomTrajectoryFile='bom_trajectories',
```

`FRAME` remains the default and preserves the existing per-time output byte
contract. `ARCHIVE` creates one segment per model startup. The segment name
contains `nIter0`, so a restart creates a new segment and cannot overwrite the
previous run.

For a four-tile run with neither P3 nor P4, one segment has exactly 11 members,
independent of the number of output frames:

```text
bom_trajectories.s0000000000.claim
bom_trajectories.s0000000000.index.data
bom_trajectories.s0000000000.index.meta
bom_trajectories.s0000000000.001.001.data/meta
bom_trajectories.s0000000000.002.001.data/meta
bom_trajectories.s0000000000.001.002.data/meta
bom_trajectories.s0000000000.002.002.data/meta
```

P3-only or P4-only adds one fixed signature `.data/.meta` pair for a total of
13; P3+P4 adds both fixed pairs for a total of 15. The persistent `.claim` is
created with `STATUS='NEW'` before any MDS member and reserves the segment name.
It is not the frame publication ledger.

The data width is 64 big-endian float64 words. Each tile repeats:

```text
frame header, zero or more owner records, frame commit
```

Owner words 1:48 are the normalized existing core, words 49:56 are the existing
P3 owner sidecar, words 57:60 are the existing P4 owner sidecar, and words
61:64 are frozen zero reserves. Full P3/P4 per-frame provenance is appended to
the fixed segment signature streams. A global index descriptor is record 1;
record `frame+1` is the ordered commit for that frame.

Index `.meta` is authoritative. Readers consume only its committed frames and
ignore index data beyond index meta, tile data/meta beyond committed blocks,
and active signature data/meta beyond the cumulative high-water in index
commit fields 34/36.

The base gate builds serial and MPI-2 debug/IEEE production executables and
checks one/three-frame append, all 64 words against normalized `FRAME`, atomic
claim creation, sequential collision rejection with unchanged hashes,
injected index/tile orphan-tail handling, split-restart immutable segments, and
MPI-2 publication. The active gate covers P3 serial/MPI-2, P4-only
`initial=4/live=2`, a test-only count-growth state with `initial=1/live=2`,
and P3+P4; it compares all owner words and complete legacy signature bytes.
The count-growth state exercises the archive/decoder bound but is not an
end-to-end birth transaction. The final local evidence IDs are
`p56-archive-dev-attempt08` and `p56-archive-active-dev-attempt04`.
