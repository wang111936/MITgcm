# Phase 1 BOM-Lite 需求追踪

状态：P1.1—P1.5 生产实现及原阶段门禁完成；原 P1-G01 255/255 PASS；PR #13/#14 已顺序集成，新增球面 RK2/RK4 两项后，同步头 P1.5 专属 62 项、前序 195 项及 P1-G01 257 项精确头复验待执行；独立 Ready 复审仍保留

本表是 Phase 1 需求、计划例程和测试之间的权威映射。实现阶段不得把“已有代码”当作完成证据；只有对应测试通过并在 `TEST_RESULTS.md` 记录后，需求状态才能改为完成。

## 1. 需求—实现—测试矩阵

| ID | 需求 | 计划实现位置 | 验收测试 | 工作包 | 当前状态 |
|---|---|---|---|---|---|
| P1-R01 | `ALLOW_BOM`/`useBOM` 独立控制，关闭时零影响且启动参数安全 | 已有核心挂接、`BOM_CHECK` | P1-C01、P1-Z01、P1-N01b | P1.1–P1.5 回归 | 完成；P1.5 四组合共存、关闭输出、P1.1 零影响及全部前序矩阵通过 |
| P1-R02 | 读取 schema 1 初始文件并拒绝损坏输入 | `BOM_INIT_VARIA`、`BOM_READ_INITIAL` | P1-S01、P1-N02 | P1.1 | P1.1 完成 |
| P1-R03 | 全局 64 位 ID 唯一且交换/I/O 不失真 | `BOM_ID_FROM_WORDS`、后续 pack/交换/pickup | P1-S02、P1-X04、P1-P02 | P1.1、P1.4、P1.5 | 完成；初值、MPI 交换、轨迹和 pickup 均用两字精确恢复，大于 `2^53` 的 ID 及重复 ID 负测通过 |
| P1-R04 | 每 tile 权威 SoA、紧凑 owner 和容量安全 | `BOM.h`、`BOM_SIZE.h`、`BOM_READ_INITIAL`、`bomNPartExpected`、`BOM_CHECK_STATE` | P1-S03、P1-S04a、P1-N03a—N03b、P1-N08 | P1.1、P1.3、P1.4 | P1.1 初值容量、P1.3 完整状态预算、P1.4 发送/接收/目标 tile 预检与事务提交全部完成 |
| P1-R05 | 支持规则 Cartesian 与未旋转 spherical-polar 映射 | `BOM_INIT_MAPPING`、`BOM_NORMALIZE_X`、`BOM_MAP_XY2IJLOCAL`、`BOM_MAP_IJLOCAL2XY`、兼容 `BOM_LOCATE_INITIAL` | P1-S03、P1-M01、P1-M02、P1-N04 | P1.1、P1.2 | 完成；19/19 门禁覆盖累计溢出、非有限原点/间距/末端 face 与正负极端有限经度 |
| P1-R06 | 表层 C-grid U/V 正确转为 C 点 east/north | `BOM_BUILD_FIELDS`、`bomGrid*` 单层数组 | P1-F01、P1-F02 | P1.2 | 完成；`Nr=2` 串行/MPI4 旋转、mask 和标量 halo 门禁及前序回归通过 |
| P1-R07 | 对湿点做一致的归一化双线性插值 | `BOM_INTERP_WET_PAIR`、`BOM_MAIN` 非移动诊断调用层 | P1-F03、P1-N05 | P1.2 | 完成；串行/MPI4 组件、生产生命周期和调用层异常终止门禁通过，权威粒子状态 bitwise 不变 |
| P1-R08 | LEEW 海流 RHS 使用 SI 且坐标率转换正确 | `BOM_RHS_LEEWAY` | P1-I01、P1-I02、P1-I03 | P1.3 | 完成；Cartesian 与非零纬度 spherical-polar 的 RK2/RK4 解析位移、零场调用方及坐标率均通过 |
| P1-R09 | 可选 EXF 风按独立经验系数叠加 | `BOM_CHECK`、`BOM_BUILD_FIELDS`、`bomGridWind*`、`BOM_RHS_LEEWAY` | P1-I04、P1-N06 | P1.3 | 完成；source/依赖矩阵、冻结风场与 EXF→field→RHS 串行/MPI4 端到端门禁通过 |
| P1-R10 | Stokes 在 Phase 1 固定关闭，误配置失败 | `BOM_READPARMS`、`BOM_CHECK` | P1-N07 | P1.1 | P1.1 完成 |
| P1-R11 | 固定子步、显式中点 RK2 和经典 RK4 | `BOM_MAIN`、`BOM_RK2`、`BOM_RK4` | P1-S04b、P1-I05、P1-I06 | P1.3 | 完成；等长子步、精确 release 分割、生产事务调用、P1-I05 1.9885/1.9942 与 P1-I06 3.9858/3.9931 均通过 |
| P1-R12 | 每个子步后完成唯一 owner tile/rank 迁移 | `BOM_PARTICLE_EXCHANGE`、`BOM_LOCATE_OWNER` | P1-X01—P1-X04 | P1.4 | 完成；同 rank/MPI2/MPI4、周期 X、多子步、大 ID、容量与 hop 门禁 36/36 通过 |
| P1-R13 | 轨迹使用独立 schema/前缀并可按 ID 重组 | `BOM_OUTPUT`、`BOM_WRITE_TRAJECTORY` | P1-O01、P1-O02 | P1.5 | 完成；24-field schema、双字 ID、迁移后 serial/MPI4、关闭输出和 150/60 非整除调度门禁通过 |
| P1-R14 | 相同分解 pickup 连续/重启状态 bitwise 一致 | `BOM_READ_PICKUP`、`BOM_WRITE_PICKUP` | P1-P01、P1-P02、P1-P03 | P1.5 | 完成；核心 suffix、1/2/4 ranks 5+3 restart、事务 scratch、调度恢复和改变分解早期拒绝通过 |
| P1-R15 | FLT 与 BOM 状态、例程、I/O 独立且可共存 | BOM namespace、核心调度 | P1-K01、P1-K02 | P1.5 | 完成；serial/MPI2 四组合及核心、FLT、BOM 双向不变性 25/25 通过 |
| P1-R16 | 运行中检查有限数、CFL、owner 数和状态预算 | `BOM_RHS_LEEWAY`、`BOM_CHECK_STATE`、`BOM_MAIN` | P1-N08、P1-X03、P1-G01 | P1.3–P1.5 | 原 P1-G01 255/255 通过；纳入两项球面 RK 门禁后的同步头 257 项复验待执行 |

