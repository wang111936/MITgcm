# MITGCM-BOM Phase 1：BOM-Lite 设计规格

> 本文件冻结 Phase 1 的需求、状态、环境场、数值积分、并行迁移、I/O 和 FLT 共存边界。设计评审通过前不实现粒子运动；实现若需偏离，必须先更新本文件、追踪表和对应测试。

| 项目 | 值 |
|---|---|
| 设计版本 | 1.2（P1.2 映射与环境场接口冻结） |
| 日期 | 2026-08-24 |
| 基线标签 | `MITGCM-BOM-v0.1` |
| 基线提交 | `b2f3ecf1081f7bab25749c4a6004730175d99955` |
| MITgcm 上游基线 | `dfc30dafb16561462ef1d4f9518f5d78753ec750` |
| Julia 参考 | `SargassumBOMB.jl@156557359185e4413ce82829f3ed26a4eb8c6283` |
| 目标版本 | `MITGCM-BOM-v0.2` |
| 目标平台 | Linux HPC，GNU/OpenMPI 为第一工具链 |

## 1. 目标、边界与完成定义

### 1.1 Phase 1 目标

Phase 1 建立一个可验证、可重启、可在规则网格 MPI 分解间迁移的二维表层粒子内核。完成后，`pkg/bom` 应能：

1. 从独立 BOM 初始文件读取固定数量的粒子；
2. 把 MITgcm 表层 C-grid `uVel/vVel` 转为 C 点 east/north 速度；
3. 在规则 Cartesian 或未旋转 spherical-polar 网格上定位粒子并做湿点归一化双线性插值；
4. 按固定子步执行显式 RK2 或 RK4；
5. 在 tile 和 MPI rank 之间迁移唯一 owner 状态；
6. 输出独立 BOM 轨迹文件；
7. 在相同 MPI/tile 分解下完成确定性 pickup 重启；
8. 与 `pkg/flt` 分别开启、同时开启或分别关闭，不共享状态且不发生符号或文件冲突。

Phase 1 的物理模式固定为 `bomMode='LEEW'`。其速度定义为

$$
\mathbf v_p=\mathbf v_E+\alpha_{10}\mathbf v_{10},
$$

其中 $\mathbf v_E$ 为 MITgcm 表层欧拉流，$\mathbf v_{10}$ 为可选 EXF 10 m 风，`bomLeewayWindCoeff` 为无量纲经验风偏移系数。海流单独测试时该系数为 0。

### 1.2 明确不属于 Phase 1

- 慢流形 Maxey–Riley 惯性修正；
- Stokes 漂移进入运动方程；
- 弹簧、邻居、raft 连通分量和 ghost 粒子；
- 生长、出生、死亡、搁浅状态转换和 free-list；
- 三维运动、沉降或再悬浮；
- `EXCH2`、cubed-sphere、LLC、旋转或一般曲线网格；
- 改变 MPI/tile 分解后的 pickup 重启；
- OpenMP 多线程生产支持；
- Julia 自适应 ODE 求解器的逐步复刻；
- BOM 对海洋状态的反向反馈。

选择上述边界的目的，是先验证所有后续物理都会依赖的坐标、插值、owner、时间推进和重启基础设施。

### 1.3 Phase 1 完成定义

只有同时满足以下条件，Phase 1 才能标记为完成并创建 `MITGCM-BOM-v0.2`：

- 本文件和需求追踪表中的 `P1-R01`—`P1-R16` 均有实现与可执行证据；
- B01、B02、B03、B06、B10、B15 的 Phase 1 子集全部通过；
- 1、2、4 MPI ranks 的解析轨迹和 owner 预算满足规定容差；
- 相同分解连续运行与 pickup 重启的最终权威状态逐字段 bitwise 相同；
- BOM 关闭、零粒子和 FLT/BOM 共存门禁没有改变冻结的 MITgcm 基线结果；
- 容量、重复 ID、非法参数、缺失依赖和不支持网格均明确停止，不得静默降级；
- 所有提交保持 `WangYuLin <wang111936@outlook.com>` 作者身份并在独立阶段 PR 中留痕。

## 2. 参考行为与方程裁决

### 2.1 Julia 对照范围

锁定 Julia 源码的 `Leeway!` 使用：

$$
\dot x=v_{E,x}+\alpha v_{W,x},\qquad
\dot y=v_{E,y}+\alpha v_{W,y}.
$$

它不叠加 Stokes 漂移，也不使用 `ClumpParameters.σ`。因此 Phase 1 的 Julia 对照只覆盖 leeway RHS 分量和由该 RHS 得到的轨迹；不把 Julia 的以下行为作为生产规范：

- 默认 `Tsit5` 自适应积分器；
- equirectangular、km 和 day 的内部单位；
- 通过位置是否变化判断粒子存活；
- 全局数组槽号直接充当永久粒子 ID。

MITGCM-BOM 内部使用 SI，位置采用 MITgcm 原生水平坐标，时间使用秒，并以显式状态码判断粒子是否存活。

