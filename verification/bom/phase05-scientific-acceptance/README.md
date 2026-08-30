# MITGCM-BOM Phase 5 scientific acceptance

Status: **P5.1 THROUGH P5.4 COMPLETE; P5.4 PRODUCTION-QUALIFICATION GATE 8/8 PASS**

This work package proves that the released v0.5 BOM package works through the
normal MITgcm production lifecycle: it is linked into `mitgcmuv`, reads real
runtime files, advances nonzero particles for nonzero model time through
`FORWARD_STEP -> BOM_MAIN`, publishes production output, and agrees with
independent numerical references.

The authoritative frozen definition is
[SCIENTIFIC_ACCEPTANCE_PLAN.md](SCIENTIFIC_ACCEPTANCE_PLAN.md). P5.1 provides
the admitted production-build matrix, deterministic input generator,
independent input/evidence auditors and BOM-off ocean-baseline smoke. P5.2
adds the four-rank 96-step production run, byte-reproduced locked Julia
references, independent trajectory/component/pickup decoders and exact-head
scientific comparison. P5.3 adds the independent 90-decimal PAPER2024 oracle,
a separately locked convergence-resolving affine fixture, four production MPI
runs and the frozen 900/450/225 s RK4 temporal-convergence decision. P5.4
qualifies six released-feature cases, the stock dynamic-ocean gyre,
restart/rank-decomposition consistency and a 30-day endurance run.

Accepted results and evidence roots are recorded in
[P5.1_CLOSEOUT.md](P5.1_CLOSEOUT.md),
[P5.2_CLOSEOUT.md](P5.2_CLOSEOUT.md),
[P5.3_CLOSEOUT.md](P5.3_CLOSEOUT.md), and
[P5.4_CLOSEOUT.md](P5.4_CLOSEOUT.md).

Run any complete gate from a clean exact head with:

```sh
MITGCM_BOM_TEST_ID=<fresh-p51-id> \
  ./verification/bom/phase05-scientific-acceptance/run_p51_gate.sh

MITGCM_BOM_TEST_ID=<fresh-p52-id> \
  ./verification/bom/phase05-scientific-acceptance/run_p52_gate.sh

MITGCM_BOM_TEST_ID=<fresh-p53-id> \
  ./verification/bom/phase05-scientific-acceptance/run_p53_gate.sh

MITGCM_BOM_TEST_ID=<fresh-p54-id> \
  ./verification/bom/phase05-scientific-acceptance/run_p54_gate.sh
```

P5.5/P5-SA-G99 aggregation remains unexecuted at this boundary.

Scientific acceptance precedes the already-planned Phase 5 HPC hardening.
Passing P5-SA-G99 establishes correctness on the admission platforms; it does
not establish OpenMP safety, 100,000-particle/256-rank scale, less than 20%
ocean-model overhead, or changed-decomposition restart.
