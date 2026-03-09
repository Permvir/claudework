# SDD Workflow — 功能文档

## 简介

SDD（Spec-Driven Development）是基于 GitLab issue 规范驱动的开发工作流工具。通过 Claude Code Skill 机制，在任意 GitLab 项目目录下使用 `/sdd` 命令，实现从需求阅读、代码开发、MR 提交到自动 review 的完整流程。

## 文件结构

```
sdd_workflow/
├── features.md                         # 本文档
├── CHANGELOG.md                        # 更新日志
├── install.sh                          # 一键安装脚本（支持 --uninstall）
├── skill/
│   ├── SKILL.md                        # Skill 主文件（精简路由）
│   └── actions/                        # 各 action 的详细执行步骤
│       ├── create.md
│       ├── read.md
│       ├── refine.md
│       ├── review.md
│       ├── dev.md
│       ├── submit.md
│       ├── done.md
│       ├── update.md
│       ├── link.md
│       ├── list.md
│       ├── template.md
│       ├── status.md
│       ├── reopen.md
│       ├── assign.md
│       └── label.md
├── scripts/
│   ├── config.sh                       # 配置加载器
│   ├── config-template.sh              # 配置模板
│   ├── gitlab-api.sh                   # GitLab API 封装
│   ├── issue-parser.sh                 # Issue markdown 解析器
│   ├── mr-helper.sh                    # MR 创建辅助
│   └── json-helper.py                  # JSON 操作 + MR 模板渲染辅助工具
├── references/
│   ├── gitlab-api-reference.md         # API 端点速查
│   └── workflow-guide.md               # 工作流阶段指南
├── templates/
│   ├── issue-spec-template.md          # Issue 需求规范模板
│   ├── bug-report-template.md          # Bug issue 模板（错误日志原文保留）
│   ├── dev-notes-template.md           # 开发记录模板
│   └── mr-description-template.md      # MR 描述模板
├── examples/
│   └── sample-issue.md                 # 示例 issue
└── tests/                              # 自动化测试（仅开发时使用，不部署）
    ├── run_tests.sh                    # 测试总入口
    ├── test_json_helper.py             # json-helper.py 全部 action 测试
    ├── test_issue_parser.py            # issue-parser.sh 解析测试
    ├── test_config_functions.sh        # config.sh 辅助函数测试
    ├── test_url_parsing.sh             # gitlab-api.sh URL 解析 + 退出码测试
    └── fixtures/                       # 测试用 issue 样本
```

安装后部署位置：
- `~/.claude/skills/sdd/` — Skill 文件 + actions + scripts + references + templates + examples
- `~/.claude/sdd-config.sh` — 用户配置（token 等，仅首次创建，重装不覆盖）

## 安装

```bash
bash sdd_workflow/install.sh
```

安装完成后，编辑配置文件完成以下步骤：

```bash
vi ~/.claude/sdd-config.sh
```

### 第一步：填写 GitLab 实例地址

找到 `GITLAB_URL` 行，替换为你所在团队的 GitLab 地址（不含尾部斜杠）：

```bash
# 替换前（占位符）
GITLAB_URL="https://your-gitlab.example.com"

# 替换后（填写你的实际地址）
GITLAB_URL="http://your-company-gitlab.com"
```

> 不确定地址？在浏览器中打开任意一个项目 issue，URL 中 `/-/issues/` 之前的部分（去掉项目路径）就是 `GITLAB_URL`。

### 第二步：填写 Personal Access Token

找到 `GITLAB_TOKEN` 行，替换为你的 Personal Access Token：

```bash
GITLAB_TOKEN="YOUR_TOKEN_HERE"   # 替换为实际 Token
```

**Token 获取方式**：GitLab → 右上角头像 → Edit profile → Access Tokens → Add new token
- Name：随意（如 `sdd-workflow`）
- Expiration date：建议设置（如 90 天后）
- Scopes：勾选 **api**
- 点击 Create → 复制生成的 Token（只显示一次）

### 第三步：验证配置

```bash
bash ~/.claude/skills/sdd/scripts/config.sh --export
```

输出示例（配置正确时）：

