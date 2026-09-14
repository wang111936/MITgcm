# MITGCM-BOM：用于地球流体动力学的 Maxey–Riley 粒子追踪模块

**MITGCM-BOM** 是独立的 **MITgcm（MITGCM）** 表面拉格朗日粒子追踪模块，
面向 **Geophysical Fluid Dynamics（地球流体动力学）** 中的漂浮物输运研究。
通过 Maxey–Riley 框架下的 **BOM 慢流形动力学**，分析表面漂浮物为什么不一定
沿着纯海流平流轨迹运动，并可按需加入直接风漂、Stokes 漂移和马尾藻筏过程。

[English](README.md) · [使用指南](pkg/bom/README.md) ·
[可运行教程](verification/tutorial_MITGCM-BOM/README.md)

**由广东海洋大学海洋与气象学院王煜林博士开发。**

**Developed by Dr. Yulin Wang, College of Ocean and Meteorology,
Guangdong Ocean University.**

联系邮箱：[wang111936@outlook.com](mailto:wang111936@outlook.com)

当前为研究预发布版本，是独立维护的 MITgcm 扩展，不代表上游官方接纳，
也不代表已通过完整 HPC/v1.0 验收。

## 解决什么问题？

只让粒子随海流运动，不能描述所有表面漂浮物的输运行为。本模块利用运行中的
MITgcm 或其 offline 配置提供的环境场，研究以下过程对轨迹的影响：

- **惯性输运**：比较常规 leeway 与 BOM 慢流形运动；分别保留 `PAPER2024`
  和锁定 `JULIA` 参考实现的方程约定。它不是完整未约化 Maxey–Riley 方程所有项的求解器。
- **风浪影响**：按配置加入直接风漂和波致 Stokes 输运，避免重复计入 Stokes。
- **漂浮筏相互作用**：可选 Hooke/eBOMB 弹簧和连通分量诊断。
- **马尾藻生命周期试验**：可选温度/营养盐控制的生长、繁殖、死亡和近岸终止事件；
  已有这些过程并不等于完成了真实海域的业务预报定标。
- **可复现数值实验**：支持 RK2/RK4、串行/MPI、同分解重启和轨迹诊断；
  可选 `ARCHIVE` 连续输出，使每次启动片段的轨迹文件数量不随输出时刻增加。

## 与 FLT 有什么区别？

| 对比项 | MITGCM-BOM（`pkg/bom`） | MITgcm FLT（`pkg/flt`） |
|---|---|---|
| 主要用途 | 表面漂浮物的惯性运动，以及可选筏相互作用与生命周期 | 海洋浮标、漂流器平流、剖面浮标及定点采样 |
| 运动模型 | 二维表面运动；leeway 或 Maxey–Riley 框架下的 BOM 慢流形速度 | 主要由模型流速驱动，包含深度/剖面和三维运动选项 |
| 扩展物理 | 可配直接风漂、Stokes、Hooke/eBOMB 弹簧、Brooks 生物过程 | 不包含 BOM 慢流形、弹簧和 Brooks 核心 |
| 是否互相依赖 | 独立状态、参数和生命周期，不调用或依赖 FLT | 原生独立包，不依赖 BOM |
| 适合的研究 | 表面惯性漂移、风浪贡献、相互作用漂浮筏 | 浮标平流、深度相关运动与剖面观测模拟 |

**BOM 不是 FLT 的封装，也不是对 FLT 所有用途的替代。** 两者可分别编译、
分别开启，也可在同一模型中共存以开展对照。初始位置相同，不保证不同物理、
插值和积分设置下的轨迹完全一致。

## 从小型案例开始

需要 Linux、Fortran 编译器（如 GNU gfortran）、GNU make、常规 MITgcm
构建工具、Python 3.9+ 和绘图用 Matplotlib；串行教程不要求 MPI。

```bash
git clone --branch MITGCM-BOM/development --single-branch \
  https://github.com/wang111936/MITgcm.git MITGCM-BOM
cd MITGCM-BOM
git rev-parse HEAD
cd verification/tutorial_MITGCM-BOM
./run_tutorial.sh \
  --work-root /tmp/MITGCM-BOM-tutorial-paper2024 \
  --equation PAPER2024
```

每次运行使用新的工作目录。教程会编译 `mitgcmuv`、生成小型输入、积分三个
粒子六小时，输出 CSV、JSON 和 PNG；成功标志为 `MITGCM-BOM TUTORIAL PASS`。
教程绘图使用 FRAME；ARCHIVE 的解码与校验入口见
[连续轨迹输出说明](verification/bom/phase05-trajectory-archive/README.md)。

## 文档、测试与限制

- [参数和可选功能开关](pkg/bom/BOM_PARAMETER_REFERENCE.md)
- [初值、轨迹和重启文件](pkg/bom/BOM_INPUT_OUTPUT_REFERENCE.md)
- [预发布说明与已知限制](doc/phys_pkgs/MITGCM-BOM/PRE_RELEASE_2026-09-14.md)
- [逐项验证摘要](doc/phys_pkgs/MITGCM-BOM/PRE_RELEASE_EVIDENCE_2026-09-14/README.md)
- [开发状态和剩余工作](doc/phys_pkgs/MITGCM-BOM/PROJECT_STATUS.md)

2026-09-14 预发布专项为 **66/66**；历史科学基准为 **754/754**，另有独立
**21/21** 退出审计。各结果只适用于证据中对应的版本和矩阵，不等于完整 HPC
或真实海域预测验收。当前支持规则 Cartesian/球面经纬网、单向表面粒子、
每 MPI rank 一个执行线程，以及同分解重启。

S1 随机轨迹扩散、逐粒子扩展生物冷启动初值尚未实现；事件缓冲及增量 I/O、
OpenMP 和目标 HPC 验收仍待完成；粒子 MNC/NetCDF 输出延期。

## 联系与参与

科学问题、合作或使用反馈请联系王煜林博士：
[wang111936@outlook.com](mailto:wang111936@outlook.com)。
可复现问题也可提交至[问题入口](https://github.com/wang111936/MITgcm/issues)，
附上源码 SHA、编译器/MPI、网格与进程布局、相关配置和首条错误日志；
不要提交账号凭据或受限数据。较大的新物理功能请先讨论设计。

## 理论来源与致谢

上述开发署名指 **MITGCM-BOM 新增实现与集成工作**，不替代原 MITgcm 模型、
BOM 理论和参考软件的作者署名。

- Bonner、Beron-Vera、Olascoaga（2024）：
  [Maxey–Riley 框架中的非线性弹性与马尾藻生命周期模型](https://arxiv.org/html/2410.01468v1)。
- [SargassumBOMB.jl 参考实现](https://github.com/70Gage70/SargassumBOMB.jl)与
  [固定参考版本](doc/phys_pkgs/MITGCM-BOM/REFERENCE_LOCK.md)。
- [MITgcm 上游模型](https://mitgcm.org/)及[上游文档](https://mitgcm.readthedocs.io/en/latest/)。
- 保留[许可证和原始版权声明](LICENSE.txt)。

关键词：MITGCM、BOM、Maxey-Riley、Geophysical Fluid Dynamics、地球流体动力学、
Lagrangian particle tracking、拉格朗日粒子追踪、inertial particles、惯性粒子、
ocean modeling、海洋模拟、Sargassum、马尾藻、Stokes drift、风漂、Fortran、MPI。
