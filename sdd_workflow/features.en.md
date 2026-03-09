中文版: [features.md](features.md)

# SDD Workflow — Feature Documentation

## Overview

SDD (Spec-Driven Development) is a GitLab issue spec-driven development workflow tool. Using Claude Code's Skill mechanism, run `/sdd` commands in any GitLab project directory to cover the full cycle: reading requirements, writing code, submitting MRs, and automated reviews.

## File Structure

```
sdd_workflow/
├── features.md                         # This document
├── CHANGELOG.md                        # Changelog
├── install.sh                          # One-click install script (supports --uninstall)
├── skill/
│   ├── SKILL.md                        # Skill entry file (lightweight router)
│   └── actions/                        # Detailed steps for each action
│       ├── create.md
│       ├── read.md
│       ├── refine.md
│       ├── review.md
│       ├── dev.md
│       ├── submit.md
│       ├── done.md
│       ├── update.md
│       ├── link.md
│       ├── list.md
│       ├── template.md
│       ├── status.md
│       ├── reopen.md
│       ├── assign.md
│       └── label.md
├── scripts/
│   ├── config.sh                       # Config loader
│   ├── config-template.sh              # Config template
│   ├── gitlab-api.sh                   # GitLab API wrapper
│   ├── issue-parser.sh                 # Issue markdown parser
│   ├── mr-helper.sh                    # MR creation helper
│   └── json-helper.py                  # JSON utilities + MR template renderer
├── references/
│   ├── gitlab-api-reference.md         # API endpoint quick reference
│   └── workflow-guide.md               # Workflow stage guide
├── templates/
│   ├── issue-spec-template.md          # Issue requirement spec template
│   ├── bug-report-template.md          # Bug issue template (preserves raw error log)
│   ├── dev-notes-template.md           # Development notes template
│   └── mr-description-template.md      # MR description template
├── examples/
│   └── sample-issue.md                 # Sample issue
└── tests/                              # Automated tests (development only, not deployed)
    ├── run_tests.sh                    # Test runner entry point
    ├── test_json_helper.py             # Tests for all json-helper.py actions
    ├── test_issue_parser.py            # Tests for issue-parser.sh
    ├── test_config_functions.sh        # Tests for config.sh helper functions
    ├── test_url_parsing.sh             # Tests for gitlab-api.sh URL parsing + exit codes
    └── fixtures/                       # Test issue fixtures
```

Deployment paths after installation:
- `~/.claude/skills/sdd/` — Skill files + actions + scripts + references + templates + examples
- `~/.claude/sdd-config.sh` — User config (token etc., created only on first install, not overwritten on reinstall)

## Installation

```bash
bash sdd_workflow/install.sh
```

After installation, edit the config file to complete setup:

```bash
vi ~/.claude/sdd-config.sh
```

### Step 1: Set GitLab Instance URL

Find the `GITLAB_URL` line and replace it with your team's GitLab URL (no trailing slash):

```bash
# Before (placeholder)
GITLAB_URL="https://your-gitlab.example.com"

# After (your actual URL)
GITLAB_URL="http://your-company-gitlab.com"
```

> Not sure of the URL? Open any project issue in your browser — everything before `/-/issues/` (minus the project path) is your `GITLAB_URL`.

### Step 2: Set Personal Access Token

Find the `GITLAB_TOKEN` line and replace it with your Personal Access Token:

```bash
GITLAB_TOKEN="YOUR_TOKEN_HERE"   # Replace with your actual token
```

**How to get a token**: GitLab → Avatar (top right) → Edit profile → Access Tokens → Add new token
- Name: anything (e.g. `sdd-workflow`)
- Expiration date: recommended (e.g. 90 days)
- Scopes: check **api**
- Click Create → copy the generated token (shown only once)

### Step 3: Verify Configuration

```bash
bash ~/.claude/skills/sdd/scripts/config.sh --export
```

Sample output (when configured correctly):

```
SDD Workflow Config:

  [GitLab]
  GITLAB_URL              = http://your-company-gitlab.com
  GITLAB_TOKEN            = Set (20 chars)

  [Developer]
  DEVELOPER_NAME          = your.name

  [Git Branch Management]
  DEFAULT_BASE_BRANCH     = dev
  ...
```

