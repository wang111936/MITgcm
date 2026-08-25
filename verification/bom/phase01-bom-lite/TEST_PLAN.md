# Phase 1 BOM-Lite 测试计划

状态：P1.1、P1.2 已验收；P1.3 原 157 项矩阵及 Ready remediation 新增的球面 RK2/RK4 两项解析位移均通过，累计 159 项；PR #13 等待 Ready 复审

P1.1 权威执行记录见 [`TEST_RESULTS.md`](TEST_RESULTS.md)，工作包边界审计见 [`P1.1_SCOPE_AUDIT.md`](P1.1_SCOPE_AUDIT.md)。

## 1. 测试原则与证据布局

所有构建和运行位于仓库外：

```text
/home/wyl/build/mitgcm-bom/phase01-state/<test-id>/
/home/wyl/runs/mitgcm-bom/phase01-state/<test-id>/
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/<test-id>/
```

P1.2 使用新的 `p12-*` test ID，映射、字段与插值/生命周期的构建/运行根分别放在 `phase01-mapping`、`phase01-fields` 与 `phase01-interp` 下；不得复用或覆盖 `phase01-state/p11-*` 证据。冻结接口见 [`P1.2_INTERFACE_FREEZE.md`](P1.2_INTERFACE_FREEZE.md)。

P1.3 使用新的 `p13-*` test ID，构建、运行和紧凑证据根分别为 `phase01-single-tile/<test-id>`、`phase01-single-tile/<test-id>` 与 `phase01/p13/<test-id>`；不得复用 P1.2 或更早证据。冻结接口见 [`P1.3_INTERFACE_FREEZE.md`](P1.3_INTERFACE_FREEZE.md)。

每次运行使用唯一 `test-id`，拒绝覆盖已有证据目录。最终在本目录提交紧凑的 `TEST_RESULTS.md`，至少记录：

- 源码 SHA、分支、dirty 状态；
- MITgcm/Julia 参考 SHA；
- 编译器、MPI、optfile、`SIZE.h`、`packages.conf`；
- namelist 与初始文件 SHA-256；
- 命令、退出状态、正常/异常结束标志；
- 粒子数、owner 预算、轨迹误差、文件哈希；
- 原始日志和二进制证据的仓库外绝对路径。

Phase 0 的 `phase00-final-gate/run_gate.sh` 在 P1.1—P1.5 每个工作包结束时回归执行。测试脚本不能把 Fortran `STOP` 的退出码 0 当成成功或失败的唯一依据。

## 2. 构建与静态门禁

| ID | 配置 | 需求 | 判据 |
|---|---|---|---|
| P1-C01 | BOM 未编译、BOM 编译；串行和 MPI | P1-R01 | `genmake2`、depend、编译、链接 4/4 通过 |
| P1-C02 | FLT only、BOM only、FLT+BOM | P1-R15 | 无重复符号；各包例程均进入链接 |
| P1-C03 | GNU debug flags | P1-R04、P1-R16 | 边界、未初始化和浮点 trap 构建通过 |
| P1-C04 | 变更范围审计 | 全部 | 工作包 diff 仅含计划文件，禁止构建产物 |

P1.0 只执行 P1-C04 的 Markdown-only 变体；不编译源码。

## 3. 零影响与参数负测

