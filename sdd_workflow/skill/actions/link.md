# Action: link

向指定 issue 的「关联 Issue」栏目追加一条关联 URL。

## 命令格式

```
/sdd link <related_url> [desc]
/sdd link --issue=N <related_url> [desc]
/sdd link --issue=<issue_url> <related_url> [desc]
```

**识别规则**：action 为 `link` 时，`--issue=N` 或 `--issue=<url>` 选项指定当前 issue（省略则从会话上下文获取）。第一个非选项的 `http://` 或 `https://` 开头参数为 related issue URL，其后所有文本拼接为 description。

**示例**：
```
/sdd link http://gitlab.example.com/mygroup/backend/-/issues/12 后端 API 接口定义
/sdd link --issue=8 http://gitlab.example.com/mygroup/frontend/-/issues/5
/sdd link http://gitlab.example.com/mygroup/common/-/issues/3 公共组件库变更
```

## 步骤

1. **确定当前 issue**：从 `--issue=N` 选项或会话上下文获取 project_id 和 issue_iid。如果会话中没有 issue 上下文且未通过 `--issue` 指定，提示用户提供 issue URL
2. **获取当前 issue 描述**：运行 `bash <skill_dir>/scripts/gitlab-api.sh get-issue <project_id> <issue_iid>`，提取 `description` 字段
3. **验证关联 URL**：对 `<related_issue_url>` 调用 `bash <skill_dir>/scripts/gitlab-api.sh parse-issue-url "<url>"` 确认是合法的 issue URL，然后调用 `resolve-project-id` + `get-issue` 获取关联 issue 的标题和状态，验证 issue 存在
4. **检查重复**：在当前 description 中搜索该 URL，如果已存在则提示用户并退出：
   ```
   ⚠️ 该 URL 已存在于关联 Issue 中，无需重复添加。
   ```
5. **定位或创建栏目**：在 description 中查找 `## 关联 Issue` 栏目：
   - **栏目已存在**：在栏目内容末尾（下一个 `## ` 标题之前）追加新行
   - **栏目不存在**：在 `## 技术备注` 之前插入完整的 `## 关联 Issue` 栏目（含注释），再追加新行。如果 `## 技术备注` 也不存在，在 `## 验收标准` 之后插入
6. **追加关联条目**：生成新行格式为：
   - 有 description：`- <url> — <description>`
   - 无 description 但获取到了关联 issue 标题：`- <url> — <related_issue_title>`
   - 无 description 且无法获取标题：`- <url>`
7. **并发保护**：调用 update-issue-description 前，重新 get-issue 获取最新 updated_at，与步骤 2 获取时的值比较。如果不一致，提示用户："issue 在编辑期间被外部修改，是否仍要覆盖？" 展示时间差异。

8. **更新 issue 描述**：运行 `bash <skill_dir>/scripts/gitlab-api.sh update-issue-description <project_id> <issue_iid> "<new_description>"`
9. **展示结果**：
   ```
   ✅ 已添加关联 Issue:
   - Issue #12: 后端 API 接口定义 (opened) — http://gitlab.example.com/mygroup/backend/-/issues/12

   当前关联 Issue 列表：
   - Issue #12: 后端 API 接口定义 (opened)
   - Issue #5: 前端页面适配 (opened)
   ```

## 注意

- link 操作只修改 issue 的 description 字段中的 `## 关联 Issue` 栏目，不影响其他章节
- link 不改变 issue 的标签状态
- 如果用户没有提供 description，会自动使用关联 issue 的标题作为说明
