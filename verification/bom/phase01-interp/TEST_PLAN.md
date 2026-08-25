# P1.2 wet-pair interpolation test plan

| Gate | Decomposition | Acceptance rule |
|---|---|---|
| source contract | source audit | production routine uses readiness, mathematical floor, complete overlap bounds, `maskC`, one wet weight, and no FLT call; P1.3 `BOM_CHECK_STATE` consumes mapping plus the wet pair; verification markers remain outside `pkg/bom` |
| P1-F03 FULL | serial four tiles and MPI4 | a constant pair remains constant at negative fractional overlap indices; fully wet affine east/north fields match analytic bilinear values |
| P1-F03 PARTIAL | serial four tiles and MPI4 | an exactly accepted 0.5 wet weight excludes large dry values and produces the analytic pair from the same normalized weights |
| P1-N05 | serial four tiles and MPI4 | unready, incomplete, non-finite, insufficient-wet, and invalid-tile calls return `isValid=.FALSE.` and zero pair values without out-of-bounds access |

Both builds use GNU bounds checking, floating-point traps, debug
initialization, Bash syntax checking, ShellCheck, symbol audits, and normal
log markers. The six numerical cases call the production interpolation
routine directly. Production consumption is structurally audited here and is
exercised end-to-end by the P1.3 lifecycle gate.

The former diagnostic-only `BOM_MAIN` cases belong to immutable P1.2 evidence
and are no longer current regressions after the P1.3 caller began moving and
transactionally committing particles. This component gate does not claim
P1.3 lifecycle acceptance or authorize a tag.
