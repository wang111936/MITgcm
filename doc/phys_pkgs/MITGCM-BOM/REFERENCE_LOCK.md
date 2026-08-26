# MITGCM-BOM 参考版本锁

状态：`LOCKED`（P2.4 BOM 专用解析输入、固定步长 golden、完整来源预检与 B16 比较已通过）

日期：2026-08-27

## 1. MITgcm

| 项目 | 值 |
|---|---|
| 上游 | `https://github.com/MITgcm/MITgcm.git` |
| 固定提交 | `dfc30dafb16561462ef1d4f9518f5d78753ec750` |
| 开发仓库 | `https://github.com/wang111936/MITgcm.git` |

## 2. Julia 参考源码

| 项目 | 值 |
|---|---|
| 仓库 | `https://github.com/70Gage70/SargassumBOMB.jl.git` |
| 固定提交 | `156557359185e4413ce82829f3ed26a4eb8c6283` |
| 包版本 | `0.7.14` |
| Julia 兼容约束 | `1.10` |
| 实际解析版本 | `1.10.12` |
| 独立 checkout | `/home/wyl/projects/mitgcm-bom-reference/SargassumBOMB.jl` |

源码固定提交中的根级 `Project.toml` SHA-256：

```text
12cfb1288a21b19216662a719d430bf41b5587dfd8b00e973f8b3c9c25f1f99d
```

## 3. 自定义注册表

参考项目依赖 `SargassumFromAFAI` 和 `SargassumColors`，它们不在 General registry 中。按照参考项目文档，依赖以下注册表：

| 项目 | 值 |
|---|---|
| 仓库 | `https://github.com/70Gage70/SargassumRegistry.git` |
| 固定提交 | `02961aced4cfa2b3430ebd4b44cdb7a3056e7175` |
| 独立 checkout | `/home/wyl/projects/mitgcm-bom-reference/SargassumRegistry` |

## 4. 重建的 Julia 环境

固定的 SargassumBOMB 提交没有根级 `Manifest.toml`。Phase 0 使用 Julia 1.10.12、General registry 和上述固定 SargassumRegistry 提交重新解析依赖，并保存：

```text
verification/bom/reference/julia_env/Project.toml
verification/bom/reference/julia_env/Manifest.toml
```

Manifest SHA-256：

```text
86aeeb80ac54752316307a7eed2329c5d06dad2d680e52ef3b98e3c514b5e695
```

重建命令的等价形式：

```bash
env JULIA_DEPOT_PATH=/home/wyl/opt/mitgcm-bom/julia-depot \
  /home/wyl/opt/mitgcm-bom/juliaup/bin/julia \
  --startup-file=no --project=. \
  -e 'using Pkg; Pkg.Registry.add("General"); Pkg.resolve()'
```

## 5. 可复现性限制

这份 Manifest 是在 2026-08-23 重建的依赖集合，不是参考代码作者原始运行时的历史 Manifest。因此：

1. 源码行为以固定提交为准；
2. 依赖版本以本文件保存的 Manifest 为准；
3. 论文模式不能仅凭 Julia 输出定义；
4. Phase 2 已先比较全部 27 个 RHS 分量和解析场，再接受固定步长 RK2/RK4 轨迹为 golden；
5. 如果重建环境无法通过参考项目测试，不能静默升级包，必须建立新的设计决定记录。

## 6. 已执行验证

### 环境实例化和加载

- `Pkg.instantiate(allow_autoprecomp=false)`：通过；
- `using SargassumBOMB`：通过；
- Julia：`1.10.12`；
- 首次加载会尝试构建默认环境插值场；外部场数据不完整时只输出警告，但包仍加载成功。

### 上游测试状态

固定提交的 `test/runtests.jl` 调用：

```julia
SargassumBOMB.Examples.generate_rp_example()
```

但该提交的 `Examples` 模块没有定义 `generate_rp_example`。实际 `Pkg.test()` 结果为：

```text
0 passed, 0 failed, 1 errored
UndefVarError: generate_rp_example not defined
```

