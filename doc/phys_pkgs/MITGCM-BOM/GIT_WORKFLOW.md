# MITGCM-BOM Git 与 GitHub 记录规范

## 1. 仓库和作者

| 项目 | 值 |
|---|---|
| GitHub 开发仓库 | `https://github.com/wang111936/MITgcm.git` |
| 官方上游 | `https://github.com/MITgcm/MITgcm.git` |
| 作者名 | `WangYuLin` |
| 作者邮箱 | `wang111936@outlook.com` |

上述作者信息使用仓库级配置，不修改系统中其他项目的 Git 身份。

## 2. 分支层级

```text
master
└── MITGCM-BOM/development
    ├── MITGCM-BOM/phase-00-reference-lock
    ├── MITGCM-BOM/phase-00-skeleton
    ├── MITGCM-BOM/phase-01-bom-lite
    ├── MITGCM-BOM/phase-02-inertial
    ├── MITGCM-BOM/phase-03-springs
    ├── MITGCM-BOM/phase-04-biology
    ├── MITGCM-BOM/phase-05-hpc
    └── MITGCM-BOM/phase-06-general-grid
```

- `master` 跟踪项目选择的稳定 MITgcm 基线；
- `MITGCM-BOM/development` 只接受通过阶段门禁的提交；
- 每个阶段在自己的 `MITGCM-BOM/phase-NN-topic` 分支开发；
- 临时科学试验使用 `MITGCM-BOM/spike-topic`，不得直接作为生产实现合并。

## 3. 提交规范

提交消息使用：

```text
MITGCM-BOM(<phase>/<scope>): <imperative summary>
```

示例：

```text
MITGCM-BOM(P0/docs): lock reference sources and Julia environment
MITGCM-BOM(P0/pkg): add empty package lifecycle
MITGCM-BOM(P1/interp): add surface velocity interpolation
MITGCM-BOM(P3/mpi): exchange spring ghost particles
```

每个提交必须满足：

- 只完成一个可描述的目的；
- 不混入行尾或无关格式变化；
- 在提交正文记录对应测试 ID 和运行命令；
- 影响物理公式时链接设计决定；
- 影响 pickup 或 MPI 时附连续/重启或分解一致性结果。

## 4. GitHub 阶段记录

当前 `wang111936/MITgcm` 仓库关闭了 Issues。启用 Issues 之前，以阶段分支、提交历史和 `PROJECT_STATUS.md` 为权威记录；启用后再按本节补建 Issue，不影响源码阶段开发。

每个 Phase 建立一个 GitHub issue，标题采用：

```text
[MITGCM-BOM][Phase N] 阶段名称
```

Issue 正文至少包含：

- 阶段范围和明确不做的内容；
- 工作包 checklist；
- 测试 ID 与退出条件；
- 风险和设计决定链接；
- 阶段分支和提交链接；
- 最终测试摘要。

阶段开发通过 pull request 合并到 `MITGCM-BOM/development`。PR 未通过门禁时保持 draft，不以“能够编译”替代验收。

## 5. 标签与版本

建议的本地/远程标签：

| 标签 | 含义 |
|---|---|
| `MITGCM-BOM-v0.1` | 空包骨架和零影响门禁 |
| `MITGCM-BOM-v0.2` | BOM-Lite |
| `MITGCM-BOM-v0.3` | 慢流形惯性物理 |
| `MITGCM-BOM-v0.4` | 分布式弹簧 |
| `MITGCM-BOM-v0.5` | 生物和陆地事件 |
| `MITGCM-BOM-v1.0` | 规则经纬网 HPC 生产版 |

标签只在相应阶段退出条件全部通过后创建。
