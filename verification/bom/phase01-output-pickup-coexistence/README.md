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

当前状态：轨迹输出、同分解事务性 pickup/restart 和 FLT 独立共存生产
实现已完成。开发工作树上的 output/pickup 25/25、真实迁移 12/12、
FLT/BOM 共存 25/25 均通过；clean exact-head 专属门禁和全部前序回归仍
是关闭 P1.5 与 Phase 1 前的必要条件。
