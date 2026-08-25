# P1.5 output, pickup, and FLT coexistence results

状态：**SYNCHRONIZED EXACT-HEAD PASS — INDEPENDENT READY REVIEW PENDING**

| 项目 | 值 |
|---|---|
| 执行日期 | 2026-08-25 |
| synchronized clean exact tested head | `adb9e315836079d8ef1280e15d7ede7aa52fee6c` |
| 分支 | `MITGCM-BOM/phase-01-output-pickup-coexistence` |
| Draft PR | `wang111936/MITgcm#15` |
| P1.4 集成基线 | `9d258da4ff43d84f4877ba11d894af0e96b3177b` |
| P1.5 生产实现提交 | `746171a37e61974ef3a7aca6b49c4f95b1400a3b` |
| 同步提交 | `adb9e315836079d8ef1280e15d7ede7aa52fee6c` |
| P1.5 专属门禁 | 62/62 PASS |
| P1.4 及更早回归 | 195/195 PASS |
| P1-G01 总计 | 257/257 PASS |

## 1. Output、pickup 与 restart

- 结果：25/25 PASS；
- test ID：`p15-output-final01-cb1ffa1ec-20260826T180000Z`；
- artifact：
  `/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/p15-output-final01-cb1ffa1ec-20260826T180000Z`；
- 覆盖：serial/MPI2/MPI4 构建；150/60 非整除调度；输出关闭；5+3
  split/restart；大 ID 与 WAITING；MPI2 pickup 用 MPI4 恢复时的分解
  signature 早期拒绝；缺失 tile、坏 schema、重复 ID 和时间损坏的
  事务性拒绝；同分解完整记录和跨分解物理规范化视图的 bitwise 比较。

该门禁同时证明 BOM pickup 使用 MITgcm 核心 checkpoint suffix，连续与
相同分解 restart 的权威状态、下一输出时刻和 canonical 轨迹逐位一致。

## 2. 生产 owner 迁移后的 I/O

- 结果：12/12 PASS；
- test ID：`p15-migration-final01-cb1ffa1ec-20260826T190000Z`；
- artifact：
  `/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/p15-migration-final01-cb1ffa1ec-20260826T190000Z`；
- 覆盖：生产 schema-1 初值和 U/V 场；serial/MPI4 四帧；真实跨
  tile/rank；大 ID WAITING→ALIVE；迁移后 permanent core+BOM pickup；
  5+3 restart；serial/MPI4 物理字段 bitwise 一致，布局字段分别满足各自
  分解的 owner、tile 和局部索引规则。

## 3. FLT/BOM 独立共存

- 结果：25/25 PASS；
- test ID：`p15-coexistence-final01-cb1ffa1ec-20260826T200000Z`；
- artifact：
  `/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/p15-coexistence-final01-cb1ffa1ec-20260826T200000Z`；
- 覆盖：MITgcm exp4 FLT 基准；neither、FLT-only、BOM-only、FLT+BOM
  的 serial/MPI2 八组构建与八组运行；关闭包不产文件；四组合核心
  permanent pickup SHA-256 相同；FLT-only 与共存的 FLT
  trajectory/pickup SHA-256 相同；BOM-only 与共存的 BOM canonical
  trajectory/pickup bitwise 相同。

源码契约同时确认两个包使用独立编译/运行开关、COMMON 状态、入口和
文件前缀，BOM 生产源不 include 或引用 FLT 状态。

## 4. 同一 exact head 的前序回归

| 工作包 | PASS |
|---|---:|
| P1.4 owner migration | 36 |
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
| **合计** | **193** |

P1.3 lifecycle 与 P1.1 state 只在该后继 head 上显式设置默认关闭的
`MITGCM_BOM_ALLOW_OWNER_MIGRATION=yes`，以采用 P1.4 已冻结的两个替代
判据：halo-aware RK/迁移替代严格 K4 owner 拒绝，`OL>=2` 启动约束替代
旧的 OL1 active 正向用例。默认模式没有被静默改变。

## 5. P1-G01 紧凑证据与 manifest 审计

十五份专属及前序摘要、同一 `source-head.txt`、空的
`git-status.txt`、环境记录、十五个门禁驱动的 `config.sha256`、逐项
审计日志和总 `manifest.sha256` 位于：

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/
  p15-g01-cb1ffa1ec-20260826T234500Z
```

总 manifest 的 21 个条目全部通过 `sha256sum -c`。P1.5、P1.4 和
P1.3 的九个原始紧凑工件 manifest 也全部复验通过；其
`source-head.txt` 均等于表中 exact head，P1.5/P1.4 的 Git 快照为空。
全部 255 个结果行均为 PASS，没有失败行，也没有复用或覆盖历史证据。

## 6. 结论与边界

P1-R03、P1-R13—P1-R16 中属于 P1.5 的输出、精确 ID I/O、事务性
pickup/restart、改变分解拒绝和 FLT/BOM 共存要求均有直接运行证据；
P1-G01 的专属及前序矩阵无开放发现。P1.5 的实现与证据门禁通过。

本结论不等于独立 PR Ready 复审，不授权把 PR #15 改为 Ready、合并、
创建 `MITGCM-BOM-v0.2` 标签或发布。记录本文件的文档提交还须在新的
clean exact head 上复验，并把最终提交与证据位置补充到 Draft PR #15。

## 7. P1.4 integration synchronization and final P1-G01

PR #14 merged as `9d258da4ff43d84f4877ba11d894af0e96b3177b` and was
incorporated by merge commit `adb9e315836079d8ef1280e15d7ede7aa52fee6c`.
The synchronized clean head passed the complete updated matrix:

| Matrix | PASS |
|---|---:|
| output/pickup | 25 |
| production migration I/O | 12 |
| FLT/BOM coexistence | 25 |
| P1.4 owner migration | 36 |
| P1.3 lifecycle/setup/RHS/RK2/RK4 | 69 |
| P1.2 interpolation/fields/mapping | 35 |
| P1.1 state | 42 |
| Phase 0 final plus nested P0.4 | 13 |
| **P1-G01 total** | **257** |

The aggregate artifact is:

```text
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/p15-g01-adb9e315-attempt01
```

It contains fifteen summaries, an empty Git status, the exact source head,
environment and driver hashes, nine validated native manifests, a row audit
and a self-validating aggregate manifest. SHA-256 values:

- aggregate manifest: `5ef39863d8f3284a7c41dbde26e2c851b4da2411bc6e8b48a18f130d94ab36a2`;
- row audit: `62ef52b7367dcaca6720198556dbefa97050ce05379093bb356c21911abe27bb`;
- exit audit: `dfaac4a9f07bddcafbae83a527f6b7cc9ddde827511590c28bbe3364df93397e`.
