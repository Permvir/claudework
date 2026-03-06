# CLAUDE.md

## Overview

claudework is a collaborative repository for building practical tools and solving tasks through AI (primarily Claude). Each tool/task has its own directory for easy sharing and reuse.

## Directory Structure

```
claudework/
├── CLAUDE.md                  # Project conventions (this file)
├── README.md                  # Project overview & tool list
├── gitlab_profiles/           # GitLab multi-account switching
│   ├── features.md            # Feature documentation (Chinese)
│   ├── features.en.md         # Feature documentation (English)
│   ├── install.sh             # One-click install script
│   ├── lib/                   # Core function library
│   └── templates/             # Profile templates
└── sdd_workflow/              # SDD Workflow Skill
    ├── features.md            # Feature documentation (Chinese)
    ├── features.en.md         # Feature documentation (English)
    ├── CHANGELOG.md           # Changelog
    ├── install.sh             # One-click install script
    ├── skill/                 # Skill entry + modular actions
    ├── scripts/               # Shell scripts (API, parser, config)
    ├── references/            # Reference docs
    ├── templates/             # Template files
    ├── examples/              # Examples
    └── tests/                 # Test suite
```

## Development Conventions

- **One tool per directory**: Each tool or task gets its own directory at the repository root
- **Language**: Primarily Shell scripts, supplemented by Python; choose the best fit for the task
- **Documentation**: Each tool directory must include `.md` docs covering purpose, installation, and configuration
- **Install scripts**: If a tool requires setup steps, provide an `install.sh` one-click install script
- **README updates**: When adding a new tool, modifying tool logic, or renaming a directory, you **must** update the corresponding entry in the root `README.md`

## Existing Tools

| Tool | Directory | Description |
|------|-----------|-------------|
| GitLab Multi-Account Switching | `gitlab_profiles/` | Switch GitLab accounts via `gitlab-use`, with interactive add/remove/inspect profiles, automatic token validation, session-scoped |
| SDD Workflow | `sdd_workflow/` | Spec-driven development powered by GitLab issues — requirement parsing, code development, MR submission, and automated review (Skill-driven) |

---

[中文版 (Chinese)](CLAUDE.zh-CN.md)
