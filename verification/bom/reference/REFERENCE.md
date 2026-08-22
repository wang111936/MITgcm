# MITGCM-BOM reference inputs

This directory contains immutable source and environment locks used to build
MITGCM-BOM analytical and Julia golden tests.

The authoritative rationale, checksums, limitations, and regeneration process
are recorded in:

```text
doc/phys_pkgs/MITGCM-BOM/REFERENCE_LOCK.md
```

Current state: source and Julia dependency versions are pinned, while analytical
inputs and golden trajectories are still pending Phase 0/Phase 2 work.

Do not update `julia_env/Manifest.toml` as part of routine package upgrades.
Any change requires a recorded reference-lock decision and regenerated golden
results.
