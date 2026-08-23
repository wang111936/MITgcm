# Phase 1 BOM-Lite 需求追踪

状态：P1.0 设计基线

本表是 Phase 1 需求、计划例程和测试之间的权威映射。实现阶段不得把“已有代码”当作完成证据；只有对应测试通过并在 `TEST_RESULTS.md` 记录后，需求状态才能改为完成。

## 1. 需求—实现—测试矩阵

| ID | 需求 | 计划实现位置 | 验收测试 | 工作包 | 当前状态 |
|---|---|---|---|---|---|
| P1-R01 | `ALLOW_BOM`/`useBOM` 独立控制，关闭时零影响 | 已有核心挂接、`BOM_CHECK` | P1-C01、P1-Z01 | P1.1–P1.5 回归 | 已有骨架，待持续验证 |
| P1-R02 | 读取 schema 1 初始文件并拒绝损坏输入 | `BOM_INIT_VARIA`、`BOM_READ_INITIAL` | P1-S01、P1-N02 | P1.1 | 未实现 |
| P1-R03 | 全局 64 位 ID 唯一且交换/I/O 不失真 | `BOM_ID_PACK/UNPACK`、初始化与交换 | P1-S02、P1-X04、P1-P02 | P1.1、P1.4、P1.5 | 未实现 |
| P1-R04 | 每 tile 权威 SoA、紧凑 owner 和容量安全 | `BOM.h`、`BOM_SIZE.h`、`BOM_CHECK_STATE` | P1-S03、P1-N03 | P1.1 | 未实现 |
| P1-R05 | 支持规则 Cartesian 与未旋转 spherical-polar 映射 | `BOM_MAPPING` | P1-M01、P1-M02、P1-N04 | P1.2 | 未实现 |
| P1-R06 | 表层 C-grid U/V 正确转为 C 点 east/north | `BOM_BUILD_FIELDS` | P1-F01、P1-F02 | P1.2 | 未实现 |
| P1-R07 | 对湿点做一致的归一化双线性插值 | `BOM_INTERP` | P1-F03、P1-N05 | P1.2 | 未实现 |
| P1-R08 | LEEW 海流 RHS 使用 SI 且坐标率转换正确 | `BOM_RHS_LEEWAY` | P1-I01、P1-I02、P1-I03 | P1.3 | 未实现 |
| P1-R09 | 可选 EXF 风按独立经验系数叠加 | `BOM_BUILD_FIELDS`、`BOM_RHS_LEEWAY` | P1-I04、P1-N06 | P1.3 | 未实现 |
| P1-R10 | Stokes 在 Phase 1 固定关闭，误配置失败 | `BOM_READPARMS`、`BOM_CHECK` | P1-N07 | P1.1 | 未实现 |
| P1-R11 | 固定子步、显式中点 RK2 和经典 RK4 | `BOM_MAIN`、`BOM_RK2`、`BOM_RK4` | P1-I05、P1-I06 | P1.3 | 未实现 |
| P1-R12 | 每个子步后完成唯一 owner tile/rank 迁移 | `BOM_PARTICLE_EXCHANGE`、`BOM_MAPPING` | P1-X01—P1-X04 | P1.4 | 未实现 |
| P1-R13 | 轨迹使用独立 schema/前缀并可按 ID 重组 | `BOM_OUTPUT` | P1-O01、P1-O02 | P1.5 | 未实现 |
| P1-R14 | 相同分解 pickup 连续/重启状态 bitwise 一致 | `BOM_READ_PICKUP`、`BOM_WRITE_PICKUP` | P1-P01、P1-P02 | P1.5 | 未实现 |
| P1-R15 | FLT 与 BOM 状态、例程、I/O 独立且可共存 | BOM namespace、核心调度 | P1-K01、P1-K02 | P1.5 | 部分骨架，待完整验证 |
| P1-R16 | 运行中检查有限数、CFL、owner 数和状态预算 | `BOM_CHECK_STATE`、`BOM_MAIN` | P1-N08、P1-X03、P1-G01 | P1.3–P1.5 | 未实现 |

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
