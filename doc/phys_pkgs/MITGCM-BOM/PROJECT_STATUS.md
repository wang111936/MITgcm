# MITGCM-BOM 项目状态账本

> 本文件是跨会话恢复工作的唯一状态入口。每次开发结束前必须更新“当前恢复点”“阶段状态”和“会话记录”。

| 项目 | 当前值 |
|---|---|
| 最后更新 | 2026-08-27 |
| 权威开发仓库 | `/home/wyl/projects/mitgcm-bom` |
| GitHub 仓库 | `wang111936/MITgcm` |
| 上游仓库 | `MITgcm/MITgcm` |
| 集成分支 | `MITGCM-BOM/development` |
| 当前任务分支 | `MITGCM-BOM/p3.0-interface-freeze` |
| 当前阶段 PR | Draft PR #26：远端范围复审 PASS，保持未合并且未获合并授权 |
| 当前阶段 | Phase 3：非线性弹簧和分布式邻居（进行中） |
| 当前工作包 | P3.0 完成：本地审计 12/12，PR #26 为 9 个 Markdown、ahead 2/behind 0 |
| 下一工作包 | 获得明确授权并集成 PR #26 后，进入 P3.1 参数/代码、geometry、KNN oracle 和 spring laws |
| 当前阻塞 | 无 |

## 1. 当前恢复点

下一次继续开发时，从以下任务开始：

1. 读取 [Phase 3 阶段记录](PHASE_RECORDS/PHASE-03.md) 和
   [P3.0 验证入口](../../../verification/bom/phase03-springs-neighbors/README.md)；
2. 核对冻结提交 `e81ddaa521e5f3babe54ba0ac8964c3dae058f88` 的
   `P3.0_DOC_AUDIT PASS 12/12` 和 `P3.0_DESIGN_AUDIT.md`；
3. 核对 Draft PR #26 仍以 `MITGCM-BOM/development` 为 base、以
   `MITGCM-BOM/p3.0-interface-freeze` 为 head，且 behind 为 0；
4. 未经用户明确授权不得合并 PR #26，也不得创建 `MITGCM-BOM-v0.4`；
5. P3.0 集成后进入 P3.1；范围仅限参数/代码、canonical pair geometry、
   verification-only KNN oracle 和 stateless Hooke/eBOMB laws；
6. 保持 Ubuntu 22.04、GNU Fortran 11.4、OpenMPI 4.1.2 和 Julia 1.10.12
   为 Phase 3 本地基线。

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
| Phase 1 BOM-Lite | 完成 | v0.2 | 257/257、独立退出审计、PR #16 和 annotated tag `MITGCM-BOM-v0.2` 全部完成 | [Phase 1](PHASE_RECORDS/PHASE-01.md) |
| Phase 2 慢流形惯性 | 完成 | v0.3 | PR #20--#24 顺序集成；最终 390/390；独立退出审计 PASS | [Phase 2](PHASE_RECORDS/PHASE-02.md) |
| Phase 3 弹簧与邻居 | 进行中 | v0.4 | P3.0 完成；Draft PR #26 远端复审 PASS，等待明确合并授权 | [Phase 3](PHASE_RECORDS/PHASE-03.md) |
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

### P2.1 参数与 accepted endpoint 状态首增量

- 功能提交 `920e22fbdcdf7ceb59f2bd795cad86d116ac21af` 加入冻结参数、稳定代码和双端点 accepted storage；
- 权威 `p21-endpoint-920e22fbd-attempt01` 在干净精确提交上通过 13/13 summary 行；
- GNU 串行与 MPI4 构建、BOM 串行/MPI4 初始化、LEEW 零影响及 7 项负向门禁均 PASS；
- summary SHA-256 为 `29453e3305d6d6a43bb8b055995417109644e3a53dbf5a5f93b38e1969440293`；
- 本结果不关闭 P2.1：exact-time providers、事务发布、插值与 field pickup 仍待实现；
- 详细证据见 `verification/bom/phase02-endpoint-state/TEST_RESULTS.md`。

### P2.1 transactional ocean/NONE/NONE 端点增量