```
SDD Workflow 配置：

  [GitLab]
  GITLAB_URL              = http://your-company-gitlab.com
  GITLAB_TOKEN            = 已设置 (20 字符)

  [开发者]
  DEVELOPER_NAME          = your.name

  [Git 分支管理]
  DEFAULT_BASE_BRANCH     = dev
  ...
```

如果 `GITLAB_TOKEN` 显示"未设置"，说明 Token 未正确填写。

### 可选配置

配置文件中还有以下可按需调整的选项（均有默认值，可不填）：

```bash
# 开发者名称（留空则自动从 git config user.name 读取）
DEVELOPER_NAME=""

# 默认基线分支（自动检测：远程无 dev 分支时回退为 master）
DEFAULT_BASE_BRANCH="dev"

# MR 合并后是否删除源分支（默认 true）
MR_REMOVE_SOURCE_BRANCH="true"

# MR 合并时是否 squash commits（默认 true）
MR_SQUASH="true"
```

Token 获取：GitLab → Settings → Access Tokens → 创建（需要 `api` scope）

> **安全提示**：`~/.claude/sdd-config.sh` 包含 Token 等敏感凭证，安装脚本已自动将其权限设为 600（仅所有者可读写）。请勿将此文件提交到 git 仓库。建议在 GitLab 中设置 Token 过期时间并定期轮换（如每 90 天），过期后重新编辑配置文件更新 Token 值即可。

### 多账户切换（配合 gitlab_profiles）

同一台电脑上有多人使用，或需要在不同 GitLab 账户之间切换时，推荐配合 **gitlab_profiles** 工具动态切换账户，无需修改 `~/.claude/sdd-config.sh`。

**原理**：`gitlab_profiles` 切换账户时，通过 `source` 把 `GITLAB_URL`、`GITLAB_TOKEN`、`DEVELOPER_NAME` 写入当前 shell 的环境变量。SDD 的 `config.sh` 在加载时，会**优先使用环境变量，覆盖配置文件中的值**，因此两者天然兼容，无需修改任何代码。

**优先级**：环境变量（`gitlab_profiles` 注入）> `~/.claude/sdd-config.sh`（本地默认账户）> 脚本内置默认值

**使用方式**：

```bash
# 1. 安装 gitlab_profiles（如尚未安装）
bash gitlab_profiles/install.sh

# 2. 添加各自的账户 profile（每人操作一次）
gitlab-use add
# 按提示填写：profile 名称、GitLab URL、Personal Access Token、开发者名称

# 3. 使用前切换到自己的账户（在 Claude Code 启动前，或在新 session 中）
gitlab-use alice      # 切换到 alice 的账户

# 4. 正常使用 SDD（自动使用 alice 的 URL 和 Token）
/sdd read <issue_url>
```

**典型场景（多人共用一台 Mac）**：

| 操作者 | 操作 | 效果 |
|--------|------|------|
| Alice | `gitlab-use alice` | `GITLAB_TOKEN` 切换为 Alice 的 Token |
| Bob | `gitlab-use bob` | `GITLAB_TOKEN` 切换为 Bob 的 Token |
| 任意人 | 不执行 `gitlab-use` | 使用 `~/.claude/sdd-config.sh` 中的默认账户 |

**注意**：`gitlab-use` 切换效果仅限当前 shell session，关闭终端后自动失效，不影响其他人。

> `~/.claude/sdd-config.sh` 适合作为个人电脑的**默认账户**兜底配置。多人共用机器时，建议配置文件中保持 `GITLAB_TOKEN="YOUR_TOKEN_HERE"`（不填 Token），强制每个人都通过 `gitlab-use` 切换后再使用，避免误用他人账户提交。

### 卸载

```bash
bash sdd_workflow/install.sh --uninstall
```

> 卸载会删除 `~/.claude/skills/sdd/` 目录，但保留用户配置文件 `~/.claude/sdd-config.sh`（含敏感凭证，需手动删除）。

