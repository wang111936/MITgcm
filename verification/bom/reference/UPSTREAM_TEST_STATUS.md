# Upstream Julia reference test status

Date: 2026-08-23

## Locked environment

- SargassumBOMB commit: `156557359185e4413ce82829f3ed26a4eb8c6283`
- SargassumRegistry commit: `02961aced4cfa2b3430ebd4b44cdb7a3056e7175`
- Julia: `1.10.12`
- Manifest SHA-256: `86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695`

## Results

Dependency instantiation succeeded. Loading the package with
`using SargassumBOMB` also succeeded.

During load, construction of the default environmental interpolants emitted a
warning and continued without usable interpolants. The reference package catches
the underlying data error, so a successful import does not prove that external
environmental data are available.

The upstream test suite contains one test call and produced:

```text
Test Summary:    | Error  Total
SargassumBOMB.jl |     1      1
0 passed, 0 failed, 1 errored
UndefVarError: generate_rp_example not defined
```

The failing call is:

```julia
SargassumBOMB.Examples.generate_rp_example()
```

The locked commit's `Examples` module does not define that function. This is an
upstream test/interface mismatch, not a package-resolution failure.

## MITGCM-BOM decision

Do not patch the locked reference checkout merely to make its old test pass.
Build independent analytical-field, RHS-component, single-step, and trajectory
golden tests under `verification/bom/reference` instead. External environmental
data must be explicit inputs with checksums; missing inputs must be fatal in the
MITGCM-BOM validation path.