- 功能提交 `b81bb01293dbc4279db544174efe9558382115a3` 增加独立 scratch、fresh/normal transaction 和 production hooks；
- ocean 复制表层 C-grid 后旋转/共置并交换标量 halo；NONE wind/Stokes 发布湿点有效的精确零；
- continuity 和 source failure 直接测试证明 accepted metadata、fields、validity 全部不变；
- 权威 `p21-transaction-b81bb0129-attempt01` 在精确提交上 15/15 PASS；
- summary SHA-256 为 `7f6bd0426866908bd83a79ae29cf9c11a96940ff795a1e6fe8ceedf76ddd8ee5`；
- 本结果不关闭 P2.1：EXF、FILES/COUPLER、时间插值和 field pickup 仍待实现；
- 详细证据见 `verification/bom/phase02-endpoint-state/TEST_RESULTS.md`。

### P2.1 exact-time EXF/FILES/COUPLER provider 增量

- EXF `43a79d1b1`、FILES `16ab457e3` 和 compiled COUPLER `6247ee6ba` 顺序实现 BOM-owned exact endpoints；
- COUPLER setter 分量复制 geographic C-point fields，分别验证完整性、mask、time 和 iteration，生产者内存永不 alias；
- source failure 在串行/MPI4 直接证明 accepted bracket bitwise 不变，clean retry 正常提交；
- P2-E05/N03/N04 覆盖 COUPLER sigma 合法行、PRECOMBINED/NONE 合法行、duplicate、missing/partial/stale/future/mixed/non-finite/dry-value；
- 权威 `p21-coupler-6247ee6ba-attempt01` 在精确提交上 32/32 PASS；
- summary SHA-256 为 `87375f0d0003f240854e4c5738982c007b7b84e422d9d00c195933a2d7314dec`；
- 证据根为 `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state/p21-coupler-6247ee6ba-attempt01`；
- P2.1 仍需 E06 stage-time interpolation 与 schema-2 field pickup，因此不关闭、不合并 PR #20、不打 v0.3 标签；
- 详细证据见 `verification/bom/phase02-endpoint-state/TEST_RESULTS.md`。

### P2.2 C-point 导数、球面度量与协变算子完成

- Cartesian 功能提交 `f2c86ddf73d2f0b8dc470ad6abcac68a48accaef`
  建立非均匀二阶梯度、stage-time derivative interpolation 与事务状态；
- 完整功能提交 `5d4b918318682bee99b871684f781fa0ceefa482` 加入
  spherical `tauSphere`、MITgcm `fCori`、metric validity 和 finite-checked
  covariant material derivative/vorticity；
- D05 直接验证 PAPER total-field 与 JULIA base-only vorticity candidates；
  模式特定 RHS 调度仍留给 P2.3，未提前宣称完成；
- `p22-derivative-5d4b91831-attempt01` 为 16/16，endpoint/provider 为
  34/34，schema-2 pickup 为 10/10，Phase-1/Phase-0 前序为 257/257；
- 关闭聚合共 18 组、317/317 PASS；证据根为
  `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p22-closure/`
  `p22-closure-5d4b91831-attempt02`；
- row audit SHA-256 为
  `8074e632d887e2e23bdb6233c2c1f8896ef098522b3dbc10a72a3b42e96ca163`；
  aggregate manifest SHA-256 为
  `1d4d4409a47e729d713066245f2942179ee04995452c931d87c46782ffdc2a40`；
- 前序生命周期 attempt01 仅因启动器未传 P1.4 已集成开关而在静态审计
  前停止；冻结集成配置 attempt02 为 13/13，无生产修改；
- 关闭证据 attempt01 仅因锁定 Julia 可执行文件不在普通 PATH 而停止；
  使用正式 Phase-0 门禁同一绝对路径的 attempt02 完成自验证；
- P2.2 标记完成，无开放实现 finding；P2.3 成为唯一下一工作包；
- 远端同步按完整工作包批量进行；Draft PR #20 仍属于 P2.1，未合并，
  也未创建 `MITGCM-BOM-v0.3`。

### P2.3 双模式慢流形 RHS 完成

- 功能提交 `fb004faf735e638c9248beabc49422b05aa09eb7` 增加独立
  `BOM_RHS_PAPER2024`、`BOM_RHS_JULIA` 和统一 stateless dispatcher；
- PAPER 路径使用 combined-total material derivative 与 total vorticity；
  JULIA 路径保持 weighted per-source derivative 与 base-current vorticity；