If `GITLAB_TOKEN` shows "Not set", the token was not filled in correctly.

### Optional Configuration

Additional options in the config file (all have defaults, optional):

```bash
# Developer name (auto-read from git config user.name if empty)
DEVELOPER_NAME=""

# Default base branch (auto-detect: falls back to master if no dev branch on remote)
DEFAULT_BASE_BRANCH="dev"

# Delete source branch after MR merge (default: true)
MR_REMOVE_SOURCE_BRANCH="true"

# Squash commits on MR merge (default: true)
MR_SQUASH="true"
```

Token: GitLab → Settings → Access Tokens → Create (requires `api` scope)

> **Security note**: `~/.claude/sdd-config.sh` contains sensitive credentials such as tokens. The install script automatically sets its permissions to 600 (owner read/write only). Do not commit this file to a git repository. Set a token expiration in GitLab and rotate regularly (e.g. every 90 days) — just update the token value in the config file when it expires.

### Multi-account Switching (with gitlab_profiles)

When multiple people share one machine, or you need to switch between GitLab accounts, use **gitlab_profiles** to switch accounts dynamically without modifying `~/.claude/sdd-config.sh`.

**How it works**: When `gitlab_profiles` switches accounts, it writes `GITLAB_URL`, `GITLAB_TOKEN`, and `DEVELOPER_NAME` into the current shell's environment variables via `source`. SDD's `config.sh` prioritizes environment variables over config file values, so both tools work together natively with no code changes needed.

**Priority**: environment variables (`gitlab_profiles` injected) > `~/.claude/sdd-config.sh` (local default) > script built-in defaults

**Usage**:

```bash
# 1. Install gitlab_profiles (if not already installed)
bash gitlab_profiles/install.sh

# 2. Add each user's profile (once per person)
gitlab-use add
# Follow prompts: profile name, GitLab URL, Personal Access Token, developer name

# 3. Switch to your account before using (before launching Claude Code, or in a new session)
gitlab-use alice      # switch to alice's account

# 4. Use SDD normally (automatically uses alice's URL and token)
/sdd read <issue_url>
```

**Typical scenario (shared Mac)**:

| User | Action | Effect |
|------|--------|--------|
| Alice | `gitlab-use alice` | `GITLAB_TOKEN` switches to Alice's token |
| Bob | `gitlab-use bob` | `GITLAB_TOKEN` switches to Bob's token |
| Anyone | skip `gitlab-use` | uses default account from `~/.claude/sdd-config.sh` |

**Note**: `gitlab-use` switch only applies to the current shell session and expires when the terminal closes — it does not affect others.

> `~/.claude/sdd-config.sh` works best as the **default account** fallback on a personal machine. On shared machines, keep `GITLAB_TOKEN="YOUR_TOKEN_HERE"` in the config (empty token) to force everyone to switch via `gitlab-use` before use, avoiding accidental commits under another person's account.

### Uninstall

```bash
bash sdd_workflow/install.sh --uninstall
```

> Uninstall removes `~/.claude/skills/sdd/` but preserves the user config file `~/.claude/sdd-config.sh` (contains sensitive credentials — delete manually if needed).

## Configuration Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `GITLAB_URL` | `http://gitlab.example.com` | GitLab instance URL |
| `GITLAB_TOKEN` | — | Personal Access Token (required) |
| `DEVELOPER_NAME` | git config user.name | Developer name used in branch naming |
| `DEFAULT_BASE_BRANCH` | `dev` | Default base branch (auto-detect: falls back to `master` if no dev branch) |
| `DEFAULT_BRANCH_TYPE` | `dev` | Default branch type (dev/hotfix/feature) |
| `BRANCH_PATTERN_DEV` | `dev-{developer}-{issue_iid}` | dev branch naming pattern |
| `BRANCH_PATTERN_HOTFIX` | `hotfix-{developer}-{issue_iid}` | hotfix branch naming pattern |
| `BRANCH_PATTERN_FEATURE` | `feature-{developer}-{issue_iid}` | feature branch naming pattern |
| `MR_REMOVE_SOURCE_BRANCH` | `true` | Delete source branch after MR merge |
| `MR_SQUASH` | `true` | Squash commits on MR merge |
| `SDD_CACHE_TTL` | `300` | Branch detection cache TTL in seconds (set to 0 to disable) |

