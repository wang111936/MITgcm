# MITGCM-BOM Phase 2 阶段记录

| 项目 | 当前值 |
|---|---|
| 阶段 | Phase 2：慢流形惯性物理 |
| 目标版本 | `MITGCM-BOM-v0.3` |
| 基线标签 | `MITGCM-BOM-v0.2` |
| 基线 tag object | `ab4317e5fe695fb0b2eb3be9b1ce91b39ba137f1` |
| 基线提交 | `1067c21d230e9c9619e89245b97c01e9474c7ed7` |
| 准入日期 | 2026-08-25 |
| 状态 | **进行中（P2.2 Cartesian 首增量已在 `f2c86ddf7` 通过精确门禁）** |
| 当前工作包 | P2.2 球面度量、协变算子和涡度 |
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
| P2.1 old/new 场 | 双时间层海流/风/Stokes 快照、时间插值和 pickup 状态 | 常值与时变场、mask/halo、restart | 完成（精确头 `41d0dbc20`；301/301） |
| P2.2 导数网格 | colocated 梯度、时间导数、涡度和球面度量 | B04、解析导数、坏度量负测 | 进行中（Cartesian 首增量 `f2c86ddf7`；D01--D03/Cartesian N05 PASS） |
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
- [x] P2.1 exact endpoints、时间插值、schema-2 field pickup 与全部前序回归通过；
- [ ] P2.0—P2.5 全部完成并顺序集成；
- [ ] B04、B05、B16 与 RK 收敛门禁通过；
- [ ] `PAPER2024`/`JULIA` 分量、Stokes 去重和单位/符号有直接证据；
- [ ] 1/2/4-rank、连续/restart 与全部 Phase 1/Phase 0 回归通过；
- [ ] Julia golden 从 provisional 升级或保留限制有新的明确裁决；
- [ ] 创建 `MITGCM-BOM-v0.3` 前完成独立退出审计。

## 7. 唯一下一任务

从 P2.2 Cartesian 精确功能头 `f2c86ddf7` 继续同一工作包，下一增量只实现：

- 未旋转 spherical-polar 的 `tauSphere=tan(latitude)/rSphere`，并验证
  `rSphere`、纬度、`cos(latitude)`、`tan(latitude)` 和 `fCori`；
- 在 stage-time 梯度插值后计算物质导数和
  `vort=dEast(wNorth)-dNorth(wEast)+tauSphere*wEast`；
- 建立 P2-D04、P2-D05 与剩余 spherical P2-N05 的 serial/MPI 门禁；
- 保持 Cartesian `tauSphere=0` 和当前 D01--D03/N05 结果无回归。

本增量不加入 P2.3 `PAPER2024`/`JULIA` RHS、粒子 stage 调度或 RK 接线。
P2-D01--D05、完整 P2-N05 和 accepted predecessor 回归全部通过前，不能
宣称 P2.2 关闭。

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
- GitHub 记录：Draft PR #20，base `MITGCM-BOM/development`，保持未合并；
- 实现范围：冻结参数、stable source/endpoint/failure/stage codes、accepted endpoint 零状态；
- 权威测试 ID：`p21-endpoint-920e22fbd-attempt01`；
- 结果：source contract、串行/MPI4 构建、BOM 串行/MPI4、LEEW compatibility 与 7 项负测共 13/13 PASS；
- summary SHA-256：`29453e3305d6d6a43bb8b055995417109644e3a53dbf5a5f93b38e1969440293`；
- 证据目录：`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state/p21-endpoint-920e22fbd-attempt01`；
- 边界：未实现 exact-time providers、transaction commit、时间插值、field pickup、导数或 RHS；
- 状态：P2.1 继续进行，无开放 finding，不创建 `MITGCM-BOM-v0.3`。

## 10. P2.1 事务端点增量记录