| ID | 场景 | 需求 | 判据 |
|---|---|---|---|
| P1-Z01 | BOM 关闭、编译关闭、零粒子开启；1/2/4 ranks | P1-R01 | MITgcm checkpoint 与冻结基线 SHA-256 一致 |
| P1-N01 | 非法模式、积分器、负时间步/频率 | P1-R01 | `BOM_CHECK` 输出具体参数并全局停止 |
| P1-N01b | 非有限 target/风系数/CFL、不可表示 `subRatio`、零/非有限 `dtSub` 或时间端点 | P1-R01、P1-R11、P1-R16 | 在 `CEILING` 或推进前输出参数名和值并终止；权威粒子状态不提交 |
| P1-N02 | 坏 schema/meta、截断/完整或残缺尾随数据、NaN、坏状态 | P1-R02 | meta、头记录与物理长度不一致时完整拒绝，无部分粒子进入状态 |
| P1-N03 | 容量溢出父项 | P1-R04 | 由 P1-N03a 与 P1-N03b 完成，不静默截断 |
| P1-N03a | 初值全局或 tile 容量溢出 | P1-R04 | 输出 tile/需要量/上限后停止，不截断 |
| P1-N03b | 交换发送或接收容量溢出 | P1-R04、P1-R12 | P1.4 输出 rank/方向/需要量/上限后停止 |
| P1-N04 | rotated、curvilinear、EXCH2、`usingPCoords`、多线程、非正网格间距或不一致域界 | P1-R05 | Phase 1 明确拒绝并说明支持范围；不能建立部分映射状态 |
| P1-N05 | 域外/缺失 stencil、字段未就绪、非有限字段或湿权重不足 | P1-R07 | 输出 tile、局部索引和湿权重后明确停止，不做夹取、常数外推或静默搁浅 |
| P1-N06 | 风系数非零但 source NONE；EXF 未编译；`useEXF`/`useAtmWind` 未启用；非法 source | P1-R09 | 依赖检查失败，信息包含 source、系数和具体缺失依赖 |
| P1-N07 | `bomStokesSource=FILES/COUPLER` | P1-R10 | Phase 1 明确拒绝，不读取外部文件 |
| P1-N08 | 非有限坐标率/度量、半格 CFL tie、stage CFL 超限、stage/final 离开当前 owner、age 溢出、计数/ID/状态预算损坏 | P1-R04、P1-R16 | 按冻结优先级输出首个 failCode、粒子 ID、substep、stage 和局部量后全局停止；失败粒子子步不提交 |

## 4. 状态、ID 与初值

P1.1 的 BOM-active 正向用例在初始化完成后零步结束，避免初值门禁
依赖 P1.4 才提供的跨 owner 迁移；BOM-disabled 1/2/4-rank 用例仍运行
完整基线并验证 8/8 checkpoint 哈希。P1.3 生命周期运动由独立门禁负责。

| ID | 场景 | 分解 | 需求 | 判据 |
|---|---|---|---|---|
| P1-S01 | 0、1、多粒子合法 schema 1 | 1 rank | P1-R02 | 计数、坐标、状态、release time 逐字段一致 |
| P1-S02 | ID 覆盖 32 位边界和大于 $2^{53}$ | 1/2 ranks | P1-R03 | 高低字往返恢复原 `INTEGER*8`，无重复 |
| P1-S03 | 粒子恰在 tile 边界与角点 | 1/4 ranks | P1-R04、P1-R05 | 按 `[west,east) x [south,north)` 唯一归属；内部角点由东北 tile 拥有 |
| P1-S04 | 未来 release time 父项 | 1 rank | P1-R04、P1-R11 | 由 P1-S04a 与 P1-S04b 共同完成 |
| P1-S04a | WAITING 初值 | 1 rank | P1-R04 | P1.1 精确保留 future release、WAITING 和零 age |
| P1-S04b | release 位于子步前、起点、内部、终点和未来 | 1 rank | P1-R11 | release 前位置/age 不变；内部精确分割；终点转 ALIVE 但零位移/零 age |

## 5. 映射与环境场