- 27 个稳定诊断分量、显式/预合成 Stokes policy、SI 参数、`fCori`、
  `tauSphere`、有限/溢出保护和 final-drift CFL 只在整次成功后发布；
- 权威 `p23-rhs-fb004faf7-attempt01` 为 18/18 PASS，串行/MPI4 的八条
  component records 位级一致，17 项 N06 注入均保持粒子 sentinels 不变；
- 同一精确头的 P2.2 为 16/16、P2.1 endpoint/pickup 为 34/34 与 10/10、
  Phase-1/Phase-0 前序为 257/257；19 组聚合总计 335/335 PASS；
- 关闭证据为 `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/`
  `p23-closure/p23-closure-fb004faf7-attempt01`；row audit 与 manifest
  SHA-256 分别为 `290b3626e8343ae389f2227425ddf4b3591b4fa2f3e8ed54a08090c7b418c13e`
  和 `9feacb71d499c8327b9d2b6ba5c61d6e53ffa7c521dd4e7aba93bc4b32a8fb42`；
- 19 份 summary、13 份原生 manifest、source/driver hashes、环境、精确
  source head 和空 Git 状态均通过自验证；
- P2.3 未接入 `BOM_MAIN`/RK、未改 pickup、未实现 B04/B05/B16；P2.4
  成为唯一下一工作包。无开放实现 finding，未创建 v0.3 tag。

### P2.4 stage-aware RK 与 locked Julia golden

- 功能提交 `4b2d09d40b96cd4408a64e1ee0d4716b7a6255ad` 完成每 stage
  exact-time field/derivative sampling、双模式 RHS 与事务 RK2/RK4；
- B04/B05 stage/RK 11/11，B16/N07 12/12，同头完整聚合 358/358 PASS；
- B16 固定步 RHS/RK2/RK4 成为 checksummed gating oracle；adaptive Tsit5
  保留为可重复但 non-gating 的上下文；
- P2.4 关闭提交 `618ccbe329b5e54287965bf3ffabb2b40932acb5`，PR #23 以
  merge commit `bb641b9d1c29efac9935e056cddd1e6b903005fe` 集成。

### P2.5 集成收口与 Phase 2 最终门禁

- 功能提交 `d37dccae7d7c219deeafbea5bee65b880a48efd0` 完成 live schema-2
  output/pickup、同分解 restart、1/2/4-rank 与 FLT/BOM coexistence；
- changed-decomposition restart 保持显式拒绝，不在 Phase 2 静默放宽；
- PR #20--#24 顺序 merge commit 集成，最终生产头为
  `f71e76e89864ab3c6f32de3770efca39f5f819e5`；
- 退出审计头 `db41805cda3a10fe9b96889c87069c6347788cbc` 只增加两个已集成
  P2.4 README 的 allowlist 路径，生产树与最终 development 一致；
- 权威 `p2-integrated-g01-db41805cd-attempt02` 为 390/390 PASS；row audit
  与 manifest SHA-256 分别为
  `d29712970d8de8db828c0611384de38f7680047c001494b3917cce4fc04e677a`
  和 `ce29af66b0a3b925cce2bc8c70a1a937aff94a621d3f6bc10b314e26b5a5b85c`；
- P2-R01--P2-R18 全部关闭，独立退出审计 PASS、无开放 finding；目标
  服务器 HPC 仍归 Phase 5，不阻塞 P3.0。

## 4. 未决问题与风险

