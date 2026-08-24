# MITGCM-BOM Phase 1 阶段记录

| 项目 | 当前值 |
|---|---|
| 阶段 | Phase 1：BOM-Lite / Leeway |
| 目标版本 | `MITGCM-BOM-v0.2` |
| 基线标签 | `MITGCM-BOM-v0.1` |
| 基线提交 | `b2f3ecf1081f7bab25749c4a6004730175d99955` |
| 当前分支 | `MITGCM-BOM/phase-01-mapping-environment` |
| 当前 PR | `wang111936/MITgcm#10`（Draft，P1.2 映射与环境场） |
| 当前工作包 | P1.2 映射与环境场 |
| 状态 | P1.2 P1-R05—P1-R07 实现、生产生命周期门禁、全回归和最终审计全部 PASS；PR #10 保持 Draft |
| 开始日期 | 2026-08-23 |
| 作者身份 | `WangYuLin <wang111936@outlook.com>` |

## 1. 阶段目标

在不引入惯性、Stokes、弹簧和生物过程的条件下，建立可在 Linux HPC 上运行的二维表层 BOM 粒子基础设施：独立状态、MITgcm 表层流插值、固定步积分、tile/MPI owner 迁移、轨迹和相同分解 pickup 重启。

Phase 1 结束时应提供可执行证据，证明 BOM-Lite 的解析轨迹正确、MPI 分解不改变权威状态、FLT 与 BOM 可以独立或同时运行。

## 2. 分工作包记录

| 工作包 | 状态 | 分支/PR | 结论 |
|---|---|---|---|
| P1.0 设计冻结 | 完成 | `MITGCM-BOM/phase-01-design` / PR #7 | merge commit `acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f` |
| P1.1 状态与初值 | 完成 | `MITGCM-BOM/phase-01-state` / PR #8 | merge commit `ab30b3dc530404fda796189e50b8de776bf4441d`；集成 P1.1/Phase 0 门禁通过 |
| P1.2 映射与环境场 | 待集成 | `MITGCM-BOM/phase-01-mapping-environment` / PR #10（Draft） | 审计修复 `2f346d98cf978922cae53bff67fc32088cbb8941`；P1-R05—P1-R07、全回归和最终审计 PASS，等待 Ready/合并的分步授权 |
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
- 所有目录均保留且未覆盖；`p11-physical-size-fix-attempt01` 是最终合并前权威证据，`p11-integrated-pr8-attempt01` 是当前权威集成证据。

### 6.5 GitHub 记录

- 功能提交：`c5ee5549a504ed428f152bbc5022368095a1752d`；
- 正式审查修复提交：`2c688a7e90d1bdd814a8bd8b0ef5db63c7d67a65`；
- 物理长度修复提交：`40f5754b3b00ea4bb6a9b20c64c10e968080ad24`；
- 作者与提交者：`WangYuLin <wang111936@outlook.com>`；
- merged PR #8：`https://github.com/wang111936/MITgcm/pull/8`；
- base：`MITGCM-BOM/development@acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f`；
- 生产/门禁 head：`MITGCM-BOM/phase-01-state@40f5754b3b00ea4bb6a9b20c64c10e968080ad24`；
- PR head：`d39a878ef647f5e4dbc2b47ef694563848ce8ba4`；
- merge commit：`ab30b3dc530404fda796189e50b8de776bf4441d`；
- 当前不创建 `MITGCM-BOM-v0.2` 标签。

### 6.6 集成结果

- P1.1 集成门禁：`p11-integrated-pr8-attempt01`，8/8 构建、14/14 正向、20/20 负向、104/104 checkpoint 通过；
- P1.1 summary SHA-256：`93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7`；
- Phase 0 集成门禁：`p11-integrated-pr8-phase0-attempt01`，锁定参考、离线 Julia、smoke 和 P0.4 总门禁通过；
- Phase 0 summary SHA-256：`e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2`；
- 测试产物全部位于仓库外，集成分支运行后工作树保持干净。
- PR #9 最终独立复审重新核对 merge 双亲、42/42 P1.1 结果、104 条 checkpoint 记录、4/4 Phase 0 总门禁结果、9/9 嵌套 P0.4 结果和三份摘要哈希，未发现源码或测试问题。

## 7. Phase 1 总退出条件