| ID | 场景 | 需求 | 判据 |
|---|---|---|---|
| P1-M01 | 规则 Cartesian 原生坐标与局部 ij 往返，覆盖内点、面、内部角点及西/南负分数 overlap | P1-R05 | 规范化坐标往返接近舍入误差；半开 owner 全局唯一；`isOwner`、`hasStencil` 与数学 floor 低端索引正确 |
| P1-M02 | 全球/区域 spherical-polar、±360° 等价经度、上界和非零纬度 | P1-R05 | 全球域经度规范化到半开域且 owner 唯一；区域域不回绕；反向映射返回规范化值 |
| P1-F01 | `Nr>1` 配置中的均匀表层 model-grid U/V，经真实 `ROTATE_UV2EN_RL` 转到 east/north | P1-R06 | 真正 `kSize=1` 数组无步长混淆；所有湿 C 点向量达到尺度化舍入容差 |
| P1-F02 | 人工 angle/mask、多 tile halo | P1-R06 | 旋转符号、C-grid colocation、干点零值和交换后共享 halo 一致；不宣称支持 `rotateGrid` |
| P1-F03 | 常数/双线性可表示 C 点 pair 场的确定性粒子集合，全湿与部分湿 stencil | P1-R07 | 常数在舍入范围内保持；全湿线性场达解析容差；部分湿时两分量复用同一归一化权重 |

## 6. 积分与解析轨迹

| ID | 场景 | 分解 | 需求 | 判据 |
|---|---|---|---|---|
| P1-I01 | 零海流、零风，含 ALIVE 与各类 WAITING release | 1 rank | P1-R08、P1-R11 | 位置 bitwise 不变；状态与 age 满足冻结 release 契约 |
| P1-I02 | Cartesian 均匀海流，RK2/RK4 | 1 rank | P1-R08 | $x=x_0+ut$、$y=y_0+vt$，误差满足 `_RL` 舍入传播阈值 |
| P1-I03 | spherical-polar 纯 east 与纯 north 均匀流，含非零纬度 | 1 rank | P1-R08 | 使用相同 `rSphere` 的 lon/lat 解析位移通过，不把 m/s 当 degree/s |
| P1-I04 | Cartesian 均匀海流+EXF 10 m 风 | 1 rank | P1-R09 | RHS 等于 `water+bomLeewayWindCoeff*wind`；与 Julia RHS 经 m/s 和 km/day 换算后一致 |
| P1-I05 | 双线性可表示的空间线性平滑 RHS，子步连续减半 | 1 rank | P1-R11 | RK2 最细两组观测阶均在 `[1.8,2.2]` |
| P1-I06 | 与 I05 相同 RHS | 1 rank | P1-R11 | RK4 最细两组观测阶均在 `[3.5,4.5]` |

I05/I06 使用 `P1.3_INTERFACE_FREEZE.md` 固定的全湿 Cartesian 仿射场：在中央 C 点定义 `T=deltaTClock`、局地 `Lx/Ly`，以 `u0=0.04Lx/T`、`ax=0.20/T`、`v0=0.03Ly/T`、`ay=-0.15/T` 和对应指数解析解裁决误差。四个子步尺度固定为 `T/4,T/8,T/16,T/32`，以最细两组的 `log2(E(h)/E(h/2))` 作为观测阶判据。必须预先证明所有 stage 留在同一 owner tile、最近 C 点度量有效且低于 CFL；不能只报告一条“误差很小”的轨迹，也不能运行后调整 fixture。

## 7. tile/MPI owner 迁移

| ID | 场景 | 分解 | 需求 | 判据 |
|---|---|---|---|---|
| P1-X01 | 单 rank 多 tile 横向/纵向/角点穿越 | 1 rank | P1-R12 | 位置连续、owner 唯一、总数不变 |
| P1-X02 | 穿越 rank 边界与周期边界 | 2/4 ranks | P1-R12 | 按 ID 排序后的权威状态与 1 rank 一致 |
| P1-X03 | 一个海洋步内经多个子步跨多个 tile | 1/4 ranks | P1-R12、P1-R16 | 每子步 hop 不超限，最终 owner/位置正确 |
| P1-X04 | 大 64 位 ID 迁移 | 2/4 ranks | P1-R03、P1-R12 | ID 高低字、状态、位置逐字段不变 |

