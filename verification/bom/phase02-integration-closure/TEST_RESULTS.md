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

P2-G01 exact-head aggregate: **390/390 PASS**.

- functional head: `d37dccae7d7c219deeafbea5bee65b880a48efd0`;
- evidence root:
  `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-closure/`
  `p25-closure-d37dccae7-attempt01`;
- independent audit: PASS for 20 changed files and 390 rows;
- `row-audit.tsv` SHA-256:
  `d29712970d8de8db828c0611384de38f7680047c001494b3917cce4fc04e677a`;
- `manifest.sha256` SHA-256:
  `4d608484d628d8d8181ad79dfe80c6b45cfabf3de79f7a07add4ad72148e04a7`.

All 23 registered groups passed at their exact expected row counts. The
aggregate contains 257 Phase-1/Phase-0 predecessor rows, 101 accepted
P2.1--P2.4 rows, and 32 P2.5 integration/coexistence rows. This closes P2.5
and the Phase-2 integration boundary for the supported same-decomposition
restart contract. Changed-decomposition restart remains rejected by design.

No tag or merge is authorized by this result file.
