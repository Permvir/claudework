#!/usr/bin/env bash
# Tests for config.sh helper functions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "  ✓ ${desc}"
        PASS=$((PASS + 1))
    else
        echo "  ✗ ${desc}: expected '${expected}', got '${actual}'"
        FAIL=$((FAIL + 1))
    fi
}

echo "--- test_config_functions.sh ---"

# Setup: mock environment
export DEVELOPER_NAME="ocean"
export GITLAB_URL="http://gitlab.example.com"
export GITLAB_TOKEN="test_token"
# Set DEFAULT_BASE_BRANCH to non-"dev" to skip git ls-remote network call
export DEFAULT_BASE_BRANCH="master"
export _SDD_CONFIG_LOADED=""  # force reload

# Source config
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || true

# Test get_branch_name
echo "get_branch_name:"
assert_eq "dev type" "master-ocean-8" "$(get_branch_name dev 8)"
assert_eq "hotfix type" "hotfix-ocean-8" "$(get_branch_name hotfix 8)"
assert_eq "feature type" "feature-ocean-8" "$(get_branch_name feature 8)"

# Test get_base_branch
echo "get_base_branch:"
# Note: DEFAULT_BASE_BRANCH may be "dev" or "master" depending on git context
BASE=$(get_base_branch dev)
assert_eq "dev type returns DEFAULT_BASE_BRANCH" "${DEFAULT_BASE_BRANCH}" "${BASE}"
assert_eq "hotfix type returns master" "master" "$(get_base_branch hotfix)"
assert_eq "feature type returns master" "$(get_base_branch feature)" "master"

# Test get_primary_mr_target
echo "get_primary_mr_target:"
assert_eq "dev type" "${DEFAULT_BASE_BRANCH}" "$(get_primary_mr_target dev)"
assert_eq "hotfix type" "master" "$(get_primary_mr_target hotfix)"
assert_eq "feature type" "master" "$(get_primary_mr_target feature)"

# Test no_proxy dedup
echo "no_proxy dedup:"
export _SDD_CONFIG_LOADED=""
export DEFAULT_BASE_BRANCH="master"
export no_proxy=""
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || true
FIRST_NO_PROXY="${no_proxy}"
export _SDD_CONFIG_LOADED=""
export DEFAULT_BASE_BRANCH="master"
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || true
SECOND_NO_PROXY="${no_proxy}"
assert_eq "no duplicate after double source" "${FIRST_NO_PROXY}" "${SECOND_NO_PROXY}"

# Test exit codes are exported
echo "exit codes:"
assert_eq "SDD_EXIT_OK" "0" "${SDD_EXIT_OK}"
assert_eq "SDD_EXIT_CONFIG" "2" "${SDD_EXIT_CONFIG}"
assert_eq "SDD_EXIT_API" "3" "${SDD_EXIT_API}"
assert_eq "SDD_EXIT_VALIDATION" "4" "${SDD_EXIT_VALIDATION}"
assert_eq "SDD_EXIT_GIT" "5" "${SDD_EXIT_GIT}"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]] || exit 1
