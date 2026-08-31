# Expected tutorial result

The JULIA tutorial completed from a fresh GNU debug/IEEE build on Ubuntu 22.04
with the production Fortran parent
`2447777a3412a184de7dcdcd00aef3b7a1a2ed13`.

Accepted structural result:

- normal MITgcm completion;
- 24 schema-2 frames at 900--21,600 s;
- 96 tiled core files and 72 decoded owner records;
- three unique owners in every frame;
- IDs 1001, 1002, and 1003 remain `ALIVE`;
- all decoded binary64 values are finite;
- two scheduled BOM pickup suffixes are present; and
- CSV, JSON, and the full-domain/displacement PNG are generated.

The local run record is `expected_julia_summary.json`. Endpoint numbers are a
regression reference for the same compiler/options; the structural checks are
the portable tutorial acceptance criteria. The locked Phase-5 Julia and
PAPER2024 comparisons remain the scientific authority.

The authoritative local validation products were written to:

```text
/home/wyl/runs/mitgcm-bom/tutorial_MITGCM-BOM-julia-20260831-attempt01
```

Generated binaries and plots are intentionally not committed. Run
`../run_tutorial.sh` to recreate them in a clean work root.
