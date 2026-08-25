# MITGCM-BOM Phase 2 阶段记录

| 项目 | 当前值 |
|---|---|
| 阶段 | Phase 2：慢流形惯性物理 |
| 目标版本 | `MITGCM-BOM-v0.3` |
| 基线标签 | `MITGCM-BOM-v0.2` |
| 基线 tag object | `ab4317e5fe695fb0b2eb3be9b1ce91b39ba137f1` |
| 基线提交 | `1067c21d230e9c9619e89245b97c01e9474c7ed7` |
| 准入日期 | 2026-08-25 |
| 状态 | **进行中（P2.0 完成，P2.1 首增量实现并通过开发门禁）** |
| 当前工作包 | P2.1 参数契约、稳定代码与 accepted endpoint 状态 |
| 准入记录 | PR #17/#18 已合并；当前集成基线 `f84ac9a824f6e2e38f92c7bb5d8e538ac16ced3f` |
| P2.0 记录 | PR #19；设计提交 `628a6bb4621429bf6f58e9e46a13216c21de7815` |
| 作者身份 | `WangYuLin <wang111936@outlook.com>` |

## 1. 准入裁决

Phase 2 的全部前置条件已满足：P1.1—P1.5 顺序集成，最终 production
code head `3f330b59db76b8d7d0ca0fb2bfd007e567fbd6bc` 的 P1-G01 257/257
PASS，Phase 0 及嵌套 P0.4 无回归，独立退出审计无开放 finding，且
`MITGCM-BOM-v0.2` 已发布并验证。

P2.0 已完成纯文档冻结并通过本地范围/编号审计与 GitHub PR #19
不可变远端补丁复审。该增量没有加入生产 Fortran、测试脚本、算例输入
或生成证据。Phase 2 进入实现阶段，但必须继续按 P2.1—P2.5 顺序开发，
每个工作包在合并前执行其冻结门禁。

## 2. 阶段目标与边界

Phase 2 在已验收 BOM-Lite 基础上增加慢流形惯性物理：

- 保存并发布 old/new 环境场及其确切时间标签；
- 构造 east/north colocated 速度导数、物质导数、涡度和球面度量；
- 接入显式 Stokes 漂移与 EXF 10 m 风，同时防止 Stokes 重复计入；
- 实现并明确区分 `PAPER2024` 与 `JULIA` 方程模式；
- 建立 B04 固体旋转、B05 时变均匀流和 B16 固定 Julia golden；
- 扩展 pickup，使模式和 old/new 状态可确定性恢复。

Phase 2 不包括弹簧/邻居、出生死亡、生物过程、搁浅、随机过程、一般
网格或目标站点性能加固；它们分别由 Phase 3—Phase 6 管理。

## 3. P2.0 必须冻结的决定

1. `old`/`new` 的模型时刻、迭代号、EXF 请求时刻与可用性状态；
2. 海流、风和 Stokes 的 C-grid 来源、east/north colocation、mask、halo 和 SI 单位；
3. `bomStokesSource=NONE/FILES/COUPLER` 的数据所有权、更新时间和失败语义；
4. 输入海流已含 Stokes 时的显式去重配置与可审计诊断；
5. Cartesian 与未旋转 spherical-polar 的米制度量导数、极区/坏度量拒绝边界；
6. `PAPER2024` 与 `JULIA` 两种 RHS 的逐项公式、符号、参数和共享/差异部分；
7. 固定 Julia 输入、Project/Manifest、坐标/单位、时间步和 golden 容差；
8. RK stage 使用 old/new 时间插值的规则及 B05 对总体时间阶的裁决；
9. 新增模式/场状态的 pickup schema、向后兼容与事务恢复规则；
10. stable failure/stage codes、有限性/CFL/rollback 和 1/2/4-rank 证据矩阵。

## 4. 分工作包方案

| 工作包 | 交付 | 主要验收 | 当前状态 |
|---|---|---|---|
| P2.0 设计冻结 | 需求、接口、方程、时间层、Stokes 去重、golden/test plan | 18 需求、18 决定、编号/链接/范围与 PR patch | 完成（PR #19） |
| P2.1 old/new 场 | 双时间层海流/风/Stokes 快照、时间插值和 pickup 状态 | 常值与时变场、mask/halo、restart | 进行中（首增量：参数/代码/状态） |
| P2.2 导数网格 | colocated 梯度、时间导数、涡度和球面度量 | B04、解析导数、坏度量负测 | 未开始 |
| P2.3 慢流形 RHS | `PAPER2024`/`JULIA` 分量与统一调度 | 分量解析、符号、Stokes 去重 | 未开始 |
| P2.4 积分与 golden | RK stage 时间插值、固定 Julia 对照 | B05、B16、收敛与 rollback | 未开始 |
| P2.5 集成收口 | 全回归、MPI/restart、独立退出审计 | Phase 2 总门禁与 v0.3 决策 | 未开始 |