## 配置项

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `GITLAB_URL` | `http://gitlab.example.com` | GitLab 实例地址 |
| `GITLAB_TOKEN` | — | Personal Access Token（必填） |
| `DEVELOPER_NAME` | git config user.name | 开发者名称，用于分支命名 |
| `DEFAULT_BASE_BRANCH` | `dev` | 默认基线分支（自动检测：远程无 dev 分支时回退为 `master`） |
| `DEFAULT_BRANCH_TYPE` | `dev` | 默认分支类型（dev/hotfix/feature） |
| `BRANCH_PATTERN_DEV` | `dev-{developer}-{issue_iid}` | dev 类型分支命名 |
| `BRANCH_PATTERN_HOTFIX` | `hotfix-{developer}-{issue_iid}` | hotfix 类型分支命名 |
| `BRANCH_PATTERN_FEATURE` | `feature-{developer}-{issue_iid}` | feature 类型分支命名 |
| `MR_REMOVE_SOURCE_BRANCH` | `true` | MR 合并后删除源分支 |
| `MR_SQUASH` | `true` | MR 合并时 squash commits |
| `SDD_CACHE_TTL` | `300` | 分支检测缓存有效期（秒），设为 0 禁用缓存 |

验证配置：

```bash
bash ~/.claude/skills/sdd/scripts/config.sh --export
```

## Group 级配置（Wiki 自动标签）

除了本地 `~/.claude/sdd-config.sh` 的个人配置外，SDD 还支持从 GitLab **Group Wiki** 读取团队级配置。目前支持的 Group 级配置：

### 仓库系统标签自动映射（按仓库名）

在 Group 的 **Plan → Wiki** 中创建名为 **`sdd-configuration`** 的页面，可配置「仓库 → 系统标签」映射关系。`/sdd create` 创建 issue 时，会自动根据目标项目匹配对应的系统标签。

**创建方式**：进入 GitLab Group → Plan → Wiki → New page，标题填 `sdd-configuration`。

**页面格式规范**：

```markdown
# 系统标签映射

## 系统::订单系统
- order-frontend
- order-backend

## 系统::用户系统
- user-manage-frontend
- user-manage

## 系统::支付引擎
- payment-engine
```

**格式说明**：

| 元素 | 格式 | 说明 |
|------|------|------|
| 标签名 | `## 标签名` | 二级标题，即为要自动添加的 Label 名称 |
| 仓库名 | `- 仓库名` | 列表项，标签下方列出属于该标签的仓库名（仅仓库名，不含 Group 路径） |

**规则**：
- 每个 `##` 标题定义一个标签，其下的列表项为关联的仓库
- 仓库名必须与 GitLab 项目的 **仓库名**（非完整路径）完全匹配
- 一个仓库可出现在多个标签下（支持一对多映射）
- `#` 一级标题和非 `##`/`-` 开头的行会被忽略，可用于写注释说明
- Label 必须已在 Group 中创建（SDD 不会自动创建 Label）

**行为**：
- `/sdd create` 时自动读取当前项目所属 Group 的 `sdd-configuration` Wiki 页面
- 根据目标项目仓库名匹配标签，自动合并到 issue labels 中（与 `workflow::backlog` 和 `--label` 参数合并）
- 不在映射表中的项目不受影响，行为与之前一致
- Wiki 页面不存在或读取失败时静默跳过，不影响正常创建流程
- 匹配成功时在创建结果中展示 `自动添加标签: 系统::xxx（来自 Group Wiki 配置）`

### Issue type 标签映射（按 --type 参数）

在同一 `sdd-configuration` Wiki 页面中，可添加「创建Issue type标签映射」章节，配置 `--type` 值到标签的映射关系：

```markdown
# 创建Issue type标签映射

## requirement
- requirement

## bug
- bug
```

**格式说明**：

| 元素 | 格式 | 说明 |
|------|------|------|
| 章节标题 | `# 创建Issue type标签映射` | 一级标题，固定名称 |
| type 名 | `## requirement` / `## bug` | 二级标题，对应 `--type` 参数值 |
| 标签名 | `- requirement` / `- bug` | 列表项，该 type 对应要添加的标签 |

**行为**：
- `/sdd create` 时根据 `--type` 值（默认 `requirement`）查找对应标签并自动添加
- 与系统标签、`--label` 参数合并，不覆盖
- Wiki 中无对应 type 配置时不添加 type 标签，不影响正常流程
- Label 必须已在 Group 中创建（SDD 不会自动创建 Label）

## 使用方式

在任意 GitLab 项目目录下启动 Claude Code：

### Issue URL 简写

**只需在会话中首次操作时指定 issue URL，后续操作可省略**。Claude 会从对话上下文自动获取 issue 信息。

