# P2.5 test plan

## Direct gates

| Gate | Execution | Pass criterion |
|---|---|---|
| P2-P01 | schema-2 serial write/read plus independent decode | fingerprint, endpoint sidecar, particles and all 27 diagnostics validate before one commit |
| P2-P02 | LEEW schema-1 write/read; same files with BOM mode | LEEW accepted unchanged; BOM fails with code 15 before completion |
| P2-P03 | continuous 8 steps vs 5+pickup+3 steps, serial/MPI2/MPI4 | final particle state, 27 diagnostics, endpoint data and output schedule bitwise identical within each decomposition |
| P2-P04 | mode, source, parameter, decomposition, particle diagnostic and endpoint-block mutations | each reports the expected early schema failure, code 15 and no read-completion marker |
| P2-M01 | fixed 3 m/s field and three exact IDs, serial/MPI2/MPI4 | owner crossing occurs; sorted state, diagnostics and endpoint interiors are bitwise identical across layouts |
| P2-K01 | LEEW four-combination matrix; BOM-only and FLT+BOM in BOM mode | no symbols/files leak; BOM, FLT and core results remain independently unchanged |

The integration gate has 20 row-complete assertions. The BOM-mode coexistence
extension has 12 assertions and imports the separately verified 25-row LEEW
matrix by immutable evidence ID.

## P2-G01

On one clean functional head and fresh build/run/evidence roots:

1. run every P2-C/Z/E/N/D/H/I gate from P2.1--P2.4;
2. run both P2.5 direct gates;
3. rerun all Phase-1 gates and the Phase-0/nested P0.4 gates;
4. generate a row-complete aggregate with requirement IDs and source head;
5. audit the functional patch and evidence manifest independently;
6. do not merge, tag or create `MITGCM-BOM-v0.3` in this work package.

All roots must be new. A failed tolerance gate is investigated under the
frozen tolerance-change rule; exact fields are never tolerance-based.

