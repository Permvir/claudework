# Action: assign

将 issue 指派给一个或多个项目成员，支持按用户名模糊搜索。

## 命令格式

```
/sdd assign <issue_url> <username1> [username2 ...]
/sdd assign <issue_iid> <username1> [username2 ...]
/sdd assign <username1> [username2 ...]  — 从会话上下文获取 issue
/sdd assign --clear                      — 清空指派人
```

## 步骤

1. **解析 issue**：获取 project_id、issue_iid（同 read 步骤 1-2）

2. **获取 issue 详情**：运行 `bash <skill_dir>/scripts/gitlab-api.sh get-issue <project_id> <issue_iid>`，展示当前指派人（`assignees` 字段）

3. **处理 `--clear` 选项**：
   - `--clear` 与用户名互斥，如果同时传入 `--clear` 和用户名，报错提示："--clear 与用户名不能同时使用，请单独使用 --clear 清空指派人，或指定用户名设置指派人"，然后退出
   - 如果仅传入 `--clear`，跳转到步骤 5，以空 user_ids 调用 API 清空指派人

4. **解析用户名，获取 user_id**：
   - 对每个用户名调用 `bash <skill_dir>/scripts/gitlab-api.sh resolve-user-id <project_id> <username>`
   - 如果某个用户名不存在，提示用户并跳过该用户名
   - 如果所有用户名均无效，报错退出

5. **设置指派人**：
   ```bash
   bash <skill_dir>/scripts/gitlab-api.sh update-issue-assignees <project_id> <issue_iid> "<user_id1,user_id2,...>"
   ```
   清空时传空字符串 `""`。

6. **输出结果**：
   ```
   ✅ Issue #<iid> 指派人已更新
   指派人: @<username1> @<username2>
   （清空时显示：指派人已清空）
   ```

## 注意

- 此操作会**替换**全部指派人，而非追加
- 用户必须是项目成员（通过 `resolve-user-id` 验证）
- 不修改 issue 标签或状态
