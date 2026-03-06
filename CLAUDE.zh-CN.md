English version: [CLAUDE.md](CLAUDE.md)

# CLAUDE.md

## 项目简介

claudework 是团队协作仓库，用于通过 AI（主要是 Claude）驱动开发实用工具和解决临时任务。每个工具/任务独立一个文件夹，方便团队成员共享和复用。

## 目录结构

```
claudework/
├── CLAUDE.md                  # 项目规范（本文件）
├── README.md                  # 项目说明 & 工具列表
├── gitlab_profiles/              # GitLab 多账户切换
│   ├── features.md            # 功能文档
│   ├── install.sh             # 一键安装脚本
│   ├── lib/                   # 核心函数库
│   └── templates/             # Profile 模板
└── sdd_workflow/                # SDD 工作流 Skill
    ├── features.md            # 功能文档
    ├── CHANGELOG.md           # 变更日志
    ├── install.sh             # 一键安装脚本
    ├── skill/                 # Skill 主文件（模块化 actions）
    ├── scripts/               # Shell 脚本（API、解析器、配置）
    ├── references/            # 参考文档
    ├── templates/             # 模板文件
    ├── examples/              # 示例
    └── tests/                 # 测试套件
```

## 开发规范

- **一个工具一个文件夹**：每个工具或任务在仓库根目录下创建独立文件夹
- **语言**：以 Shell 脚本为主，辅以 Python；根据场景选择最合适的语言
- **文档**：每个工具目录内必须包含 `.md` 文档，说明用途、安装方式和配置方法
- **安装脚本**：如工具需要安装步骤，应提供 `install.sh` 一键安装脚本
- **README 更新规则**：新建工具、修改工具功能逻辑或重命名目录时，**必须**同步更新根目录 `README.md` 的对应条目说明

## 现有工具

| 工具 | 目录 | 简述 |
|------|------|------|
| GitLab 多账户切换 | `gitlab_profiles/` | 通过 `gitlab-use` 命令切换 GitLab 账户，支持交互式添加/删除/查看 profile，Token 自动验证，仅影响当前 session |
| SDD 工作流 | `sdd_workflow/` | 基于 GitLab issue 规范驱动开发，支持需求解析、代码开发、MR 提交和自动 review（Skill 驱动） |
