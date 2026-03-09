#!/usr/bin/env bash
# GitLab Profiles — 核心函数库
# 安装位置: ~/.claude/gitlab-profiles/.functions.sh
# 由 gitlab-use 函数（~/.zshrc）在运行时 source

# ── 颜色 ──
_GP_GREEN='\033[0;32m'
_GP_YELLOW='\033[1;33m'
_GP_RED='\033[0;31m'
_GP_NC='\033[0m'

_GP_PROFILE_DIR="${HOME}/.claude/gitlab-profiles"
_GP_TEMPLATE="${_GP_PROFILE_DIR}/.template"

# ── Token 验证 ──
_gitlab_validate_token() {
    local url="$1" token="$2"
    curl -s -L --noproxy '*' -o /dev/null -w '%{http_code}' \
        --connect-timeout 3 --max-time 5 \
        -H "PRIVATE-TOKEN: ${token}" \
        "${url}/api/v4/user" 2>/dev/null
}

# ── 获取用户名 ──
_gitlab_get_username() {
    local url="$1" token="$2"
    curl -s -L --noproxy '*' --connect-timeout 3 --max-time 5 \
        -H "PRIVATE-TOKEN: ${token}" \
        "${url}/api/v4/user" 2>/dev/null | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('username',''))" 2>/dev/null
}

# ── 从 profile 文件提取字段 ──
_gitlab_extract_field() {
    local file="$1" field="$2"
    grep "^export ${field}=" "$file" 2>/dev/null | head -1 | sed "s/^export ${field}=\"//" | sed 's/"$//'
}

# ── 创建 profile 文件 ──
_gitlab_create_profile() {
    local name="$1" url="$2" token="$3" dev="$4" email="$5"
    local outfile="${_GP_PROFILE_DIR}/${name}.sh"

    if [[ ! -f "${_GP_TEMPLATE}" ]]; then
        echo -e "${_GP_RED}错误:${_GP_NC} 模板文件不存在: ${_GP_TEMPLATE}"
        echo "请重新运行 install.sh"
        return 1
    fi

    sed \
        -e "s|__PROFILE_NAME__|${name}|g" \
        -e "s|__GITLAB_URL__|${url}|g" \
        -e "s|__GITLAB_TOKEN__|${token}|g" \
        -e "s|__DEVELOPER_NAME__|${dev}|g" \
        -e "s|__GIT_EMAIL__|${email}|g" \
        "${_GP_TEMPLATE}" > "${outfile}"

    chmod +x "${outfile}"
}

