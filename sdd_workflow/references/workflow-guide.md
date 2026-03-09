# SDD 工作流阶段指南

## 概览

SDD（Spec-Driven Development）工作流基于 GitLab Issue Board 标签驱动：

```
workflow::backlog → workflow::start → workflow::in dev → workflow::evaluation → workflow::done → Closed
       │                │                  │                   │                    │
       │                │                  │                   │                    └── 验收完成，准备关闭
       │                │                  │                   └── 测试/验收中
       │                │                  └── 正在开发（/sdd dev）
       │                └── 已规划，近期开发
       └── 待办事项（需求收集）
```

> `workflow::` 为 GitLab scoped label，同一 scope 下同一时间只保留一个标签。

## Git 分支管理规范

### 分支模型

```
master（生产环境） ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━→
  │              ↑ hotfix 合入        ↑ feature 合入  ↑ 发版
  │              │                   │               │
  ├──→ hotfix-developer-iid ──→ 同时合 dev + master
  ├──→ feature-developer-iid ──→ 同时合 dev + master
  │
dev（开发主线） ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━→
  │            ↑ 开发分支合入
  ├──→ dev-developer-iid ──→ MR 到 dev
```

> **无 dev 分支的项目**：自动检测远程分支，若无 `dev` 分支则默认基线回退到 `master`。此时 dev 类型的基线和 MR 目标均为 `master`，hotfix/feature 的 MR 目标仅合到 `master`。适用于只有 master 分支的工具类项目，无需手动配置。

### 分支类型详解

#### master 分支
- 线上稳定和部署生产环境功能的主分支
- 功能开发完成后发版时，将代码合到 master，通常打上版本号标签
- **任何时间都不能直接修改代码**
- 只接受来自 dev（发版）、hotfix（紧急修复）、feature（紧急功能）的合入

#### dev 分支
- 维护未来最新一次发版的代码
- 只有未来最新一次发版的代码才需要合并至此分支
- 常规迭代开发的 MR 目标分支

#### hotfix 分支
- 用于线上紧急 bug 修复，或开发不属于本迭代周期内优先级高于当前迭代的紧急功能
- **从 master 拉取**
- 命名：`hotfix-{开发人员}-{issue编号}` 或 `hotfix-{开发人员}-{问题描述}`
- 开发完成后**同时合到 dev 和 master**（无 dev 分支时仅合 master）

#### feature 功能分支
- 用于开发紧急上线且周期短的新功能
- **从 master 拉取**
- 命名：`feature-{开发人员}-{issue编号}` 或 `feature-{开发人员}-{功能描述}`
- 开发完成后**同时合到 dev 和 master**（无 dev 分支时仅合 master）

### SDD 中的分支选择

| 场景 | 分支类型 | 命令 |
|------|----------|------|
| 常规迭代需求 | dev | `/sdd dev <url>` |
| 线上紧急 bug | hotfix | `/sdd dev --type=hotfix <url>` |
| 紧急上线小功能 | feature | `/sdd dev --type=feature <url>` |

## 阶段零：Create（创建 Issue）

**对应命令**: `/sdd create <project_url> <description>`

**步骤**:
1. 从项目 URL 提取 `project_path`（使用 `parse-project-url`）
2. 调用 `resolve-project-id` 获取 `project_id`
3. Claude 根据用户描述 + 项目上下文，按照 SDD issue 模板生成结构化内容：
   - 标题、背景、需求列表、验收标准、技术备注
4. 规范完整度检查（必填章节：背景、需求、验收标准），缺失时提示用户
5. 直接调用 `create-issue` 创建 issue（无需用户确认），自动添加 `workflow::backlog` 标签
6. 返回 issue URL

**输出**: 创建成功的 issue URL，可直接用于后续 `/sdd read <issue_url>` 或 `/sdd dev <issue_url>`

## 阶段一：Read（需求阅读）

**对应命令**: `/sdd read <url>`

**步骤**:
1. 从 issue URL 提取 `project_path` 和 `issue_iid`
2. 调用 `resolve-project-id` 获取 `project_id`
3. 调用 `get-issue` 获取 issue 详情
4. 用 `issue-parser.sh` 解析 markdown 为结构化 JSON
5. 展示结构化摘要给用户：
   - 标题、标签、指派人
   - 背景、需求列表、验收标准
   - 技术备注（如有）
6. 检查规范完整度，标记缺失章节
7. 获取 issue 评论（补充上下文）
8. 如果 issue 处于 `workflow::backlog` 状态，提示用户确认后更新标签为 `workflow::start`（用户可跳过）

**输出**: 结构化的需求摘要 + 规范完整度检查结果

## 阶段 1.5：Refine（需求精炼）

**对应命令**: `/sdd refine <url>`

**前置条件**: 已执行 read，issue 中包含讨论点

**两种模式**:

