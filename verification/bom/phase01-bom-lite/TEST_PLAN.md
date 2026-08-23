# Phase 1 BOM-Lite 测试计划

状态：P1.0 设计基线，尚无执行结果

## 1. 测试原则与证据布局

所有构建和运行位于仓库外：

```text
/home/wyl/build/mitgcm-bom/<test-id>/
/home/wyl/runs/mitgcm-bom/<test-id>/
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/<test-id>/
```

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
| P1-N02 | 坏 schema、截断文件、NaN、坏状态 | P1-R02 | 输入被完整拒绝，无部分粒子进入状态 |
| P1-N03 | 全局、tile 或交换容量溢出 | P1-R04 | 输出 rank/tile/需要量/上限后停止，不截断 |
| P1-N04 | rotated、curvilinear、EXCH2 或多线程 | P1-R05 | Phase 1 明确拒绝并说明支持范围 |
| P1-N05 | 湿权重不足或域外插值 | P1-R07 | 明确停止，不做常数外推或静默搁浅 |
| P1-N06 | 风系数非零但 source NONE；EXF 未编译/未启用 | P1-R09 | 依赖检查失败，信息包含 source 和系数 |
| P1-N07 | `bomStokesSource=FILES/COUPLER` | P1-R10 | Phase 1 明确拒绝，不读取外部文件 |
| P1-N08 | NaN RHS、CFL/overlap 超限 | P1-R16 | 输出粒子 ID 和局部量后全局停止 |

## 4. 状态、ID 与初值

| ID | 场景 | 分解 | 需求 | 判据 |
|---|---|---|---|---|
| P1-S01 | 0、1、多粒子合法 schema 1 | 1 rank | P1-R02 | 计数、坐标、状态、release time 逐字段一致 |
| P1-S02 | ID 覆盖 32 位边界和大于 $2^{53}$ | 1/2 ranks | P1-R03 | 高低字往返恢复原 `INTEGER*8`，无重复 |
| P1-S03 | 粒子恰在 tile 边界与角点 | 1/4 ranks | P1-R04、P1-R05 | 由最小全局 tile 编号唯一拥有 |
| P1-S04 | 未来 release time | 1 rank | P1-R04、P1-R11 | release 前位置不变，跨 release 子步正确分割 |

## 5. 映射与环境场

| ID | 场景 | 需求 | 判据 |
|---|---|---|---|
| P1-M01 | 规则 Cartesian 原生坐标与局部 ij 往返 | P1-R05 | 内点接近舍入误差，边界遵守半开区间 |
| P1-M02 | spherical-polar、周期经度与非零纬度 | P1-R05 | 经度规范化、局部 ij 和 owner 正确 |
| P1-F01 | 均匀 model-grid U/V，经旋转到 east/north | P1-R06 | C 点向量与解析值接近舍入误差 |
| P1-F02 | 人工角度场与 mask | P1-R06 | 旋转方向、colocation 和掩膜正确 |
| P1-F03 | 常数/线性 C 点场的随机粒子插值 | P1-R07 | 常数精确，线性场达到双线性解析容差 |

## 6. 积分与解析轨迹

| ID | 场景 | 分解 | 需求 | 判据 |
|---|---|---|---|---|
| P1-I01 | 零海流、零风 | 1 rank | P1-R08 | ALIVE 与 WAITING 位置 bitwise 不变，状态正确 |
| P1-I02 | Cartesian 均匀海流 | 1 rank | P1-R08 | $x=x_0+ut$、$y=y_0+vt$，误差接近舍入级 |
| P1-I03 | spherical-polar 均匀 east/north 流 | 1 rank | P1-R08 | lon/lat 位移满足球面换算容差 |
| P1-I04 | 均匀海流+EXF 风 | 1 rank | P1-R09 | RHS 等于 `vE + bomLeewayWindCoeff*v10`；与 Julia RHS 单位换算后一致 |
| P1-I05 | 空间线性、光滑 RHS，子步连续减半 | 1 rank | P1-R11 | RK2 误差比接近 $2^2$ |
| P1-I06 | 同一光滑 RHS | 1 rank | P1-R11 | RK4 误差比接近 $2^4$ |

收敛测试至少使用四个子步尺度，以最高两个误差比作为判据。阈值在脚本中固定；不能只报告一条“误差很小”的轨迹。

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
| P1.1 | P1-C01、P1-C03、P1-Z01、P1-N01—N03、P1-N07、P1-S01—S04 |
| P1.2 | P1-N04—N05、P1-M01—M02、P1-F01—F03，加前序回归 |
| P1.3 | P1-N06、P1-N08、P1-I01—I06，加前序回归 |
| P1.4 | P1-X01—X04，加 1/2/4 ranks 前序回归 |
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
- RK 收敛：检查阶数而非单一绝对误差；
- Julia 对照：先统一 km/day 到 m/s、equirectangular到目标坐标和固定步设置，再设位置阈值；
- 任何容差变更必须在同一 PR 说明失败证据和数值原因。
