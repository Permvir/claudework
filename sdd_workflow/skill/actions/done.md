<!-- Purpose: Close the issue after MR merge, update label to workflow::done. -->
# Action: done

MR 合入后关闭 issue，自动更新标签为 `workflow::done`。

## 步骤

1. **解析 issue URL**：获取 project_id 和 issue_iid（支持省略 URL 从会话上下文获取）

2. **获取关联 MR 列表**：运行 `bash <skill_dir>/scripts/gitlab-api.sh list-issue-related-mrs <project_id> <issue_iid>`
   > 此接口返回 MR 描述中包含 `Closes #N` / `Resolve #N` 引用的 MR 列表，每个 MR 含 `iid`、`title`、`state` 字段
   >
   > ⚠️ 注意：此接口仅识别 MR 描述中的 `Closes #N` 格式引用。如果 MR 描述被手动修改移除了该引用，或使用了其他关联格式（如 `Related to #N`），该 MR 不会出现在结果中。SDD 默认 MR 模板包含 `Closes #{issue_iid}`，正常流程下不受影响。

3. **检查 MR 合入状态**，分三种情况：

   **情况 A：所有关联 MR 均已合入（state = merged）**
   ```
   ✅ 检测到 {n} 个关联 MR，已全部合入：
     - !{iid} {title}（merged）
     - ...
   ```
   直接进入步骤 4。

   **情况 B：存在未合入的 MR（state = opened 或 closed）**
   ```
   ⚠️ 检测到以下关联 MR 尚未合入：
     - !{iid} {title}（{state}）

   是否仍要关闭 issue？
   ```
   等待用户确认，确认后继续步骤 4，取消则退出。

   > **多 MR 场景说明**：hotfix/feature 类型可能创建 2 个 MR（dev + master）。需确认所有关联 MR 的状态，只有全部为 merged 才算情况 A，任一 MR 为 opened/closed 均需提示用户确认。

   **情况 C：无关联 MR**
   ```
   ℹ️ 未检测到关联 MR（issue 描述中无 Closes/Resolve 引用）。

   是否仍要关闭 issue？
   ```
   等待用户确认，确认后继续步骤 4，取消则退出。

4. **更新标签并关闭 issue**：
   ```bash
   bash <skill_dir>/scripts/gitlab-api.sh update-issue-labels <project_id> <issue_iid> "workflow::done"
   bash <skill_dir>/scripts/gitlab-api.sh close-issue <project_id> <issue_iid>
   ```

5. **确认完成**：
   ```
   ✅ Issue #<iid> 已关闭
   标签已更新为 workflow::done
   <issue_url>
   ```

6. **清理本地分支**（可选）：
   - 获取当前分支名：`git branch --show-current`
   - 加载配置获取 DEVELOPER_NAME：`source <skill_dir>/scripts/config.sh`
   - 如果当前分支是 SDD 开发分支（匹配 `*-<developer>-<iid>`、`hotfix-<developer>-<iid>`、`feature-<developer>-<iid>`，且 iid 与当前 issue 一致，且 developer 等于 DEVELOPER_NAME），提示用户：
     ```
     是否切回基线分支并删除本地开发分支 <branch_name>？(y/n)
     ```
   - 用户确认后：
     ```bash
     source <skill_dir>/scripts/config.sh
     BASE=$(get_base_branch "<type>")
     git checkout ${BASE} || { echo "切换到 ${BASE} 失败，跳过分支清理"; exit 0; }
     git pull origin ${BASE}
     git branch -d <branch_name> 2>/dev/null || {
         echo "git branch -d 失败，以下是该分支上可能未合入基线的提交："
         git log --oneline ${BASE}..<branch_name>
         # 提示用户确认后才执行 git branch -D <branch_name>
     }
     ```
     > 注：squash merge 后 `-d` 可能失败（因为 Git 无法识别已合入），此时展示未合入提交列表并等待用户确认后才执行 `-D` 强制删除。先确认 checkout 成功再执行删除，避免在当前分支上删除自身。
   - 用户拒绝或当前不在 SDD 开发分支上，跳过此步骤
