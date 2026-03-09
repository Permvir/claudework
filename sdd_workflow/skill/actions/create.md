# Action: create

根据描述自动生成结构化 issue 并创建到 GitLab。

## 命令格式

```
/sdd create <project_url> <description>
/sdd create --type=requirement <project_url> <description>
/sdd create --type=bug <project_url> <error_log>
/sdd create --label="<labels>" <project_url> <description>
/sdd create --type=bug --label="<labels>" <project_url> <error_log>
```

例如：
```
/sdd create http://gitlab.example.com/mygroup/myproject 优化sdd这个skill, 提供在命令行创建issue的功能
/sdd create --type=requirement http://gitlab.example.com/mygroup/myproject 优化登录页性能
/sdd create --type=bug http://gitlab.example.com/mygroup/myproject NullPointerException at UserService.java:42
/sdd create --label="priority::high" http://gitlab.example.com/mygroup/myproject 修复登录页崩溃问题
```

**识别规则**：action 为 `create` 时：
- `--type=bug|requirement` 为可选参数，**默认为 `requirement`**（未传 `--type` 时也视为 `requirement`）
- `--label="..."` 为可选参数
- 以上可选参数若存在则先解析，顺序不限
- 其后第一个以 `http://` 或 `https://` 开头且不匹配 `/-/issues/\d+` 模式的参数为项目 URL
- 其后所有内容作为描述（requirement 类型）或错误日志原文（bug 类型）

## 步骤

1. **解析参数**：
   - 提取 `--type` 值（默认 `requirement`），支持 `bug` 或 `requirement`
   - 提取 `--label="..."` 值（若有）
   - 提取项目 URL 和描述/错误日志

2. **解析项目 URL**：运行 `bash <skill_dir>/scripts/gitlab-api.sh parse-project-url "<url>"` 提取 `project_path`

3. **获取 project_id**：运行 `bash <skill_dir>/scripts/gitlab-api.sh resolve-project-id "<project_path>"`

3.5. **自动匹配系统标签 & type 标签（Group Wiki 配置）**：
   ```bash
   # 获取项目的 namespace 信息
   NS=$(bash <skill_dir>/scripts/gitlab-api.sh get-project-namespace "<project_id>")
   NAMESPACE_KIND=$(echo "$NS" | python3 <skill_dir>/scripts/json-helper.py get-field namespace_kind)
   NAMESPACE_ID=$(echo "$NS" | python3 <skill_dir>/scripts/json-helper.py get-field namespace_id)
   REPO_NAME=$(echo "$NS" | python3 <skill_dir>/scripts/json-helper.py get-field repo_name)
   ```
   - 仅当 `namespace_kind == "group"` 时继续；若为 `user`（个人命名空间）则跳过此步骤
   - 尝试获取 Group Wiki 页面：
     ```bash
     WIKI=$(bash <skill_dir>/scripts/gitlab-api.sh get-group-wiki-page "$NAMESPACE_ID" "sdd-configuration" 2>/dev/null)
     ```
   - 如果获取失败（404 或网络错误），**静默跳过**，不影响正常流程，并在步骤 6 结果中追加提示：
     ```
     💡 可在 Group Wiki 创建 sdd-configuration 页面，配置仓库与标签映射，create 时自动添加系统标签。
        参考格式详见 sdd_workflow/features.md「Group 级配置」章节。
     ```
   - 如果获取成功，分别解析两类标签：
     ```bash
     # 系统标签（按仓库名匹配）
     AUTO_LABELS=$(echo "$WIKI" | python3 <skill_dir>/scripts/json-helper.py parse-wiki-labels "$REPO_NAME")

     # type 标签（按 --type 参数匹配「创建Issue type标签映射」章节）
     TYPE_LABEL=$(echo "$WIKI" | python3 <skill_dir>/scripts/json-helper.py parse-wiki-type-label "$ISSUE_TYPE")
     ```
   - 将 `AUTO_LABELS` 和 `TYPE_LABEL` 保存，供步骤 5 合并到最终标签中

4. **生成 issue 内容**：根据 `--type` 值走不同分支

   ### type = requirement（默认）

   结合当前项目上下文（如有），按照 `<skill_dir>/templates/issue-spec-template.md` 生成完整的 issue 内容：

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

   **规范完整度检查**：将生成的 description 通过 `echo "<description>" | bash <skill_dir>/scripts/issue-parser.sh` 解析，检查 `_completeness.missing_sections` 字段：
   - 必填章节：`background`（背景）、`requirements`（需求）、`acceptance_criteria`（验收标准）
   - 如有缺失，提示用户：
     ```
     ⚠️ 生成的 issue 缺少以下必填章节：{missing_sections}
     是否要补充后再创建，还是直接创建？
     ```
   - 用户选择补充则回到本步骤完善内容，选择继续则直接进入步骤 5

   ### type = bug

   **不使用 issue-spec-template**，直接将错误日志原文嵌入 bug 模板：
   - 从用户输入中提取一行简洁标题（如异常类型 + 关键位置）
   - 以 `<skill_dir>/templates/bug-report-template.md` 为框架，将用户提供的错误日志**原文不做任何修改**地填入「错误日志」章节的代码块中
   - 其余章节（复现步骤、影响范围、技术备注）可根据错误日志内容作简单推断，**若无法确定则留空**，不要编造

   > **重要**：bug 类型不对错误日志内容做任何改动，确保开发者看到的是原始信息

5. **创建 issue**：拼接标签参数后运行，无需等待用户确认
   - 基础标签：`workflow::backlog`
   - 如果用户传了 `--label="..."` 参数，追加到基础标签（逗号拼接）
   - 如果步骤 3.5 中 `AUTO_LABELS` 非空，追加到标签列表
   - 如果步骤 3.5 中 `TYPE_LABEL` 非空，追加到标签列表
   - 最终标签示例：`workflow::backlog,requirement,系统::发薪系统` 或 `workflow::backlog,bug,系统::会员系统`
   - 运行：`bash <skill_dir>/scripts/gitlab-api.sh create-issue <project_id> "<title>" "<description>" "<labels>"`

6. **返回结果**：输出创建成功的 issue URL（从 API 返回的 `web_url` 字段获取），并展示生成的 issue 标题和正文摘要供用户参考
   - 如果步骤 3.5 自动添加了系统标签，在结果中展示：`🏷️ 自动添加标签: <AUTO_LABELS>（来自 Group Wiki 配置）`
   - 如果步骤 3.5 自动添加了 type 标签，在结果中展示：`🏷️ 类型标签: <TYPE_LABEL>（来自 Group Wiki type 映射）`
   - 如果步骤 3.5 未找到 Wiki 配置，在结果末尾追加提示（见步骤 3.5 说明）

## 注意

- 生成的 issue 自动添加 `workflow::backlog` 标签；使用 `--label` 时自定义标签与 `workflow::backlog` 合并，不覆盖
- **bug 类型**：错误日志原文不做任何修改，完整保留在 issue 的「错误日志」代码块中
- **requirement 类型**（默认）：按 issue-spec-template 生成结构化规范
- 创建完成后可直接使用 `/sdd read <issue_url>` 查看，或 `/sdd dev <issue_url>` 开始开发
- 如果用户对已创建的 issue 不满意，可使用 `/sdd refine <issue_url>` 来修改内容
