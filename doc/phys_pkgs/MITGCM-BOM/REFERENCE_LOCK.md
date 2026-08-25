# MITGCM-BOM 参考版本锁

状态：`PROVISIONAL`（源码、依赖、包加载和纯函数 smoke 已验证，BOM 专用 Julia golden 测试尚未建立）

日期：2026-08-23

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
4. Phase 2 必须先比较 RHS 分量和解析场，再将整条 Julia 轨迹升级为 golden；
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

## 7. 尚待完成

- 建立 BOM 专用解析输入；
- 生成 `input_checksums.sha256`；
- 生成第一组 `golden_*.csv`；
- 完成后将状态从 `PROVISIONAL` 改为 `LOCKED`。

## 8. Phase 1 退出结论

Phase 1 不把固定 Julia 提交的自适应 Tsit5 整轨迹当作 MITgcm 固定步
RK2/RK4 的逐步 oracle。最终集成门禁在固定提交
`156557359185e4413ce82829f3ed26a4eb8c6283` 上验证了 `water+alpha*wind`
RHS 代数、`1 m/s = 86.4 km/day` 单位换算，并用独立 Julia 仿射场
fixture 验证显式中点 RK2 和经典 RK4 的阶数。该证据足以裁决 Phase 1
实际实现的 Leeway 范围。

完整 trajectory golden、论文 `PAPER2024` 与旧 `JULIA` 方程模式差异、
old/new 时变场和 Stokes 输入属于 Phase 2。因此本参考锁对 trajectory
golden 继续保持 `PROVISIONAL`，但该限制已明确且不阻塞 Phase 1 退出。
