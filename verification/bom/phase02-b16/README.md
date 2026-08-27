# MITGCM-BOM P2.4 B16 Julia-reference verification

Status: **P2.4 CLOSED; PHASE 2 CLOSED BY P2.5**

This isolated serial comparator verifies the production `JULIA` equation
path against the locked Phase-2 B16 fixture. It uses three particles in a
fully wet Cartesian domain, distinct affine base-current, Stokes and wind
fields, a 900 s fixed step, and an 86400 s trajectory.

## Locked authority

- Julia: `1.10.12`;
- SargassumBOMB source commit:
  `156557359185e4413ce82829f3ed26a4eb8c6283`;
- `physics.jl` SHA-256:
  `1acef9ed3c8d13646c95799565387a4add76e839827cea1c0e745ced73f1885d`;
- rebuilt Project/Manifest SHA-256:
  `12cfb1288a21b19216662a719d430bf41b5587dfd8b00e973f8b3c9c25f1f99d`
  and
  `86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695`.

The comparator reads only checksummed files in `reference/phase02`. P2-I05
checks all 27 RHS diagnostics plus native coordinate rates with
`abs <= 2e-12 + 5e-12*abs(reference)`. P2-I06 checks every fixed RK2/RK4
saved position and accumulated path with
`abs <= max(1e-6 m, 5e-11*reference_path)`.

The adaptive `Tsit5` file is deliberately separate and every row states
`gating=false`. It records behavior of the actual locked
`OrdinaryDiffEqTsit5` solver at `abstol=reltol=1e-12`; it is provenance and
scientific context, not an oracle for MITgcm's fixed-step RK2/RK4 methods.

## Fail-closed and reproducibility gates

P2-N07 mutates, one at a time, the locked physics source, Project, Manifest,
input field, golden RHS, source commit, and Julia version. Every mutation
must be rejected before generation or comparison. The fixed RHS/RK2/RK4
files are regenerated and compared byte for byte before compiling MITgcm.
The recurring gate validates the Tsit5 file's independent context checksum
but does not compare its numerical values to MITgcm.

```bash
verification/bom/phase02-b16/run_b16_gate.sh
```

The summary contains 12 required PASS rows: seven P2-N07 rejections, the
source/environment/regeneration lock, one production build, P2-I05 RHS, and
P2-I06 RK2/RK4 trajectories.

Exact functional-head results, artifact hashes, and the non-gating Tsit5
record are documented in `TEST_RESULTS.md`.
