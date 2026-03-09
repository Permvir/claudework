#!/usr/bin/env bash
# SDD Workflow — GitLab API 封装
# 用法：bash gitlab-api.sh <action> [args...]
#
# Actions:
#   parse-issue-url <url>                    — 从 URL 提取 project_path 和 issue_iid
#   parse-mr-url <url>                       — 从 MR URL 提取 project_path 和 mr_iid
#   parse-project-url <url>                  — 从项目 URL 提取 project_path
#   resolve-project-id <project_path>        — 从 project_path 获取 project_id
#   get-issue <project_id> <issue_iid>       — 获取 issue 详情
#   create-issue <project_id> <title> <description> [labels] — 创建 issue
#   get-issue-notes <project_id> <issue_iid> — 获取 issue 评论
#   add-issue-note <project_id> <issue_iid> <body> — 添加 issue 评论
#   update-issue-labels <project_id> <issue_iid> <add_labels> [remove_labels] — 更新标签
#   update-issue-description <project_id> <issue_iid> <description> — 更新 issue 描述
#   create-mr <project_id> <source> <target> <title> <description> [remove_source_branch] — 创建 MR
#   get-mr <project_id> <mr_iid>             — 获取 MR 详情
#   get-mr-changes <project_id> <mr_iid>     — 获取 MR 变更文件
#   add-mr-note <project_id> <mr_iid> <body> — 添加 MR 评论
#   set-mr-reviewers <project_id> <mr_iid> <reviewer_ids> — 设置 MR reviewer（逗号分隔的 user id）
#   resolve-user-id <project_id> <username>  — 从 username 获取 user_id
#   get-project-members <project_id>         — 获取项目成员
#   close-issue <project_id> <issue_iid>     — 关闭 issue
#   list-issue-related-mrs <project_id> <issue_iid> — 获取 issue 关联的 MR 列表（closed_by）
#   list-project-mrs <project_id> <source> <target> [state] — 按分支查询项目 MR 列表
#   get-mr-notes <project_id> <mr_iid>      — 获取 MR 评论列表
#   update-mr-note <project_id> <mr_iid> <note_id> <body> — 更新 MR 评论
#   reopen-issue <project_id> <issue_iid>  — 重新打开已关闭的 issue
#   list-project-issues <project_id> [state] [labels] — 获取项目 issue 列表（可选按状态和标签过滤）
#   update-issue-assignees <project_id> <issue_iid> <user_ids> — 设置 issue 指派人（逗号分隔的 user id）
#   get-project-namespace <project_id>       — 获取项目的 namespace 信息（group_id、kind、repo_name）
#   get-group-wiki-page <group_id> <slug>    — 获取 Group Wiki 页面内容

set -euo pipefail

# ─── 错误码规范 ──────────────────────────────────────────────
readonly SDD_EXIT_OK=0
readonly SDD_EXIT_ERROR=1
readonly SDD_EXIT_CONFIG=2
readonly SDD_EXIT_API=3
readonly SDD_EXIT_VALIDATION=4
readonly SDD_EXIT_GIT=5

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# ─── curl 能力检测 ────────────────────────────────────────────
# --fail-with-body 需要 curl >= 7.76.0，旧版本降级为 --fail
_CURL_FAIL_OPT="--fail"
_cv=$(curl --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ -n "${_cv}" ]]; then
    _cmaj=$(echo "$_cv" | cut -d. -f1)
    _cmin=$(echo "$_cv" | cut -d. -f2)
    if [[ "${_cmaj}" -ge 8 ]] || { [[ "${_cmaj}" -eq 7 ]] && [[ "${_cmin}" -ge 76 ]]; }; then
        _CURL_FAIL_OPT="--fail-with-body"
    fi
fi

# ─── 辅助函数 ──────────────────────────────────────────────

_check_token() {
    if [[ -z "${GITLAB_TOKEN}" || "${GITLAB_TOKEN}" == "YOUR_TOKEN_HERE" ]]; then
        echo '{"error": "GITLAB_TOKEN 未配置，请编辑 ~/.claude/sdd-config.sh"}' >&2
        exit ${SDD_EXIT_CONFIG}
    fi
}

