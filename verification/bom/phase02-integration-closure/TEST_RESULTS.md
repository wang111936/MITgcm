# P2.5 test results

## Development runs

| Gate | Result | Evidence root |
|---|---:|---|
| P2.1 pickup regression | 10/10 PASS | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-pickup/p25-schema2-dev02` |
| Phase-1 output/pickup regression | 25/25 PASS | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/p25-p1-output-dev01` |
| P2-P01--P04, P2-M01 | 20/20 PASS | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-integration/p25-integration-dev04` |
| LEEW coexistence matrix | 25/25 PASS | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/p25-k01-dev01` |
| P2-K01 BOM-mode extension | 12/12 PASS | `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-k01/p25-k01-bom-dev02` |

The direct production behavior is closed in development: schema 1 remains
compatible; schema 2 carries all diagnostics; same-decomposition restart is
bitwise; corruption is fail-closed; serial/MPI2/MPI4 and FLT coexistence pass.

## Exact-head closure

P2-G01 exact-head aggregate: pending the functional commit.

No tag or merge is authorized by this result file.

