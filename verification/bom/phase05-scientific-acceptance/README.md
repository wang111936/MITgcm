# MITGCM-BOM Phase 5 scientific acceptance

Status: **P5.0 PLAN FROZEN; NO PHASE 5 BUILD OR RUN EVIDENCE**

This work package proves that the released v0.5 BOM package works through the
normal MITgcm production lifecycle: it is linked into `mitgcmuv`, reads real
runtime files, advances nonzero particles for nonzero model time through
`FORWARD_STEP -> BOM_MAIN`, publishes production output, and agrees with
independent numerical references.

The authoritative frozen definition is
[SCIENTIFIC_ACCEPTANCE_PLAN.md](SCIENTIFIC_ACCEPTANCE_PLAN.md). P5.0 changes
documentation only. It does not compile MITgcm, generate fixtures, run Julia,
run a model, or claim a Phase 5 test result.

Scientific acceptance precedes the already-planned Phase 5 HPC hardening.
Passing P5-SA-G99 establishes correctness on the admission platforms; it does
not establish OpenMP safety, 100,000-particle/256-rank scale, less than 20%
ocean-model overhead, or changed-decomposition restart.
