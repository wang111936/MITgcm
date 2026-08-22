# Phase 0：参考基线与骨架设计

状态：`进行中`

目标版本：`MITGCM-BOM-v0.1`

阶段分支前缀：`MITGCM-BOM/phase-00-`

P0.1 提交：`ff1ab313d348fc0219e6e192bcbab928eb49e7e7`

P0.1 PR：`https://github.com/wang111936/MITgcm/pull/1`

## 1. 范围

Phase 0 只建立可复现参考、MITgcm 包骨架、参数检查和零粒子验证，不实现粒子运动、Stokes、惯性、弹簧或生物过程。

## 2. 工作包

| ID | 工作包 | 状态 | 证据 |
|---|---|---|---|
| P0.1 | 参考源码与 Julia 依赖锁 | 完成 | `REFERENCE_LOCK.md`、`verification/bom/reference/julia_env` |
| P0.2 | `pkg/bom` 空包骨架 | 未开始 | 下一开发任务 |
| P0.3 | MITgcm 生命周期挂接 | 未开始 | 等待 P0.2 |
| P0.4 | `verification/bom` 零粒子算例 | 未开始 | 等待 P0.3 |
| P0.5 | 串行/MPI/零影响门禁 | 未开始 | 等待 P0.4 |

## 3. P0.1 实际记录

### 已完成

- 固定 MITgcm 提交；
- 固定 SargassumBOMB.jl 提交；
- 发现根级 Manifest 缺失；
- 从项目文档定位 SargassumRegistry；
- 固定注册表提交；
- 使用独立 Julia depot 成功生成 Julia 1.10.12 Manifest；
- 记录 Project 和 Manifest SHA-256；
- 完成依赖实例化并成功加载 `SargassumBOMB`；
- 复现并记录上游测试调用不存在函数的错误；
- 配置 Git 作者、阶段分支和 GitHub 记录规范。

### 发现的问题

首次 `Pkg.resolve()` 因 `SargassumFromAFAI` 未注册而失败。加入项目文档指定的 SargassumRegistry 后，独立 depot 又因缺少 General registry 无法解析 `OrdinaryDiffEqTsit5`。显式同时加入 General 和固定自定义注册表后解析成功。

该过程证明参考依赖不能只靠根级 `Project.toml` 重建，必须保存自定义注册表提交和 Manifest。

### P0.1 完成条件

- [x] 源码提交固定；
- [x] 自定义注册表提交固定；
- [x] Project 和 Manifest 入库；
- [x] 校验和记录；
- [x] Julia 环境完整实例化；
- [x] `using SargassumBOMB` 成功；
- [x] 参考项目单元测试结果已记录（上游接口错误，0 passed、1 errored）。

P0.1 已完成。上游测试错误作为已知参考缺陷保留，不阻塞 P0.2；BOM 专用解析/golden 测试仍是 Phase 0/2 的必要门禁。

## 4. Phase 0 退出条件

- [ ] BOM 关闭时 MITgcm 基线结果不变；
- [ ] BOM 开启、零粒子时单进程正常运行；
- [ ] BOM 开启、零粒子时 2 和 4 MPI ranks 正常运行；
- [ ] `data.bom` 参数默认值和错误检查通过；
- [ ] Julia 参考环境能加载并执行基础测试；
- [ ] 需求—实现—测试追踪表已更新；
- [ ] 阶段 PR 合并到 `MITGCM-BOM/development`。

## 5. 下一任务：P0.2

建立 `MITGCM-BOM/phase-00-skeleton` 分支，只创建：

- `pkg/bom/BOM_OPTIONS.h`；
- `pkg/bom/BOM_SIZE.h`；
- `pkg/bom/BOM.h`；
- 空生命周期例程；
- `data.bom` 参数声明和 `BOM_CHECK` 骨架。

本工作包不得加入粒子平流或环境场插值。
