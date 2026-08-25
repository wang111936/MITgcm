# P1.4 owner 迁移执行结果

状态：**IMPLEMENTATION/EVIDENCE PASS — INDEPENDENT READY REVIEW PENDING**

| 项目 | 值 |
|---|---|
| 执行日期 | 2026-08-25 |
| clean exact tested head | `1786d52f9f510e4f9d0c470ed75b9b7289ca64b0` |
| 分支 | `MITGCM-BOM/phase-01-owner-migration` |
| Draft PR | `wang111936/MITgcm#14` |
| 基线 | `00896885a4938824bc9466eae990e23bf7329b4f` |
| 接口冻结提交 | `4ca368ea22c6a0f90cf6d7f4ed2eb645c109b573` |
| 生产实现提交 | `58d9df73b06a766b40ebb8e331e6608a44560616` |
| 专属门禁提交 | `54f993c970ed41ee0a42626322e681381a1fb542` |
| 前序兼容提交 | `1786d52f9f510e4f9d0c470ed75b9b7289ca64b0` |
| P1.4 专属门禁 | 36/36 PASS |
| 前序回归 | 157/157 PASS |

## 1. P1.4 专属门禁

| 类别 | PASS | 覆盖 |
|---|---:|---|
| 生产源码契约 | 1 | 二分 owner 定位、halo-aware RK、双字 64 位 ID 与事务交换 |
| GNU debug/IEEE 构建 | 7 | serial、MPI2、MPI4、多 tile serial/MPI4、发送接收容量、tile 容量 |
| 正向运行 | 18 | 横向、纵向、角点、周期 X、大 ID、多子步多 tile、halo stencil |
| bitwise 分解比较 | 6 | 横向、纵向、角点、周期 X、大 ID、多子步路径 |
| 负向门禁 | 4 | SEND、RECV、目标 tile 容量及最大 hop |

专属摘要逐项证明：

- P1-X01 在同 rank 及 MPI2/MPI4 分解中保持唯一 owner、连续位置、全局
  粒子数和 ID；
- P1-X02 的横/纵/角点与周期 X 权威状态按 ID 重组后，在
  serial/MPI2/MPI4 间逐位一致；
- P1-X03 连续 16 个 nominal 子步逐步迁移，每步 `hop=1`，serial 与
  MPI4 最终状态逐位一致；
- P1-X04 对大于 `2^53` 的正 64 位 ID 使用两个 `MPI_INTEGER` 字恢复，
  不经过 `_RL`，serial/MPI2/MPI4 状态逐位一致；
- P1-N03b 分别触发 rank 0 SEND `needed/limit=2/1`、rank 2 RECV
  `2/1` 和 rank 0 tile `(2,1)` `2/1` 的集体致命停止，没有截断或
  部分提交；
- hop 负测记录 ID、源/目标 owner、`hop/limit=2/1` 以及
  iter/substep/time；stencil 负测保持候选坐标回滚。

## 2. 正式执行位置

```text
Build:
/home/wyl/build/mitgcm-bom/phase01-owner-migration/p14-owner-1786d52f-20260825T133000Z

Run:
/home/wyl/runs/mitgcm-bom/phase01-owner-migration/p14-owner-1786d52f-20260825T133000Z

Compact evidence:
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p14/p14-owner-1786d52f-20260825T133000Z
```

紧凑证据包含 `summary.tsv`、`source-head.txt`、空的
`git-status.txt`、`environment.txt`、`config.sha256` 和
`manifest.sha256`。`sha256sum -c manifest.sha256` 全部通过，源码记录
与表中 exact head 一致。

## 3. 同一 exact head 的前序回归

| 工作包 | PASS |
|---|---:|
| P1.3 lifecycle | 13 |
| P1.3 setup | 17 |
| P1.3 Leeway RHS | 15 |
| P1.3 RK2 | 11 |
| P1.3 RK4 | 11 |
| P1.2 interpolation | 9 |
| P1.2 surface fields | 7 |
| P1.2 mapping | 19 |
| P1.1 state/negative matrix | 42 |
| Phase 0 final gate | 4 |
| nested P0.4 formal gate | 9 |
| **合计** | **157** |

十一份摘要、同一 `source-head.txt` 和空工作树记录已复制到：

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p14/
  p14-owner-1786d52f-20260825T133000Z/predecessor-regressions
```

该子目录使用独立 `manifest.sha256`；校验全部通过，所有 157 个结果行
均为 PASS，没有复用或覆盖历史 P1.3/P1.2/P1.1/Phase 0 证据。

P1.4 改变了两个历史前提，前序驱动只在显式
`MITGCM_BOM_ALLOW_OWNER_MIGRATION=yes` 时采用以下替代判据：

1. P1.3 的严格 K4 离开 owner 拒绝由 P1.4 halo-aware RK、stencil
   回滚和子步后迁移门禁替代；
2. P1.1 的 `OLx=OLy=1` BOM-active 正向用例由 P1.4 明确的
   `OLx/OLy>=2` 启动拒绝替代。

兼容开关默认关闭，因此历史分支上的原门禁语义未被静默改写。

## 4. 结论与边界

P1.4 的生产实现、P1-N03b/P1-X01—X04、分解一致性、失败事务以及
全部前序回归均无开放发现。P1.4 可以作为 P1.5 输出、pickup/restart
与 FLT 共存工作的冻结输入。

本结论不是独立 PR Ready 复审，也不授权把 PR #14 改为 Ready、合并、
创建标签或发布。P1.5 不得把轨迹/pickup I/O 与 FLT 状态混用，也不得
削弱本文件锁定的 36/36 和 157/157 判据。

## 5. P1.3 integration synchronization revalidation

PR #13 merged into `MITGCM-BOM/development` as
`41fb093866ef4c2dbda778696892457cfca160f9`. P1.4 synchronized that history at
clean head `55d6eac29d748e41f194247c70dd28f8f33817ff`; the synchronization changes
P1.3 verification and records only, not P1.4 production source.

The following exact-head gates pass:

| Gate | Test ID | Result | Summary SHA-256 |
|---|---|---:|---|
| owner migration | `p14-ready-sync-owner-55d6eac2-attempt01` | 36/36 | `6c8bb94c78cc334a6780c208ca6673bca124610624f679d1dfafc135177974cb` |
| RK2 | `p14-ready-sync-rk2-55d6eac2-attempt01` | 12/12 | `1d1800b750eda15d04a39c34c38341178bd427425b77d2f5520ce707ffd0fcc4` |
| RK4 | `p14-ready-sync-rk4-55d6eac2-attempt01` | 12/12 | `f96989908429bff60562c02bdcf9b6af96423d379824d7d253ded0691cb60fb0` |

Artifact roots:

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p14/p14-ready-sync-owner-55d6eac2-attempt01
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/p14-ready-sync-rk2-55d6eac2-attempt01
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p13/p14-ready-sync-rk4-55d6eac2-attempt01
```

All three gates record the same clean source head and contain only PASS rows.