| ID | 风险 | 当前处理 | 阻塞阶段 |
|---|---|---|---|
| R-001 | 上游 Julia 提交没有根级 Manifest | 固定重建环境与校验和；B16 fixed-step golden 已通过，保留上游限制记录 | 已裁决，不阻塞 |
| R-002 | 论文方程与旧 Julia 行为可能不完全一致 | `PAPER2024` 与 `JULIA` 分离实现并通过逐分量/轨迹门禁 | 已关闭 |
| R-003 | 分布式弹簧邻居复杂度高 | 先建立小规模 gather oracle，再实现 cell-linked list | Phase 3 |
| R-004 | 目标服务器工具链尚未确定 | 本地 GNU/MPI 为基线，服务器 optfile 在 Phase 5 单独建立 | Phase 5 |
| R-005 | 一般网格迁移不能直接继承 FLT | Phase 6 后置并建立专门拓扑测试 | Phase 6 |
| R-006 | GitHub 仓库当前关闭 Issues | 暂用阶段分支、提交和本状态账本记录；启用 Issues 后补建阶段 Issue | 不阻塞源码开发 |
| R-007 | 固定 Julia 提交的自带测试调用不存在的函数；默认场失败时只警告 | 不修改参考源码；保存失败证据，另建 BOM 解析场和 smoke/golden 测试 | Phase 0/2 |
| R-008 | MITgcm 的 Fortran `STOP` 可能返回 0，截断文件也可能由运行时直接终止 | 驱动禁止只看退出码，同时识别正常结束、MITgcm 异常和 Fortran runtime error | Phase 0/CI |
| R-009 | Phase 1 海洋步内冻结环境场，对真实时变驱动不具高阶时间精度 | Phase 2 old/new stage-time interpolation 与 B05 endpoint-refinement 已通过 | 已关闭 |
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
- 本增量只修改 Markdown，不实现 Fortran、脚本或测试输入，因此不运行编译/运行矩阵；范围、链接、编号、隔离词和身份审计均通过；
- 以 `WangYuLin <wang111936@outlook.com>` 创建设计冻结提交 `5240abcf808835f2163b4b358d4a00e99f3e7645`，推送独立分支并创建 Draft PR #13；下一步为独立设计复审。
- 独立复审从实际 `forward_step`、`LOAD_FIELDS_DRIVER`、EXF、BOM、网格度量和锁定 Julia 源码重新取证，确认时间标签、EXF 依赖和 Julia 适用边界无误；
- 提出 P1.3-A—P1.3-E：不安全的子步整数转换、缺失权威状态预算、CFL tie/度量/球面阈值歧义、失败/候选 age 语义不完整以及收敛 fixture 未固定；
- 修订接口为 `EPSILON(oneRL)`、可表示 `subRatio`、精确 `bomNPartExpected`/全局 ID 预算、确定性最近 C 点与失败优先级、候选状态/age 事务和固定仿射解析场；
- 形成 P1-D030—P1-D033 与 `P1.3_DESIGN_AUDIT.md`；下一步先提交 remediation，再从新 head 复核，当前不宣称 PASS。
- 以 WangYuLin 身份创建整改提交 `941c74e5b855753a5700f7b883a56924b57c2fc0`，从固定基线重新审计 8 个 Markdown、3 个提交、33 项决策、16 条需求与 28 个本地链接；范围、模式、身份、隔离词、标签和 GitHub Draft PR 状态全部通过；
- P1.3-A—P1.3-E 全部关闭，独立设计复审结论为 PASS、无开放 finding；本轮没有编译或数值运行，因为范围仍为纯 Markdown；
- PR #13 保持 Draft，不合并、不打标签；下一步等待单独的生产实现授权。

### 2026-08-25：P1.3—P1.5 集成与 Phase 1 最终退出门禁

- PR #13、#14、#15 分别以 merge commit `41fb093866ef4c2dbda778696892457cfca160f9`、`9d258da4ff43d84f4877ba11d894af0e96b3177b`、`3f330b59db76b8d7d0ca0fb2bfd007e567fbd6bc` 顺序集成；
- 在最终 production code head `3f330b59d` 上重新执行 15 组门禁，P1.5 专属 62/62、前序 195/195、P1-G01 257/257 全部 PASS；
- Phase 0 最终门禁 4/4 与嵌套 P0.4 9/9 在同一代码头通过；
- 聚合证据根为 `/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/p1-integrated-g01-3f330b59-attempt01`；
- 聚合 manifest、逐行审计和退出计数 SHA-256 分别为 `d5a83b7d0e1033bfc105aaab52f688aec38ac2de871ab7824d9135f864290af7`、`737c489957c7dbe65a8665955090dd2cbb76afc6e3f4fe463367b7414ad28fce`、`dfaac4a9f07bddcafbae83a527f6b7cc9ddde827511590c28bbe3364df93397e`；
- 9 份原生 manifest、15 份 summary、同一 source head、空 Git 状态、环境和门禁脚本哈希均复验通过；
- Julia 参考适用边界与完整 trajectory golden 延期结论、目标服务器独立验证条件均已明确记录；
- 独立退出审计结论为 PASS、无开放 finding；审计前本地与远端均不存在 `MITGCM-BOM-v0.2`。