**模式 A — 会话内讨论回写**（当前会话已有 read + 讨论时自动触发）:
1. 重新获取 issue 最新 description
2. 回顾本次会话中 read 后的对话，提取结论
3. 生成更新后的 description（结论融入对应章节）
4. 展示 diff 对比，直接调用 `update-issue-description` 写回 GitLab（无需用户确认）

**模式 B — 结构化讨论**（标准流程）:
1. 同 read 步骤 1-4，获取并解析 issue，保存原始 description
2. 提取讨论点：
   - `## 问题` 章节中的问题列表（`questions` / `questions_list`）
   - `<!-- TODO: xxx -->` 内联标记（`todos`，含行号和上下文）
3. 展示讨论点总览，然后逐项讨论
   - 支持「跳过」和「全部跳过」
   - Claude 可读取项目代码回答技术问题
4. 生成更新后的 description：
   - 已解决的问题从 `## 问题` 移除（全部解决则删除整个章节）
   - 已解决的 TODO 标记删除，结论写入原位
   - 未解决的保持原样
5. 展示 diff 对比，直接调用 `update-issue-description` 写回 GitLab（无需用户确认）

**输出**: 更新后的 issue description

**注意**:
- 如果 issue 处于 `workflow::backlog` 状态，refine 会自动将标签更新为 `workflow::start`；已处于后续阶段的 issue 标签不受影响
- 可多次执行，逐步完善需求
- 如果 issue 中没有讨论点，可进入自由讨论模式

## 阶段 1.7：Review（规范审查）

`review` 根据 URL 类型自动选择审查模式。

### Issue Spec Review

**对应命令**: `/sdd review <issue_url>`

**前置条件**: 已执行 refine 完善需求（或 issue spec 已就绪）

**建议**: 在新的 Claude session 中执行，以冷读者视角审查

**步骤**:
1. 同 read 步骤 1-4，获取并解析 issue
2. 获取 issue 评论作为补充上下文
3. 逐维度审查 spec 质量（结构完整性、需求清晰度、验收标准覆盖、一致性等）
4. 输出结构化审查报告，给出通过/未通过结论

**输出**: 审查报告（阻塞项 + 建议项 + 各维度评估表）

**后续**:
- ✅ 通过 → 进入 `/sdd dev <url>`
- ❌ 未通过 → 返回 `/sdd refine <url>` 修复后重新 review

### MR Code Review

**对应命令**: `/sdd review <mr_url>`

**前置条件**: MR 已创建（通常在 `/sdd submit` 之后）

**步骤**:
1. 解析 MR URL，提取 `project_path` 和 `mr_iid`
2. 获取 `project_id`
3. 获取 MR 详情（title、description、source/target branch）
4. 获取 MR 变更（所有文件 diff）
5. 从 MR description 提取关联 issue（如有），获取 issue 详情作为需求上下文
6. 逐文件审查 diff：代码质量、需求覆盖度、安全性、测试覆盖、潜在 bug
7. 输出 MR Review 报告
8. 自动将 review 报告作为评论添加到 MR

**输出**: MR Review 报告（必须修改项 + 建议改进项 + 各维度评估表 + 变更摘要），同时写入 MR 评论

## 阶段二：Dev（开发）

**对应命令**: `/sdd dev [--type=dev|hotfix|feature] <url>`

**前置条件**: 已执行 read，了解需求

**步骤**:
1. 解析 issue URL，获取 project_id 和 issue 信息
2. 确定分支类型（默认 dev），加载对应的分支配置
3. 从正确的基线分支创建开发分支（基线由 `get_base_branch()` 决定）：
   - dev 类型：`git checkout -b dev-developer-iid origin/dev`（无 dev 分支时为 `origin/master`）
   - hotfix 类型：`git checkout -b hotfix-developer-iid origin/master`
   - feature 类型：`git checkout -b feature-developer-iid origin/master`
4. 更新 issue 标签：添加 `workflow::in dev`（GitLab 自动移除同 scope 旧标签）
5. 根据需求进行开发：
   - 编写代码实现
   - 编写/更新测试
   - 确保测试通过
6. 提交代码到开发分支
7. 推送分支到远程

**注意**:
- 开发过程中可随时用 `/sdd update <url>` 添加 Issue 评论记录进度
- 分支名从开发者名称和 issue 编号自动生成

## 阶段三：Submit（提交）

**对应命令**: `/sdd submit <url>`

**前置条件**: 开发完成，代码已推送到远程分支

**步骤**:
1. 解析 issue URL，获取 project_id
2. 从当前分支名自动识别分支类型（dev/hotfix/feature）
3. 确定 MR 目标分支（由 `get_primary_mr_target()` 决定；有 dev 分支时 hotfix/feature 需同时合 dev 和 master；无 dev 分支时所有类型仅合 master）
4. 检查工作目录：如有未提交的变更，提示用户先 commit 或 stash
5. 确保代码已推送到远程
6. 本地 code review：
   - 获取所有变更的 diff
   - 审查代码质量、安全性、是否满足验收标准
   - 向用户展示 review 结果
