# P1.2 wet-pair interpolation test plan

| Gate | Decomposition | Acceptance rule |
|---|---|---|
| source contract | source audit | production routine uses readiness, mathematical floor, complete overlap bounds, `maskC`, one wet weight, and no FLT call; verification markers remain outside `pkg/bom` |
| P1-F03 FULL | serial four tiles and MPI4 | a constant pair remains constant at negative fractional overlap indices; fully wet affine east/north fields match analytic bilinear values |
| P1-F03 PARTIAL | serial four tiles and MPI4 | an exactly accepted 0.5 wet weight excludes large dry values and produces the analytic pair from the same normalized weights |
| P1-N05 | serial four tiles and MPI4 | unready, incomplete, non-finite, insufficient-wet, and invalid-tile calls return `isValid=.FALSE.` and zero pair values without out-of-bounds access |

Both builds use GNU bounds checking, floating-point traps, debug
initialization, Bash syntax checking, ShellCheck, symbol audits, and
normal/abnormal log markers.  Tests call the production interpolation routine
directly because P1.3, which will consume the result in a particle RHS, has
not started.

This increment does not move particles, modify owner state, add wind or
Stokes fields, start P1.3, or authorize a v0.2 tag.