Verify configuration:

```bash
bash ~/.claude/skills/sdd/scripts/config.sh --export
```

## Group-Level Configuration (Wiki Auto Labels)

In addition to the local `~/.claude/sdd-config.sh` personal config, SDD supports reading team-level configuration from GitLab **Group Wiki**. Currently supported Group-level configurations:

### Repository System Label Mapping (by repo name)

Create a page named **`sdd-configuration`** in your Group's **Plan → Wiki** to configure repo → system label mappings. When `/sdd create` creates an issue, it automatically matches the target project's system labels.

**How to create**: Go to GitLab Group → Plan → Wiki → New page, set the title to `sdd-configuration`.

**Page format**:

```markdown
# System Label Mapping

## System::Orders
- order-frontend
- order-backend

## System::Users
- user-manage-frontend
- user-manage

## System::Payments
- payment-engine
```

**Format reference**:

| Element | Format | Description |
|---------|--------|-------------|
| Label name | `## label-name` | Second-level heading — the label to be auto-applied |
| Repo name | `- repo-name` | List item under a label — repos that belong to this label (repo name only, no group path) |

**Rules**:
- Each `##` heading defines one label; list items below it are the associated repos
- Repo name must exactly match the GitLab project's **repository name** (not the full path)
- A repo can appear under multiple labels (one-to-many mapping supported)
- `#` top-level headings and non-`##`/`-` lines are ignored and can be used for comments
- Labels must already exist in the Group (SDD does not create labels automatically)

**Behavior**:
- On `/sdd create`, automatically reads the `sdd-configuration` Wiki page from the target project's Group
- Matches labels by repo name and merges them into issue labels (alongside `workflow::backlog` and `--label` params)
- Projects not in the mapping table are unaffected
- If the Wiki page is missing or fails to load, silently skips — normal create flow is not interrupted
- On successful match, shows `Auto-applied labels: System::xxx (from Group Wiki config)` in the result

### Issue Type Label Mapping (by --type parameter)

In the same `sdd-configuration` Wiki page, add an "Issue type label mapping" section to configure `--type` value → label mappings:

```markdown
# Issue Type Label Mapping

## requirement
- requirement

## bug
- bug
```

**Format reference**:

| Element | Format | Description |
|---------|--------|-------------|
| Section heading | `# Issue Type Label Mapping` | Top-level heading, fixed name |
| Type name | `## requirement` / `## bug` | Second-level heading, matches `--type` parameter value |
| Label name | `- requirement` / `- bug` | List item — the label to apply for this type |

**Behavior**:
- On `/sdd create`, looks up the label for the `--type` value (default: `requirement`) and auto-applies it
- Merged with system labels and `--label` params — does not override
- If no matching type config exists in the Wiki, no type label is added — normal flow is not interrupted
- Labels must already exist in the Group (SDD does not create labels automatically)

## Usage

Launch Claude Code in any GitLab project directory:

### Issue URL Shorthand

**Only specify the issue URL on the first command in a session — subsequent commands can omit it.** Claude automatically retrieves issue info from the conversation context.

Three supported forms:
| Form | Example | When to use |
|------|---------|-------------|
| Full URL | `/sdd read http://gitlab.example.com/mygroup/myproject/-/issues/8` | First use or switching issues |
| Issue number | `/sdd read 8` | Auto-constructs full URL from git remote |
| Omit URL | `/sdd review` | Reuses the issue already loaded in the session |

**Typical single-session workflow**:
```
/sdd read http://gitlab.example.com/mygroup/myproject/-/issues/8   ← specify full URL first
(discuss requirements with Claude)
/sdd refine                                                 ← omit URL, auto-reuse
/sdd review                                                 ← omit URL, auto-reuse
/sdd dev                                                    ← omit URL, auto-reuse
(write code...)
/sdd submit                                                 ← omit URL, auto-reuse
```

> **Note**: Omitting the URL requires that a command with an issue URL was already run in the current session. In a new session, specify the issue URL again.

### Create Issue

```
/sdd create http://gitlab.example.com/mygroup/myproject Optimize login flow, add CAPTCHA validation
```