目标是相同编译器和输入下，按 ID 排序的 1/2/4 ranks 最终状态 bitwise 一致。若交换或数学库导致不可避免差异，必须先形成设计决定并给出逐字段上界，不能临时放宽。

## 8. 输出、pickup 与 FLT 共存

| ID | 场景 | 分解 | 需求 | 判据 |
|---|---|---|---|---|
| P1-O01 | 多输出时刻和跨 rank 迁移 | 1/4 ranks | P1-R13 | 每个 `(time,id)` 恰一条，字段/schema/单位正确 |
| P1-O02 | 输出关闭、非整除频率 | 1 rank | P1-R13 | 无意外文件；调度不漏写/重复写 |
| P1-P01 | 连续 N 步 vs K 步+pickup+(N-K) 步 | 1/2/4 ranks | P1-R14 | 最终权威状态、计数和下一输出时刻 bitwise 相同 |
| P1-P02 | 大 ID、WAITING、跨 tile 后重启 | 4 ranks | P1-R03、P1-R14 | ID、status、age、owner 重建无损 |
| P1-P03 | 变更分解尝试恢复 | 不同分解 | P1-R14 | Phase 1 根据分解签名明确拒绝 |
| P1-K01 | 两者均关、FLT only、BOM only、FLT+BOM | 1/2 ranks | P1-R15 | 四组合均按预期运行，无文件/符号冲突 |
| P1-K02 | 对比独立与共存轨迹 | 1/2 ranks | P1-R15 | 共存不改变 FLT 结果或 BOM 按 ID 轨迹 |

## 9. 工作包门禁

| 工作包 | 必须通过 |
|---|---|
| P1.0 | Markdown-only 范围、链接、ID 和禁词审计 |
| P1.1 | P1-C01、P1-C03、P1-Z01、P1-N01、P1-N02、P1-N03a、P1-N07、P1-S01—S03、P1-S04a |
| P1.2 | P1-N04—N05、P1-M01—M02、P1-F01—F03，加前序回归 |
| P1.3 | P1-C01、P1-C03、P1-Z01、P1-N01b、P1-S04b、P1-N06、P1-N08、P1-I01—I06，加 P1.2/P1.1/Phase 0 全部前序回归 |
| P1.4 | P1-N03b、P1-X01—X04，加 1/2/4 ranks 前序回归 |
| P1.5 | P1-O01—O02、P1-P01—P03、P1-K01—K02、P1-G01 |

### P1-G01 最终集成门禁

最终门禁从全新构建/运行目录执行：

1. 验证锁定源码、参数、输入和测试脚本校验和；
2. 运行 Phase 0 完整门禁；
3. 完成串行和 1/2/4 ranks 的 Phase 1 正向矩阵；
4. 完成全部负向门禁并匹配预期错误文本；
5. 比较解析、分解、输出和 pickup 结果；
6. 审计 FLT/BOM 共存矩阵；
7. 生成需求覆盖和阶段退出报告；
8. 拒绝复用测试 ID 或覆盖历史证据。

## 10. 容差冻结原则

- 常数场、ID、状态、计数和相同分解 pickup：要求 exact/bitwise；
- Cartesian 均匀流：以 `_RL` 舍入传播上界为阈值；
- spherical 位移：解析公式使用与实现相同的 `rSphere`，阈值按经纬转换舍入设定；
- 双线性线性场：阈值不超过工作精度合理舍入量；
- RK 收敛：检查阶数而非单一绝对误差；RK2 观测阶 `[1.8,2.2]`，RK4 观测阶 `[3.5,4.5]`；
- Julia 对照：P1.3 只对照 `water+coeff*wind` RHS，使用精确因子 `1 m/s = 86.4 km/day`；不把 Julia 自适应 Tsit5 轨迹当作固定步 RK 的逐步 oracle；
- 任何容差变更必须在同一 PR 说明失败证据和数值原因。
