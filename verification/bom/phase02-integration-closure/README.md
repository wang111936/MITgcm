# Phase 2.5 integration closure

Status: **P2.5 CLOSED; PHASE 2 INTEGRATION COMPLETE**

P2.5 completes the Phase-2 production integration left after P2.4: live
schema-2 diagnostics, transactional restart, serial/MPI reproducibility,
same-decomposition restart and FLT isolation. It does not add changed-
decomposition restart; that remains an explicit rejection.

Production changes are limited to the BOM output/pickup format owners and
schema constants. `LEEW` schema 1 is unchanged. The precise schema-2 layout is
in `SCHEMA2.md`.

The focused integration gate is:

```bash
verification/bom/phase02-integration-closure/run_integration_gate.sh
```

It builds serial, MPI2 and MPI4 and executes P2-P01--P04 and P2-M01. The
coexistence gate is:

```bash
verification/bom/phase02-integration-closure/run_coexistence_bom_gate.sh
```

It first establishes or reuses the 25-row LEEW neither/FLT/BOM/both matrix,
then runs BOM schema 2 with BOM-only and FLT+BOM in serial and MPI2. The BOM,
FLT and core outputs are independently compared.

`verify_schema2.py` is an independent binary decoder. It validates exact ID
words, mode/source codes, record widths, diagnostic identities, signature,
schedule and endpoint interiors, and writes decomposition-aware canonical
files. `mutate_schema2.py` supplies one corruption at a time. `make_velocity.py`
creates the fixed 3 m/s field that makes an active particle cross an owner-tile
boundary during the 480 s test.

Development evidence before the exact-head closure run:

- P2.1 pickup regression: 10/10
- Phase-1 output/pickup regression: 25/25
- P2.5 P/M integration gate: 20/20
- LEEW coexistence matrix: 25/25
- BOM-mode coexistence extension: 12/12

The authoritative P2-G01 exact-head evidence is 390/390 PASS at functional
commit `d37dccae7d7c219deeafbea5bee65b880a48efd0`. Its aggregate manifest,
independent audit and SHA-256 identifiers are recorded in `TEST_RESULTS.md`.
