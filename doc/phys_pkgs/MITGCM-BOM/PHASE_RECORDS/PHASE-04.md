# MITGCM-BOM Phase 4 阶段记录：生物过程、陆地与事件

## 1. 阶段目标

Phase 4 在已发布的 v0.4 弹簧/分布式邻居系统之上增加：

1. 表层温度与营养盐的事务端点；
2. 固定 BOM 子步的 Brooks amount 更新；
3. 生物死亡、搁浅、域外和出生取消的独立事件；
4. 保持紧凑 owner 前缀的 O(1) 尾部槽位复用；
5. 与 MPI 分解无关的出生角度、重试、ID 和谱系；
6. schema 4 轨迹/事件/pickup 与闭合诊断；
7. B11--B15、B17--B19 及完整前序回归。

目标版本为 annotated tag MITGCM-BOM-v0.5。

## 2. 准入基线

| 项目 | 冻结值 |
|---|---|
| base tag | MITGCM-BOM-v0.4 |
| tag object | 67ac22063a4860e30c504624f1530f853d29f1a2 |
| peeled commit | 70c02a277ea7d472ccf6e9a7533b2b41ed7eab5a |
| Phase 3 final gate | 538/538 PASS |
| Phase 3 row audit | 14bb14aadf48382e169a325d0bd435f1a7f02f36eec0c8e9a3a36ca5ed8f98f2 |
| Phase 3 release-head manifest | 89a19cda62556e6c30fb537f2be20527ec218fbe8caa9797d9e4ffda2b302b48 |
| Phase 3 independent exit audit | PASS |
| Julia reference | 156557359185e4413ce82829f3ed26a4eb8c6283 |
| local platform | Ubuntu 22.04 / GNU Fortran 11.4 / Open MPI 4.1.2 / Julia 1.10.12 |

Phase 3 PR #30、#31 和退出记录 PR #32 已依次以 merge commit 集成。
最终 development、远端 development 与 v0.4 peeled commit 一致，进入
P4.0 时工作树洁净。

## 3. P4.0 设计裁决

### 3.1 参考实现与生产实现的边界

锁定 Julia 版本提供 Brooks 公式、严格阈值和“距父体一个 L、均匀角度”
的对照，但以下行为不得照搬：

- 自适应 ODE callback 决定事件时刻；
- 全局状态 RNG；
- 只递增 slot、死亡后不复用；
- 达到容量后截掉出生候选；
- 陆地与生物死亡使用同一 kill 状态；
- 无湿点/域外重试和无事件日志；
- 出生 string 路径依赖未定义旧粒子数。

MITGCM-BOM 使用固定子步、事务候选、稳定状态/事件码、精确 ID、尾部
槽位复用和 counter RNG。

### 3.2 紧凑状态与 free-list

v0.4 的运动、ghost、邻居、迁移和 I/O 都要求每 tile 有效 owner 位于
1:bomNPartTile。P4 不引入中间空洞。

删除 owner 时把最后一个有效 owner 交换到被删槽位，清空旧尾部并压入
尾部空闲栈；出生从尾部栈弹出且必须得到 bomNPartTile+1。删除与分配均为
O(1)，slot 顺序不作为身份或随机键。

### 3.3 出生排序与 MPI

仅按 rank 的 MPI exclusive prefix sum 不能保证换分解后 ID 不变。P4
先交换有界事件元数据并按父体 exact ID 全局排序，再从 bomNextId 连续
分配。允许交换事件元数据，不允许 gather 全部存活 owner。Phase 5 可用
分布式排序替换该实现，但不得改变排序语义。

### 3.4 陆地与 RK

合法干点/域外遭遇在 RK scratch 中成为 terminal candidate，不是任意
插值失败；权威位置保持子步开始时最后一个湿点，尝试位置只进入事件记录。
RK stage 内不改变 owner 数、slot、ID、事件 buffer 或权威 graph。

### 3.5 生物与环境

温度来自表层 theta，营养盐来自受编译/运行保护的 PTRACER 或 BOM FILES。
两者使用 accepted OLD/NEW 端点并在完整子步 tSub1 插值。缺测策略明确为
STOP 或 NO_GROWTH；后者只关闭生长，死亡率仍生效。

Brooks 内部使用 s^-1、显式 Tmin/Tmax/Topt 分支、N=max(N,0) 和严格
S<Smin、S>Smax 事件。出生成功时父/子设 S0；全部湿点重试失败时取消
出生并恢复父体本子步更新前 S。

## 4. 工作包

