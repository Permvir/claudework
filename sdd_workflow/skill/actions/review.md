# Action: review

`review` 根据传入的 URL 类型自动选择审查模式：
- 传入 **issue URL**（或省略 URL 从上下文获取）→ Issue Spec Review
- 传入 **MR URL**（匹配 `/-/merge_requests/\d+`）→ MR Code Review

## Issue Spec Review

当用户执行 `/sdd review <issue_url>` 时：

1. **解析 issue**：同 read 步骤 1-4，获取 issue 信息和结构化 JSON
2. **获取评论**：获取 issue 评论作为补充上下文
3. **结构化审查**：以"从未参与过需求讨论的开发者"视角，逐维度审查 issue spec：

   **审查维度与标准：**

   | 维度 | 审查标准 | 严重程度 |
   |------|---------|---------|
   | 结构完整性 | 必填章节（背景/需求/验收标准）是否齐全，内容是否实质性 | 🔴 阻塞 |
   | 需求清晰度 | 每条需求是否足够具体、无歧义，能直接指导编码 | 🔴 阻塞 |
   | 验收标准覆盖 | 每条需求是否都有对应的验收标准，标准是否可验证 | 🔴 阻塞 |
   | 一致性 | 需求、验收标准、技术备注之间是否存在矛盾 | 🔴 阻塞 |
   | 自包含性 | 仅凭描述能否完全理解需求，是否存在隐含假设或未定义术语（关联 Issue 中的外部引用视为合理的依赖，不因此判定为不自包含） | 🟡 建议 |
   | 技术可行性 | 技术方案是否合理，是否有明显遗漏的技术约束 | 🟡 建议 |
   | 边界定义 | 是否明确了范围边界（做什么 / 不做什么） | 🟡 建议 |
   | 遗留标记 | 是否还有未解决的 `<!-- TODO -->` 或 `## 问题` 内容 | 🟡 建议 |

4. **输出审查报告**：

   ```
   ## Spec Review: Issue #{iid} — {title}

   ### 审查结论：✅ 通过 / ❌ 未通过（存在阻塞项）

   ### 🔴 阻塞项（必须修复才能进入开发）
   1. [维度] 问题描述 — 改进建议
   2. ...
   （如无：无阻塞项）

   ### 🟡 建议项（建议改进，不阻塞开发）
   1. [维度] 问题描述 — 改进建议
   2. ...
   （如无：无建议项）

   ### 各维度评估
   | 维度 | 结果 | 说明 |
   |------|------|------|
   | 结构完整性 | ✅/❌ | ... |
   | 需求清晰度 | ✅/❌ | ... |
   | ... | ... | ... |

   ---
   ✅ 通过 → 可执行 `/sdd dev <url>` 进入开发
   ❌ 未通过 → 建议执行 `/sdd refine <url>` 修复阻塞项后重新 review
   ```

**注意：**
- Issue spec review 是只读操作，**不修改** issue 的描述、标签或任何内容
- review 不改变 issue 的标签状态
- 可多次执行 review，与 refine 交替使用直到通过
- 建议在**新 session** 中执行 review，以获得无偏见的冷读者视角

## MR Code Review

当用户执行 `/sdd review <mr_url>` 时（URL 匹配 `/-/merge_requests/\d+`）：

1. **解析 MR URL**：运行 `bash <skill_dir>/scripts/gitlab-api.sh parse-mr-url "<url>"` 提取 `project_path` 和 `mr_iid`
2. **获取 project_id**：运行 `bash <skill_dir>/scripts/gitlab-api.sh resolve-project-id "<project_path>"`
3. **获取 MR 详情**：运行 `bash <skill_dir>/scripts/gitlab-api.sh get-mr <project_id> <mr_iid>`，获取 title、description、source_branch、target_branch、labels 等信息
4. **获取 MR 变更**：运行 `bash <skill_dir>/scripts/gitlab-api.sh get-mr-changes <project_id> <mr_iid>`，获取所有文件的 diff
5. **获取关联 issue 上下文**（可选）：从 MR description 中提取关联 issue 引用，按以下模式匹配：
   - `Closes #N` 或 `Closes #{N}` — GitLab 标准格式
   - `Resolve #N` 或 `Resolve "title"` — SDD 默认 MR 模板格式
   - `Refs #N`、`Related to #N` — 弱关联引用
   提取到 issue_iid 后，使用 MR 所属的同一 project_id 调用 `get-issue` 获取 issue 详情作为需求上下文