_api() {
    local method="$1"
    local endpoint="$2"
    shift 2

    local url="${GITLAB_URL}/api/v4${endpoint}"
    local _response _exit_code _http_code
    local _curl_stderr_file
    _curl_stderr_file=$(mktemp "${TMPDIR:-/tmp}/sdd-curl.XXXXXX")

    for _attempt in 1 2; do
        _response=$(curl -s ${_CURL_FAIL_OPT} \
            -w '\n%{http_code}' \
            --connect-timeout 10 \
            --max-time 30 \
            --request "${method}" \
            --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
            --header "Content-Type: application/json" \
            "$@" \
            "${url}" 2>"${_curl_stderr_file}") && _exit_code=0 || _exit_code=$?

        # 空响应防护（curl 连接失败等场景）
        if [[ -z "${_response}" ]]; then
            _http_code="000"
            _response=""
            break
        fi

        _http_code=$(echo "${_response}" | tail -1)
        _response=$(echo "${_response}" | sed '$d')

        # 仅在 5xx 或 curl 超时（exit 28）时重试一次
        if [[ ${_attempt} -eq 1 ]] && { [[ "${_http_code}" =~ ^5[0-9]{2}$ ]] || [[ ${_exit_code} -eq 28 ]]; }; then
            echo "⚠ SDD API: ${method} ${endpoint} 失败（HTTP ${_http_code}，exit ${_exit_code}），2 秒后重试..." >&2
            sleep 2
            continue
        fi
        break
    done

    if [[ ${_exit_code} -ne 0 ]]; then
        [[ -n "${_response}" ]] && echo "${_response}" >&2
        local _curl_err
        _curl_err=$(<"${_curl_stderr_file}" 2>/dev/null) || true
        [[ -n "${_curl_err}" ]] && echo "curl: ${_curl_err}" >&2
        echo "⚠ SDD: ${method} ${endpoint} 失败（HTTP ${_http_code}，curl exit ${_exit_code}）" >&2
        rm -f "${_curl_stderr_file}" 2>/dev/null
        return ${SDD_EXIT_API}
    fi
    rm -f "${_curl_stderr_file}" 2>/dev/null
    echo "${_response}"
}

_url_encode() {
    python3 "${SCRIPT_DIR}/json-helper.py" url-encode "$1"
}

