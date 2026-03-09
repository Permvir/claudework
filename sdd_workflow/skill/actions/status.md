# Action: status

展示当前 SDD 工作状态概览。

## 步骤

1. **获取当前分支信息**：
   - 运行 `git branch --show-current` 获取当前分支名
   - `source <skill_dir>/scripts/config.sh` 加载配置，获取 `DEVELOPER_NAME`
   - 从分支名解析分支类型和 issue 编号（需包含开发者名称以收紧匹配）：
     - `hotfix-{DEVELOPER_NAME}-<数字>` → hotfix 类型
     - `feature-{DEVELOPER_NAME}-<数字>` → feature 类型
     - `*-{DEVELOPER_NAME}-<数字>` → dev 类型（前缀跟随基线分支名）
   - 如果 DEVELOPER_NAME 为空（git config user.name 未设置），降级为宽松匹配：仅通过前缀（hotfix-/feature-/其他）和末尾数字判断分支类型和 issue 编号
   - 如果无法解析（如在 dev/master 分支上，或分支格式不匹配），提示未在 SDD 开发分支上

2. **获取项目信息**：
   - 从 git remote 解析项目路径：`git remote get-url origin`
   - 调用 `bash <skill_dir>/scripts/gitlab-api.sh resolve-project-id "<project_path>"` 获取 project_id

3. **获取 Issue 状态**（如果解析出 issue_iid）：
   - 调用 `bash <skill_dir>/scripts/gitlab-api.sh get-issue <project_id> <issue_iid>` 获取 issue 详情
   - 提取标题、标签（工作流阶段）、状态

4. **获取本地变更统计**：
   - 运行 `git diff --stat` 获取未暂存变更
   - 运行 `git diff --cached --stat` 获取已暂存变更
   - 运行 `git log origin/<base_branch>..HEAD --oneline` 获取本地未推送的提交

5. **展示状态概览**：

   **在 SDD 开发分支上**：
   ```
   ## SDD 状态

   **分支**: dev-ocean-8 (dev 类型)
   **基线**: dev
   **关联 Issue**: #8 — 添加用户头像上传功能
   **工作流阶段**: workflow::in dev

   **本地变更**:
   - 未暂存: 3 files changed
   - 已暂存: 1 file changed
   - 未推送提交: 2 commits
   ```

   **不在 SDD 开发分支上**：
   ```
   ## SDD 状态

   **当前分支**: dev

   ℹ️ 未在 SDD 开发分支上。使用 `/sdd dev <issue_url>` 开始开发。
   ```

## 注意

- status 是只读操作，不修改任何内容
- 不改变 issue 标签状态
