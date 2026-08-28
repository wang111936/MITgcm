# MITGCM-BOM P3.1 executable test results

Date: 2026-08-28

Decision: **PASS -- the P3.1 functional head satisfies its direct gate and the
complete Phase 2 predecessor regression.**

This result closes only the P3.1 implementation package. It does not authorize
P3.2 work, merge the branch, or create `MITGCM-BOM-v0.4`.

## Authoritative subject

- branch: `MITGCM-BOM/p3.1-reference-laws`;
- baseline/P3.0 integration merge: `96b38052c5444c995bc9e88078066a6ba9899ead`;
- functional head: `3c1bc5821ea6a7515dafe5b4142140c16a6cec98`;
- author/committer: `WangYuLin <wang111936@outlook.com>`;
- exact-head worktree: clean before, during and after both gates;
- environment: Ubuntu 22.04 WSL2, GNU Fortran 11.4.0, Open MPI 4.1.2,
  Python 3.10.12 and Julia 1.10.12.

## Direct P3.1 gate

Command:

```bash
MITGCM_BOM_EXPECTED_HEAD=3c1bc5821ea6a7515dafe5b4142140c16a6cec98 \
MITGCM_BOM_REQUIRE_CLEAN=yes \
MITGCM_BOM_TEST_ID=p31-reference-3c1bc582-attempt01 \
  verification/bom/phase03-reference-laws/run_reference_law_gate.sh
```

Result: **34/34 PASS**.

The rows cover scope/NONE-dispatch isolation, serial and MPI4 debug/IEEE
builds, KNN/locked Julia references, configuration and stable codes, canonical
Cartesian/spherical/periodic geometry, Hooke/eBOMB direct kernels, transactional
negative paths, accepted namelists, 14 fail-before-state configurations and
bitwise-equal serial/MPI4 sorted records.

External evidence root:

`/home/wyl/projects/mitgcm-bom-test-artifacts/phase03/p31-reference-laws/p31-reference-3c1bc582-attempt01`

| Evidence | SHA-256 |
|---|---|
| `summary.tsv` | `17d2f0a1aa3292a424aee6b321c7c358b407b88947dabcfa1b5fb39958a8238a` |
| `metadata.tsv` | `f24dba6ddd00e1e3d5789f87af27f2c28db435d5aa72f58cfb3e7756ecedf83b` |
| `manifest.sha256` | `3e94c58b6ddb0f2ff86117f8d55e1702e766548963f6f78112b1a590f771807d` |
| `manifest-check.log` | `a6e4c9f00b3855927ca54628d8146bcf3ed86edbe16c9b813a354cd25c19b424` |

Every row in `manifest-check.log` is `OK`; captured `git-status.txt` is empty.

## Complete predecessor regression

Command:

```bash
MITGCM_BOM_EXPECTED_HEAD=3c1bc5821ea6a7515dafe5b4142140c16a6cec98 \
MITGCM_BOM_TEST_ID=p31-phase2-3c1bc582-attempt01 \
  verification/bom/phase03-reference-laws/run_phase2_regression_gate.sh
```

Result: **390/390 PASS**.

| Group | Rows | Result |
|---|---:|---|
| p05-final | 4 | PASS |
| p04-zero | 9 | PASS |
| p11-state | 42 | PASS |
| p12-mapping | 19 | PASS |
| p12-fields | 7 | PASS |
| p12-interp | 9 | PASS |
| p13-setup | 17 | PASS |
| p13-rhs | 15 | PASS |
| p13-rk2 | 12 | PASS |
| p13-rk4 | 12 | PASS |
| p13-lifecycle | 13 | PASS |
| p14-owner | 36 | PASS |
| p15-output | 25 | PASS |
| p15-migration | 12 | PASS |
| p15-coexistence | 25 | PASS |
| p21-endpoint | 34 | PASS |
| p21-pickup | 10 | PASS |
| p22-derivative | 16 | PASS |
| p23-rhs | 18 | PASS |
| p24-stage-rk | 11 | PASS |
| p24-b16 | 12 | PASS |
| p25-integration | 20 | PASS |
| p25-k01 | 12 | PASS |
| **TOTAL** | **390** | **PASS** |

External evidence root:

`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-closure/p31-phase2-3c1bc582-attempt01`

| Evidence | SHA-256 |
|---|---|
| `row-audit.tsv` | `d29712970d8de8db828c0611384de38f7680047c001494b3917cce4fc04e677a` |
| `independent-audit.log` | `34c365561bd3b62b3f8e20f66b5a80cad953bdff1c34f17ddb04d86fa730f642` |
| `source-head.txt` | `412fb93e39ff0a0c5c204358a8fbad05d81281bd28e4fd09e94107e4c1685ca7` |
| `manifest.sha256` | `9926b5d5423280d83b9ef0206f9b3064740cf5a70ba6da4074962aac920eee71` |
| `manifest-check.log` | `2f1976adbd016d6865ae2ae11f20dc85d392eaef81867dbfa58d9a4f77fb2c72` |

The independent audit reports `scope=P3.1`, 26 changed files and 390 rows. It
accepts only the six frozen P3.1 production files, the two P3.1 verification
trees, and its own backward-compatible audit extension. Historical P2.5 mode
remains the default when the Phase 2 closure is invoked directly.

## Evidence interpretation

Development attempts are retained outside the repository but are not cited as
authoritative. The two results above use the same final clean functional head.
A later evidence-only Markdown commit may record these immutable results; it
does not change the tested production tree or require a numerical rerun.