Automatically generates a structured issue from the description (background, requirements, acceptance criteria), checks required section completeness before creating, and adds the `workflow::backlog` label on GitLab.

**`--type` parameter**: Use `--type=requirement|bug` to specify the issue type. **Defaults to `requirement`** (same behavior when omitted):

| Type | Behavior |
|------|----------|
| `requirement` (default) | Generates structured spec via `issue-spec-template` (background, requirements, acceptance criteria, etc.) |
| `bug` | Places the error log **exactly as-is, without any modification** into the "Error Log" code block; other sections are inferred minimally from the log |

```
# Default requirement type
/sdd create http://gitlab.example.com/mygroup/myproject Optimize login flow, add CAPTCHA validation

# Explicit requirement
/sdd create --type=requirement http://gitlab.example.com/mygroup/myproject Optimize login page performance

# Bug type: error log preserved verbatim
/sdd create --type=bug http://gitlab.example.com/mygroup/myproject NullPointerException at UserService.java:42
```

**Type label auto-mapping**: After adding an "Issue type label mapping" section to the Group Wiki `sdd-configuration` page, `create` will automatically match and apply the corresponding label for the `--type` value (e.g. `requirement` or `bug`). Wiki config format:

```markdown
# Issue Type Label Mapping
## requirement
- requirement

## bug
- bug
```

Use `--label="..."` to append extra labels (merged with `workflow::backlog` and the type label — does not override):

```
/sdd create --label="priority::high" http://gitlab.example.com/mygroup/myproject Fix login page crash
/sdd create --type=bug --label="priority::high" http://gitlab.example.com/mygroup/myproject <error log>
```

### Read Issue

```
/sdd read http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Parses the issue markdown and displays a structured summary (background, requirements, acceptance criteria), checking spec completeness. If the issue has a "Related Issues" section, automatically fetches each linked issue's title and status. If the issue is in `workflow::backlog` state, automatically updates it to `workflow::start`.

### Refine Issue

```
/sdd refine http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Reads discussion points from the issue and writes conclusions back to the issue description after discussion with Claude. Two modes:

**Mode A: In-session discussion write-back** — If `read` was already run in the current session and discussion has taken place, `refine` reviews the conversation history and incorporates conclusions into the issue description. Typical usage:
```
/sdd read <url>          ← read issue
(freely discuss requirements, technical approach, etc. with Claude)
/sdd refine <url>        ← write discussion conclusions back to issue
```

**Mode B: Structured discussion** — If no prior discussion context exists, `refine` extracts discussion points from the issue and works through them one by one:
- **`## Questions` section**: general questions — removed from list once resolved
- **`<!-- TODO: xxx -->` inline markers**: context-specific questions — marker deleted and conclusion written in-place once resolved

If the issue is in `workflow::backlog` state, refine automatically updates the label to `workflow::start`; issues already in later stages are unaffected. Can be run multiple times to iteratively refine requirements — best used after `read` and before `dev`.

### Review Issue Spec

```
/sdd review http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Reviews issue spec quality from a cold-reader perspective, producing a structured review report. Checks structure completeness, requirement clarity, acceptance criteria coverage, and more — gives a pass/fail verdict with specific improvement suggestions.

Best run in a new session after `refine` and before `dev`, to get an unbiased review.

### Review MR Code Changes

```
/sdd review http://gitlab.example.com/mygroup/myproject/-/merge_requests/42
```

Performs a structured review of MR code changes. Automatically fetches the MR diff and reviews each file across dimensions including code quality, security, test coverage, and potential bugs, producing an MR Review report. If the MR description links an issue (e.g. `Closes #N`), also checks requirement coverage against the issue's acceptance criteria. The review is automatically posted as an MR comment for the team to view.

### Develop

