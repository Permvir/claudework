English version: [README.md](README.md)

# claudeWork

这个仓库的目标是为了通过AI实现某些任务的仓库, 一个任务可以创建一个文件夹这样方便团队共享和利用AI来实现这些功能

## 工具列表

### gitlab_profiles — GitLab 多账户切换

在不同 GitLab 实例上方便地切换多个账户，仅影响当前 shell session。通过 `gitlab-use` 命令管理 profile：`gitlab-use <name>` 切换账户、`gitlab-use add` 交互式添加、`gitlab-use remove <name>` 删除、`gitlab-use info` 查看详情。切换时自动验证 Token 有效性。同时覆盖 SDD 工作流和 git push 认证（通过 `GIT_CONFIG_COUNT` 注入 credential helper 覆盖 Keychain）。关闭终端自动失效。

详见 [`gitlab_profiles/features.md`](gitlab_profiles/features.md)

### sdd_workflow — SDD 工作流

对于为什么采用**Specification-Driven Development (SDD)** 可以查看这个[链接](https://github.com/github/spec-kit/blob/main/spec-driven.md) , **sdd_workflow**是基于 **Claude**和**GitLab issue** 实现 规范驱动开发，支持需求解析、代码开发、MR 提交和自动 review。通过 Skill 机制集成到 Claude Code，提供从需求到代码的全流程自动化工作流。支持多团队共用，各自通过 `~/.claude/sdd-config.sh` 配置 GitLab 地址和 Token。新增模块化 skill/actions、json-helper.py、完整测试套件（`tests/run_tests.sh`）。

详见 [`sdd_workflow/features.md`](sdd_workflow/features.md)
