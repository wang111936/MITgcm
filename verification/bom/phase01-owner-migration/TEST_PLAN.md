# P1.4 owner 迁移测试计划

## 1. 生产符号与静态门禁

- `BOM_LOCATE_OWNER`：全局半开域、周期规范化、真实 rank 映射与 hop。
- `BOM_RHS_LEEWAY_HALO`、`BOM_RK2_MIGRATE`、`BOM_RK4_MIGRATE`：halo stage，K1 仍为严格 owner。
- `BOM_PARTICLE_EXCHANGE`：容量预检、两字 ID、两个 `MPI_Alltoallv`、确定性提交。
- 生产源码不得出现验证场景标识，不得调用或修改 `FLT_*` 状态。

## 2. 正向矩阵

| 用例 | ranks | 内容 | 判据 |
|---|---:|---|---|
| P1-X01-H | 1 | 水平 tile face 穿越 | 唯一东侧 owner、状态守恒 |
| P1-X01-V | 1 | 垂直 tile face 穿越 | 唯一北侧 owner、状态守恒 |
| P1-X01-C | 1 | 内部角点穿越 | 唯一东北 owner、状态守恒 |
| P1-X02-R | 2/4 | rank face 与 rank corner | ID 排序状态等于 1 rank oracle |
| P1-X02-P | 1/2/4 | 周期 X 上界穿越 | 坐标规范化、owner 唯一、分解一致 |
| P1-X03 | 1/4 | 一个 ocean step 的多个子步跨多个 tile | 每子步 hop 不超限，最终位置/owner 正确 |
| P1-X04 | 2/4 | `2^32` 边界与大于 `2^53` ID | ID 与所有最小权威状态 bitwise 不变 |

## 3. 负向矩阵

| 用例 | 注入 | 判据 |
|---|---|---|
| P1-N03b-SEND | 编译期小发送上限，多粒子离开同 rank | `direction=SEND`、needed/limit、集体失败 |
| P1-N03b-RECV | 多源汇入同一 rank，接收超限 | `direction=RECV`、needed/limit、集体失败 |
| P1-N03b-TILE | 多粒子汇入已满目标 tile | 目标 tile/needed/limit、无截断 |
| P1-X03-HOP | `bomMaxHop` 小于目标距离 | ID/source/destination/hop/limit、集体失败 |
| P1-X-STENCIL | stage 离开 overlap | 明确 stencil 或 map 失败，粒子子步回滚 |

## 4. 回归与证据

P1.4 专属门禁必须生成 `summary.tsv`、源码 head、环境/配置清单和 SHA-256 manifest。随后在同一 clean exact head 运行 P1.3 lifecycle/setup/RHS/RK2/RK4、P1.2 interpolation/fields/mapping、P1.1 state、Phase 0 final gate；各历史结果目录不得覆盖。

P1.4 上运行 P1.3 lifecycle 与 P1.1 state 门禁时必须显式设置
`MITGCM_BOM_ALLOW_OWNER_MIGRATION=yes`。该兼容模式只记录两项由 P1.4
冻结契约明确替代的旧判据：严格 K4 owner 拒绝改由 halo RK/迁移门禁覆盖，
以及 `OL=1` 正向运行改为验证 `OLx/OLy>=2` 的预期启动失败；其余前序
构建、正例和负例仍须实际执行。默认 `no` 保持原阶段门禁不变。