实际开发允许因新发现调整内部增量，但不得跳过 P2.0，也不得把未验证
假设静默变成生产默认值。新增问题必须登记为 finding/risk，明确 owner、
阻塞阶段、修复提交与复验范围。

## 5. 已知风险与后置条件

| ID | 风险/限制 | Phase 2 处理 |
|---|---|---|
| P2-RISK-01 | Julia 固定提交无历史根 Manifest，整轨迹 golden 仍为 provisional | P2.0 冻结重建环境与输入校验和；P2.4 才允许升级为 golden oracle |
| P2-RISK-02 | Phase 1 步内冻结场不能证明真实时变问题的高阶精度 | P2.1 保存 old/new；P2.4 用 B05 裁决时间插值与总体阶数 |
| P2-RISK-03 | 海流产品可能已经包含 Stokes | P2.0 冻结显式声明/去重/诊断；禁止隐式叠加 |
| P2-RISK-04 | 论文方程与旧 Julia 行为不完全相同 | 两种模式分开实现、分量测试和命名，不以兼容模式替代生产默认 |
| P2-RISK-05 | 目标服务器工具链尚未指定 | 继续用本地 GNU/MPI 基线；站点 optfile、调度器与性能由 Phase 5 验证 |
| P2-RISK-06 | 球面导数在极区和坏度量上可能不适定 | P2.0 固定支持域与失败边界；P2.2 加解析/负向门禁 |

## 6. Phase 2 总退出条件

- [x] P2.0 设计、需求、接口和测试契约已冻结并通过 PR #19 补丁复审；
- [ ] P2.0—P2.5 全部完成并顺序集成；
- [ ] B04、B05、B16 与 RK 收敛门禁通过；
- [ ] `PAPER2024`/`JULIA` 分量、Stokes 去重和单位/符号有直接证据；
- [ ] 1/2/4-rank、连续/restart 与全部 Phase 1/Phase 0 回归通过；
- [ ] Julia golden 从 provisional 升级或保留限制有新的明确裁决；
- [ ] 创建 `MITGCM-BOM-v0.3` 前完成独立退出审计。

## 7. 唯一下一任务

继续当前 `MITGCM-BOM/p2.1-environment-endpoints` 分支，下一增量只实现：

- fresh start 将同一 `(startTime,nIter0)` 事务发布到 OLD/NEW；
- 正常步将已接受 NEW 复制到 scratch OLD，并构建 exact-time NEW；
- 首先接通 ocean、`wind=NONE`、`Stokes=NONE` provider；
- component failure 保持 accepted state 完全不变；
- 增补 P2-E01/E02/E06 与连续性/rollback 直接门禁。

P2.1 不加入空间导数、协变项、慢流形 RHS 或 RK stage 接线；这些依次
属于 P2.2—P2.4。若实现需要改变已冻结的时间、来源、去重或 schema
语义，必须先更新 P2.0 契约和追踪表。

## 8. P2.0 完成记录

- 设计提交：`628a6bb4621429bf6f58e9e46a13216c21de7815`；
- GitHub PR：`wang111936/MITgcm#19`；
- 核心冻结交付：5 个 Markdown、1086 行；生产源码/脚本/输入变化为 0；
- 状态收口另更新 4 个 Markdown，只记录 PR、阶段和下一任务；
- 本地审计：`git diff --check` 与 `P2.0_DOC_AUDIT` PASS；
- 远端审计：5/5 文件为 Markdown，论文/Julia 模式、显式 current policy、
  exact endpoint、P2-H/N 编号和隔离命名检查全部 PASS；
- 结果：P2.0 关闭，无开放 finding；`MITGCM-BOM-v0.3` 未创建。

## 9. P2.1 首增量记录

- 功能提交：`920e22fbdcdf7ceb59f2bd795cad86d116ac21af`；
- 实现范围：冻结参数、stable source/endpoint/failure/stage codes、accepted endpoint 零状态；
- 权威测试 ID：`p21-endpoint-920e22fbd-attempt01`；
- 结果：source contract、串行/MPI4 构建、BOM 串行/MPI4、LEEW compatibility 与 7 项负测共 13/13 PASS；
- summary SHA-256：`29453e3305d6d6a43bb8b055995417109644e3a53dbf5a5f93b38e1969440293`；
- 证据目录：`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state/p21-endpoint-920e22fbd-attempt01`；
- 边界：未实现 exact-time providers、transaction commit、时间插值、field pickup、导数或 RHS；
- 状态：P2.1 继续进行，无开放 finding，不创建 `MITGCM-BOM-v0.3`。