### 2.2 风参数命名

Phase 1 使用 `bomLeewayWindCoeff`，避免与后续 BOM 慢流形方程的水—风混合参数 `bomAlpha` 混淆：

- `bomLeewayWindCoeff`：工程 leeway，直接把风速的一部分加到欧拉流；
- `bomAlpha`：Phase 2 慢流形方程中的暴露/混合参数，进入 $(1-\alpha)\mathbf v+\alpha\mathbf v_W$。

两个参数不得互为别名，轨迹元数据必须记录实际使用的参数名和值。

### 2.3 Stokes 漂移在本阶段的处理

Stokes 漂移表示表面重力波引起的拉格朗日平均净位移速度。它可在后续物理中与欧拉流组成水体携带速度，但若外部海流产品已包含波致漂移，再叠加会重复计数。

Phase 1 冻结以下接口约束：

- `bomStokesSource='NONE'` 是唯一合法运行值；
- 不读取 Stokes 文件，不分配 old/new Stokes 场，不把 Stokes 加入 leeway RHS；
- `FILES` 和 `COUPLER` 名称保留给 Phase 2，Phase 1 选择它们必须由 `BOM_CHECK` 明确拒绝；
- Phase 2 启用前必须增加“海流是否已含 Stokes”的配置和元数据检查。

## 3. 实施增量与 PR 边界

Phase 1 分六个可独立审查的工作包。后一个工作包只在前一个门禁通过后开始。

| 工作包 | 范围 | 主要交付 | 最小门禁 |
|---|---|---|---|
| P1.0 | 设计冻结 | 本规格、阶段记录、追踪表、测试计划 | Markdown 审计，无源码变化 |
| P1.1 | 状态与初值 | Phase 1 SoA、参数、初始文件读取、ID/容量检查 | 编译矩阵、零/单/多粒子初始化 |
| P1.2 | 映射与环境场 | C-grid 转换、east/north 场、坐标映射、湿点插值 | Cartesian/spherical 映射与均匀场插值 |
| P1.3 | 单 tile 积分 | 子步、RK2/RK4、海流和可选 EXF 风 RHS | B01–B03、B06 单 tile |
| P1.4 | owner 迁移 | tile/rank 交换、重复迁移、全局预算 | B10，1/2/4 ranks 分解一致 |
| P1.5 | 输出与重启 | 轨迹、pickup、FLT 共存和集成门禁 | B15、共存矩阵、完整回归 |

每个实现 PR 只能覆盖表中一个工作包。若发现架构问题，先把问题和裁决写入设计决策记录，再更新需求和测试；不得把未评审的新物理顺带加入当前 PR。

## 4. 生命周期与调用契约

### 4.1 MITgcm 挂接点

| 调用位置 | BOM 例程 | Phase 1 契约 |
|---|---|---|
| `packages_readparms.F` | `BOM_READPARMS` | 设置默认值、读取 namelist；`useBOM=.FALSE.` 时立即返回 |
| `packages_check.F` | `BOM_CHECK` | 检查模式、网格、依赖、时间步和容量配置 |
| `packages_init_fixed.F` | `BOM_INIT_FIXED` | 建立静态映射辅助量并注册计时/输出元数据 |
| `packages_init_variables.F` | `BOM_INIT_VARIA` | 从初值或 pickup 恢复 owner 粒子并建立局部索引 |
| `forward_step.F` | `BOM_MAIN` | 把粒子从 `myTime-deltaTClock` 推进到 `myTime` |
| `packages_write_pickup.F` | `BOM_WRITE_PICKUP` | 在 MITgcm pickup 时刻写 BOM 独立 pickup |

Phase 0 已建立前五类挂接中的空实现；`packages_write_pickup.F` 挂接属于 P1.5。`BOM_MAIN` 继续位于 `FLT_MAIN` 之后，两个包都只读本海洋步的状态。

### 4.2 `BOM_MAIN` 顺序

每个海洋步执行：

1. 构造本步冻结的表层 east/north 环境场并完成 halo exchange；
2. 计算 `nSub = max(1, ceiling(deltaTClock/bomDeltaTTarget))`；
3. 令 `bomDeltaT = deltaTClock/nSub`，不得留下截断的末子步；
4. 对每个子步执行 RK stage；
5. 提交新位置，更新局部分数索引；
6. 重复迁移，直至每个活粒子回到唯一 owner tile；
7. 检查全局粒子数、ID、有限数和 owner 不变量；
8. 到达输出时刻时写轨迹。

Phase 1 在一个海洋步内冻结环境场；不声称对时变场有高阶时间精度。old/new 场及 stage 时间插值属于 Phase 2，届时 B05 会单独验证。