支持三种形式：
| 形式 | 示例 | 说明 |
|------|------|------|
| 完整 URL | `/sdd read http://gitlab.example.com/mygroup/myproject/-/issues/8` | 首次使用或切换 issue 时 |
| Issue 编号 | `/sdd read 8` | 从 git remote 自动拼接完整 URL |
| 省略 URL | `/sdd review` | 复用会话中已加载的 issue |

**典型工作流（单会话内）**：
```
/sdd read http://gitlab.example.com/mygroup/myproject/-/issues/8   ← 首次指定完整 URL
（与 Claude 讨论需求）
/sdd refine                                                 ← 省略 URL，自动复用
/sdd review                                                 ← 省略 URL，自动复用
/sdd dev                                                    ← 省略 URL，自动复用
（编写代码...）
/sdd submit                                                 ← 省略 URL，自动复用
```

> **注意**：省略 URL 的前提是当前会话中已执行过带 issue URL 的命令。如果是新会话，需要重新指定 issue URL。

### 创建 Issue

```
/sdd create http://gitlab.example.com/mygroup/myproject 优化登录流程, 增加验证码校验
```

根据描述自动按 SDD 模板生成结构化 issue（背景、需求、验收标准），创建前自动检查必填章节完整度，创建到 GitLab 并自动添加 `workflow::backlog` 标签。

**`--type` 参数**：通过 `--type=requirement|bug` 指定 issue 类型，**默认为 `requirement`**（不传时等同于 `requirement`）：

| 类型 | 行为 |
|------|------|
| `requirement`（默认） | 按 `issue-spec-template` 生成结构化规范（背景、需求、验收标准等） |
| `bug` | 将错误日志**原文不做任何修改**地放入 issue 的「错误日志」代码块，其余章节仅作简单推断 |

```
# 默认 requirement 类型
/sdd create http://gitlab.example.com/mygroup/myproject 优化登录流程, 增加验证码校验

# 显式指定 requirement
/sdd create --type=requirement http://gitlab.example.com/mygroup/myproject 优化登录流程, 增加验证码校验

# bug 类型：错误日志原文保留，不做修改
/sdd create --type=bug http://gitlab.example.com/mygroup/myproject NullPointerException at UserService.java:42\n  at com.example.UserService.getUser(UserService.java:42)
```

**type 标签自动映射**：在 Group Wiki 的 `sdd-configuration` 页面中添加「创建Issue type标签映射」章节后，create 时会根据 `--type` 值自动匹配并添加对应标签（如 `requirement` 或 `bug`）。Wiki 配置格式：

```markdown
# 创建Issue type标签映射
## requirement
- requirement

## bug
- bug
```

支持通过 `--label="..."` 参数附加额外标签（与 `workflow::backlog` 及 type 标签合并，不覆盖）：

```
/sdd create --label="priority::high" http://gitlab.example.com/mygroup/myproject 修复登录页崩溃问题
/sdd create --type=bug --label="priority::high" http://gitlab.example.com/mygroup/myproject <错误日志>
```

### 阅读 Issue

```
/sdd read http://gitlab.example.com/mygroup/myproject/-/issues/8
```

解析 issue markdown，展示结构化摘要（背景、需求、验收标准），检查规范完整度。如果 issue 包含「关联 Issue」栏目，自动获取每个关联 issue 的标题和状态一并展示。如果 issue 处于 `workflow::backlog` 状态，自动更新为 `workflow::start`。

### 精炼 Issue

```
/sdd refine http://gitlab.example.com/mygroup/myproject/-/issues/8
```

读取 issue 中的讨论点，与 Claude 讨论后将结论更新回 issue 描述。支持两种模式：

**模式 A：会话内讨论回写** — 如果当前会话已执行过 `read` 并有讨论，`refine` 会自动回顾对话历史，将讨论结论融入 issue 描述。典型用法：
```
/sdd read <url>          ← 阅读 issue
（与 Claude 自由讨论需求、技术方案等）
/sdd refine <url>        ← 将讨论结论写回 issue
```

**模式 B：结构化讨论** — 如果没有已有讨论上下文，`refine` 从 issue 中提取讨论点逐项讨论：
- **`## 问题` 专区**：放通用问题，讨论解决后从列表中移除
- **`<!-- TODO: xxx -->` 行内标记**：贴近上下文的具体疑问，讨论解决后删除标记、结论写入原位

