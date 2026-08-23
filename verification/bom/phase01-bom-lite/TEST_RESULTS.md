# Phase 1.1 state and initial-file results

Status: **PASS**

| Record | Value |
|---|---|
| Date | 2026-08-23 |
| Branch | `MITGCM-BOM/phase-01-state` |
| Base/PR #7 merge | `acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f` |
| Initial P1.1 feature commit | `c5ee5549a504ed428f152bbc5022368095a1752d` |
| Review-fix commit | `2c688a7e90d1bdd814a8bd8b0ef5db63c7d67a65`; authoritative tests ran immediately before this commit from identical production code, gate, generator, and inputs |
| Physical-length fix commit | `40f5754b3b00ea4bb6a9b20c64c10e968080ad24`; authoritative tests ran immediately before this commit from identical production code, gate, generator, and inputs |
| Working tree during execution | intentionally dirty only with the subsequently committed physical-length fix; all build and run products were outside the repository |

## 1. Locked references and environment

| Item | Value |
|---|---|
| MITgcm upstream reference | `dfc30dafb16561462ef1d4f9518f5d78753ec750` |
| Julia reference | `SargassumBOMB.jl@156557359185e4413ce82829f3ed26a4eb8c6283` |
| Host | Ubuntu 22.04 under WSL2, Linux `6.18.33.2-microsoft-standard-WSL2` x86_64 |
| GNU Fortran | 11.4.0 |
| Open MPI | 4.1.2 |
| Python | 3.10.12 |
| ShellCheck | 0.8.0 |
| optfile | `tools/build_options/linux_amd64_gfortran` |
| verification base | `verification/exp2` |
| package list | `verification/bom/phase00-zero-particle/code/packages.conf` |

## 2. Authoritative P1.1 gate

Command:

```bash
MITGCM_BOM_TEST_ID=p11-physical-size-fix-attempt01 \
  verification/bom/phase01-bom-lite/run_state_gate.sh
```

Evidence roots:

```text
/home/wyl/build/mitgcm-bom/phase01-state/p11-physical-size-fix-attempt01
/home/wyl/runs/mitgcm-bom/phase01-state/p11-physical-size-fix-attempt01
```

Summary SHA-256:

```text
93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7  summary.tsv
```

| Group | Result | Coverage |
|---|---:|---|
| Builds | 8/8 PASS | BOM serial/MPI2/MPI4/debug/OL1-debug plus BOM-uncompiled serial/MPI2/MPI4 |
| Positive runs | 14/14 PASS | state cases, OL1 locator init, compiled-disabled and uncompiled 1/2/4 ranks |
| Negative runs | 20/20 PASS | ID/schema/meta/state/finite/release/physical-file/domain/capacity/Stokes/parameter failures |
| Ocean regressions | 104/104 PASS | 13 applicable runs each preserved all 8 frozen exp2 checkpoint hashes; OL1 is an initialization-only bounds test |

Positive-state assertions include:

- exact owner counts for zero, one, two, and three particles;
- exact restoration of IDs `1`, `4294967301`, and `9007199254740993`;
- exact decimal restoration of every tested `x`, `y`, status, release time, and age field;
- preservation of two ALIVE plus one WAITING state, future release `216000`, and WAITING age zero;
- exactly one owner in serial, MPI2, and MPI4;
- the `(180,0)` internal corner belongs to PID 3, the north-east half-open tile, in MPI4;
- `OLx=OLy=1` initialization completes under GNU bounds checking with momentum and tracer stepping disabled, as required by the MITgcm core overlap guard;
- compiled-disabled and BOM-uncompiled configurations preserve the baseline on 1/2/4 ranks;
- normal MITgcm termination and no fatal marker.

Negative cases are: duplicate ID, bad data schema, fractional ID word, reserved biological status, NaN coordinate, infinite age, negative release time, a 64-byte truncated MDS file, missing MDS meta, bad meta schema, a complete trailing record (192 actual vs 128 expected bytes), one partial trailing byte (129 vs 128), outside domain, per-tile capacity 65 > 64, global input 10001 > 10000, premature Stokes source, unsupported mode, unsupported integrator, non-positive step, and negative output frequency. The three physical-length cases keep meta and header counts mutually consistent where applicable and are rejected before any particle record is accepted. The driver does not trust Fortran `STOP` status 0; it requires expected log text and an abnormal marker while rejecting any normal-end marker.

## 3. Gate source hashes

```text
b29503af643b4344b2027bcb18fc2592aa46cd1fe862bcb8c417865c090eb9f4  run_state_gate.sh
04d0acd9bfd64dbeb1641e3fb3808e8da61930e2b9bb69b7a7752f9c58b88d9c  make_initial.py
86ab79d0e30937f0eb58d8577ca2efd2fb68c9b100406981519bbf5455480f73  code/SIZE.h.ol1
61bfdd0d299c725b167b48095d2fe487706a991e1fa0ad4d3986b965de934901  input/data.bom.valid
46355cb1764d9780f40f9ef266a60faf50cf01c40b856d559c0af1ee3b0d23b8  input/data.bom.one
ad5069b34c7a10defc9d9b883aca6d071068194d3a943674c6e71fb76e88c772  input/data.bom.two
b7638cc0eb9a3236f1ac43652dca593ce4a2a8681f62c11ec01aa46776438971  input/data.bom.capacity
2d9a2f6245eb4a31887c99a4b77dd8b06f7f6b09709620b8543efe72411473b0  input/data.bom.limit
47a3f729e9e5c6c02fa048e8a17d6e4e927d70c3747f14a7c8608ae140d18655  input/data.bom.stokes
8475c4f94d7c91686edc498046ba9cc7acd9b0c69623225558f27c2b6ca2d215  input/data.bom.bad-mode
6f7df996dd6c1705440c552547fa50e8a00a7d434cb9b60d17a2cde985132bd8  input/data.bom.bad-integrator
4b9a7666508d7936dcfab00e73fc376b037622243efa841515cb869fe7d043c9  input/data.bom.bad-step
ff06dbed654ee04bdf5fe22b37960c259f1d6d9832b879a5b3e03c975979db4c  input/data.bom.bad-frequency
```

