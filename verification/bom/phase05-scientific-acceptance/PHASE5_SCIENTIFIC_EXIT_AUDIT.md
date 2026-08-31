# MITGCM-BOM Phase 5 scientific exit audit

Status: **PASS FOR SCIENTIFIC ACCEPTANCE; HPC NOT EVALUATED**

## 1. Audited candidate

| Item | Accepted value |
|---|---|
| Source head | `f3f50a77a0e01fd4a1687ead312282422999280d` |
| Branch | `MITGCM-BOM/p5.5-scientific-g99` |
| Aggregate gate | P5-SA-G99 754/754 PASS |
| Scientific decisions | P5-D001--P5-D021, 21/21 PASS |
| Aggregate evidence | `p55-g99-f3f50a77a-attempt06` |
| Exit evidence | `p55-exit-f3f50a77a-attempt02` |
| Source state | clean before and after aggregate; clean at exit audit |
| Tag state | unchanged; no tag created |

The independent exit auditor rehashed the aggregate manifest, required all
five child roots and all 754 rows, recomputed the frozen acceptance inventory
and rejected missing, duplicate, extra, non-PASS or non-exact-head evidence.

## 2. Decision results

| Decision | Independently audited result |
|---|---|
| P5-D001 | Required multi-step integrations and specialised one-step F01 transaction probes match their frozen contracts. |
| P5-D002 | Production call chain is `FORWARD_STEP -> BOM_MAIN`; expected call counts pass. |
| P5-D003 | No verification `bom_*.F/F90` production override exists. |
| P5-D004 | All admitted build modifications are SIZE/package/options headers. |
| P5-D005 | P5.1 and P5.4 production builds use one exact source head. |
| P5-D006 | OFFLINE remains a controlled provider and is not compiled into BOM. |
| P5-D007 | Independent input reader passes 302 binary checks, 316 files, 97 endpoints and 98 forcing records. |
| P5-D008 | Julia 1.10.12, SargassumBOMB and physics locks pass for 8,352 component comparisons. |
| P5-D009 | Independent 90-decimal PAPER2024 oracle and all source/fixture locks pass. |
| P5-D010 | Both predeclared mode-discrimination differences exceed ten roundoff bounds. |
| P5-D011 | Complete P5.2/P5.3/O01/L01 time-series inventories pass. |
| P5-D012 | Exact F01/R01/L01 state, event and budget inventories pass. |
| P5-D013 | Thirty protected hashes and every frozen tolerance/step pass. |
| P5-D014 | Same-build restart matrix passes; both changed-decomposition cases reject before publication. |
| P5-D015 | Cross-layout owner and canonical event ordering pass. |
| P5-D016 | Five child manifests, schemas and independent readers pass. |
| P5-D017 | BOM-off ocean pickup, O01 ocean invariance and endpoint replay pass. |
| P5-D018 | Fresh-root refusal and immutable failure-evidence behavior pass. |
| P5-D019 | Required dependency failures are BLOCKED/nonzero; accepted evidence has no SKIP. |
| P5-D020 | The strict source/path allowlist contains no foreign-project dependency. |
| P5-D021 | Scientific builds retain double-precision `_RS` reference storage. |

## 3. Evidence integrity

The aggregate and exit manifests self-validate. Their manifest-file SHA-256
values are, respectively:

- `da8bef9a303495eb7f8f6fcc09f7f94fda5612d6826103662774f532f38ed336`;
- `b34b9fd1ec53575ea257a1453bc70db19f86997f696a364009b2567e249d4e8e`.

The exit decision trace SHA-256 is
`3ecf479b783594fc1795d3dd39320750e3c3755a2eaec1386ff6e83c0779ea28`.
The accepted roots are external to the repository and remain available under
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/`.

## 4. Exit decision

The released regular-grid, one-way, surface BOM package is scientifically
accepted on the frozen admission platforms. This closes P5.0--P5.5 scientific
acceptance only.

OpenMP production safety, target-server scheduler and parallel-filesystem
behavior, changed-decomposition restart, 100,000 particles, up to 256 MPI
ranks, communication/memory scaling and less-than-20-percent ocean-model
overhead are **NOT EVALUATED**. Consequently Phase 5 remains in progress,
v1.0 is not released and no Phase 5 tag is authorized by this audit.
