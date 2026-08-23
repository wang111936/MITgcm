# MITGCM-BOM Phase 1 阶段记录

| 项目 | 当前值 |
|---|---|
| 阶段 | Phase 1：BOM-Lite / Leeway |
| 目标版本 | `MITGCM-BOM-v0.2` |
| 基线标签 | `MITGCM-BOM-v0.1` |
| 基线提交 | `b2f3ecf1081f7bab25749c4a6004730175d99955` |
| 当前分支 | `MITGCM-BOM/phase-01-design` |
| 当前工作包 | P1.0 需求与接口设计 |
| 状态 | 进行中 |
| 开始日期 | 2026-08-23 |
| 作者身份 | `WangYuLin <wang111936@outlook.com>` |

## 1. 阶段目标

在不引入惯性、Stokes、弹簧和生物过程的条件下，建立可在 Linux HPC 上运行的二维表层 BOM 粒子基础设施：独立状态、MITgcm 表层流插值、固定步积分、tile/MPI owner 迁移、轨迹和相同分解 pickup 重启。

Phase 1 结束时应提供可执行证据，证明 BOM-Lite 的解析轨迹正确、MPI 分解不改变权威状态、FLT 与 BOM 可以独立或同时运行。

## 2. 分工作包记录

| 工作包 | 状态 | 分支/PR | 结论 |
|---|---|---|---|
| P1.0 设计冻结 | 进行中 | `MITGCM-BOM/phase-01-design` | 设计文档编写与评审 |
| P1.1 状态与初值 | 未开始 | 待建立 | 等待 P1.0 合并 |
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

- [ ] Git diff 只有预定 Markdown 文件；
- [ ] 没有新增或修改 Fortran、shell、Julia、Python 和二进制文件；
- [ ] 所有需求 ID 在追踪表中唯一且至少映射一个测试；
- [ ] TEST_PLAN 中每个测试有判据、分解和证据路径；
- [ ] 设计与锁定 MITgcm/Julia 源码相符；
- [ ] 不含未声明的外部数据或服务器依赖；
- [ ] `PROJECT_STATUS.md` 可作为下一次会话唯一恢复入口；
- [ ] Git 作者身份为 WangYuLin；
- [ ] 远端分支和 draft PR 创建后补记 PR 编号和提交 SHA。

## 6. Phase 1 总退出条件

- [ ] P1.1—P1.5 全部完成并顺序集成；
- [ ] 解析、收敛、迁移、重启和 FLT 共存门禁全部通过；
- [ ] Phase 0 完整门禁重新执行且无回归；
- [ ] Julia 专用 RHS/golden 限制有明确结论；
- [ ] 目标服务器所需但本地无法验证的条件已单独记录；
- [ ] 集成分支创建 `MITGCM-BOM-v0.2` 前完成独立退出审计。

## 7. 下一恢复点

P1.0 draft PR 创建后：

1. 只评审设计、需求追踪与测试充分性；
2. 处理评审意见时继续保持 Markdown-only；
3. 合并 P1.0 后，从更新的 `MITGCM-BOM/development` 建立 P1.1 状态与初值分支；
4. P1.1 先实现状态和输入，不同时实现环境场或粒子运动；
5. 在 P1.1 通过编译、初始化、ID 和容量门禁前不进入 P1.2。
