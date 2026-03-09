#!/usr/bin/env bash
# SDD Workflow — 用户配置文件
# 安装时复制到 ~/.claude/sdd-config.sh，已存在则不覆盖
#
# 优先级：环境变量 > 本文件 > config.sh 默认值
# CI/CD 环境建议通过环境变量注入（如 GITLAB_TOKEN），无需修改本文件

# ─── GitLab 连接 ───────────────────────────────────────────
# GitLab 实例地址（不含尾部斜杠）
# 请替换为你的 GitLab 实例地址，例如 https://gitlab.example.com
GITLAB_URL="https://your-gitlab.example.com"

# GitLab Personal Access Token（需要 api scope）
# 在 GitLab → Settings → Access Tokens 中创建
# 安全提示：
#   - 此文件包含凭证，请勿提交到 git 仓库
#   - 建议定期轮换 Token（如每 90 天），在 GitLab 中可设置 Token 过期时间
#   - CI/CD 环境建议通过环境变量 GITLAB_TOKEN 注入，避免写入文件
GITLAB_TOKEN="YOUR_TOKEN_HERE"

# ─── 开发者信息 ───────────────────────────────────────────
# 开发者名称，用于分支命名（如 alice、bob）
# 留空则自动从 git config user.name 读取
DEVELOPER_NAME=""

# ─── Git 分支管理 ─────────────────────────────────────────
# 默认基线分支（常规开发从此分支拉取）
# 自动检测：如果远程不存在 dev 分支（工具类项目仅有 master），自动回退为 master
# 显式设置此值可覆盖自动检测
DEFAULT_BASE_BRANCH="dev"

# 分支类型及命名规范：
#   dev     — 常规迭代开发，从 dev 拉取，MR 合到 dev（无 dev 分支时从 master 拉取，MR 合到 master）
#   hotfix  — 线上紧急修复/紧急功能，从 master 拉取，同时合到 dev 和 master（无 dev 分支时仅合 master）
#   feature — 紧急上线且周期短的新功能，从 master 拉取，同时合到 dev 和 master（无 dev 分支时仅合 master）
#
# 命名模式中的变量：{base_branch} = 实际基线分支名, {developer} = 开发者名称, {issue_iid} = issue 编号, {description} = 简要描述
# dev 类型前缀动态跟随基线：有 dev 分支时为 dev-ocean-8，无 dev 回退 master 时为 master-ocean-8
BRANCH_PATTERN_DEV='{base_branch}-{developer}-{issue_iid}'
BRANCH_PATTERN_HOTFIX='hotfix-{developer}-{issue_iid}'
BRANCH_PATTERN_FEATURE='feature-{developer}-{issue_iid}'

# 默认分支类型（dev / hotfix / feature）
DEFAULT_BRANCH_TYPE="dev"

# ─── Workflow 标签 ─────────────────────────────────────────
# Issue 看板流程：workflow::backlog → workflow::start → workflow::in dev → workflow::evaluation → workflow::done → Closed
# workflow:: 为 GitLab scoped label，同一 scope 内同一时间只能有一个标签（GitLab 自动替换）
WORKFLOW_LABEL_BACKLOG="workflow::backlog"
WORKFLOW_LABEL_START="workflow::start"
WORKFLOW_LABEL_DEV="workflow::in dev"
WORKFLOW_LABEL_EVAL="workflow::evaluation"
WORKFLOW_LABEL_DONE="workflow::done"

# ─── 缓存设置 ────────────────────────────────────────────
# 分支检测缓存有效期（秒），默认 300 秒（5 分钟）
# 设为 0 可禁用缓存，每次都重新检测远程分支
# SDD_CACHE_TTL=300

# ─── MR 默认设置 ──────────────────────────────────────────
# MR 是否默认删除源分支
MR_REMOVE_SOURCE_BRANCH="true"

# MR 是否默认 squash commits
MR_SQUASH="true"