- [ ] P1.1—P1.5 全部完成并顺序集成；
- [ ] 解析、收敛、迁移、重启和 FLT 共存门禁全部通过；
- [ ] Phase 0 完整门禁重新执行且无回归；
- [ ] Julia 专用 RHS/golden 限制有明确结论；
- [ ] 目标服务器所需但本地无法验证的条件已单独记录；
- [ ] 集成分支创建 `MITGCM-BOM-v0.2` 前完成独立退出审计。

## 8. 下一恢复点

从 `MITGCM-BOM/phase-01-mapping-environment` 恢复：

1. 核对当前分支包含 P1.2 审计修复功能提交 `2f346d98cf978922cae53bff67fc32088cbb8941`；
2. 以 [`P1.2_INTERFACE_FREEZE.md`](../../../../verification/bom/phase01-bom-lite/P1.2_INTERFACE_FREEZE.md) 和 mapping/fields/interp 三份 `TEST_RESULTS.md` 作为接口与证据入口；
3. 复核 [`P1.2_SCOPE_AUDIT.md`](../../../../verification/bom/phase01-bom-lite/P1.2_SCOPE_AUDIT.md) 的 PASS 结论、关闭项和六套权威证据；
4. 下一步等待明确授权后才可将 PR #10 标记 Ready；Ready 不等于授权合并；
5. 未获后续授权不合并 PR #10、不开始 P1.3、不创建 `MITGCM-BOM-v0.2` 标签。

## 9. P1.2 启动记录

### 9.1 PR #9 合并与基线

- PR #9 已以 merge commit `320a07d5eb2e2795ddd1e0b93ceaddd6c32a1621` 合并；
- 合并双亲为原 `development@ab30b3dc530404fda796189e50b8de776bf4441d` 与 PR head `09a9590456c6e50072ce707607011fd535c523b3`；
- 合并范围保持 3 个 Markdown，四个 PR 项目提交作者均为 `WangYuLin <wang111936@outlook.com>`；
- 本地 `MITGCM-BOM/development` 已快进到合并提交，工作树干净，未创建 `MITGCM-BOM-v0.2`。

### 9.2 P1.2 分支与环境

- 从 `development@320a07d5eb2e2795ddd1e0b93ceaddd6c32a1621` 创建 `MITGCM-BOM/phase-01-mapping-environment`；
- 仓库 Git 身份固定为 `WangYuLin <wang111936@outlook.com>`；
- MITGCM-BOM 专用环境自检通过：GNU Fortran 11.4、OpenMPI 4.1.2、NetCDF-C 4.8.1、NetCDF-Fortran 4.5.4、fortls 3.2.2、Julia 1.10.12、MPI smoke；
- 源码、构建和运行根分别保持 `/home/wyl/projects/mitgcm-bom`、`/home/wyl/build/mitgcm-bom`、`/home/wyl/runs/mitgcm-bom`。

### 9.3 P1.2 接口冻结

- 只读审计 `pkg/flt/flt_mapping.F`、`flt_interp_linear.F`、`model/src/rotate_uv2en.F`、当前 `pkg/bom` 与锁定 Julia checkout；
- Julia `Leeway!` 只裁决 P1.3 RHS，不裁决 MITgcm C-grid、tile、halo、周期 owner 或湿点插值；
- 形成 P1-D015—P1-D020：网格/粒子诊断分离命名、只对完整 360° 球面域回绕、east/north 标量交换、pair 插值显式有效性、Julia 映射非权威，以及负分数 overlap 使用数学 floor；
- 冻结 `BOM_INIT_MAPPING`、`BOM_NORMALIZE_X`、正反映射、`BOM_BUILD_FIELDS` 和 `BOM_INTERP_WET_PAIR` 的接口与失败边界；
- 以 `WangYuLin <wang111936@outlook.com>` 创建设计提交 `4d7bfa8dae16e8ca23d96043b6207a4b91a95f3e`，推送分支并创建 Draft PR #10；
- Draft PR 初始远端范围为 1 个提交、6 个 Markdown、ahead 1/behind 0，无状态检查或工作流；
- 本次只修改 Markdown，没有实现 Fortran、门禁脚本或测试输入，因此未运行编译矩阵。

### 9.4 P1.2 首个映射实现

