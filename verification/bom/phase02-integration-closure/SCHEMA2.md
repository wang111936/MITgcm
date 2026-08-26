# BOM trajectory and pickup schema 2

This document freezes the P2.5 on-disk extension used when `bomMode='BOM'`.
`LEEW` continues to write and read the unchanged Phase-1 schema-1 records.
Every number is big-endian IEEE float64 through the existing tiled MDS API.
The unsigned high and low words of a particle ID remain separate exact fields.

## Trajectory records

Schema 2 has 48 fields. The maximum is deliberately 48 so the format also
works with the smallest supported verification tiles and their MDS 3-D buffer.

The tile header retains schema-1 fields 1--18. Fields 19--24 contain the mode,
equation, current, wind, Stokes and integrator codes. Field 25 is `27`, field
26 is the first diagnostic field (`22`), and field 27 is the last diagnostic
field (`48`). Fields 28--48 are zero.

Particle fields 1--21 retain their schema-1 meaning and order:

1. ID high word
2. ID low word
3. status
4. sample time (s)
5. iteration
6. x
7. y
8. release time (s)
9. age (s)
10. local fractional i
11. local fractional j
12. base-current east velocity (m/s)
13. base-current north velocity (m/s)
14. wind east velocity (m/s)
15. wind north velocity (m/s)
16. final drift east velocity (m/s)
17. final drift north velocity (m/s)
18. rank
19. local tile i
20. local tile j
21. active-record marker

Schema-1 fields 22--24 were reserved zeros. Schema 2 version-controls and
reuses those positions, then continues through field 48, for the complete
27-component accepted diagnostic vector described below. Equation and current
policy are frame-wide and are carried by header fields 20 and 21.

## Pickup particle records

Schema 2 has 45 fields. Header fields 1--23 retain their schema-1 meaning;
field 24 is the diagnostic count `27`, and fields 25--45 are zero.

Particle fields 1--18 retain all Phase-1 semantic fields: exact ID words,
status, x/y, release time, age, local i/j, base current, wind, drift and owner
rank/tile. Schema-1 fields 19--24 were reserved zeros. Schema 2 reuses field 19
as the first diagnostic and fields 19--45 contain all 27 diagnostics.

The schema-2 signature field 53 stores the particle record width (`45`). The
remaining signature fields retain the mode/source/parameter/decomposition and
provider fingerprint frozen in P2.1. Endpoint sidecars retain both accepted
endpoints for all three sources; gradients are rebuilt deterministically after
a successful read.

## Diagnostic vector

The order is the `BOM_RHS_*` order in `BOM.h`:

| Index | Quantity | Units |
|---:|---|---|
| 1--2 | `vBaseE`, `vBaseN` | m/s |
| 3--4 | `vSE`, `vSN` | m/s |
| 5--6 | `vWE`, `vWN` | m/s |
| 7--8 | `vE`, `vN` | m/s |
| 9--10 | `uE`, `uN` | m/s |
| 11--12 | `DvE`, `DvN` | m/s^2 |
| 13--14 | `DuE`, `DuN` | m/s^2 |
| 15 | `omega` | s^-1 |
| 16 | `f` | s^-1 |
| 17 | `tauSphere` | m^-1 |
| 18--19 | `cV`, `cU` | s^-1 |
| 20--23 | rotational v/u components | m/s^2 |
| 24--25 | inertial east/north components | m/s^2 |
| 26--27 | final drift east/north | m/s |

Trajectory diagnostics are evaluated at the accepted final position and the
trajectory sample time. Pickup diagnostics are the authoritative accepted
values at pickup time. A schema-2 reader requires exact equality between the
duplicated base-current, wind and drift fields before it can commit.

## Read transaction

The reader validates, in order, signature and decomposition, endpoint sidecar,
tiled physical lengths and MDS metadata, headers, finite particle fields,
owner mapping, exact global IDs, and diagnostic/legacy equality. Particle and
diagnostic arrays plus endpoint fields are held in scratch storage. Only after
all ranks pass are the endpoint fields, particle state, diagnostics and output
schedule committed once. Any failure reports `BOM_FAIL_PICKUP_SCHEMA=15` and
does not print the completion marker.

