# P1.5 output, pickup, and FLT coexistence test plan

状态：生产实现、62/62 专属门禁、193/193 前序回归和 P1-G01
255/255 clean exact-head 总验收通过；独立 Ready 复审保留

## 1. 证据原则

每次运行必须使用全新 `test-id`，拒绝复用 build/run/artifact 目录。
门禁生成 `summary.tsv`、`source-head.txt`、空 `git-status.txt`、环境与
配置校验和、SHA-256 manifest。正向进程必须匹配正常结束；负向门禁
必须同时匹配上下文诊断和 fatal marker，不能只看退出码。

## 2. 静态与构建门禁

| 用例 | 构建 | 判据 |
|---|---|---|
| source-contract | P1.5 生产源 | 输出在迁移/状态预算后；pickup 使用核心 suffix；双字 ID；全局分解签名；scratch 后提交；无 FLT 状态引用 |
| build-neither | `ALLOW_FLT`/`ALLOW_BOM` 均关 | 编译、链接；无 BOM/FLT 未解析符号 |
| build-flt | FLT only | 编译、链接；只含 FLT 入口 |
| build-bom | BOM only | GNU debug/IEEE 编译、链接；含输出/pickup 入口 |
| build-both | FLT+BOM | 编译、链接；无重复符号或 COMMON 冲突 |
| build-both-mpi2 | FLT+BOM MPI | MPI2 编译、链接及 writer/reader 符号 |
| build-both-mpi4 | FLT+BOM MPI | MPI4 编译、链接及迁移/I/O 符号 |

## 3. P1-O01 多时刻轨迹

- serial 与 MPI4 从相同 schema 1 粒子集合运行多个海洋步；至少一个
  粒子跨 tile/rank，一个保持 WAITING 后释放，一个 ID 大于 `2^53`；
- `bomOutputFreq=2*deltaTClock`，验证每个事件所有 tiled header/meta；
- 解析每个 24-field record，验证 schema、单位、reserved、owner、
  sample/scheduled/next time 和 ID 高低字；
- 合并所有 tile 并按 `(sampleTime,INTEGER*8 id)` 排序，要求每个 key
  恰一条；同分解完整 24-field 表 bitwise 一致；跨分解对物理字段
  1—9、12—17、21—24 做 bitwise 比较，local `i/j` 与 rank/tile owner
  字段按 serial/MPI4 布局分别验证。

## 4. P1-O02 调度边界

1. `bomOutputFreq=0`：完整运行后不存在 `bom_traj*`；
2. `deltaTClock=60 s`、`bomOutputFreq=150 s`：从 `t=0` 运行八步，只在
   `180,300,480 s` 生成三组文件；scheduled time 为 `150,300,450 s`；
3. 初始化 `DO_THE_MODEL_IO`、restart 初始化和同一 iter 的重复调用均不
   产生重复帧；最终 next time 精确为 `600 s`；
4. 正频率小于一个海洋步、非有限或损坏 next time 均带上下文停止。

## 5. P1-P01 连续与 split/restart

对 serial、MPI2、MPI4 分别执行：

- 连续运行 N=8 步；
- 运行 K=5 步并生成 permanent core+BOM pickup；
- 从同 suffix、相同分解恢复，再运行 N-K 步；
- 比较最终 `bomNPartExpected`、每 tile count、完整 ID/status/x/y/
  release/age/i/j/ocean/wind/drift 和 next-output 状态；全部要求
  在同一分解的连续与 restart 之间 bitwise 一致；
- 比较连续与 split 的 canonical trajectory key 集，无缺帧、重复或
  restart 初始化帧。

## 6. P1-P02/P03 与 pickup 负测

| 用例 | 场景 | 判据 |
|---|---|---|
| P1-P02 | MPI4；大 ID、WAITING、跨 rank 后写 pickup/restart | 两字 ID、status、age、owner、诊断与 next time bitwise 无损 |
| P1-P03 | MPI2 pickup 用 MPI4 恢复 | 在 tiled read 前报告 stored/current signature 并集体停止 |
| P1-N09-schema | 修改 sig/tile schema 或 field count | 带文件/suffix/rank/tile/header 上下文停止，无权威提交 |
| P1-N09-record | 截断、坏 count、非有限值、reserved、重复 ID | scratch/global ID 检查失败，无权威提交 |
| P1-N09-time | pickup iter/time/outputFreq/next time 与运行配置不符 | 明确字段和值后集体停止 |

## 7. P1-K01/K02 FLT 共存

P1-K01 在 serial 与 MPI2 运行 neither、FLT only、BOM only、FLT+BOM。
每组必须正常结束，输出/pickup 文件只属于启用的包，关闭组合保持冻结
海洋 checkpoint 哈希。

P1-K02 使用非零、确定性的 FLT 与 BOM 粒子：

- FLT-only 与 FLT+BOM 的 `float_trajectories*`、`float_profiles*`（若
  启用）和 `pickup_flt*` 逐文件 SHA-256 一致；
- BOM-only 与 FLT+BOM 的 canonical `bom_traj*`、`pickup_bom*` 和最终
  BOM 状态一致；
- `nm` 与源搜索证明无共享 COMMON、无跨包调用、无文件前缀冲突。

## 8. P1-G01 与前序回归

P1.5 专属门禁通过后，在同一 clean exact head 运行：P1.4 owner gate；
P1.3 lifecycle/setup/RHS/RK2/RK4；P1.2 interpolation/fields/mapping；
P1.1 state；Phase 0 final gate及嵌套 P0.4。凡 P1.5 新语义替代历史判据，
必须使用默认关闭的显式兼容开关并在结果中逐项记录，禁止静默减少用例。

最终 P1-G01 从全新目录审计全部需求、summary PASS 行、manifest、
源码范围、分支/PR 状态及未创建标签事实。缺少任何直接证据即不关闭 P1。