工作包边界进一步固定为：P1.3 执行步骤 1—5，并在每个 stage 和最终候选位置要求粒子仍属于当前 owner tile；离开 owner 时带上下文终止。P1.4 才以受测试的迁移替换该拒绝路径并完成步骤 6；P1.5 才加入步骤 8。P1.3 中 `BOM_MAIN` 收到步末 `myTime`，权威积分区间为 `[myTime-deltaTClock,myTime]`。

## 5. 运行参数契约

### 5.1 保留的 `BOM_PARM01`

| 参数 | Phase 1 含义 | 默认/限制 |
|---|---|---|
| `bomMode` | 运动方程模式 | 默认且仅允许非零粒子使用 `LEEW` |
| `bomEquationMode` | 后续方程裁决 | 保留 `PAPER2024`，Phase 1 不改变 RHS |
| `bomIntegrator` | 固定步积分器 | `RK2` 或 `RK4`，默认 `RK4` |
| `bomDeltaTTarget` | 目标粒子子步 | 秒，必须大于 0 |
| `bomOutputFreq` | 轨迹输出间隔 | 秒，0 表示关闭 |
| `bomPickupFreq` | 保留的独立周期设置 | Phase 1 默认且仅允许 0；只跟随 MITgcm pickup |
| `bomSeed` | 后续确定性事件种子 | 保留并写元数据，Phase 1 不使用随机数 |
| `bomMaxParticles` | 全局允许粒子数上限 | 0 为零粒子模式；不得超过输入头声明上限 |
| `bomInitialFile` | 初始文件前缀 | 非零粒子且非重启时必须提供 |

`bomMaxParticles` 是运行时全局上限，不是数组第一维。每 tile 静态容量由 `bomMaxPartTile` 决定；启动时必须同时验证全局输入计数和每 tile 初始计数。

### 5.2 新增 `BOM_PARM02`

| 参数 | 类型 | 默认 | 合法值/单位 |
|---|---|---:|---|
| `bomLeewayWindCoeff` | `_RL` | 0 | 无量纲，$0\leq\alpha_{10}\leq0.1$ |
| `bomWindSource` | `CHARACTER*8` | `NONE` | `NONE`、`EXF` |
| `bomStokesSource` | `CHARACTER*8` | `NONE` | Phase 1 仅 `NONE` |
| `bomWetWeightMin` | `_RL` | 0.5 | $(0,1]$ |
| `bomAdvCFL` | `_RL` | 0.5 | $(0,1]$，运行时位移防护 |
| `bomMaxHop` | `INTEGER` | 8 | 每子步最多 owner 迁移轮数，正整数 |
| `bomInitGlobalLimit` | `INTEGER` | 10000 | P1.1 全局初值读取的硬上限，正整数 |
| `bomCheckEverySubstep` | `LOGICAL` | `.TRUE.` | 调试期预算检查开关 |

约束：

- `bomWindSource='NONE'` 时，风场严格为 0；若风系数非零，`BOM_CHECK` 报错；
- `bomWindSource='EXF'` 时必须编译 `ALLOW_EXF`，运行时启用 `useEXF` 与 `useAtmWind`，且风系数必须非负；
- `bomPickupFreq` 非零时明确停止，避免产生没有对应海洋状态的孤立 BOM pickup；
- 非零粒子且 `bomMode` 为 `BOM`、`EBOM` 或 `EBOMB` 时明确停止；
- `bomIntegrator='RK2'` 定义为显式中点法，不是 FLT 的旧 RK2 变体；
- 不支持的网格、旋转、`ALLOW_EXCH2` 或多线程配置在 Phase 1 明确停止。

## 6. 粒子状态与容量

### 6.1 Phase 1 权威 SoA

每个 tile 的有效 owner 槽位严格为 `1:bomNPartTile(bi,bj)`，内部保持紧凑。Phase 1 没有出生/死亡，因此暂不建立 free-list。

| 字段 | 类型 | 语义 | pickup | 迁移 |
|---|---|---|---:|---:|
| `bomNPartTile` | `INTEGER` | tile 的 owner 粒子数 | 是 | 由收发重建 |
| `bomId` | `INTEGER*8` | 全局唯一、正数、永不重写 | 是 | 是 |
| `bomStatus` | `INTEGER` | 显式状态码 | 是 | 是 |
| `bomX`, `bomY` | `_RL` | MITgcm 原生全局水平坐标 | 是 | 是 |
| `bomReleaseTime` | `_RL` | 开始运动的模型时间，秒 | 是 | 是 |
| `bomAge` | `_RL` | 已激活运动时间，秒 | 是 | 是 |
| `bomI`, `bomJ` | `_RL` | owner tile 局部分数索引缓存 | 否，可重建 | 是 |
| `bomVEast`, `bomVNorth` | `_RL` | 最近一次欧拉流诊断 | 否 | 否 |
| `bomWindEast`, `bomWindNorth` | `_RL` | 最近一次风诊断 | 否 | 否 |
| `bomDriftEast`, `bomDriftNorth` | `_RL` | 最近一次总漂移诊断 | 否 | 否 |

Phase 1 使用以下状态码：

