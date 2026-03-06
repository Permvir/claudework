<!-- Purpose: Add a structured progress/status comment to the GitLab issue. -->
# Action: update

向 GitLab Issue 评论区添加一条结构化评论。

## 步骤

1. **解析 issue URL**：获取 project_id 和 issue_iid
2. **交互式收集信息**：向用户提问"请问要记录哪些内容？可以包括：已完成事项、关键决策、待办事项等。"，等待用户用自然语言回复
3. **格式化评论**：将用户回复按 `templates/dev-notes-template.md` 模板格式化，自动填入日期，{phase} 从 issue 当前的 workflow 标签推断（如 workflow::in dev → "开发中"，workflow::evaluation → "测试验收中"），无 workflow 标签时填"进行中"。将内容拆分到对应章节（完成内容、关键决策、待办事项）
4. **并发提示**：发布评论前可重新 get-issue 获取最新 updated_at，如果 issue 在操作期间被外部修改，提示用户（update 是追加评论，风险较低，仅提示不阻塞）
5. **添加评论**：运行 `bash <skill_dir>/scripts/gitlab-api.sh add-issue-note <project_id> <issue_iid> "<note_body>"`
6. **确认完成**：告知用户评论已添加到 Issue，展示评论内容摘要

## 交互示例

```
用户: /sdd update 8

Claude: 请问要记录哪些内容？可以包括：已完成事项、关键决策、待办事项等。

用户: 完成了登录接口开发和单元测试，决定 token 过期时间设为 24h，还要补集成测试

Claude: 已添加评论到 Issue #8 ✓
        完成内容：登录接口开发、单元测试
        关键决策：Token 过期时间 24h
        待办：补充集成测试
```

## Prompt 用法

用户回复不限于手动输入，也可以让 Claude 从当前会话上下文自动提炼：
- **上下文自动提炼**（推荐）：`把完成的功能和对话的上下文帮我记录一下`、`根据我们这次对话，帮我总结今天做了什么`
- **指定角度提炼**：`重点记录一下我们刚才做的技术决策`、`记录一下当前进度和下一步计划`
- **上下文 + 手动追加**：`帮我总结今天的对话，另外待办事项加上：明天还要补集成测试`
- **纯手动输入**：直接描述内容让 Claude 格式化
