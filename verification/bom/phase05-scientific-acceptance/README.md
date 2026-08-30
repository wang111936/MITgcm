# MITGCM-BOM Phase 5 scientific acceptance

Status: **P5.1 COMPLETE; P5-B01/P5-I01 GATE 18/18 PASS**

This work package proves that the released v0.5 BOM package works through the
normal MITgcm production lifecycle: it is linked into `mitgcmuv`, reads real
runtime files, advances nonzero particles for nonzero model time through
`FORWARD_STEP -> BOM_MAIN`, publishes production output, and agrees with
independent numerical references.

The authoritative frozen definition is
[SCIENTIFIC_ACCEPTANCE_PLAN.md](SCIENTIFIC_ACCEPTANCE_PLAN.md). P5.1 now
provides the admitted production-build matrix, deterministic input generator,
independent input/evidence auditors and BOM-off ocean-baseline smoke. The
accepted exact-head result and evidence roots are recorded in
[P5.1_CLOSEOUT.md](P5.1_CLOSEOUT.md).

Run the complete P5.1 gate from a clean exact head with:

```sh
MITGCM_BOM_TEST_ID=<fresh-id> \
  ./verification/bom/phase05-scientific-acceptance/run_p51_gate.sh
```

P5.2 and all later scientific-acceptance cases remain unexecuted at this
boundary.

Scientific acceptance precedes the already-planned Phase 5 HPC hardening.
Passing P5-SA-G99 establishes correctness on the admission platforms; it does
not establish OpenMP safety, 100,000-particle/256-rank scale, less than 20%
ocean-model overhead, or changed-decomposition restart.
