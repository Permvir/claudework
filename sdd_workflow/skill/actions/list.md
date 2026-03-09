# Action: list

列出当前项目中带 `workflow::` 标签的 issue，按工作流阶段分组展示。

## 命令格式

```
/sdd list
/sdd list <project_url>
```

## 步骤

1. **确定项目**：
   - 如果提供了 `<project_url>`，运行 `bash <skill_dir>/scripts/gitlab-api.sh parse-project-url "<url>"` 提取 `project_path`
   - 如果省略，从当前目录的 git remote 自动解析项目路径：`git remote get-url origin`
   - 运行 `bash <skill_dir>/scripts/gitlab-api.sh resolve-project-id "<project_path>"` 获取 project_id

2. **获取 issue 列表**：运行 `bash <skill_dir>/scripts/gitlab-api.sh list-project-issues <project_id> opened`
   - 获取所有 opened 状态的 issue

3. **筛选和分组**：从返回的 issue 列表中，筛选带 `workflow::` 标签的 issue，按工作流阶段分组：
   - `workflow::backlog` — 待办事项
   - `workflow::start` — 已规划
   - `workflow::in dev` — 开发中
   - `workflow::evaluation` — 测试验收中
   - `workflow::done` — 已完成（通常已关闭，opened 中较少出现）

   不含任何 `workflow::` 标签的 issue 归入"未分类"组。

4. **展示结果**：

   ```
   ## SDD Issue 看板 — {project_name}

   ### 开发中 (workflow::in dev) — {n} 个
   - [#{iid}]({web_url}) {title} — @{assignee}
   - [#{iid}]({web_url}) {title} — @{assignee}

   ### 测试验收中 (workflow::evaluation) — {n} 个
   - [#{iid}]({web_url}) {title} — @{assignee}

   ### 已规划 (workflow::start) — {n} 个
   - [#{iid}]({web_url}) {title} — @{assignee}

   ### 待办事项 (workflow::backlog) — {n} 个
   - [#{iid}]({web_url}) {title}

   ### 未分类 — {n} 个
   - [#{iid}]({web_url}) {title} — @{assignee}

   ---
   共 {total} 个活跃 issue
   ```

   展示顺序按工作流阶段从后往前（开发中 > 测试 > 已规划 > 待办 > 未分类），优先展示最需要关注的 issue。每个 issue 显示带链接的编号、标题、指派人（如有），`web_url` 从 API 返回的 `web_url` 字段获取。空分组不展示（包括未分类组）。

## 注意

- list 是只读操作，不修改任何内容
- 不改变 issue 标签状态
- 仅展示 opened 状态的 issue（已关闭的不展示）
