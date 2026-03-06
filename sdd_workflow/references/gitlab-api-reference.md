# GitLab API 端点速查

本文件供 Claude 在 SDD 工作流中快速查阅 API 端点和参数。

## 基础信息

- Base URL: `{GITLAB_URL}/api/v4`
- 认证: `PRIVATE-TOKEN: {token}` header
- 编码: project path 需要 URL encode（`/` → `%2F`）

## Issues

| 操作 | 方法 | 端点 |
|------|------|------|
| 获取 issue | GET | `/projects/:id/issues/:iid` |
| 获取 issue 列表 | GET | `/projects/:id/issues?state=opened&labels=<labels>` |
| 创建 issue | POST | `/projects/:id/issues` body: `{title, description, labels}` |
| 更新 issue | PUT | `/projects/:id/issues/:iid` body: `{description}` 或 `{add_labels}` 等 |
| 关闭 issue | PUT | `/projects/:id/issues/:iid` body: `{state_event: "close"}` |
| 重新打开 issue | PUT | `/projects/:id/issues/:iid` body: `{state_event: "reopen"}` |
| 设置指派人 | PUT | `/projects/:id/issues/:iid` body: `{assignee_ids: [id, ...]}` 或 `[]` 清空 |
| 获取 issue 评论 | GET | `/projects/:id/issues/:iid/notes?sort=asc` |
| 添加 issue 评论 | POST | `/projects/:id/issues/:iid/notes` body: `{body}` |
| 获取关联 MR | GET | `/projects/:id/issues/:iid/closed_by` |

### Issue 字段

```json
{
  "iid": 8,
  "title": "...",
  "description": "markdown 内容",
  "state": "opened",
  "labels": ["workflow::start", "workflow::backlog"],
  "assignees": [{"username": "..."}],
  "web_url": "https://..."
}
```

### 创建 Issue

```
POST /projects/:id/issues
Body: {"title": "...", "description": "markdown 内容", "labels": "workflow::backlog"}
```

### 更新标签

```
PUT /projects/:id/issues/:iid
Body: {"add_labels": "workflow::in dev"}
```

### 更新 Issue 描述

```
PUT /projects/:id/issues/:iid
Body: {"description": "新的 markdown 描述内容"}
```

对应脚本：`bash gitlab-api.sh update-issue-description <project_id> <issue_iid> <description>`

## Merge Requests

| 操作 | 方法 | 端点 |
|------|------|------|
| 创建 MR | POST | `/projects/:id/merge_requests` |
| 获取 MR | GET | `/projects/:id/merge_requests/:iid` |
| 获取 MR 变更 | GET | `/projects/:id/merge_requests/:iid/changes` |
| 按分支查询 MR | GET | `/projects/:id/merge_requests?source_branch=&target_branch=&state=opened` |
| 添加 MR 评论 | POST | `/projects/:id/merge_requests/:iid/notes` body: `{body}` |
| 获取 MR 评论 | GET | `/projects/:id/merge_requests/:iid/notes?sort=desc&per_page=100` |
| 更新 MR 评论 | PUT | `/projects/:id/merge_requests/:iid/notes/:note_id` body: `{body}` |
| 设置 MR reviewer | PUT | `/projects/:id/merge_requests/:iid` body: `{reviewer_ids: [id]}` |

### 创建 MR Body

```json
{
  "source_branch": "dev-alice-8",
  "target_branch": "dev",
  "title": "Resolve \"issue title\"",
  "description": "...",
  "remove_source_branch": true,
  "squash": true
}
```

## Projects & Users

| 操作 | 方法 | 端点 |
|------|------|------|
| 获取项目 | GET | `/projects/:id` 或 `/projects/:encoded_path` |
| 获取成员 | GET | `/projects/:id/members/all?per_page=100` |
| 搜索成员 | GET | `/projects/:id/members/all?search=:username&per_page=20` |

### 从路径获取项目

```bash
# project_path = "mygroup/myproject"
# encoded = "mygroup%2Fmyproject"
GET /projects/mygroup%2Fmyproject
```

## gitlab-api.sh 速查

| 命令 | 说明 |
|------|------|
| `reopen-issue <pid> <iid>` | 重新打开已关闭的 issue |
| `list-project-issues <pid> [state] [labels]` | 获取项目 issue 列表（可选按状态和标签过滤） |
| `update-issue-assignees <pid> <iid> <user_ids>` | 设置指派人（逗号分隔 user id，传空字符串清空） |
| `list-project-mrs <pid> <source> <target> [state]` | 按分支查询 MR 列表 |
| `get-mr-notes <pid> <mr_iid>` | 获取 MR 评论列表 |
| `update-mr-note <pid> <mr_iid> <note_id> <body>` | 更新 MR 评论 |

## MR Helper

| 操作 | 命令 |
|------|------|
| 创建 MR | `mr-helper.sh create <project_id> <issue_iid> <title> <source> <target> [desc_file] [rm_branch]` |
| 批量通知 reviewer | `mr-helper.sh batch-notify-reviewers <project_id> <mr_iid> <user1,user2,...>` |

`batch-notify-reviewers` 一次性解析所有用户名、设置 reviewer、发送单条 @mention 评论。

## 常用分页参数

- `per_page=100` — 每页条数（最大 100）
- `page=1` — 页码
- `sort=asc|desc` — 排序方向
