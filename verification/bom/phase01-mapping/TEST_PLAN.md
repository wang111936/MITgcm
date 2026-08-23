# P1.2 mapping and locator-wrapper test plan

| Gate | Executable evidence | Acceptance rule |
|---|---|---|
| P1-M01 | four-tile, overlap-two Cartesian debug build | analytic indices and native-coordinate round trips meet scaled `_RL` tolerance; shared corner has exactly one north-east owner; `-0.25` has a stencil and `-1.25` correctly does not |
| P1-M02 global | 8-by-6 global spherical-polar grid | `xLo-360`, `xHi`, and interior `x±360` normalize to the canonical half-open domain and retain one owner |
| P1-M02 regional | 80-degree regional spherical-polar grid | longitude is unchanged and outside after `+360`; `xHi` remains outside; interior round trip succeeds |
| P1-N04 grid modes | test-only post-grid invalid-state injection | each unsupported state reaches the production guard, reports its exact reason, marks mapping state unavailable, and ends abnormally |
| P1-N04 OpenMP | actual `genmake2 -omp` binary with two threads | production initialization rejects the configuration before a mapping is published |
| P1-N04 EXCH2 | actual EXCH2 package build and single-facet topology | production initialization reports EXCH2 unsupported and does not publish mapping state |
| P1-S03 locator compatibility | production source audit plus complete P1.1 runtime gate | the public locator calls `BOM_MAP_XY2IJLOCAL`, retains `NINT(ix/jy)` center-mask acceptance, performs no direct `xG/yG` search, and preserves unique owner/wet/domain/OL1 behavior |

All builds use GNU bounds checking, floating-point traps, fresh external build
and run directories, symbol audits, Bash syntax checking, and ShellCheck.

This increment replaces only the internals of `BOM_LOCATE_INITIAL` with a
compatibility call.  It does not construct ocean velocity fields, interpolate
environmental fields, or move particles.