```
/sdd dev http://gitlab.example.com/mygroup/myproject/-/issues/8
/sdd dev --type=hotfix http://gitlab.example.com/mygroup/myproject/-/issues/8
/sdd dev --type=feature http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Creates a development branch `dev-{developer}-8` from `dev` by default, updates the issue label to `workflow::in dev`, and writes code and tests based on requirements. If the issue has related issues, automatically fetches their requirements and technical notes for cross-repo context before coding begins (code changes are limited to the current repo). Supports hotfix (from master) and feature (from master) types.

### Submit MR

```
/sdd submit http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Pushes code to remote, reviews changes locally (shows a file stats summary first, then diff snippets only for problematic files), automatically creates an MR with reviewers set, and updates the label to `workflow::evaluation`. For hotfix/feature types with a dev branch, automatically creates 2 MRs (dev + master) — the first MR is set to not delete the source branch so both MRs can merge from the same source; the source branch is auto-deleted by the second MR after both are merged.

**Reviewer priority**:
1. `--reviewer=user1,user2` command-line parameter
2. `## Reviewer` section in the issue description
3. No reviewer set (submitter reviews themselves)

If no reviewer is specified, the MR is created normally without blocking the submit flow.

### Close Issue

```
/sdd done http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Manually triggered after MR is merged to close the issue. Automatically checks the merge status of linked MRs:
- **All merged**: automatically updates the issue label to `workflow::done` and closes the issue
- **Not yet merged**: prompts the user to confirm whether to force-close anyway

After closing, if currently on an SDD development branch, prompts whether to switch back to the base branch and delete the local dev branch.

### Add Issue Comment

```
/sdd update http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Adds a structured comment to the GitLab Issue's comment section. Claude interactively asks what you want to record — describe it in natural language and Claude will format it and post it to the issue.

**Example interaction**:
```
> /sdd update 8

Claude: What would you like to record? You can include: completed items, key decisions, TODOs, etc.

User: Finished login API development and unit tests. Decided token expiry should be 24 hours.
      Still need to add integration tests and API docs.

Claude: Comment added to Issue #8 ✓
```

The comment is published to GitLab in structured format:
```markdown
### Dev Log — 2026-03-03

**Stage**: In Development

**Completed**:
- Finished login API development
- Finished unit tests

**Key Decisions**:
- Token expiry set to 24 hours

**TODOs**:
- Add integration tests
- Write API documentation
```

#### Prompt Tips for the update Interaction

**Auto-distill from context** (easiest, recommended)

```
Summarize what we've done and the decisions we made in this session
```
```
Based on our conversation, help me record what was completed today and what decisions were made
```

**Focus on a specific angle**

```
Focus on the technical decisions we made, keep everything else brief
```
```
Record the problem we encountered and how we solved it, as a reference note
```

**Context + manual additions**

```
Summarize today's conversation, and add to TODOs: need to add integration tests and docs tomorrow
```

**Pure manual input**

```
Finished login API and unit tests, decided token expiry is 24h, still need integration tests
```

| Scenario | Recommended approach |
|----------|----------------------|
| Rich context, don't want to type | "Summarize the conversation" style |
| Only want to record one type of info | "Focus on decisions/issues/progress" |
| Have extra content to add | "Summarize conversation + also add xxx" |
| Thin context | Describe content directly for Claude to format |

### Link Related Issue

```
/sdd link http://gitlab.example.com/mygroup/backend/-/issues/12 Backend API interface definition
/sdd link --issue=8 http://gitlab.example.com/mygroup/frontend/-/issues/5
```

Appends a related URL to the "Related Issues" section of the specified issue. The current issue is retrieved from session context (requires a prior `read`/`dev` etc.), or specify explicitly with `--issue=N`. Automatically validates that the linked issue exists, checks for duplicates, and creates the section if it doesn't exist. If no description text is provided, uses the linked issue's title automatically.

### View Work Status

```
/sdd status
```

Shows a current SDD work status overview: current branch, branch type, linked issue title and workflow stage, local unstaged/staged/unpushed change counts. Useful for quickly understanding development context at the start of a new session.

### Reopen Issue

