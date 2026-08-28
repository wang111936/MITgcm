# MITGCM-BOM Phase 3 阶段记录

| 项目 | 当前值 |
|---|---|
| 阶段 | Phase 3：非线性弹簧和分布式邻居 |
| 目标版本 | `MITGCM-BOM-v0.4` |
| 基线标签 | `MITGCM-BOM-v0.3` |
| 基线 tag object | `9360a06d0379051aced0601b25aa814dda6330fb` |
| 基线提交 | `332a406e958e5005f60267c187fada1f74319fc3` |
| 准入日期 | 2026-08-27；P3.3 集成、P3.4 功能完成日期 2026-08-28 |
| 状态 | **进行中：P3.0--P3.3 已集成；P3.4 功能完成，最终干净头证据待记录** |
| 当前工作包 | P3.4 FINAL components、raft diagnostics 与 schema 3（功能完成） |
| 当前分支 | `MITGCM-BOM/p3.4-components-schema3` |
| 作者身份 | `WangYuLin <wang111936@outlook.com>` |

## 1. 准入裁决

Phase 3 的全部前置条件已经满足：Phase 2 的 P2.0--P2.5 已顺序完成并
集成，最终集成门禁为 390/390 PASS，独立退出审计无开放 finding，且
annotated tag `MITGCM-BOM-v0.3` 已发布并 peel 到
`332a406e958e5005f60267c187fada1f74319fc3`。

P3.0 是文档冻结工作包。它必须先关闭参考差异、生产算法、MPI 所有权、
事务语义、磁盘 schema、确定性和测试门禁，不能提前加入生产 Fortran、
测试驱动、算例输入或生成证据。

## 2. 阶段目标与边界

Phase 3 在已验收的慢流形 BOM 粒子积分上增加：

- 小规模 K 近邻参考实现和确定性自然长度；
- 无全局 all-particle 生产路径的 cutoff cell-linked-list；
- 一阶段、只读、事务式 MPI ghost exchange；
- SI 单位 Hooke 与 overflow-safe eBOMB 弹簧速度；
- 与耦合弹簧相容的 ensemble RK stage transaction 和全局 rollback；
- FINAL cutoff 图上的确定性连通分量/raft 诊断；
- schema 3 sidecar、B07--B09、B17 与本地固定密度性能门禁。

Phase 3 不包括温度/营养盐、生长繁殖死亡、搁浅、随机事件、OpenMP
加固、目标服务器 100k/256-rank 性能或 EXCH2/LLC。它们分别保留给
Phase 4--Phase 6。

## 3. P3.0 冻结交付

P3.0 的权威文档位于
`verification/bom/phase03-springs-neighbors/`：

- `P3.0_SOURCE_AUDIT.md`：锁定 Julia 和 v0.3 源码事实、差异与处理；
- `P3.0_INTERFACE_FREEZE.md`：参数、几何、图、ghost、弹簧、RK、raft、
  schema、错误码和性能边界；
- `REQUIREMENTS_TRACEABILITY.md`：P3-R01--P3-R18 正向/反向追踪；
- `TEST_PLAN.md`：B07--B09、B17、负向、分解、重启和性能门禁；
- `P3.0_DESIGN_AUDIT.md`：冻结提交形成后记录独立文档/范围审计。

冻结候选包含 18 条需求和 22 项设计决定。任何实现中发现的新问题都必须
登记为 finding/risk，并明确阻塞工作包、解决提交和复验范围；不得静默
改变冻结默认值。

## 4. 分工作包方案