这是固定参考提交的测试/接口不一致，不是依赖解析失败。MITGCM-BOM 不修改参考 checkout 来制造通过，而是在自身验证目录建立解析输入、RHS 分量测试和 golden 轨迹。详细记录见 `verification/bom/reference/UPSTREAM_TEST_STATUS.md`。

### P0.5 专用 smoke

- 使用锁定 Manifest 和专用 depot 离线 `Pkg.instantiate`：通过；
- Julia 1.10.12、SargassumBOMB 0.7.14：匹配；
- 坐标往返、时间往返和纯工具函数：8/8 断言通过；
- 不调用陈旧 `generate_rp_example`，不依赖默认环境场，也不下载数据；
- 详细记录见 `verification/bom/phase00-final-gate/TEST_RESULTS.md`。

### P2.4 B16 专用 golden 与比较

- 解析输入 schema：`MITGCM-BOM-B16-v1`，3 个粒子、3 套互异仿射场、
  900 s 固定步长、86400 s 积分区间；
- `JULIA` 模式 RHS：原生坐标率和全部 27 个诊断分量通过冻结容差；
- 固定步长 RK2/RK4：每个粒子 97 个时刻的位置和累计路径通过物理容差；
- N07：物理源码、Project、Manifest、输入、golden、源码提交和 Julia
  版本 7 种变异均在生成/比较前失败；
- 精确功能提交：`4b2d09d40b96cd4408a64e1ee0d4716b7a6255ad`；
- B16 证据：`p24-b16/p24-closure-4b2d09d40-b16-attempt01`，12/12 PASS；
- P2.4 聚合证据：`p24-closure/p24-closure-4b2d09d40-attempt01`，
  358/358 PASS。

固定文件 SHA-256：

```text
505a1f1d39c3223e1697a0d626623ac16e02369d11e726dd6215b3f5e2f6f012  golden_rhs_julia_v1.csv
af62593cca8f2bdd2184cb5c153f4a2cbab154b4e0e3b1ad4e3a6a07be5f5790  golden_traj_julia_rk2_v1.csv
30082f0d47bd1ae406935bb5eab4003a36d83869b52eeaf82f138bc5ae0cde0a  golden_traj_julia_rk4_v1.csv
74c8036bcaf183fb13692de0d1063cfd8d13c5a4615b8206a64feed13755cb1a  context_tsit5_julia_v1.csv
```

最后一个文件由实际 `OrdinaryDiffEqTsit5` 在
`abstol=reltol=1e-12` 下生成，两次结果逐字节一致；其每行明确记录
`gating=false`，仅作自适应求解上下文，不裁决 MITgcm 固定 RK2/RK4。

## 7. 锁定结论与变更规则

- BOM 专用解析输入、三份固定步长 golden 和独立 Tsit5 上下文均已建立；
- 输入、生成器、预检、golden 与上下文分别由 checksum 清单保护；
- 本参考锁正式从 `PROVISIONAL` 升级为 `LOCKED`；
- 后续任何源码、Julia、Project/Manifest、输入或 golden 变化都必须建立
  新版本与设计决定，禁止静默更新。

## 8. Phase 1 退出结论

Phase 1 不把固定 Julia 提交的自适应 Tsit5 整轨迹当作 MITgcm 固定步
RK2/RK4 的逐步 oracle。最终集成门禁在固定提交
`156557359185e4413ce82829f3ed26a4eb8c6283` 上验证了 `water+alpha*wind`
RHS 代数、`1 m/s = 86.4 km/day` 单位换算，并用独立 Julia 仿射场
fixture 验证显式中点 RK2 和经典 RK4 的阶数。该证据足以裁决 Phase 1
实际实现的 Leeway 范围。

完整 trajectory golden、论文 `PAPER2024` 与旧 `JULIA` 方程模式差异、
old/new 时变场和 Stokes 输入当时被正确留给 Phase 2。P2.4 已完成这些
范围中的 B04/B05/B16 固定参考与比较，因此 Phase 1 退出时保留的
`PROVISIONAL` 限制现已解除；P2.5 仍负责输出、pickup、MPI 与 FLT 的
最终系统集成，而不重新定义本参考锁。
