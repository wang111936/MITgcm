# P1.3 first production increment test plan

| Gate | Build/layout | Acceptance rule |
|---|---|---|
| source contract | source audit | expected owner budget, independent wind arrays/metadata, standard IEEE finite checks, pre-division integer guard, and verification/production separation are present |
| no-EXF build | serial debug | BOM setup symbols link without EXF and no EXF symbol leaks into the executable |
| EXF builds | serial debug and MPI4 debug | BOM and EXF setup symbols link together with bounds checks and floating-point traps |
| P1-N01b valid preflight | all positive runs | `deltaTClock=1200 s`, target `300 s`, `nSub=4`, and `dtSub=300 s` are published in the setup log |
| NONE snapshot | serial, four local tiles | wind arrays are exactly zero; `t0=t1-deltaTClock` and `myIter-1` metadata publish only after complete validation |
| EXF snapshot | serial and 2 x 2 MPI ranks | constant `2.5/-1.25 m s-1` east/north wind is copied at wet C points, dry points remain zero, scalar halos agree, and EXF inputs remain unchanged |
| time endpoint | serial debug | the unrepresentable/ambiguous lower time endpoint is rejected before `bomFieldsReady` can publish |
| P1-N06 dependency matrix | no-EXF and EXF serial | reject EXF source when not compiled, `useEXF` is false, or `useAtmWind` is false; reject nonzero coefficient with source `NONE` |
| wind source domain | no-EXF serial | reject any source other than `NONE` or `EXF` |
| finite-value preflight | no-EXF serial debug | NaN target step, coefficient, and CFL are rejected by controlled BOM diagnostics under active invalid-operation traps |
| substep integer range | no-EXF serial debug | an excessive ratio is rejected before division overflow or `CEILING` conversion |
| expected owner lifecycle | P1.1 state regression | reset value is zero; a fully validated input publishes the exact global input/owner count in serial, MPI2, and MPI4 |

All case builds use fresh external roots.  The driver also runs Bash syntax
checking, ShellCheck, `nm` symbol audits, normal/abnormal termination checks,
and a compact SHA-256 manifest.  The authoritative P1.3 result must be
followed by the P1.2 mapping, field, and interpolation gates, the P1.1 state
gate, and the Phase-0 final gate before this increment is recorded complete.