- 在 `BOM.h` 建立域界、周期、容差与字段就绪状态；`BOM_INIT_FIXED` 调用新的 `BOM_INIT_MAPPING`；
- 实现 `BOM_NORMALIZE_X`、`BOM_MAP_XY2IJLOCAL` 和 `BOM_MAP_IJLOCAL2XY`，完整 360° spherical-polar 域使用半开规范区间，区域域不回绕；
- 映射将 owner 与 overlap stencil 分离，并以数学 floor 处理负分数局部索引；
- `p12-map-20260824-b` 的 regular debug、实际 OpenMP、实际 EXCH2 构建和 11 项运行/源码检查全部通过，共 14/14 summary 行；
- 映射 summary SHA-256 为 `52d3e2b26c043d870bcb1c21169dd307b1f96d449bdcba0c76327e258f6d9bde`；
- `p12-regression-p11-20260824` 通过 8/8 构建、14/14 正向、20/20 负向、104/104 checkpoint；
- `p12-regression-p05-20260824` 与嵌套 `p12-regression-p05-20260824-p04` 通过 Phase 0 总门禁；
- 功能提交为 `633d3f9af75b4a052303ec0d0a06edf40677e18c`，作者与提交者均为 `WangYuLin <wang111936@outlook.com>`；
- 本增量未修改 `BOM_LOCATE_INITIAL`，未构造环境场、未插值、未移动粒子；PR #10 保持 Draft，不创建标签、不开始 P1.3。

### 9.5 P1.2 locator 兼容包装

- `BOM_LOCATE_INITIAL` 保留原公共接口，内部改为调用 `BOM_MAP_XY2IJLOCAL`；
- 继续用 `NINT(ix/jy)` 和 owner 中心 `maskC` 判定初值湿点，不把四点 stage stencil 变成初值要求；
- 门禁增加包装源审计，确认没有旧 `xG/yG` 搜索或未来 `BOM_INTERP_WET_PAIR` 调用；
- `p12-locator-20260824-a` 通过 15/15 summary 行，summary SHA-256 为 `24ee80deb67395b9a8c14662d26e1da66be30b76ffc284ba409f15fc66c725d7`；
- `p12-locator-regression-p11-20260824` 通过 8/8 构建、14/14 正向、20/20 负向、104/104 checkpoint；
- `p12-locator-regression-p05-20260824` 与嵌套 `-p04` 通过 Phase 0 总门禁；
- 功能提交为 `14636cda2bc9da61da784752b1dec11e54d518f1`，作者与提交者均为 `WangYuLin <wang111936@outlook.com>`；
- P1-R05 完成，但 P1-R06/P1-R07 未实现；PR #10 保持 Draft，不创建标签、不开始 P1.3。

### 9.6 P1.2 表层环境场构造

- 新增四个冻结的单层 C-grid 数组，并在 `BOM_INIT_STATE` 中确定性清零；
- `BOM_BUILD_FIELDS` 只复制 `uVel/vVel` 的 `k=1`，调用真实 `ROTATE_UV2EN_RL`，随后对 east/north 分量各做一次标量 `EXCH_3D_RL`；
- 旋转、两次交换和有限/干点检查完成后才发布 `bomFieldTime/bomFieldIter/bomFieldsReady`；零粒子 `BOM_MAIN` 保持立即返回；
- `p12-field-20260824-a` 首轮通过源码契约、串行/MPI4 `Nr=2` 调试构建及四项 P1-F01/P1-F02 运行，共 7/7 summary 行；summary SHA-256 为 `97d21381200a8c8314de96302d790bb4aa995092a100bb9b83e42f27840d4492`；
- 回归 `p12-20260823T214951Z-501860` 通过映射/locator 15/15，`20260823T215044Z-548609` 通过 P1.1 42/42，`20260823T215320Z-668561` 通过 Phase 0 4/4；
- 功能提交为 `50dd6a6ab7e92ac5ca26ab4666ce2e45d7495899`，作者与提交者均为 `WangYuLin <wang111936@outlook.com>`；
- P1-R06 完成，P1-R07 未实现；未加入湿点 pair 插值、风、Stokes 或粒子运动，PR #10 保持 Draft，不创建标签、不开始 P1.3。

### 9.7 P1.2 湿点 pair 插值

