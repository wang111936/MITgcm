# MITgcm-BOM 开发环境就绪报告

日期：2026-08-23

## 1. 结论

本机已具备 MITgcm-BOM 的独立本地开发与验证能力。Ubuntu 22.04 已设置为默认 WSL2 发行版；源码、构建、运行、Julia 和 VS Code workspace 分处独立路径；当前 MITgcm 提交已通过串行和双进程 MPI 的 `verification/exp2` 编译与运行基线。

当前源码基线提交：`dfc30dafb16561462ef1d4f9518f5d78753ec750`

开发分支：`MITGCM-BOM/development`

## 2. 独立目录布局

| 用途 | 路径 |
|---|---|
| WSL 原生源码 | `/home/wyl/projects/mitgcm-bom` |
| 外置 VS Code workspace | `/home/wyl/projects/mitgcm-bom.code-workspace` |
| 构建根目录 | `/home/wyl/build/mitgcm-bom` |
| 运行根目录 | `/home/wyl/runs/mitgcm-bom` |
| 环境与自检脚本 | `/home/wyl/.config/mitgcm-bom` |
| 专用 Juliaup/Julia | `/home/wyl/opt/mitgcm-bom/juliaup` |

这些路径不依赖 Windows 挂载盘进行编译或运行。Windows 工作区仅作为初次源码快照来源。

## 3. 已确认的工具链

| 组件 | 版本/状态 |
|---|---|
| Ubuntu | 22.04.5 LTS / WSL2 |
| GNU Fortran | 11.4.0 |
| GNU Make | 4.3 |
| OpenMPI | 4.1.2 |
| NetCDF-C | 4.8.1 |
| NetCDF-Fortran | 4.5.4 |
| HDF5 | 1.10.7 |
| Python | 3.10.12 |
| fortls | 3.2.2 |
| Julia | 1.10.12（专用 Juliaup 通道 `1.10`） |
| VS Code | 1.134.0 |
| Remote-WSL | 0.104.3 |
| Shell stack | `unlimited` |

环境自检同时验证了 `mpirun -np 2` 可以正常启动。

## 4. MITgcm 基线验证

### 串行

- 构建目录：`/home/wyl/build/mitgcm-bom/exp2-serial`
- 运行目录：`/home/wyl/runs/mitgcm-bom/exp2-serial`
- 正常结束标志：`STOP NORMAL END`
- 主程序结束标志：`PROGRAM MAIN: Execution ended Normally`
- 模型结果文件数：368（不含后来生成的校验清单）

### MPI

- 构建目录：`/home/wyl/build/mitgcm-bom/exp2-mpi`
- 独立 MPI 配置副本：`/home/wyl/build/mitgcm-bom/exp2-mpi-mods`
- 运行目录：`/home/wyl/runs/mitgcm-bom/exp2-mpi`
- 进程布局：`nPx=2, nPy=1`
- 两个 MPI 进程均输出 `STOP NORMAL END`
- 可执行文件已链接 `libmpi_mpifh.so.40` 与 `libmpi.so.40`
- 模型结果文件数：371（不含后来生成的校验清单）

串行与 MPI 的 8 个 `pickup.ckptA`/`pickup_cd.ckptA` 数据文件 SHA-256 完全一致。清单位于各自运行目录的 `checkpoint.sha256`。

## 5. 日常入口

从 Windows 打开远程 workspace：

```powershell
code --remote wsl+Ubuntu-22.04 /home/wyl/projects/mitgcm-bom.code-workspace
```

进入 WSL 后加载开发环境并自检：

```bash
source /home/wyl/.config/mitgcm-bom/env.sh
/home/wyl/.config/mitgcm-bom/check-env.sh
```

调用专用 Julia：

```bash
/home/wyl/opt/mitgcm-bom/juliaup/bin/julia --version
```

## 6. 后续开发约束

1. 所有功能分支从 `/home/wyl/projects/mitgcm-bom` 创建，使用 `MITGCM-BOM/phase-NN-topic` 命名。
2. 所有 `genmake2` 输出和对象文件写入 `/home/wyl/build/mitgcm-bom`，不在源码树内编译。
3. 所有算例输出写入 `/home/wyl/runs/mitgcm-bom`，大规模结果以后迁移到服务器 scratch。
4. Julia 只作为 BOM 参考实现和 golden 轨迹生成器；MITgcm 在线模块保持 Fortran/MPI 原生实现。
5. 高性能服务器部署时需另行生成站点专用 optfile，并验证编译器、MPI、NetCDF/HDF5、调度器和并行文件系统。
6. 当前缺少本地 Slurm 命令属于预期状态；`sbatch` 只在目标服务器上验证。Ninja 与 Fortran 自动格式化器不属于 MITgcm `genmake2` 基线依赖，暂不引入。