```
/sdd reopen http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Reopens a closed issue and updates its label to `workflow::start`.

### Assign Issue

```
/sdd assign http://gitlab.example.com/mygroup/myproject/-/issues/8 alice
/sdd assign 8 alice bob
/sdd assign --clear
```

Assigns the issue to one or more project members. `--clear` removes all assignees. If the issue URL is omitted, it is retrieved from session context.

### Manage Issue Labels

```
/sdd label --label="bug::functional,priority::high" <issue_url>
/sdd label --remove="bug::functional" <issue_url>
/sdd label --label="priority::high" --remove="priority::low" <issue_url>
```

Adds or removes labels from an issue. Pass label names via `--label="..."` / `--remove="..."`, supporting labels with spaces and `::`. Multiple labels are comma-separated. If the issue URL is omitted, it is retrieved from session context.

Edge cases: empty parameter value causes an error; adding and removing the same label simultaneously results in no change; removing a non-existent label shows a prompt.

### View Issue Board

```
/sdd list
/sdd list http://gitlab.example.com/mygroup/myproject
```

Lists issues with `workflow::` labels in the current project (or a specified project), grouped by workflow stage (In Dev > Evaluation > Planned > Backlog). Each issue shows its number, title, and assignee. Useful for a quick overview of project progress.

### View Template

```
/sdd template
```

Outputs the SDD issue spec template for creating new requirement issues.

## Intent Inference and Action Chaining

Each SDD action (create, read, dev, submit, etc.) is **independent** — there is no automatic chaining between actions. However, Claude infers from the user's original intent whether to continue with the next action.

### Real Example

User runs:
```
/sdd create http://gitlab.example.com/mygroup/claudework Improve gitlab_profiles and test successfully on the shared Mac
```

Claude's reasoning:
1. Identifies as **create action** (project URL + description) → creates Issue #9
2. Analyzes user's original intent: "**Improve**... and **test successfully**" — expresses wanting to **complete the whole thing**, not just create an issue
3. References the create action hint in SKILL.md: `After creating, you can use /sdd dev <issue_url> to start development`
4. Determines user expects the full workflow → proactively continues with the dev action

### Controlling This Behavior

| User expression | Claude behavior | Reason |
|-----------------|-----------------|--------|
| `Improve gitlab_profiles and test successfully` | create → auto-continue dev | Intent clearly includes "develop and complete" |
| `Create an issue: improve gitlab_profiles` | create only | Intent explicitly limited to "create issue" |
| `Create an issue to track gitlab_profiles improvement plans` | create only | Intent is to record and track, not immediate development |

### Design Notes

- **Action independence**: Each action has clear start and end boundaries, tracking state via GitLab labels — no automatic chaining at the configuration level
- **Intent-driven**: Claude infers next steps from the user's natural language, not a preset workflow orchestration
- **Predictability**: To control execution scope precisely, express intent boundaries clearly in the command (e.g. "create an issue" rather than "improve a feature")

## Git Branch Management

> See `references/workflow-guide.md` for detailed branch specs and flow diagrams.

Projects use a master + dev dual-mainline branch model (overview):

| Branch type | Base | MR target | Naming | Purpose |
|-------------|------|-----------|--------|---------|
| dev (default) | `dev` | `dev` | `dev-{developer}-{iid}` | Regular iterative development |
| hotfix | `master` | `dev` + `master` | `hotfix-{developer}-{iid}` | Production emergency fixes |
| feature | `master` | `dev` + `master` | `feature-{developer}-{iid}` | Urgent short-cycle new features |

- **master**: Production environment — code must never be modified directly
- **dev**: Development mainline — MR target for regular development
- **hotfix/feature**: Merged into both dev and master on completion

> **Projects without a dev branch**: Remote branches are auto-detected; if no `dev` branch exists, the base branch defaults to `master`. In this case, the dev type's base and MR target are both `master`, and hotfix/feature MR targets are `master` only. Designed for tool-type projects with only a master branch — no manual configuration needed.

## Workflow State Transitions (Issue Board Labels)

> See `references/workflow-guide.md` for detailed stage steps.

```
workflow::backlog → workflow::start → workflow::in dev → workflow::evaluation → workflow::done → Closed
       │                │                  │                   │                    │
     Backlog          Planned          In Development       In Review/QA          Done
