# MITGCM-BOM 项目状态账本

> 本文件是跨会话恢复工作的唯一状态入口。每次开发结束前必须更新“当前恢复点”“阶段状态”和“会话记录”。

| 项目 | 当前值 |
|---|---|
| 最后更新 | 2026-08-24 |
| 权威开发仓库 | `/home/wyl/projects/mitgcm-bom` |
| GitHub 仓库 | `wang111936/MITgcm` |
| 上游仓库 | `MITgcm/MITgcm` |
| 集成分支 | `MITGCM-BOM/development` |
| 当前任务分支 | `MITGCM-BOM/phase-01-single-tile-integration` |
| 当前阶段 PR | 待创建（P1.3 单 tile 积分） |
| 当前阶段 | Phase 1：BOM-Lite / Leeway（进行中） |
| 当前工作包 | P1.3 接口冻结：Leeway RHS、EXF 风、release、RK2/RK4 与单 tile 安全边界 |
| 下一工作包 | 提交并推送纯 Markdown 设计增量，创建 Draft PR 后进行独立设计复审 |
| 当前阻塞 | 无技术阻塞；设计复审通过前不开始 P1.3 生产 Fortran |

## 1. 当前恢复点

下一次继续开发时，从以下任务开始：

1. 核对当前分支为 `MITGCM-BOM/phase-01-single-tile-integration`，基线为 PR #12 merge commit `eefca92fe53f1b144bbfca7fcf00dc949a22afb3`；
2. 读取 [P1.3 接口冻结](../../../verification/bom/phase01-bom-lite/P1.3_INTERFACE_FREEZE.md)、[P1.2 收口记录](../../../verification/bom/phase01-bom-lite/P1.2_CLOSEOUT.md) 和 [P1.2 收口独立复审](../../../verification/bom/phase01-bom-lite/P1.2_CLOSEOUT_AUDIT.md)；
3. 核对 P1.3 当前范围只含 Markdown，目标需求为 P1-R08/P1-R09/P1-R11 及 P1-R16 的单 tile 部分；
4. 下一步先完成 Markdown 范围、链接、编号、禁词和身份审计，再以 WangYuLin 身份提交、推送并创建 Draft PR；
5. 设计独立复审通过前不实现生产 Fortran，不创建 `MITGCM-BOM-v0.2` 标签，也不提前加入 P1.4 owner 迁移。

开始前执行：

```bash
source /home/wyl/.config/mitgcm-bom/env.sh
/home/wyl/.config/mitgcm-bom/check-env.sh
git -C /home/wyl/projects/mitgcm-bom status --short --branch
```

## 2. 阶段状态

