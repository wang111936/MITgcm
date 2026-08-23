# MITGCM-BOM Phase 1 阶段记录

| 项目 | 当前值 |
|---|---|
| 阶段 | Phase 1：BOM-Lite / Leeway |
| 目标版本 | `MITGCM-BOM-v0.2` |
| 基线标签 | `MITGCM-BOM-v0.1` |
| 基线提交 | `b2f3ecf1081f7bab25749c4a6004730175d99955` |
| 当前分支 | `MITGCM-BOM/phase-01-state` |
| 当前 PR | `wang111936/MITgcm#8`（Ready） |
| 当前工作包 | P1.1 状态与初值 |
| 状态 | 五项阻断均关闭且最终独立复审通过，PR #8 已 Ready 并等待明确的合并授权 |
| 开始日期 | 2026-08-23 |
| 作者身份 | `WangYuLin <wang111936@outlook.com>` |

## 1. 阶段目标

在不引入惯性、Stokes、弹簧和生物过程的条件下，建立可在 Linux HPC 上运行的二维表层 BOM 粒子基础设施：独立状态、MITgcm 表层流插值、固定步积分、tile/MPI owner 迁移、轨迹和相同分解 pickup 重启。

Phase 1 结束时应提供可执行证据，证明 BOM-Lite 的解析轨迹正确、MPI 分解不改变权威状态、FLT 与 BOM 可以独立或同时运行。

## 2. 分工作包记录

| 工作包 | 状态 | 分支/PR | 结论 |
|---|---|---|---|
| P1.0 设计冻结 | 完成 | `MITGCM-BOM/phase-01-design` / PR #7 | merge commit `acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f` |
| P1.1 状态与初值 | 待合并 | `MITGCM-BOM/phase-01-state` / PR #8 | 5 项审查阻断已关闭；最终独立复审通过且 PR 已 Ready |
| P1.2 映射与环境场 | 未开始 | 待建立 | 等待 P1.1 门禁 |
| P1.3 单 tile 积分 | 未开始 | 待建立 | 等待 P1.2 门禁 |
| P1.4 owner 迁移 | 未开始 | 待建立 | 等待 P1.3 门禁 |
| P1.5 输出与重启 | 未开始 | 待建立 | 等待 P1.4 门禁 |

## 3. P1.0 交付范围

本工作包只允许 Markdown：

- `BOM_LITE_DESIGN.md`：需求、状态、环境场、积分、并行、I/O、FLT 共存边界；
- `PHASE_RECORDS/PHASE-01.md`：跨会话阶段记录；
- `verification/bom/phase01-bom-lite/REQUIREMENTS_TRACEABILITY.md`：需求到实现和测试的双向追踪；
- `verification/bom/phase01-bom-lite/TEST_PLAN.md`：分阶段可执行测试矩阵；
- `PROJECT_STATUS.md` 和 `verification/bom/README.md`：恢复点与目录入口更新。

本工作包不得修改：

- `pkg/bom/*.F` 或头文件；
- `model/src`、`model/inc` 或任何 MITgcm 调度代码；
- verification 脚本、输入、参考输出或构建产物；
- Phase 0 的锁定参考、测试证据和标签。

## 4. P1.0 已冻结的关键结论

1. BOM-Lite 方程为欧拉海流加可选 10 m 风偏移；
2. Julia `Leeway!` 不含 Stokes，Phase 1 的 `bomStokesSource` 只能为 `NONE`；
3. 风偏移使用 `bomLeewayWindCoeff`，不复用后续慢流形 `bomAlpha`；
4. 权威位置使用 MITgcm 原生坐标，环境向量统一为 SI east/north；
5. Phase 1 海洋步内冻结环境场，old/new 时间插值留到 Phase 2；
6. 粒子数固定，owner 数组保持紧凑，暂不建立 free-list；
7. 64 位 ID 在文件和 `_RL` 交换缓冲中拆为高、低 32 位；
8. Phase 1 支持规则 Cartesian 和未旋转 spherical-polar 网格，不支持 `EXCH2`；
9. pickup 先保证相同 MPI/tile 分解下 bitwise 重启；
10. BOM 和 FLT 不共享 COMMON、文件、ID、插值或通信例程。

