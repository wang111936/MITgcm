# Phase 1.5 output, pickup, and FLT coexistence verification

本目录验证 P1.4 权威 owner 状态的轨迹输出、相同分解 pickup/restart 与
MITgcm `pkg/flt` 独立共存。

权威接口见
[`../phase01-bom-lite/P1.5_INTERFACE_FREEZE.md`](../phase01-bom-lite/P1.5_INTERFACE_FREEZE.md)，
执行矩阵见 [`TEST_PLAN.md`](TEST_PLAN.md)。本目录只提交驱动、fixture、
解析器和紧凑结果；构建、运行、二进制和原始日志必须位于仓库外唯一目录。

预定证据根：

```text
/home/wyl/build/mitgcm-bom/phase01-output-pickup-coexistence/<test-id>/
/home/wyl/runs/mitgcm-bom/phase01-output-pickup-coexistence/<test-id>/
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p15/<test-id>/
```

当前状态：**IMPLEMENTATION/EVIDENCE PASS — INDEPENDENT READY REVIEW
PENDING**。clean exact head
`adb9e315836079d8ef1280e15d7ede7aa52fee6c` 上的 output/pickup 25/25、
真实迁移 12/12、FLT/BOM 共存 25/25 及 P1.4 到 Phase 0 的 195/195
前序回归均通过，P1-G01 合计 257/257。权威执行记录见
[`TEST_RESULTS.md`](TEST_RESULTS.md)，最终范围审计见
[`../phase01-bom-lite/P1.5_SCOPE_AUDIT.md`](../phase01-bom-lite/P1.5_SCOPE_AUDIT.md)。