如果 issue 处于 `workflow::backlog` 状态，refine 会自动将标签更新为 `workflow::start`；已处于后续阶段的 issue 标签不受影响。可多次执行以逐步完善需求，适用于 `read` 之后、`dev` 之前的需求精炼阶段。

### 审查 Issue Spec

```
/sdd review http://gitlab.example.com/mygroup/myproject/-/issues/8
```

以冷读者视角审查 issue spec 质量，输出结构化审查报告。检查结构完整性、需求清晰度、
验收标准覆盖等维度，给出通过/未通过结论和具体改进建议。

建议在 refine 之后、dev 之前，于新 session 中执行，以获得无偏见的审查效果。

### 审查 MR 代码变更

```
/sdd review http://gitlab.example.com/mygroup/myproject/-/merge_requests/42
```

对 MR 代码变更进行结构化审查。自动获取 MR diff，从代码质量、安全性、测试覆盖、潜在 bug 等维度逐文件审查，输出 MR Review 报告。如果 MR 描述中关联了 issue（如 `Closes #N`），还会对照 issue 验收标准检查需求覆盖度。审查结论自动作为评论写入 MR，方便团队查看。

### 开发

```
/sdd dev http://gitlab.example.com/mygroup/myproject/-/issues/8
/sdd dev --type=hotfix http://gitlab.example.com/mygroup/myproject/-/issues/8
/sdd dev --type=feature http://gitlab.example.com/mygroup/myproject/-/issues/8
```

默认从 `dev` 分支创建开发分支 `dev-{developer}-8`，更新 issue 标签为 `workflow::in dev`，根据需求编写代码和测试。如果 issue 包含关联 Issue，开始编码前会自动获取关联 issue 的需求和技术备注作为跨仓库上下文参考（代码修改仅限当前仓库）。支持 hotfix（从 master）和 feature（从 master）类型。

### 提交 MR

```
/sdd submit http://gitlab.example.com/mygroup/myproject/-/issues/8
```

推送代码到远程，本地 review 变更（先展示文件统计摘要，仅对有问题文件展示 diff 片段），自动创建 MR 并设置 reviewer，更新标签为 `workflow::evaluation`。hotfix/feature 类型在有 dev 分支时自动创建 2 个 MR（dev + master），第一个 MR 设为不删除源分支，确保两个 MR 都可从同一源分支合入；两个 MR 都合入后源分支由第二个 MR 自动删除。

**Reviewer 优先级**：
1. 命令行 `--reviewer=user1,user2` 参数
2. issue 描述的 `## Reviewer` 章节
3. 不设置 Reviewer（由提交人自行 review）

未指定 reviewer 时 MR 正常创建，不会阻塞提交流程。

### 完成 Issue

```
/sdd done http://gitlab.example.com/mygroup/myproject/-/issues/8
```

MR 合入后，手动触发此命令关闭 issue。执行时自动检测关联 MR 的合入状态：
- **已全部合入**：自动将 issue 标签更新为 `workflow::done` 并关闭 issue
- **尚未合入**：提示用户确认是否仍要强制关闭

关闭后如果当前在 SDD 开发分支上，提示是否切回基线分支并删除本地开发分支。

### 添加 Issue 评论

```
/sdd update http://gitlab.example.com/mygroup/myproject/-/issues/8
```

向 GitLab Issue 评论区添加一条结构化评论。执行后 Claude 会交互式询问你要记录的内容，你只需用自然语言描述即可，Claude 会自动格式化并发布到 Issue 评论区。

**交互流程示例**：
```
> /sdd update 8

Claude: 请问要记录哪些内容？可以包括：已完成事项、关键决策、待办事项等。

用户: 完成了登录接口开发和单元测试，决定 token 过期时间设为 24 小时，
      还需要补充集成测试和接口文档

Claude: 已添加评论到 Issue #8 ✓
```

评论会以结构化格式发布到 GitLab，团队成员在 Issue 页面可直接查看：
```markdown
### 开发记录 — 2026-03-03

**阶段**：开发中

**完成内容**：
- 完成登录接口开发
- 完成单元测试

**关键决策**：
- Token 过期时间设为 24 小时

**待办事项**：
- 补充集成测试
- 编写接口文档
```