### 2026-08-25：Phase 1 发布与 Phase 2 准入

- Phase 1 退出审计 PR #16 已以 merge commit `1067c21d230e9c9619e89245b97c01e9474c7ed7` 集成；first-parent 范围为 16 个 Markdown；
- annotated tag `MITGCM-BOM-v0.2` 已创建并推送，tag object 为 `ab4317e5fe695fb0b2eb3be9b1ce91b39ba137f1`，peeled commit 为 `1067c21d230e9c9619e89245b97c01e9474c7ed7`；
- 本地/远端 tag object 与 peeled commit 一致，tagger 为 `WangYuLin <wang111936@outlook.com>`；
- Phase 1 标记为完成，最终 production code evidence 仍为 `3f330b59d` 的 257/257；审计/发布纯文档提交不改变数值结果；
- Phase 2 准入通过但生产实现尚未开始；建立 `PHASE-02.md` 记录边界、风险、分工作包和 P2.0 唯一下一任务；
- P2.0 首先冻结 old/new 环境场、Stokes source/去重规则、导数/度量接口、`PAPER2024`/`JULIA` 模式和 Julia golden 输入，不混入弹簧、生物或站点 HPC 优化。
- Phase 2 准入记录 PR #17 已以 merge commit `ed767ed22db7933cfee82dc89ade14691e081f91` 集成；development 同步后唯一下一任务保持为 P2.0。

### 2026-08-25：P2.0 接口、需求与测试冻结

- PR #18 以 merge commit `f84ac9a824f6e2e38f92c7bb5d8e538ac16ced3f` 完成 Phase 2 准入记录收口；
- 在独立分支 `MITGCM-BOM/p2.0-interface-freeze` 完成论文、锁定 Julia、MITgcm/EXF、当前 BOM 和 pickup 源码审计；
- 冻结 exact old/new 端点、EXF 风、FILES/COUPLER Stokes、显式 `bomCurrentPolicy`、C 点 SI 导数、`PAPER2024`/`JULIA` 双模式和 schema 2；
- 新增 18 条需求、18 项设计决定及 B04/B05/B16、负向、MPI、restart、FLT coexistence 和全回归门禁；
- 初始设计提交为 `628a6bb4621429bf6f58e9e46a13216c21de7815`，GitHub PR #19 的 5 文件不可变补丁复审 PASS；
- 核心冻结为 5 个 Markdown、1086 行，状态收口另更新 4 个 Markdown；没有生产 Fortran、脚本、算例输入或生成证据变化，因此未运行编译/数值矩阵；
- P2.0 无开放 finding，Phase 2 状态改为进行中；未创建 `MITGCM-BOM-v0.3`；
- 唯一下一任务为 P2.1 transactional old/new 环境场与 exact-time providers，不混入 P2.2 导数或 P2.3 RHS。

### 2026-08-25：P2.1 参数与 accepted endpoint 状态首增量

- 从 PR #19 合并提交建立 `MITGCM-BOM/p2.1-environment-endpoints`，未读取或修改其他开发工程；
- 分支已推送并创建 Draft PR #20，目标为 `MITGCM-BOM/development`；当前不授权 Ready 或合并；
- 实现全部冻结运行参数、`bomTauDays` 防溢出秒转换、current/Stokes policy matrix 和 FILES 元数据预检；
- 新增 `BOM_FIELDS.h` accepted old/new/source/time/iteration/valid/ready 状态，并保持 Phase-1 `bomGrid*` 状态不变；
- 稳定 failure code 9—15、stage code 6—8 及 source/endpoint code 已由直接断言固定；
- 功能提交为 `920e22fbdcdf7ceb59f2bd795cad86d116ac21af`；权威门禁 13/13 PASS；
- 当前明确保留非零 `BOM` 拒绝，P2.1 尚未关闭，不创建 `MITGCM-BOM-v0.3`；
- 唯一下一任务为 transactional fresh/normal endpoint publisher 与 ocean/NONE/NONE providers。

### 2026-08-26：P2.1 transactional ocean/NONE/NONE endpoints