| 值 | 名称 | 行为 |
|---:|---|---|
| 0 | `BOM_UNUSED` | 仅未用槽位，不能出现在有效紧凑区 |
| 1 | `BOM_ALIVE` | 参与积分、迁移和轨迹输出 |
| 2 | `BOM_DEAD_BIO` | 保留给 Phase 4，Phase 1 输入不得使用 |
| 3 | `BOM_BEACHED` | 保留给 Phase 4，Phase 1 输入不得使用 |
| 4 | `BOM_OUTSIDE` | 开放边界外；保留在边界 tile，但不再运动 |
| 5 | `BOM_INVALID` | NaN、映射失败或状态损坏，运行立即停止 |
| 6 | `BOM_WAITING` | 未到 `bomReleaseTime`，位置不变但仍有 owner |

`BOM_DEAD_BIO` 和 `BOM_BEACHED` 的编码沿用总体开发手册，具体事件语义在 Phase 4 冻结；Phase 1 不产生这些状态。

### 6.2 坐标语义

- Cartesian 网格：`bomX/bomY` 与 `xC/yC` 同单位，要求为米；
- spherical-polar 网格：`bomX` 为东经度、`bomY` 为纬度，单位为 degree；
- 粒子速度和环境向量始终为 east/north、m s$^{-1}$；
- 输出可同时给出原生坐标和 lon/lat；Cartesian 算例若无地理变换，lon/lat 写缺测值。

球面网格的 RHS 转换为：

$$
\dot\lambda=\frac{180}{\pi}\frac{v_\mathrm{east}}{r_\mathrm{Sphere}\cos\phi},\qquad
\dot\phi=\frac{180}{\pi}\frac{v_\mathrm{north}}{r_\mathrm{Sphere}}.
$$

Phase 1 拒绝包含极点或使 `cos(phi)` 小于安全阈值的网格。

### 6.3 容量和不变量

- `bomMaxPartTile` 从 Phase 0 的占位值提升为 verification 明确配置的静态上限；
- `bomMaxExchange` 是一轮单方向交换容量；
- `bomMaxGhostTile`、`bomMaxNeighbor` 和 `bomMaxEventBuffer` 保留但 Phase 1 不使用；
- 容量不足时输出 rank、tile、实际需要量和编译上限后全局停止；
- 不能像 FLT 一样把 `INTEGER*8` ID 直接放入单个 `_RL` 交换字段；交换和文件中使用高、低 32 位，重组后校验；
- 每次迁移后总记录数必须保持不变，ALIVE 数等于已释放数减去明确的 outside 数；
- 每个 WAITING、ALIVE 或 OUTSIDE ID 只能在一个 owner tile 出现一次。

## 7. 初始粒子文件

### 7.1 文件形式

Phase 1 采用 BOM 独立的 MDS 风格全局二进制文件，不复用 FLT 文件。前缀由 `bomInitialFile` 给出，包含：

- `<prefix>.meta`：标准维度、精度和记录数元数据，并以 `fldList(1)='BOMV0001'` 记录 BOM schema；
- `<prefix>.data`：big-endian IEEE 64-bit 记录。

第一个记录为 8 个 `_RL` 头字段：

| 序号 | 字段 | 值/含义 |
|---:|---|---|
| 1 | schema | Phase 1 为 1 |
| 2 | fieldsPerParticle | Phase 1 为 8 |
| 3 | nParticles | 全局记录数 |
| 4 | coordinateCode | 1=`MODEL_NATIVE` |
| 5 | idEncoding | 1=`UINT32_PAIR` |
| 6 | precisionBits | 64 |
| 7 | reserved | 必须为 0 |
| 8 | reserved | 必须为 0 |

后续每粒子记录：

| 序号 | 字段 | 约束 |
|---:|---|---|
| 1 | `id_hi` | 0 到 $2^{31}-1$，以 `_RL` 精确保存 |
| 2 | `id_lo` | 无符号 32 位值，以 `_RL` 精确保存 |
| 3 | `x` | 模型原生全局坐标 |
| 4 | `y` | 模型原生全局坐标 |
| 5 | `releaseTime` | 模型秒；小于等于 `startTime` 表示立即释放 |
| 6 | `status` | 只允许 WAITING 或 ALIVE |
| 7 | `age` | 非负秒，初始通常为 0 |
| 8 | reserved | 必须为 0 |

### 7.2 读取与分发

P1.1 可让各 rank 读取同一个小型 verification 全局文件，再只保留属于本 rank/tile 的记录，但必须受 `bomInitGlobalLimit` 硬上限保护；超过上限时明确停止。生产可扩展的分片读取属于 P1.5 前必须完成的设计复核项，不能把百万粒子永久 gather 到 rank 0，也不能让所有 ranks 永久读取完整生产文件。

