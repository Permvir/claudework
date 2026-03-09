# Action: refine

读取 issue 中的问题和 TODO 标记，讨论后更新 issue 描述。根据上下文有两种模式：

## 模式 A：会话内讨论回写（优先判断）

**触发条件**：当前会话中已执行过 /sdd read 且之后有用户与 Claude 的实质性讨论（不含纯确认性回复）。

在此模式下，Claude 已经掌握了完整的讨论上下文，流程简化为：

1. **获取最新 issue 描述**：
   - 始终重新拉取 issue 详情以获取最新 description，避免因外部修改或会话内其他操作导致数据不一致（API 开销小，可靠性更高）
2. **回顾对话历史**：梳理本次会话中 `read` 之后的所有讨论，提取关键结论和决策
3. **生成更新描述**：基于当前 description 和讨论结论，生成更新后的 description：
   - 将讨论结论融入对应章节（补充需求、细化技术方案、更新验收标准等）
   - 已讨论解决的 `## 问题` 项和 `<!-- TODO: -->` 标记按标准规则处理（见模式 B 第 4 步）
   - 不改动未涉及的章节内容
4. **并发保护**：调用 update-issue-description 前，重新 get-issue 获取最新 updated_at，与步骤 1 获取时的值比较。如果不一致，提示用户："issue 在编辑期间被外部修改，是否仍要覆盖？" 展示时间差异。
5. **展示并更新**：展示 diff 对比，然后直接调用 `update-issue-description` 写回 GitLab（无需用户确认）
6. **更新 issue 标签**：如果 issue 当前标签包含 `workflow::backlog`，运行 `bash <skill_dir>/scripts/gitlab-api.sh update-issue-labels <project_id> <issue_iid> "workflow::start"` 将标签流转为 `workflow::start`

## 模式 B：结构化讨论（标准流程）

**触发条件**：当前会话中没有对同一 issue 的 `read` + 讨论记录，或用户显式指定要从头讨论。

1. **获取并解析 issue**：
   - 同 read 步骤 1-4：解析 URL → 获取 project_id → 获取 issue 详情 → 解析 markdown
   - 额外保存 issue 的原始 `description` 文本，后续更新时需要基于它修改

2. **提取讨论点**：
   - 从解析结果中提取 `questions` / `questions_list`（`## 问题` 专区内容）
   - 从解析结果中提取 `todos`（`<!-- TODO: xxx -->` 内联标记，每项包含 content、line、context）
   - 将两类讨论点合并为统一列表，展示给用户
   - 如果没有找到任何讨论点，提示用户：
     ```
     未找到讨论点。你可以在 issue 中通过以下方式添加：
     1. 在 `## 问题` 章节下列出通用问题
     2. 在正文中使用 `<!-- TODO: 具体疑问 -->` 标注行内问题

     是否要进入自由讨论模式，直接讨论需求？
     ```
     如果用户选择自由讨论，则跳过逐项讨论，直接与用户对话讨论需求。讨论结束后，用户可以选择是否将结论更新到 issue。

3. **逐项讨论**：
   - 先展示讨论点总览：
     ```
     ## 讨论点总览

     ### 来自「问题」章节（{n} 项）
     1. {question_1}
     2. {question_2}

     ### 来自 TODO 标记（{m} 项）
     1. [L{line}] {todo_content}
        上下文：{context_preview}
     2. ...

     共 {n+m} 个讨论点，逐项讨论开始。
     输入「跳过」可跳过当前项，「全部跳过」可跳过所有剩余项。
     ```
   - 然后逐项讨论：展示该讨论点的内容和上下文，Claude 可以读取项目代码来回答技术问题
   - 每项讨论结束后，记录结论（已解决/未解决/修改后的描述）
   - 如果用户回复内容为空或不相关，将该项标记为"未解决"并继续下一项
   - 用户可输入「跳过」跳过当前项，「全部跳过」跳过所有剩余项

4. **生成更新描述**：
   基于原始 description 和讨论结论，生成更新后的 description：
   - **`## 问题` 章节**：
     - 已解决的问题从列表中移除
     - 如果所有问题都已解决，删除整个 `## 问题` 章节
     - 未解决的问题保持原样
   - **`<!-- TODO: xxx -->` 标记**：
     - 已解决的 TODO 标记删除，将结论直接写入原位置（作为正文内容）
     - 未解决的 TODO 标记保持原样
   - 其他章节内容不变

5. **并发保护**：调用 update-issue-description 前，重新 get-issue 获取最新 updated_at，与步骤 1 获取时的值比较。如果不一致，提示用户："issue 在编辑期间被外部修改，是否仍要覆盖？" 展示时间差异。

6. **展示并更新**：
   - 向用户展示更新前后的对比（diff 形式），清晰标出修改点
   - 直接运行 `bash <skill_dir>/scripts/gitlab-api.sh update-issue-description <project_id> <issue_iid> "<new_description>"`（无需等待用户确认）
   - 确认更新成功，展示 issue URL

7. **更新 issue 标签**：如果 issue 当前标签包含 `workflow::backlog`，运行 `bash <skill_dir>/scripts/gitlab-api.sh update-issue-labels <project_id> <issue_iid> "workflow::start"` 将标签流转为 `workflow::start`
   > 注：仅当 issue 处于 `workflow::backlog` 状态时才更新，避免将已进入后续阶段的 issue 状态回退。

## 注意

- 如果 issue 处于 `workflow::backlog` 状态，refine 会自动将标签流转为 `workflow::start`；已处于后续阶段的 issue 标签不受影响
- 可以多次执行 refine，逐步完善需求描述
- refine 操作只修改 issue 的 description 字段，不影响评论