- 新增独立 transaction scratch 和生产 `BOM_BUILD_ENDPOINTS`/`BOM_TRY_BUILD_ENDPOINTS`；
- fresh 发布相同 `(startTime,nIter0)`，normal 验证连续性并将 accepted NEW 精确复制到 OLD；
- ocean provider 完成表层复制、C 点共置、east/north 旋转、mask、halo 和有限性校验；
- `wind=NONE`、`Stokes=NONE` 发布精确零且湿点 valid，失败不修改 accepted state；
- 功能提交 `b81bb01293dbc4279db544174efe9558382115a3` 的权威门禁为 15/15 PASS；
- 中断开发尝试 `p21-transaction-dev-gate02` 和通过的 pre-commit gate03 均保留在仓库外且未覆盖；
- Draft PR #20 仍未 Ready、未合并；P2.1 未关闭，未创建 `MITGCM-BOM-v0.3`；
- 唯一下一任务为 BOM-owned exact-time EXF wind provider 与 P2-E03/P2-N03 focused gate。

### 2026-08-26：P2.1 exact-time EXF/FILES/COUPLER endpoints

- 先后完成 BOM-owned EXF wind、FILES Stokes 和 compiled COUPLER Stokes provider；
- COUPLER API 使用 `ALLOW_BOM_STOKES_COUPLER` 显式编译边界及 per-component copied publication；
- fresh/normal/retry 与所有 source failure 都经生产 `BOM_TRY_BUILD_ENDPOINTS` 验证；
- 功能提交 `6247ee6ba0fd1e796047bff944558c8e80c3511f` 的权威门禁为 32/32 PASS；
- 权威证据 ID 为 `p21-coupler-6247ee6ba-attempt01`，summary SHA-256 为 `87375f0d0003f240854e4c5738982c007b7b84e422d9d00c195933a2d7314dec`；
- Draft PR #20 仍未 Ready、未合并，未创建 `MITGCM-BOM-v0.3`，无开放阻塞；
- 唯一下一任务为 `BOM_INTERP_ENV_TIME` 和 P2-E06/P2-N02 focused serial/MPI4 gate；
- schema-2 pickup、空间导数、RHS 和 RK stage 接线保持后置。

### 2026-08-26：P2.1 时间插值、schema-2 pickup 与工作包收口

- `83913ce594158f3c5e52907f56e5f69881ad9791` 完成 exact endpoint/interior
  `BOM_INTERP_ENV_TIME`，P2-E06/P2-N02 聚合门禁 34/34 PASS；
- `df67380a803a7c675ee8c4456f693ecbbd88a022` 完成 schema-2 exact
  fingerprint、OLD/NEW endpoint sidecar、scratch preflight 和一次提交；
- MPI 开发测试暴露全局 signature 非 owner rank 关闭未打开 unit，修复为仅
  对正 file unit 关闭；最终串行/MPI4 pickup 门禁 10/10 PASS；
- P1.4 的两个验证专用 `BOM_SIZE.h` 已同步 schema-2 常量，精确头 36/36；
  P1.1 LEEW/FILES 仍在初始化前拒绝，并使用稳定语义片段匹配；
- 最终精确功能头为 `41d0dbc20404df1759a7a5d1b274bc85d5c415fd`；
- 同一头上 P1-G01 15 组 257/257、endpoint 34/34、pickup 10/10，
  聚合 301/301 PASS，11 份原生 manifest、全部 summary、source head 和
  空 Git 状态均完成自验证；
- 聚合证据根：`/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/`
  `p21-closure/p21-closure-41d0dbc20-attempt02`；row audit 与 manifest
  SHA-256 分别为 `7b15d0540f5d1228760e93e879ce8e8b9b45d47a0307865ebd4d55a1fa442559`
  和 `423c679704876f68a4962f56c43bfe02f66a38f6088ef4914228170d61774d9c`；
- P2.1 标记完成，Draft PR #20 尚未 Ready/合并，未创建 v0.3；
- 唯一下一任务为创建本地 `MITGCM-BOM/p2.2-derivatives` 并实现 Cartesian
  C-point derivative/time-secant 与 P2-D01--D03/P2-N05 首增量。

### 2026-08-26：P2.2 Cartesian derivative 首增量

- 在本地分支 `MITGCM-BOM/p2.2-derivatives` 完成 accepted OLD/NEW 环境场
  的四分量 C 点空间梯度、validity、transactional publication 和 stage-time
  gradient interpolation；功能提交为
  `f2c86ddf73d2f0b8dc470ad6abcac68a48accaef`；