读取前必须交叉验证 meta 和头记录计数，并要求 `<prefix>.data` 的实际长度精确等于 `(nParticles+1) * fieldsPerParticle * 8` 字节；截断、完整额外记录和任意残缺尾随字节均为致命错误。读取后执行：schema、有限数、ID 正数且全局唯一、状态、release time、坐标域、湿单元、全局上限和每 tile 容量检查。错误输入不得部分接受。

为使 P1.1 的初值分发可独立验收，允许本工作包提供只服务于规则网格初始 owner 判定的 `BOM_LOCATE_INITIAL`。它不提供周期规范化、stage-time 映射、反向坐标变换或插值 stencil，不能替代 P1.2 的完整映射接口。

## 8. 环境场接口

### 8.1 Phase 1 字段表

| BOM 量 | 来源 | 位置 | 单位 | Phase 1 |
|---|---|---|---|---|
| `bomGridVEast/bomGridVNorth` 网格场 | `uVel/vVel(:,:,1)` | C 点 | m s$^{-1}$ | 必需 |
| 风网格场 | EXF `uwind/vwind` | C 点 | m s$^{-1}$ | P1.3 |
| `maskC(:,:,1)` | MITgcm GRID | C 点 | 0/1 | 必需 |
| Stokes | 无 | C 点 | m s$^{-1}$ | 固定为 0 |

`BOM_BUILD_FIELDS` 使用单层工作数组调用 `ROTATE_UV2EN_RL`：`xy2en=.TRUE.`、`switchGrid=.TRUE.`、`applyMask=.TRUE.`。不得以错误的三维数组步长把完整 `Nr` 数组伪装成 `kSize=1`。

单层输入固定命名为 `bomGridUWork/bomGridVWork`，C 点输出固定命名为 `bomGridVEast/bomGridVNorth`，避免与每粒子诊断 `bomVEast/bomVNorth` 冲突。四个数组都有显式 `kSize=1` 维。转换完成后把 east/north 当作固定地理方向的两个标量，分别执行 `EXCH_3D_RL(...,1,myThid)`，再允许粒子插值；不得再次应用模型网格矢量换向。BOM 不修改 `uVel`、`vVel`、EXF 字段或海洋 tendency。

P1.2 的完整接口、失败语义和实现顺序由 [`P1.2_INTERFACE_FREEZE.md`](../../../verification/bom/phase01-bom-lite/P1.2_INTERFACE_FREEZE.md) 冻结。P1.2 只建立欧拉表层场；EXF 风进入 RHS 属于 P1.3，Stokes 在 Phase 1 继续固定为 0。

### 8.2 时间语义

`BOM_MAIN(myTime,myIter,myThid)` 被调用时，Phase 1 将当时可见的海流和风冻结为区间 `[myTime-deltaTClock,myTime]` 的驱动。该近似只在稳态解析场中作为 Phase 1 验收依据。

对真实时变外场，Phase 1 输出元数据必须标记 `fieldTimeMode='STEP_END_FROZEN'`。Phase 2 引入 old/new 快照后，schema 和测试将升级为 stage-time 线性插值。

### 8.3 双线性插值和海岸防护

1. 先把 east/north 分量 colocate 到 C 点；
2. 使用粒子 stage 位置对应的四个 C 点；
3. `BOM_INTERP_WET_PAIR` 让两个分量逐位复用同一组几何权重，权重只保留 `maskC(:,:,1)>0` 的湿点，随后按共同湿权重和重新归一化；
4. stencil 不完整、字段未就绪、值非有限或湿权重和小于 `bomWetWeightMin` 时先返回显式无效状态，再由带粒子/tile 上下文的调用层清晰停止；
5. 不对域外做常数外推；周期经度在映射层规范化；
6. 所有分量使用完全相同的位置、mask 和权重。

Phase 1 不把海岸失败解释为搁浅。搁浅是 Phase 4 的状态转换，提前引入会混淆数值错误与物理事件。

## 9. 映射、积分与 owner 迁移

### 9.1 支持的网格

Phase 1 只支持：

- `usingCartesianGrid=.TRUE.`；或
- `usingSphericalPolarGrid=.TRUE.` 且 `rotateGrid=.FALSE.`；
- 规则 tile 邻接，`ALLOW_EXCH2` 未启用；
- `nTx*nTy=1` 的 MPI-only 验收配置。

映射算法可参考 `FLT_MAP_XY2IJLOCAL` 和 `FLT_MAP_IJLOCAL2XY`，但使用独立的 `BOM_MAP_XY2IJLOCAL`、`BOM_MAP_IJLOCAL2XY` 和 `BOM_NORMALIZE_X`，具有独立 mask 语义和错误处理，不在运行时调用 FLT 例程。`isOwner` 与 `hasStencil` 必须分别返回：stage 位置允许落在当前 owner 的 overlap stencil 内，但不能因此改变 committed owner。

边界恰好命中时采用 `[west,east) x [south,north)` 半开区间。内部边界因此归属于以该点为西/南边界的东/北侧 tile；内部角点归属于东北侧 tile，不再另设“全局 tile 编号最小”这一相互矛盾的 tie-break。若数值误差仍产生多个候选 owner，必须停止。

