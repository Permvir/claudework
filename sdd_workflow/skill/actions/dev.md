# Action: dev

创建分支、开发代码、编写测试。

## 命令格式

```
/sdd dev <issue_url>
/sdd dev --type=hotfix <issue_url>
/sdd dev --type=feature <issue_url>
```

## 步骤

1. **解析 issue**：同 read 步骤 1-4，获取 issue 信息和结构化需求

2. **确定分支类型**：
   - 如果用户指定了 `--type=hotfix` 或 `--type=feature`，使用指定类型
   - 否则默认为 `dev` 类型
   - 向用户确认分支类型和即将执行的操作

3. **加载配置，获取分支参数**：直接调用 config.sh 子命令（每个命令都是独立 bash 进程，内部自动完成配置加载和分支检测）：
   ```bash
   BRANCH_NAME=$(bash <skill_dir>/scripts/config.sh --get-branch-name "<type>" "<issue_iid>")
   BASE_BRANCH=$(bash <skill_dir>/scripts/config.sh --get-base-branch "<type>")
   ```
   - `dev` 类型 → 基线由自动检测决定，分支名前缀跟随基线（有 dev 时为 `dev-ocean-8`，无 dev 回退 master 时为 `master-ocean-8`）
   - `hotfix` 类型 → 基线 `master`，分支名如 `hotfix-ocean-8`
   - `feature` 类型 → 基线 `master`，分支名如 `feature-ocean-8`

4. **创建开发分支**：
   ```bash
   git fetch origin
   ```
   - 先检查分支是否已存在：`git rev-parse --verify <branch_name> 2>/dev/null`
   - 如果分支已存在，提示用户选择：
     - **切换到现有分支**：`git checkout <branch_name>`
     - **中止操作**：退出，由用户决定后续处理（如删除旧分支后重试）
   - 如果分支不存在，正常创建：`git checkout -b <branch_name> origin/<base_branch>`

5. **更新 issue 标签**：运行 `bash <skill_dir>/scripts/gitlab-api.sh update-issue-labels <project_id> <issue_iid> "workflow::in dev"`
   > 注：所有标签均为 `workflow::` scoped label，添加新标签时 GitLab 自动移除同 scope 的旧标签，无需手动指定 remove_labels。

6. **向用户展示分支信息**：
   ```
   分支已创建：
     类型: dev
     分支名: dev-ocean-8
     基线: origin/dev
     MR 目标: dev
   ```

7. **获取关联 Issue 上下文**（可选）：如果解析结果中包含 `related_issues_list`，在开始编码前获取每个关联 issue 的描述（特别是需求和技术备注章节），理解跨仓库的接口约定、数据格式等依赖关系。将关联 issue 的关键信息作为开发参考，但代码修改仅限当前仓库。
   - 对每个关联 URL，调用 `bash <skill_dir>/scripts/gitlab-api.sh parse-issue-url` + `resolve-project-id` + `get-issue` 获取 issue 详情
   - 将关联 issue 的需求和技术备注展示给用户，作为额外上下文

8. **开始开发**：
   - 根据需求和验收标准，编写代码实现
   - 编写或更新相关测试
   - 运行测试确保通过
   - 提交代码（commit message 引用 issue: `refs #{issue_iid}`）

9. **推送分支**（可选）：
   - 开发结束或需要备份时推送：`git push -u origin <branch_name>`
   - 推送可延迟到 `/sdd submit` 时执行（submit 步骤 4 会自动推送未推送的分支）
   - 如果用户明确要求推送，或代码已全部提交完毕，则立即推送

## 开发原则

- 每次提交都应该是可编译/可运行的
- commit message 要清晰说明变更内容
- 优先满足验收标准中列出的条件
