#!/usr/bin/env bash
# SDD Workflow — MR 创建辅助
# 用法：bash mr-helper.sh <action> [args...]
#
# Actions:
#   create <project_id> <issue_iid> <issue_title> <source_branch> <target_branch> [description_file] [remove_source_branch]
#   batch-notify-reviewers <project_id> <mr_iid> <usernames>  — 逗号分隔，一次性设置并通知

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# ── 语言检测 ──
if [[ "${LANG:-}" != zh_CN* && "${LANG:-}" != zh_TW* ]]; then
  _SDD_LANG=en
else
  _SDD_LANG=zh
fi

TEMPLATE_DIR="${SCRIPT_DIR}/../templates"

# ─── MR 描述生成 ──────────────────────────────────────────

generate_mr_description() {
    local issue_iid="$1"
    local issue_title="$2"
    local description_file="${3:-}"

    local template_file="${TEMPLATE_DIR}/mr-description-template.md"

    python3 "${SCRIPT_DIR}/json-helper.py" render-mr-template \
        "${template_file}" "${issue_iid}" "${issue_title}" "${description_file}"
}

# ─── 创建 MR ─────────────────────────────────────────────

create_mr_for_issue() {
    local project_id="$1"
    local issue_iid="$2"
    local issue_title="$3"
    local source_branch="$4"
    local target_branch="$5"
    local description_file="${6:-}"
    local remove_source_branch="${7:-}"

    local mr_title="Resolve \"${issue_title}\""
    local description
    description=$(generate_mr_description "${issue_iid}" "${issue_title}" "${description_file}")

    bash "${SCRIPT_DIR}/gitlab-api.sh" create-mr \
        "${project_id}" \
        "${source_branch}" \
        "${target_branch}" \
        "${mr_title}" \
        "${description}" \
        "${remove_source_branch}"
}

# ─── 批量设置 & 通知 Reviewer ─────────────────────────────

batch_notify_reviewers() {
    local project_id="$1"
    local mr_iid="$2"
    local usernames="$3"  # 逗号分隔的用户名，如 "alice,bob"

    local reviewer_ids=()
    local mention_parts=()

    # 按逗号拆分用户名
    local IFS=','
    read -ra username_arr <<< "${usernames}"

    for username in "${username_arr[@]}"; do
        # 去除空白
        username="${username## }"
        username="${username%% }"
        [[ -z "${username}" ]] && continue

        local user_info
        if ! user_info=$(bash "${SCRIPT_DIR}/gitlab-api.sh" resolve-user-id "${project_id}" "${username}" 2>/dev/null); then
            if [[ "${_SDD_LANG}" == "en" ]]; then
                echo "⚠ Reviewer @${username}: resolve-user-id failed, skipping" >&2
            else
                echo "⚠ Reviewer @${username}: resolve-user-id 失败，跳过" >&2
            fi
            continue
        fi

        local user_id
        if ! user_id=$(echo "${user_info}" | python3 "${SCRIPT_DIR}/json-helper.py" get-field user_id 2>/dev/null) || [[ -z "${user_id}" ]]; then
            if [[ "${_SDD_LANG}" == "en" ]]; then
                echo "⚠ Reviewer @${username} not a project member, skipped" >&2
            else
                echo "⚠ Reviewer @${username} 不在项目成员中，已跳过" >&2
            fi
            continue
        fi

        reviewer_ids+=("${user_id}")
        mention_parts+=("@${username}")
    done

    # 一次性设置所有 reviewer
    if [[ ${#reviewer_ids[@]} -gt 0 ]]; then
        local ids_csv
        ids_csv=$(printf '%s,' "${reviewer_ids[@]}")
        ids_csv="${ids_csv%,}"

        local _reviewer_err
        if ! _reviewer_err=$(bash "${SCRIPT_DIR}/gitlab-api.sh" set-mr-reviewers \
            "${project_id}" "${mr_iid}" "${ids_csv}" 2>&1); then
            if [[ "${_SDD_LANG}" == "en" ]]; then
                echo "⚠ set-mr-reviewers failed: ${_reviewer_err}" >&2
            else
                echo "⚠ set-mr-reviewers 失败: ${_reviewer_err}" >&2
            fi
        fi

        # 单条评论 @提醒所有 reviewer
        local mentions="${mention_parts[*]}"
        local note
        if [[ "${_SDD_LANG}" == "en" ]]; then
            note="${mentions} Please review this MR. This MR was auto-created by the SDD workflow. The linked issue contains the full spec and acceptance criteria."
        else
            note="${mentions} 请 review 此 MR。此 MR 由 SDD 工作流自动创建，关联 issue 中包含完整的需求规范和验收标准。"
        fi

        bash "${SCRIPT_DIR}/gitlab-api.sh" add-mr-note \
            "${project_id}" \
            "${mr_iid}" \
            "${note}"
    else
        if [[ "${_SDD_LANG}" == "en" ]]; then
            echo "⚠ No reviewers resolved, skipping notification" >&2
        else
            echo "⚠ 未成功解析任何 reviewer，跳过通知" >&2
        fi
    fi
}

# ─── 入口 ─────────────────────────────────────────────────

main() {
    local action="${1:-}"
    shift || true

    case "${action}" in
        create)
            [[ $# -ge 5 ]] || { if [[ "${_SDD_LANG}" == "en" ]]; then echo "Usage: mr-helper.sh create <project_id> <issue_iid> <issue_title> <source_branch> <target_branch> [description_file] [rm_branch]" >&2; else echo "用法: mr-helper.sh create <project_id> <issue_iid> <issue_title> <source_branch> <target_branch> [description_file] [rm_branch]" >&2; fi; exit ${SDD_EXIT_VALIDATION}; }
            create_mr_for_issue "$@"
            ;;
        batch-notify-reviewers)
            [[ $# -ge 3 ]] || { if [[ "${_SDD_LANG}" == "en" ]]; then echo "Usage: mr-helper.sh batch-notify-reviewers <project_id> <mr_iid> <usernames>" >&2; else echo "用法: mr-helper.sh batch-notify-reviewers <project_id> <mr_iid> <usernames>" >&2; fi; exit ${SDD_EXIT_VALIDATION}; }
            batch_notify_reviewers "$1" "$2" "$3"
            ;;
        *)
            if [[ "${_SDD_LANG}" == "en" ]]; then
                echo "Usage: mr-helper.sh <action> [args...]" >&2
            else
                echo "用法: mr-helper.sh <action> [args...]" >&2
            fi
            echo "" >&2
            echo "Actions:" >&2
            echo "  create <project_id> <issue_iid> <title> <source> <target> [desc_file] [rm_branch]" >&2
            echo "  batch-notify-reviewers <project_id> <mr_iid> <user1,user2,...>" >&2
            exit ${SDD_EXIT_VALIDATION}
            ;;
    esac
}

main "$@"
