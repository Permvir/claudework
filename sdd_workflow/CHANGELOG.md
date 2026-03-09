# SDD Workflow — 更新日志

## 2026-03-06: 全面 Review — 7 修复 + 2 架构优化

**Bug 修复**

- `refine.md`: Mode A 步骤编号重复（两个 `5.`），第二个改为 `6.`
- `mr-helper.sh`: `batch_notify_reviewers` 中内联 Python 改用 `json-helper.py get-field`

**架构优化**

- `mr-helper.sh`: `generate_mr_description` 大段内联 Python 模板渲染移至 `json-helper.py render-mr-template`，mr-helper.sh 中**零内联 Python**
- `gitlab-api.sh`: `_api()` 函数 curl 的 `2>/dev/null` 改为 `2>"${_curl_stderr_file}"`，失败时输出 `curl: <error>` 到 stderr，保留 SSL/DNS/超时等具体错误信息辅助排查

**一致性**

- `link.md`: 补充并发保护步骤（与 refine/update 保持一致，更新描述前检查 `updated_at`），并修正后续步骤编号（7→8→9）

**UX 改进**

- `list.md`: 输出格式中 issue 编号改为带链接形式 `[#{iid}]({web_url})`，方便在终端中点击跳转

**json-helper.py**

- 新增 `render-mr-template` action：渲染 MR 描述模板，替代 mr-helper.sh 中的内联 Python
- 新增 `get-field` action：从 stdin JSON 对象中提取单个字段值
- 移除 `extract-project-info`（已无调用方，功能与 `resolve-project` 完全重复）

**测试**

- 新增 `TestRenderMrTemplate`（5 用例）和 `TestGetField`（5 用例），总计 75 个 Python 测试用例

## 2026-03-06: 全面 Review — 16 修复 + 3 架构优化

**文档一致性修复**

- `issue-spec-template.md`: Reviewer 字段说明改为"写不写 @ 都行，解析器会自动处理"
- `sample-issue.md`: Reviewer 示例去除 `@` 前缀，与模板一致
- `workflow-guide.md`: read action 标签更新改为"提示用户确认后更新"
- `refine.md`: Mode A 触发条件从"对话轮次 ≥ 2"改为更精确的"实质性讨论"描述
- `issue-spec-template.md`: 在问题章节前添加"开发记录"章节占位
- `update.md` + `dev-notes-template.md`: 明确 `{phase}` 占位符来源（从 workflow 标签推断）
- `list.md`: 添加"未分类"分组（不含 workflow 标签的 issue）

**Bug 修复**

- `submit.md`: 补全 MR1 创建失败时的中止逻辑（不创建 MR2，不设置 Reviewer，不更新标签）
- `done.md`: 分支删除从 `-d || -D` 改为失败时展示未合入提交并等待用户确认
- `config.sh`: `no_proxy` 追加前检查是否已包含，避免重复 source 导致重复追加
- `install.sh`: `find | sort | xargs cat` 改为 `-print0 | sort -z | xargs -0`，修复文件名含空格时 hash 计算错误

**架构优化**

- `json-helper.py`: 从 2 个 action 扩展到 13 个（新增 url-encode、parse-url、resolve-project、find-member、issue-payload、labels-payload、description-payload、mr-payload、ids-payload、merge-arrays、extract-project-info），消除 gitlab-api.sh 中所有内联 Python
- `gitlab-api.sh`: 新增错误码规范（SDD_EXIT_OK=0, ERROR=1, CONFIG=2, API=3, VALIDATION=4, GIT=5），所有 exit/return 使用语义化常量
- `gitlab-api.sh`: 所有 URL 解析、JSON payload 生成、成员查找、分页合并统一调用 json-helper.py
- `.claude/settings.local.json`: `Bash(git *)` 收窄为 18 条具体命令白名单

**健壮性改进**

- `refine.md`: Mode A 和 Mode B 更新 issue 描述前新增并发保护（检查 updated_at）
- `update.md`: 发布评论前增加并发修改提示
- `_api_paginated`: 移除 `2>/dev/null`，分页合并前添加 JSON 格式假设注释

**测试**

- 新增 `tests/` 目录，含 4 个测试文件和 6 个 fixture
- `test_json_helper.py`: 66 个用例覆盖全部 13 个 action
- `test_issue_parser.py`: 16 个用例覆盖章节解析、代码块、TODO、Reviewer、完整度检查
- `test_config_functions.sh`: 15 个用例覆盖分支函数、no_proxy 去重、错误码
- `test_url_parsing.sh`: 16 个用例覆盖 URL 解析和退出码
- `install.sh`: hash 计算排除 tests/ 目录，测试仅开发时使用

