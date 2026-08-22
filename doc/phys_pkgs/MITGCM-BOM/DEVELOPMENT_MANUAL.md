# MITgcm-BOM 开发手册

> 面向 Linux 高性能计算服务器的马尾藻漂移、筏团相互作用与生命周期模块

| 项目 | 内容 |
|---|---|
| 手册版本 | 0.1（实施基线） |
| 更新日期 | 2026-08-23 |
| MITgcm 基线 | `dfc30dafb16561462ef1d4f9518f5d78753ec750` |
| Julia 参考基线 | `70Gage70/SargassumBOMB.jl@156557359185e4413ce82829f3ed26a4eb8c6283` |
| 理论基线 | Bonner、Beron-Vera 和 Olascoaga（2024），eBOMB |
| 首个生产目标 | 规则经纬网、在线单向耦合、MPI、确定性重启 |
| 模块目录 | `pkg/bom` |
| 验证算例目录 | `verification/bom` |

本文是后续源码开发、代码审查和验收的共同依据。开始修改源码前，应先冻结本手册中的接口、状态定义、单位和测试编号；若实现需要偏离，应先更新“设计决策记录”和相应测试。

## 目录

1. [项目目标与边界](#1-项目目标与边界)
2. [权威来源与兼容策略](#2-权威来源与兼容策略)
3. [物理与生物方程](#3-物理与生物方程)
4. [MITgcm 集成架构](#4-mitgcm-集成架构)
5. [状态与内存布局](#5-状态与内存布局)
6. [环境场接口](#6-环境场接口)
7. [时间积分与事件顺序](#7-时间积分与事件顺序)
8. [并行设计](#8-并行设计)
9. [参数文件设计](#9-参数文件设计)
10. [输入、输出与 pickup](#10-输入输出与-pickup)
11. [Linux HPC 构建与运行](#11-linux-hpc-构建与运行)
12. [验证体系](#12-验证体系)
13. [分阶段开发计划](#13-分阶段开发计划)
14. [编码规范](#14-编码规范)
15. [需求—实现—测试追踪](#15-需求实现测试追踪)
16. [设计决策记录](#16-设计决策记录)
17. [开工检查表](#17-开工检查表)
18. [参考资料与当前源码依据](#18-参考资料与当前源码依据)
19. [下一步实施顺序](#19-下一步实施顺序)

---

## 1. 项目目标与边界

### 1.1 总体目标

开发独立的 MITgcm `pkg/bom`，使马尾藻 clump 能够在 MITgcm 在线环境场中完成：

1. 表层欧拉海流、Stokes 漂移和风场共同驱动的平流；
2. BOM/eBOMB 慢流形 Maxey–Riley 惯性修正；
3. clump 间非线性弹簧连接、筏团分裂和重新组合；
4. 温度和营养盐控制的生长、繁殖、死亡及近岸搁浅；
5. 跨 tile、跨 MPI 进程迁移与跨域弹簧相互作用；
6. 轨迹、网格化诊断量和可确定性重启的 pickup 输出；
7. 在 Linux HPC 上达到可扩展、可复现、可诊断的生产运行质量。

`pkg/flt` 是 MITgcm 生命周期、粒子插值、坐标映射和 tile 迁移的参考实现，但不是 BOM 状态容器。BOM 的状态和并行通信必须独立实现，避免把生物量、谱系和弹簧字段塞进 FLT 的九字段记录。

### 1.2 功能模式

运行时至少支持以下四种递进模式：

| 模式 | 速度方程 | 弹簧 | 生物过程 | 用途 |
|---|---|---:|---:|---|
| `LEEW` | 纯海流/风偏移 | 否 | 否 | 最小验证与业务基线 |
| `BOM` | 慢流形惯性速度 | 否 | 否 | 单 clump 物理验证 |
| `EBOM` | 慢流形惯性速度 | 线性 Hooke | 否 | 弹簧守恒验证 |
| `EBOMB` | 慢流形惯性速度 | 非线性 | 可选 | 完整目标模式 |

模式名称写入 pickup 和轨迹元数据，重启时不得静默改变。

### 1.3 第一版明确不做

第一版不包含：

- 马尾藻对海洋动量、温盐或营养盐的反向反馈；
- 三维沉降、再悬浮和波浪破碎下沉；
- 自适应 ODE 积分器；
- GPU 移植；
- cubed-sphere/LLC/`EXCH2` 的生产支持；
- 自动参数反演或卫星同化。

这些不属于第一版验收条件，但数据结构不能阻止后续增加相应能力。

### 1.4 完成定义

“代码能编译”不等于功能完成。每个阶段只有同时满足以下条件才可合并：

- 方程、单位和边界条件有测试；
- 单进程、MPI 和 pickup 重启结果通过该阶段的验收阈值；
- 新参数在 `data.bom` 中有默认值、合法范围和错误检查；
- 新输出有名称、单位、符号和时间语义；
- 没有未解释的全局同步、全粒子 gather 或随 MPI 划分变化的随机结果；
- 文档的需求—例程—测试追踪表已同步更新。

---

## 2. 权威来源与兼容策略

### 2.1 来源优先级

遇到公式或行为冲突时，按以下顺序裁决：

1. 2024 eBOMB 论文及补充材料；
2. 固定提交的 Julia 源码，用于产生对照轨迹；
3. 当前 MITgcm 基线的网格、时间、并行和 I/O 约定；
4. 本手册明确记录的修正。

“论文一致”是默认模式。为了对照旧结果，可提供 `bomEquationMode='JULIA'`，但兼容模式不得成为生产默认值。

### 2.2 固定参考版本

开发仓库中应增加以下不可变清单，后续由 Phase 0 建立：

    verification/bom/reference/REFERENCE.md
    verification/bom/reference/julia_commit.txt
    verification/bom/reference/mitgcm_commit.txt
    verification/bom/reference/input_checksums.sha256
    verification/bom/reference/golden_*.csv

Golden 数据必须记录 Julia 版本、`Project.toml`、`Manifest.toml`、输入场校验和、时间步长和完整参数，不允许以“当前最新版”作为参考。

### 2.3 不得复制的旧 Julia 行为

源码审查已发现下列风险，MITgcm 实现应把它们转化为回归测试，而不是逐字复制：

1. 不能通过“位置是否变化”判断 clump 是否存活；静止但存活的 clump 必须保留。
2. 快速路径必须分别检查 x、y 惯性修正，不能重复检查同一分量。
3. 预计算和运行时必须使用同一个球面几何开关。
4. `maxParticles` 限制的是同时存活数；死亡槽位应由 free-list 复用。
5. 繁殖例程不能依赖未定义的旧 clump 数变量。
6. leeway RHS 每次调用必须完整覆盖两个速度分量。
7. 生物和陆地事件使用固定 BOM 子步长，不能依赖自适应步长越过阈值。
8. 环境数据缺失必须明确报错；不得吞掉下载或初始化失败。
9. 无存活 clump 时质心应输出缺测标志和零计数，不能产生未标注 NaN。
10. MPI 划分变化不能改变出生角度；随机数必须由稳定键生成。

---

## 3. 物理与生物方程

### 3.1 环境速度

海洋携带速度为

$$
\mathbf v=\mathbf v_E+\sigma\mathbf v_S ,
$$

其中：

- $\mathbf v_E$：MITgcm 表层欧拉流速；
- $\mathbf v_S$：波浪导致的 Stokes 漂移；
- $\sigma$：Stokes 漂移不确定性/响应系数。

水—风混合速度为

$$
\mathbf u=(1-\alpha)\mathbf v+\alpha\mathbf v_W ,
$$

其中 $\mathbf v_W$ 是近表面风速，$\alpha$ 是 eBOMB 的风暴露参数。它与传统 leeway 模式中的经验性 1%–3% 风偏移系数不是同一参数。

Stokes 漂移是可选输入。若海流产品已经是含 Stokes 项的拉格朗日速度，`bomUseStokes` 必须为假，防止重复叠加。

### 3.2 慢流形 BOM 速度

第 $i$ 个 clump 满足

$$
\sqrt{\mathsf m}\,\dot{\mathbf x}_i
=\mathbf u|_i+\tau\mathbf u_\tau|_i+\tau\mathbf F_i ,
$$

其中

$$
\begin{aligned}
\mathbf u_\tau={}&R\left(\partial_t\mathbf v+
\nabla_{\mathbf v}\mathbf v\right)
+R\left(f+\frac{1}{3}\omega\right)\mathbf v^\perp\\
&-\partial_t\mathbf u-\nabla_{\mathbf u}\mathbf u
-\left(f+\tau_\odot u_x+\frac{1}{3}R\omega\right)
\mathbf u^\perp .
\end{aligned}
$$

球面几何定义：

$$
\omega=\gamma_\odot^{-1}\partial_xv_y-\partial_yv_x+
\tau_\odot v_x ,
$$

$$
\nabla_{\mathbf w}\mathbf w=
\gamma_\odot^{-1}w_x\partial_x\mathbf w+
w_y\partial_y\mathbf w+
\tau_\odot w_x\mathbf w^\perp .
$$

第一版限制在规则经纬网。实现中速度统一转为 east/north，空间导数用 MITgcm 米制网格量计算；不得直接对经纬度数值求差。`fCori` 直接使用 MITgcm 的 s$^{-1}$ 值。论文中 $\sqrt{\mathsf m}$ 的作用由 east/north 到经纬方向的度量转换实现，不能再额外重复乘球面因子。

### 3.3 Leeway 模式

验证模式定义为

$$
\dot{\mathbf x}_i=\mathbf v_E|_i+
\alpha_{10}\mathbf v_{10}|_i .
$$

如果项目需要比较“含 Stokes 的工程 leeway”，必须使用单独开关和诊断名称，不得悄悄改变上述论文基线。

### 3.4 弹簧力

$$
\mathbf F_i=-\sum_{j\in{\cal N}(i,t)}
k(d_{ij})(d_{ij}-L)\frac{\mathbf x_{ij}}{d_{ij}},
$$

$$
k(d)=\frac{A}{\exp((d-2L)/\Delta)+1}.
$$

其中 $d_{ij}$ 是球面局部 east/north 米制距离，$L$ 为自然长度，$A$ 为刚度幅度，$\Delta$ 为平滑截止尺度。

实现要求：

- 当 $d<d_\epsilon$ 时不得除零；使用确定性方向或跳过零长对并计数告警。
- 邻居表按全局粒子 ID 排序后累加，以获得与 MPI 划分无关的求和顺序。
- 每条无向连接对两端使用同一个 $L$；若使用每边自然长度，应保存为边状态并进入 pickup。
- 论文兼容初值：对每个 clump 求初始 $K$ 近邻平均距离，再取所有 clump 的中位数作为 $L$。
- 生产邻居搜索使用半径 cutoff 与 cell-linked list；全局 K 近邻仅用于小规模对照。

建议令

$$
r_\text{cut}=2L+n_\Delta\Delta,\qquad n_\Delta=8,
$$

使 cutoff 处刚度已足够小。`nDeltaCut` 必须可配置并进入元数据。

### 3.5 生长、繁殖和死亡

每个活 clump 保存无量纲 amount $S$：

$$
S(t+h)=S(t)+[g(T,N)-m]h ,
$$

$$
g(T,N)=\mu_{\max}{\cal T}(T)
\frac{N}{k_N+N}.
$$

令 $T_0=(T_{\min}+T_{\max})/2$，温度因子为

$$
{\cal T}(T)=
\begin{cases}
\exp\left[-\frac12\left(\frac{T-T_0}{T-T_{\min}}\right)^2\right],
&T_{\min}\le T\le T_0,\\
\exp\left[-\frac12\left(\frac{T-T_0}{T-T_{\max}}\right)^2\right],
&T_0<T\le T_{\max},\\
0,&\text{其他}.
\end{cases}
$$

事件规则：

- $S<S_{\min}$：状态改为死亡并释放槽位；
- $S>S_{\max}$：父体和新生体均设为 `bomS0`；
- 新生体位于父体距离 $L$、角度 $\theta\in[0,2\pi)$ 的位置；
- 新生体落在陆地或域外时，最多重试 `bomBirthMaxTry` 次，失败则取消出生并保留父体更新前的 $S$；
- 触陆状态与生物死亡状态必须分开编码。

营养盐必须做 $N\ge0$ 限幅；缺测值触发配置决定的 `STOP` 或关闭生长，不能默认为任意数。

温度恰好等于 $T_{\min}$ 或 $T_{\max}$ 时直接令温度因子为 0，避免按公式字面计算时出现除零；$T=T_0$ 时温度因子为 1。

### 3.6 单位约定

模块内部一律使用 SI：

| 量 | 外部常见单位 | BOM 内部单位 | 转换 |
|---|---|---|---|
| 速度 | km d$^{-1}$ | m s$^{-1}$ | 除以 86.4 |
| 时间 $\tau$ | d | s | 乘 86400 |
| 长度 $L,\Delta$ | km | m | 乘 1000 |
| 刚度 $A$ | d$^{-2}$ | s$^{-2}$ | 除以 $86400^2$ |
| 生长/死亡率 | d$^{-1}$ | s$^{-1}$ | 除以 86400 |
| 温度 | °C | °C | MITgcm `theta` 近表层近似；需记录 |
| 氮浓度 | mmol N m$^{-3}$ | 同左 | 不转换 |
| 科氏参数 | s$^{-1}$ | s$^{-1}$ | 使用 `fCori` |

`BOM_READPARMS` 负责一次性转换并打印输入值和 SI 值。计算内核不得反复出现 `86400` 常数。

---

## 4. MITgcm 集成架构

### 4.1 总体数据流

    uVel/vVel ─┐
    EXF wind ──┼─> BOM_BUILD_FIELDS ─> 时间快照/导数/涡度
    Stokes ────┤                            │
    theta/N ───┘                            v
                                      BOM_INTERP
                                           │
    owner particles ─> ghost/neighbor ─> BOM_RHS ─> RK 子步
           ^                                      │
           └──────── particle migration <────────┘
                                           │
                                  land + biology + birth
                                           │
                         trajectory + diagnostics + pickup

第一版采用在线单向耦合：MITgcm 驱动 BOM，BOM 不修改 MITgcm 状态。

### 4.2 核心挂接点

参考当前 `pkg/flt` 的生命周期，在以下文件加入 `ALLOW_BOM`/`useBOM`：

| MITgcm 文件 | BOM 调用 | 目的 |
|---|---|---|
| `model/inc/PARAMS.h` | 声明 `useBOM` | `data.pkg` 运行开关 |
| `model/src/packages_boot.F` | 默认假、读 `PACKAGES`、打印状态 | 包启动 |
| `model/src/packages_readparms.F` | `BOM_READPARMS` | 参数读取 |
| `model/src/packages_check.F` | `BOM_CHECK` | 编译/运行依赖检查 |
| `model/src/packages_init_fixed.F` | `BOM_INIT_FIXED` | 网格和通信初始化 |
| `model/src/packages_init_variables.F` | `BOM_INIT_VARIA` | 粒子/场快照/pickup |
| `model/src/forward_step.F` | `BOM_MAIN` | 每个海洋步结束后积分 |
| `model/src/packages_write_pickup.F` | `BOM_WRITE_PICKUP` | 确定性重启 |
| `pkg/pkg_depend` | `bom +mdsio +mom_common =diagnostics` | 构建依赖 |

`PACKAGES_CONFIG.h` 由 `genmake2` 根据 `packages.conf` 生成，禁止手工编辑。

当前 `forward_step.F` 在更新 `myTime` 到步末后调用 `FLT_MAIN`。`BOM_MAIN(myTime,myIter,myThid)` 应放在同一层级，定义为把粒子从 `myTime-deltaTClock` 积分到 `myTime`。

### 4.3 包内文件及职责

建议初始文件集：

| 文件 | 单一职责 |
|---|---|
| `BOM_OPTIONS.h` | 编译期能力开关 |
| `BOM_SIZE.h` | 每 tile 粒子、ghost、交换和邻居上限 |
| `BOM.h` | 参数、粒子 SoA、计数器 |
| `BOM_FIELDS.h` | old/new 环境场及导数字段 |
| `BOM_EXCHANGE.h` | 粒子和 ghost 通信缓冲区 |
| `README.md` | 包用户说明和参数表 |
| `bom_readparms.F` | 读 `data.bom`、单位转换 |
| `bom_check.F` | 参数、依赖、内存、时间步检查 |
| `bom_init_fixed.F` | 网格映射、cell-list 几何、诊断注册 |
| `bom_init_varia.F` | 初值或 pickup、初始场快照 |
| `bom_main.F` | 单个海洋步的总调度 |
| `bom_build_fields.F` | 收集并转换环境场 |
| `bom_drift_grid.F` | 涡度、物质导数、$\mathbf u_\tau$ |
| `bom_interp.F` | 空间和时间插值 |
| `bom_mapping.F` | 物理坐标、tile 和局地分数索引映射 |
| `bom_rhs.F` | 四种模式的统一 RHS |
| `bom_rk2.F` / `bom_rk4.F` | 固定步积分器 |
| `bom_neighbors.F` | cell-linked list 和边生成 |
| `bom_ghost_exchange.F` | cutoff halo clump 交换 |
| `bom_particle_exchange.F` | owner 迁移 |
| `bom_springs.F` | 力计算 |
| `bom_land.F` | 海陆/域外处理 |
| `bom_biology.F` | $S$ 更新和事件判定 |
| `bom_birth_death.F` | free-list、ID 和谱系 |
| `bom_diagnostics_init.F` | 网格诊断注册 |
| `bom_diagnostics_fill.F` | 粒子到网格归并 |
| `bom_output.F` | 轨迹分片输出 |
| `bom_read_pickup.F` / `bom_write_pickup.F` | 重启 |

每个文件只实现表中职责。不得形成一个同时读取场、计算弹簧、出生和写文件的巨型例程。

### 4.4 编译期开关

`BOM_OPTIONS.h` 初期只保留会改变依赖或存储布局的开关：

    ALLOW_BOM_STOKES
    ALLOW_BOM_BIOLOGY
    ALLOW_BOM_PTRACER_N
    ALLOW_BOM_EXCH2

方程模式、积分阶数和邻居策略尽量使用运行时参数，减少可执行文件组合。`ALLOW_BOM_EXCH2` 在通过专门测试前默认 `undef`。

---

## 5. 状态与内存布局

### 5.1 粒子所有权

每个活粒子恰有一个 owner tile。owner 保存权威状态，ghost 只用于当前 RHS 的邻居力，不参与出生、死亡、输出或 pickup。

owner 规则：

1. 粒子中心所在湿网格单元决定 tile；
2. 恰在边界时采用全局 tile 编号较小的一侧；
3. 每个完整 BOM 子步后迁移；
4. 若单步跨越多个 tile，迁移循环继续直到抵达最终 owner，超过 `bomMaxHop` 时停止并报错。

### 5.2 Structure of Arrays

为便于向量化，权威粒子状态使用 SoA：

| 字段 | 类型 | 含义 | pickup |
|---|---|---|---:|
| `bomId` | `INTEGER*8` | 全局唯一、永不复用 | 是 |
| `bomParentId` | `INTEGER*8` | 父体 ID；初始体为 0 | 是 |
| `bomRaftId` | `INTEGER*8` | 可选连通分量标签 | 是 |
| `bomStatus` | `INTEGER` | 活/死亡/搁浅/域外 | 是 |
| `bomX,bomY` | `_RL` | 全局物理坐标 | 是 |
| `bomI,bomJ` | `_RL` | owner tile 局部分数索引 | 是 |
| `bomS` | `_RL` | amount | 是 |
| `bomAge` | `_RL` | 存活秒数 | 是 |
| `bomBirthCount` | `INTEGER` | 该父体已出生次数 | 是 |
| `bomUx,bomUy` | `_RL` | 最近诊断速度 | 可重建 |
| `bomFx,bomFy` | `_RL` | 最近弹簧项 | 可重建 |

状态码固定：

| 值 | 名称 | 含义 |
|---:|---|---|
| 0 | `BOM_UNUSED` | free-list 槽位 |
| 1 | `BOM_ALIVE` | 存活 |
| 2 | `BOM_DEAD_BIO` | 生物死亡 |
| 3 | `BOM_BEACHED` | 搁浅 |
| 4 | `BOM_OUTSIDE` | 离开开放边界 |
| 5 | `BOM_INVALID` | 数值异常，运行应停止 |

死亡记录在事件日志输出后即可释放槽位，但全局 ID 不得复用。

### 5.3 固定容量与 free-list

MITgcm 包通常使用编译期静态数组。`BOM_SIZE.h` 至少包含：

    bomMaxPartTile
    bomMaxGhostTile
    bomMaxExchange
    bomMaxNeighbor
    bomMaxEventBuffer

`BOM_CHECK` 在启动时打印每 rank 预计内存。任何容量溢出都必须输出 rank、tile、所需容量和编译容量，然后安全停止；不得截断粒子或邻居。

free-list 操作必须是 O(1)。在 OpenMP 模式下，出生槽位分配放在 master 串行事件阶段，或使用每 tile 明确的线程所有权，禁止多个线程无保护修改栈顶。

### 5.4 环境场快照

每个需要进入 $\partial_t$ 或 RK 时间插值的二维场保存 old/new 两份：

    bomVEast0, bomVNorth0
    bomVEast1, bomVNorth1
    bomUEast0, bomUNorth0
    bomUEast1, bomUNorth1

Stokes、风、温度和营养盐若在子步内插值，也应保存时间端点或直接调用已经时间插值到端点的 EXF 字段。

初始化时在 `startTime` 建立 old。每个海洋步末：

1. 从新 MITgcm 状态建立 new；
2. 在 $[t_n,t_{n+1}]$ 内按 RK stage 时间线性插值；
3. 用 $(new-old)/\Delta t$ 计算时间导数；
4. BOM 积分完成后令 old = new。

pickup 必须保存 old 场及其时间标签，否则重启后的第一个 $\partial_t$ 与连续运行不同。

---

## 6. 环境场接口

### 6.1 字段清单

| BOM 量 | 首选 MITgcm 来源 | 网格/位置 | 单位 | 必需 |
|---|---|---|---|---:|
| $\mathbf v_E$ | `uVel/vVel` 表层 | C-grid U/V | m s$^{-1}$ | 是 |
| $\mathbf v_W$ | EXF `uwind/vwind` | C 点 east/north | m s$^{-1}$ | 按模式 |
| $\mathbf v_S$ | `bomUStokesFile/bomVStokesFile` | C 点 east/north | m s$^{-1}$ | 可选 |
| $T$ | `theta(:,:,1)` | C 点 | °C/势温 | 生物模式 |
| $N$ | PTRACERS 指定索引或外部文件 | C 点 | mmol N m$^{-3}$ | 生物模式 |
| land | `maskC(:,:,1)` | C 点 | 0/1 | 是 |
| $f$ | `fCori` | C 点 | s$^{-1}$ | BOM 模式 |

### 6.2 C-grid 到 east/north

`uVel/vVel` 不能作为 colocated 向量直接做双线性插值。`BOM_BUILD_FIELDS` 应：

1. 复制表层 U/V 到 `kSize=1` 的工作数组；
2. 调用 `ROTATE_UV2EN_RL`，设置 `xy2en=.TRUE.`、`switchGrid=.TRUE.`、`applyMask=.TRUE.`；
3. 对输出 C 点 east/north 场执行 halo exchange；
4. 再计算空间导数和粒子插值。

不能把完整 `Nr` 数组以 `kSize=1` 的假形状传入，因为 tile 维步长不同。

`MOM_CALC_RELVORT3` 可用于验证欧拉 C-grid 涡度，但其输出位于网格角点，且总海洋速度还包含 C 点 Stokes 场。生产 `BOM_DRIFT_GRID` 应实现与目标 colocated 场一致的米制度量差分，并用解析测试验证。

### 6.3 Stokes 漂移

第一版提供三种运行来源：

| `bomStokesSource` | 行为 |
|---|---|
| `NONE` | $\mathbf v_S=0$ |
| `FILES` | 使用 BOM 外部时变二进制场 |
| `COUPLER` | 预留波浪耦合接口，未编译时禁止选择 |

外部场读取遵循 EXF 的两时间片方法或复用通用外场加载器。必须检查：

- 时间覆盖完整；
- east/north 分量和单位明确；
- 缺测值处理一致；
- 周期和时间原点与 MITgcm 一致；
- 输入是否已经包含在 $\mathbf v_E$ 中。

### 6.4 温度和营养盐

`theta(:,:,1)` 是 MITgcm 势温，不总等于原 Julia 数据中的表面温度。使用前应在实验说明中记录此近似；如需原位温度，应新增显式转换而不是改名掩盖。

营养盐来源：

1. `bomNSource='PTRACER'`：读取 `pTracer(:,:,1,bomNTracerIndex)`；
2. `bomNSource='FILE'`：读取外部时变场；
3. `bomNSource='CONST'`：仅用于单元测试。

若编译时没有 PTRACERS 而运行时选择 `PTRACER`，`BOM_CHECK` 必须停止。

### 6.5 粒子空间插值

第一版使用双线性插值，约定：

- 对速度、温度和营养盐均使用同一 stage 位置；
- 海岸 stencil 只对湿点加权并重新归一化；
- 湿权重和小于 `bomWetWeightMin` 时判为触陆；
- 域外不做常数外推；
- 经度周期边界在映射层处理，不在插值例程临时修正。

`pkg/flt/flt_interp_linear.F` 和 `flt_mapping.F` 可复用算法思路，但 BOM 例程要有自己的接口和 mask 语义。

---

## 7. 时间积分与事件顺序

### 7.1 子步数

每个海洋时间步 $\Delta t_o$ 使用

$$
N_s=\max\left(1,\left\lceil\frac{\Delta t_o}
{\Delta t_{\mathrm{bom,target}}}\right\rceil\right),\qquad
\Delta t_b=\frac{\Delta t_o}{N_s}.
$$

必须至少检查：

$$
\Delta t_b\left(\frac{|u|}{\Delta x}+
\frac{|v|}{\Delta y}\right)<C_{\mathrm{adv}},
$$

以及弹簧经验限制

$$
\Delta t_b\,\tau A N_{\mathrm{nbr}}<C_{\mathrm{spring}}.
$$

默认 $C_{\mathrm{adv}}=0.5$，$C_{\mathrm{spring}}=0.5$。实际稳定性由收敛测试确定，不得把这两个经验式当成充分证明。

### 7.2 RK4 stage

默认使用固定步长 RK4，RK2 仅用于对照。每个 stage：

1. 构造 stage 粒子位置；
2. 按 stage 时间插值环境场；
3. 更新/验证 neighbor list；
4. 交换 cutoff 范围 ghost；
5. 按全局 ID 顺序计算弹簧力；
6. 计算 `BOM_RHS`；
7. 检查所有 RHS 和 stage 位置为有限数。

验证版本每个 stage 重建邻居。生产版本可使用带 skin 的 Verlet/cell list，但必须证明 stage 最大位移小于 skin/2，否则立即重建。

### 7.3 完整子步后的顺序

一个 $\Delta t_b$ 完成后严格执行：

1. 提交 RK 新位置；
2. 更新物理坐标和局部分数索引；
3. 迁移 owner 粒子；
4. 检查触陆/域外；
5. 对仍存活粒子更新生物量；
6. 收集死亡事件；
7. 按父体全局 ID 排序处理出生；
8. 为新粒子分配全局 ID 和 owner；
9. 重建受影响的邻居；
10. 累加诊断和事件日志。

事件不能在 RK stage 中改变粒子数组长度。

### 7.4 确定性出生 ID 和随机数

每个进程先统计本子步出生数，通过 MPI exclusive prefix sum 得到本进程 ID 区间；全局 `bomNextId` 增加总出生数。

出生角度使用 counter-based RNG：

    key = (bomSeed, parentId, parentBirthCount, eventTimeIndex)

禁止使用“本 rank 第几个随机数”或依赖遍历顺序的全局 RNG。相同输入、相同数值模式下，1 rank 与多 rank 的出生角度和 ID 必须一致。

---

## 8. 并行设计

### 8.1 两阶段实现

验证实现：

- 每个 RK stage allgather 所有活粒子；
- 仅用于 $N\le$`bomGatherLimit`；
- 作为分布式算法的数值 oracle；
- 超过上限必须停止，不能误用于生产。

生产实现：

- 空间域分解 owner 粒子；
- 基于 $r_\text{cut}$ 的 cell-linked list；
- 与相邻 tile/rank 交换 ghost；
- owner 独立计算自身粒子受力；
- 一条跨 rank 弹簧可在两端各计算一次，避免反向力通信和原子写。

### 8.2 Ghost 内容

ghost 最小字段：

    id, x, y, status, sourceRank, sourceTile

如果 $L$ 或刚度是粒子/边相关量，应增加相应字段。ghost 不携带 $S$、age 或随机数状态，除非物理公式确实需要。

### 8.3 通信不变量

- 每个全局 ID 在 owner 集合中恰好出现一次；
- owner 与 ghost 集合不重叠计数；
- ghost 生命周期不超过一个 stage；
- 发送和接收记录带 schema version；
- 缓冲区溢出是致命错误；
- 空 tile 不进行不必要的大缓冲通信；
- 通信结束后全局 owner 数等于事件预算计算的存活数。

### 8.4 OpenMP

粒子 RHS 循环可按 slot 并行，前提是每个线程只写自己的 owner slot。以下阶段保持串行或显式分区：

- free-list 修改；
- 出生 ID 分配；
- 同一网格格点的诊断归并；
- 轨迹缓冲区压缩；
- MPI 调用（除非确认线程级别）。

先通过 MPI-only，再开放 `nTx*nTy>1` 测试。

### 8.5 可扩展性目标

阶段 5 的初始目标：

- $10^5$ 活 clump；
- 平均 8–16 个有效邻居；
- 256 MPI ranks；
- BOM 增量耗时不超过海洋模式耗时的 20%；
- 每 rank 内存随本地 owner+ghost 线性增长；
- 不存在每步 O($N^2$) 或全粒子 root gather。

性能目标在真实网格和机器上测量，报告平均值、P95 rank 值和负载不均衡。

---

## 9. 参数文件设计

### 9.1 `data.pkg`

    &PACKAGES
      useEXF         = .TRUE.,
      useDiagnostics = .TRUE.,
      useBOM         = .TRUE.,
    &

EXF 和 diagnostics 可按运行模式关闭，但 `BOM_CHECK` 必须验证所选字段来源。

### 9.2 `data.bom` 草案

    &BOM_PARM01
      bomMode            = 'EBOMB',
      bomEquationMode    = 'PAPER2024',
      bomIntegrator      = 'RK4',
      bomDeltaTTarget    = 300.,
      bomOutputFreq      = 3600.,
      bomPickupFreq      = 86400.,
      bomSeed            = 20240801,
    /

    &BOM_PARM02
      bomAlpha           = 3.37D-3,
      bomTauDays         = 1.03D-2,
      bomR               = 8.23D-1,
      bomSigma           = 1.20D0,
      bomSpringADay2     = 15.1D0,
      bomSpringLKm       = 0.D0,
      bomSpringDeltaKm   = 0.2D0,
      bomNeighborK       = 5,
      bomNDeltaCut       = 8.D0,
    /

    &BOM_PARM03
      bomUseBiology      = .TRUE.,
      bomMuMaxDay        = 5.41D-3,
      bomMortDay         = 4.02D-3,
      bomKN              = 1.29D-4,
      bomTMin            = 10.D0,
      bomTMax            = 40.D0,
      bomS0              = 0.D0,
      bomSMin            = -4.82D-3,
      bomSMax            = 1.D-3,
      bomBirthMaxTry     = 16,
      bomMaxParticles    = 100000,
    /

    &BOM_PARM04
      bomWindSource      = 'EXF',
      bomStokesSource    = 'FILES',
      bomNSource         = 'PTRACER',
      bomNTracerIndex    = 1,
      bomUStokesFile     = 'bom_ustokes.bin',
      bomVStokesFile     = 'bom_vstokes.bin',
      bomInitialFile     = 'bom_particles.bin',
    /

参数名最终需满足 Fortran namelist 和 MITgcm 风格限制。上面的默认数值是论文量级基线，不是未经校准即可用于业务预报的保证。
`bomSpringLKm=0` 表示按初始 $K$ 近邻统计自动计算 $L$；正值表示使用用户指定的固定自然长度。

### 9.3 `packages.conf`

验证算例建议：

    gfd
    mom_common
    exf
    diagnostics
    bom

`pkg/pkg_depend` 中令 BOM 强依赖 `mdsio` 和 `mom_common`，推荐 diagnostics；EXF 和 PTRACERS 保持运行模式可选。

---

## 10. 输入、输出与 pickup

### 10.1 初始粒子文件

初始记录至少包含：

| 字段 | 单位/编码 |
|---|---|
| id_hi, id_lo | 64 位 ID 拆成两个可由 `_RL` 精确表示的 32 位字 |
| x, y | 模型物理坐标 |
| S | amount |
| status | 初始必须为 `BOM_ALIVE` |
| parent_hi, parent_lo | 初始体为 0 |
| raft_hi, raft_lo | 可选 |

文件头包含 magic、schema version、记录字段数、粒子总数、坐标类型、字节序和浮点精度。读取后进行全局 ID 唯一性检查。

### 10.2 轨迹输出

每条记录建议包括：

    time, id, parent_id, raft_id, status,
    x, y, lon, lat, S, age,
    vE_east, vE_north, vS_east, vS_north,
    wind_east, wind_north,
    drift_east, drift_north, spring_east, spring_north

轨迹按 rank 分片缓冲写出，避免每个粒子每次输出都打开文件。每个输出时刻提供 manifest，列出分片、记录数、时间和校验和。后处理按 `(time,id)` 排序，不依赖 rank 文件顺序。

### 10.3 网格诊断

诊断名不超过 8 个字符：

| 名称 | 含义 | 单位 |
|---|---|---|
| `BOMCOUNT` | 每个湿网格单元的活 clump 数 | 1 |
| `BOMMASS` | $S$ 或配置的生物量和 | 1 |
| `BOMBIRTH` | 输出窗内出生数 | 1 |
| `BOMDEAD` | 生物死亡数 | 1 |
| `BOMBEACH` | 搁浅数 | 1 |
| `BOMDRFU` | east 漂移速度平均 | m s$^{-1}$ |
| `BOMDRFV` | north 漂移速度平均 | m s$^{-1}$ |
| `BOMSPRF` | 弹簧加速度项模长平均 | m s$^{-2}$ |

`BOMSPRF` 输出 $\mathbf F$ 本身，因此是加速度；不得仅因为它在轨迹方程中被乘以 $\tau$ 就标成速度。

### 10.4 Pickup 完整性

pickup 必须保存：

- 所有 owner 粒子权威字段；
- `bomNextId`、`bomSeed`、出生计数；
- free-list 可重建所需的 slot 状态；
- 当前方程模式和 schema version；
- old 环境场快照及时间；
- 尚未写出的事件/轨迹缓冲，或在写 pickup 前强制 flush；
- 计时累计量和下一输出时刻。

邻居表和 ghost 不写 pickup，重启时重建。

Phase 1 可要求相同 MPI/tile 划分重启。支持变更分解前，必须实现可扩展的重分片读取，不能通过把百万粒子全部 gather 到 rank 0 解决。

---

## 11. Linux HPC 构建与运行

### 11.1 推荐工具链

- GNU：`gfortran`、OpenMPI/MPICH、`make`；
- Intel：`ifort/ifx` 与匹配的 Intel MPI；
- 调试构建：边界检查、浮点异常、未初始化检查；
- 生产构建：保留 IEEE 安全设置，使用经验证的优化级别。

第一阶段以 GNU + MPI 作为可移植基线，再验证目标服务器编译器。

### 11.2 验证算例构建

在 Linux 上：

    cd verification/bom/build
    ../../../tools/genmake2 \
      -mods=../code \
      -of=../../../tools/build_options/linux_amd64_gfortran \
      -mpi
    make depend
    make -j 8

运行：

    cd ../run
    ln -s ../input/* .
    mpirun -np 4 ../build/mitgcmuv

实际服务器提交脚本应记录：Git SHA、`SIZE.h`、`packages.conf`、optfile、编译器版本、MPI 版本、namelist 校验和、任务拓扑和环境场校验和。

### 11.3 调试构建门禁

提交生产运行前至少通过一次：

- 数组越界检查；
- 浮点 invalid/divide-by-zero/overflow trap；
- 未初始化变量检查；
- 1、2、4 ranks；
- `nTx*nTy=1`，随后再测多线程；
- 连续运行与中途 pickup 重启对比。

---

## 12. 验证体系

### 12.1 测试矩阵

| ID | 测试 | 关键判据 |
|---|---|---|
| B01 | 零环境场、无弹簧 | 活粒子位置不变 |
| B02 | 均匀海流 | 位移等于 $\mathbf v\Delta t$ |
| B03 | 风和 Stokes 组合 | 精确复现 $\mathbf u$ |
| B04 | 固体旋转流 | 涡度和惯性项符号正确 |
| B05 | 时变均匀流 | $\partial_t\mathbf v$ 使用 old/new |
| B06 | RK4 收敛 | 时间步减半呈四阶误差收敛 |
| B07 | 两粒子 Hooke 弹簧 | 质心不受内部力改变 |
| B08 | 非线性刚度 | $d\ll2L$、$d=2L$、$d\gg2L$ 正确 |
| B09 | 跨 tile 弹簧 | 与单 tile 结果一致 |
| B10 | 粒子跨多 tile | owner 唯一、位置连续 |
| B11 | 海岸 stencil/搁浅 | 无穿陆、状态码正确 |
| B12 | Brooks 生长 | 对常 T/N 的解析线性 $S(t)$ |
| B13 | 出生/死亡/free-list | 计数预算、ID、槽位复用正确 |
| B14 | RNG | 1/2/4 ranks 出生位置一致 |
| B15 | Pickup | 连续与重启结果逐字段一致 |
| B16 | Julia golden | 规定场景轨迹在容差内 |
| B17 | MPI 分解不变性 | 按 ID 排序后状态一致 |
| B18 | 诊断预算 | 活+死+搁浅+域外收支闭合 |
| B19 | 容量溢出 | 清晰停止，不截断 |
| B20 | 弱/强扩展 | 达到阶段性能目标 |

### 12.2 数值容差

- B01–B05 的解析简单场应接近舍入误差；
- B06 不使用单一绝对误差判据，而检查误差比接近 $2^4$；
- B07 内部力按同一 ID 顺序求和时，质心漂移以域尺度归一化；
- B15 在相同硬件、编译器和 MPI 划分下要求 bitwise 相同；
- B16 应先把 MITgcm 与 Julia 统一为同一固定步长、同一 SI 输入和同一几何模式，再定义位置容差；
- B17 的目标是 bitwise；若外部 MPI reduction 阻止达到，必须记录逐字段误差上界，不能简单写“看起来一致”。

每个容差写进机器可执行的测试脚本，不能只保存在论文笔记中。

### 12.3 预算不变量

每个子步检查：

$$
N_\mathrm{alive}^{n+1}=
N_\mathrm{alive}^{n}
+N_\mathrm{birth}
-N_\mathrm{bio\ dead}
-N_\mathrm{beached}
-N_\mathrm{outside}.
$$

并检查：

- 全局 owner ID 无重复；
- 所有 alive 粒子在湿单元或处于刚完成、尚未判陆的明确阶段；
- `bomNextId` 大于所有已分配 ID；
- 所有数值字段有限；
- 邻居数不超过容量。

调试模式每子步检查，生产模式至少在输出/诊断时检查。

---

## 13. 分阶段开发计划

### Phase 0：参考基线与骨架设计

交付：

- 固定 Julia 和 MITgcm 版本清单；
- 解析场和 Julia golden 数据；
- `pkg/bom` 空包骨架；
- `verification/bom` 最小算例；
- `data.bom` 参数解析和 `BOM_CHECK`。

退出条件：BOM 关闭时 MITgcm 基线结果不变；BOM 开启但无粒子时 1/4 ranks 均可运行。

### Phase 1：BOM-Lite / Leeway

交付：

- 初始粒子读取；
- C-grid 表层流速转换和双线性插值；
- RK2/RK4、子步；
- tile/MPI owner 迁移；
- 轨迹和 pickup；
- B01–B03、B06、B10、B15。

退出条件：均匀流解析测试、跨 tile 和重启测试全部通过。

### Phase 2：慢流形惯性物理

交付：

- old/new 场快照；
- 时间导数、空间导数、涡度和球面度量；
- Stokes、EXF wind；
- `PAPER2024` 与 `JULIA` 方程模式；
- B04、B05、B16。

退出条件：解析惯性测试、RK 收敛和固定 Julia 对照通过。

### Phase 3：非线性弹簧和分布式邻居

交付：

- K 近邻参考实现；
- cutoff cell-linked list；
- ghost exchange；
- Hooke 与 eBOMB 刚度；
- 连通分量/raft 诊断；
- B07–B09、B17、性能基线。

退出条件：跨 rank 内力测试与小规模 gather oracle 一致，无 O($N^2$) 生产路径。

### Phase 4：生物过程和陆地

交付：

- 温度/营养盐接口；
- Brooks 模型；
- 状态机、free-list；
- 确定性出生 ID/RNG；
- 搁浅与事件日志；
- B11–B14、B18–B19。

退出条件：事件预算闭合，MPI 划分不改变出生和死亡结果。

### Phase 5：HPC 加固

交付：

- 通信与负载分析；
- 轨迹分片和后处理；
- OpenMP 安全；
- $10^5$ 粒子扩展测试；
- 长期重启和故障检查；
- 生产运行模板。

退出条件：B20 达标，连续/重启长实验一致，内存和通信无非线性增长。

### Phase 6：一般网格（后续）

交付：

- `EXCH2`/cubed-sphere/LLC 映射；
- 面旋转后的向量和 ghost；
- 一般拓扑迁移；
- 专门角点和面边界测试。

当前 `pkg/flt` 在未定义 `DEVEL_FLT_EXCH2` 时会主动拒绝 EXCH2，这说明不能把 FLT 的 EXCH2 当作已完成能力直接继承。

---

## 14. 编码规范

### 14.1 Fortran/MITgcm 风格

- 源文件使用预处理固定格式 `.F`；
- 例程和公共符号使用 `BOM_`/`bom` 前缀；
- 浮点状态使用 `_RL`，网格 mask 可沿用 `_RS`；
- 数组维度遵循 `1-OLx:sNx+OLx` 和 tile 维；
- tile 循环使用 `myBxLo/myBxHi/myByLo/myByHi`；
- master 工作使用 `_BEGIN_MASTER`/`_END_MASTER`，需要时显式 `_BARRIER`；
- 错误通过 `PRINT_ERROR` 给出上下文后停止；
- 关键例程接入 `debugMode` 和 TIMER；
- 禁止在粒子内循环中分配内存、读文件或执行全局归约。

### 14.2 数值防护

所有除法、开方、指数都要规定输入域：

- $d$ 使用 `MAX(d,bomDistanceEps)`；
- $N$ 使用 `MAX(N,0)`；
- logistic 指数在安全范围限幅，避免 `exp` overflow；
- 纬度接近极点时第一版 `BOM_CHECK` 拒绝运行；
- stage 结束检查 NaN/Inf；
- 粒子单步位移超过 `bomMaxCellCross` 时打印 ID 和局部场。

### 14.3 审查粒度

推荐按以下顺序提交，避免一个 PR 同时改核心挂接、物理和 MPI：

1. 包骨架与 `useBOM`；
2. 参数/状态/初值；
3. 环境场与插值；
4. 单粒子积分；
5. 迁移与 pickup；
6. 惯性项；
7. 弹簧参考实现；
8. 分布式邻居；
9. 生物和事件；
10. 性能优化。

每个 PR 附对应测试 ID、运行命令和输出摘要。

---

## 15. 需求—实现—测试追踪

| 需求 ID | 需求 | 主例程 | 验证 |
|---|---|---|---|
| BOM-R01 | 欧拉流、风、Stokes 组合 | `BOM_BUILD_FIELDS` | B02–B03 |
| BOM-R02 | 慢流形惯性修正 | `BOM_DRIFT_GRID/BOM_RHS` | B04–B06、B16 |
| BOM-R03 | 非线性弹簧 | `BOM_SPRINGS` | B07–B09 |
| BOM-R04 | 规则经纬网坐标与插值 | `BOM_MAPPING/BOM_INTERP` | B02、B04、B10 |
| BOM-R05 | MPI owner/ghost | `BOM_PARTICLE_EXCHANGE/BOM_GHOST_EXCHANGE` | B09–B10、B17 |
| BOM-R06 | 生长、出生、死亡 | `BOM_BIOLOGY/BOM_BIRTH_DEATH` | B12–B14、B18 |
| BOM-R07 | 搁浅 | `BOM_LAND` | B11、B18 |
| BOM-R08 | 确定性重启 | `BOM_READ/WRITE_PICKUP` | B15 |
| BOM-R09 | 可诊断 I/O | `BOM_OUTPUT/BOM_DIAGNOSTICS_*` | B18 |
| BOM-R10 | 容量安全 | `BOM_CHECK` 和所有交换例程 | B19 |
| BOM-R11 | HPC 扩展性 | 邻居、通信、I/O | B20 |
| BOM-R12 | BOM 关闭零影响 | 核心挂接点 | Phase 0 基线 |

新增需求必须先加入本表并指定验证证据。

---

## 16. 设计决策记录

### D001：独立 `pkg/bom`，不直接扩展 `pkg/flt`

原因：BOM 有动态出生/死亡、谱系、弹簧邻居、ghost 和更多 pickup 状态；FLT 的固定九字段交换记录不足。

### D002：第一版在线单向耦合

原因：可先验证粒子动力学且不改变海洋守恒；未来双向反馈需独立科学论证。

### D003：固定步 RK4 + 子步

原因：MITgcm 时间循环、MPI 事件和确定性重启比复刻 Julia 自适应积分更重要；RK4 也与论文伪代码相容。

### D004：内部 SI，环境向量统一 east/north

原因：避免 km/day、m/s、经纬度导数和模型网格方向混用。

### D005：生产邻居使用半径 cutoff

原因：全局 K 近邻在 HPC 上扩展性差。K 近邻保留为初始化 $L$ 和小规模 oracle。

### D006：counter-based RNG

原因：出生位置不能依赖 rank 数和线程调度。

### D007：第一版规则经纬网

原因：当前 FLT 的 EXCH2 仍标记为开发能力；先建立可验证的物理和并行基线。

---

## 17. 开工检查表

第一次实际改码前：

- [ ] 为开发建立 `MITGCM-BOM/phase-NN-topic` 分支或明确的项目分支；
- [ ] 确认工作树中现有修改的归属，避免行尾变化污染补丁；
- [ ] 冻结 Julia golden 输入和版本；
- [ ] 建立 `verification/bom`；
- [ ] 决定目标服务器编译器、MPI 和作业系统；
- [ ] 确认首个算例网格、时间步和粒子规模；
- [ ] 确认风、Stokes 和营养盐的实际数据来源；
- [ ] 估算 `BOM_SIZE.h` 内存；
- [ ] 将 B01–B03 设为首个自动验收门禁。

每次生产实验前：

- [ ] `BOM_CHECK` 无警告；
- [ ] 记录源码、构建和输入校验和；
- [ ] Stokes 未重复计入；
- [ ] 粒子容量和 ghost 容量有余量；
- [ ] pickup 频率满足队列时限；
- [ ] 小规模同配置重启测试已通过；
- [ ] 输出磁盘容量已估算；
- [ ] 诊断预算 B18 已开启。

---

## 18. 参考资料与当前源码依据

理论与参考实现：

- Bonner, G., Beron-Vera, F. J., and Olascoaga, M. J. (2024), “Charting the course of Sargassum: Incorporating nonlinear elastic interactions and life cycles in the Maxey–Riley model”: <https://arxiv.org/html/2410.01468v1>
- Julia 工具包：<https://github.com/70Gage70/SargassumBOMB.jl>
- 后续项目文档：<https://70gage70.github.io/Sargassum.jl/dev/simulation-api>

本 MITgcm 基线中的直接参考：

- `pkg/flt/flt_main.F`：粒子包主循环；
- `pkg/flt/flt_interp_linear.F`：粒子位置插值；
- `pkg/flt/flt_mapping.F`：物理坐标与 tile 索引映射；
- `pkg/flt/flt_exchg.F`：规则拓扑粒子迁移；
- `pkg/flt/flt_write_pickup.F`：粒子 pickup 写出；
- `model/src/rotate_uv2en.F`：C-grid 到中心 east/north；
- `pkg/mom_common/mom_calc_relvort3.F`：MITgcm 网格涡度参考；
- `pkg/exf/EXF_FIELDS.h`：10 m 风 `uwind/vwind`；
- `model/inc/GRID.h`：度量、角度、mask 和 `fCori`；
- `model/src/forward_step.F`：步末 BOM 调用位置；
- `pkg/mypackage`：标准包参数、初始化、诊断和 pickup 风格。

---

## 19. 下一步实施顺序

按本手册开始实际开发时，第一批改动应严格限于：

1. 创建 `pkg/bom` 的 options、size、状态头文件和空生命周期例程；
2. 在 MITgcm 八个核心挂接点加入 `useBOM`；
3. 创建 `verification/bom` 的零流/均匀流小网格；
4. 实现 `data.bom` 读取、单位转换和参数检查；
5. 先通过“BOM 关闭零影响”和“BOM 开启零粒子”门禁。

通过 Phase 0 后再加入粒子运动。不要在第一个补丁中同时实现 Stokes、惯性、弹簧、生物和 MPI ghost。
