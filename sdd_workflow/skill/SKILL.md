---
name: sdd
description: SDD (Spec-Driven Development) 工作流 — 从 GitLab issue 驱动开发、提交 MR、自动 review
disable-model-invocation: true
---

# SDD — Spec-Driven Development 工作流

> **`<skill_dir>`** = 本 SKILL.md 所在目录（安装后为 `~/.claude/skills/sdd`）。下文所有 `<skill_dir>` 均指此路径。

你是 SDD 工作流助手。你帮助开发者基于 GitLab issue 规范进行开发：阅读需求、编写代码、review 变更并辅助提交 MR。

## 命令格式规范

> **关键规则**：调用 `gitlab-api.sh` 传递多行文本参数时，必须使用 heredoc 方式（如 `"$(cat <<'EOF'...EOF)"`），**不要**使用变量赋值方式（如 `NEW_DESC='...' bash script.sh ... "$NEW_DESC"`），因为变量赋值前缀会导致命令无法匹配已配置的 allow permissions。

## 配置

脚本和模板位于本 Skill 目录下：
- `scripts/` — Shell 脚本（GitLab API、解析器、配置）
- `templates/` — MR 描述、开发记录等模板
- `references/` — API 速查和工作流指南
- `examples/` — 示例 issue
- `actions/` — 各 action 的详细执行步骤

用户配置文件：`~/.claude/sdd-config.sh`

## 项目自动识别

从当前工作目录的 git remote 自动解析 GitLab 项目路径：

```bash
git remote get-url origin
# 例如：git@gitlab.example.com:mygroup/myproject.git → mygroup/myproject
# 或：http://gitlab.example.com/mygroup/myproject.git → mygroup/myproject
```

## Git 分支管理规范

> 分支模型详细图示参见 `<skill_dir>/references/workflow-guide.md`

### 分支类型

| 类型 | 基线分支 | MR 目标 | 命名规范 | 用途 |
|------|----------|---------|----------|------|
| **dev**（默认） | `dev` | `dev` | `{基线分支}-{developer}-{issue_iid}` | 常规迭代开发 |
| **hotfix** | `master` | `dev`（同时需合 master） | `hotfix-{developer}-{issue_iid}` | 线上紧急 bug 修复或紧急功能 |
| **feature** | `master` | `dev`（同时需合 master） | `feature-{developer}-{issue_iid}` | 紧急上线且周期短的新功能 |

> **dev 类型命名规则**：分支前缀动态跟随实际基线分支名。有 dev 分支时为 `dev-alice-8`，无 dev 分支自动回退 master 时为 `master-alice-8`。hotfix/feature 始终使用固定前缀，不受此规则影响。

> **无 dev 分支的项目**：自动检测远程分支，若无 `dev` 分支则默认基线回退到 `master`。此时 dev 类型的基线和 MR 目标均为 `master`，hotfix/feature 的 MR 目标仅合到 `master`。适用于只有 master 分支的工具类项目，无需手动配置。

> **核心规则**：master 任何时候不能直接修改代码，只通过 MR 合入。hotfix/feature 完成后同时合到 dev 和 master（无 dev 分支时仅合 master）。

## 用法

```
/sdd <action> <url> [options]
/sdd <action> [options]              — 省略 URL，从会话上下文自动获取
```

## Actions

| Action | 说明 |
|--------|------|
| `create <project_url> <description>` | 根据描述自动生成结构化 issue 并创建到 GitLab |
| `read` | 获取并解析 issue，展示结构化摘要 |
| `refine` | 读取 issue 中的问题和 TODO 标记，讨论后更新 issue 描述 |
| `review` | 审查 issue spec 质量（传 issue URL）或审查 MR 代码变更（传 MR URL） |
| `dev [--type=dev\|hotfix\|feature]` | 创建分支、开发代码、编写测试 |
| `submit [--type=dev\|hotfix\|feature]` | 推送代码、review 变更、自动创建 MR 并设置 reviewer |
| `done` | MR 合入后关闭 issue，自动更新标签为 `workflow::done` |
| `update` | 添加 Issue 评论（开发进度、关键决策等） |
| `link [--issue=N] <related_url> [desc]` | 向指定 issue 的「关联 Issue」栏目追加一条关联 URL |
| `template` | 输出 SDD issue 规范模板 |
| `status` | 展示当前 SDD 工作状态概览（分支、关联 issue、工作流阶段） |
| `reopen` | 重新打开已关闭的 issue，标签回退为 `workflow::start` |
| `assign [--clear] <username ...>` | 将 issue 指派给项目成员，`--clear` 清空指派人 |
| `list [project_url]` | 列出项目中带 `workflow::` 标签的 issue，按阶段分组展示 |

