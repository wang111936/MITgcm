# MITGCM-BOM Phase 3 阶段记录

| 项目 | 当前值 |
|---|---|
| 阶段 | Phase 3：非线性弹簧和分布式邻居 |
| 目标版本 | `MITGCM-BOM-v0.4` |
| 基线标签 | `MITGCM-BOM-v0.3` |
| 基线 tag object | `9360a06d0379051aced0601b25aa814dda6330fb` |
| 基线提交 | `332a406e958e5005f60267c187fada1f74319fc3` |
| 准入日期 | 2026-08-27 |
| 状态 | **进行中：P3.0 完成，Draft PR #26 等待明确合并授权；P3.1 未开始** |
| 当前工作包 | P3.0 设计、接口与测试冻结（完成） |
| 当前分支 | `MITGCM-BOM/p3.0-interface-freeze` |
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
| P3.1 参考与定律 | 参数/代码、canonical geometry、外部 KNN oracle、Hooke/eBOMB kernels | P3-C01/K01/D01、B07/B08、N03/N05 | 未开始 |
| P3.2 邻居生产路径 | cell geometry/list、exact cutoff local graph、容量事务 | P3-N01/N02、L01/L02、N10 | 未开始 |
| P3.3 分布式积分 | ghost、ensemble RK、全局 rollback、迁移扩展 | G01/G02、I01--I03、B09/B17、M01 | 未开始 |
| P3.4 raft 与 schema 3 | FINAL components、raft diagnostics、sidecar/pickup | RF01/RF02、P01--P04、restart | 未开始 |
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
- [ ] P3.1--P3.5 全部完成并按顺序集成；
- [ ] B07--B09、B17、负向、restart 和 1/2/4-rank 门禁通过；
- [ ] 跨 rank 内力与小规模 gather oracle 一致；
- [ ] 生产邻居调用图没有全局 all-particle 或无条件 O(N-squared) 路径；
- [ ] 固定密度 work/communication counter 门禁通过；
- [ ] Phase 0--Phase 2 全部适用回归通过；
- [ ] 独立 Phase 3 退出审计无开放 finding；
- [ ] 仅在最终集成和退出审计后创建 annotated tag `MITGCM-BOM-v0.4`。

## 8. 唯一下一任务

复核 Draft PR #26 并等待明确合并授权；只能使用 merge commit，且不得
提前创建 `MITGCM-BOM-v0.4`。P3.0 集成后，P3.1 才能开始参数/稳定代码、
canonical pair geometry、verification-only KNN oracle 和 stateless
spring laws。

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
  `draft=true`、`mergeable=true`、9 个 Markdown、ahead 2/behind 0；
  未经用户明确授权保持未合并。