7. 生成 MR 描述：使用模板填充 issue 信息和变更摘要
8. 展示 MR 创建计划并等待用户确认
9. 自动创建 MR（使用 `mr-helper.sh create`），从 API 返回中提取 MR URL
10. 设置 Reviewer：从 issue 描述解析 reviewer 用户名，调用 `mr-helper.sh batch-notify-reviewers` 一次性设置所有 reviewer 并发送单条 @mention 评论
11. 更新 issue 标签：添加 `workflow::evaluation`

**输出**: MR 创建结果（URL）+ Review 摘要

**hotfix/feature 后续操作提醒**:
- 有 dev 分支时：hotfix/feature submit 自动创建 dev 和 master 两个 MR，第一个 MR 设为不删除源分支
- 无 dev 分支时：所有类型仅创建一个 MR 到 master

## 阶段四：Update（添加 Issue 评论）

**对应命令**: `/sdd update <url>`

**步骤**:
1. 解析 issue URL
2. 交互式询问用户要记录的内容，用户用自然语言回复即可
3. 将用户回复按 `dev-notes-template.md` 格式化为结构化评论（自动归类到完成内容、关键决策、待办事项）
4. 调用 `add-issue-note` 添加到 GitLab Issue 评论区
5. 确认完成，展示评论摘要

**输出**: Issue 评论区新增一条结构化评论，团队成员可在 GitLab Issue 页面直接查看

## 阶段五：Done（关闭 Issue）

**对应命令**: `/sdd done <url>`

**前置条件**: MR 已合入（通常在 submit 并通过 review 之后）

**步骤**:
1. 解析 issue URL，获取 project_id 和 issue_iid
2. 调用 `list-issue-related-mrs` 获取关联 MR 列表
3. 检查 MR 合入状态：
   - **全部合入** → 直接进入步骤 4
   - **存在未合入 MR** → 提示用户确认是否仍要关闭
   - **无关联 MR** → 提示用户确认是否仍要关闭
4. 更新标签为 `workflow::done`，关闭 issue
5. 清理本地分支（可选）：如果当前在 SDD 开发分支上，提示用户是否切回基线分支并删除本地开发分支

**输出**: Issue 关闭确认，标签更新为 `workflow::done`

## 附加：Status（状态概览）

**对应命令**: `/sdd status`

**步骤**:
1. 从当前 git 分支名解析分支类型和 issue 编号
2. 从 git remote 获取项目信息
3. 如果解析出 issue_iid，查询 issue 状态（标题、标签、工作流阶段）
4. 获取本地变更统计（未暂存、已暂存、未推送提交）
5. 展示状态概览

**输出**: 当前分支、关联 issue、工作流阶段、本地变更统计

## 附加：Reopen（重新打开 Issue）

**对应命令**: `/sdd reopen <issue_url>`

**步骤**:
1. 解析 issue URL，获取 project_id 和 issue_iid
2. 获取 issue 详情，检查当前状态是否为 closed
3. 向用户确认操作
4. 调用 `reopen-issue` 重新打开 issue
5. 更新标签为 `workflow::start`

**输出**: Issue 重新打开确认，标签更新为 `workflow::start`

**注意**: 仅对 closed 状态的 issue 执行；重开后可继续使用 `/sdd dev` 开发或 `/sdd assign` 指派

## 附加：Assign（指派 Issue）

**对应命令**: `/sdd assign <issue_url> <username1> [username2 ...]`

**步骤**:
1. 解析 issue URL，获取 project_id 和 issue_iid
2. 获取 issue 详情，展示当前指派人
3. 解析用户名，通过 `resolve-user-id` 获取 user_id
4. 调用 `update-issue-assignees` 设置指派人

**输出**: 指派人更新确认

**选项**:
- `--clear`: 清空所有指派人（与用户名互斥）
- 此操作会替换全部指派人，而非追加
- 不修改 issue 标签或状态

## 附加：List（Issue 看板）

**对应命令**: `/sdd list [project_url]`

**步骤**:
1. 确定项目：从参数 URL 或 git remote 获取项目路径
2. 调用 `list-project-issues` 获取所有 opened issue
3. 筛选带 `workflow::` 标签的 issue，按工作流阶段分组（开发中 > 测试验收 > 已规划 > 待办）
4. 展示分组结果，每个 issue 显示编号、标题、指派人

**输出**: 按工作流阶段分组的 issue 看板

**注意**: 只读操作，不修改任何内容

## 附加：Template（模板输出）

**对应命令**: `/sdd template`

**步骤**:
1. 读取 `templates/issue-spec-template.md`
2. 输出模板内容，供用户创建新 issue 时参考