## 2026-03-06: 全面 Review 优化（第三批）

**Bug 修复**

- `gitlab-api.sh`: `_url_encode` 从纯 bash 实现改为 python3 `urllib.parse.quote`，修复多字节 UTF-8 字符（如中文项目路径、用户名）编码错误的问题
- `gitlab-api.sh`: `_api_paginated` 修复 JSON 合并异常时 `a` 变量引用不安全的问题，重构为收集全部分页后一次性合并，单页场景无需启动 python3

**新功能**

- `list` action: `/sdd list` 列出项目中带 `workflow::` 标签的 issue，按工作流阶段分组展示（开发中 > 测试验收 > 已规划 > 待办）
- `gitlab-api.sh`: 新增 `list-project-issues` API，支持按状态和标签过滤

**健壮性改进**

- `gitlab-api.sh`: 新增 curl 版本检测，`--fail-with-body` 在 curl < 7.76.0 时自动降级为 `--fail`，避免旧版 curl 报错
- `submit`: 新增步骤 4 检查工作目录未提交变更，提示用户先 commit 或 stash 后再 submit
- `review`: MR code review 新增大 diff 处理策略（跳过文件类型、单文件 500 行阈值、总量 2000 行阈值）
- `config.sh`: 缓存临时文件从 `$$` 改为 `mktemp`，避免并发写入竞争
- `config.sh`: 新增 `_SDD_CONFIG_LOADED` 防重复加载机制，高频 source 时跳过重复检测
- `config.sh`: 环境变量优先级高于配置文件（GITLAB_URL/GITLAB_TOKEN/DEVELOPER_NAME），CI/CD 场景更可靠

**代码质量**

- `issue-parser.sh`: 移除临时文件（mktemp/trap/cp），python 直接从 stdin 或文件参数读取
- `config-template.sh`: 使用纯值赋值替代 `${VAR:-default}` 语法，用户编辑更清晰；环境变量覆盖由 config.sh 统一处理
- `install.sh`: 新增版本检测（内容 hash），无变更时跳过安装；区分"首次安装"和"更新安装"提示
- `SKILL.md`: `<skill_dir>` 定义从文末"重要提示"提升到文件开头，更醒目

## 2026-03-05: 全面 Review 优化（第二批）

**新功能**

- `reopen` action: `/sdd reopen` 重新打开已关闭的 issue，标签回退为 `workflow::start`
- `assign` action: `/sdd assign <username ...>` 将 issue 指派给项目成员，`--clear` 清空指派人

**功能性修复**

- `gitlab-api.sh`: 新增 `reopen-issue`、`update-issue-assignees` API
- `dev`: 步骤 9 推送改为可选，推送可延迟到 `submit` 时执行

**代码质量**

- `scripts/json-helper.py`: 新增 JSON 操作辅助脚本（`body-payload`、`count`），消除 `add_issue_note`、`add_mr_note`、`update_mr_note`、`get_issue_notes`、`get_project_members` 中重复的 python3 一行式

## 2026-03-05: 全面 Review 优化（第一批）

**功能性修复（高优先级）**

- `submit`: 创建 MR 前检查已有 opened MR，避免重复创建（新增 `list-project-mrs` API）
- `config.sh`: `get_primary_mr_target()` 类型感知 — hotfix/feature 返回 `master`，dev 返回 `DEFAULT_BASE_BRANCH`
- `issue-parser.sh`: 空白内容章节不再通过完整性检查
- `read`: 标签 backlog → start 流转前先通知用户，给用户跳过机会

**健壮性改进（中优先级）**

- `gitlab-api.sh`: `get_issue_notes` / `get_project_members` 返回 >= 100 条时输出分页截断警告
- `review`: MR review 评论先查已有再更新，避免重复评论（新增 `get-mr-notes` + `update-mr-note` API）
- `status`: 分支名解析收紧，要求包含 `DEVELOPER_NAME`，避免误匹配非 SDD 分支
- `config.sh`: 分支缓存从 `/tmp` 迁移到 `~/.cache/sdd/`，不被系统清理
- `config.sh`: hostname 提取从 python3 改为 bash 字符串操作，消除每次 source 的 python3 启动开销
- `mr-helper.sh`: 模板改为传文件路径，Python 内部读取，避免大模板作为 argv 传递
- `gitlab-api.sh`: `parse_issue_url` / `parse_mr_url` 增加 GITLAB_URL 主机名校验

