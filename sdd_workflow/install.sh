#!/usr/bin/env bash
# SDD Workflow — 安装脚本
# 将 Skill 文件和脚本部署到 ~/.claude/skills/sdd/
# 用户配置文件 ~/.claude/sdd-config.sh 仅首次创建，不会被覆盖

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DST="${HOME}/.claude/skills/sdd"
CONFIG_DST="${HOME}/.claude/sdd-config.sh"

# ─── 卸载模式 ─────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
    echo "卸载 SDD Workflow Skill..."
    if [[ -d "${SKILL_DST}" ]]; then
        rm -rf "${SKILL_DST}"
        echo -e "${GREEN}✓${NC} 已删除 ${SKILL_DST}"
    else
        echo -e "${YELLOW}!${NC} ${SKILL_DST} 不存在，跳过"
    fi
    echo ""
    echo "注意：用户配置文件 ${CONFIG_DST} 未删除（含敏感凭证，请手动处理）"
    echo "提示：缓存目录 ~/.cache/sdd/ 可手动删除（含分支检测缓存等临时数据）"
    echo -e "${GREEN}卸载完成。${NC}"
    exit 0
fi

# ─── 安装模式 ─────────────────────────────────────────────

# 检查必需依赖
for cmd in python3 curl git; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}错误:${NC} 缺少依赖 '$cmd'，请先安装后再运行安装脚本。" >&2
        exit 1
    fi
done

# 检查 curl 版本（--fail-with-body 需要 ≥7.76.0）
curl_version=$(curl --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ -n "${curl_version}" ]]; then
    curl_major=$(echo "$curl_version" | cut -d. -f1)
    curl_minor=$(echo "$curl_version" | cut -d. -f2)
    if [[ -n "${curl_major}" && -n "${curl_minor}" ]]; then
        if [[ "$curl_major" -lt 7 ]] || [[ "$curl_major" -eq 7 && "$curl_minor" -lt 76 ]]; then
            echo -e "${YELLOW}!${NC} curl 版本 ${curl_version} 不支持 --fail-with-body（需要 ≥7.76.0），API 错误信息可能不完整"
        fi
    else
        echo -e "${YELLOW}!${NC} 无法解析 curl 版本号，跳过版本检查"
    fi
else
    echo -e "${YELLOW}!${NC} 无法获取 curl 版本信息，跳过版本检查"
fi

# ─── 版本检测 ─────────────────────────────────────────────
# 使用源文件内容 hash 检测是否有变化
if command -v md5sum &>/dev/null; then
    _new_hash=$(find "${PROJECT_DIR}" \( -name "*.md" -o -name "*.sh" -o -name "*.py" \) -not -path "*/.claude/*" -not -path "*/tests/*" -print0 | sort -z | xargs -0 cat 2>/dev/null | md5sum | cut -d' ' -f1)
elif command -v md5 &>/dev/null; then
    _new_hash=$(find "${PROJECT_DIR}" \( -name "*.md" -o -name "*.sh" -o -name "*.py" \) -not -path "*/.claude/*" -not -path "*/tests/*" -print0 | sort -z | xargs -0 cat 2>/dev/null | md5 -q)
else
    _new_hash="unknown"
fi
_old_hash=""
[[ -f "${SKILL_DST}/.version" ]] && _old_hash=$(cat "${SKILL_DST}/.version" 2>/dev/null)

if [[ "${_new_hash}" != "unknown" && "${_new_hash}" == "${_old_hash}" ]]; then
    echo -e "${GREEN}SDD Workflow Skill 已是最新版本，无需更新。${NC}"
    # 仍然检查 token 配置
    if grep -q 'YOUR_TOKEN_HERE' "${CONFIG_DST}" 2>/dev/null; then
        echo ""
        echo -e "${YELLOW}!${NC} 请配置 GitLab Token："
        echo "  编辑文件：${CONFIG_DST}"
        echo "  将 GITLAB_TOKEN=\"YOUR_TOKEN_HERE\" 替换为你的 Personal Access Token"
    fi
    exit 0
fi

if [[ -n "${_old_hash}" ]]; then
    echo "检测到版本变更，更新安装 SDD Workflow Skill..."
else
    echo "首次安装 SDD Workflow Skill..."
fi
echo ""

