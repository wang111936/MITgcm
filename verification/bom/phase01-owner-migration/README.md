# Phase 1.4 owner 迁移验证

本目录验证 `pkg/bom` 在规则 Cartesian 与未旋转 spherical-polar 网格上的同 rank 多 tile、跨 MPI rank 和周期 X owner 迁移。

权威接口见 [`../phase01-bom-lite/P1.4_INTERFACE_FREEZE.md`](../phase01-bom-lite/P1.4_INTERFACE_FREEZE.md)，场景与判据见 [`TEST_PLAN.md`](TEST_PLAN.md)。所有构建、运行和原始日志必须位于仓库外的唯一目录；本目录只提交脚本、fixture 和紧凑结果。

预定证据根：

```text
/home/wyl/build/mitgcm-bom/phase01-owner-migration/<test-id>/
/home/wyl/runs/mitgcm-bom/phase01-owner-migration/<test-id>/
/home/wyl/projects/mitgcm-bom-test-artifacts/phase01/p14/<test-id>/
```

当前状态：接口与生产实现已完成，P1.4 专属门禁已实现并通过开发模式
36/36；clean exact-head 正式证据与全部前序回归待完成。