### P1.1 反向追踪

| 生产例程/接口 | 需求 | 已执行测试 |
|---|---|---|
| `BOM.h`、`BOM_SIZE.h` | P1-R04 | P1-C03、P1-S01、P1-N03a |
| `BOM_INIT_STATE` | P1-R04 | P1-S01、P1-S04a |
| `BOM_ID_FROM_WORDS` | P1-R03 | P1-S02、重复/坏 ID 负测 |
| `BOM_LOCATE_INITIAL` | P1-R02、P1-R04、P1-R05 的受限初值部分 | P1-S03、域外负测 |
| `BOM_READ_INITIAL` | P1-R02—P1-R04 | P1-S01—S03、P1-S04a、P1-N02、P1-N03a |
| `BOM_READPARMS`、`BOM_CHECK` | P1-R01、P1-R10 | P1-N01、P1-N07、Phase 0 回归 |

权威执行证据见 [`TEST_RESULTS.md`](TEST_RESULTS.md)。P1.1 没有实现或宣称完成环境场、stage-time 映射、粒子运动、release 转换、交换、轨迹或 pickup。

### P1.2 分阶段反向追踪

| 生产例程/接口 | 需求 | 当前证据 |
|---|---|---|
| `BOM_INIT_MAPPING`、`BOM_NORMALIZE_X` | P1-R05 | P1-M02、P1-N04 及新增非有限/溢出几何和极端有限周期输入门禁 19/19 通过 |
| `BOM_MAP_XY2IJLOCAL`、`BOM_MAP_IJLOCAL2XY` | P1-R05 | P1-M01、P1-M02、P1-N04 已通过 |
| `BOM_LOCATE_INITIAL` 兼容包装 | P1-R02、P1-R04、P1-R05 | 包装源审计、P1-S03、完整 P1.1 与 Phase 0 回归已通过 |
| `BOM_BUILD_FIELDS`、`bomGridUWork/bomGridVWork` | P1-R06 | P1-F01、P1-F02 与多层步长探针已通过 |
| `bomGridVEast/bomGridVNorth`、标量 halo exchange | P1-R06 | P1-F01、P1-F02 串行/MPI4 及 Phase 0 零影响回归已通过 |
| `BOM_INTERP_WET_PAIR` | P1-R07 | 组件级 P1-F03/P1-N05 串行/MPI4 及低湿权重生产调用层门禁通过 |
| `BOM_MAIN` 非移动诊断调用层 | P1-R07 | 串行/MPI4 正向生命周期门禁证明只更新诊断字段；域外/低湿权重负测证明带上下文的集体终止 |