6. **结构化审查代码变更**：逐文件审查 diff，审查维度：

   | 维度 | 审查标准 | 严重程度 |
   |------|---------|---------|
   | 代码质量与可读性 | 命名规范、代码结构、重复代码、复杂度 | 🟡 建议 |
   | 需求覆盖度 | 对照 issue 验收标准，检查功能实现完整性（仅当有关联 issue 时） | 🔴 阻塞 |
   | 安全性 | OWASP 常见漏洞：注入、XSS、硬编码凭证、不安全的反序列化等 | 🔴 阻塞 |
   | 测试覆盖 | 新增/修改的逻辑是否有对应测试，边界场景是否覆盖 | 🟡 建议 |
   | 潜在 bug 与边界情况 | 空值处理、并发安全、资源泄漏、异常路径 | 🔴 阻塞 |

7. **输出 MR Review 报告**：

   ```
   ## MR Code Review: !{mr_iid} — {title}

   **分支**: {source_branch} → {target_branch}
   **关联 Issue**: #{issue_iid} {issue_title}（如有）
   **变更文件数**: {N} 个文件，+{additions} -{deletions}

   ### 审查结论：✅ 通过 / ⚠️ 有建议 / ❌ 需要修改

   ### 🔴 必须修改
   1. [{文件}:{行号}] 问题描述 — 修改建议
   2. ...
   （如无：无阻塞项）

   ### 🟡 建议改进
   1. [{文件}:{行号}] 问题描述 — 改进建议
   2. ...
   （如无：无建议项）

   ### 各维度评估
   | 维度 | 结果 | 说明 |
   |------|------|------|
   | 代码质量与可读性 | ✅/⚠️/❌ | ... |
   | 需求覆盖度 | ✅/⚠️/❌/N/A | ... |
   | 安全性 | ✅/❌ | ... |
   | 测试覆盖 | ✅/⚠️ | ... |
   | 潜在 bug 与边界情况 | ✅/❌ | ... |

   ### 变更摘要
   | 文件 | 变更类型 | 说明 |
   |------|---------|------|
   | {file_path} | 新增/修改/删除 | 简要描述变更内容 |
   | ... | ... | ... |
   ```

8. **添加或更新 MR 评论**：
   - 在 review 报告末尾追加隐藏标记：`<!-- sdd-review-marker:v1 {mr_iid} -->`（包含版本号和 MR 编号，避免与 diff 内容或用户评论冲突）
   - 先运行 `bash <skill_dir>/scripts/gitlab-api.sh get-mr-notes <project_id> <mr_iid>` 获取已有评论
   - 在评论列表中查找包含 `<!-- sdd-review-marker:v1` 标记的 SDD review 评论（使用此唯一标记而非标题匹配，避免与用户评论中恰好包含相同标题的内容混淆）
   - 如果找到已有 SDD review 评论，运行 `bash <skill_dir>/scripts/gitlab-api.sh update-mr-note <project_id> <mr_iid> <note_id> "<review_report>"` 更新该评论
   - 如果未找到，运行 `bash <skill_dir>/scripts/gitlab-api.sh add-mr-note <project_id> <mr_iid> "<review_report>"` 新增评论
   - 方便团队成员在 GitLab 上查看，多次 review 不会产生重复评论

**注意：**
- MR code review 会自动将审查结论写入 MR 评论
- **大 diff 处理策略**：如果 MR diff 内容过大，按以下规则处理：
  - **跳过的文件类型**：`*.lock`、`*.min.js`、`*.min.css`、`*.generated.*`、`*.pb.go`、`*.snap`、`vendor/`、`node_modules/`、`Pods/`、编译产物目录
  - **单文件策略**：单个文件 diff 超过 500 行时，重点审查新增/修改的函数和关键逻辑段，跳过纯格式化或重构性的大段移动
  - **总量策略**：总 diff 超过 2000 行时，优先审查核心业务逻辑文件，配置文件和测试文件次之，在报告中注明"部分文件因篇幅未详细审查"
- 审查报告中的文件路径和行号对应 diff 中的位置，方便定位
