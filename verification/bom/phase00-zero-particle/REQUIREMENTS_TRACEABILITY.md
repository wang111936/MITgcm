# Phase-0 requirements traceability

| Requirement | Implementation | Verification | Status |
|---|---|---|---|
| P0-R01 Lock MITgcm and Julia references | `REFERENCE_LOCK.md`, `reference/` | Julia instantiate/load record and checksums | complete |
| P0-R02 Compile an empty BOM package | `pkg/bom`, `pkg/pkg_depend` | `phase00-skeleton/TEST_RESULTS.md` | complete |
| P0-R03 Default BOM to disabled | `useBOM=.FALSE.` in `PACKAGES_BOOT` | P0.3 compiled-disabled serial/MPI runs | complete |
| P0-R04 Enable zero-particle lifecycle | package read/check/init/main hooks | P0.4 serial, MPI-2, MPI-4 positive cases | complete: `p04-attempt01` |
| P0-R05 Preserve the ocean baseline | empty guarded `BOM_MAIN` | eight checkpoint SHA-256 checks per decomposition | complete: 24/24 checks |
| P0-R06 Reject uncompiled activation | `PACKAGES_CHECK` | `uncompiled-activation` negative gate | complete: expected rejection |
| P0-R07 Reject nonzero Phase-0 state | `BOM_CHECK` | `nonzero-particles` negative gate | complete: expected rejection |
| P0-R08 Detect false-success `STOP` | log-aware `run_gate.sh` assertions | both negative gates | complete: status 0 did not cause false pass |
| P0-R09 Exclude later physics | Phase-0 scope guards and empty state | source diff/scope audit | complete |

Execution evidence is recorded in `TEST_RESULTS.md` and under the external run
root `/home/wyl/runs/mitgcm-bom/phase00-zero-particle/p04-attempt01`.
