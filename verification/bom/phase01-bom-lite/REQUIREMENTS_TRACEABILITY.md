# Phase 1 BOM-Lite 需求追踪

状态：P1.1 已验收；P1.2 P1-R05—P1-R07 实现、生产生命周期门禁、全回归和最终审计全部通过；PR #10 与集成记录 PR #11 均已使用 merge commit 合并，PR #11 合并后全门禁再次 PASS，PR #12 纯文档收口独立复审 PASS 且无开放 finding

本表是 Phase 1 需求、计划例程和测试之间的权威映射。实现阶段不得把“已有代码”当作完成证据；只有对应测试通过并在 `TEST_RESULTS.md` 记录后，需求状态才能改为完成。

## 1. 需求—实现—测试矩阵

| ID | 需求 | 计划实现位置 | 验收测试 | 工作包 | 当前状态 |
|---|---|---|---|---|---|
| P1-R01 | `ALLOW_BOM`/`useBOM` 独立控制，关闭时零影响 | 已有核心挂接、`BOM_CHECK` | P1-C01、P1-Z01 | P1.1–P1.5 回归 | P1.1 回归通过，后续持续验证 |
| P1-R02 | 读取 schema 1 初始文件并拒绝损坏输入 | `BOM_INIT_VARIA`、`BOM_READ_INITIAL` | P1-S01、P1-N02 | P1.1 | P1.1 完成 |
| P1-R03 | 全局 64 位 ID 唯一且交换/I/O 不失真 | `BOM_ID_FROM_WORDS`、后续 pack/交换/pickup | P1-S02、P1-X04、P1-P02 | P1.1、P1.4、P1.5 | P1.1 初值恢复与唯一性完成；交换/I/O 待后续 |
| P1-R04 | 每 tile 权威 SoA、紧凑 owner 和容量安全 | `BOM.h`、`BOM_SIZE.h`、`BOM_READ_INITIAL`、后续 `BOM_CHECK_STATE` | P1-S03、P1-S04a、P1-N03a—N03b | P1.1、P1.4 | P1.1 状态/初值容量完成；运行/交换检查待后续 |
| P1-R05 | 支持规则 Cartesian 与未旋转 spherical-polar 映射 | `BOM_INIT_MAPPING`、`BOM_NORMALIZE_X`、`BOM_MAP_XY2IJLOCAL`、`BOM_MAP_IJLOCAL2XY`、兼容 `BOM_LOCATE_INITIAL` | P1-S03、P1-M01、P1-M02、P1-N04 | P1.1、P1.2 | 完成；19/19 门禁覆盖累计溢出、非有限原点/间距/末端 face 与正负极端有限经度 |
| P1-R06 | 表层 C-grid U/V 正确转为 C 点 east/north | `BOM_BUILD_FIELDS`、`bomGrid*` 单层数组 | P1-F01、P1-F02 | P1.2 | 完成；`Nr=2` 串行/MPI4 旋转、mask 和标量 halo 门禁及前序回归通过 |
| P1-R07 | 对湿点做一致的归一化双线性插值 | `BOM_INTERP_WET_PAIR`、`BOM_MAIN` 非移动诊断调用层 | P1-F03、P1-N05 | P1.2 | 完成；串行/MPI4 组件、生产生命周期和调用层异常终止门禁通过，权威粒子状态 bitwise 不变 |
| P1-R08 | LEEW 海流 RHS 使用 SI 且坐标率转换正确 | `BOM_RHS_LEEWAY` | P1-I01、P1-I02、P1-I03 | P1.3 | 未实现 |
| P1-R09 | 可选 EXF 风按独立经验系数叠加 | `BOM_BUILD_FIELDS`、`BOM_RHS_LEEWAY` | P1-I04、P1-N06 | P1.3 | 未实现 |
| P1-R10 | Stokes 在 Phase 1 固定关闭，误配置失败 | `BOM_READPARMS`、`BOM_CHECK` | P1-N07 | P1.1 | P1.1 完成 |
| P1-R11 | 固定子步、显式中点 RK2 和经典 RK4 | `BOM_MAIN`、`BOM_RK2`、`BOM_RK4` | P1-I05、P1-I06 | P1.3 | 未实现 |
| P1-R12 | 每个子步后完成唯一 owner tile/rank 迁移 | `BOM_PARTICLE_EXCHANGE`、`BOM_MAPPING` | P1-X01—P1-X04 | P1.4 | 未实现 |
| P1-R13 | 轨迹使用独立 schema/前缀并可按 ID 重组 | `BOM_OUTPUT` | P1-O01、P1-O02 | P1.5 | 未实现 |
| P1-R14 | 相同分解 pickup 连续/重启状态 bitwise 一致 | `BOM_READ_PICKUP`、`BOM_WRITE_PICKUP` | P1-P01、P1-P02 | P1.5 | 未实现 |
| P1-R15 | FLT 与 BOM 状态、例程、I/O 独立且可共存 | BOM namespace、核心调度 | P1-K01、P1-K02 | P1.5 | 部分骨架，待完整验证 |
| P1-R16 | 运行中检查有限数、CFL、owner 数和状态预算 | `BOM_CHECK_STATE`、`BOM_MAIN` | P1-N08、P1-X03、P1-G01 | P1.3–P1.5 | 未实现 |

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