#### update 交互阶段的 Prompt 用法

Claude 的格式化能力不仅限于手动输入内容。当会话上下文丰富时（如刚完成一段开发或需求讨论），可以直接让 Claude 从对话中提炼并生成评论，效果更好。

**上下文自动提炼**（最省力，推荐）

让 Claude 主动梳理当前对话，自动生成结构化评论：

```
把完成的功能和对话的上下文帮我记录一下
```
```
根据我们这次对话，帮我总结今天做了什么、做了哪些决策
```
```
把刚才我们讨论的技术方案和最终决策记录下来
```

> 适合在开发收尾或讨论结束后使用，此时对话上下文最丰富，效果最好。

**指定角度提炼**

只想记录某一类信息时：

```
重点记录一下我们刚才做的技术决策，其他内容不用写太多
```
```
把刚才遇到的问题和解决方案记录一下，作为经验备注
```
```
记录一下当前进度和下一步计划，完成内容简单提一下就行
```

**上下文 + 手动追加**

让 Claude 总结上下文，同时补充你额外想写的内容：

```
帮我总结今天的对话，另外待办事项加上：明天还要补集成测试和文档
```
```
根据对话记录今天的进展，关键决策那里加一条：暂不支持批量操作，等下期迭代
```

**纯手动输入**

直接描述内容让 Claude 格式化，不依赖上下文：

```
完成了登录接口和单元测试，决定 token 过期时间设为 24h，还需要补集成测试
```

| 场景                   | 推荐用法                     |
| ---------------------- | ---------------------------- |
| 对话内容丰富，懒得手打 | "帮我总结对话" 类            |
| 只想记某类信息         | "重点记录决策/问题/进度"     |
| 有额外内容需补充       | "总结对话 + 另外加上 xxx"    |
| 对话内容少             | 直接口述内容让 Claude 格式化 |

### 关联 Issue（link）

```
/sdd link http://gitlab.example.com/mygroup/backend/-/issues/12 后端 API 接口定义
/sdd link --issue=8 http://gitlab.example.com/mygroup/frontend/-/issues/5
```

向指定 issue 的「关联 Issue」栏目追加一条关联 URL。当前 issue 从会话上下文获取（需先执行过 `read`/`dev` 等），也可通过 `--issue=N` 显式指定。自动验证关联 issue 是否存在、检查重复，栏目不存在时自动创建。如果未提供说明文字，自动使用关联 issue 的标题。

### 查看工作状态

```
/sdd status
```

展示当前 SDD 工作状态概览：当前分支、分支类型、关联 issue 标题和工作流阶段、本地未暂存/已暂存/未推送变更统计。用于新会话中快速了解当前开发上下文。

### 重新打开 Issue

```
/sdd reopen http://gitlab.example.com/mygroup/myproject/-/issues/8
```

重新打开已关闭的 issue，并将标签更新为 `workflow::start`。

### 指派 Issue

```
/sdd assign http://gitlab.example.com/mygroup/myproject/-/issues/8 alice
/sdd assign 8 alice bob
/sdd assign --clear
```

将 issue 指派给一个或多个项目成员，`--clear` 清空指派人。如果省略 issue URL，从会话上下文自动获取。

### 管理 Issue 标签

```
/sdd label --label="bug::functional,priority::high" <issue_url>
/sdd label --remove="bug::functional" <issue_url>
/sdd label --label="priority::high" --remove="priority::low" <issue_url>
```

为 issue 添加或移除标签。标签名通过 `--label="..."` / `--remove="..."` 格式传入，支持含空格和 `::` 的标签名，多个标签用逗号分隔。省略 issue URL 时从会话上下文自动获取。

边界行为：参数值为空时报错；同时添加和移除同一标签时该标签不变（无操作）；移除不存在的标签时提示用户。

### 查看 Issue 看板

```
/sdd list
/sdd list http://gitlab.example.com/mygroup/myproject
```

列出当前项目（或指定项目）中带 `workflow::` 标签的 issue，按工作流阶段分组展示（开发中 > 测试验收 > 已规划 > 待办）。每个 issue 显示编号、标题和指派人。用于快速了解项目整体进度。

### 查看模板

```
/sdd template
```

输出 SDD issue 规范模板，用于创建新的需求 issue。

