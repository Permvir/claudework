#!/usr/bin/env bash
# GitLab Profiles — 安装脚本
# 安装 functions、模板、zshrc 函数，并在无 profile 时引导交互式创建

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="${HOME}/.claude/gitlab-profiles"
TEMPLATE_SRC="${PROJECT_DIR}/templates/profile.sh.tpl"
FUNCTIONS_SRC="${PROJECT_DIR}/lib/functions.sh"
ZSHRC="${HOME}/.zshrc"
MARKER_BEGIN="# >>> gitlab-use function >>>"
MARKER_END="# <<< gitlab-use function <<<"

echo "安装 GitLab Profiles..."
echo ""

# 1. 创建 profile 目录
mkdir -p "${PROFILE_DIR}"
echo -e "${GREEN}✓${NC} 目录已创建: ${PROFILE_DIR}"

# 2. 安装函数库
cp "${FUNCTIONS_SRC}" "${PROFILE_DIR}/.functions.sh"
echo -e "${GREEN}✓${NC} 函数库已安装: ${PROFILE_DIR}/.functions.sh"

# 3. 安装模板
cp "${TEMPLATE_SRC}" "${PROFILE_DIR}/.template"
echo -e "${GREEN}✓${NC} 模板已安装: ${PROFILE_DIR}/.template"

# 4. 注入 gitlab-use 函数到 ~/.zshrc（支持升级：有旧版则替换）
if grep -qF "${MARKER_BEGIN}" "${ZSHRC}" 2>/dev/null; then
    # 移除旧版函数块
    sed -i '' "/${MARKER_BEGIN//\//\\/}/,/${MARKER_END//\//\\/}/d" "${ZSHRC}"
    echo -e "${YELLOW}!${NC} 已移除旧版 gitlab-use 函数"
fi

cat >> "${ZSHRC}" << 'ZSHRC_BLOCK'

# >>> gitlab-use function >>>
gitlab-use() {
    local _fn="${HOME}/.claude/gitlab-profiles/.functions.sh"
    if [[ ! -f "$_fn" ]]; then
        echo "gitlab-use: 未找到函数库，请重新安装: bash <project>/gitlab_profiles/install.sh"
        return 1
    fi
    source "$_fn"
    _gitlab_use_main "$@"
}
# <<< gitlab-use function <<<
ZSHRC_BLOCK
echo -e "${GREEN}✓${NC} gitlab-use 函数已更新到 ~/.zshrc"

# 5. 如果没有任何 profile，引导交互式创建
profile_count=$(find "${PROFILE_DIR}" -maxdepth 1 -name '*.sh' -not -name '.*' 2>/dev/null | wc -l | tr -d ' ')
if [[ "${profile_count}" -eq 0 ]]; then
    echo ""
    echo -e "${YELLOW}未检测到任何 profile，开始创建第一个...${NC}"
    echo ""
    # Source functions and run interactive add
    source "${PROFILE_DIR}/.functions.sh"
    _gitlab_use_add
else
    echo -e "${GREEN}✓${NC} 已有 ${profile_count} 个 profile"
fi

echo ""
echo -e "${GREEN}安装完成。${NC}"
echo ""
echo "使用方式："
echo "  source ~/.zshrc              # 重新加载 shell 配置"
echo "  gitlab-use                   # 查看可用 profile 列表"
echo "  gitlab-use <name>            # 切换到指定账户"
echo "  gitlab-use add               # 交互式添加新 profile"
echo "  gitlab-use remove <name>     # 删除 profile"
echo "  gitlab-use info [name]       # 查看 profile 详情"
echo ""
echo "详细文档：${PROJECT_DIR}/features.md"
