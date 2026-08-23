# Phase 1.1 state and initial-file results

Status: **PASS**

| Record | Value |
|---|---|
| Date | 2026-08-23 |
| Branch | `MITGCM-BOM/phase-01-state` |
| Base/PR #7 merge | `acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f` |
| P1.1 feature commit | `c5ee5549a504ed428f152bbc5022368095a1752d`; tests ran immediately before this commit from identical production code, gate, generator, and inputs |
| Working tree during execution | intentionally dirty with the uncommitted P1.1 work package; build and run products were outside the repository |

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
MITGCM_BOM_TEST_ID=p11-state-attempt05 \
  verification/bom/phase01-bom-lite/run_state_gate.sh
```

Evidence roots:

```text
/home/wyl/build/mitgcm-bom/phase01-state/p11-state-attempt05
/home/wyl/runs/mitgcm-bom/phase01-state/p11-state-attempt05
```

Summary SHA-256:

```text
aaed7084bcc1b8df7def4c4020f6b7afc0e9158bcc75d994e60b3bd605a79c19  summary.tsv
```

| Group | Result | Coverage |
|---|---:|---|
| Builds | 4/4 PASS | serial, MPI2, MPI4, GNU debug; link contains all four P1.1 routines |
| Positive runs | 7/7 PASS | zero, one, two, three particles; serial, MPI2, MPI4, debug |
| Negative runs | 16/16 PASS | ID/schema/state/finite/release/file/domain/capacity/Stokes/parameter failures |
| Ocean regression per positive run | 8/8 PASS | every frozen exp2 checkpoint hash unchanged |

Positive-state assertions include:

- exact owner counts for zero, one, two, and three particles;
- exact restoration of IDs `1`, `4294967301`, and `9007199254740993`;
- preservation of two ALIVE plus one WAITING state and the future release time;
- exactly one owner in serial, MPI2, and MPI4;
- the `(180,0)` internal corner belongs to PID 3, the north-east half-open tile, in MPI4;
- normal MITgcm termination and no fatal marker.

Negative cases are: duplicate ID, bad schema, fractional ID word, reserved biological status, NaN coordinate, infinite age, negative release time, truncated MDS file, outside domain, per-tile capacity 65 > 64, global input 10001 > 10000, premature Stokes source, unsupported mode, unsupported integrator, non-positive step, and negative output frequency. The driver does not trust Fortran `STOP` status 0; it requires expected log text and either a MITgcm abnormal marker or a Fortran runtime-error marker while rejecting any normal-end marker.

## 3. Gate source hashes

```text
82b98ffa4e73a37a4c0aaa5afe5ea4c031ed67cd37d0240b529f93b1f325a979  run_state_gate.sh
b656bce24233a82d611401c370bef9c68e89b5bfbbabf6b8af08a761df7e4040  make_initial.py
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
MITGCM_BOM_TEST_ID=p11-phase0-regression-attempt03 \
  verification/bom/phase00-final-gate/run_gate.sh
```

Result root:

```text
/home/wyl/runs/mitgcm-bom/phase00-final-gate/p11-phase0-regression-attempt03
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
| `p11-phase0-regression-attempt01`—`attempt02` | Phase 0 gates passed | superseded because source or records were subsequently finalized |

No evidence directory was overwritten or removed.

## 6. Deferred by work-package boundary

- P1-S04a (WAITING initialization) is complete; P1-S04b (release-time substep split) requires P1.3 motion.
- P1-N03a (initial global/tile capacity) is complete; P1-N03b requires P1.4 exchange buffers.
- Periodic normalization, general Cartesian/spherical mapping, C-grid field construction, and interpolation remain P1.2.
- Movement, exchange, trajectories, pickup, and FLT coexistence remain P1.3—P1.5.