## 意图推理与 Action 链式执行

SDD 的每个 action（create、read、dev、submit 等）是**独立的**，action 之间没有自动触发机制。但 Claude 会根据用户的原始意图，推理是否需要继续执行下一个 action。

### 实际案例

用户执行：
```
/sdd create http://gitlab.example.com/mygroup/claudework 完善gitlab_profiles这个工具并在共享的mac电脑测试成功
```

Claude 的推理过程：
1. 识别为 **create action**（项目 URL + 描述）→ 创建了 Issue #9
2. 分析用户原始意图："**完善**...并在共享的mac电脑**测试成功**" — 表达的是要**完成整件事**，不只是创建 issue
3. 参考 SKILL.md 中 create action 的提示：`创建完成后可直接使用 /sdd dev <issue_url> 开始开发`
4. 判断用户期望完整工作流 → 主动继续执行 dev action

整个过程中 create action 在步骤 6（返回 issue URL）就已结束，后续的 dev 是 Claude 基于意图推理主动发起的。

### 如何控制这个行为

| 用户表达 | Claude 行为 | 原因 |
|----------|-------------|------|
| `完善gitlab_profiles工具并测试成功` | create → 自动继续 dev | 意图明确包含"开发并完成" |
| `帮我创建一个issue：完善gitlab_profiles工具` | 仅 create | 意图明确限定在"创建 issue" |
| `创建issue跟踪gitlab_profiles的改进计划` | 仅 create | 意图是记录和跟踪，非立即开发 |

### 设计要点

- **Action 独立性**：每个 action 有明确的开始和结束边界，通过 GitLab label 跟踪状态，不存在配置层面的自动链式触发
- **意图驱动**：Claude 根据用户输入的自然语言推理下一步操作，而非预设的流程编排
- **可预期性**：想精确控制执行范围时，在指令中明确表达意图边界（如"创建一个 issue"而非"完善某功能"）

## Git 分支管理

> 详细分支规范和流程图见 `references/workflow-guide.md`。

项目采用 master + dev 双主线分支模型（概要）：

| 分支类型 | 基线 | MR 目标 | 命名规范 | 用途 |
|----------|------|---------|----------|------|
| dev（默认） | `dev` | `dev` | `dev-{developer}-{iid}` | 常规迭代开发 |
| hotfix | `master` | `dev` + `master` | `hotfix-{developer}-{iid}` | 线上紧急修复 |
| feature | `master` | `dev` + `master` | `feature-{developer}-{iid}` | 紧急短周期新功能 |

- **master**: 生产环境，任何时候不能直接修改代码
- **dev**: 开发主线，常规开发的 MR 目标
- **hotfix/feature**: 完成后同时合到 dev 和 master

> **无 dev 分支的项目**：自动检测远程分支，若无 `dev` 分支则默认基线回退到 `master`。此时 dev 类型的基线和 MR 目标均为 `master`，hotfix/feature 的 MR 目标仅合到 `master`。适用于只有 master 分支的工具类项目，无需手动配置。

## 工作流状态流转（Issue Board 标签）

> 各阶段详细操作步骤见 `references/workflow-guide.md`。

```
workflow::backlog → workflow::start → workflow::in dev → workflow::evaluation → workflow::done → Closed
       │                │                  │                   │                    │
     待办事项          已规划             开发中            测试验收中              完成
```

> 所有标签均为 `workflow::` scoped label，同一 scope 下同一时间只保留一个标签，GitLab 自动替换。

| 标签 | 说明 | SDD 动作 |
|------|------|----------|
| `workflow::backlog` | 待办事项，需求收集 | — |
| `workflow::start` | 已规划，近期开发 | `/sdd read` 或 `/sdd refine` 自动设置 |
| `workflow::in dev` | 正在开发中 | `/sdd dev` 自动设置 |
| `workflow::evaluation` | 测试/验收中 | `/sdd submit` 自动设置；可用 `/sdd review <mr_url>` 审查 MR |
| `workflow::done` | 验收完成，准备关闭 | `/sdd done` 自动设置并关闭 issue |

## Issue 规范

SDD 要求 issue 按统一格式编写，包含以下章节：