## 5. P1.0 审计清单

- [x] Git diff 只有预定 Markdown 文件；
- [x] 没有新增或修改 Fortran、shell、Julia、Python 和二进制文件；
- [x] 所有需求 ID 在追踪表中唯一且至少映射一个测试；
- [x] TEST_PLAN 中每个测试有判据、分解和证据路径；
- [x] 设计与锁定 MITgcm/Julia 源码相符；
- [x] 不含未声明的外部数据或服务器依赖；
- [x] `PROJECT_STATUS.md` 可作为下一次会话唯一恢复入口；
- [x] Git 作者身份为 WangYuLin；
- [x] 远端分支和 PR #7 已记录设计提交 `34cad7bd9c0d6bef3c9681dfb254d449cacbd6ac`；PR #7 已以 merge commit `acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f` 集成。

## 6. P1.1 状态与初值记录

### 6.1 交付

- 在 `BOM.h`/`BOM_SIZE.h` 建立每 tile 紧凑 SoA、稳定状态码、64 位 ID 和静态容量；
- 增加 `BOM_PARM02`，零粒子旧输入仍可省略该 namelist；
- 读取受 `bomInitGlobalLimit` 约束的 schema 1 MDS 全局初值文件，并交叉验证 meta 维度、float64 精度、记录数、`BOMV0001` schema 和实际物理文件长度；
- 用高/低 32 位字精确恢复正 `INTEGER*8` ID，拒绝重复与损坏 ID；
- 对有限数、状态、release time、age、域、湿单元、全局计数和 tile 容量做失败即停检查；
- 提供只供初值分发使用的规则网格 `BOM_LOCATE_INITIAL`，不提前实现 P1.2 的 stage-time 映射与插值；
- Stokes 在 Phase 1 继续固定为 `NONE`，提前启用时明确失败；
- 未修改 MITgcm 核心调度、FLT、Phase 0 锁定输入或参考哈希。

### 6.2 正式证据

- 权威 P1.1 测试 ID：`p11-physical-size-fix-attempt01`；
- 8/8 构建通过：BOM 串行/MPI2/MPI4/debug/OL1-debug，以及 BOM-uncompiled 串行/MPI2/MPI4；
- 14/14 正向运行通过：粒子状态、OL1 初始化、compiled-disabled 和 uncompiled 1/2/4 ranks；
- 20/20 负向门禁通过；截断、完整额外记录和单字节尾随分别以 64/192/129 实际字节对 128 预期字节被主动拒绝；
- 13 个适用运行保持 104/104 冻结海洋 checkpoint 哈希；
- `x/y/status/releaseTime/age` 均由门禁逐字段精确断言；
- `9007199254740993`（大于 $2^{53}$）在串行/MPI 中精确恢复；
- MPI4 的 `(180,0)` 内部角点按半开区间唯一归属 PID 3 的东北 tile；
- 最终 Phase 0 回归 ID：`p11-physical-size-fix-phase0-attempt01`，锁定参考、离线 Julia、8/8 smoke、P0.4 的 4 构建/3 正向/2 负向全部通过；
- 最终独立复审未发现剩余源码或测试问题；复审时 PR #8 为 6 个提交、31 个文件、ahead 6/behind 0、可合并但保持 draft，且无状态检查、工作流、评审或评审线程；
- bare-prefix 优先级探针位于 `/home/wyl/runs/mitgcm-bom/phase01-state/p11-final-rereview-bare-prefix-attempt01`；128 字节 bare prefix 与 192 字节 `.data` 并存时程序选择 bare prefix、仅有一个 owner 并正常结束；
- 完整路径、校验和和失败尝试说明见 `verification/bom/phase01-bom-lite/TEST_RESULTS.md`。

### 6.3 实现中形成的决定

