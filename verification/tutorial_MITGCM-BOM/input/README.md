# Tutorial input

The checked-in namelists are readable templates. `gendata.py` copies the
selected equation template and creates a complete run directory containing
big-endian binary64 fields, the particle MDS file, an input manifest, and
`SHA256SUMS`.

```bash
python3 gendata.py /tmp/MITGCM-BOM-input --equation JULIA
```

The output directory must not already exist. No generated binary belongs in
the source tree.