周期经度只在 `usingSphericalPolarGrid` 且全局 `sum(delX)` 在尺度化机器精度容差内等于 360° 时启用，并先规范化到 `[xgOrigin,xgOrigin+360)`；上界等价于下界。区域 spherical-polar 和所有 Cartesian 域不自动回绕，南北方向在 Phase 1 不回绕。坐标比较容差不得扩张 owner 半开区间造成重复归属。

### 9.2 RK 定义

- RK2：显式中点法；
- RK4：经典四阶段 RK4；
- stage 中只产生临时位置，不改变权威数组长度或 owner；
- 每个 stage 重新映射并插值；
- 每个 stage 检查位置、RHS 和权重为有限数；
- WAITING 粒子的所有 stage RHS 为 0；跨越 release time 的子步在 release time 处分割，使 age 和位移不依赖粗时间步。

为保证 stage 可从当前 owner 的 halo 取值，每个子步的预计位移必须满足配置的 advective CFL，并不超过可用 overlap。超限时停止并打印 ID、速度、局部网格尺度和建议子步。

### 9.3 owner 迁移

每个完整子步后：

1. 根据提交位置判定粒子是否仍属当前 tile；
2. 按 east/west 方向打包离开粒子，完成收发并压紧 owner 数组；
3. 按 north/south 方向重复；
4. 若仍不属于本 tile，继续迁移轮次；
5. 超过 `bomMaxHop` 时全局停止；
6. 重建 `bomI/bomJ` 并检查唯一 owner 和全局预算。

交换记录带 schema，至少包括 `id_hi/id_lo`、status、x、y、release time、age。接收前先检查容量，发送粒子只有在成功打包后才从 owner 集合删除。

开放边界由 MITgcm 拓扑判定。离域粒子转为 `BOM_OUTSIDE`，保留在最后一个边界 owner tile，并写最终轨迹；周期边界保持 ALIVE。Phase 1 不允许未经声明的跨域回绕。

## 10. FLT 共存边界

| 方面 | FLT | BOM Phase 1 | 共存规则 |
|---|---|---|---|
| 编译开关 | `ALLOW_FLT` | `ALLOW_BOM` | 可独立组合 |
| 运行开关 | `useFLT` | `useBOM` | 可独立组合 |
| 状态 | `FLT.h` 九字段 `_RL` | `BOM.h` 独立 SoA | 不共享 COMMON |
| 映射/插值 | `FLT_*` | `BOM_*` | 只参考算法，不交叉调用 |
| 主循环 | 先 `FLT_MAIN` | 后 `BOM_MAIN` | 都只读海洋状态 |
| 迁移缓冲 | `FLT_EXCHG_BUFF` | `BOM_EXCHG_*` | 名称、schema 和容量独立 |
| 初始文件 | `float_positions*` | `bomInitialFile*` | 格式互不冒充 |
| 轨迹 | FLT 自有文件 | `bom_traj*` | 前缀不冲突 |
| pickup | `pickup_flt.*` | `pickup_bom.*` | 分别写、分别恢复 |
| 粒子 ID | `_RL npart` | `INTEGER*8 bomId` | 不做隐式互转 |

共存验收必须覆盖四种运行组合：两者均关、仅 FLT、仅 BOM、两者均开。两者均开时，BOM 轨迹必须与仅 BOM 在相同环境场下相同；FLT 结果也必须与仅 FLT 相同。

## 11. 轨迹与 pickup

### 11.1 轨迹 schema 1

每条轨迹记录至少包含：

```text
time, id_hi, id_lo, status, x, y, lon, lat,
vE_east, vE_north, wind_east, wind_north,
drift_east, drift_north, owner_rank, owner_tile
```

文件前缀为 `bom_traj`，按 rank/tile 分片，写入 schema、Git 提交、方程模式、积分器、时间语义和实际参数。验证后处理按 `(time,id_hi,id_lo)` 排序，禁止依赖 rank 文件顺序。

### 11.2 pickup schema 1

文件前缀为 `pickup_bom.<suffix>`，至少保存：

- schema、模型时间、迭代号和分解签名；
- `bomNPartTile`；
- ID、status、x、y、release time、age；
- 下一轨迹输出时刻和计数；
- 模式、积分器、坐标类型和影响轨迹的参数指纹。

`bomI/bomJ` 和诊断速度在恢复后重建。Phase 1 pickup 只保证相同 `nPx/nPy/nSx/nSy/sNx/sNy` 的重启；分解签名不一致时明确拒绝。写 pickup 前刷新轨迹缓冲，避免重启后重复或丢失记录。

## 12. 风险、异常与设计变更协议

