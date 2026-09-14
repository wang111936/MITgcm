# MITGCM-BOM 预发布专项证据

日期：2026-09-14。实际测试提交：
`ddc8699d7ea1996efc91d9b531b9bb7eeeba5c73`。

四组均由项目专用 WSL Ubuntu 22.04 GNU debug/IEEE 构建运行；每组
`MITGCM_BOM_MAKE_JOBS=4`，新建独立 build/run/artifact 根，无复用旧结果。
启动前及全部结束后确认同一 HEAD、干净工作区。归档脚本原生摘要未记录
source-head，此处的绑定来自本轮执行命令和前后干净 HEAD 核验，不伪称
原脚本已经具有完整来源 manifest。endpoint/pickup 原生 manifest 已复验。

| Gate | 结果 | 随仓库保留的原样摘要 |
|---|---:|---|
| endpoint | 40/40 | [endpoint.tsv](endpoint.tsv) |
| pickup | 10/10 | [pickup.tsv](pickup.tsv) |
| archive | 10/10 | [archive.tsv](archive.tsv) |
| active archive | 6/6 | [active-archive.tsv](active-archive.tsv) |

计数包括构建和接口检查；四个脚本返回 0，逐项全部 PASS、没有重复 key。
汇总为 66/66，不替代 754-row 科学聚合或 HPC 准入。校验文件：
[SHA256SUMS](SHA256SUMS)。

## 源码目录指纹

以下为候选提交中的 Git tree object，发布时应保持一致：

| 目录 | Git tree SHA |
|---|---|
| pkg/bom | d9c4bf464b9b3ba7d305b80223652bc0ccfe4085 |
| pkg/exf | 9ebba199174af6cd33deab7bfdd978dc62d4c7e5 |
| verification/bom/phase02-endpoint-state | cf82f3662f62e7ff6e26694e3f4220be7f0eac26 |
| verification/bom/phase05-trajectory-archive | 823ed7d99e931e0ee91b4705504da755533202d2 |

后续结果记录提交仅改 doc/phys_pkgs/MITGCM-BOM 下的文件，合并前后
核验代码差异为空，不重复编译仅文档变更的提交。

## 完整外部证据根

以下为开发机路径；仓库仅发布小型摘要，不上传运行场或可执行程序。

- `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-endpoint-state/prerelease-endpoint-ddc8699d7-20260914-attempt01`
- `/home/wyl/projects/mitgcm-bom-test-artifacts/phase02/p21-pickup/prerelease-pickup-ddc8699d7-20260914-attempt01`
- `/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/p56-archive/prerelease-archive-ddc8699d7-20260914-attempt01`
- `/home/wyl/projects/mitgcm-bom-test-artifacts/phase05/p56-archive-active/prerelease-active-archive-ddc8699d7-20260914-attempt01`

原始 build/run 在 `/home/wyl/build/mitgcm-bom` 与 `/home/wyl/runs/mitgcm-bom`
下对应 gate 目录，使用同名 test ID。

## 复验入口

使用 `MITGCM_BOM_TEST_ID` 指定新的唯一 ID，然后运行：

```bash
bash verification/bom/phase02-endpoint-state/run_endpoint_state_gate.sh
bash verification/bom/phase02-endpoint-state/run_pickup_gate.sh
bash verification/bom/phase05-trajectory-archive/run_archive_gate.sh
bash verification/bom/phase05-trajectory-archive/run_active_archive_gate.sh
```

须先按项目环境说明配置编译器、MPI、shellcheck 和 Python，归档门禁要求
干净工作区；不要复用上述已存在的证据目录。
