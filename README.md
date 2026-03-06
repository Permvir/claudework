# claudeWork

A collaborative repository for building practical tools and solving tasks through AI (primarily Claude). Each tool/task lives in its own directory for easy sharing and reuse across the team.

## Tools

### gitlab_profiles — GitLab Multi-Account Switching

Easily switch between multiple GitLab accounts, scoped to the current shell session only. Manage profiles via the `gitlab-use` command: `gitlab-use <name>` to switch, `gitlab-use add` to interactively create, `gitlab-use remove <name>` to delete, `gitlab-use info` to inspect. Token validity is automatically verified on switch. Also overrides SDD workflow and git push authentication (injects a credential helper via `GIT_CONFIG_COUNT` to bypass Keychain). Closing the terminal resets everything.

See [`gitlab_profiles/features.md`](gitlab_profiles/features.md) for details.

### sdd_workflow — SDD Workflow

For background on **Specification-Driven Development (SDD)**, see this [link](https://github.com/github/spec-kit/blob/main/spec-driven.md). **sdd_workflow** implements spec-driven development using **Claude** and **GitLab issues** — supporting requirement parsing, code development, MR submission, and automated review. Integrated into Claude Code via the Skill mechanism, it provides an end-to-end automated workflow from requirements to code. Supports multi-team usage with per-user configuration via `~/.claude/sdd-config.sh`. Includes modular skill/actions, json-helper.py, and a comprehensive test suite (`tests/run_tests.sh`).

See [`sdd_workflow/features.md`](sdd_workflow/features.md) for details.

---

[中文版 (Chinese)](README.zh-CN.md)