| 工作包 | 交付 | 主要验收 | 当前状态 |
|---|---|---|---|
| P3.0 设计冻结 | 源码审计、需求、接口、MPI/事务/schema、测试和性能契约 | 18 需求、22 决定、编号/链接/范围审计 | 完成：冻结头 `e81ddaa52`；12/12 PASS |
| P3.1 参考与定律 | 参数/代码、canonical geometry、外部 KNN oracle、Hooke/eBOMB kernels | P3-C01/K01/D01、B07/B08、N03/N05 | 已由 PR #27 集成；P3.3 头复验 34/34 |
| P3.2 邻居生产路径 | cell geometry/list、exact cutoff local graph、容量事务 | P3-N01/N02、L01/L02、N10 | 已由 PR #28 集成；P3.3 头复验 18/18 |
| P3.3 分布式积分 | ghost、ensemble RK、全局 rollback、迁移扩展 | G01/G02、I01--I03、B09/B17、M01 | 已由 PR #29 以 merge commit 集成 |
| P3.4 raft 与 schema 3 | FINAL components、raft diagnostics、sidecar/pickup | RF01/RF02、P01--P04、restart | 功能完成；开发矩阵通过，最终干净头证据待记录 |
| P3.5 性能与收口 | 结构复杂度、固定密度基线、全回归、退出审计 | X01/X02、P3-G99、v0.4 决策 | 未开始 |

工作包必须按 P3.0--P3.5 的依赖顺序关闭。允许在工作包内部拆分小增量，
但每个包必须在精确提交上通过自身门禁和全部适用前序回归。

## 5. 冻结的关键裁决

1. K 表示 K 个非自身邻居，并以 `(distance, globalId)` 打破距离并列；
2. KNN/all-pairs 仅作小规模 verification oracle，不链接到生产邻居路径；
3. 生产边使用精确 `distance <= cutoff`、无自边/重复边和 ID 排序；
4. canonical pair 从低 ID 指向高 ID，周期 X 使用最短位移；
5. 零长度或不可解析 pair 失败关闭，禁止静默跳过；
6. ghost 与 owner migration 独立，只读且仅存活一个 stage；
7. 两端 owner 各自计算本地粒子的 pair 贡献，不发送反向力消息；
8. 弹簧项是乘以 `tau` 的 SI 速度贡献，`k/A` 为 `s^-2`；
9. 开启弹簧后，RK 对全部 owner/rank 是同步 ensemble transaction；
10. 每个 RK stage 和 FINAL 都重建图，Verlet skin 后置；
11. owner 只在完整子步提交后迁移；
12. raft ID 是 FINAL cutoff 连通分量中的最小全局粒子 ID；
13. schema 3 保留 schema-2 核心宽度，增加固定 8 字段 sidecar；
14. 复杂度以生产调用图和计数器证明，计时只能作为辅助证据。

完整 P3-D001--P3-D022 见 `P3.0_INTERFACE_FREEZE.md`。

## 6. 风险与后置条件

| ID | 风险/限制 | 当前处理 |
|---|---|---|
| P3-RISK-01 | v0.3 RK 是逐粒子事务，不能安全直接叠加耦合弹簧 | P3.3 新增同步 ensemble scratch transaction |
| P3-RISK-02 | 密集病态单元可能产生二次 candidate 数 | P3.2 容量失败关闭；P3.5 以固定密度计数门禁，不虚报最坏情形 |
| P3-RISK-03 | 跨 rank 累加顺序可能破坏位级确定性 | canonical pair/ID 排序并由 B17 直接裁决 |
| P3-RISK-04 | ghost/component 容量或通信错误可能部分发布 | 独立 scratch、collective verdict 和全局 rollback |
| P3-RISK-05 | schema 3 损坏或参数不匹配可能污染 accepted state | 全部 sidecar/指纹先验证，随后单次提交 |
| P3-RISK-06 | 目标 HPC 编译器、调度器和网络尚未指定 | Phase 3 关闭本地结构/固定密度门禁；站点规模由 Phase 5 接管 |

## 7. Phase 3 总退出条件

- [x] Phase 2 最终 390/390 和 `MITGCM-BOM-v0.3` 准入已核验；
- [x] P3.0 设计、接口、需求和测试冻结通过独立审计；
- [ ] P3.1--P3.5 全部完成并按顺序集成（P3.1--P3.3 已集成，P3.4 功能完成）；
- [ ] B07--B09、B17、负向、restart 和 1/2/4-rank 门禁通过；
- [ ] 跨 rank 内力与小规模 gather oracle 一致；
- [ ] 生产邻居调用图没有全局 all-particle 或无条件 O(N-squared) 路径；
- [ ] 固定密度 work/communication counter 门禁通过；
- [ ] Phase 0--Phase 2 全部适用回归通过；
- [ ] 独立 Phase 3 退出审计无开放 finding；
- [ ] 仅在最终集成和退出审计后创建 annotated tag `MITGCM-BOM-v0.4`。