| 风险 | 早期检测 | 处置 |
|---|---|---|
| C-grid 旋转/colocation 方向错误 | 均匀 east/north 与旋转网格单元测试 | 修正 P1.2，不在积分器补符号 |
| 球面坐标把 m/s 当 degree/s | 赤道和非零纬度解析位移 | 修正映射/RHS 单位层 |
| stage 越过可用 halo | CFL 和 overlap 运行时检查 | 减小子步；不做无数据外推 |
| ID 经 `_RL` 失真 | 高/低 32 位往返测试 | 所有 I/O 和交换统一 pair 编码 |
| 迁移时丢失或复制粒子 | 每子步 owner/ID 预算 | 停止并保留测试证据，修正交换协议 |
| FLT 与 BOM 文件或 COMMON 冲突 | 四组合共存测试 | 重命名 BOM 资源，不修改 FLT 状态 |
| 时变场精度不足 | 输出 `STEP_END_FROZEN` 元数据 | Phase 2 引入 old/new，不虚报 RK 时间阶 |
| pickup 隐含分解依赖 | 分解签名和重启门禁 | Phase 1 拒绝变分解，后续单独设计 |
| 静态容量不足 | 启动估算与溢出负测 | 调整 `BOM_SIZE.h` 后重建，不截断 |
| HPC 编译器差异 | GNU 调试门禁后增加目标编译器矩阵 | 记录编译器特例，不改变科学方程 |

遇到未预见问题时：

1. 保留最小复现输入、命令、日志和源码 SHA；
2. 判断属于实现缺陷、设计缺口、外部依赖或服务器配置；
3. 为设计缺口新增 `P1-Dxxx` 决策，更新需求追踪与测试；
4. 只在当前工作包范围内修复；需要扩大物理范围时结束当前 PR 并另建工作包；
5. 门禁失败不得通过放宽容差、吞掉错误或删减测试解决。

## 13. Phase 1 设计决策

