# MITGCM-BOM Phase 4 exit audit

Status: **RELEASE-CANDIDATE AUDIT PASS; RELEASE-HEAD REVALIDATION PENDING**

Audit date: 2026-08-30

Audited clean exact development head:
`9a468ec3d642986f292b941aa6612d74301dda91`.

## 1. Exit decision

The Phase 4 release candidate passes the complete 689-row P4-G99 gate and
the independent Phase 4 exit audit. No open Phase 4 production, regression,
schema, bounded-collective or scope finding remains at the audited head.

This record is intentionally not the release action. After this record is
merged, P4-G99 and the independent audit must run again on the resulting clean
exact `MITGCM-BOM/development` head. Annotated tag `MITGCM-BOM-v0.5` may be
created only if both release-head reruns pass.

## 2. Ordered integration

| Package/change | PR | Merge commit |
|---|---:|---|
| P4.0 interface freeze | #33 | `2e65cc63d66ff625594dbbf61048e60513ed39fe` |
| P4.1 biology fields and Brooks plans | #34 | `0d7a20ef232c45c70fa0f90dbba1dc79a3893ab9` |
| P4.2 boundary, terminal and free stack | #35 | `f7937de95f7637b9b30ff8f08fb5e20d77f4f360` |
| P4.3 RNG, births, schema 3 and graph | #36 | `d97eb32e299a9f8fbefa23c661a863a51c2798b1` |
| P4.4 schema 4, events and pickup | #37 | `4306d03e80943d33487bf73dbda91cad2c276856` |
| P4.5 capacity and exit drivers | #38 | `3c066e7d86bf6007411c6d0893ffd4e8db81dcf9` |
| isolated-clone branch setup | #39 | `89f54eebbb9ee889029a77e198caaf2fecead613` |
| isolated-clone tag isolation | #40 | `d52fb14b9f6cbbf84b38902d1e94500b8323763c` |
| owner-preflight predecessor audit | #41 | `0db1bea6b02eba2b75c9bcdafcdbefc38d10cf81` |
| exact P4.5 predecessor scope | #42 | `1e2ac4f5b694223710992f6fe527d53028ab6136` |
| P4.4 B18 final-audit coverage | #43 | `9a468ec3d642986f292b941aa6612d74301dda91` |

The immutable implementation package heads used by the audit are P4.0
`260d54518f4cfea2499b586a0e742f86d8d1e1be`, P4.1
`77a780f0f3c7bb01a6e846b51c2049cd64ca6fbf`, P4.2
`9d50924fe06f60652f042864874d6e37c261a739`, P4.3
`ed6c6f301d6c438d334b188dc752dff378f789c1`, P4.4
`3db095463bfc7bc64bd0ce198951ba0f805c6015` and P4.5
`d618716f3936da7b589598b53f023f2ae379cf15`.

## 3. Release-candidate evidence

P4-G99 evidence root:
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/p4-g99/p4-g99-release-candidate-9a468ec3d-attempt06`.

- P4.1: 31/31;
- P4.2: 18/18;
- P4.3: 26/26;
- P4.4: 57/57;
- P4.5: 19/19;
- exact Phase 3 predecessor matrix: 538/538;
- aggregate: 689/689 PASS;
- `row-audit.tsv` SHA-256:
  `ad2eef6c8c88be67f4014b40d0f7feb940bcfd0adfae04a8e3e303875253d703`;
- `manifest.sha256` SHA-256:
  `45ef971a30cb9a06149d70458b552c057dbe35be25792f8287fa1d4a2ffdfb77`;
- `independent-audit.log` SHA-256:
  `b24a8375070d4b4d02832a0eee9df0804a50b5baf450f62e435ce0f25f504dda`.

Independent exit evidence root:
`/home/wyl/projects/mitgcm-bom-test-artifacts/phase04/exit-audit/phase4-exit-release-candidate-9a468ec3d-attempt01`.

- result: `PHASE 4 INDEPENDENT EXIT AUDIT PASS`;
- audited requirements: P4-R01--P4-R20;
- audited rows: 689;
- audited package/merge ancestry: complete and ordered;
- `manifest.sha256` SHA-256:
  `b9f18b8e9083a6ec4e1a42ac18b002dc8e502bb4e68d2b0f6fa69f3b7f72f4d6`;
- `independent-exit-audit.log` SHA-256:
  `03532a15b40dcf417d463fb9ca419b3b0364bcbafca5ac8241b6f303641b79b7`.

## 4. Requirement and boundary findings

- P4-R01--P4-R20 are closed on the release candidate by direct evidence,
  exact predecessor replay and independent source/manifest audit.
- B11--B15 and B17--B19 are present in the registered direct matrices.
- Schema 1 LEEW, schema 2 BOM core and schema 3 spring paths remain unchanged;
  P4 biology/event state is confined to schema 4.
- Event ordering exchanges bounded metadata only. No production path gathers
  all live owner state.
- Every capacity overflow is preflighted, carries stable need/capacity and
  canonical context, and fails before authoritative mutation.
- BOM remains an independent package. `FLT+BOM` is only a coexistence test and
  is not a runtime dependency.
- No SKRIPS source, evidence or configuration is part of this development.
- OpenMP/target-server scaling remains Phase 5; general grids remain Phase 6.

## 5. Integration findings resolved during P4-G99

The first integrated executions exposed five audit/driver compatibility
defects rather than new production semantics. Each was fixed in a separate
reviewed merge before the successful release-candidate run:

1. initialize the current branch correctly in the isolated shared clone;
2. prevent the clone from copying the future-phase tag namespace;
3. teach the historical P1.4 audit the unified owner-exchange preflight and
   stable capacity diagnostic;
4. admit the exact P4.5 closure scope while retaining earlier scope checks;
5. recognize the frozen P4.4 B18 budget evidence in the final row audit.

## 6. Required release action

1. merge this exit record to `MITGCM-BOM/development` with a merge commit;
2. rerun P4-G99 on that exact clean release head and require 689/689;
3. rerun the independent Phase 4 exit audit against the new P4-G99 evidence;
4. verify local and remote development heads are identical and the tree is
   clean;
5. create and push annotated tag `MITGCM-BOM-v0.5` at that exact head;
6. verify both the remote tag object and its peeled commit before opening
   Phase 5.

