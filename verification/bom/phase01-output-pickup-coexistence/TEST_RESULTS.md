# P1.5 output, pickup, and FLT coexistence results

状态：开发门禁通过；clean exact-head P1-G01 待执行

以下证据均基于分支
`MITGCM-BOM/phase-01-output-pickup-coexistence`，记录的 source head 为
`4f6c4bf4361933091390ead4273223e18ff1bc29`，并包含尚未提交的 pickup、
迁移与共存实现。因此它们证明生产路径在开发工作树上成立，但不能替代
最终 clean exact-head 验收。

## 1. Output、pickup 与 restart

- 结果：25/25 PASS；
- test-id：`p15-pickup-dev04-4f6c4bf4-20260825T230000Z`；
- artifact：`/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/p15-pickup-dev04-4f6c4bf4-20260825T230000Z`；
- 覆盖：serial/MPI2/MPI4 构建；150/60 非整除调度；输出关闭；5+3
  split/restart；大 ID 与 WAITING；真实 MPI2→MPI4 signature 拒绝；缺失
  tile、坏 schema、重复 ID 和时间损坏的事务性拒绝；同分解完整记录和
  跨分解物理规范化视图的 bitwise 比较。

## 2. 生产 owner 迁移后的 I/O

- 结果：12/12 PASS；
- test-id：`p15-migration-dev02-4f6c4bf4-20260826T010000Z`；
- artifact：`/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/p15-migration-dev02-4f6c4bf4-20260826T010000Z`；
- 覆盖：生产 schema-1 初值和 U/V 场；serial/MPI4 四帧；真实跨 tile/rank；
  大 ID WAITING→ALIVE；迁移后 permanent core+BOM pickup；5+3 restart；
  serial/MPI4 物理字段 bitwise 一致。

## 3. FLT/BOM 独立共存

- 结果：25/25 PASS；
- test-id：`p15-coexistence-dev02-4f6c4bf4-20260826T030000Z`；
- artifact：`/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/p15-coexistence-dev02-4f6c4bf4-20260826T030000Z`；
- 覆盖：MITgcm exp4 FLT 基准；neither/FLT-only/BOM-only/FLT+BOM 的
  serial/MPI2 八组构建与八组运行；关闭包不产文件；四组合核心 pickup
  SHA-256 相同；FLT-only 与共存的 FLT trajectory/pickup SHA-256 相同；
  BOM-only 与共存的 BOM canonical trajectory/pickup bitwise 相同。

## 4. 关闭条件

提交生产实现和门禁后，必须在同一 clean exact head 重新执行三项 P1.5
门禁、P1.4 owner gate、P1.3 全部门禁、P1.2/P1.1 与 Phase 0 全回归，
并审计空 `git-status.txt`、summary、环境、配置校验和及 manifest。完成前
PR 保持 Draft，不创建 `MITGCM-BOM-v0.2` 标签。
