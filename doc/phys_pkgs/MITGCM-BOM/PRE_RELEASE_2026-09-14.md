# MITGCM-BOM 2026-09-14 预发布基线

状态：**预发布专项 66/66 PASS；交付目标为 development，非 HPC/v1.0 正式发布**。

用户授权把当前已完成成果集中更新到 `wang111936/MITgcm` 的
`MITGCM-BOM/development`，作为本轮预发布最终基线。此次不是完整
Phase 5/HPC/v1.0 退出，不创建 GitHub Release 或任何标签。

## 1. 纳入范围

- 远端起点：`00ce0c39177afacf3eef6e7930a567ed52d3d785`，已有 P5.0--P5.4。
- P5.5 科学验收聚合/审计及记录：截至 `16711ae22266c45ad91e7e0b406557d718dd8aee`。
- 连续 MDS trajectory ARCHIVE：`3dcb37216dcfeb2c702c748f01784b8c8e690f4d`。
- CAL--EXF：精确迁入实验副本的两个生产文件差异、endpoint 测试驱动和四个 CAL 配置。
- 状态更正及未实现功能清单，不把 S1、生物扩展初值等标为完成。

CAL 修复必须同时包含 `pkg/bom/bom_get_exf_wind.F` 和
`pkg/exf/exf_getffieldrec.F`，后者涉及通用 EXF 路径。代码保持实验补丁字节一致：

| 文件 | SHA-256 |
|---|---|
| bom_get_exf_wind.F | d175b489f6846e8b83220e6f9e511c1a2d1297111c985737ebde71786771719a |
| exf_getffieldrec.F | e5242b1b21007c773e9aa37c2a1f0228f868ec4510e5629cb09b41caf6fb97f7 |

作者为 WangYuLin；集成分支为 `MITGCM-BOM/pre-release-20260914`，
通过一个 PR/merge commit 更新 development。实验源码、可执行程序、
案例数据、FIX 交付目录和 SKRIPS 文件不随本次发布修改。

## 2. 验证与证据边界

本轮在同一个干净候选提交运行以下已有专项，不改变夹具和容差：

| 专项 | 状态 | 覆盖 |
|---|---|---|
| P2.1 endpoint state（含 CAL） | 40/40 PASS | ocean/NONE/EXF/FILES/COUPLER、CAL serial/MPI4、真实生产短跑、来源/事务负测 |
| P2.1 pickup | 10/10 PASS | 既有环境端点连续/分段恢复及损坏拒绝；不是完整 CAL restart 矩阵 |
| P5.6 ARCHIVE 基础 | 10/10 PASS | serial/MPI2、FRAME 等价、恒定文件数、claim、基础孤立尾部、分段 restart |
| P5.6 ARCHIVE active | 6/6 PASS | P3 serial/MPI2、P4/P3+P4 状态和签名、计数增长夹具 |

四组均在干净提交 `ddc8699d7ea1996efc91d9b531b9bb7eeeba5c73` 执行，
所有脚本正常完成，汇总检查了精确行数、无重复 case key、全部 PASS。
测试期间源码未变化；之后只增加文档和摘要，最终合并树的生产代码与
上述测试提交保持一致，不将文档提交描述成一次新的模型测试。

可下载的逐项摘要、SHA-256、目录对象和外部证据根见
[预发布验证证据](PRE_RELEASE_EVIDENCE_2026-09-14/README.md)。
66 行含构建/接口检查，不是 66 个独立完整科学案例。

历史科学基准 754/754、独立 21/21 仅绑定 `16711ae22`。
历史 CAL 通用路径影响比较 `cal-none-old-new-20260910-attempt01`
为 8/8、4800 s、515 文件位级一致，验证的是其记录的补丁和夹具，
不是本轮新运行，也不是任意 EXF 配置的普遍保证。
本次专项不能替代新的完整科学聚合或目标 HPC 退出。

旧聚合入口也不是当前预发布版本的现成总门禁：Phase 2 closure 固定
endpoint 34 行，CAL 扩展后独立驱动为 40 行；P5.5 范围白名单未覆盖
后续 ARCHIVE verification 和包外 EXF 修改。H05 必须先明确新增计数与
范围再执行完整聚合。本轮不放宽旧白名单或删行制造 754/754 结果。

## 3. 下载与使用

明确选择开发分支，不能用上游默认分支代替：

```bash
git clone --branch MITGCM-BOM/development --single-branch \
  https://github.com/wang111936/MITgcm.git MITGCM-BOM
cd MITGCM-BOM
git rev-parse HEAD
```

合并后的固定提交可从本 PR 的 merge commit 获取。`development` 今后仍会变化，
复现实验必须记录实际 SHA，并按 [用户指南](../../../pkg/bom/README.md)
重新编译 `mitgcmuv`；下载源码不会更新服务器既有可执行文件。

避免逐时轨迹文件时，在已有有效 `data.bom` 中显式设置
`bomTrajectoryMode='ARCHIVE'`，保持原来需要的 `bomOutputFreq`。
默认仍为 FRAME。ARCHIVE 每次启动一个 nIter0 segment，不跨重启覆盖旧 segment。
教程绘图器仍为 FRAME-only；ARCHIVE 的校验/解码入口为
`verification/bom/phase05-trajectory-archive/verify_archive.py`。

## 4. 已知限制与开放任务

| 项目 | 预发布状态 |
|---|---|
| S1 随机轨迹扩散/多 seed 集合 | 未实现；bomSeed 仅供生物出生 RNG，bomSigma 是 Stokes 权重 |
| D08 生物扩展初值 | 未实现；只读 schema 1，fresh biology 统一 bomS0/零谱系；P4 freeze §16.1 差异重新打开 |
| D09/D10 事件 I/O | 无高水位自动刷写；刷写复制/校验完整历史 shard；不能用轨迹 ARCHIVE 的结果替代 |
| 年度/月历 EXF 风 | 未支持；本次 CAL 修复仅 regular 非年度序列 |
| 原位温度、运行时自动 L、Verlet/skin | 未实现；THETA 代理、显式 L、逐 stage 重建是现有支持边界 |
| OpenMP、大规模分片初值、变分解 restart | 未实现/未准入；当前一线程/rank、同分解 restart |
| HPC 性能、故障恢复、并行文件系统、ARCHIVE 完整压力矩阵 | 尚未完成，不能宣称最终 HPC 验收 |
| MNC 粒子轨迹 NetCDF | 用户明确延期；格点 diagnostics MNC 不等于 trajectory MNC |
| Phase 6、三维粒子、双向反馈、GPU/自适应积分、同化 | 后置/范围外；不进入此次发布 |
| 真实区域案例 C3/C4、运行元数据和观测检验 | 按案例任务补证据，当前预发布不替它们签发完成结论 |

完整任务索引见[开发盘点及补录](DEVELOPMENT_RECONCILIATION_2026-09-12.md)。
功能存在、指定测试通过、任意案例适用必须分别记录。