## 4. Final Phase 0 regression

Command:

```bash
MITGCM_BOM_TEST_ID=p11-physical-size-fix-phase0-attempt01 \
  verification/bom/phase00-final-gate/run_gate.sh
```

Result root:

```text
/home/wyl/runs/mitgcm-bom/phase00-final-gate/p11-physical-size-fix-phase0-attempt01
```

Summary SHA-256:

```text
e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2  summary.tsv
```

Locked references, offline Julia instantiation, BOM-specific Julia smoke, and the P0.4 formal gate all passed. P0.4 supplied 4/4 builds including BOM-uncompiled serial, 3/3 zero-particle positive runs across serial/MPI2/MPI4, 24/24 checkpoint hashes, and 2/2 negative activations.

## 5. Preserved non-authoritative attempts

| Test ID | Outcome | Disposition |
|---|---|---|
| `p11-state-attempt01` | smaller early matrix passed | superseded by expanded attempt05 |
| `p11-state-attempt02` | serial compile failed | fixed-form line exceeded column 72; source corrected |
| `p11-state-attempt03` | production cases passed through truncated input; harness then stopped | truncated file produced a GNU Fortran runtime error instead of MITgcm `ABNORMAL END`; log-aware predicate corrected |
| `p11-state-attempt04` | expanded gate passed | superseded by attempt05 after final source/document synchronization |
| `p11-state-attempt05` | initial P1.1 gate passed | superseded by the review-expanded attempt03 |
| `p11-state-review-fixes-attempt01` | all eight builds passed; first nonzero run stopped in native meta parser | generator dimList spacing was not standard MDS fixed width; corrected |
| `p11-state-review-fixes-attempt02` | all original state cases passed; OL1 run stopped in CONFIG_CHECK | MITgcm requires overlap >=2 with momentum stepping; OL1 became a zero-step locator-only debug run |
| `p11-ol1-preflight-attempt01` | OL1 locator initialization passed under bounds checking | non-authoritative focused validation before the full attempt03 |
| `p11-state-review-fixes-attempt03` | 8/8 builds, 14/14 positive, and 19/19 then-defined negative gates passed | superseded after independent re-review exposed an unannounced physical trailing record |
| `p11-rereview-physical-trailing-attempt01` | 192-byte data with meta/header declaring 128 bytes ended normally and silently ignored the extra record | retained as the reproducer that triggered the physical-length fix |
| `p11-final-rereview-bare-prefix-attempt01` | bare prefix was 128 bytes while the suffixed `.data` was 192 bytes; the run ended normally with exactly one owner | confirms the reader and physical-size check share bare-prefix-first precedence |
| previous Phase 0 attempts | passed | superseded by `p11-physical-size-fix-phase0-attempt01` on the physical-length fix source |

No evidence directory was overwritten or removed.

## 6. Final independent re-review

- Remote snapshot at review time: base `acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f`, head `54eb37bd49970091fffed5091ec96939d73b6d7f`, 6 commits, 31 files, ahead 6/behind 0, mergeable and draft, with no statuses, workflows, reviews, or review threads.
- The review revalidated 8 builds, 34 positive/negative run outcomes, all 13 applicable groups of 8 checkpoint records, the three physical-length failures, and the focused bare-prefix probe.
- Focused probe SHA-256 values: run log `4c3eb78a04534ba55d3b756684f26d157240de5af19080781d4d093268329ff3`, bare input `a6ac5b6dcd5c57f80269276dc59090f461f7bc3ab80a49026ef80c2ee41c29e5`, suffixed `.data` `4f27a263be24f755a08d2ac6afd29c0c0068dcbc809ed7ef4a6e949d57b8e41f`, and meta `0c25dcf630576b4dc38570f0a330a667a0cf22d7958b2dcbc5b44e5fb573a942`.
- No remaining source or test blocker was found. The only findings were stale recovery text and the missing P1-D014 row in the authoritative design-decision table; both are corrected in the documentation-only follow-up.
- The full build matrix was not repeated after this follow-up because production source, gate scripts, generators, and inputs are unchanged from the authoritative runs; Markdown scope and consistency are checked statically.

## 7. Deferred by work-package boundary

- P1-S04a (WAITING initialization) is complete; P1-S04b (release-time substep split) requires P1.3 motion.
- P1-N03a (initial global/tile capacity) is complete; P1-N03b requires P1.4 exchange buffers.
- Periodic normalization, general Cartesian/spherical mapping, C-grid field construction, and interpolation remain P1.2.
- Movement, exchange, trajectories, pickup, and FLT coexistence remain P1.3—P1.5.