# ── 子命令: 列表 ──
_gitlab_use_list() {
    echo "当前: ${_GITLAB_PROFILE_ACTIVE:-none}"
    echo "可用 profiles:"
    local count=0
    local _pname
    for f in "${_GP_PROFILE_DIR}"/*.sh; do
        [[ -f "$f" ]] || continue
        _pname="$(basename "$f" .sh)"
        count=$((count + 1))
        if [[ "${_pname}" == "${_GITLAB_PROFILE_ACTIVE:-}" ]]; then
            echo -e "  ${_GP_GREEN}*${_GP_NC} ${_pname}  (active)"
        else
            echo "    ${_pname}"
        fi
    done
    if [[ $count -eq 0 ]]; then
        echo "  (无 profile，使用 gitlab-use add 创建)"
    fi
    echo ""
    echo "命令: gitlab-use <name> | add | remove <name> | info [name]"
}

# ── 子命令: 交互式添加 ──
_gitlab_use_add() {
    echo "=== 添加新 GitLab Profile ==="
    echo ""

    local p_name p_url p_token p_dev p_email p_dev_default

    printf "Profile 名称: "
    read -r p_name
    [[ -z "$p_name" ]] && echo -e "${_GP_RED}错误:${_GP_NC} 名称不能为空" && return 1
    [[ "$p_name" =~ ^(add|remove|info)$ ]] && echo -e "${_GP_RED}错误:${_GP_NC} '${p_name}' 是保留子命令名" && return 1

    if [[ -f "${_GP_PROFILE_DIR}/${p_name}.sh" ]]; then
        echo -e "${_GP_RED}错误:${_GP_NC} Profile '${p_name}' 已存在"
        return 1
    fi

    printf "GitLab URL [http://gitlab.example.com]: "
    read -r p_url
    p_url="${p_url:-http://gitlab.example.com}"

    printf "Personal Access Token (api scope): "
    read -r p_token
    [[ -z "$p_token" ]] && echo -e "${_GP_RED}错误:${_GP_NC} Token 不能为空" && return 1

    # Validate token
    echo -n "验证 Token... "
    local http_code
    http_code=$(_gitlab_validate_token "$p_url" "$p_token")
    if [[ "$http_code" == "200" ]]; then
        local username
        username=$(_gitlab_get_username "$p_url" "$p_token")
        echo -e "${_GP_GREEN}✓${_GP_NC} 有效 (用户: ${username})"
        p_dev_default="${username:-${p_name}}"
    else
        echo -e "${_GP_RED}✗${_GP_NC} 验证失败 (HTTP ${http_code})"
        printf "仍要继续创建? [y/N]: "
        local confirm
        read -r confirm
        [[ "$confirm" != [yY] ]] && return 1
        p_dev_default="${p_name}"
    fi

    printf "开发者名称 [${p_dev_default}]: "
    read -r p_dev
    p_dev="${p_dev:-${p_dev_default}}"

    local default_email="${p_dev}@example.com"
    printf "Git 邮箱 [${default_email}]: "
    read -r p_email
    p_email="${p_email:-${default_email}}"

    # Generate profile
    _gitlab_create_profile "$p_name" "$p_url" "$p_token" "$p_dev" "$p_email" || return 1

    echo ""
    echo -e "${_GP_GREEN}✓${_GP_NC} Profile '${p_name}' 已创建: ${_GP_PROFILE_DIR}/${p_name}.sh"
    echo "  使用 gitlab-use ${p_name} 切换"
}

# ── 子命令: 删除 ──
_gitlab_use_remove() {
    local target="$1"
    [[ -z "$target" ]] && echo "用法: gitlab-use remove <name>" && return 1

    if [[ ! -f "${_GP_PROFILE_DIR}/${target}.sh" ]]; then
        echo -e "${_GP_RED}错误:${_GP_NC} Profile '${target}' 不存在"
        return 1
    fi

    if [[ "${target}" == "${_GITLAB_PROFILE_ACTIVE:-}" ]]; then
        echo -e "${_GP_RED}错误:${_GP_NC} 不能删除当前激活的 profile '${target}'"
        echo "提示: 先切换到其他 profile，再删除"
        return 1
    fi

    rm "${_GP_PROFILE_DIR}/${target}.sh"
    echo -e "${_GP_GREEN}✓${_GP_NC} Profile '${target}' 已删除"
}

# ── 子命令: 详情 ──
_gitlab_use_info() {
    local target="${1:-${_GITLAB_PROFILE_ACTIVE:-}}"
    [[ -z "$target" ]] && echo -e "${_GP_RED}错误:${_GP_NC} 没有激活的 profile，请指定名称: gitlab-use info <name>" && return 1

    local pfile="${_GP_PROFILE_DIR}/${target}.sh"
    [[ ! -f "$pfile" ]] && echo -e "${_GP_RED}错误:${_GP_NC} Profile '${target}' 不存在" && return 1

    local info_url info_token info_dev info_email
    info_url=$(_gitlab_extract_field "$pfile" "GITLAB_URL")
    info_token=$(_gitlab_extract_field "$pfile" "GITLAB_TOKEN")
    info_dev=$(_gitlab_extract_field "$pfile" "DEVELOPER_NAME")
    info_email=$(_gitlab_extract_field "$pfile" "GIT_AUTHOR_EMAIL")

    # Mask token
    local masked_token
    if [[ ${#info_token} -gt 10 ]]; then
        masked_token="${info_token:0:10}...${info_token: -4}"
    else
        masked_token="***"
    fi

    echo "=== Profile: ${target} ==="
    [[ "${target}" == "${_GITLAB_PROFILE_ACTIVE:-}" ]] && echo -e "状态:       ${_GP_GREEN}✓ 激活中${_GP_NC}"
    echo "GitLab URL: ${info_url}"
    echo "Token:      ${masked_token}"
    echo "开发者:     ${info_dev}"
    echo "邮箱:       ${info_email}"

    # Validate token
    echo -n "Token 状态: "
    local http_code
    http_code=$(_gitlab_validate_token "$info_url" "$info_token")
    if [[ "$http_code" == "200" ]]; then
        echo -e "${_GP_GREEN}✓ 有效${_GP_NC}"
    else
        echo -e "${_GP_RED}✗ 无效 (HTTP ${http_code})${_GP_NC}"
    fi
}

# ── 子命令: 切换 ──
_gitlab_use_switch() {
    local name="$1"
    local profile="${_GP_PROFILE_DIR}/${name}.sh"

    if [[ ! -f "${profile}" ]]; then
        echo -e "${_GP_RED}Profile not found:${_GP_NC} ${name}"
        echo "可用: $(ls "${_GP_PROFILE_DIR}"/*.sh 2>/dev/null | xargs -I{} basename {} .sh | tr '\n' ' ')"
        echo "使用 gitlab-use add 创建新 profile"
        return 1
    fi

    source "${profile}"

    # Validate token after switch
    local http_code
    http_code=$(_gitlab_validate_token "${GITLAB_URL}" "${GITLAB_TOKEN}")
    if [[ "$http_code" != "200" ]]; then
        echo -e "${_GP_YELLOW}⚠ 警告:${_GP_NC} Token 验证失败 (HTTP ${http_code})，可能已过期"
    fi
}

# ── 主调度 ──
_gitlab_use_main() {
    case "${1:-}" in
        "")     _gitlab_use_list ;;
        add)    _gitlab_use_add ;;
        remove) shift; _gitlab_use_remove "$@" ;;
        info)   shift; _gitlab_use_info "$@" ;;
        *)      _gitlab_use_switch "$1" ;;
    esac
}
