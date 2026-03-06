#!/usr/bin/env bash
# Tests for gitlab-api.sh URL parsing (no token required)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
API_SCRIPT="${SCRIPT_DIR}/gitlab-api.sh"
PASS=0
FAIL=0

# Export required env vars to avoid config errors
export GITLAB_URL="http://gitlab.example.com"
export GITLAB_TOKEN="test_token"
export DEVELOPER_NAME="alice"
# Set DEFAULT_BASE_BRANCH to non-"dev" to skip git ls-remote network call
export DEFAULT_BASE_BRANCH="master"

assert_json_field() {
    local desc="$1" json="$2" field="$3" expected="$4"
    local actual
    actual=$(echo "${json}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('${field}',''))" 2>/dev/null || echo "PARSE_ERROR")
    if [[ "${actual}" == "${expected}" ]]; then
        echo "  ✓ ${desc}"
        PASS=$((PASS + 1))
    else
        echo "  ✗ ${desc}: expected '${expected}', got '${actual}'"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit_code() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "  ✓ ${desc} (exit ${actual})"
        PASS=$((PASS + 1))
    else
        echo "  ✗ ${desc}: expected exit ${expected}, got ${actual}"
        FAIL=$((FAIL + 1))
    fi
}

echo "--- test_url_parsing.sh ---"

# parse-issue-url
echo "parse-issue-url:"
result=$(bash "${API_SCRIPT}" parse-issue-url "http://gitlab.example.com/mygroup/myproject/-/issues/8" 2>/dev/null) && ec=0 || ec=$?
assert_exit_code "valid issue URL succeeds" 0 "${ec}"
assert_json_field "project_path" "${result}" "project_path" "mygroup/myproject"
assert_json_field "issue_iid" "${result}" "issue_iid" "8"

result=$(bash "${API_SCRIPT}" parse-issue-url "http://gitlab.example.com/group/sub/project/-/issues/42" 2>/dev/null) && ec=0 || ec=$?
assert_exit_code "subgroup issue URL succeeds" 0 "${ec}"
assert_json_field "project_path subgroup" "${result}" "project_path" "group/sub/project"

result=$(bash "${API_SCRIPT}" parse-issue-url "http://other.com/mygroup/myproject/-/issues/1" 2>/dev/null) && ec=0 || ec=$?
if [[ ${ec} -ne 0 ]]; then
    echo "  ✓ host mismatch returns non-zero (exit ${ec})"
    PASS=$((PASS + 1))
else
    echo "  ✗ host mismatch should return non-zero"
    FAIL=$((FAIL + 1))
fi

# parse-mr-url
echo "parse-mr-url:"
result=$(bash "${API_SCRIPT}" parse-mr-url "http://gitlab.example.com/mygroup/myproject/-/merge_requests/5" 2>/dev/null) && ec=0 || ec=$?
assert_exit_code "valid MR URL succeeds" 0 "${ec}"
assert_json_field "project_path" "${result}" "project_path" "mygroup/myproject"
assert_json_field "mr_iid" "${result}" "mr_iid" "5"

# parse-project-url
echo "parse-project-url:"
result=$(bash "${API_SCRIPT}" parse-project-url "http://gitlab.example.com/mygroup/myproject" 2>/dev/null) && ec=0 || ec=$?
assert_exit_code "valid project URL succeeds" 0 "${ec}"
assert_json_field "project_path" "${result}" "project_path" "mygroup/myproject"

result=$(bash "${API_SCRIPT}" parse-project-url "http://gitlab.example.com/mygroup/myproject.git" 2>/dev/null) && ec=0 || ec=$?
assert_exit_code ".git suffix handled" 0 "${ec}"
assert_json_field "project_path no .git" "${result}" "project_path" "mygroup/myproject"

result=$(bash "${API_SCRIPT}" parse-project-url "http://gitlab.example.com/mygroup/myproject/-/boards" 2>/dev/null) && ec=0 || ec=$?
assert_exit_code "strips /-/ suffix" 0 "${ec}"
assert_json_field "project_path stripped" "${result}" "project_path" "mygroup/myproject"

# Missing args should fail with validation exit code
echo "validation errors:"
result=$(bash "${API_SCRIPT}" parse-issue-url 2>/dev/null) && ec=0 || ec=$?
assert_exit_code "missing arg returns SDD_EXIT_VALIDATION" 4 "${ec}"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]] || exit 1
