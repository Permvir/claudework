# Action: label

为 issue 添加或移除标签。

## 命令格式

```
/sdd label --label="<labels>" [--remove="<labels>"] [<issue_url>]
/sdd label --remove="<labels>" [<issue_url>]
```

例如：
```
/sdd label --label="bug::functional,priority::high" <issue_url>
/sdd label --remove="bug::functional" <issue_url>
/sdd label --label="priority::high" --remove="priority::low" <issue_url>
```

**参数说明**：
- `--label="..."` — 要添加的标签，多个标签用逗号分隔，支持含空格和 `::` 的标签名
- `--remove="..."` — 要移除的标签，多个标签用逗号分隔
- `<issue_url>` — 可选，省略时从会话上下文获取

## 步骤

1. **解析参数**：从命令中提取 `--label` 和 `--remove` 的值，以及可选的 issue URL
   - 以引号内逗号分割标签列表（注意标签名可能含 `::` 和空格）
   - 至少需要 `--label` 或 `--remove` 其中之一，否则报错提示命令格式不正确
   - 标签参数值为空（如 `--label=""`）时，报错提示命令格式不正确

2. **校验参数**：
   - 如果同一个标签同时出现在 `--label` 和 `--remove` 列表中，从两个列表中移除该标签（最终对此标签无操作），并提示用户

3. **解析 issue**：同 read 步骤 1-4，获取 issue 信息
   - 记录操作前的标签列表（从 issue 详情的 `labels` 字段获取），供后续比对

4. **调用 API 更新标签**：
   - 有 `--label` 时：运行 `bash <skill_dir>/scripts/gitlab-api.sh update-issue-labels <project_id> <issue_iid> "<add_labels>" ""`
   - 有 `--remove` 时：运行 `bash <skill_dir>/scripts/gitlab-api.sh update-issue-labels <project_id> <issue_iid> "" "<remove_labels>"`
   - 同时有 `--label` 和 `--remove` 时：运行 `bash <skill_dir>/scripts/gitlab-api.sh update-issue-labels <project_id> <issue_iid> "<add_labels>" "<remove_labels>"`

5. **检查移除结果**：如果用户传了 `--remove` 参数：
   - 对比 API 返回的标签列表与操作前的标签列表
   - 若某个 `--remove` 中指定的标签在操作前后均不存在于 issue 标签中，提示用户：`⚠️ 标签 "<label>" 不存在，无需移除`

6. **展示结果**：输出操作后 issue 的完整标签列表

## 注意

- `workflow::` scoped label 被 GitLab 自动管理（同 scope 只保留一个），不建议通过此命令直接操作 `workflow::` 标签，应使用对应的 SDD 工作流命令
- label 操作不改变 issue 的 `workflow::` 标签状态