- 功能提交：`b81bb01293dbc4279db544174efe9558382115a3`；
- 实现 fresh 双端点、normal NEW→scratch OLD、exact ocean/NONE/NONE provider 与原子提交；
- 连续性或 source component 失败保持 accepted metadata、全部 fields 和 validity 完全不变；
- 生产生命周期覆盖 fresh 初始化和零粒子一步 normal advance；
- 权威测试 ID：`p21-transaction-b81bb0129-attempt01`；
- 结果：source、3 构建、串行/MPI4 transaction、production step、LEEW 与 7 项负测共 15/15 PASS；
- summary SHA-256：`7f6bd0426866908bd83a79ae29cf9c11a96940ff795a1e6fe8ceedf76ddd8ee5`；
- 证据目录：`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state/p21-transaction-b81bb0129-attempt01`；
- 边界：EXF、FILES/COUPLER、时间插值、field pickup、导数及 RHS 仍未实现；
- 状态：P2.1 继续进行，无开放 finding，不创建 `MITGCM-BOM-v0.3`。

## 11. P2.1 exact-time provider 增量记录

- EXF 功能提交：`43a79d1b14761cc355861e11b76a4d702c78cc80`，精确门禁 21/21 PASS；
- FILES Stokes 功能提交：`16ab457e321ba6751488e7dda861b25be1626252`，精确门禁 24/24 PASS；
- compiled COUPLER 功能提交：`6247ee6ba0fd1e796047bff944558c8e80c3511f`；
- COUPLER API 分 east/north 复制生产者 C-point geographic fields，独立保存 ready/time/iter，禁止 alias；
- missing、partial、stale、future、mixed-label、wrong-iteration、non-finite 和 dry-value 均返回 source failure，accepted bracket bitwise 不变；
- P2-E05 覆盖 EULERIAN+COUPLER 的 sigma 非零/零合法行、PRECOMBINED+NONE 合法行及 duplicate COUPLER 拒绝；
- 权威测试 ID：`p21-coupler-6247ee6ba-attempt01`；
- 结果：source contract、9 构建、14 正向/兼容运行和 8 负测，共 32/32 PASS；
- summary SHA-256：`87375f0d0003f240854e4c5738982c007b7b84e422d9d00c195933a2d7314dec`；
- 证据目录：`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state/p21-coupler-6247ee6ba-attempt01`；
- P2-R05 已由 exact-commit evidence 覆盖 NONE/FILES/COUPLER；P2-R06 的 endpoint policy matrix 已覆盖，H04 可审计 RHS 诊断留在 P2.3；
- 边界：stage-time interpolation 和 schema-2 field pickup 仍未实现，P2.1 不关闭；
- Draft PR #20 保持未 Ready、未合并，且未创建 `MITGCM-BOM-v0.3`。

## 12. P2.1 环境时间插值记录

- 功能提交：`83913ce594158f3c5e52907f56e5f69881ad9791`；
- 生产 `BOM_INTERP_ENV_TIME` 对 exact/tolerance endpoint 进行精确吸附，
  对区间内部线性插值并返回常值 OLD/NEW secant；
- fresh duplicated bracket 仅接受唯一端点并返回精确零时间导数；
- 非有限、反向、错误迭代连续性、未发布或区间外请求均返回 FIELD_TIME，
  输出候选无效且 accepted bracket bitwise 不变；
- 权威门禁 `p21-envtime-83913ce59-attempt02` 为 34/34 PASS；
- P2-E06/P2-N02 与 P2-R07 的 field-value 部分关闭。

## 13. P2.1 schema-2 pickup 与工作包收口

- 生产主提交：`df67380a803a7c675ee8c4456f693ecbbd88a022`；
- P1.4 尺寸覆盖兼容提交：`c603fc706`；P1.1 稳定诊断兼容提交：
  `41d0dbc20404df1759a7a5d1b274bc85d5c415fd`；
- schema 2 精确指纹覆盖模式、方程/current/source policy、SI 参数、调度、
  forcing、endpoint metadata、分解与 compiled capability；