- `P1-D013`：初值必须在 P1.1 可独立分发，因此允许受限 locator；完整周期、正反映射和 stage 插值仍属于 P1.2；
- 内部边界统一为 `[west,east) x [south,north)`，角点由东北 tile 拥有；删除与之冲突的“最小全局 tile 编号”表述；
- P1-S04 拆为 P1.1 的 WAITING 初值检查和 P1.3 的 release 跨子步转换；P1-N03 拆为 P1.1 初值容量与 P1.4 交换容量，旧父编号保留；
- `P1-D014`：meta 与头记录计数一致仍不足以证明输入完整；实际 `.data` 长度必须精确等于 `(nParticles+1)*8*8` 字节，截断和任意尾随字节均由 BOM 主动终止；
- 正式审查发现 locator halo 越界风险、meta 契约未执行、逐字段证据不足以及 BOM 关闭/未编译矩阵不完整；修复提交 `2c688a7e90d1bdd814a8bd8b0ef5db63c7d67a65` 已关闭四项。
- 独立复审以 `p11-rereview-physical-trailing-attempt01` 证明 meta/header 一致时额外物理记录仍会被静默忽略；修复提交 `40f5754b3b00ea4bb6a9b20c64c10e968080ad24` 已关闭该项。

### 6.4 非权威尝试

- `p11-state-attempt01`：早期较小矩阵通过，后被扩展门禁取代；
- `p11-state-attempt02`：72 列固定格式错误导致串行编译失败，随后修正；
- `p11-state-attempt03`：生产代码和新增用例均通过到截断文件，测试驱动因只接受 `ABNORMAL END` 而停止，随后补充运行时错误判据；
- `p11-state-attempt04`：扩展门禁通过；最终文件同步后由 attempt05 再次验证并取代；
- `p11-state-attempt05`：初始正式门禁通过，后由正式审查扩展矩阵取代；
- `p11-state-review-fixes-attempt01`：meta dimList 非标准固定宽度，原生解析器拒绝；随后修正；
- `p11-state-review-fixes-attempt02`：MITgcm 核心拒绝 momStepping 下 OL1；随后改为 locator-only 初始化配置；
- `p11-state-review-fixes-attempt03`：当时定义的全部扩展门禁通过，独立复审后由物理长度修复门禁取代；
- `p11-rereview-physical-trailing-attempt01`：保留为静默接受额外物理记录的复现证据；
- 所有目录均保留且未覆盖，只有 `p11-physical-size-fix-attempt01` 是当前权威 P1.1 证据。

### 6.5 GitHub 记录

- 功能提交：`c5ee5549a504ed428f152bbc5022368095a1752d`；
- 正式审查修复提交：`2c688a7e90d1bdd814a8bd8b0ef5db63c7d67a65`；
- 物理长度修复提交：`40f5754b3b00ea4bb6a9b20c64c10e968080ad24`；
- 作者与提交者：`WangYuLin <wang111936@outlook.com>`；
- Ready PR #8：`https://github.com/wang111936/MITgcm/pull/8`；
- base：`MITGCM-BOM/development@acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f`；
- 生产/门禁 head：`MITGCM-BOM/phase-01-state@40f5754b3b00ea4bb6a9b20c64c10e968080ad24`；
- 当前不合并、不创建 `MITGCM-BOM-v0.2` 标签。

## 7. Phase 1 总退出条件

- [ ] P1.1—P1.5 全部完成并顺序集成；
- [ ] 解析、收敛、迁移、重启和 FLT 共存门禁全部通过；
- [ ] Phase 0 完整门禁重新执行且无回归；
- [ ] Julia 专用 RHS/golden 限制有明确结论；
- [ ] 目标服务器所需但本地无法验证的条件已单独记录；
- [ ] 集成分支创建 `MITGCM-BOM-v0.2` 前完成独立退出审计。

## 8. 下一恢复点

从 Ready PR #8 恢复：

1. 最终独立复审已完成且 PR #8 已标记 Ready；先确认其相对 `MITGCM-BOM/development` 保持 31 文件独立差异；
2. 等待明确的 merge commit 合并授权，不自动合并；
3. 本 PR 不加入环境场、通用映射、粒子运动或交换等 P1.2+ 范围；
4. 获得明确合并授权后使用 merge commit，并在集成分支复跑 P1.1 与 Phase 0 门禁；
5. 集成通过前不创建 `MITGCM-BOM-v0.2` 标签；通过后创建独立 P1.2“映射与环境场”分支。