详细调用契约见 [`P1.2_INTERFACE_FREEZE.md`](P1.2_INTERFACE_FREEZE.md)，最终复审结论见 [`P1.2_SCOPE_AUDIT.md`](P1.2_SCOPE_AUDIT.md)，合并后收口证据见 [`P1.2_CLOSEOUT.md`](P1.2_CLOSEOUT.md)。映射、字段构造和插值/生命周期证据分别见 [`../phase01-mapping/TEST_RESULTS.md`](../phase01-mapping/TEST_RESULTS.md)、[`../phase01-fields/TEST_RESULTS.md`](../phase01-fields/TEST_RESULTS.md) 和 [`../phase01-interp/TEST_RESULTS.md`](../phase01-interp/TEST_RESULTS.md)。P1-R05—P1-R07 均已关闭，P1.2 最终审计及两次合并后回归均为 PASS。

### P1.3 分增量反向追踪

| 生产例程/接口 | 需求 | 当前证据/冻结验收 |
|---|---|---|
| `BOM_CHECK` 的数值 preflight 与 EXF 依赖矩阵 | P1-R01、P1-R09、P1-R11、P1-R16 | 首增量完成；P1-N01b/P1-N06 的有限 target/系数/CFL、可表示子步和 EXF source/依赖组合门禁通过 |
| `bomGridWindEast/bomGridWindNorth`、扩展 `BOM_BUILD_FIELDS` | P1-R09 | 首增量完成冻结、mask、标量 halo、时间标签和有限性组件证据；第二增量中与 RHS 组成同次 EXF 端到端门禁 |
| `BOM_RHS_LEEWAY` | P1-R08、P1-R09、P1-R16 | 第二增量完成；P1-I01—I04 串行/MPI4、Cartesian/球面坐标率、EXF Leeway、半格 tie、stage CFL 和 P1-N08 RHS 失败类别 15/15 通过 |
| `BOM_RK_COORD_UPDATE`、`BOM_RK2` | P1-R08、P1-R11、P1-R16 | 12/12 门禁覆盖球面 P1-I03、K1/K2/FINAL、零场、Cartesian 解析位移、P1-I05 二阶收敛和阶段回滚 |
| `BOM_RK4`、`BOM_RK4_COORD_UPDATE` | P1-R08、P1-R11、P1-R16 | 12/12 门禁覆盖球面 P1-I03、K1--K4/FINAL、极值安全加权、P1-I06 四阶收敛和逐 stage 回滚 |
| `BOM_MAIN` 的等长子步和 release 状态机 | P1-R11、P1-R16 | 完成；P1-N01b、P1-S04b、P1-I01、P1-N08 覆盖安全子步、精确 release 分割、候选 age 与事务提交 |
| `bomNPartExpected`、`BOM_CHECK_STATE` | P1-R04、P1-R16 | 完成；P1-N08 覆盖紧凑槽、全局 owner/ID/status/release/age 预算与集体诊断 |

详细契约见 [`P1.3_INTERFACE_FREEZE.md`](P1.3_INTERFACE_FREEZE.md)。setup、RHS、RK2 和 RK4 增量证据分别见对应验证目录；生产 release/事务/state-budget 证据见 [`../phase01-lifecycle/TEST_RESULTS.md`](../phase01-lifecycle/TEST_RESULTS.md)，最终结论见 [`P1.3_SCOPE_AUDIT.md`](P1.3_SCOPE_AUDIT.md)。Ready remediation 补齐两项球面 RK 门禁，PR #13 已完成复审并以 `41fb0938` 集成。

### P1.4 反向追踪