- 非均匀二阶 centered/允许的一侧三点公式只使用共同全湿 stencil；不足
  stencil 显式 invalid，坏度量/算术失败不留下 partial publish；
- 精确门禁 `p22-derivative-f2c86ddf7-attempt01` 通过 P2-D01--D03 与
  Cartesian P2-N05，共 9/9 PASS；同一头 pickup 回归为 10/10 PASS；
- 开发过程 endpoint/provider 回归 `p22-cartesian-smoke-26b295c52-attempt04`
  为 34/34 PASS；它不是 `f2c86ddf7` 精确头证据，只登记为开发回归；
- P2-D02 已澄清：二次场验证三点公式精确性，三次 manufactured field
  用于观测非零二阶误差；
- 本节保留为 Cartesian 首增量历史；完整 P2.2 关闭见下一会话记录；
- spherical D04/D05/N05 已在 `5d4b91831` 完成，不再是开放任务；
- 本分支继续按用户要求积累完整 P2.2 后集中推送；
- Draft PR #20 保持 P2.1 未合并记录，未创建 tag。

### 2026-08-26：P2.2 球面协变完成与工作包关闭

- 功能提交 `5d4b918318682bee99b871684f781fa0ceefa482` 完成 Cartesian/
  spherical C-point metric transaction、MITgcm `fCori` 与有限保护协变算子；
- P2-D04 验证多纬度物理梯度和 `tauSphere`；P2-D05 验证独立 PAPER-total/
  JULIA-base vorticity candidates；完整 N05 覆盖半径、近极、非有限
  `fCori`、坏 stencil/metric、overflow 与 rollback；
- 精确 derivative 16/16、endpoint 34/34、pickup 10/10、前序 257/257，
  总计 317/317 PASS；
- 聚合证据为 `p22-closure/p22-closure-5d4b91831-attempt02`，row audit 与
  manifest SHA-256 分别为
  `8074e632d887e2e23bdb6233c2c1f8896ef098522b3dbc10a72a3b42e96ca163`
  和 `1d4d4409a47e729d713066245f2942179ee04995452c931d87c46782ffdc2a40`；
- P2.2 关闭；P2.3 是唯一下一工作包，先实现 stateless 双模式 RHS 和
  P2-H01--H06/P2-N06，不进入 RK stage/P2.4；
- 本轮在完整阶段记录形成后最多进行一次批量推送，不在小增量间反复同步；
  不创建 `MITGCM-BOM-v0.3` 标签。

### 2026-08-26：P2.3 双模式 RHS 完成与工作包关闭

- 本地分支 `MITGCM-BOM/p2.3-rhs-components` 的功能提交 `fb004faf7`
  完成 PAPER combined-total 与 JULIA weighted per-source 两条独立路径；
- H01--H06/N06、串行/MPI4 构建及八条记录位级一致共 18/18 PASS；
- 同一精确头重跑 P2.2 16/16、P2.1 endpoint 34/34、pickup 10/10 与
  Phase-1/Phase-0 257/257，总计 335/335 PASS；
- 聚合证据为 `p23-closure/p23-closure-fb004faf7-attempt01`，row audit 与
  manifest SHA-256 分别为
  `290b3626e8343ae389f2227425ddf4b3591b4fa2f3e8ed54a08090c7b418c13e`
  和 `9feacb71d499c8327b9d2b6ba5c61d6e53ffa7c521dd4e7aba93bc4b32a8fb42`；
- 历史 P1.1 runner 首次沿用 pre-P1.4 日志文本，启用已集成 owner-migration
  兼容开关后 42/42 PASS；没有生产源码修复或跳过项；
- P2.3 关闭；P2.4 是唯一下一工作包，范围为 RK stage-time 接线、
  B04/B05/B16 和 P2-I01--I06/P2-N07；不提前进入 P2.5；
- 用户要求减少 GitHub 推送，本工作包只在代码、测试、证据和文档全部
  完成后批量同步一次；不合并既有 PR，不创建 v0.3 tag。

### 2026-08-27：P2.4/P2.5 关闭与 PR #20--#24 顺序集成

- P2.4 精确功能头 `4b2d09d40` 通过 stage/RK 11/11、B16/N07 12/12
  及前序总计 358/358；关闭提交为 `618ccbe329`；
- P2.5 精确功能头 `d37dccae7` 通过 integration 20/20、BOM coexistence
  12/12 与前序总计 390/390；关闭提交为 `560577dfac`；
