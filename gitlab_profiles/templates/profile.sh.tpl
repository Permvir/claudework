#!/usr/bin/env bash
# GitLab Profile: __PROFILE_NAME__
# Usage: source ~/.claude/gitlab-profiles/__PROFILE_NAME__.sh
#   or:  gitlab-use __PROFILE_NAME__

# ── 清除旧 profile 状态 ──
unset GITLAB_TOKEN GITLAB_URL DEVELOPER_NAME
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1
unset GIT_TERMINAL_PROMPT _GITLAB_PROFILE_ACTIVE

# ── SDD / GitLab API ──
export GITLAB_URL="__GITLAB_URL__"
export GITLAB_TOKEN="__GITLAB_TOKEN__"
export DEVELOPER_NAME="__DEVELOPER_NAME__"

# ── Git commit 身份 ──
export GIT_AUTHOR_NAME="__DEVELOPER_NAME__"
export GIT_AUTHOR_EMAIL="__GIT_EMAIL__"
export GIT_COMMITTER_NAME="__DEVELOPER_NAME__"
export GIT_COMMITTER_EMAIL="__GIT_EMAIL__"

# ── Git push 认证（覆盖 Keychain，仅当前 session）──
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0="credential.helper"
export GIT_CONFIG_VALUE_0=""
export GIT_CONFIG_KEY_1="credential.helper"
export GIT_CONFIG_VALUE_1="!f() { test \"\$1\" = get && echo \"username=__DEVELOPER_NAME__\" && echo \"password=${GITLAB_TOKEN}\"; }; f"

export GIT_TERMINAL_PROMPT=0
export _GITLAB_PROFILE_ACTIVE="__PROFILE_NAME__"

echo "Switched to GitLab profile: __PROFILE_NAME__ (${GITLAB_URL})"