1. **背景** — 问题上下文和动机（必填）
2. **需求** — 功能需求列表（必填）
3. **验收标准** — 可验证的完成条件（必填）
4. **关联 Issue** — 跨仓库关联的 Issue URL（可选，用于跨仓库协作场景）
5. **技术备注** — 技术约束和建议（可选）
6. **测试计划** — 测试策略和边界场景（可选）
7. **Reviewer** — MR 审查人（可选，提交 MR 时自动设置）
8. **问题** — 待讨论的问题（可选，配合 `/sdd refine` 使用）
9. **开发记录** — 开发过程记录（开发阶段填写）

完整示例见 `examples/sample-issue.md`。

### 关联 Issue（跨仓库协作）

当一个任务涉及多个仓库时，可在各仓库的 issue 中通过「关联 Issue」栏目互相引用，让 Claude 在开发时获得跨仓库的全局上下文。

**使用方式**：在 issue 的 `## 关联 Issue` 栏目中，每行列出一个 Issue URL，可附简要说明：

```markdown
## 关联 Issue

- http://gitlab.example.com/mygroup/backend/-/issues/12 — 后端 API 接口定义
- http://gitlab.example.com/mygroup/frontend/-/issues/8 — 前端页面适配
```

**SDD 各 action 的行为**：
- **create** — 生成的 issue 包含空的关联 Issue 栏目，方便后续填写
- **read** — 自动获取关联 issue 的标题和状态，在摘要中展示
- **refine** — 精炼 issue 内容时保留关联 Issue 栏目，不修改其中的关联条目
- **review** — spec 审查中，关联 Issue 的外部引用视为合理的依赖，不影响自包含性评分
- **dev** — 开始编码前自动获取关联 issue 的需求和技术备注，理解接口约定、数据格式等依赖关系（代码修改仅限当前仓库）
- **submit** — 不涉及关联 Issue 栏目，MR 描述通过 `Closes #N` 关联当前 issue
- **done** — 关闭当前 issue，不影响关联 Issue 中引用的其他 issue 状态
- **update** — 添加评论，不涉及关联 Issue 栏目
- **link** — 向当前 issue 追加关联 URL，自动验证、去重、创建栏目
- **list** — 列出 issue 看板，不涉及关联 Issue
- **template** — 输出的模板包含关联 Issue 栏目占位
- **status** — 展示当前工作状态，不涉及关联 Issue
- **reopen** — 重新打开 issue，不涉及关联 Issue 栏目
- **assign** — 指派 issue，不涉及关联 Issue 栏目
- **label** — 添加或移除标签，不涉及关联 Issue 栏目

**设计原则**：关联 Issue 是可选栏目，不加入必填检查。SDD 保持单仓库单 issue 的核心模型，关联 Issue 仅提供跨仓库的参考上下文。

## 文档说明

> **Single Source of Truth**: `skill/SKILL.md` + `skill/actions/*.md` 是 SDD 工作流的权威定义，本文档（features.md）为面向用户的功能说明。如有不一致，以 SKILL.md 和 action 文件为准。

## 设计原则

| 原则 | 说明 |
|------|------|
| 规范驱动 | 以 issue 中的需求规范为开发依据，验收标准为完成判定 |
| 用户显式调用 | `disable-model-invocation: true`，所有操作需用户主动触发 |
| 项目自动识别 | 从 git remote 解析项目路径，无需手动指定 |
| 配置分离 | 用户配置独立于 Skill 文件，重装不丢失 |
| 标签流转 | 通过 Issue Board 标签自动管理开发状态 |
| 按需加载 | SKILL.md 为精简路由，action 详细步骤按需读取，节省 context |

## 开发与测试

运行自动化测试（开发时使用，tests/ 目录不部署到用户环境）：

```bash
bash sdd_workflow/tests/run_tests.sh
```

测试覆盖：
- `test_json_helper.py` — json-helper.py 全部 17 个 action（78 个用例）
- `test_issue_parser.py` — issue markdown 解析、章节映射、代码块处理、TODO 提取、Reviewer 解析、完整度检查
- `test_config_functions.sh` — 分支名生成、基线分支、MR 目标、no_proxy 去重、错误码
- `test_url_parsing.sh` — issue/MR/project URL 解析、host 校验、退出码验证

## 更新日志

详细更新记录见 [`CHANGELOG.md`](./CHANGELOG.md)。