- PR #20--#24 按依赖顺序全部转 Ready，并使用 merge commit 合并到
  `MITGCM-BOM/development`；合并提交为 `4771bdb9`、`6c9d94e5`、
  `8730fe90`、`bb641b9d`、`f71e76e8`；
- 最终 development tree 与 P2.5 关闭头 tree 完全一致；合并前/后未创建
  `MITGCM-BOM-v0.3`，满足“集成测试前不创建标签”的发布边界。

### 2026-08-27：Phase 2 最终 390 门禁与退出审计

- 从合并生产头建立 `MITGCM-BOM/phase-02-exit-audit`；提交
  `db41805cda3a10fe9b96889c87069c6347788cbc` 只把两个 P2.4 README
  加入 P2.5 独立审计 allowlist，不修改生产源码或测试驱动；
- attempt01 因全局 artifact-root override 被嵌套驱动继承，summary 写入
  非冻结位置而停止，保留为非权威配置诊断；
- 修正后的 `p2-integrated-g01-db41805cd-attempt02` 在干净精确头上通过
  23 组 390/390；captured Git status 为空，manifest 自校验 PASS；
- 证据根为 `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p25-closure/`
  `p2-integrated-g01-db41805cd-attempt02`；row audit 与 manifest SHA-256
  分别为 `d29712970d8de8db828c0611384de38f7680047c001494b3917cce4fc04e677a`
  和 `ce29af66b0a3b925cce2bc8c70a1a937aff94a621d3f6bc10b314e26b5a5b85c`；
- P2-R01--P2-R18、全部退出条件和 Julia golden 裁决均关闭；独立退出
  审计为 PASS、无开放 finding；
- 下一动作是合并退出审计 PR，在其 merge commit 上创建并推送 annotated
  tag `MITGCM-BOM-v0.3`；之后从 P3.0 设计/接口/测试冻结开始 Phase 3。

### 2026-08-27：Phase 3 准入与 P3.0 冻结候选

- `MITGCM-BOM-v0.3` tag object `9360a06d0379051aced0601b25aa814dda6330fb`
  已核对 peel 到 Phase 2 退出审计 merge commit `332a406e958e5005f60267c187fada1f74319fc3`；
- 从该提交创建 `MITGCM-BOM/p3.0-interface-freeze`，未继承其他开发任务文件；
- 锁定 Julia 参考提交 `156557359185e4413ce82829f3ed26a4eb8c6283`，记录 springs、physics、
  rafts/clumps 与 Project/Manifest 的 SHA-256；
- 冻结 KNN oracle、exact cutoff graph、cell-linked-list、ghost、Hooke/eBOMB、
  ensemble RK、raft、schema 3、错误码、复杂度与 B07--B09/B17 契约；
- 建立 P3-R01--P3-R18、P3-D001--P3-D022 和分工作包测试矩阵；
- 本工作包只允许 Markdown；生产 Fortran、测试脚本、输入和生成证据变化必须为零；
- 冻结提交 `e81ddaa521e5f3babe54ba0ac8964c3dae058f88` 在精确提交上通过
  changed-path、Markdown-only、diff whitespace、禁用词、requirements、
  decisions、source findings、测试标识、核心契约、链接和 v0.3 基线共
  12/12 审计；
- 8 个冻结文件共 1410 insertions、12 deletions；`pkg/bom` 和 `model`
  差异为空，没有生产源码、脚本、输入、锁定数据或生成证据变化；
- P3.0 标记完成、无开放 design/scope finding；分支已批量推送并创建
  Draft PR #26；
- PR #26 远端复审确认 `draft=true`、`mergeable=true`、base/head SHA
  正确、2 个提交、9 个 Markdown、ahead 2/behind 0；
- 未经用户明确授权不合并 PR #26，不创建 `MITGCM-BOM-v0.4`；
- P3.1--P3.5 的实现和运行测试均未开始；下一生产任务严格限于 P3.1。

## 6. 每次会话结束时必须更新

1. 当前任务分支、当前工作包和下一工作包；
2. 本次新增提交 SHA；
3. 实际运行的测试及结果路径；
4. 新风险、阻塞项和设计决定；
5. 阶段完成度及退出条件；
6. 下一次开始时唯一、具体、可执行的任务。