## 8. 唯一下一任务

在精确的 P3.4 功能提交上运行 42/42 直接门禁和已接受的 P3.3、P3.2、
P3.1、Phase 2 前序回归，记录仓库外证据根和 manifest；随后仅完成
P3.4 本地关闭记录。未经用户明确授权不推送、不创建 PR、不合并，且不
创建 `MITGCM-BOM-v0.4`。P3.5 仍是下一独立工作包。

## 9. P3.0 完成记录

- 冻结提交：`e81ddaa521e5f3babe54ba0ac8964c3dae058f88`；tree：
  `1f7c78b4660d1211a787af52b2d863d038ced480`；
- 变更范围：8 个 Markdown，1410 insertions、12 deletions；生产 Fortran、
  测试脚本、算例输入、锁定数据和生成证据变化为零；
- 精确提交审计：changed-path allowlist、Markdown-only、diff whitespace、
  禁用词、18 requirements、22 decisions、10 source findings、测试标识、
  核心契约、相对链接和 v0.3 tag/base 共 12/12 PASS；
- Julia 锁定提交和五个 source/environment SHA-256 与源码审计表一致；
- 设计审计见 `verification/bom/phase03-springs-neighbors/`
  `P3.0_DESIGN_AUDIT.md`；
- P3.0 无开放 design/scope finding；P3.1--P3.5 的实现与运行门禁仍全部
  未开始，不能由本次文档审计代替。
- GitHub Draft PR #26 以 `MITGCM-BOM/development` 为 base；远端复审为
  `draft=true`、`mergeable=true`、9 个 Markdown、behind 0；
  未经用户明确授权保持未合并。

## 10. P3.1--P3.4 进展记录

- P3.1 已由 PR #27 以 merge commit
  `7c146974e0133083f23ee7014dc5f1bac13dcf39` 集成；
- P3.2 已由 PR #28 以 merge commit
  `3d01b638731c15e88a9b3945fe0f18368a96b231` 集成；
- P3.3 生产与完整 Phase 2 前序功能头为
  `53f9670ee97e7b793f4a1ac164f46c1ce30c1abf`，390/390 PASS；
- P3.3 统一直接验证头为
  `9b9ea50df28a5ce1e405b903d78fe6dbc9120eb0`：P3.3 34/34、
  P3.2 18/18、P3.1 34/34 全部 PASS；
- 已实现 version-1 ghost packet、同步 ensemble RK2/RK4、组合 RHS/CFL、
  全局 rollback 和 post-commit migration packet schema 2；
- B17 的 P3.3 动力学记录在 serial/MPI2/MPI4 间按 exact ID 位一致；
- P3.4 前的 P3.3 分支已批量推送，PR #29 已按用户授权转为 Ready，并以
  merge commit `be87475712f0084c5acc1a342ebc97172ccdaf82` 集成；
- P3.3 与 P3.0 冻结计划一致，无公式、容差、图定义或接口决策修订；
- 从 P3.3 集成提交创建
  `MITGCM-BOM/p3.4-components-schema3`，实现 FINAL cutoff 图分布式
  最小标签连通分量、exact raft ID/size 和 transactional candidate
  rollback；
- schema 3 保持 schema-2 48/45-field core 和 Phase-2 指纹不变，新增
  8-field P3 sidecar/P3 signature，并在 pickup 单次 commit 前重建和验证
  FINAL graph、spring、neighbor 和 raft；
- 开发阶段组件矩阵、Hooke/eBOMB 串行/MPI2/MPI4 写出/重启/位比较及
  14 项 corruption matrix 均通过；最终干净提交和完整前序回归待记录；
- P3.5 的性能、P3-G99 和 Phase 3 退出审计仍未开始；没有修改 SKRIPS
  文件，没有推送 P3.4 分支，也没有创建 `MITGCM-BOM-v0.4` 标签。