# 自动分页获取所有结果（合并为单个 JSON 数组）
# 用法：_api_paginated GET "/projects/123/issues/8/notes?sort=asc"
_api_paginated() {
    local method="$1"
    local endpoint="$2"
    shift 2

    local page=1
    local per_page=100
    local -a _all_pages=()
    local sep="?"
    [[ "${endpoint}" == *"?"* ]] && sep="&"

    while true; do
        local page_result
        if ! page_result=$(_api "${method}" "${endpoint}${sep}per_page=${per_page}&page=${page}" "$@"); then
            # 首页失败直接返回错误
            [[ ${page} -eq 1 ]] && return 1
            # 非首页失败：输出警告并返回已获取的部分数据
            echo "⚠ SDD: 分页请求第 ${page} 页失败，返回前 $((page - 1)) 页数据" >&2
            break
        fi

        _all_pages+=("${page_result}")

        local count
        count=$(echo "${page_result}" | python3 "${SCRIPT_DIR}/json-helper.py" count || echo 0)

        # 不足一页说明已是最后一页
        if [[ "${count}" -lt ${per_page} ]]; then
            break
        fi

        page=$((page + 1))
        # 安全上限，防止无限循环
        if [[ ${page} -gt 10 ]]; then
            echo "⚠ SDD: 分页超过 10 页（${page}00+ 条记录），已截断" >&2
            break
        fi
    done

    # 单页直接输出，多页一次性合并（避免每页启动 python3）
    # 假设每页 API 响应为单行紧凑 JSON（GitLab API 默认行为）
    if [[ ${#_all_pages[@]} -eq 0 ]]; then
        echo "[]"
    elif [[ ${#_all_pages[@]} -eq 1 ]]; then
        echo "${_all_pages[0]}"
    else
        printf '%s\n' "${_all_pages[@]}" | python3 "${SCRIPT_DIR}/json-helper.py" merge-arrays
    fi
}

# ─── Actions ───────────────────────────────────────────────

parse_issue_url() {
    local url="$1"
    python3 "${SCRIPT_DIR}/json-helper.py" parse-url issue "${url}" "${GITLAB_URL}"
}

parse_mr_url() {
    local url="$1"
    python3 "${SCRIPT_DIR}/json-helper.py" parse-url mr "${url}" "${GITLAB_URL}"
}

parse_project_url() {
    local url="$1"
    python3 "${SCRIPT_DIR}/json-helper.py" parse-url project "${url}"
}

resolve_project_id() {
    local project_path="$1"
    local encoded response
    encoded=$(_url_encode "${project_path}")
    if ! response=$(_api GET "/projects/${encoded}"); then
        echo "{\"error\": \"无法获取项目信息: ${project_path}\"}" >&2
        return ${SDD_EXIT_API}
    fi
    echo "${response}" | python3 "${SCRIPT_DIR}/json-helper.py" resolve-project
}

get_issue() {
    local project_id="$1"
    local issue_iid="$2"
    _api GET "/projects/${project_id}/issues/${issue_iid}"
}

create_issue() {
    local project_id="$1"
    local title="$2"
    local description="$3"
    local labels="${4:-}"

    local payload
    payload=$(printf '%s' "${description}" | python3 "${SCRIPT_DIR}/json-helper.py" issue-payload "${title}" "${labels}")

    _api POST "/projects/${project_id}/issues" \
        --data "${payload}"
}

get_issue_notes() {
    local project_id="$1"
    local issue_iid="$2"
    _api_paginated GET "/projects/${project_id}/issues/${issue_iid}/notes?sort=asc"
}

add_issue_note() {
    local project_id="$1"
    local issue_iid="$2"
    local body="$3"
    _api POST "/projects/${project_id}/issues/${issue_iid}/notes" \
        --data "$(printf '%s' "${body}" | python3 "${SCRIPT_DIR}/json-helper.py" body-payload)"
}

update_issue_labels() {
    local project_id="$1"
    local issue_iid="$2"
    local add_labels="$3"
    local remove_labels="${4:-}"

    local payload
    payload=$(python3 "${SCRIPT_DIR}/json-helper.py" labels-payload "${add_labels}" "${remove_labels}")

    _api PUT "/projects/${project_id}/issues/${issue_iid}" \
        --data "${payload}"
}

update_issue_description() {
    local project_id="$1"
    local issue_iid="$2"
    local description="$3"
    local payload
    payload=$(printf '%s' "${description}" | python3 "${SCRIPT_DIR}/json-helper.py" description-payload)
    _api PUT "/projects/${project_id}/issues/${issue_iid}" \
        --data "${payload}"
}

create_mr() {
    local project_id="$1"
    local source_branch="$2"
    local target_branch="$3"
    local title="$4"
    local description="$5"
    local remove_source_branch="${6:-${MR_REMOVE_SOURCE_BRANCH}}"

    local payload
    payload=$(printf '%s' "${description}" | python3 "${SCRIPT_DIR}/json-helper.py" mr-payload \
        "${source_branch}" "${target_branch}" "${title}" \
        "${remove_source_branch}" "${MR_SQUASH}")

    _api POST "/projects/${project_id}/merge_requests" \
        --data "${payload}"
}

get_mr() {
    local project_id="$1"
    local mr_iid="$2"
    _api GET "/projects/${project_id}/merge_requests/${mr_iid}"
}

get_mr_changes() {
    local project_id="$1"
    local mr_iid="$2"
    _api GET "/projects/${project_id}/merge_requests/${mr_iid}/changes"
}

add_mr_note() {
    local project_id="$1"
    local mr_iid="$2"
    local body="$3"
    _api POST "/projects/${project_id}/merge_requests/${mr_iid}/notes" \
        --data "$(printf '%s' "${body}" | python3 "${SCRIPT_DIR}/json-helper.py" body-payload)"
}

set_mr_reviewers() {
    local project_id="$1"
    local mr_iid="$2"
    local reviewer_ids="$3"  # 逗号分隔的 user id，如 "22" 或 "22,33"

    local payload
    payload=$(python3 "${SCRIPT_DIR}/json-helper.py" ids-payload reviewer_ids "${reviewer_ids}")

    _api PUT "/projects/${project_id}/merge_requests/${mr_iid}" \
        --data "${payload}"
}

resolve_user_id() {
    local project_id="$1"
    local username="$2"
    local encoded_username response
    encoded_username=$(_url_encode "${username}")
    if ! response=$(_api GET "/projects/${project_id}/members/all?search=${encoded_username}&per_page=20"); then
        echo "{\"error\": \"无法查询项目成员: ${username}\"}" >&2
        return ${SDD_EXIT_API}
    fi
    echo "${response}" | python3 "${SCRIPT_DIR}/json-helper.py" find-member "${username}"
}

get_project_members() {
    local project_id="$1"
    _api_paginated GET "/projects/${project_id}/members/all"
}

close_issue() {
    local project_id="$1"
    local issue_iid="$2"
    _api PUT "/projects/${project_id}/issues/${issue_iid}" \
        --data '{"state_event": "close"}'
}

list_issue_related_mrs() {
    local project_id="$1"
    local issue_iid="$2"
    _api GET "/projects/${project_id}/issues/${issue_iid}/closed_by"
}

list_project_mrs() {
    local project_id="$1"
    local source_branch="$2"
    local target_branch="$3"
    local state="${4:-opened}"
    local encoded_source encoded_target
    encoded_source=$(_url_encode "${source_branch}")
    encoded_target=$(_url_encode "${target_branch}")
    _api GET "/projects/${project_id}/merge_requests?source_branch=${encoded_source}&target_branch=${encoded_target}&state=${state}&per_page=20"
}

get_mr_notes() {
    local project_id="$1"
    local mr_iid="$2"
    _api_paginated GET "/projects/${project_id}/merge_requests/${mr_iid}/notes?sort=desc"
}

update_mr_note() {
    local project_id="$1"
    local mr_iid="$2"
    local note_id="$3"
    local body="$4"
    _api PUT "/projects/${project_id}/merge_requests/${mr_iid}/notes/${note_id}" \
        --data "$(printf '%s' "${body}" | python3 "${SCRIPT_DIR}/json-helper.py" body-payload)"
}

reopen_issue() {
    local project_id="$1"
    local issue_iid="$2"
    _api PUT "/projects/${project_id}/issues/${issue_iid}" \
        --data '{"state_event": "reopen"}'
}

list_project_issues() {
    local project_id="$1"
    local state="${2:-opened}"
    local labels="${3:-}"
    local endpoint="/projects/${project_id}/issues?state=${state}"
    if [[ -n "${labels}" ]]; then
        local encoded_labels
        encoded_labels=$(_url_encode "${labels}")
        endpoint="${endpoint}&labels=${encoded_labels}"
    fi
    _api_paginated GET "${endpoint}"
}

get_project_namespace() {
    local project_id="$1"
    local response
    if ! response=$(_api GET "/projects/${project_id}"); then
        echo "{\"error\": \"无法获取项目信息: ${project_id}\"}" >&2
        return ${SDD_EXIT_API}
    fi
    echo "${response}" | python3 "${SCRIPT_DIR}/json-helper.py" get-project-namespace
}

get_group_wiki_page() {
    local group_id="$1"
    local slug="$2"
    local encoded
    encoded=$(_url_encode "${slug}")
    _api GET "/groups/${group_id}/wikis/${encoded}"
}

update_issue_assignees() {
    local project_id="$1"
    local issue_iid="$2"
    local user_ids="$3"  # 逗号分隔的 user id，如 "22" 或 "22,33"；传空字符串清空指派

    local payload
    payload=$(python3 "${SCRIPT_DIR}/json-helper.py" ids-payload assignee_ids "${user_ids}")

    _api PUT "/projects/${project_id}/issues/${issue_iid}" \
        --data "${payload}"
}

# ─── 入口 ─────────────────────────────────────────────────

main() {
    local action="${1:-}"
    shift || true

    case "${action}" in
        parse-issue-url)
            [[ $# -ge 1 ]] || { echo "用法: gitlab-api.sh parse-issue-url <url>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            parse_issue_url "$1"
            exit 0
            ;;
        parse-mr-url)
            [[ $# -ge 1 ]] || { echo "用法: gitlab-api.sh parse-mr-url <url>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            parse_mr_url "$1"
            exit 0
            ;;
        parse-project-url)
            [[ $# -ge 1 ]] || { echo "用法: gitlab-api.sh parse-project-url <url>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            parse_project_url "$1"
            exit 0
            ;;
    esac

    _check_token

    case "${action}" in
        resolve-project-id)
            [[ $# -ge 1 ]] || { echo "用法: gitlab-api.sh resolve-project-id <project_path>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            resolve_project_id "$1"
            ;;
        get-issue)
            [[ $# -ge 2 ]] || { echo "用法: gitlab-api.sh get-issue <project_id> <issue_iid>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            get_issue "$1" "$2"
            ;;
        create-issue)
            [[ $# -ge 3 ]] || { echo "用法: gitlab-api.sh create-issue <project_id> <title> <description> [labels]" >&2; exit ${SDD_EXIT_VALIDATION}; }
            create_issue "$@"
            ;;
        get-issue-notes)
            [[ $# -ge 2 ]] || { echo "用法: gitlab-api.sh get-issue-notes <project_id> <issue_iid>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            get_issue_notes "$1" "$2"
            ;;
        add-issue-note)
            [[ $# -ge 3 ]] || { echo "用法: gitlab-api.sh add-issue-note <project_id> <issue_iid> <body>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            add_issue_note "$1" "$2" "$3"
            ;;
        update-issue-labels)
            [[ $# -ge 3 ]] || { echo "用法: gitlab-api.sh update-issue-labels <project_id> <issue_iid> <add_labels> [remove_labels]" >&2; exit ${SDD_EXIT_VALIDATION}; }
            update_issue_labels "$@"
            ;;
        update-issue-description)
            [[ $# -ge 3 ]] || { echo "用法: gitlab-api.sh update-issue-description <project_id> <issue_iid> <description>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            update_issue_description "$1" "$2" "$3"
            ;;
        create-mr)
            [[ $# -ge 5 ]] || { echo "用法: gitlab-api.sh create-mr <project_id> <source> <target> <title> <description> [remove_source_branch]" >&2; exit ${SDD_EXIT_VALIDATION}; }
            create_mr "$1" "$2" "$3" "$4" "$5" "${6:-}"
            ;;
        get-mr)
            [[ $# -ge 2 ]] || { echo "用法: gitlab-api.sh get-mr <project_id> <mr_iid>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            get_mr "$1" "$2"
            ;;
        get-mr-changes)
            [[ $# -ge 2 ]] || { echo "用法: gitlab-api.sh get-mr-changes <project_id> <mr_iid>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            get_mr_changes "$1" "$2"
            ;;
        add-mr-note)
            [[ $# -ge 3 ]] || { echo "用法: gitlab-api.sh add-mr-note <project_id> <mr_iid> <body>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            add_mr_note "$1" "$2" "$3"
            ;;
        set-mr-reviewers)
            [[ $# -ge 3 ]] || { echo "用法: gitlab-api.sh set-mr-reviewers <project_id> <mr_iid> <reviewer_ids>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            set_mr_reviewers "$1" "$2" "$3"
            ;;
        resolve-user-id)
            [[ $# -ge 2 ]] || { echo "用法: gitlab-api.sh resolve-user-id <project_id> <username>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            resolve_user_id "$1" "$2"
            ;;
        get-project-members)
            [[ $# -ge 1 ]] || { echo "用法: gitlab-api.sh get-project-members <project_id>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            get_project_members "$1"
            ;;
        close-issue)
            [[ $# -ge 2 ]] || { echo "用法: gitlab-api.sh close-issue <project_id> <issue_iid>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            close_issue "$1" "$2"
            ;;
        list-issue-related-mrs)
            [[ $# -ge 2 ]] || { echo "用法: gitlab-api.sh list-issue-related-mrs <project_id> <issue_iid>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            list_issue_related_mrs "$1" "$2"
            ;;
        reopen-issue)
            [[ $# -ge 2 ]] || { echo "用法: gitlab-api.sh reopen-issue <project_id> <issue_iid>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            reopen_issue "$1" "$2"
            ;;
        update-issue-assignees)
            [[ $# -ge 3 ]] || { echo "用法: gitlab-api.sh update-issue-assignees <project_id> <issue_iid> <user_ids>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            update_issue_assignees "$1" "$2" "$3"
            ;;
        get-project-namespace)
            [[ $# -ge 1 ]] || { echo "用法: gitlab-api.sh get-project-namespace <project_id>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            get_project_namespace "$1"
            ;;
        get-group-wiki-page)
            [[ $# -ge 2 ]] || { echo "用法: gitlab-api.sh get-group-wiki-page <group_id> <slug>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            get_group_wiki_page "$1" "$2"
            ;;
        list-project-mrs)
            [[ $# -ge 3 ]] || { echo "用法: gitlab-api.sh list-project-mrs <project_id> <source_branch> <target_branch> [state]" >&2; exit ${SDD_EXIT_VALIDATION}; }
            list_project_mrs "$1" "$2" "$3" "${4:-}"
            ;;
        list-project-issues)
            [[ $# -ge 1 ]] || { echo "用法: gitlab-api.sh list-project-issues <project_id> [state] [labels]" >&2; exit ${SDD_EXIT_VALIDATION}; }
            list_project_issues "$1" "${2:-}" "${3:-}"
            ;;
        get-mr-notes)
            [[ $# -ge 2 ]] || { echo "用法: gitlab-api.sh get-mr-notes <project_id> <mr_iid>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            get_mr_notes "$1" "$2"
            ;;
        update-mr-note)
            [[ $# -ge 4 ]] || { echo "用法: gitlab-api.sh update-mr-note <project_id> <mr_iid> <note_id> <body>" >&2; exit ${SDD_EXIT_VALIDATION}; }
            update_mr_note "$1" "$2" "$3" "$4"
            ;;
        *)
            echo "用法: gitlab-api.sh <action> [args...]" >&2
            echo "" >&2
            echo "Actions:" >&2
            echo "  parse-issue-url <url>                              从 URL 提取 project_path 和 issue_iid" >&2
            echo "  parse-mr-url <url>                                 从 MR URL 提取 project_path 和 mr_iid" >&2
            echo "  parse-project-url <url>                            从项目 URL 提取 project_path" >&2
            echo "  resolve-project-id <project_path>                  获取 project_id" >&2
            echo "  get-issue <project_id> <issue_iid>                 获取 issue 详情" >&2
            echo "  create-issue <pid> <title> <desc> [labels]         创建 issue" >&2
            echo "  get-issue-notes <project_id> <issue_iid>           获取 issue 评论" >&2
            echo "  add-issue-note <project_id> <issue_iid> <body>     添加 issue 评论" >&2
            echo "  update-issue-labels <project_id> <iid> <add> [rm]  更新标签" >&2
            echo "  update-issue-description <pid> <iid> <desc>        更新 issue 描述" >&2
            echo "  create-mr <pid> <source> <target> <title> <desc> [rm_branch]  创建 MR" >&2
            echo "  get-mr <project_id> <mr_iid>                       获取 MR 详情" >&2
            echo "  get-mr-changes <project_id> <mr_iid>               获取 MR 变更" >&2
            echo "  add-mr-note <project_id> <mr_iid> <body>           添加 MR 评论" >&2
            echo "  set-mr-reviewers <project_id> <mr_iid> <ids>       设置 MR reviewer" >&2
            echo "  resolve-user-id <project_id> <username>            获取用户 ID" >&2
            echo "  get-project-members <project_id>                   获取项目成员" >&2
            echo "  close-issue <project_id> <issue_iid>               关闭 issue" >&2
            echo "  list-issue-related-mrs <project_id> <issue_iid>    获取 issue 关联 MR 列表" >&2
            echo "  list-project-mrs <pid> <source> <target> [state]   按分支查询 MR 列表" >&2
            echo "  get-mr-notes <project_id> <mr_iid>                 获取 MR 评论列表" >&2
            echo "  update-mr-note <pid> <mr_iid> <note_id> <body>     更新 MR 评论" >&2
            echo "  reopen-issue <project_id> <issue_iid>              重新打开 issue" >&2
            echo "  list-project-issues <pid> [state] [labels]          获取项目 issue 列表" >&2
            echo "  update-issue-assignees <pid> <iid> <user_ids>      设置 issue 指派人" >&2
            exit ${SDD_EXIT_VALIDATION}
            ;;
    esac
}

main "$@"
