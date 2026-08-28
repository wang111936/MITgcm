# P3.5 performance and closure test results

Decision: **LOCAL CANDIDATE PASS; P3.5 IMPLEMENTATION COMPLETE; INTEGRATED
PHASE 3 EXIT PENDING**

Functional and candidate-evidence head:
`fc64c6e8c5671db2f1e123142b9b073da50d1e31`

Branch: `MITGCM-BOM/p3.5-performance-closeout`

Environment: Ubuntu 22.04 under WSL2, GNU Fortran 11.4.0 debug/IEEE/bounds
builds and Open MPI 4.1.2. Timing is informational on shared WSL hardware;
counter and graph bounds are gating.

## Accepted evidence

| Gate | Result | Source head | Evidence root |
|---|---:|---|---|
| P3.5 direct performance/complexity | 20/20 PASS | `fc64c6e8c` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p35-performance-closeout/p3-g99-candidate-fc64c6e8c-attempt01-p35-performance` |
| P3-G99 candidate aggregate | 538/538 PASS | `fc64c6e8c` | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p3-g99/p3-g99-candidate-fc64c6e8c-attempt01` |

The aggregate row audit is:

| Group | Expected | Actual | Result |
|---|---:|---:|---:|
| P3.5 performance | 20 | 20 | PASS |
| P3.4 components | 42 | 42 | PASS |
| P3.3 ensemble | 34 | 34 | PASS |
| P3.2 cutoff | 18 | 18 | PASS |
| P3.1 reference | 34 | 34 | PASS |
| Phase 2 | 390 | 390 | PASS |
| Total | 538 | 538 | PASS |

Evidence hashes:

- P3.5 native manifest: `83f0518a871bd65cecf141c52c787cc0df82dbbf052325418e3142e71ecf38bf`;
- P3-G99 manifest: `b15067cef6c168f5ccf2cee1eaebabf587579c079f9b24d461ce763ab7291689`;
- P3-G99 row audit: `14bb14aadf48382e169a325d0bd435f1a7f02f36eec0c8e9a3a36ca5ed8f98f2`;
- P3-G99 all 538 rows: `880168235bc942e359f209a400aa562eb02e482d7d9f3f36b3c1f12d4ea29553`.

Both native and aggregate manifests self-validated. The independent marker is
`P3-G99 CANDIDATE AUDIT PASS`, with 538 rows and 120 Phase 3 changed files.
The captured Git status is empty.

## Isolated final-mode rehearsal

After the candidate closeout was committed, a shared clone under
`/tmp/mitgcm-bom-p35-integration-rehearsal-20260829-a` reproduced the frozen
merge order without modifying the authoritative repository:

1. P3.4 package head `38fd1824f` was merged with merge commit `1beaf10945`;
2. P3.5 package head `b904c91d7` was merged with merge commit `5c9e70a779`;
3. final-mode P3-G99 passed 538/538 at `5c9e70a779`;
4. the separate Phase 3 exit audit passed and identified the same two merges.

Rehearsal evidence roots are:

- `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p3-g99/`
  `p3-g99-final-rehearsal-5c9e70a779-attempt01`;
- `/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/phase3-exit-audit/`
  `phase3-exit-rehearsal-5c9e70a779-attempt01`.

The final-rehearsal P3-G99 manifest SHA-256 is
`1d28cf6301b04a295fddd8858e0161bbe1bbecc0096b1e64c83eeb250287eb8c`.
The exit-audit manifest and independent-log SHA-256 values are
`6e4f8c00dfcfc2020bbbf504944c73aab01e52fe7d17875580e08de885876758`
and `868a440e0e7f570cc3d9d0b510a7ea4c80bbf563f407e1616b6843f9bf212d58`.

This rehearsal proves the final-mode driver and exit-audit topology, but it is
not authoritative integration evidence. The real development branch remained
at `be87475712f0084c5acc1a342ebc97172ccdaf82`; no remote ref or tag changed.

## Fixed-density observations

All six Cartesian/spherical fixtures pass in serial, MPI2 and MPI4. Candidate
comparisons per owner remain bounded and decrease with N:

| Layout | Observed range |
|---|---:|
| serial | 9.1885--9.7657 |
| MPI2 | 9.0938--9.3750 |
| MPI4 | 9.0000 |

MPI ghost records per boundary owner stay between 0.0715 and 0.1518. The
largest fixture has 4096 owners; comparisons are 37636 (serial), 37248
(MPI2), and 36864 (MPI4), all below the frozen 16-per-owner bound. The dense
five-neighbor fixture fails closed in every layout at the verification-only
capacity of four. Serial/MPI2/MPI4 timing and load-imbalance columns are
retained in the evidence but do not decide PASS.

## Findings closed

1. The first production scaling run exposed repeated tile-routed ghost copies
   entering a rank-wide cell list and raising the 16x16 comparison rate to 36
   per owner. Exact-ID validation/deduplication and remote-ghost compaction in
   `BOM_SPRING_STAGE` reduce the observed rate to 9.0--9.8 without changing
   pair geometry or graph semantics.
2. The first P3-G99 rehearsal stopped because the frozen P1.4 source audit
   matched a forbidden datatype name in a comment. The comment was rewritten;
   production had never used that datatype.
3. The next focused P1.4 build showed that its two verification-only
   `BOM_SIZE.h` overrides lacked the new counter constants. Both fixtures were
   extended without changing their reduced capacities. P1.4 then passed
   36/36 and the complete Phase 2 closure passed 390/390 in P3-G99.

No finding changed a scientific formula, cutoff, tolerance, schema, exact-ID
representation or restart transaction.

## Reproduction

```bash
MITGCM_BOM_EXPECTED_HEAD=fc64c6e8c5671db2f1e123142b9b073da50d1e31 \
MITGCM_BOM_INTEGRATION_MODE=candidate \
MITGCM_BOM_TEST_ID=p3-g99-candidate-fc64c6e8c-attempt01 \
  verification/bom/phase03-integration-closure/run_p3_g99.sh
```

This is candidate evidence on a branch stacked above the unmerged P3.4 head.
It does not authorize a push, PR merge, Phase 3 exit audit or creation of the
`MITGCM-BOM-v0.4` tag. Final P3-G99 must be rerun on the ordered merged
development head.
