#!/usr/bin/env bash
# GitLab Profiles — 核心函数库
# 安装位置: ~/.claude/gitlab-profiles/.functions.sh
# 由 gitlab-use 函数（~/.zshrc）在运行时 source

# ── 颜色 ──
_GP_GREEN='\033[0;32m'
_GP_YELLOW='\033[1;33m'
_GP_RED='\033[0;31m'
_GP_NC='\033[0m'

# ── 语言检测 ──
if [[ "${LANG:-}" != zh_CN* && "${LANG:-}" != zh_TW* ]]; then
  _GP_LANG=en
else
  _GP_LANG=zh
fi

_GP_PROFILE_DIR="${HOME}/.claude/gitlab-profiles"
_GP_TEMPLATE="${_GP_PROFILE_DIR}/.template"

# ── i18n 消息函数 ──
_gp_msg() {
    local key="$1"; shift
    if [[ "${_GP_LANG}" == "en" ]]; then
        case "${key}" in
            current)            echo "Current: ${1:-none}" ;;
            available)          echo "Available profiles:" ;;
            active)             echo "(active)" ;;
            no_profile)         echo "  (no profiles, use gitlab-use add to create)" ;;
            usage_cmd)          echo "Commands: gitlab-use <name> | add | remove <name> | info [name]" ;;
            add_header)         echo "=== Add New GitLab Profile ===" ;;
            prompt_name)        printf "Profile name: " ;;
            err_name_empty)     echo -e "${_GP_RED}Error:${_GP_NC} Name cannot be empty" ;;
            err_reserved)       echo -e "${_GP_RED}Error:${_GP_NC} '${1}' is a reserved subcommand name" ;;
            err_exists)         echo -e "${_GP_RED}Error:${_GP_NC} Profile '${1}' already exists" ;;
            prompt_url)         printf "GitLab URL: " ;;
            err_url_empty)      echo -e "${_GP_RED}Error:${_GP_NC} GitLab URL cannot be empty" ;;
            prompt_token)       printf "Personal Access Token (api scope): " ;;
            err_token_empty)    echo -e "${_GP_RED}Error:${_GP_NC} Token cannot be empty" ;;
            validating)         echo -n "Validating Token... " ;;
            token_valid)        echo -e "${_GP_GREEN}✓${_GP_NC} Valid (user: ${1})" ;;
            token_invalid)      echo -e "${_GP_RED}✗${_GP_NC} Validation failed (HTTP ${1})" ;;
            confirm_continue)   printf "Continue creating anyway? [y/N]: " ;;
            prompt_dev)         printf "Developer name [${1}]: " ;;
            prompt_email)       printf "Git email: " ;;
            err_email_empty)    echo -e "${_GP_RED}Error:${_GP_NC} Git email cannot be empty" ;;
            created)            echo -e "${_GP_GREEN}✓${_GP_NC} Profile '${1}' created: ${2}" ;;
            switch_hint)        echo "  Use gitlab-use ${1} to switch" ;;
            usage_remove)       echo "Usage: gitlab-use remove <name>" ;;
            err_not_found)      echo -e "${_GP_RED}Error:${_GP_NC} Profile '${1}' not found" ;;
            err_del_active)     echo -e "${_GP_RED}Error:${_GP_NC} Cannot delete the active profile '${1}'" ;;
            hint_switch_first)  echo "Hint: Switch to another profile first, then delete" ;;
            deleted)            echo -e "${_GP_GREEN}✓${_GP_NC} Profile '${1}' deleted" ;;
            err_no_active)      echo -e "${_GP_RED}Error:${_GP_NC} No active profile, specify a name: gitlab-use info <name>" ;;
            status_active)      echo -e "Status:     ${_GP_GREEN}✓ Active${_GP_NC}" ;;
            label_dev)          echo "Developer:  ${1}" ;;
            label_email)        echo "Email:      ${1}" ;;
            token_status)       echo -n "Token status: " ;;
            token_ok)           echo -e "${_GP_GREEN}✓ Valid${_GP_NC}" ;;
            token_bad)          echo -e "${_GP_RED}✗ Invalid (HTTP ${1})${_GP_NC}" ;;
            avail_list)         echo "Available: ${1}" ;;
            hint_add)           echo "Use gitlab-use add to create a new profile" ;;
            warn_token)         echo -e "${_GP_YELLOW}⚠ Warning:${_GP_NC} Token validation failed (HTTP ${1}), may have expired" ;;
            err_template)       echo -e "${_GP_RED}Error:${_GP_NC} Template file not found: ${1}" ;;
            hint_reinstall)     echo "Please re-run install.sh" ;;
        esac
    else
        case "${key}" in
            current)            echo "当前: ${1:-none}" ;;
            available)          echo "可用 profiles:" ;;
            active)             echo "(active)" ;;
            no_profile)         echo "  (无 profile，使用 gitlab-use add 创建)" ;;
            usage_cmd)          echo "命令: gitlab-use <name> | add | remove <name> | info [name]" ;;
            add_header)         echo "=== 添加新 GitLab Profile ===" ;;
            prompt_name)        printf "Profile 名称: " ;;
            err_name_empty)     echo -e "${_GP_RED}错误:${_GP_NC} 名称不能为空" ;;
            err_reserved)       echo -e "${_GP_RED}错误:${_GP_NC} '${1}' 是保留子命令名" ;;
            err_exists)         echo -e "${_GP_RED}错误:${_GP_NC} Profile '${1}' 已存在" ;;
            prompt_url)         printf "GitLab URL: " ;;
            err_url_empty)      echo -e "${_GP_RED}错误:${_GP_NC} GitLab URL 不能为空" ;;
            prompt_token)       printf "Personal Access Token (api scope): " ;;
            err_token_empty)    echo -e "${_GP_RED}错误:${_GP_NC} Token 不能为空" ;;
            validating)         echo -n "验证 Token... " ;;
            token_valid)        echo -e "${_GP_GREEN}✓${_GP_NC} 有效 (用户: ${1})" ;;
            token_invalid)      echo -e "${_GP_RED}✗${_GP_NC} 验证失败 (HTTP ${1})" ;;
            confirm_continue)   printf "仍要继续创建? [y/N]: " ;;
            prompt_dev)         printf "开发者名称 [${1}]: " ;;
            prompt_email)       printf "Git 邮箱: " ;;
            err_email_empty)    echo -e "${_GP_RED}错误:${_GP_NC} Git 邮箱不能为空" ;;
            created)            echo -e "${_GP_GREEN}✓${_GP_NC} Profile '${1}' 已创建: ${2}" ;;
            switch_hint)        echo "  使用 gitlab-use ${1} 切换" ;;
            usage_remove)       echo "用法: gitlab-use remove <name>" ;;
            err_not_found)      echo -e "${_GP_RED}错误:${_GP_NC} Profile '${1}' 不存在" ;;
            err_del_active)     echo -e "${_GP_RED}错误:${_GP_NC} 不能删除当前激活的 profile '${1}'" ;;
            hint_switch_first)  echo "提示: 先切换到其他 profile，再删除" ;;
            deleted)            echo -e "${_GP_GREEN}✓${_GP_NC} Profile '${1}' 已删除" ;;
            err_no_active)      echo -e "${_GP_RED}错误:${_GP_NC} 没有激活的 profile，请指定名称: gitlab-use info <name>" ;;
            status_active)      echo -e "状态:       ${_GP_GREEN}✓ 激活中${_GP_NC}" ;;
            label_dev)          echo "开发者:     ${1}" ;;
            label_email)        echo "邮箱:       ${1}" ;;
            token_status)       echo -n "Token 状态: " ;;
            token_ok)           echo -e "${_GP_GREEN}✓ 有效${_GP_NC}" ;;
            token_bad)          echo -e "${_GP_RED}✗ 无效 (HTTP ${1})${_GP_NC}" ;;
            avail_list)         echo "可用: ${1}" ;;
            hint_add)           echo "使用 gitlab-use add 创建新 profile" ;;
            warn_token)         echo -e "${_GP_YELLOW}⚠ 警告:${_GP_NC} Token 验证失败 (HTTP ${1})，可能已过期" ;;
            err_template)       echo -e "${_GP_RED}错误:${_GP_NC} 模板文件不存在: ${1}" ;;
            hint_reinstall)     echo "请重新运行 install.sh" ;;
        esac
    fi
}

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
        _gp_msg err_template "${_GP_TEMPLATE}"
        _gp_msg hint_reinstall
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
    _gp_msg current "${_GITLAB_PROFILE_ACTIVE:-none}"
    _gp_msg available
    local count=0
    local _pname
    for f in "${_GP_PROFILE_DIR}"/*.sh; do
        [[ -f "$f" ]] || continue
        _pname="$(basename "$f" .sh)"
        count=$((count + 1))
        if [[ "${_pname}" == "${_GITLAB_PROFILE_ACTIVE:-}" ]]; then
            echo -e "  ${_GP_GREEN}*${_GP_NC} ${_pname}  $(_gp_msg active)"
        else
            echo "    ${_pname}"
        fi
    done
    if [[ $count -eq 0 ]]; then
        _gp_msg no_profile
    fi
    echo ""
    _gp_msg usage_cmd
}

# ── 子命令: 交互式添加 ──
_gitlab_use_add() {
    _gp_msg add_header
    echo ""

    local p_name p_url p_token p_dev p_email p_dev_default

    _gp_msg prompt_name
    read -r p_name
    [[ -z "$p_name" ]] && _gp_msg err_name_empty && return 1
    [[ "$p_name" =~ ^(add|remove|info)$ ]] && _gp_msg err_reserved "${p_name}" && return 1

    if [[ -f "${_GP_PROFILE_DIR}/${p_name}.sh" ]]; then
        _gp_msg err_exists "${p_name}"
        return 1
    fi

    _gp_msg prompt_url
    read -r p_url
    [[ -z "$p_url" ]] && _gp_msg err_url_empty && return 1

    _gp_msg prompt_token
    read -r p_token
    [[ -z "$p_token" ]] && _gp_msg err_token_empty && return 1

    # Validate token
    _gp_msg validating
    local http_code
    http_code=$(_gitlab_validate_token "$p_url" "$p_token")
    if [[ "$http_code" == "200" ]]; then
        local username
        username=$(_gitlab_get_username "$p_url" "$p_token")
        _gp_msg token_valid "${username}"
        p_dev_default="${username:-${p_name}}"
    else
        _gp_msg token_invalid "${http_code}"
        _gp_msg confirm_continue
        local confirm
        read -r confirm
        [[ "$confirm" != [yY] ]] && return 1
        p_dev_default="${p_name}"
    fi

    _gp_msg prompt_dev "${p_dev_default}"
    read -r p_dev
    p_dev="${p_dev:-${p_dev_default}}"

    _gp_msg prompt_email
    read -r p_email
    [[ -z "$p_email" ]] && _gp_msg err_email_empty && return 1

    # Generate profile
    _gitlab_create_profile "$p_name" "$p_url" "$p_token" "$p_dev" "$p_email" || return 1

    echo ""
    _gp_msg created "${p_name}" "${_GP_PROFILE_DIR}/${p_name}.sh"
    _gp_msg switch_hint "${p_name}"
}

# ── 子命令: 删除 ──
_gitlab_use_remove() {
    local target="$1"
    [[ -z "$target" ]] && _gp_msg usage_remove && return 1

    if [[ ! -f "${_GP_PROFILE_DIR}/${target}.sh" ]]; then
        _gp_msg err_not_found "${target}"
        return 1
    fi

    if [[ "${target}" == "${_GITLAB_PROFILE_ACTIVE:-}" ]]; then
        _gp_msg err_del_active "${target}"
        _gp_msg hint_switch_first
        return 1
    fi

    rm "${_GP_PROFILE_DIR}/${target}.sh"
    _gp_msg deleted "${target}"
}

# ── 子命令: 详情 ──
_gitlab_use_info() {
    local target="${1:-${_GITLAB_PROFILE_ACTIVE:-}}"
    [[ -z "$target" ]] && _gp_msg err_no_active && return 1

    local pfile="${_GP_PROFILE_DIR}/${target}.sh"
    [[ ! -f "$pfile" ]] && _gp_msg err_not_found "${target}" && return 1

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
    [[ "${target}" == "${_GITLAB_PROFILE_ACTIVE:-}" ]] && _gp_msg status_active
    echo "GitLab URL: ${info_url}"
    echo "Token:      ${masked_token}"
    _gp_msg label_dev "${info_dev}"
    _gp_msg label_email "${info_email}"

    # Validate token
    _gp_msg token_status
    local http_code
    http_code=$(_gitlab_validate_token "$info_url" "$info_token")
    if [[ "$http_code" == "200" ]]; then
        _gp_msg token_ok
    else
        _gp_msg token_bad "${http_code}"
    fi
}

# ── 子命令: 切换 ──
_gitlab_use_switch() {
    local name="$1"
    local profile="${_GP_PROFILE_DIR}/${name}.sh"

    if [[ ! -f "${profile}" ]]; then
        echo -e "${_GP_RED}Profile not found:${_GP_NC} ${name}"
        _gp_msg avail_list "$(ls "${_GP_PROFILE_DIR}"/*.sh 2>/dev/null | xargs -I{} basename {} .sh | tr '\n' ' ')"
        _gp_msg hint_add
        return 1
    fi

    source "${profile}"

    # Validate token after switch
    local http_code
    http_code=$(_gitlab_validate_token "${GITLAB_URL}" "${GITLAB_TOKEN}")
    if [[ "$http_code" != "200" ]]; then
        _gp_msg warn_token "${http_code}"
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
