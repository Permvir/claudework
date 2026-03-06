#!/usr/bin/env bash
# SDD Workflow — Issue Markdown 解析器
# 将 issue 的 markdown 内容解析为结构化 JSON
# 用法：echo "<markdown>" | bash issue-parser.sh
#       bash issue-parser.sh <file>

set -euo pipefail

# 文件参数时直接传路径，stdin 时用临时文件（避免与 heredoc 的 stdin 冲突）
if [[ $# -ge 1 && -f "$1" ]]; then
    _INPUT="$1"
else
    _INPUT=$(mktemp)
    trap 'rm -f "${_INPUT}"' EXIT
    cat - > "${_INPUT}"
fi

python3 - "${_INPUT}" <<'PYEOF'
import json
import re
import sys

def parse_issue_markdown(text):
    """解析 SDD 规范 issue markdown，提取各个章节内容"""
    sections = {}
    current_section = None
    current_content = []

    # 标准章节标题映射（中英文都支持）
    section_map = {
        '背景': 'background',
        'background': 'background',
        '需求': 'requirements',
        'requirements': 'requirements',
        '功能需求': 'requirements',
        '验收标准': 'acceptance_criteria',
        'acceptance criteria': 'acceptance_criteria',
        '技术备注': 'technical_notes',
        'technical notes': 'technical_notes',
        '技术说明': 'technical_notes',
        '测试计划': 'test_plan',
        'test plan': 'test_plan',
        '开发记录': 'dev_notes',
        'dev notes': 'dev_notes',
        '开发日志': 'dev_notes',
        '参考': 'references',
        'references': 'references',
        '备注': 'notes',
        'notes': 'notes',
        'reviewer': 'reviewer',
        'reviewers': 'reviewer',
        '问题': 'questions',
        'questions': 'questions',
        '关联 issue': 'related_issues',
        '关联issue': 'related_issues',
        'related issues': 'related_issues',
    }

    in_code_block = False
    for line in text.split('\n'):
        stripped = line.strip()
        # 跳过代码块内的内容，避免代码示例中的 ## 被误解析为章节标题
        if stripped.startswith('```'):
            in_code_block = not in_code_block
            if current_section:
                current_content.append(line)
            continue
        if in_code_block:
            if current_section:
                current_content.append(line)
            continue

        # 匹配 ## 标题
        header_match = re.match(r'^##\s+(.+)$', stripped)
        if header_match:
            # 保存上一个章节
            if current_section:
                sections[current_section] = '\n'.join(current_content).strip()

            title = header_match.group(1).strip()
            title_lower = title.lower()
            current_section = section_map.get(title_lower, title_lower.replace(' ', '_'))
            current_content = []
        elif current_section:
            current_content.append(line)

    # 保存最后一个章节
    if current_section:
        sections[current_section] = '\n'.join(current_content).strip()

    # 提取 <!-- TODO: xxx --> 内联标记（跳过代码块内的内容）
    todos = []
    all_lines = text.split('\n')
    in_code_block = False
    for i, line in enumerate(all_lines):
        if line.strip().startswith('```'):
            in_code_block = not in_code_block
            continue
        if in_code_block:
            continue
        for m in re.finditer(r'<!--\s*TODO:\s*(.+?)\s*-->', line):
            ctx_start = max(0, i - 2)
            ctx_end = min(len(all_lines), i + 3)
            todos.append({
                'content': m.group(1).strip(),
                'line': i + 1,
                'context': '\n'.join(all_lines[ctx_start:ctx_end]),
            })
    if todos:
        sections['todos'] = todos

    # 提取验收标准为列表
    if 'acceptance_criteria' in sections:
        criteria = []
        for line in sections['acceptance_criteria'].split('\n'):
            line = line.strip()
            # 匹配 - [ ] 或 - [x] 或 - 开头的列表项
            m = re.match(r'^-\s*\[[ x]\]\s*(.+)$', line)
            if m:
                criteria.append(m.group(1).strip())
            elif line.startswith('- '):
                criteria.append(line[2:].strip())
        if criteria:
            sections['acceptance_criteria_list'] = criteria

    # 提取需求为列表
    if 'requirements' in sections:
        requirements = []
        for line in sections['requirements'].split('\n'):
            line = line.strip()
            m = re.match(r'^(?:\d+\.\s*|-\s*)(.+)$', line)
            if m:
                requirements.append(m.group(1).strip())
        if requirements:
            sections['requirements_list'] = requirements

    # 提取问题为列表
    if 'questions' in sections:
        questions_list = []
        for line in sections['questions'].split('\n'):
            line = line.strip()
            m = re.match(r'^(?:\d+\.\s*|-\s*|\*\s*)(.+)$', line)
            if m:
                questions_list.append(m.group(1).strip())
        if questions_list:
            sections['questions_list'] = questions_list

    # 提取关联 Issue URL 列表
    if 'related_issues' in sections:
        related_list = []
        for line in sections['related_issues'].split('\n'):
            line = line.strip()
            # 匹配 URL（可能带说明）
            m = re.match(r'^(?:-\s*|\*\s*|\d+\.\s*)?(https?://[a-zA-Z0-9:.\-_/%@+~]+/-/issues/\d+)(.*)', line)
            if m:
                url = m.group(1).strip()
                desc = m.group(2).strip().lstrip('—–-').strip()
                item = {'url': url}
                if desc:
                    item['description'] = desc
                related_list.append(item)
        if related_list:
            sections['related_issues_list'] = related_list

    # 提取 Reviewer 用户名列表（先剥离 HTML 注释，避免注释内容被误解析为用户名）
    if 'reviewer' in sections:
        reviewers = []
        text = re.sub(r'<!--.*?-->', '', sections['reviewer'], flags=re.DOTALL)
        for part in re.split(r'[,，\s]+', text):
            part = part.strip().lstrip('@')
            if part:
                reviewers.append(part)
        if reviewers:
            sections['reviewer_list'] = reviewers

    # 检查规范完整度（空白内容视为缺失）
    expected = ['background', 'requirements', 'acceptance_criteria']
    missing = [s for s in expected if s not in sections or not sections[s].strip()]
    # 计数仅含真实章节，排除派生字段（*_list、todos）
    real_sections = [k for k in sections if not k.startswith('_') and not k.endswith('_list') and k != 'todos']
    sections['_completeness'] = {
        'has_all_required': len(missing) == 0,
        'missing_sections': missing,
        'total_sections': len(real_sections),
    }

    return sections

if len(sys.argv) < 2:
    print('错误: 缺少文件参数', file=sys.stderr)
    sys.exit(1)
try:
    with open(sys.argv[1]) as f:
        text = f.read()
except FileNotFoundError:
    print(f'错误: 文件不存在: {sys.argv[1]}', file=sys.stderr)
    sys.exit(1)

result = parse_issue_markdown(text)
print(json.dumps(result, ensure_ascii=False, indent=2))
PYEOF
