# Action: read

获取并解析 issue，展示结构化摘要。

## 步骤

1. **解析 issue URL**：运行 `bash <skill_dir>/scripts/gitlab-api.sh parse-issue-url "<url>"` 提取 `project_path` 和 `issue_iid`
2. **获取 project_id**：运行 `bash <skill_dir>/scripts/gitlab-api.sh resolve-project-id "<project_path>"`
3. **获取 issue 详情**：运行 `bash <skill_dir>/scripts/gitlab-api.sh get-issue <project_id> <issue_iid>`
4. **解析 issue 内容**：将 issue 的 `description` 字段传给 `bash <skill_dir>/scripts/issue-parser.sh`，获取结构化 JSON
5. **获取评论**：运行 `bash <skill_dir>/scripts/gitlab-api.sh get-issue-notes <project_id> <issue_iid>`
6. **展示结构化摘要**：向用户展示以下内容：

```
## Issue #{iid}: {title}
**状态**: {state} | **标签**: {labels}
**指派**: {assignees}

### 背景
{background}

### 需求
1. {requirement_1}
2. {requirement_2}
...

### 验收标准
- [ ] {criteria_1}
- [ ] {criteria_2}
...

### 关联 Issue
（当 related_issues_list 存在时展示，对每个 URL 调用 `bash <skill_dir>/scripts/gitlab-api.sh parse-issue-url` + `resolve-project-id` + `get-issue` 获取标题和状态。**性能优化**：同一 project_path 的多个 issue 复用已解析的 project_id，避免重复调用 resolve-project-id。多个关联 issue 的 API 调用应尽量并行执行。）
- Issue #12: 后端 API 接口定义 (opened) — https://...
- Issue #8: 前端页面适配 (closed) — https://...
（无关联 Issue 时省略此节）

### 技术备注
{technical_notes}

### 规范完整度
✓ 已包含：{sections}
✗ 缺失：{missing_sections}
```

7. 如有评论中包含补充需求，也一并展示

8. **更新 issue 标签**：如果 issue 当前标签包含 `workflow::backlog`，先告知用户：
   ```
   ℹ️ 该 issue 当前处于 workflow::backlog，将自动流转为 workflow::start。如需跳过，请告知。
   ```
   然后运行 `bash <skill_dir>/scripts/gitlab-api.sh update-issue-labels <project_id> <issue_iid> "workflow::start"` 将标签流转为 `workflow::start`。
   > 注：仅当 issue 处于 `workflow::backlog` 状态时才更新，避免将已进入后续阶段的 issue 状态回退。用户可在提示后选择跳过此步骤。