- 新增 `BOM_INTERP_WET_PAIR`，对 east/north C 点 pair 复用同一组 mask 过滤和湿权重归一化；
- 在整数转换前拒绝非有限或超出 overlap 的实数索引，再以数学 floor 建立四点 stencil，避免巨大有限值的整数转换溢出；
- 未就绪、缺失 stencil、非有限 pair、湿权重不足或坏 tile 均返回 `isValid=.FALSE.` 和零速度值；湿权重不足时保留实际权重供未来上层诊断；
- `p12-interp-20260824-a` 首轮通过源码契约、串行/MPI4 debug/bounds 构建和六项 P1-F03/P1-N05 运行，共 9/9 summary 行；summary SHA-256 为 `75fcde1ce34ceb1b43cb2ef8dcc6e323948db1edb6df2d4fb90329d8395be81a`；
- 回归 `p12-field-20260823T222525Z-392`、`p12-20260823T222622Z-390`、`20260823T222731Z-385` 和 `20260823T223014Z-381` 分别通过字段 7/7、映射 15/15、P1.1 42/42 和 Phase 0 4/4；
- 功能提交为 `597d1a706de2ca388d1312dd6bb667421ae9adc7`，作者与提交者均为 `WangYuLin <wang111936@outlook.com>`；
- P1-R05—P1-R07 的生产实现与全回归完成；未加入粒子 RHS、运动、迁移、风或 Stokes，PR #10 继续保持 Draft，下一步为 P1.2 范围审计和独立复审。

### 9.8 P1.2 最终范围与契约审计

- 审计基线/头为 `320a07d5eb2e2795ddd1e0b93ceaddd6c32a1621..f9b6098d657b6749130cdbdbb0ce091f73c99a9c`；Draft PR #10 的 10 个提交和 56 个变更文件均在 P1.2 允许路径内；
- `git diff --check` 通过，没有核心调度、FLT、其他工程、构建产物、运行输出或 P1.3 变更；
- 六套权威 summary 的 SHA-256 全部重算一致；插值 9/9、字段 7/7、映射 15/15、P1.1 42/42、Phase 0 4/4、嵌套 P0.4 9/9 均无非 PASS 行；
- P1.1 的 104/104 与嵌套 P0.4 的 24/24 checkpoint 原始记录均为 `OK`，已有证据可信；
- 最终审计未通过：`BOM_MAIN` 尚未接入非移动的已有粒子映射/插值诊断及调用层上下文终止，故 P1-R07/P1-N05 仍开放；
- 映射初始化还需补齐累计/派生有限性、末端 face 端点和极端有限周期输入防护及负测，故 P1-R05 重新开放；
- 审计详情记录于 `verification/bom/phase01-bom-lite/P1.2_SCOPE_AUDIT.md`；P1-R06 保持完成；
- PR #10 保持 Draft，不合并、不创建 `MITGCM-BOM-v0.2` 标签、不开始 P1.3。下一增量只修复上述 P1.2 问题并复跑受影响门禁与全部前序回归。

### 9.9 P1.2 审计修复与 PASS 复审

- 功能提交 `2f346d98cf978922cae53bff67fc32088cbb8941` 在 `BOM_MAIN` 对当前 owner 记录执行非移动映射/湿点 pair 插值，有效时只发布 `bomI/bomJ/bomVEast/bomVNorth`，无效时输出粒子、tile、局地索引和湿权重后集体终止；
- 同一提交为映射累计、派生边界/容差、stored-face 双端点和周期规范化增加有限性与预溢出防护；初始化失败不发布部分映射状态；
- 权威门禁：`p12-interp-auditfix-20260824-c` 15/15，summary `aaff9205a4f5faa580d06fe55b18720bbcd42a72667caae7b5f27fd4632c13d4`；`p12-map-auditfix-20260824-b` 19/19，summary `926575f1093bb7353f09e9835e175289a309c13e653ded5a96871e06b3810c02`；
- 回归门禁：字段 `p12-field-auditfix-20260824-a` 7/7，P1.1 `p12-auditfix-p11-20260824-a` 42/42 且 104/104 checkpoint，Phase 0 `p12-auditfix-phase0-20260824-a` 4/4，嵌套 P0.4 `-p04` 9/9 且 24/24 checkpoint；
- 映射 `-a` 和插值 `-a/-b` 失败尝试保留为非权威证据，没有复用或覆盖目录；
- 最终审计为 PASS，P1-R05—P1-R07 和 R-013/R-014 全部关闭。未引入 RHS、位置更新、release 转换、owner 迁移、风、Stokes 或 P1.3；PR #10 保持 Draft，不合并、不创建标签。