# 1. 创建目标目录
mkdir -p "${SKILL_DST}"

# 2. 复制 Skill 主文件
cp "${PROJECT_DIR}/skill/SKILL.md" "${SKILL_DST}/"
echo -e "${GREEN}✓${NC} SKILL.md 已部署"

# 3. 复制 actions/
mkdir -p "${SKILL_DST}/actions"
cp "${PROJECT_DIR}/skill/actions/"*.md "${SKILL_DST}/actions/"
echo -e "${GREEN}✓${NC} actions/ 已部署（$(ls "${PROJECT_DIR}/skill/actions/"*.md | wc -l | tr -d ' ') 个 action）"

# 4. 验证并复制 scripts/
mkdir -p "${SKILL_DST}/scripts"
for script in "${PROJECT_DIR}/scripts/"*.sh; do
    if ! bash -n "${script}" 2>/dev/null; then
        echo -e "${RED}✗${NC} Shell 脚本语法错误: $(basename "${script}")" >&2
        exit 1
    fi
done
for pyscript in "${PROJECT_DIR}/scripts/"*.py; do
    [[ -f "${pyscript}" ]] || continue
    if ! python3 -m py_compile "${pyscript}" 2>/dev/null; then
        echo -e "${RED}✗${NC} Python 脚本语法错误: $(basename "${pyscript}")" >&2
        exit 1
    fi
done
cp "${PROJECT_DIR}/scripts/"*.sh "${SKILL_DST}/scripts/"
cp "${PROJECT_DIR}/scripts/"*.py "${SKILL_DST}/scripts/" 2>/dev/null || true
chmod +x "${SKILL_DST}/scripts/"*.sh
echo -e "${GREEN}✓${NC} scripts/ 已部署（语法检查通过）"

# 5. 复制 references/
mkdir -p "${SKILL_DST}/references"
cp "${PROJECT_DIR}/references/"*.md "${SKILL_DST}/references/"
echo -e "${GREEN}✓${NC} references/ 已部署"

# 6. 复制 templates/
mkdir -p "${SKILL_DST}/templates"
cp "${PROJECT_DIR}/templates/"*.md "${SKILL_DST}/templates/"
echo -e "${GREEN}✓${NC} templates/ 已部署"

# 7. 复制 examples/
mkdir -p "${SKILL_DST}/examples"
cp "${PROJECT_DIR}/examples/"*.md "${SKILL_DST}/examples/"
echo -e "${GREEN}✓${NC} examples/ 已部署"

# 8. 写入版本标记
echo "${_new_hash}" > "${SKILL_DST}/.version"

# 9. 创建/更新用户配置
# 策略：
#   - 首次安装：直接复制模板
#   - 已存在且模板未变化：跳过（不改动用户文件）
#   - 已存在但模板有更新：提取 GITLAB_URL 和 GITLAB_TOKEN，整个配置换成新模板，再写回凭证
#     （sdd-config.sh 中只有这两个字段是用户私有数据，其余均为可安全覆盖的默认值）
# 配置文件包含 GITLAB_TOKEN 等敏感凭证，权限设为 600（仅所有者可读写）

_CONFIG_TEMPLATE="${PROJECT_DIR}/scripts/config-template.sh"
_CONFIG_HASH_FILE="${HOME}/.claude/sdd-config.version"

# 计算当前模板的 hash
if command -v md5sum &>/dev/null; then
    _tpl_hash=$(md5sum "${_CONFIG_TEMPLATE}" | cut -d' ' -f1)
elif command -v md5 &>/dev/null; then
    _tpl_hash=$(md5 -q "${_CONFIG_TEMPLATE}")
else
    _tpl_hash="unknown"
fi

if [[ ! -f "${CONFIG_DST}" ]]; then
    # 首次安装
    cp "${_CONFIG_TEMPLATE}" "${CONFIG_DST}"
    chmod 600 "${CONFIG_DST}"
    [[ "${_tpl_hash}" != "unknown" ]] && echo "${_tpl_hash}" > "${_CONFIG_HASH_FILE}"
    echo -e "${GREEN}✓${NC} 配置文件已创建: ${CONFIG_DST}（权限 600）"