| 阶段 | 状态 | 目标版本 | 当前结论 | 详细记录 |
|---|---|---|---|---|
| Phase -1 环境与基线 | 完成 | 基线 | WSL、GNU/MPI、Julia、串并行 exp2 均通过 | [环境报告](ENVIRONMENT_READINESS.md) |
| Phase 0 参考与骨架 | 完成 | v0.1 | PR #1—#6 已集成；P0.5 门禁通过；`MITGCM-BOM-v0.1` 已发布 | [Phase 0](PHASE_RECORDS/PHASE-00.md) |
| Phase 1 BOM-Lite | 进行中 | v0.2 | P1.0—P1.2 已完成并收口；PR #12 已合并为 `eefca92fe`；P1.3 单 tile 积分接口已冻结，尚无生产实现 | [Phase 1](PHASE_RECORDS/PHASE-01.md) |
| Phase 2 慢流形惯性 | 未开始 | v0.3 | 等待 Phase 1 门禁 | [开发手册](DEVELOPMENT_MANUAL.md#phase-2慢流形惯性物理) |
| Phase 3 弹簧与邻居 | 未开始 | v0.4 | 等待 Phase 2 门禁 | [开发手册](DEVELOPMENT_MANUAL.md#phase-3非线性弹簧和分布式邻居) |
| Phase 4 生物与陆地 | 未开始 | v0.5 | 等待 Phase 3 门禁 | [开发手册](DEVELOPMENT_MANUAL.md#phase-4生物过程和陆地) |
| Phase 5 HPC 加固 | 未开始 | v1.0 | 等待目标服务器信息和 Phase 4 门禁 | [开发手册](DEVELOPMENT_MANUAL.md#phase-5hpc-加固) |
| Phase 6 一般网格 | 后置 | v2.x | 不阻塞规则经纬网 v1.0 | [开发手册](DEVELOPMENT_MANUAL.md#phase-6一般网格后续) |

状态只能使用：`未开始`、`进行中`、`阻塞`、`完成`、`后置`。只有阶段退出条件全部通过后才能标记为完成。

## 3. 已完成证据

### 环境与 MITgcm 基线

- MITgcm 提交：`dfc30dafb16561462ef1d4f9518f5d78753ec750`；
- 串行 `verification/exp2`：正常结束；
- 双进程 MPI `verification/exp2`：两个进程正常结束；
- 8 个串行/MPI checkpoint 数据文件 SHA-256 完全一致；
- 环境自检：GNU Fortran 11.4、OpenMPI 4.1.2、Julia 1.10.12、NetCDF 和 fortls 通过。

### P0.1 参考版本锁

- 本地/GitHub 提交：`ff1ab313d348fc0219e6e192bcbab928eb49e7e7`；
- GitHub PR：`https://github.com/wang111936/MITgcm/pull/1`，已合并为 `ccaf4f81243ae7ded8d09be0bd2074aced4600d8`；
- Julia 参考源码固定到 `156557359185e4413ce82829f3ed26a4eb8c6283`；
- 自定义注册表固定到 `02961aced4cfa2b3430ebd4b44cdb7a3056e7175`；
- 已为 Julia 1.10.12 重建根级 Manifest；
- `Project.toml` 和重建 Manifest 已复制到 `verification/bom/reference/julia_env`；
- 固定环境能够实例化并成功执行 `using SargassumBOMB`；
- 上游自带测试结果已记录：0 passed、1 errored，原因为测试调用不存在的 `generate_rp_example`；
- 详细限制与校验和见 [REFERENCE_LOCK](REFERENCE_LOCK.md)。

### P0.2 可编译空包骨架

- 本地/GitHub 提交：`eee711c9b5aea0644ffb54fc5a08c544d2d7919e`；
- GitHub PR：`https://github.com/wang111936/MITgcm/pull/2`，已合并为 `db9610264b21c7c55c4cce7a94fb6d357fbe9459`；
- 新增 `pkg/bom` 的 options、size、控制参数、读取/检查和空生命周期例程；
- `pkg/pkg_depend` 登记 `mdsio`、`mom_common` 强依赖；
- 串行与双进程 MPI 均完成 `genmake2`、`make depend`、编译和链接；
- 两个可执行文件均包含五个 `bom_*` 例程，证明包源码实际进入链接；
- 串行和双进程 MPI `verification/exp2` 均正常结束；
- 两套运行的 8 个 checkpoint 数据文件均与冻结基线 SHA-256 一致；
- 本工作包未修改 `model/src`、`model/inc`、`data.pkg` 或时间步调度；
- 详细命令和哈希见 `verification/bom/phase00-skeleton/TEST_RESULTS.md`。

### P0.3 生命周期注册

- 本地/GitHub 提交：`7e156a418b6d3f345298edeadbe7af73c938a1c7`；
- GitHub PR：`https://github.com/wang111936/MITgcm/pull/3`，已合并为 `81b53387d6c941b23177f23774e705dd200d940e`；
- 在 `PARAMS.h` 和 `data.pkg` 的 `PACKAGES` namelist 中注册 `useBOM`，默认关闭；
- 将读取、检查、固定初始化、变量初始化和空 `BOM_MAIN` 挂接到 MITgcm；
- `BOM_MAIN` 位于 FLT 之后、嵌套和 monitor 之前；
- 完成 BOM 未编译/已编译和串行/MPI 共四套完整构建；
- 完成六套正常运行：未编译、编译但关闭、编译且零粒子开启，各含串行和 2-rank MPI；
- 六套运行均正常结束，48/48 个 checkpoint 文件与冻结基线一致；
- 未编译却设置 `useBOM=true` 时，`PACKAGES_CHECK` 按预期终止；
- `bomMaxParticles=1` 时，`BOM_CHECK` 按预期拒绝未实现粒子状态；
- 详细证据见 `verification/bom/phase00-lifecycle/TEST_RESULTS.md`。

### P0.4 正式零粒子门禁

- 本地/GitHub 提交：`1e5bda7e4375db5520446fb715849e199725642a`；
- GitHub PR：`https://github.com/wang111936/MITgcm/pull/4`，已合并为 `d5e18cec22ed1be9c300bdd79ff908b6bd452e0c`；
- 固化 BOM 开启/关闭包清单、零粒子输入和 2 x 2 MPI 网格配置；
- 新增仓库外、唯一测试 ID 的自动测试驱动，并拒绝覆盖既有证据目录；
- `bash -n` 与 `shellcheck` 均通过；
- BOM 编译开启的串行、2-rank、4-rank MPI，以及 BOM 未编译的串行构建共 4/4 通过；
- 串行、2-rank 和 4-rank MPI 正向运行共 3/3 通过；
- 三种分解共 24/24 个 checkpoint SHA-256 与冻结基线一致；
- 未编译误开启与非零粒子两项负向门禁共 2/2 通过；
- 驱动通过正常/异常结束标志和预期错误文本避免 `STOP` 退出码 0 的误判；
- 需求—实现—测试追踪表已完成；
- 详细证据见 `verification/bom/phase00-zero-particle/TEST_RESULTS.md`。

### P0.5 Phase 0 最终门禁

- 本地/GitHub 功能提交：`6d705ed68d8d497597984d6c266a4954cd3b7ab8`；
- GitHub PR：`https://github.com/wang111936/MITgcm/pull/5`，已合并为 `2baea214fe1f898e16df4953892c142a07b82111`；
- 精确核对 Julia 源码、自定义注册表提交和锁定 Project/Manifest SHA-256；
- 专用 Julia depot 在离线模式下完成依赖实例化；
- Julia 1.10.12 / SargassumBOMB 0.7.14 的基础 smoke 8/8 断言通过；
- smoke 只覆盖加载、坐标/时间往返和纯工具函数，不依赖默认环境场或陈旧示例入口；
- 从全新目录重跑 P0.4，4/4 构建、3/3 正向、24/24 哈希、2/2 负向再次通过；
- 相同测试 ID 在覆盖历史证据前被拒绝；
- Phase 0 可执行退出条件全部满足，PR #1—#5 已完成顺序集成；
- 已记录顺序合并方案及集成后重跑/标记条件；
- 详细证据见 `verification/bom/phase00-final-gate/TEST_RESULTS.md`。

### Phase 0 集成结果

- PR #1—#5 均重定向到 `MITGCM-BOM/development`，复核独立差异后使用 merge commit 顺序合并；
- 五个 merge commit 依次为 `ccaf4f81243ae7ded8d09be0bd2074aced4600d8`、`db9610264b21c7c55c4cce7a94fb6d357fbe9459`、`81b53387d6c941b23177f23774e705dd200d940e`、`d5e18cec22ed1be9c300bdd79ff908b6bd452e0c` 和 `2baea214fe1f898e16df4953892c142a07b82111`；
- 在最终集成提交 `2baea214fe1f898e16df4953892c142a07b82111` 上运行 `p05-integrated-attempt01`；
- Julia 离线实例化、8/8 smoke、4/4 构建、3/3 正向运行、24/24 checkpoint 哈希和 2/2 负向门禁全部通过；
- 复用相同测试 ID 在覆盖历史证据前被拒绝；
- PR #6 已以 merge commit `b2f3ecf1081f7bab25749c4a6004730175d99955` 集成；
- 已创建并推送 annotated tag `MITGCM-BOM-v0.1`，tag object 为 `eb3a5e9372fa7f2c437c81384322667a3bb2cfd1`；
- Phase 1 已进入 P1.0 设计冻结，尚未修改粒子运动源码；
- 详细记录见 `verification/bom/phase00-final-gate/INTEGRATION_RESULTS.md`。

### P1.1 状态与初值完成及集成

- PR #7 已以 merge commit `acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f` 合并到 `MITGCM-BOM/development`；
- 从该提交创建 `MITGCM-BOM/phase-01-state`，未混入其他项目文件；
- 建立紧凑每 tile SoA、稳定状态码、schema 1 初值、32 位高低字到正 64 位 ID 的精确恢复和受限初值 owner locator；
- 明确拒绝非有限数、损坏/重复 ID、坏状态/release、域外/干点、全局/tile 容量溢出和提前启用 Stokes；
- 正式审查的四项阻断已由提交 `2c688a7e90d1bdd814a8bd8b0ef5db63c7d67a65` 修复：locator 边界、MDS meta 契约、逐字段断言和 BOM 关闭/未编译矩阵；
- 第五项物理长度阻断已由提交 `40f5754b3b00ea4bb6a9b20c64c10e968080ad24` 修复；
- 权威 `p11-physical-size-fix-attempt01`：8/8 构建、14/14 正向、20/20 负向、104/104 适用 checkpoint 哈希通过；
- 最终 `p11-physical-size-fix-phase0-attempt01`：锁定参考、离线 Julia、专用 smoke 和 P0.4 总门禁全部通过；
- P1-D013 允许 P1.1 受限初值 locator，并将内部边界统一为 `[west,east) x [south,north)`；P1-D014 要求初始 `.data` 物理长度精确匹配 schema；
- 最终独立复审未发现剩余源码或测试问题；额外 bare-prefix 优先级探针正常结束且只有一个 owner，证明物理长度检查与 MDS 读取选择同一文件；
- 生产代码未加入环境场、插值、粒子运动、迁移、轨迹或 pickup；
- 功能提交 `c5ee5549a504ed428f152bbc5022368095a1752d` 已推送并创建 draft PR #8；
- PR #8 已以 merge commit `ab30b3dc530404fda796189e50b8de776bf4441d` 合并到 `MITGCM-BOM/development`；
- 集成 `p11-integrated-pr8-attempt01` 再次通过 8/8 构建、14/14 正向、20/20 负向和 104/104 checkpoint；summary SHA-256 为 `93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7`；
- 集成 `p11-integrated-pr8-phase0-attempt01` 再次通过锁定参考、离线 Julia、smoke 和 P0.4 总门禁；summary SHA-256 为 `e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2`；
- 详细证据和非权威尝试见 `verification/bom/phase01-bom-lite/TEST_RESULTS.md`。

### P1.2 映射、字段构造与湿点 pair 插值

- 映射核心提交：`633d3f9af75b4a052303ec0d0a06edf40677e18c`；locator 包装提交：`14636cda2bc9da61da784752b1dec11e54d518f1`；
- 新增规则网格映射状态、只针对完整 360° spherical-polar 域的经度规范化，以及正反局部映射；
- owner 与 stencil 判定彼此独立，负分数 overlap 使用数学 floor，区域球面域不回绕也不裁剪；
- `BOM_LOCATE_INITIAL` 保留公共符号，内部调用新映射接口，同时保持 P1.1 中心湿点接受判据；
- `p12-locator-20260824-a` 通过包装源审计、3 项构建、3 项正向映射和 7 项 P1-N04 拒绝门禁，共 15/15 summary 行；
- 当前映射 summary SHA-256 为 `24ee80deb67395b9a8c14662d26e1da66be30b76ffc284ba409f15fc66c725d7`；
- `p12-locator-regression-p11-20260824` 通过 8/8 构建、14/14 正向、20/20 负向和 104/104 checkpoint；
- `p12-locator-regression-p05-20260824` 通过 Phase 0 总门禁，嵌套 P0.4 为 4 构建、3 正向、2 负向和 24/24 checkpoint；
- 字段构造提交为 `50dd6a6ab7e92ac5ca26ab4666ce2e45d7495899`；四个真实单层数组只复制 `k=1`，经真实旋转后以两次标量交换发布；
- `p12-field-20260824-a` 通过 7/7 summary 行，覆盖串行/MPI4 `Nr=2` 构建、P1-F01 均匀场和 P1-F02 旋转、干点及 halo；summary SHA-256 为 `97d21381200a8c8314de96302d790bb4aa995092a100bb9b83e42f27840d4492`；
- 本增量后的映射 15/15、P1.1 42/42 与 Phase 0 4/4 回归均通过；
- 字段增量完成 P1-R06；该增量当时未加入湿点 pair 插值或粒子运动，证据见 mapping/fields 两份 `TEST_RESULTS.md`；
- 插值提交为 `597d1a706de2ca388d1312dd6bb667421ae9adc7`；`BOM_INTERP_WET_PAIR` 使用共同湿权重并以显式无效结果处理未就绪、缺 stencil、非有限和湿权重不足；
- `p12-interp-20260824-a` 通过 9/9 summary 行，覆盖 P1-F03 全湿/部分湿和 P1-N05 串行/MPI4；summary SHA-256 为 `75fcde1ce34ceb1b43cb2ef8dcc6e323948db1edb6df2d4fb90329d8395be81a`；
- 插值后的字段 7/7、映射 15/15、P1.1 42/42 和 Phase 0 4/4 回归全部通过；
- 审计修复提交 `2f346d98cf978922cae53bff67fc32088cbb8941` 将 `BOM_MAIN` 接入非移动映射/插值诊断与调用层集体终止，并补齐映射初始化和极端周期输入的有限性防护；
- 修复后插值/生命周期 15/15、映射 19/19、字段 7/7、P1.1 42/42、Phase 0 4/4 与嵌套 P0.4 9/9 均 PASS；
- P1.2 最终审计为 PASS，P1-R05—P1-R07 全部关闭；详见 `verification/bom/phase01-bom-lite/P1.2_SCOPE_AUDIT.md`。

## 4. 未决问题与风险

| ID | 风险 | 当前处理 | 阻塞阶段 |
|---|---|---|---|
| R-001 | 上游 Julia 提交没有根级 Manifest | 使用固定自定义注册表重建并保存 Manifest；golden 测试继续验证 | Phase 2 |
| R-002 | 论文方程与旧 Julia 行为可能不完全一致 | 保留 `PAPER2024` 与 `JULIA` 两种明确模式 | Phase 2 |
| R-003 | 分布式弹簧邻居复杂度高 | 先建立小规模 gather oracle，再实现 cell-linked list | Phase 3 |
| R-004 | 目标服务器工具链尚未确定 | 本地 GNU/MPI 为基线，服务器 optfile 在 Phase 5 单独建立 | Phase 5 |
| R-005 | 一般网格迁移不能直接继承 FLT | Phase 6 后置并建立专门拓扑测试 | Phase 6 |
| R-006 | GitHub 仓库当前关闭 Issues | 暂用阶段分支、提交和本状态账本记录；启用 Issues 后补建阶段 Issue | 不阻塞源码开发 |
| R-007 | 固定 Julia 提交的自带测试调用不存在的函数；默认场失败时只警告 | 不修改参考源码；保存失败证据，另建 BOM 解析场和 smoke/golden 测试 | Phase 0/2 |
| R-008 | MITgcm 的 Fortran `STOP` 可能返回 0，截断文件也可能由运行时直接终止 | 驱动禁止只看退出码，同时识别正常结束、MITgcm 异常和 Fortran runtime error | Phase 0/CI |
| R-009 | Phase 1 海洋步内冻结环境场，对真实时变驱动不具高阶时间精度 | 输出明确标记 `STEP_END_FROZEN`；Phase 2 以 old/new 快照和 B05 升级 | Phase 2 |
| R-010 | Phase 1 pickup 只支持相同 MPI/tile 分解 | 写入并核对分解签名；变分解重启明确拒绝，后续单独设计 | Phase 5 |
| R-011 | P1.1 为小型验证文件采用每 rank 全量读取 | 以 `bomInitGlobalLimit` 硬限制；P1.5 前复核可扩展分片读取，禁止直接用于百万粒子 | Phase 1.5 |
| R-012 | P1.1 locator 只覆盖规则原生坐标初值分发 | 已由 P1.2 映射核心与兼容包装关闭；完整映射、P1.1 和 Phase 0 门禁已通过 | 已关闭 |
| R-013 | P1.2 插值组件未接入 `BOM_MAIN` 的已有粒子诊断路径 | 已实现非移动调用、上下文集体终止；串行/MPI4 权威状态 bitwise 不变门禁通过 | 已关闭 |
| R-014 | 映射初始化未完整拒绝累计溢出、派生非有限量和末端非有限 face | 已补强预溢出、派生量、双端点和周期算术检查；19/19 门禁通过 | 已关闭 |
| R-015 | P1.3 单 tile 阶段无法合法提交跨 owner 轨迹 | 每个 RK stage/final 离开当前 owner 时明确失败；P1.4 以迁移协议替换该边界 | Phase 1.4 |
| R-016 | EXF 已启用但 10 m `uwind/vwind` 未更新或被误标为 BOM 步末时刻 | source 同时要求 `ALLOW_EXF`、`useEXF`、`useAtmWind`；复制到 BOM 快照并分别记录 EXF 请求 `t0` 与海流步末 `t1` | Phase 1.3 |
| R-017 | RK2/RK4 可能被误解为对真实时变海洋场具有相同高阶精度 | P1.3 明确标记步末冻结场；只用稳态解析 fixture 验证积分器阶数，old/new 场留给 Phase 2 | Phase 2 |

## 5. 会话记录

### 2026-08-23：环境和参考锁

- 创建独立 WSL 源码、构建、运行、Julia 和 VS Code 环境；
- 完成 MITgcm 串行/MPI 基线；
- 建立阶段化开发方案；
- 配置仓库级作者 `WangYuLin <wang111936@outlook.com>`；
- 采用 `MITGCM-BOM/phase-NN-topic` 分支命名；
- 固定 Julia 参考提交和自定义注册表；
- 发现并记录上游缺少根级 Manifest 的可复现性风险。
- Julia 固定环境实例化和包加载成功；上游测试的陈旧接口错误已复现并记录。
- GitHub Issues 当前关闭，阶段 Issue 创建请求返回 HTTP 410，已采用仓库内账本作为当前替代记录。
- 创建并推送 P0.1 提交 `ff1ab313d348fc0219e6e192bcbab928eb49e7e7`；
- 创建 GitHub PR #1，目标为 `MITGCM-BOM/development`，`master` 未修改。

### 2026-08-23：P0.2 可编译空骨架

- 创建 `MITGCM-BOM/phase-00-skeleton`，基于 P0.1 已发布提交；
- 实现 `pkg/bom` 的最小稳定控制接口和零粒子安全检查；
- 只登记包依赖，未加入 MITgcm 核心生命周期调用；
- 串行和双进程 MPI 构建、链接及 exp2 运行通过；
- 8/8 checkpoint 与冻结基线一致，串行/MPI 之间也一致；
- P0.2 证据保存在 `verification/bom/phase00-skeleton`。
- 创建并推送 P0.2 提交 `eee711c9b5aea0644ffb54fc5a08c544d2d7919e`；
- 创建 draft PR #2，基分支暂为 P0.1 分支，确保差异只包含 P0.2；
- PR #1 合并后，应将 PR #2 基分支改为 `MITGCM-BOM/development`。

### 2026-08-23：P0.3 生命周期注册

- 创建 `MITGCM-BOM/phase-00-lifecycle`，基于 P0.2 已发布提交；
- 注册 `useBOM`、包状态输出以及读取/检查/初始化/时间步调用；
- 四套串行/MPI、编译开/关构建全部通过；
- 六套正向运行均正常结束并通过 48/48 checkpoint 校验；
- 两项负向配置均在预期检查点终止；
- 发现 Fortran `STOP` 退出码不可靠，登记为 R-008；
- P0.3 证据保存在 `verification/bom/phase00-lifecycle`。
- 创建并推送 P0.3 提交 `7e156a418b6d3f345298edeadbe7af73c938a1c7`；
- 创建 draft PR #3，基分支暂为 P0.2 分支，确保差异只包含 P0.3；
- PR #2 合并后，应将 PR #3 基分支调整到当时的集成基线。

### 2026-08-23：P0.4 正式零粒子门禁

- 创建 `MITGCM-BOM/phase-00-zero-particle`，基于 P0.3 已发布提交；
- 固化正式零粒子配置、4-rank 网格、负向配置和需求追踪表；
- 建立日志感知、哈希校验、外部隔离且不可覆盖历史证据的测试驱动；
- 四套构建、三套正向运行、24/24 哈希和两项负向门禁全部通过；
- 正式证据保存在 `verification/bom/phase00-zero-particle`；
- 本工作包没有修改 `pkg/bom`、MITgcm 核心源码或加入任何粒子物理。
- 创建并发布 P0.4 提交 `1e5bda7e4375db5520446fb715849e199725642a`；
- 创建 draft PR #4，基分支暂为 P0.3 分支，确保差异只包含 P0.4；
- PR #3 合并后，应将 PR #4 基分支调整到当时的集成基线。

### 2026-08-23：P0.5 Phase 0 最终门禁

- 创建 `MITGCM-BOM/phase-00-final-gate`，基于 P0.4 已发布提交；
- 建立锁定提交/校验和检查、离线实例化和 8 项纯函数 Julia smoke；
- 使用 `p05-attempt01` 从全新目录重跑完整 P0.4 门禁并通过；
- 完成 Phase 0 退出条件审计、参考锁边界说明和 PR #1—#5 合并方案；
- 当前不自动合并任何 PR，不创建标签，也不开始 Phase 1；
- P0.5 证据保存在 `verification/bom/phase00-final-gate`。
- 创建并发布 P0.5 功能提交 `6d705ed68d8d497597984d6c266a4954cd3b7ab8`；
- 创建 draft PR #5，基分支暂为 P0.4 分支，确保差异只包含 P0.5；
- PR #4 合并后，应将 PR #5 基分支调整到当时的集成基线。

### 2026-08-23：Phase 0 顺序集成与合并后门禁

- PR #1—#5 依次重定向、复核并使用 merge commit 合并到 `MITGCM-BOM/development`；
- 最终集成提交为 `2baea214fe1f898e16df4953892c142a07b82111`；
- 使用唯一测试 ID `p05-integrated-attempt01` 在最终集成提交上完成 P0.5 全量门禁；
- Julia 8/8、P0.4 的 4/4 构建、3/3 正向运行、24/24 哈希和 2/2 负向门禁全部通过；
- 同名测试 ID 的再次运行在写入前按预期拒绝，开发工作树保持干净；
- 创建 `MITGCM-BOM/phase-00-integration-record`，只记录集成事实和阶段状态；
- 以 `WangYuLin <wang111936@outlook.com>` 发布记录提交 `4e4f616d7ec97ec6e79a63879a2315e201cf47b1` 并创建 PR #6；
- PR #6 已使用 merge commit 合并，集成分支更新到 `b2f3ecf1081f7bab25749c4a6004730175d99955`；
- 已由 `WangYuLin <wang111936@outlook.com>` 创建并推送 annotated tag `MITGCM-BOM-v0.1`；
- tag object 为 `eb3a5e9372fa7f2c437c81384322667a3bb2cfd1`，peeled commit 为 `b2f3ecf1081f7bab25749c4a6004730175d99955`；
- 未创建 GitHub Release；标签发布后才开始 Phase 1 设计。

### 2026-08-23：P1.0 BOM-Lite 设计冻结

- 从 `MITGCM-BOM-v0.1` 基线创建 `MITGCM-BOM/phase-01-design`；
- 只读核对当前 BOM 空骨架、FLT 状态/映射/迁移/pickup 和锁定 Julia `Leeway!`；
- 冻结 Phase 1 状态、初始文件、环境场、RK、owner 迁移、轨迹、pickup 和 FLT 共存边界；
- 明确 Julia leeway 不含 Stokes，Phase 1 仅允许 `bomStokesSource='NONE'`；
- 把实现拆为 P1.1—P1.5，每个工作包有独立门禁；
- 以 `WangYuLin <wang111936@outlook.com>` 创建设计提交 `34cad7bd9c0d6bef3c9681dfb254d449cacbd6ac`；
- 发布分支并创建 draft PR #7：`https://github.com/wang111936/MITgcm/pull/7`；
- GitHub 记录为 6 个 Markdown 文件、766 行新增、14 行删除；
- 当前工作包只修改 Markdown，未实现粒子运动。

### 2026-08-23：P1.0 集成与 P1.1 状态/初值

- 最终审查 PR #7：2 个提交、6 个 Markdown、相对集成分支 ahead 2/behind 0，无评审线程或状态检查；
- 将 PR #7 标记 ready，并以 merge commit `acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f` 合并；
- 从更新后的 `MITGCM-BOM/development` 建立 `MITGCM-BOM/phase-01-state`；
- 实现 Phase 1 每 tile SoA、参数、确定性清零、schema 1 初值读取、64 位 ID 恢复、初值 owner 和容量检查；
- `p11-state-attempt01` 早期矩阵通过，补齐覆盖后由 attempt05 取代；
- `p11-state-attempt02` 暴露固定格式 72 列错误，`attempt03` 暴露截断文件运行时错误判据缺口；两个问题均修复且失败证据保留；
- `p11-state-attempt04` 的扩展矩阵通过；最终文件同步后，权威 `attempt05` 再次完成 4 构建、7 正向、16 负向并全部通过；
- `p11-phase0-regression-attempt03` 在最终源码上完成 Phase 0 总回归并通过；
- 形成 P1-D013，拆分 P1-S04/P1-N03 的跨工作包验收边界；
- 以 `WangYuLin <wang111936@outlook.com>` 创建功能提交 `c5ee5549a504ed428f152bbc5022368095a1752d`，推送阶段分支并创建 draft PR #8；
- 当前尚未加入 P1.2 环境场/通用映射或 P1.3 粒子运动。

### 2026-08-23：P1.1 正式审查修复

- 正式只读审查发现 locator 对 overlap-one 的潜在越界、MDS meta 未验证、P1-S01/P1-S04a 缺少逐字段证据以及 P1-C01/P1-Z01 当前源码矩阵不完整；
- 修复 locator owner-cell 循环，并增加 MITgcm 核心约束下的 OL1 locator-only GNU bounds-check 初始化；
- 使用原生 `MDS_READ_META` 校验维度、float64、记录数和 `BOMV0001`，新增 missing meta、bad meta schema、trailing record 负测；
- `p11-state-review-fixes-attempt03` 完成 8/8 构建、14/14 正向、19/19 负向和 104/104 适用海洋哈希；
- `p11-review-fixes-phase0-attempt01` 完成 Phase 0 最终回归；
- 以 `WangYuLin <wang111936@outlook.com>` 创建审查修复提交 `2c688a7e90d1bdd814a8bd8b0ef5db63c7d67a65`；
- PR #8 保持 draft，未合并、未创建 `MITGCM-BOM-v0.2` 标签，下一步为独立复审。

### 2026-08-23：P1.1 独立复审与物理长度修复

- 独立复审构造 meta/header 均声明 128 字节、实际 `.data` 为 192 字节的输入，程序正常结束并静默忽略额外粒子记录；复现证据为 `p11-rereview-physical-trailing-attempt01`；
- 在 `BOM_READ_INITIAL` 中镜像全局 MDS 文件名优先级，以 64 位整数校验实际物理长度，要求精确等于 `(nParticles+1)*8*8` 字节；
- 扩展负测为 64 字节截断、192 字节完整额外记录和 129 字节单字节尾随，三者对 128 字节预期长度均由 BOM 主动拒绝；
- `p11-physical-size-fix-attempt01` 完成 8/8 构建、14/14 正向、20/20 负向和 104/104 适用海洋哈希；summary SHA-256 为 `93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7`；
- `p11-physical-size-fix-phase0-attempt01` 完成 Phase 0 最终回归；summary SHA-256 保持 `e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2`；
- 以 `WangYuLin <wang111936@outlook.com>` 创建物理长度修复提交 `40f5754b3b00ea4bb6a9b20c64c10e968080ad24`；
- PR #8 继续保持 draft，未合并、未创建标签，下一步为修复后的最终独立复审。

### 2026-08-23：P1.1 最终独立复审与文档同步

- 复审时 PR #8 相对 `MITGCM-BOM/development@acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f` 为 6 个提交、31 个文件、ahead 6/behind 0，head 为 `54eb37bd49970091fffed5091ec96939d73b6d7f`；PR 可合并但保持 draft，且无状态检查、工作流、评审或评审线程；
- 重新核对生产实现、8 项构建、34 项正负运行结果和 13 组 checkpoint 记录，未发现剩余源码或测试问题；
- 在 `/home/wyl/runs/mitgcm-bom/phase01-state/p11-final-rereview-bare-prefix-attempt01` 以 128 字节 bare prefix 和 192 字节 `.data` 并存探测优先级；程序选择 bare prefix、仅有一个 owner 并正常结束；
- 发现唯一恢复入口仍引用旧门禁，且权威设计决定表缺少 P1-D014；已仅同步四份 Markdown，不改生产源码、门禁或输入；
- 权威 P1.1/Phase 0 门禁后的变更仅为文档，因此未重复执行完整编译矩阵；
- PR #8 保持 draft，未标记 Ready、未合并、未创建标签，等待明确授权。

### 2026-08-23：PR #8 进入 Ready

- 获得用户明确授权后，将 PR #8 从 draft 标记为 Ready for review；
- 转换前 head 为 `32e6bafeb4d28427bc138d5390a11d86b65d0675`，PR 为 7 个提交、31 个文件、ahead 7/behind 0 且可合并；
- 未合并 PR、未创建标签、未加入 P1.2+ 范围；
- 下一步等待明确的 merge commit 合并授权，集成后必须复跑 P1.1 与 Phase 0 门禁。

### 2026-08-24：PR #8 合并与集成回归

- 合并前 PR #8 为 Ready、head `d39a878ef647f5e4dbc2b47ef694563848ce8ba4`、8 个提交、31 个文件、ahead 8/behind 0 且可合并，无状态检查、工作流、评审或评审线程；
- 获得明确授权后使用 merge commit 合并，集成提交为 `ab30b3dc530404fda796189e50b8de776bf4441d`，双亲为 `acb51051ecc92ffccdf9f368c6d5aa8dc4049f6f` 和 `d39a878ef647f5e4dbc2b47ef694563848ce8ba4`；
- `p11-integrated-pr8-attempt01` 在集成提交上通过 8/8 构建、14/14 正向、20/20 负向和 104/104 checkpoint；证据位于 `/home/wyl/{build,runs}/mitgcm-bom/phase01-state/p11-integrated-pr8-attempt01`；
- `p11-integrated-pr8-phase0-attempt01` 通过锁定参考、离线 Julia、BOM smoke 与 P0.4 的 4 构建、3 正向、24 checkpoint 和 2 负向；证据位于 `/home/wyl/runs/mitgcm-bom/phase00-final-gate/p11-integrated-pr8-phase0-attempt01`；
- 两个主摘要 SHA-256 分别为 `93ee38612edbfd5511fe897d9685c05c08d1f9dd4664b34f929396463f01a9d7` 和 `e835570901ff57a5c04743297b25c1ab2159858cf11e86322aece872e5b114f2`，与合并前权威结果一致；
- 从集成提交建立 `MITGCM-BOM/phase-01-state-integration-record`，以提交 `804d80e1820a7a00376b659a372182373e215249` 记录集成证据并创建 draft PR #9；未创建标签、未开始 P1.2。

### 2026-08-24：PR #9 最终独立复审

- 复审快照：base `ab30b3dc530404fda796189e50b8de776bf4441d`、head `ad37693c89c5d251a2bab39ce39780819ae7a9a5`、2 个提交、3 个 Markdown、ahead 2/behind 0、可合并且保持 draft，无状态检查、工作流、评审或评审线程；
- 远端完整补丁未包含 Fortran、脚本、生成器、输入、测试数据、标签或 P1.2 实现；
- 原始证据核对为 42/42 P1.1 结果 PASS、13 份 checkpoint 日志共 104 行、4/4 Phase 0 总门禁结果 PASS、9/9 嵌套 P0.4 结果 PASS；merge commit 双亲和三份摘要哈希均与记录一致；
- 发现并修正三类文档一致性问题：合并前门禁仍称“当前权威”、P1.2 仍写“等待 P1.1 门禁”、恢复点仍停留在“待独立复审”；
- 修复仅涉及现有 3 个 Markdown，生产源码、门禁和证据不变，因此未重复执行编译矩阵；
- PR #9 保持 draft，未标记 Ready、未合并、未创建标签，等待明确授权。

### 2026-08-24：PR #9 进入 Ready

- 获得用户明确授权后，将 PR #9 从 draft 标记为 Ready for review；
- 转换前 head 为 `84bdaf92aed41b7f976d44f1143ad1dc1e201218`，PR 为 3 个提交、3 个 Markdown、ahead 3/behind 0 且可合并；
- 未合并 PR、未创建标签、未开始 P1.2；
- 下一步等待明确的 merge commit 合并授权。

### 2026-08-24：PR #9 合并与 P1.2 接口冻结

- 合并前 PR #9 为 Ready、head `09a9590456c6e50072ce707607011fd535c523b3`、4 个提交、3 个 Markdown、ahead 4/behind 0 且可合并，无状态检查、工作流、评审或评审线程；
- 获得明确授权后以 merge commit `320a07d5eb2e2795ddd1e0b93ceaddd6c32a1621` 合并，双亲为 `ab30b3dc530404fda796189e50b8de776bf4441d` 和 `09a9590456c6e50072ce707607011fd535c523b3`；
- 本地 `MITGCM-BOM/development` 已快进到合并提交，PR 描述已记录最终状态，工作树干净且没有 `MITGCM-BOM-v0.2` 标签；
- 从该提交建立 `MITGCM-BOM/phase-01-mapping-environment`，仓库提交身份保持 `WangYuLin <wang111936@outlook.com>`；
- MITGCM-BOM 环境自检再次通过 GNU Fortran 11.4、OpenMPI 4.1.2、NetCDF、fortls、Julia 1.10.12 和 MPI smoke；
- 只读审计 MITgcm FLT 映射/插值、`ROTATE_UV2EN_RL`、现有 BOM 状态与锁定 Julia `Leeway!`；没有读取或修改其他开发工程；
- 冻结 P1.2 数据布局、域界、完整 360° 球面周期规范化、正反映射、owner/stencil 分离、C-grid 转 east/north、标量 halo exchange、湿点 pair 插值和失败语义；
- 新增 P1-D015—P1-D020，并把 P1-R05—P1-R07、P1-M01/M02、P1-F01—F03、P1-N04/N05 反向绑定到冻结接口；P1-D020 专门防止负分数 overlap 被 Fortran `INT` 向零截断后错选 stencil；
- 以 `WangYuLin <wang111936@outlook.com>` 创建设计提交 `4d7bfa8dae16e8ca23d96043b6207a4b91a95f3e`，推送 `MITGCM-BOM/phase-01-mapping-environment` 并创建 Draft PR #10；
- PR #10 初始范围为 1 个提交、6 个 Markdown、ahead 1/behind 0，无状态检查或工作流；
- 本次设计增量仅为 Markdown，尚未实现生产 Fortran 或运行编译矩阵；下一增量从映射内核与 P1-M01/P1-M02/P1-N04 开始。

### 2026-08-24：P1.2 首个映射增量

- 在 `MITGCM-BOM/phase-01-mapping-environment` 实现映射状态、360° 球面周期规范化和规则网格正反映射；
- 保持 P1.1 `BOM_LOCATE_INITIAL` 未修改，没有建立速度场、插值环境场或移动粒子；
- 权威 `p12-map-20260824-b` 通过 regular debug、实际 OpenMP、实际 EXCH2 三套构建及 P1-M01/P1-M02/P1-N04 共 14/14 summary 行；
- 非权威 `p12-map-20260824-a` 因固定格式字符串越过 72 列在编译期失败，修复后保留该失败目录且未覆盖；
- `p12-regression-p11-20260824` 再次通过完整 P1.1 门禁，`p12-regression-p05-20260824` 再次通过 Phase 0 总门禁；
- 以 `WangYuLin <wang111936@outlook.com>` 创建功能提交 `633d3f9af75b4a052303ec0d0a06edf40677e18c`；
- Draft PR #10 保持 Draft，不创建 `MITGCM-BOM-v0.2` 标签，不开始 P1.3；下一增量只处理 locator 兼容包装与对应回归。

### 2026-08-24：P1.2 locator 兼容包装

- 将 `BOM_LOCATE_INITIAL` 收敛为 `BOM_MAP_XY2IJLOCAL` 的兼容包装，删除旧的直接 `xG/yG` 搜索；
- 保留 P1.1 公共接口、半开 owner 和 `maskC(NINT(ix),NINT(jy),1)>0` 中心湿点判据，不要求四点 stage stencil；
- `p12-locator-20260824-a` 一次通过 15/15 summary 行，包含新包装源审计及原映射/拒绝矩阵；
- `p12-locator-regression-p11-20260824` 通过完整 P1.1 门禁，`p12-locator-regression-p05-20260824` 通过 Phase 0 总门禁；
- 以 `WangYuLin <wang111936@outlook.com>` 创建功能提交 `14636cda2bc9da61da784752b1dec11e54d518f1`；
- P1-R05 标记完成，P1.2 仍进行中；PR #10 保持 Draft，不创建标签、不开始 P1.3；
- 下一增量只实现表层 C-grid 字段存储与 `BOM_BUILD_FIELDS`，建立 P1-F01/P1-F02 证据。

### 2026-08-24：P1.2 表层环境场构造

- 在冻结形状上增加 `bomGridUWork/bomGridVWork/bomGridVEast/bomGridVNorth`，初始化与重建状态均为确定值；
- 实现 `BOM_BUILD_FIELDS`：复制表层、真实 C-grid colocation/旋转、east/north 两次标量 halo exchange、非有限与干点检查，最后发布 metadata；
- `p12-field-20260824-a` 首轮通过 7/7 字段门禁；`p12-20260823T214951Z-501860`、`20260823T215044Z-548609` 和 `20260823T215320Z-668561` 分别通过映射 15/15、P1.1 42/42 和 Phase 0 4/4；
- 以 `WangYuLin <wang111936@outlook.com>` 创建功能提交 `50dd6a6ab7e92ac5ca26ab4666ce2e45d7495899`；
- P1-R06 标记完成；未实现 `BOM_INTERP_WET_PAIR`、P1-F03/P1-N05 或任何粒子运动；
- PR #10 保持 Draft，不创建 `MITGCM-BOM-v0.2` 标签，不开始 P1.3；下一增量只处理湿点 pair 插值。

### 2026-08-24：P1.2 湿点 pair 插值

- 实现 `BOM_INTERP_WET_PAIR`：实数范围预检、数学 floor、四点有限性检查、共同湿权重和显式无效返回；
- `p12-interp-20260824-a` 首轮通过 9/9；插值后字段 7/7、映射 15/15、P1.1 42/42、Phase 0 4/4 全部通过；
- 以 `WangYuLin <wang111936@outlook.com>` 创建功能提交 `597d1a706de2ca388d1312dd6bb667421ae9adc7`；
- P1-R07 标记完成，P1-R05—P1-R07 的生产实现和执行证据已齐备；
- 未实现粒子 RHS、位置推进、owner 迁移、风或 Stokes，也未开始 P1.3；
- PR #10 保持 Draft，不创建 `MITGCM-BOM-v0.2` 标签；下一步只做 P1.2 最终范围审计和独立复审。

### 2026-08-24：P1.2 最终范围与契约审计

- 冻结审计快照为 `development@320a07d5eb2e2795ddd1e0b93ceaddd6c32a1621..f9b6098d657b6749130cdbdbb0ce091f73c99a9c`；PR #10 为 Draft、可合并，10 个提交、56 个文件，无评审或未解决线程；
- 完整 diff 仅位于 `pkg/bom`、`verification/bom` 和 `doc/phys_pkgs/MITGCM-BOM`，`git diff --check` 通过，未触及核心调度、FLT、其他工程或生成物；
- 重算插值、字段、映射、P1.1、Phase 0 和嵌套 P0.4 的六个 summary SHA-256，均与记录一致；P1.1 104/104 和 P0.4 24/24 checkpoint 均为 `OK`；
- 审计发现阻断项 R-013：`BOM_MAIN` 非零粒子路径只构造字段，未执行冻结契约要求的已有位置映射/插值诊断，也没有调用层 P1-N05 上下文终止；
- 审计发现必须修复项 R-014：映射累计 span、派生界限/容差及末端 stored face 的有限性防护与负测不完整；
- P1-R06 保持完成；P1-R05/P1-R07 在修复和新证据通过前重新开放；PR #10 继续保持 Draft，不合并、不打标签、不开始 P1.3；
- 下一步唯一任务是在 P1.2 范围内先补生产诊断调用层和对应生命周期/P1-N05 门禁，再补映射有限性防护，随后按风险复跑全部前序门禁并更新审计为 PASS。

### 2026-08-24：P1.2 审计修复与复审关闭

- 功能提交 `2f346d98cf978922cae53bff67fc32088cbb8941` 完成 R-013/R-014，且不引入 RHS、位置更新、release 转换、owner 迁移、风或 Stokes；
- `p12-interp-auditfix-20260824-c` 通过 15/15，包含串行/MPI4 生产生命周期及域外/低湿权重调用层终止；summary SHA-256 为 `aaff9205a4f5faa580d06fe55b18720bbcd42a72667caae7b5f27fd4632c13d4`；
- `p12-map-auditfix-20260824-b` 通过 19/19，包含非有限原点/间距、累计溢出、非有限末端 face 和正负极端有限经度；summary SHA-256 为 `926575f1093bb7353f09e9835e175289a309c13e653ded5a96871e06b3810c02`；
- 字段、P1.1、Phase 0 和嵌套 P0.4 重新通过 7/7、42/42、4/4 和 9/9，其 summary SHA-256 均与既有权威值一致；
- 三个非权威尝试目录保留且未覆盖；其暴露的 NaN trap、生命周期 fixture 和 MPI stderr 聚合问题均已在权威运行前修正；
- P1.2 范围与契约审计更新为 PASS，P1-R05—P1-R07 和 R-013/R-014 关闭；PR #10 保持 Draft，不合并、不打标签、不开始 P1.3。

### 2026-08-24：PR #10 进入 Ready

- 获得用户明确授权后，将 PR #10 从 Draft 标记为 Ready for review；
- 状态复核为 open、未合并、可合并，head `07f428f9dcf37c2e5f998020a63abadc2df702bf`，13 个提交、58 个变更文件；
- PR 说明已同步 Ready 状态和权威证据；当前无 review 和 review thread；
- 本次状态变更不授权合并、标签或 P1.3；下一步等待单独的 merge commit 合并授权。

### 2026-08-24：PR #10 合并与合并后集成回归

- 获得用户单独授权后，使用 merge commit 合并 PR #10；集成提交为 `fe51332e1b95e145c38118fd2bd55f26cd20a6a3`，两个父提交为 `320a07d5eb2e2795ddd1e0b93ceaddd6c32a1621` 和 `37ec55dd5d0764b73f05e6125cb6f6cc847a7695`；
- 合并后 mapping `p12-integrated-pr10-map-20260824-a` 19/19、fields `p12-integrated-pr10-field-20260824-a` 7/7、interpolation/lifecycle `p12-integrated-pr10-interp-20260824-a` 15/15 全部 PASS；
- P1.1 `p12-integrated-pr10-p11-20260824-a` 42/42 且 104/104 checkpoint，Phase 0 `p12-integrated-pr10-phase0-20260824-a` 4/4，嵌套 P0.4 `-p04` 9/9 且 24/24 checkpoint，全部 PASS；
- 六份 summary SHA-256 与合并前权威值完全一致，无非 PASS 行；所有 `-a` 运行均为首次通过，未复用或覆盖证据目录；
- 从 merge commit 建立 `MITGCM-BOM/phase-01-mapping-environment-integration-record` 分支归档纯文档证据；未创建 `MITGCM-BOM-v0.2` 标签，未开始 P1.3。
- 以 `WangYuLin <wang111936@outlook.com>` 创建集成证据提交 `069452a52dda32109e2510348af553692387f1bf`，推送记录分支并创建 Draft PR #11；下一步只进行独立文档与证据复审。

### 2026-08-24：PR #11 独立集成记录复审

- 冻结复审快照为 `development@fe51332e1b95e145c38118fd2bd55f26cd20a6a3..e54badeb6257e62506a91994d1ddf741f70de58b`；PR #11 为 open、Draft、可合并，ahead 2/behind 0，无 review 或 review thread；
- GitHub 完整 patch 只含 6 个 Markdown，`git diff --check` 通过，没有源码、测试输入、运行产物、无关工程或禁止词；
- merge commit 与两个父提交复核一致；两个记录提交的作者和提交者均为 `WangYuLin <wang111936@outlook.com>`；
- 六份 summary 哈希重算与记录一致，无非 PASS 行；P1.1 104/104 和 P0.4 24/24 checkpoint 全为 `OK`；
- 本地/远端均无 `MITGCM-BOM-v0.2` 标签，无 P1.3 变更；独立复审结论为 PASS、无 finding；
- PR #11 保持 Draft，等待明确授权后才可标记 Ready；不合并、不打标签、不开始 P1.3。
- 以 `WangYuLin <wang111936@outlook.com>` 创建审计记录提交 `a74064438af6bae79b6526e854a14ca46daf456e`，并将 PR #11 说明同步为“PASS、无 finding”。

### 2026-08-24：PR #11 Ready、合并与 P1.2 收口回归

- 获得用户分别授权后，将 PR #11 标记 Ready，并锁定 head `7cb3afa9cfc8485e2c32e3e40420570c2f835c48` 使用 merge commit 合并；
- 合并提交为 `34edbc50c849379e3d4b3456f81c673c7801945b`，父提交为原 `development@fe51332e1` 与 PR head `7cb3afa9c`；合并范围严格为 7 个 Markdown；
- 合并后 mapping `p12-integrated-pr11-map-20260824-a` 19/19、fields `p12-integrated-pr11-field-20260824-a` 7/7、interpolation/lifecycle `p12-integrated-pr11-interp-20260824-a` 15/15，均 PASS；
- P1.1 `p12-integrated-pr11-p11-20260824-a` 42/42 且 104/104 checkpoint；Phase 0 `p12-integrated-pr11-phase0-20260824-a` 4/4，嵌套 P0.4 `-p04` 9/9 且 24/24 checkpoint，均 PASS；
- 六份 summary 无非 PASS 行，SHA-256 与 PR #10 合并后的确定性权威值一致；本地 `development` 与远端同步且工作树干净；
- 从 merge commit 创建 `MITGCM-BOM/phase-01-mapping-environment-closeout` 纯文档分支并新增 `P1.2_CLOSEOUT.md`；
- 以 `WangYuLin <wang111936@outlook.com>` 创建收口提交 `bea1df4d00fdd2fe562dd8712cc5ca5156ba1af9`，推送分支并创建 Draft PR #12；下一步只做独立范围与证据复审；
- 未创建 `MITGCM-BOM-v0.2` 标签，未开始 P1.3。

### 2026-08-24：PR #12 收口独立复审与修复

- 初审冻结范围为 `development@34edbc50c849379e3d4b3456f81c673c7801945b..4aea0ca9d375e267f3a583feb2cf02dd452989f2`，完整 patch 为 7 个 Markdown；
- 初审发现唯一阻断项：`P1.2_CLOSEOUT.md` 使用 `HEAD^1..HEAD` 描述 PR #11 merge diff，在当前 PR head 上实际只返回 3 个文件；
- 以 WangYuLin 身份创建修复提交 `b43a702a5197f115a956944973a00a0587a43ebc`，改用固定 merge SHA 的 first-parent 范围；该范围稳定返回 PR #11 的 7 个 Markdown；
- 修复后冻结范围为 `34edbc50c849379e3d4b3456f81c673c7801945b..b43a702a5197f115a956944973a00a0587a43ebc`，ahead 3/behind 0，三个项目提交身份均正确；
- 六份 summary 哈希重算一致且仅含 PASS；P1.1 104/104 和 P0.4 24/24 checkpoint 全为 `OK`；
- 复审结论更新为 PASS、无开放 finding；PR #12 保持 Draft，不合并、不打标签、不开始 P1.3。
- 以 `WangYuLin <wang111936@outlook.com>` 创建审计记录提交 `90dc64857ee2411edfcb1905d429fd294785012d`。

### 2026-08-24：PR #12 合并与 P1.3 接口冻结

- 在用户明确授权后将 PR #12 标记 Ready，并使用 merge commit 合并到 `MITGCM-BOM/development`；合并提交为 `eefca92fe53f1b144bbfca7fcf00dc949a22afb3`；
- PR #12 合并对象父提交为 `34edbc50c849379e3d4b3456f81c673c7801945b` 与 `333e1c0b0043e79d8e319127d6744d5a9f93e2db`，合并内容为 8 个 Markdown；
- 本地 `development` 已同步且工作树干净，本地/远端仍无 `MITGCM-BOM-v0.2` 标签；
- 从 `eefca92fe` 创建 `MITGCM-BOM/phase-01-single-tile-integration`；没有读取或修改其他开发工程；
- 只读审计当前 BOM/P1.2 生命周期、MITgcm `forward_step`/FLT、EXF 10 m 风接口和锁定 Julia `Leeway!`；
- 冻结 `[myTime-deltaTClock,myTime]` 等长子步、精确 release 分割、`water+coeff*wind` SI RHS、Cartesian/球面坐标率、显式中点 RK2、经典 RK4、stage CFL/owner 硬检查和试算后提交；
- 形成 P1-D021—P1-D029，并把 P1-S04b、P1-N06、P1-N08、P1-I01—I06 反向绑定到计划生产接口；其中 P1-D029 明确记录 EXF 请求时刻 `t0` 与海流步末 `t1`；
- 本增量只修改 Markdown，不实现 Fortran、脚本或测试输入，因此不运行编译/运行矩阵；下一步为设计范围审计、WangYuLin 提交、推送和 Draft PR。

## 6. 每次会话结束时必须更新

1. 当前任务分支、当前工作包和下一工作包；
2. 本次新增提交 SHA；
3. 实际运行的测试及结果路径；
4. 新风险、阻塞项和设计决定；
5. 阶段完成度及退出条件；
6. 下一次开始时唯一、具体、可执行的任务。
