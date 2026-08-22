# MITGCM-BOM 项目状态账本

> 本文件是跨会话恢复工作的唯一状态入口。每次开发结束前必须更新“当前恢复点”“阶段状态”和“会话记录”。

| 项目 | 当前值 |
|---|---|
| 最后更新 | 2026-08-23 |
| 权威开发仓库 | `/home/wyl/projects/mitgcm-bom` |
| GitHub 仓库 | `wang111936/MITgcm` |
| 上游仓库 | `MITgcm/MITgcm` |
| 集成分支 | `MITGCM-BOM/development` |
| 当前任务分支 | `MITGCM-BOM/phase-00-skeleton` |
| 当前阶段 PR | `wang111936/MITgcm#2`（draft，堆叠在 PR #1） |
| 当前阶段 | Phase 0：参考基线与骨架设计 |
| 当前工作包 | P0.2：`pkg/bom` 可编译空包骨架（完成，PR #2 待审查） |
| 下一工作包 | P0.3：MITgcm 生命周期与 `useBOM` 注册 |
| 当前阻塞 | 无；Julia 依赖锁为重建版本，需在 golden 测试中继续验证 |

## 1. 当前恢复点

下一次继续开发时，从以下任务开始：

1. 在 P0.2 PR 完成审查后创建 `MITGCM-BOM/phase-00-lifecycle`；
2. 增加编译期开关 `ALLOW_BOM` 和运行期开关 `useBOM` 的核心注册；
3. 只挂接 `BOM_READPARMS`、`BOM_CHECK`、初始化和空 `BOM_MAIN`；
4. 保持 `bomMaxParticles=0`，不得加入粒子状态或运动方程；
5. 为 P0.4 的 `data.pkg`、`data.bom` 零粒子算例准备稳定入口。

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
| Phase 0 参考与骨架 | 进行中 | v0.1 | P0.1、P0.2 完成；等待 P0.3 生命周期注册 | [Phase 0](PHASE_RECORDS/PHASE-00.md) |
| Phase 1 BOM-Lite | 未开始 | v0.2 | 等待 Phase 0 门禁 | [开发手册](DEVELOPMENT_MANUAL.md#phase-1bom-lite--leeway) |
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
- GitHub PR：`https://github.com/wang111936/MITgcm/pull/1`；
- Julia 参考源码固定到 `156557359185e4413ce82829f3ed26a4eb8c6283`；
- 自定义注册表固定到 `02961aced4cfa2b3430ebd4b44cdb7a3056e7175`；
- 已为 Julia 1.10.12 重建根级 Manifest；
- `Project.toml` 和重建 Manifest 已复制到 `verification/bom/reference/julia_env`；
- 固定环境能够实例化并成功执行 `using SargassumBOMB`；
- 上游自带测试结果已记录：0 passed、1 errored，原因为测试调用不存在的 `generate_rp_example`；
- 详细限制与校验和见 [REFERENCE_LOCK](REFERENCE_LOCK.md)。

### P0.2 可编译空包骨架

- 本地/GitHub 提交：`eee711c9b5aea0644ffb54fc5a08c544d2d7919e`；
- GitHub draft PR：`https://github.com/wang111936/MITgcm/pull/2`；
- 新增 `pkg/bom` 的 options、size、控制参数、读取/检查和空生命周期例程；
- `pkg/pkg_depend` 登记 `mdsio`、`mom_common` 强依赖；
- 串行与双进程 MPI 均完成 `genmake2`、`make depend`、编译和链接；
- 两个可执行文件均包含五个 `bom_*` 例程，证明包源码实际进入链接；
- 串行和双进程 MPI `verification/exp2` 均正常结束；
- 两套运行的 8 个 checkpoint 数据文件均与冻结基线 SHA-256 一致；
- 本工作包未修改 `model/src`、`model/inc`、`data.pkg` 或时间步调度；
- 详细命令和哈希见 `verification/bom/phase00-skeleton/TEST_RESULTS.md`。

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

## 6. 每次会话结束时必须更新

1. 当前任务分支、当前工作包和下一工作包；
2. 本次新增提交 SHA；
3. 实际运行的测试及结果路径；
4. 新风险、阻塞项和设计决定；
5. 阶段完成度及退出条件；
6. 下一次开始时唯一、具体、可执行的任务。