else
    chmod 600 "${CONFIG_DST}"

    # 读取上次安装时记录的模板 hash
    _old_tpl_hash=""
    [[ -f "${_CONFIG_HASH_FILE}" ]] && _old_tpl_hash=$(cat "${_CONFIG_HASH_FILE}" 2>/dev/null)

    if [[ "${_tpl_hash}" == "unknown" || "${_tpl_hash}" == "${_old_tpl_hash}" ]]; then
        # 模板未变化，无需处理
        echo -e "${YELLOW}!${NC} 配置文件无需更新: ${CONFIG_DST}"
    else
        # 模板有更新 → 自动迁移：提取凭证，换用新模板，写回凭证
        echo -e "${GREEN}✓${NC} 检测到配置模板更新，自动迁移配置..."

        # 在干净环境下 source 旧配置，提取用户私有凭证
        # 先 unset 同名环境变量，防止外部环境变量干扰提取结果
        _saved_url=$(bash -c 'unset GITLAB_URL;  source "$1" 2>/dev/null; echo "${GITLAB_URL:-}"'  _ "${CONFIG_DST}")
        _saved_token=$(bash -c 'unset GITLAB_TOKEN; source "$1" 2>/dev/null; echo "${GITLAB_TOKEN:-}"' _ "${CONFIG_DST}")

        # 整个配置文件替换为新模板
        cp "${_CONFIG_TEMPLATE}" "${CONFIG_DST}"
        chmod 600 "${CONFIG_DST}"

        # 将提取到的凭证写回新配置（python3 处理特殊字符，避免 sed 转义问题）
        python3 - "${CONFIG_DST}" "${_saved_url}" "${_saved_token}" <<'PYEOF'
import sys
path, url, token = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(path).read()
if url:
    content = content.replace('https://your-gitlab.example.com', url)
if token and token != 'YOUR_TOKEN_HERE':
    content = content.replace('YOUR_TOKEN_HERE', token)
open(path, 'w').write(content)
PYEOF

        [[ "${_tpl_hash}" != "unknown" ]] && echo "${_tpl_hash}" > "${_CONFIG_HASH_FILE}"
        echo -e "${GREEN}  ✓${NC} GITLAB_URL  → ${_saved_url:-（未配置）}"
        echo -e "${GREEN}  ✓${NC} GITLAB_TOKEN → $([ -n "${_saved_token}" ] && [ "${_saved_token}" != 'YOUR_TOKEN_HERE' ] && echo '已迁移' || echo '（未配置）')"
        echo "  其余配置项已更新为最新默认值"
    fi
fi

echo ""

# 10. 检查 token 配置
if grep -q 'YOUR_TOKEN_HERE' "${CONFIG_DST}" 2>/dev/null; then
    echo -e "${YELLOW}!${NC} 请配置 GitLab Token："
    echo ""
    echo "  编辑文件：${CONFIG_DST}"
    echo "  将 GITLAB_TOKEN=\"YOUR_TOKEN_HERE\" 替换为你的 Personal Access Token"
    echo ""
    echo "  Token 获取方式：GitLab → Settings → Access Tokens → 创建（需要 api scope）"
else
    echo -e "${GREEN}✓${NC} GitLab Token 已配置"
fi

echo ""
echo -e "${GREEN}安装完成。${NC}"
echo ""
echo "使用方式："
echo "  在任意 GitLab 项目目录下启动 Claude Code，然后："
echo ""
echo "  /sdd create <project_url> <描述>  — 根据描述生成 SDD 规范 issue 并创建到 GitLab"
echo "  /sdd read <issue_url>            — 阅读并解析 issue 需求"
echo "  /sdd refine <issue_url>          — 讨论问题并更新 issue 描述"
echo "  /sdd dev <issue_url>             — 创建分支并开始开发"
echo "  /sdd submit <issue_url>          — 推送代码、review 变更、生成 MR 描述"
echo "  /sdd update <issue_url>          — 添加 Issue 评论（进度、决策等）"
echo "  /sdd list                        — 查看项目 Issue 看板（按工作流阶段分组）"
echo "  /sdd status                      — 查看当前工作状态"
echo "  /sdd template                    — 查看 issue 规范模板"
echo ""
echo "卸载方式："
echo "  bash ${PROJECT_DIR}/install.sh --uninstall"
echo ""
echo "详细文档：${PROJECT_DIR}/features.md"