| 工作包 | 内容 | 状态 | 退出门禁 |
|---|---|---|---|
| P4.0 | 源码审计、接口/编号/schema/RNG/测试冻结 | 本地完成 | 文档/范围审计 15/15；生产 diff 为零 |
| P4.1 | 参数/稳定码、T/N 端点、Brooks stateless kernel | 本地完成 | P4-Z01/C01/E01/E02/B01、B12、前序 538 |
| P4.2 | boundary scratch、terminal state machine、compact-tail free stack | 本地完成 | P4-L01/F01/T01、B11、B13 death/free |
| P4.3 | Philox、重试、全局出生 ID、packet schema 3、graph integration | 本地完成 | P4-RNG01/BR01/ID01/M01、B13/B14/B17 |
| P4.4 | schema 4、事件分片、诊断、pickup | 未开始 | P4-S01/EV01、B15/B18 |
| P4.5 | 容量矩阵、完整集成和退出 | 未开始 | B19、P4-G99、独立退出审计 |

工作包必须按顺序完成。每个包可以有多个本地提交，但关闭时必须在同一
洁净精确头上保存直接门禁、全部已接受 P4 前序和必要的 v0.4 回归。

## 5. 冻结需求与测试

- 需求：[Phase 4 requirements traceability](../../../../verification/bom/phase04-biology-land/REQUIREMENTS_TRACEABILITY.md)
- 接口：[P4.0 interface freeze](../../../../verification/bom/phase04-biology-land/P4.0_INTERFACE_FREEZE.md)
- 源码审计：[P4.0 source audit](../../../../verification/bom/phase04-biology-land/P4.0_SOURCE_AUDIT.md)
- 测试计划：[Phase 4 test plan](../../../../verification/bom/phase04-biology-land/TEST_PLAN.md)

P4-R01--P4-R20 覆盖 v0.4 零影响、T/N、Brooks、陆地、事务、free stack、
RNG、出生 ID、容量、迁移、schema 4、restart、诊断、MPI 与最终退出。

## 6. 兼容与后置边界

- P4 开关默认关闭；
- LEEW 继续 schema 1 且无生物；
- BOM 无弹簧/P4 继续 schema 2；
- 弹簧开启但 P4 关闭继续 schema 3；
- P4 event 路径使用 schema 4；
- schema-2 core 与已有 P3 sidecar 不扩宽、不改义；
- changed-decomposition restart 继续拒绝；
- OpenMP 事件并发、目标服务器 10^5 粒子扩展归 Phase 5；
- EXCH2、cubed-sphere、LLC 和一般网格归 Phase 6；
- Phase 4 不向海洋动量、温度或营养盐反馈。

## 7. P4.0 完成结果

不可变冻结提交
`88214b7dee0816ec197691014261a356b7210614`（tree
`c157d254aa68e643fd6c30ca405577fd26bdbc94`）满足：

1. branch 精确基于 v0.4 peeled commit；
2. 锁定 Julia 提交与七份文件哈希复核通过；
3. P4-A--P4-L 均有唯一裁决和后续 owner；
4. P4-D001--P4-D028、P4-R01--P4-R20 顺序完整；
5. B11--B15、B17--B19 与 P4-G99 均已登记；
6. 所有相对链接有效；
7. 仅八个 allowlist Markdown 发生变化；
8. pkg/bom、model、测试 driver、input、reference 和生成证据 diff 为零；
9. 仓库外只读审计返回 `P4.0_DOC_AUDIT PASS 15/15`；
10. 项目状态把 P4.1 标为唯一下一生产任务。

P4.0 不运行或宣称任何已实现的 Phase 4 Fortran 功能测试。
详细证据见
[P4.0 design audit](../../../../verification/bom/phase04-biology-land/P4.0_DESIGN_AUDIT.md)。

## 8. P4.1 完成结果

P4.1 已在功能头
`4043a35ddeb049ead5c8081bae3417e335cdbae7` 本地关闭：

1. `e540aed09` 加入 inactive 参数/稳定码、事务 T/N OLD/NEW endpoint、
   THETA/PTRACER/FILES provider、exact-time/common-wet interpolation 和
   Brooks stateless/immutable plan；
2. `5d3a373e9` 加入 P4.1 串行/MPI4/no-PTRACERS 直接门禁、FILES fixture
   和 90 位 Decimal oracle；
3. `p41-final-head-attempt02` 在干净精确头通过 31/31；
4. `p41-predecessor-final-head-attempt02` 通过 P3 直接 148/148、Phase 2
   closure 390/390 和总计 538/538；
5. 两套证据的 source-head 均为 `4043a35dd...`，manifest 自校验通过；
6. live owner/event/schema4 在 P4.1 仍 fail-closed，P4.1 无出生、terminal commit、
   slot 变更、事件 I/O 或 restart/output 扩展；
7. P4.0 已由 PR #33、P4.1 已由 PR #34 依次以 merge commit 集成到
   development；未创建 v0.5。