```

> All labels are `workflow::` scoped labels — GitLab automatically replaces any existing label in the same scope.

| Label | Description | SDD action |
|-------|-------------|------------|
| `workflow::backlog` | Backlog item, requirement collection | — |
| `workflow::start` | Planned, development upcoming | Auto-set by `/sdd read` or `/sdd refine` |
| `workflow::in dev` | Currently in development | Auto-set by `/sdd dev` |
| `workflow::evaluation` | In review/QA | Auto-set by `/sdd submit`; use `/sdd review <mr_url>` to review MR |
| `workflow::done` | QA complete, ready to close | Auto-set and issue closed by `/sdd done` |

## Issue Spec

SDD requires issues to follow a unified format with these sections:

1. **Background** — Problem context and motivation (required)
2. **Requirements** — Functional requirement list (required)
3. **Acceptance Criteria** — Verifiable completion conditions (required)
4. **Related Issues** — Cross-repo linked issue URLs (optional, for cross-repo collaboration)
5. **Technical Notes** — Technical constraints and suggestions (optional)
6. **Test Plan** — Testing strategy and edge cases (optional)
7. **Reviewer** — MR reviewer (optional, auto-set on MR submit)
8. **Questions** — Pending discussion items (optional, used with `/sdd refine`)
9. **Dev Log** — Development process notes (filled during development)

See `examples/sample-issue.md` for a complete example.

### Related Issues (Cross-repo Collaboration)

When a task spans multiple repositories, link issues across repos in the "Related Issues" section to give Claude cross-repo global context during development.

**Usage**: In the issue's `## Related Issues` section, list one issue URL per line with an optional description:

```markdown
## Related Issues

- http://gitlab.example.com/mygroup/backend/-/issues/12 — Backend API interface definition
- http://gitlab.example.com/mygroup/frontend/-/issues/8 — Frontend page adaptation
```

**Behavior per action**:
- **create** — Generated issue includes an empty Related Issues section for later filling
- **read** — Automatically fetches each linked issue's title and status, shown in the summary
- **refine** — Preserves the Related Issues section without modifying its entries
- **review** — In spec review, external references in Related Issues are treated as valid dependencies, not penalized for self-containment
- **dev** — Before coding, automatically fetches related issues' requirements and technical notes for cross-repo context (code changes limited to current repo)
- **submit** — Does not involve the Related Issues section; MR description links the current issue via `Closes #N`
- **done** — Closes the current issue; does not affect the status of issues referenced in Related Issues
- **update** — Adds a comment; does not involve the Related Issues section
- **link** — Appends a related URL to the current issue, with validation, deduplication, and section auto-creation
- **list** — Lists the issue board; does not involve Related Issues
- **template** — Output template includes a Related Issues section placeholder
- **status** — Shows current work status; does not involve Related Issues
- **reopen** — Reopens issue; does not involve the Related Issues section
- **assign** — Assigns issue; does not involve the Related Issues section
- **label** — Adds or removes labels; does not involve the Related Issues section

**Design principle**: Related Issues is an optional section, not part of required field checks. SDD maintains a single-repo single-issue core model — Related Issues provides cross-repo reference context only.

## Documentation Notes

> **Single Source of Truth**: `skill/SKILL.md` + `skill/actions/*.md` are the authoritative definitions of the SDD workflow. This document (`features.md`) is the user-facing feature guide. In case of discrepancy, the SKILL.md and action files take precedence.

## Design Principles

| Principle | Description |
|-----------|-------------|
| Spec-driven | Development is guided by issue requirements; acceptance criteria determine completion |
| User-initiated | `disable-model-invocation: true` — all operations require explicit user invocation |
| Auto project detection | Project path resolved from git remote; no manual specification needed |
| Config separation | User config is separate from Skill files; not overwritten on reinstall |
| Label-based state | Issue Board labels automatically track development state |
| On-demand loading | SKILL.md is a lightweight router; action details loaded on demand to conserve context |

## Development & Testing

Run automated tests (development use only — the `tests/` directory is not deployed):

```bash
bash sdd_workflow/tests/run_tests.sh
```

Test coverage:
- `test_json_helper.py` — All 17 json-helper.py actions (78 test cases)
- `test_issue_parser.py` — Issue markdown parsing, section mapping, code block handling, TODO extraction, Reviewer parsing, completeness checks
- `test_config_functions.sh` — Branch name generation, base branch, MR target, no_proxy deduplication, exit codes
- `test_url_parsing.sh` — issue/MR/project URL parsing, host validation, exit code verification

## Changelog

See [`CHANGELOG.md`](./CHANGELOG.md) for detailed update history.