| 生产例程/接口 | 需求 | 当前证据 |
|---|---|---|
| `BOM_LOCATE_OWNER` | P1-R05、P1-R12 | 二分全局 face、半开 owner、周期 X、真实 rank 起点及 direct Chebyshev hop 的 P1-X01—X03 门禁 |
| `BOM_RHS_LEEWAY_HALO`、`BOM_RK2_MIGRATE`、`BOM_RK4_MIGRATE` | P1-R08、P1-R11、P1-R16 | K1 owner、K2—FINAL halo stencil、CFL 与精确回滚；serial/MPI2/MPI4 正向及 stencil 负测 |
| `BOM_PARTICLE_EXCHANGE` | P1-R03、P1-R04、P1-R12、P1-R16 | 两个 Alltoallv、两字 64 位 ID、SEND/RECV/tile 容量预检、确定性排序及无部分提交；36/36 PASS |
| `BOM_MAIN` 的每子步迁移调用 | P1-R11、P1-R12 | P1-X03 连续 16 子步逐步 hop，serial/MPI4 最终状态 bitwise 一致 |

权威接口见 [`P1.4_INTERFACE_FREEZE.md`](P1.4_INTERFACE_FREEZE.md)，执行证据见 [`../phase01-owner-migration/TEST_RESULTS.md`](../phase01-owner-migration/TEST_RESULTS.md)，最终审计见 [`P1.4_SCOPE_AUDIT.md`](P1.4_SCOPE_AUDIT.md)。同步头 owner 36/36、RK2 12/12、RK4 12/12 通过，PR #14 已以 `9d258da4` 集成。

### P1.5 反向追踪

| 生产例程/接口 | 需求 | 当前证据 |
|---|---|---|
| `BOM_INIT_OUTPUT_SCHEDULE`、`BOM_OUTPUT`、`BOM_WRITE_TRAJECTORY` | P1-R13、P1-R16 | P1-O01/O02 与真实迁移门禁：24-field schema、非整除频率、无重复 `(time,id)`，25+12 项通过 |
| `BOM_WRITE_PICKUP`、`BOM_READ_PICKUP` | P1-R03、P1-R14、P1-R16 | P1-P01—P03：核心 suffix、双字 ID、1/2/4 ranks 相同分解 bitwise、改变分解早期拒绝通过 |
| `DO_THE_MODEL_IO`、`PACKAGES_WRITE_PICKUP` 的独立 BOM 分支 | P1-R13—P1-R15 | P1-K01/K02：neither/FLT/BOM/both 串行/MPI2 构建运行与双向文件/状态不变性 25/25 通过 |

权威设计见 [`P1.5_INTERFACE_FREEZE.md`](P1.5_INTERFACE_FREEZE.md)，源码架构审计见 [`P1.5_DESIGN_AUDIT.md`](P1.5_DESIGN_AUDIT.md)，执行证据见 [`../phase01-output-pickup-coexistence/TEST_RESULTS.md`](../phase01-output-pickup-coexistence/TEST_RESULTS.md)，最终结论见 [`P1.5_SCOPE_AUDIT.md`](P1.5_SCOPE_AUDIT.md)。

## 2. 上层验证编号映射

| 开发手册测试 | Phase 1 具体测试 | 说明 |
|---|---|---|
| B01 零环境场 | P1-I01 | 活粒子位置不变，WAITING 粒子不误判死亡 |
| B02 均匀海流 | P1-I02、P1-I03 | Cartesian 和 spherical-polar 解析位移 |
| B03 风和 Stokes 组合 | P1-I04、P1-N07 | Phase 1 只验海流+风；Stokes 必须被拒绝 |
| B06 RK 收敛 | P1-I05、P1-I06 | RK2 二阶、RK4 四阶 |
| B10 粒子跨 tile | P1-X01—P1-X04 | owner 唯一、位置连续、ID 无损 |
| B15 Pickup | P1-P01、P1-P02 | 相同分解逐字段 bitwise 一致 |

## 3. 反向追踪规则

- 每个新增 `BOM_` 生产例程必须在本表至少对应一个需求；
- 每个测试必须在 `TEST_PLAN.md` 标明至少一个需求 ID；
- 若需求拆分或编号变更，旧编号保留为 deprecated 记录，不能静默复用；
- P1.5 集成审计使用 `rg` 生成“例程—需求—测试”清单，与本表比较；
- `TEST_RESULTS.md` 只记录实际执行证据，不把计划状态写成通过。