详细实现边界、已解决问题和证据路径见
[P4.1 closeout](../../../../verification/bom/phase04-biology-land/P4.1_CLOSEOUT.md)。

## 9. P4.2 完成结果

P4.2 在独立分支 `MITGCM-BOM/p4.2-boundary-terminal-free-stack` 本地关闭：

1. `145244380` 加入 WET/BEACHED/OUTSIDE/FATAL classifier、P4 owner/event
   状态、compact-tail free stack、负原点 periodic 修正及 land-only 迁移维护；
2. `6fbcb7819` 加入 additive RK2/RK4 P4 接口、spring terminal exclusion、
   exact-ID post-migration binding 和 all-or-nothing event transaction；
3. `62538a836` 加入 P4.2 18-row 串行/MPI4 direct gate，覆盖 P4-L01/F01/T01、
   B11 以及 B13 death/free；
4. `p42-final-head-attempt03` 在洁净精确 closeout 头通过 18/18；
5. `p42-p41-accepted-attempt04` 在同一头以显式 p42 scope 重放 P4.1
   31/31；默认 p41 范围断言保持不变；
6. 隔离共享 clone 中的 `p42-predecessor-final-head-attempt04` 通过 P3
   direct 148/148、Phase 2 closure 390/390，总计 538/538；权威分支和
   annotated v0.4 未改动；
7. P4.2 保持 owner packet schema 2、P3 container schema 3 不变；完整
   parent/S/birth migration、Philox、child ID、graph integration 属于 P4.3；
8. event files、schema 4 output/pickup、restart 与最终预算仍属于 P4.4/P4.5；
9. 本分支未推送、未创建 PR、未合并，也未创建 v0.5。

详细实现边界、已解决问题和证据路径见
[P4.2 closeout](../../../../verification/bom/phase04-biology-land/P4.2_CLOSEOUT.md)。

## 10. P4.3 完成结果

P4.3 在独立分支 `MITGCM-BOM/p4.3-rng-birth-schema3` 本地关闭：

1. `852659089` 加入精确 Philox4x32-10、16-bit limb multiply、冻结
   birth key 和 13 组独立 Python/Fortran word/angle fixture；
2. `7a14707da` 加入 WET/retry/cancel placement、有界事件元数据
   allgather、exact parent-ID 排序、重复拒绝与连续 child ID；
3. `460d42890` 加入出生/死亡/free-stack 原子事务、biology owner
   packet schema 3、完整 post-event owner candidate 和 FINAL graph/component
   rebuild；
4. 收口增量让迁移生产路径共用 packet validator，拒绝 schema、
   ID/parent words、count、destination、non-finite real 和 packet length
   变异，且在 owner replacement 前失败关闭；
5. `p43-final-head-attempt03` 在洁净精确头通过 26/26，包含
   serial/MPI2/MPI4 Philox、birth/ID/event/schema3/graph 以及反向 slot
   比较；
6. `p43-p42-accepted-attempt03` 通过 18/18，
   `p43-p41-accepted-attempt03` 以显式 p43 scope 通过 31/31；
7. 隔离 shared clone 的 `p43-predecessor-final-head-attempt03` 通过
   Phase 3 direct 148/148 与 Phase 2 closure 390/390，总计 538/538；
8. 前一次完整 replay 在 P3.5、P3.4 通过后发现 P3.3 仍检查旧二维迁移
   缓冲区源码形态；门禁已改为检查等价的一维 `packetOffset` 字段位置，
   未改变 schema 2 的 10-int/6-real 契约；
9. BOM 仍为独立 package，`FLT+BOM` 仅是兼容回归；未读写 SKRIPS；
10. event files、schema 4 output/pickup、restart、B18/B19 和 P4-G99
   仍属于 P4.4/P4.5；本分支未推送、未创建 PR、未合并、
   未创建 v0.5。

详细实现边界、已解决问题和证据路径见
[P4.3 closeout](../../../../verification/bom/phase04-biology-land/P4.3_CLOSEOUT.md)。

## 11. 当前恢复点

P4.3 本地完成后：

1. 未经明确授权不推送、创建 PR、合并或创建 v0.5；
2. 获授权后集中推送 P4.3 的生产、验证和收口提交并创建 Draft PR；
3. P4.3 经评审集成后从 development 创建 P4.4 分支；
4. P4.4 仅开发 schema-4 trajectory/P4 sidecar、event shards、diagnostics、
   same-decomposition pickup/restart 和 B15/B18；
5. P4.4 不提前进入 B19、P4-G99、Phase 4 exit 或 Phase 5 服务器扩展。

在 Phase 4 最终退出审计前不创建 MITGCM-BOM-v0.5 标签。