## 执行流程

收到 `/sdd <action>` 命令后：
1. 根据上方 Actions 表确定目标 action
2. **读取** `<skill_dir>/actions/<action>.md` 获取该 action 的详细执行步骤
3. 按步骤执行

## URL 解析优先级

action 已确定操作类型，URL 类型判断仅用于 `review` action 区分 issue review 和 MR review：

### MR URL 识别

当 URL 匹配 `/-/merge_requests/\d+` 模式时，识别为 MR URL。仅 `review` action 支持 MR URL，其他 action 均操作 issue。

### Issue URL 解析优先级

当 URL 不是 MR URL 时，按以下优先级确定目标 issue：

1. **显式完整 URL** — 用户在命令中提供了完整 issue URL（如 `/sdd read http://gitlab.example.com/mygroup/myproject/-/issues/8`）
2. **Issue 编号** — 用户只给了数字（如 `/sdd read 8`），从 git remote 自动拼接完整 URL
3. **会话上下文** — 用户省略了 URL 和编号（如 `/sdd read`），从当前会话的对话历史中获取之前已加载的 issue 信息（project_id、issue_iid 等）

**会话上下文规则**：
- 当前会话中必须已执行过带 issue URL 的命令（如 `read`、`create`、`dev` 等），上下文中才有可用的 issue 信息
- 如果会话中未找到 issue 上下文，提示用户提供 issue URL
- 如果会话中存在多个 issue 的操作记录，使用对话历史中最后一次执行的 SDD 命令所关联的 issue

## 错误处理

API 调用或脚本执行失败时，根据 HTTP 状态码给出具体指引：

| 状态码 | 含义 | 处理方式 |
|--------|------|----------|
| 401 | Token 无效或过期 | 提示用户检查 `~/.claude/sdd-config.sh` 中的 GITLAB_TOKEN，确认 token 未过期且具有 `api` scope |
| 403 | 权限不足 | 提示用户确认对目标项目有相应权限（如 Developer 角色），检查 token scope |
| 404 | 资源不存在 | 提示检查 URL 是否正确（项目路径、issue/MR 编号），确认资源未被删除 |
| 409 | 资源冲突 | 常见于重复创建（如同名分支已存在的 MR），提示用户检查是否已有相同操作 |
| 422 | 参数校验失败 | 展示 API 返回的具体错误信息（如分支不存在、标签名非法等） |
| 5xx | 服务端错误 | 脚本已自动重试一次；仍失败则告知用户 GitLab 服务可能异常，建议稍后重试 |
| 000 / curl 超时 | 网络不可达 | 告知用户检查网络连接和代理设置，确认 GITLAB_URL 可访问 |

- 脚本执行失败（非零退出码）时，展示 stderr 输出帮助定位问题
- 不要静默忽略任何错误，确保用户始终能看到失败原因

## 重要提示

- 命令构造规范参见文档顶部「命令格式规范」章节
- 执行 GitLab API 调用前，确认配置已加载（token 已设置）
- 创建分支和 MR 等操作有副作用，执行前向用户确认
- issue URL 格式：`https://<host>/<project_path>/-/issues/<iid>`
- MR URL 格式：`https://<host>/<project_path>/-/merge_requests/<iid>`
- 如果用户只给了 issue 编号而非 URL，从当前目录的 git remote 自动拼接完整 URL
- 如果用户省略了 issue URL（如 `/sdd review`），从会话上下文中获取之前已加载的 issue 信息，参见「URL 解析优先级」章节
- **绝对不要直接向 master 分支提交代码**，只通过 MR 合入（有 dev 分支时 hotfix/feature 会生成 dev 和 master 两个 MR；无 dev 分支时所有类型均 MR 到 master）