- 每个全局 tile 的 sidecar 保存 OLD/NEW Eulerian、wind、Stokes、validity
  与 exact labels；全部 signature、sidecar 和 particle tile 先在 scratch
  预检，之后只提交一次；
- LEEW 保持 schema-1 128-byte signature、原粒子布局且不写 sidecar；
  schema-1-to-BOM、参数指纹变化与损坏 sidecar 均在提交前拒绝；
- nonzero FILES Stokes 连续/分段运行的 step-2 全部 BOM pickup 文件
  SHA-256 完全相同；串行和 MPI4 schema-2 写读均通过；
- 空间导数不写入 schema 2，将由 P2.2 从已恢复端点确定性重建；当前
  coupler API 没有稳定 runtime producer ID，因此指纹记录 source 与
  compiled capability；未来增加 provider ID 必须升级 schema；
- 精确功能头 `41d0dbc20` 上 pickup 10/10、endpoint/provider 34/34、
  Phase-1/Phase-0 15 组 257/257，聚合 301/301 PASS；
- 聚合证据：`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/`
  `p21-closure/p21-closure-41d0dbc20-attempt02`；
- row audit SHA-256：
  `7b15d0540f5d1228760e93e879ce8e8b9b45d47a0307865ebd4d55a1fa442559`；
- aggregate manifest SHA-256：
  `423c679704876f68a4962f56c43bfe02f66a38f6088ef4914228170d61774d9c`；
- P2.1 状态为完成；P2.2 成为唯一下一工作包。Draft PR #20 仍未合并，
  未创建 `MITGCM-BOM-v0.3`。

## 14. P2.2 Cartesian derivative 首增量记录

- 精确功能提交：`f2c86ddf73d2f0b8dc470ad6abcac68a48accaef`；
- 在 accepted OLD/NEW east/north C 点场上构造四个空间梯度，使用非均匀
  三点二阶 centered 或允许的一侧公式，所有分量共享全湿、可用且有限的
  stencil；不可用点保持 invalid，禁止跨陆地取值或无效零填充；
- derivative scratch 与环境 endpoint 在同一发布路径提交，失败时撤回环境
  和梯度 readiness，accepted arrays/masks 保持不变；schema-2 仍只保存主
  endpoint，读取后从恢复端点确定性重建导数；
- `BOM_INTERP_ENV_DERIVATIVES` 复用权威 bracket 校验，并在 exact endpoint、
  fresh bracket 和区间内部提供相同的 snap/linear 语义；非线性协变项尚未
  在此例程中计算；
- 精确导数门禁 ID：`p22-derivative-f2c86ddf7-attempt01`，串行/MPI4 构建、
  P2-D01、P2-D02、Cartesian P2-N05 和 P2-D03 共 9/9 PASS；
- 证据目录：`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/`
  `p22-derivatives/p22-derivative-f2c86ddf7-attempt01`；summary SHA-256 为
  `a8ba156e5394634fb699b07ef7c83c6677696c11ae21a76ad7880d5ecd8afc8c`，
  `SHA256SUMS` 文件 SHA-256 为
  `b4500dfb6d2e8858bb68347c072ec0b3776131c1312d9077e2364c47469efe65`；
- 同一精确头的 schema-2 pickup 回归 `p22-pickup-f2c86ddf7-attempt01`
  为 10/10 PASS；summary SHA-256 为
  `90f92e9ef047433f47f53d993a2a4392258668df3551fc74c17e3ad5db29e132`；
- P2-D02 明确校正为：二次场验证 roundoff exactness，三次 manufactured
  field 才用于产生非零截断误差并判定二阶收敛；这不扩展生产范围；
- P2.2 尚未关闭；下一增量为 spherical `tauSphere`、`fCori`、协变 material
  derivative、vorticity 和 P2-D04/D05/spherical N05；
- 本地分支尚未推送，Draft PR #20 仍属于 P2.1，未创建 v0.3 tag。