| ID | 决策 | 原因 |
|---|---|---|
| P1-D001 | Phase 1 只实现 `LEEW` 非惯性运动 | 先隔离坐标、插值、积分和迁移风险 |
| P1-D002 | Stokes 在 Phase 1 固定为 NONE | Julia `Leeway!` 不含 Stokes；外部场时间接口属于 Phase 2 |
| P1-D003 | 风偏移参数独立命名 | 防止与慢流形 `bomAlpha` 混淆 |
| P1-D004 | 原生模型坐标为权威位置，速度统一 SI east/north | 与 MITgcm 网格映射一致并避免单位混用 |
| P1-D005 | RK2 为显式中点，RK4 为经典格式 | 算法明确、易做解析和收敛测试 |
| P1-D006 | 环境场在海洋步内冻结 | Phase 1 不提前引入 Phase 2 的 old/new 导数状态 |
| P1-D007 | Phase 1 owner 数组紧凑、无 free-list | 本阶段粒子数固定；动态槽位留给生物事件阶段 |
| P1-D008 | ID 在 I/O/通信中拆为两个 32 位字 | 避免 64 位整数经 `_RL` 丢失精度 |
| P1-D009 | 与 FLT 独立实现、仅以其算法为参考 | BOM 后续状态和通信需求超出 FLT 九字段模型 |
| P1-D010 | Phase 1 pickup 限相同分解 | 先建立确定性重启，再设计可扩展重分片读取 |
| P1-D011 | 海岸插值失败在 Phase 1 为致命错误 | 搁浅状态和岸线策略必须在 Phase 4 统一验证 |
| P1-D012 | Phase 1 先验收 MPI-only | OpenMP 共享状态安全在功能正确后单独加固 |
| P1-D013 | P1.1 使用受限初值 locator，并以 `[west,east) x [south,north)` 唯一定义内部边界 owner | 初值读取必须能独立验收；同时消除“西/南含边界”与“最小 tile 编号”的冲突，完整映射仍留在 P1.2 |
| P1-D014 | 初始 `.data` 物理长度必须精确等于 `(nParticles+1)*8*8` 字节 | meta/header 计数一致仍不能证明文件完整；截断、完整额外记录和残缺尾随字节必须在接受粒子前失败 |
| P1-D015 | P1.2 网格场使用 `bomGrid*`，保留 `bomVEast/bomVNorth` 给每粒子诊断 | 防止 COMMON 符号与语义冲突，便于 P1.3 明确区分网格输入和粒子采样值 |
| P1-D016 | 只对完整 360° 规则球面域做周期经度规范化 | 区域球面和 Cartesian 域不能根据坐标外观静默回绕；上界按半开域映射到下界 |
| P1-D017 | C-grid 转换后的 east/north 分量分别执行标量 halo exchange | east/north 已处于固定地理基，不应再次应用模型网格矢量符号或旋转规则 |
| P1-D018 | 湿点 pair 插值共享权重并返回显式有效性，状态转换留给调用层 | 数值内核可测试且不会把插值失败提前解释为 Phase 4 搁浅物理 |
| P1-D019 | Julia 参考不裁决 MITgcm 网格映射或湿点 stencil | 锁定 Julia 使用 equirectangular 插值器，没有 C-grid、tile、halo 和 BOM owner 语义 |
| P1-D020 | stage stencil 的低端索引使用数学 floor，不直接使用 Fortran `INT` | stage 可进入西/南 overlap 的负分数索引；`INT` 向零截断会选择错误 C 点并可能误判 stencil 可用 |
| P1-D021 | P1.3 把步末 `myTime` 对应的 `[myTime-deltaTClock,myTime]` 等分为 `ceiling(deltaTClock/bomDeltaTTarget)` 个子步 | 覆盖完整海洋步、消除短尾步并保持确定性 |
| P1-D022 | Julia `Leeway!` 只裁决 `water+coeff*wind` 及 m/s 与 km/day 换算，不裁决固定步积分器 | 锁定 Julia 默认使用自适应 Tsit5，坐标为 equirectangular km、时间为 day |
| P1-D023 | EXF 10 m `uwind/vwind` 必须复制到 BOM 自有格心 east/north 冻结快照 | 让整个粒子步只读单一已发布快照，并隔离 EXF COMMON 的更新时序 |
| P1-D024 | RK2/RK4 的每个 stage 与最终候选均执行映射、湿点、有限数、CFL 和当前 owner 硬检查，成功后才按粒子子步一次提交 | 避免部分 stage 结果污染权威 SoA，并为失败保留完整上下文 |
| P1-D025 | P1.3 对任何 stage 或最终候选的 owner 离开立即失败 | owner 迁移、交换容量和重复 hop 属于 P1.4，不能由 halo 静默替代 |
| P1-D026 | WAITING 粒子在 release time 精确分割 nominal 子步，age 只累计成功提交的激活时长 | 避免提前释放或丢失 release 所在子步的有效运动时间 |
| P1-D027 | `bomCheckEverySubstep` 只控制昂贵的完整预算频率，不得关闭 stage 数值安全检查；海洋步末预算始终执行 | 安全开关不能把 NaN、CFL、湿点或 owner 错误变成可继续运行状态 |
| P1-D028 | 粒子速度诊断定义为最终已提交位置的冻结场样本，不是 RK 加权平均或最后 stage 缓存 | 输出和后续 pickup 可用一个明确、可重建的诊断语义 |
| P1-D029 | P1.3 分别记录步末海流 `(t1,iter1)` 与本海洋步 EXF 请求 `(t0,iter1-1)` 的时间标签 | `LOAD_FIELDS_DRIVER` 在时间计数更新前调用 EXF，而 BOM 在更新后调用；不能把风场误标为步末场 |
| P1-D030 | 在 `CEILING` 前验证 target、CFL、系数、`subRatio` 和时间端点有限且可表示，并在导出后复核 `dtSub>0` | 防止 NaN 绕过范围比较、整数转换溢出和极小 target 导致零子步时长 |
| P1-D031 | CFL 最近 C 点使用 `floor(index+0.5)`，半格归东/北；度量必须有限正值，球面 `abs(cos(phi))` 下界为 `sqrt(EPSILON(oneRL))` | 消除编译器/舍入相关的 tie、无效 reciprocal metric 和近极点除法歧义 |
| P1-D032 | P1.3 保存成功初值的 `bomNPartExpected`，完整预算精确检查全局计数与 ID 唯一性；紧凑槽只允许 ALIVE/WAITING | P1.3 不迁移、不增删粒子，必须能检测 owner 丢失、重复 ID 和未授权状态，而非只与容量上限比较 |
| P1-D033 | RK 收敛使用固定全湿 Cartesian 仿射场、解析指数解和 `T/4—T/32` 四个步长 | 让 RK2/RK4 阶数门禁在实现前可复现，禁止运行后调整 fixture 迎合结果 |

## 14. 进入实现前的冻结检查

- [x] P1.0 PR 只含 Markdown，已审计无 Fortran、脚本或测试产物；
- [x] `P1-R01`—`P1-R16` 均有计划验收测试；
- [x] 初始文件、轨迹和 pickup 的 schema 1 已确认；
- [x] `bomLeewayWindCoeff` 与后续 `bomAlpha` 的区别已确认；
- [x] Stokes Phase 1 固定为 NONE；
- [x] 支持网格、线程和 restart 限制已确认；
- [x] FLT/BOM 四组合共存矩阵已列入集成门禁；
- [x] 每个实现工作包都有独立退出条件；
- [x] Phase 0 的零影响门禁继续作为每个实现 PR 的回归测试；
- [x] P1.1 已完成并集成；P1.2 已完成、独立复审并通过 PR #10—#12 收口；
- [x] P1.2 映射、环境场、插值和失败接口已在独立冻结记录中明确；
- [x] P1.3 已从 `development@eefca92fe` 建立独立分支并冻结单 tile 积分接口；
- [x] P1.3 独立设计复审已关闭 P1.3-A—P1.3-E，修订 head `941c74e5b` 复核 PASS；生产 Fortran 仍需单独授权。
