<!-- Purpose: Auto-generate a structured GitLab issue from a natural language description. -->
# Action: create

根据描述自动生成结构化 issue 并创建到 GitLab。

## 命令格式

```
/sdd create <project_url> <description>
```

例如：
```
/sdd create http://gitlab.example.com/mygroup/myproject 优化sdd这个skill, 提供在命令行创建issue的功能
```

**识别规则**：action 为 `create` 时，action 后的第一个参数为项目 URL（以 `http://` 或 `https://` 开头，且不匹配 `/-/issues/\d+` 模式），其后所有内容作为需求描述。

## 步骤

1. **解析项目 URL**：运行 `bash <skill_dir>/scripts/gitlab-api.sh parse-project-url "<url>"` 提取 `project_path`
2. **获取 project_id**：运行 `bash <skill_dir>/scripts/gitlab-api.sh resolve-project-id "<project_path>"`
3. **生成结构化 issue**：根据用户描述文本，结合当前项目上下文（如有），按照 SDD issue 模板（`<skill_dir>/templates/issue-spec-template.md`）生成完整的 issue 内容。

   **获取项目上下文**（可选，有助于生成更精准的 issue）：
   - 读取项目根目录的 README.md 了解项目背景
   - 查看项目目录结构（`ls` 或 `tree`）了解代码组织
   - 如果用户描述涉及特定模块，读取相关代码文件

   生成内容包括：
   - **标题**：从描述中提炼简洁的标题
   - **背景**：补充上下文和动机
   - **需求**：拆解为具体的功能需求列表
   - **验收标准**：可验证的完成条件
   - **关联 Issue**：如用户提到了相关 issue 则填写 URL，否则保留空栏目和注释
   - **技术备注**：如能从项目上下文推断则填写，否则留空
   - **测试计划**：可选，如能从需求推断测试要点则填写，否则留空
   - **Reviewer**：必须包含此章节，内容为 `<!-- 指定 MR 的 Reviewer（GitLab 用户名），多人用逗号分隔 -->` 和 `<!-- 提交 MR 时 SDD 会自动设置 Reviewer 并 @通知 -->`，后跟占位符 `@username`，提示用户填写
   - **问题**：可选，如生成过程中有不确定的点可列出；即使为空也保留章节和注释，方便开发者后续主动补充问题
4. **规范完整度检查**：将生成的 description 通过 `echo "<description>" | bash <skill_dir>/scripts/issue-parser.sh` 解析，检查 `_completeness.missing_sections` 字段：
   - 必填章节：`background`（背景）、`requirements`（需求）、`acceptance_criteria`（验收标准）
   - 如有缺失，提示用户：
     ```
     ⚠️ 生成的 issue 缺少以下必填章节：{missing_sections}
     是否要补充后再创建，还是直接创建？
     ```
   - 用户选择补充则回到步骤 3 完善内容，选择继续则直接进入步骤 5
5. **创建 issue**：直接运行 `bash <skill_dir>/scripts/gitlab-api.sh create-issue <project_id> "<title>" "<description>" "workflow::backlog"`，无需等待用户确认
6. **返回结果**：输出创建成功的 issue URL（从 API 返回的 `web_url` 字段获取），并展示生成的 issue 标题和正文摘要供用户参考

## 注意

- 生成的 issue 自动添加 `workflow::backlog` 标签
- 创建完成后可直接使用 `/sdd read <issue_url>` 查看，或 `/sdd dev <issue_url>` 开始开发
- 如果用户对已创建的 issue 不满意，可使用 `/sdd refine <issue_url>` 来修改内容