**锦上添花（低优先级）**

- `gitlab-api.sh`: `_api` 新增 1 次重试（仅 5xx/超时），间隔 2 秒
- `done`: `git branch -d` 失败时自动降级为 `-D`（squash merge 后 -d 会失败）
- `refine`: 模式 A 简化为始终重新拉取 issue 最新描述
- `config.sh`: `BRANCH_PATTERN` 弃用警告加上具体移除日期（2026-06-01）
- `issue-parser.sh`: `_completeness.total_sections` 排除派生字段（`*_list`、`todos`），仅计真实章节

## 2026-03-05: 架构优化 + Bug 修复 + 新功能

**架构：SKILL.md 拆分为路由 + 按需加载**

SKILL.md 从 710 行精简为 ~120 行的路由表，各 action 的详细执行步骤拆分到 `skill/actions/*.md`，执行时按需读取。减少每次 `/sdd` 调用约 2/3 的 context 消耗。

**Bug 修复**

- `issue-parser.sh`: 修复 Reviewer 解析会将 HTML 注释内容误解析为用户名的问题（先剥离注释再提取用户名）
- `issue-parser.sh`: 关联 Issue URL 正则收紧为 `https?://` 前缀匹配，避免误匹配非 URL 文本
- `workflow-guide.md`: 修复 submit 描述与 SKILL.md 不一致（对齐为自动创建 MR）；refine mode B 确认行为对齐（无需用户确认）

**新功能**

- `status` action: `/sdd status` 展示当前工作状态（分支、关联 issue、工作流阶段、本地变更）
- `done` action 新增本地分支清理：关闭 issue 后提示切回基线分支并删除本地开发分支
- `mr-helper.sh` 新增 `batch-notify-reviewers`: 一次性设置所有 reviewer 并发送单条 @mention 评论（替代逐个通知）
- `install.sh` 新增 `--uninstall` 选项

**脚本质量改进**

- `gitlab-api.sh`: `resolve-project-id` 和 `resolve-user-id` 增加 API 调用失败检查，避免 curl 错误被 pipe 到 python3 产生不可读报错
- `config.sh`: 旧版 `BRANCH_PATTERN` 兼容代码添加弃用警告
- `install.sh`: 新增 curl 版本检查（`--fail-with-body` 需要 ≥7.76.0）；安装时同步部署 `actions/` 目录

**文档完善**

- `SKILL.md`: 新增「错误处理」章节，指导 API 调用失败时的行为
- `features.md`: 更新文件结构、新增 status/uninstall 文档
- `workflow-guide.md`: 全面对齐 SKILL.md，新增 status 和 done 分支清理说明

## 2026-03-05: 命令格式统一 + 质量优化

**命令格式统一为 Action-First**

所有命令从 `/sdd <url> <action>` 改为 `/sdd <action> <url>`，符合 CLI 惯例（如 git、docker）。`link` 的当前 issue 指定方式从位置参数改为 `--issue=N` 选项。

**脚本质量修复**

- `gitlab-api.sh`: `resolve-user-id` 的 search 参数增加 URL 编码，修复含特殊字符用户名的查询失败
- `mr-helper.sh`: reviewer 设置失败时输出 stderr 日志（替代静默 `|| true`），便于排查
- `config.sh`: `no_proxy` 拼接前增加 `GITLAB_URL` 非空检查；分支自动检测失败时输出 stderr 警告
- `issue-parser.sh`: trap 在 mktemp 之前注册，消除清理盲区

**文档完善**

- `SKILL.md`: heredoc 命令构造规范从文末"重要提示"提升为独立的"命令格式规范"章节；`update` action 补充 Prompt 用法说明；上下文优先级中"最近一次操作"定义更精确
- `workflow-guide.md`: 补充缺失的 `done` action 文档
- `gitlab-api-reference.md`: 补充 `close-issue`、`list-issue-related-mrs`、`set-mr-reviewers`、`resolve-user-id` 等缺失端点

**其他改进**

- `install.sh`: 安装时对 shell 脚本执行 `bash -n` 语法检查，损坏脚本不再静默安装；配置文件创建提示含敏感凭证说明；命令示例更新为 action-first 格式
- `mr-description-template.md`: 添加模板变量注释说明
- `dev-notes-template.md`: 占位符改为多条目格式，消除歧义
