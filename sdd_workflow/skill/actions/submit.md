<!-- Purpose: Push code, review changes locally, auto-create MR(s), and set reviewers. -->
# Action: submit

推送代码、review 变更、自动创建 MR 并设置 reviewer。

## 命令格式

```
/sdd submit <issue_url>
/sdd submit --type=hotfix <issue_url>
```

## 步骤

1. **解析 issue**：获取 project_id、issue_iid、issue title

2. **检测分支类型**：从当前分支名自动识别类型（反向匹配，因为 dev 类型前缀是动态的）：
   - 以 `hotfix-` 开头 → hotfix 类型
   - 以 `feature-` 开头 → feature 类型
   - 其余一律 → dev 类型（dev 类型前缀跟随基线分支名，如 `dev-alice-8` 或 `master-alice-8`）
   - 用户通过 `--type` 显式指定时，以用户指定为准
   - MR 主目标由 `get_primary_mr_target("<type>")` 函数决定：dev 类型返回 `DEFAULT_BASE_BRANCH`，hotfix/feature 类型返回 `master`

3. **确定 MR 目标分支**：
   ```bash
   TARGET_BRANCH=$(bash <skill_dir>/scripts/config.sh --get-mr-target "<type>")
   ```

4. **检查工作目录状态**：
   - 运行 `git status --porcelain` 检查是否有未提交的变更
   - 如果有未提交的变更，提示用户：
     ```
     检测到以下未提交的变更：
     {git status --short 输出}

     请先 commit 或 stash 后再 submit，避免遗漏代码。
     ```
   - 等待用户处理后继续

5. **确保代码已推送**：检查当前分支是否已推送到远程，如未推送则先 `git push -u origin <branch>`

6. **本地 code review**：
   - 先运行 `git diff --stat <target_branch>...<source_branch>` 展示文件变更统计摘要（文件列表 + 增删行数）
   - 再运行 `git diff <target_branch>...<source_branch>` 获取完整 diff 进行审查，检查：
     - 代码质量和可读性
     - 是否满足 issue 中的验收标准
     - 安全性问题
     - 测试覆盖度
   - 向用户展示 review 结果时，采用精简输出：
     - 仅展示有问题文件的相关 diff 片段和具体问题说明
     - 无问题的文件仅在统计摘要中列出，不重复展示 diff
     - 如所有文件均无问题，只展示统计摘要 + "未发现问题"

7. **生成 MR 描述**：
   - 使用 `templates/mr-description-template.md` 模板，填充 issue 信息和变更摘要
   - 将生成的 MR 描述展示给用户

8. **判断 MR 创建计划**：
   - 获取实际基线分支：`DEFAULT_BASE_BRANCH=$(bash <skill_dir>/scripts/config.sh --get-base-branch dev)`
   - 判断是否需要两个 MR：当 `DEFAULT_BASE_BRANCH == "dev"` 且分支类型为 hotfix 或 feature 时，需要创建 2 个 MR（一个合 dev，一个合 master）
   - 其余情况（dev 类型、或无 dev 分支时所有类型）：只需创建 1 个 MR

9. **展示 MR 计划并等待确认**：

   **单个 MR 场景**：
   ```
   ## MR 创建计划

   将自动创建以下 MR：
   - <source_branch> → <target_branch>
   - 标题：Resolve "<issue_title>"

   是否继续？
   ```

   **两个 MR 场景**（hotfix/feature + 有 dev 分支）：
   ```
   ## MR 创建计划

   将自动创建以下 2 个 MR：
   1. <source_branch> → dev
   2. <source_branch> → master

   - 标题：Resolve "<issue_title>"
   - ⚠️ 第一个 MR 将设置为不删除源分支，等两个 MR 都合入后再删除

   是否继续？
   ```

   等待用户确认后继续。

10. **检查已有 MR 并创建**：

   创建 MR 前，先检查是否已存在相同 source → target 的 opened MR：
   ```bash
   bash <skill_dir>/scripts/gitlab-api.sh list-project-mrs <project_id> <source_branch> <target_branch> opened
   ```
   - 如果返回非空列表，说明已有 MR，跳过创建，复用已有 MR 的 `iid` 和 `web_url`，向用户提示"已存在 MR，跳过创建"
   - 如果返回空列表，正常创建 MR

   **单个 MR**：
   ```bash
   bash <skill_dir>/scripts/mr-helper.sh create <project_id> <issue_iid> "<issue_title>" <source_branch> <target_branch>
   ```

   **两个 MR**（hotfix/feature + 有 dev 分支）：
   ```bash
   # MR 1: 合入 dev（第 6 参数空 = 不提供外部描述文件，第 7 参数 "false" = 不删除源分支，等两个 MR 都合入后再删）
   bash <skill_dir>/scripts/mr-helper.sh create <project_id> <issue_iid> "<issue_title>" <source_branch> dev "" "false"

   # MR 2: 合入 master（使用默认配置，由 MR_REMOVE_SOURCE_BRANCH 决定是否删除源分支）
   bash <skill_dir>/scripts/mr-helper.sh create <project_id> <issue_iid> "<issue_title>" <source_branch> master
   ```

   每个 MR 都需独立检查是否已存在。从 API 返回的 JSON 中提取 `iid` 和 `web_url`。

   **MR1 创建失败处理**：如果 MR1（→dev）创建失败，向用户展示错误信息，中止流程（不创建 MR2，不设置 Reviewer，不更新标签），提示用户排查后重试 `/sdd submit`。

   **双 MR 场景异常处理**：如果 MR1（→dev）创建成功但 MR2（→master）创建失败，向用户展示错误信息和已创建的 MR1 URL，提示用户手动创建 MR2 或排查权限问题后重试。流程继续执行后续步骤（设置 Reviewer 等）仅针对已成功创建的 MR。

   **设置 Reviewer**（创建 MR 后立即执行）：
   - 将 issue 的 `description` 传给 `bash <skill_dir>/scripts/issue-parser.sh`，从解析结果的 `reviewer_list` 字段提取 reviewer 用户名列表
   - 将用户名用逗号拼接，对每个已创建的 MR 调用 `bash <skill_dir>/scripts/mr-helper.sh batch-notify-reviewers <project_id> <mr_iid> "<username1,username2,...>"`
   - 一次性设置所有 reviewer 并发送单条 @mention 评论

11. **输出创建结果**：

    ```
    ## MR 创建成功

    - !<mr_iid> <mr_web_url>
    （如有第二个）
    - !<mr_iid_2> <mr_web_url_2>

    ## Review 摘要

    <review 结果>
    ```

12. **更新 issue 标签**：运行 `bash <skill_dir>/scripts/gitlab-api.sh update-issue-labels <project_id> <issue_iid> "workflow::evaluation"`
