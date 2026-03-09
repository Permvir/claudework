# Action: reopen

重新打开一个已关闭的 issue，并将标签回退到合适的工作流阶段。

## 命令格式

```
/sdd reopen <issue_url>
/sdd reopen <issue_iid>
/sdd reopen            — 从会话上下文获取 issue
```

## 步骤

1. **解析 issue**：获取 project_id、issue_iid
   - 运行 `bash <skill_dir>/scripts/gitlab-api.sh parse-issue-url "<url>"`
   - 运行 `bash <skill_dir>/scripts/gitlab-api.sh resolve-project-id "<project_path>"`

2. **获取 issue 详情**：运行 `bash <skill_dir>/scripts/gitlab-api.sh get-issue <project_id> <issue_iid>`
   - 检查 issue 当前 `state` 字段
   - 如果 `state == "opened"`，提示用户 "Issue #N 已处于 opened 状态（当前标签: <labels>），无需重开"，退出

3. **确认操作**：向用户展示确认信息：
   ```
   将重新打开 Issue #<iid>: <title>
   当前状态: closed
   重开后标签将更新为: workflow::start

   是否继续？
   ```
   等待用户确认，取消则退出。

4. **重新打开 issue**：
   ```bash
   bash <skill_dir>/scripts/gitlab-api.sh reopen-issue <project_id> <issue_iid>
   ```

5. **更新标签**：将标签更新为 `workflow::start`：
   ```bash
   bash <skill_dir>/scripts/gitlab-api.sh update-issue-labels <project_id> <issue_iid> "workflow::start"
   ```

6. **输出结果**：
   ```
   ✅ Issue #<iid> 已重新打开
   标签已更新为 workflow::start
   <issue_url>

   下一步：使用 /sdd read <url> 查看 issue 详情，或 /sdd dev <url> 开始开发
   ```

## 注意

- 仅对 `state == "closed"` 的 issue 执行操作
- 重开后标签统一设为 `workflow::start`，如需其他阶段标签，执行对应 action（如 `/sdd dev` 会自动更新为 `workflow::in dev`）

## 后续操作提醒

重新打开后，根据情况提示用户：
- 如果之前已有开发分支，可用 `git checkout <branch_name>` 切回继续开发
- 如需从头开发，使用 `/sdd dev <url>` 创建新开发分支
- 如需指派给特定成员，使用 `/sdd assign <url> <username>`
