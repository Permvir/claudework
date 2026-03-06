#!/usr/bin/env bash
# SDD Workflow — 配置加载器
# 加载 ~/.claude/sdd-config.sh 用户配置，缺省值兜底
# 用法：source 本文件，或 bash config.sh --export 验证配置

set -euo pipefail

# 防止重复加载（高频 source 时跳过重复检测）
if [[ "${_SDD_CONFIG_LOADED:-}" == "true" && "${1:-}" != "--export" ]]; then
    return 0 2>/dev/null || true
fi

# ── 语言检测 ──
if [[ "${LANG:-}" != zh_CN* && "${LANG:-}" != zh_TW* ]]; then
  _SDD_LANG=en
else
  _SDD_LANG=zh
fi

# 保存环境变量（优先级高于配置文件）
_env_GITLAB_URL="${GITLAB_URL:-}"
_env_GITLAB_TOKEN="${GITLAB_TOKEN:-}"
_env_DEVELOPER_NAME="${DEVELOPER_NAME:-}"

# ─── gitlab_profiles 自动检测（基于 git remote） ────────────
# 如果环境变量未设置，尝试从 git remote origin 匹配 gitlab profile
if [[ -z "${_env_GITLAB_URL}" ]]; then
    _gp_dir="${HOME}/.claude/gitlab-profiles"
    if [[ -d "${_gp_dir}" ]] && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        _remote_url=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ -n "${_remote_url}" ]]; then
            # 提取主机名（支持 HTTPS 和 SSH 格式）
            if [[ "${_remote_url}" =~ ^https?:// ]]; then
                _remote_host="${_remote_url#*://}"
                _remote_host="${_remote_host%%/*}"
                _remote_host="${_remote_host%%:*}"
            elif [[ "${_remote_url}" =~ ^git@ ]]; then
                _remote_host="${_remote_url#git@}"
                _remote_host="${_remote_host%%:*}"
            fi

            if [[ -n "${_remote_host:-}" ]]; then
                for _pfile in "${_gp_dir}"/*.sh; do
                    [[ -f "${_pfile}" ]] || continue
                    _p_url=$(grep '^export GITLAB_URL=' "${_pfile}" 2>/dev/null | head -1 | sed 's/^export GITLAB_URL="//' | sed 's/"$//')
                    if [[ -n "${_p_url}" ]] && [[ "${_p_url}" == *"${_remote_host}"* ]]; then
                        # 匹配成功，提取连接信息
                        _env_GITLAB_URL="${_p_url}"
                        _env_GITLAB_TOKEN=$(grep '^export GITLAB_TOKEN=' "${_pfile}" 2>/dev/null | head -1 | sed 's/^export GITLAB_TOKEN="//' | sed 's/"$//')
                        _env_DEVELOPER_NAME=$(grep '^export DEVELOPER_NAME=' "${_pfile}" 2>/dev/null | head -1 | sed 's/^export DEVELOPER_NAME="//' | sed 's/"$//')
                        break
                    fi
                done
            fi
        fi
    fi
fi

# 加载用户配置（如果存在）
USER_CONFIG="${HOME}/.claude/sdd-config.sh"
if [[ -f "${USER_CONFIG}" ]]; then
    source "${USER_CONFIG}"
fi

# 环境变量覆盖配置文件（CI/CD 场景常用）
[[ -n "${_env_GITLAB_URL}" ]] && GITLAB_URL="${_env_GITLAB_URL}"
[[ -n "${_env_GITLAB_TOKEN}" ]] && GITLAB_TOKEN="${_env_GITLAB_TOKEN}"
[[ -n "${_env_DEVELOPER_NAME}" ]] && DEVELOPER_NAME="${_env_DEVELOPER_NAME}"

# ─── 默认值兜底 ────────────────────────────────────────────
GITLAB_URL="${GITLAB_URL:-https://your-gitlab.example.com}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"

# 确保 GitLab 域名不走代理（从 GITLAB_URL 提取主机名追加到 no_proxy）
if [[ -n "${GITLAB_URL}" ]]; then
    if [[ ! "${GITLAB_URL}" =~ ^https?:// ]]; then
        if [[ "${_SDD_LANG}" == "en" ]]; then
            echo "⚠ SDD: GITLAB_URL format invalid (missing http:// or https:// prefix): ${GITLAB_URL}" >&2
        else
            echo "⚠ SDD: GITLAB_URL 格式不正确（缺少 http:// 或 https:// 前缀）: ${GITLAB_URL}" >&2
        fi
    else
        _gitlab_host="${GITLAB_URL#*://}"  # 去掉 scheme
        _gitlab_host="${_gitlab_host%%/*}"  # 去掉路径
        _gitlab_host="${_gitlab_host%%:*}"  # 去掉端口
        if [[ -n "${_gitlab_host}" ]]; then
            if [[ ! "${no_proxy:-}" == *"${_gitlab_host}"* ]]; then
                export no_proxy="${no_proxy:+${no_proxy},}${_gitlab_host}"
            fi
        fi
    fi
fi

# 开发者名称：优先配置 > git config
if [[ -z "${DEVELOPER_NAME:-}" ]]; then
    DEVELOPER_NAME=$(git config user.name 2>/dev/null || echo "")
fi

# Git 分支管理
DEFAULT_BASE_BRANCH="${DEFAULT_BASE_BRANCH:-dev}"
DEFAULT_BRANCH_TYPE="${DEFAULT_BRANCH_TYPE:-dev}"

# 自动检测：如果远程不存在 dev 分支，回退到 master
# 仅当默认值为 dev 且处于 git 仓库中时检测（用户显式配置其他值时不干预）
# 检测结果缓存 5 分钟，避免每次 source 都执行 git ls-remote 网络调用
if [[ "${DEFAULT_BASE_BRANCH}" == "dev" ]] && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    # 使用 md5 hash 避免不同路径（如 /a/b 和 /a_b）产生相同 cache ID
    _repo_toplevel=$(git rev-parse --show-toplevel 2>/dev/null || echo "unknown")
    if command -v md5sum &>/dev/null; then
        _repo_id=$(echo -n "${_repo_toplevel}" | md5sum | cut -d' ' -f1)
    elif command -v md5 &>/dev/null; then
        _repo_id=$(echo -n "${_repo_toplevel}" | md5 -q)
    else
        _repo_id=$(echo -n "${_repo_toplevel}" | sed 's/[^a-zA-Z0-9]/_/g')
    fi
    _cache_dir="${HOME}/.cache/sdd"
    [[ -d "${_cache_dir}" ]] || mkdir -p "${_cache_dir}"
    _cache_file="${_cache_dir}/branch-cache-${_repo_id}"
    _cache_ttl="${SDD_CACHE_TTL:-300}"
    _needs_check=true

    if [[ -f "${_cache_file}" ]]; then
        _cache_time=$(head -1 "${_cache_file}" 2>/dev/null || echo 0)
        _now=$(date +%s)
        if [[ $((_now - _cache_time)) -lt ${_cache_ttl} ]]; then
            _cached_branch=$(tail -1 "${_cache_file}" 2>/dev/null)
            if [[ -n "${_cached_branch}" ]]; then
                DEFAULT_BASE_BRANCH="${_cached_branch}"
                _needs_check=false
            fi
        fi
    fi

    if [[ "${_needs_check}" == "true" ]]; then
        if _ls_remote_output=$(git ls-remote --heads origin dev 2>&1); then
            if ! echo "${_ls_remote_output}" | grep -q "refs/heads/dev"; then
                DEFAULT_BASE_BRANCH="master"
                if [[ "${_SDD_LANG}" == "en" ]]; then
                    echo "ℹ SDD: No remote dev branch, base branch auto-fallback to master" >&2
                else
                    echo "ℹ SDD: 远程无 dev 分支，基线自动回退为 master" >&2
                fi
            fi
        else
            if [[ "${_SDD_LANG}" == "en" ]]; then
                echo "⚠ SDD: git ls-remote failed (network or permission issue), keeping DEFAULT_BASE_BRANCH=${DEFAULT_BASE_BRANCH}" >&2
            else
                echo "⚠ SDD: git ls-remote 失败（网络或权限问题），保持 DEFAULT_BASE_BRANCH=${DEFAULT_BASE_BRANCH}" >&2
            fi
        fi
        # 原子写入缓存（mktemp + mv 避免并发写入和中断导致文件损坏）
        _cache_tmp=$(mktemp "${_cache_file}.XXXXXX" 2>/dev/null || echo "${_cache_file}.$$")
        { echo "$(date +%s)"; echo "${DEFAULT_BASE_BRANCH}"; } > "${_cache_tmp}" 2>/dev/null && mv "${_cache_tmp}" "${_cache_file}" 2>/dev/null || rm -f "${_cache_tmp}" 2>/dev/null
    fi
fi
# 注意：分支模式含 {} 占位符，不能用 ${VAR:-default} 语法（bash 大括号匹配冲突）
if [[ -z "${BRANCH_PATTERN_DEV:-}" ]]; then
    BRANCH_PATTERN_DEV='{base_branch}-{developer}-{issue_iid}'
fi
if [[ -z "${BRANCH_PATTERN_HOTFIX:-}" ]]; then
    BRANCH_PATTERN_HOTFIX='hotfix-{developer}-{issue_iid}'
fi
if [[ -z "${BRANCH_PATTERN_FEATURE:-}" ]]; then
    BRANCH_PATTERN_FEATURE='feature-{developer}-{issue_iid}'
fi

WORKFLOW_LABEL_BACKLOG="${WORKFLOW_LABEL_BACKLOG:-workflow::backlog}"
WORKFLOW_LABEL_START="${WORKFLOW_LABEL_START:-workflow::start}"
WORKFLOW_LABEL_DEV="${WORKFLOW_LABEL_DEV:-workflow::in dev}"
WORKFLOW_LABEL_EVAL="${WORKFLOW_LABEL_EVAL:-workflow::evaluation}"
WORKFLOW_LABEL_DONE="${WORKFLOW_LABEL_DONE:-workflow::done}"

MR_REMOVE_SOURCE_BRANCH="${MR_REMOVE_SOURCE_BRANCH:-true}"
MR_SQUASH="${MR_SQUASH:-true}"

# ─── 兼容旧版 BRANCH_PATTERN ──────────────────────────────
# 如果用户仍配置了旧版 BRANCH_PATTERN，将其作为 dev 类型的默认模式
if [[ -n "${BRANCH_PATTERN:-}" && "${BRANCH_PATTERN}" != "sdd/{issue_iid}" ]]; then
    if [[ "${BRANCH_PATTERN_DEV}" != '{base_branch}-{developer}-{issue_iid}' ]]; then
        if [[ "${_SDD_LANG}" == "en" ]]; then
            echo "⚠ SDD: Both BRANCH_PATTERN and BRANCH_PATTERN_DEV are set. Ignoring deprecated BRANCH_PATTERN, using BRANCH_PATTERN_DEV=\"${BRANCH_PATTERN_DEV}\"" >&2
        else
            echo "⚠ SDD: 同时配置了 BRANCH_PATTERN 和 BRANCH_PATTERN_DEV，忽略已弃用的 BRANCH_PATTERN，使用 BRANCH_PATTERN_DEV=\"${BRANCH_PATTERN_DEV}\"" >&2
        fi
    else
        BRANCH_PATTERN_DEV="${BRANCH_PATTERN}"
        if [[ "${_SDD_LANG}" == "en" ]]; then
            echo "⚠ SDD: BRANCH_PATTERN is deprecated, use BRANCH_PATTERN_DEV instead. Compatibility will be removed on 2026-06-01." >&2
        else
            echo "⚠ SDD: BRANCH_PATTERN 已弃用，请改用 BRANCH_PATTERN_DEV。该兼容将于 2026-06-01 移除。" >&2
        fi
    fi
fi

# ─── 辅助函数 ──────────────────────────────────────────────

# 根据分支类型获取分支名
# 用法：get_branch_name <type> <issue_iid> [description]
get_branch_name() {
    local branch_type="${1:-${DEFAULT_BRANCH_TYPE}}"
    local issue_iid="$2"
    local description="${3:-}"

    if [[ -z "${DEVELOPER_NAME:-}" ]]; then
        if [[ "${_SDD_LANG}" == "en" ]]; then
            echo "Error: git config user.name not set, cannot generate branch name. Please run: git config user.name 'Your Name'" >&2
        else
            echo "错误: git config user.name 未设置，无法生成分支名。请先运行: git config user.name '你的名字'" >&2
        fi
        return 1
    fi

    local pattern
    case "${branch_type}" in
        dev)     pattern="${BRANCH_PATTERN_DEV}" ;;
        hotfix)  pattern="${BRANCH_PATTERN_HOTFIX}" ;;
        feature) pattern="${BRANCH_PATTERN_FEATURE}" ;;
        *)       pattern="${BRANCH_PATTERN_DEV}" ;;
    esac

    local name="${pattern}"
    name="${name//\{base_branch\}/${DEFAULT_BASE_BRANCH}}"
    name="${name//\{developer\}/${DEVELOPER_NAME}}"
    name="${name//\{issue_iid\}/${issue_iid}}"
    name="${name//\{description\}/${description}}"
    echo "${name}"
}

# 根据分支类型获取基线分支
# 用法：get_base_branch <type>
get_base_branch() {
    local branch_type="${1:-${DEFAULT_BRANCH_TYPE}}"
    case "${branch_type}" in
        dev)     echo "${DEFAULT_BASE_BRANCH}" ;;
        hotfix)  echo "master" ;;
        feature) echo "master" ;;
        *)       echo "${DEFAULT_BASE_BRANCH}" ;;
    esac
}

# 根据分支类型获取 MR 主目标分支
# 用法：get_primary_mr_target <type>
# 注：返回主 MR 目标。hotfix/feature 的双 MR 逻辑
# （同时合 dev + master）由 submit action 处理，此函数仅返回主目标。
get_primary_mr_target() {
    local branch_type="${1:-${DEFAULT_BRANCH_TYPE}}"
    case "${branch_type}" in
        hotfix)  echo "master" ;;
        feature) echo "master" ;;
        *)       echo "${DEFAULT_BASE_BRANCH}" ;;
    esac
}

# ─── 错误码规范（供其他脚本使用） ──────────────────────────
# 仅在未定义时设置（避免与 gitlab-api.sh 的 readonly 冲突）
if [[ -z "${SDD_EXIT_OK+x}" ]]; then
    SDD_EXIT_OK=0
    SDD_EXIT_ERROR=1
    SDD_EXIT_CONFIG=2
    SDD_EXIT_API=3
    SDD_EXIT_VALIDATION=4
    SDD_EXIT_GIT=5
fi

_SDD_CONFIG_LOADED=true

# ─── 子命令模式（直接运行时使用，无需 source）──────────────
# 用法：bash config.sh --get-branch-name <type> <issue_iid>
#       bash config.sh --get-base-branch <type>
#       bash config.sh --get-mr-target <type>
if [[ "${1:-}" == "--get-branch-name" ]]; then
    get_branch_name "${2:-dev}" "${3:-}"
    exit 0
fi
if [[ "${1:-}" == "--get-base-branch" ]]; then
    get_base_branch "${2:-dev}"
    exit 0
fi
if [[ "${1:-}" == "--get-mr-target" ]]; then
    get_primary_mr_target "${2:-dev}"
    exit 0
fi

# ─── 验证模式 ──────────────────────────────────────────────
if [[ "${1:-}" == "--export" ]]; then
    if [[ "${_SDD_LANG}" == "en" ]]; then
        echo "SDD Workflow Configuration:"
        echo ""
        echo "  [GitLab]"
        echo "  GITLAB_URL              = ${GITLAB_URL}"
        if [[ -z "${GITLAB_TOKEN}" || "${GITLAB_TOKEN}" == "YOUR_TOKEN_HERE" ]]; then
            echo "  GITLAB_TOKEN            = Not set"
        else
            echo "  GITLAB_TOKEN            = Set (${#GITLAB_TOKEN} chars)"
        fi
        echo ""
        echo "  [Developer]"
        if [[ -z "${DEVELOPER_NAME:-}" ]]; then
            echo "  DEVELOPER_NAME          = Not set  ⚠ Please run: git config user.name 'Your Name'"
        else
            echo "  DEVELOPER_NAME          = ${DEVELOPER_NAME}"
        fi
        echo ""
        echo "  [Git Branch Management]"
        echo "  DEFAULT_BASE_BRANCH     = ${DEFAULT_BASE_BRANCH}$(
            if [[ "${DEFAULT_BASE_BRANCH}" == "master" ]] && git rev-parse --is-inside-work-tree &>/dev/null 2>&1 && ! git rev-parse --verify "refs/remotes/origin/dev" &>/dev/null 2>&1; then
                echo " (auto-detected: no remote dev branch)"
            fi
        )"
        echo "  DEFAULT_BRANCH_TYPE     = ${DEFAULT_BRANCH_TYPE}"
        echo "  BRANCH_PATTERN_DEV      = ${BRANCH_PATTERN_DEV}"
        echo "  BRANCH_PATTERN_HOTFIX   = ${BRANCH_PATTERN_HOTFIX}"
        echo "  BRANCH_PATTERN_FEATURE  = ${BRANCH_PATTERN_FEATURE}"
        echo ""
        echo "  [Example Branch Names]"
        echo "  dev type    → $(get_branch_name dev 8)"
        echo "  hotfix type → $(get_branch_name hotfix 8)"
        echo "  feature type→ $(get_branch_name feature 8)"
        echo ""
        echo "  [Workflow Labels]"
        echo "  WORKFLOW_LABEL_BACKLOG  = ${WORKFLOW_LABEL_BACKLOG}"
        echo "  WORKFLOW_LABEL_START    = ${WORKFLOW_LABEL_START}"
        echo "  WORKFLOW_LABEL_DEV      = ${WORKFLOW_LABEL_DEV}"
        echo "  WORKFLOW_LABEL_EVAL     = ${WORKFLOW_LABEL_EVAL}"
        echo "  WORKFLOW_LABEL_DONE     = ${WORKFLOW_LABEL_DONE}"
        echo ""
        echo "  [MR Settings]"
        echo "  MR_REMOVE_SOURCE_BRANCH = ${MR_REMOVE_SOURCE_BRANCH}"
        echo "  MR_SQUASH               = ${MR_SQUASH}"

        if [[ -z "${GITLAB_TOKEN}" || "${GITLAB_TOKEN}" == "YOUR_TOKEN_HERE" ]]; then
            echo ""
            echo "⚠ GITLAB_TOKEN not configured. Edit ${USER_CONFIG}"
            exit 1
        fi
    else
        echo "SDD Workflow 配置："
        echo ""
        echo "  [GitLab]"
        echo "  GITLAB_URL              = ${GITLAB_URL}"
        if [[ -z "${GITLAB_TOKEN}" || "${GITLAB_TOKEN}" == "YOUR_TOKEN_HERE" ]]; then
            echo "  GITLAB_TOKEN            = 未设置"
        else
            echo "  GITLAB_TOKEN            = 已设置 (${#GITLAB_TOKEN} 字符)"
        fi
        echo ""
        echo "  [开发者]"
        if [[ -z "${DEVELOPER_NAME:-}" ]]; then
            echo "  DEVELOPER_NAME          = 未设置  ⚠ 请运行: git config user.name '你的名字'"
        else
            echo "  DEVELOPER_NAME          = ${DEVELOPER_NAME}"
        fi
        echo ""
        echo "  [Git 分支管理]"
        echo "  DEFAULT_BASE_BRANCH     = ${DEFAULT_BASE_BRANCH}$(
            if [[ "${DEFAULT_BASE_BRANCH}" == "master" ]] && git rev-parse --is-inside-work-tree &>/dev/null 2>&1 && ! git rev-parse --verify "refs/remotes/origin/dev" &>/dev/null 2>&1; then
                echo " (自动检测: 远程无 dev 分支)"
            fi
        )"
        echo "  DEFAULT_BRANCH_TYPE     = ${DEFAULT_BRANCH_TYPE}"
        echo "  BRANCH_PATTERN_DEV      = ${BRANCH_PATTERN_DEV}"
        echo "  BRANCH_PATTERN_HOTFIX   = ${BRANCH_PATTERN_HOTFIX}"
        echo "  BRANCH_PATTERN_FEATURE  = ${BRANCH_PATTERN_FEATURE}"
        echo ""
        echo "  [示例分支名]"
        echo "  dev 类型    → $(get_branch_name dev 8)"
        echo "  hotfix 类型 → $(get_branch_name hotfix 8)"
        echo "  feature 类型→ $(get_branch_name feature 8)"
        echo ""
        echo "  [Workflow 标签]"
        echo "  WORKFLOW_LABEL_BACKLOG  = ${WORKFLOW_LABEL_BACKLOG}"
        echo "  WORKFLOW_LABEL_START    = ${WORKFLOW_LABEL_START}"
        echo "  WORKFLOW_LABEL_DEV      = ${WORKFLOW_LABEL_DEV}"
        echo "  WORKFLOW_LABEL_EVAL     = ${WORKFLOW_LABEL_EVAL}"
        echo "  WORKFLOW_LABEL_DONE     = ${WORKFLOW_LABEL_DONE}"
        echo ""
        echo "  [MR 设置]"
        echo "  MR_REMOVE_SOURCE_BRANCH = ${MR_REMOVE_SOURCE_BRANCH}"
        echo "  MR_SQUASH               = ${MR_SQUASH}"

        if [[ -z "${GITLAB_TOKEN}" || "${GITLAB_TOKEN}" == "YOUR_TOKEN_HERE" ]]; then
            echo ""
            echo "⚠ GITLAB_TOKEN 未配置，请编辑 ${USER_CONFIG}"
            exit 1
        fi
    fi
fi
