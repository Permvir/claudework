中文版: [features.md](features.md)

# SDD Workflow — Feature Documentation

## Introduction

SDD (Spec-Driven Development) is a development workflow tool driven by GitLab issue specifications. Through the Claude Code Skill mechanism, use the `/sdd` command in any GitLab project directory to achieve a complete workflow from requirement reading, code development, MR submission, to automated review.

## File Structure

```
sdd_workflow/
├── features.md                         # This document
├── CHANGELOG.md                        # Changelog
├── install.sh                          # One-click install script (supports --uninstall)
├── skill/
│   ├── SKILL.md                        # Skill main file (lean router)
│   └── actions/                        # Detailed execution steps for each action
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
│       └── assign.md
├── scripts/
│   ├── config.sh                       # Configuration loader
│   ├── config-template.sh              # Configuration template
│   ├── gitlab-api.sh                   # GitLab API wrapper
│   ├── issue-parser.sh                 # Issue markdown parser
│   ├── mr-helper.sh                    # MR creation helper
│   └── json-helper.py                  # JSON operations + MR template rendering helper
├── references/
│   ├── gitlab-api-reference.md         # API endpoint quick reference
│   └── workflow-guide.md               # Workflow stage guide
├── templates/
│   ├── issue-spec-template.md          # Issue spec template
│   ├── dev-notes-template.md           # Development notes template
│   └── mr-description-template.md      # MR description template
├── examples/
│   └── sample-issue.md                 # Sample issue
└── tests/                              # Automated tests (development only, not deployed)
    ├── run_tests.sh                    # Test entry point
    ├── test_json_helper.py             # json-helper.py full action tests
    ├── test_issue_parser.py            # issue-parser.sh parsing tests
    ├── test_config_functions.sh        # config.sh helper function tests
    ├── test_url_parsing.sh             # gitlab-api.sh URL parsing + exit code tests
    └── fixtures/                       # Test issue fixtures
```

Post-installation deployment locations:
- `~/.claude/skills/sdd/` — Skill files + actions + scripts + references + templates + examples
- `~/.claude/sdd-config.sh` — User configuration (tokens, etc.; created only on first install, not overwritten on reinstall)

## Installation

```bash
bash sdd_workflow/install.sh
```

After installation, edit the configuration file to complete the following steps:

```bash
vi ~/.claude/sdd-config.sh
```

### Step 1: Set the GitLab Instance URL

Find the `GITLAB_URL` line and replace it with your team's GitLab URL (without trailing slash):

```bash
# Before (placeholder)
GITLAB_URL="https://your-gitlab.example.com"

# After (your actual URL)
GITLAB_URL="http://your-company-gitlab.com"
```

> Not sure about the URL? Open any project issue in your browser. The part before `/-/issues/` in the URL (minus the project path) is your `GITLAB_URL`.

### Step 2: Set the Personal Access Token

Find the `GITLAB_TOKEN` line and replace it with your Personal Access Token:

```bash
GITLAB_TOKEN="YOUR_TOKEN_HERE"   # Replace with your actual Token
```

**How to get a Token**: GitLab > Avatar (top-right) > Edit profile > Access Tokens > Add new token
- Name: anything (e.g., `sdd-workflow`)
- Expiration date: recommended (e.g., 90 days)
- Scopes: check **api**
- Click Create > Copy the generated Token (shown only once)

### Step 3: Verify Configuration

```bash
bash ~/.claude/skills/sdd/scripts/config.sh --export
```

Example output (when configured correctly):

```
SDD Workflow Configuration:

  [GitLab]
  GITLAB_URL              = http://your-company-gitlab.com
  GITLAB_TOKEN            = Set (20 characters)

  [Developer]
  DEVELOPER_NAME          = your.name

  [Git Branch Management]
  DEFAULT_BASE_BRANCH     = dev
  ...
```

If `GITLAB_TOKEN` shows "Not set", the Token was not entered correctly.

### Optional Configuration

The configuration file also contains the following options that can be adjusted as needed (all have default values and can be left blank):

```bash
# Developer name (leave empty to auto-detect from git config user.name)
DEVELOPER_NAME=""

# Default base branch (auto-detected: falls back to master if remote has no dev branch)
DEFAULT_BASE_BRANCH="dev"

# Whether to delete source branch after MR merge (default true)
MR_REMOVE_SOURCE_BRANCH="true"

# Whether to squash commits on MR merge (default true)
MR_SQUASH="true"
```

Token generation: GitLab > Settings > Access Tokens > Create (requires `api` scope)

> **Security note**: `~/.claude/sdd-config.sh` contains sensitive credentials such as Tokens. The install script automatically sets its permissions to 600 (owner read/write only). Do not commit this file to a git repository. It is recommended to set a Token expiration date in GitLab and rotate regularly (e.g., every 90 days). When expired, simply edit the configuration file to update the Token value.

### Multi-Account Switching (with gitlab_profiles)

When multiple people share the same computer, or you need to switch between different GitLab accounts, it is recommended to use the **gitlab_profiles** tool for dynamic account switching, without modifying `~/.claude/sdd-config.sh`.

**How it works**: When `gitlab_profiles` switches accounts, it writes `GITLAB_URL`, `GITLAB_TOKEN`, and `DEVELOPER_NAME` into the current shell's environment variables via `source`. When SDD's `config.sh` loads, it **prioritizes environment variables over configuration file values**, making the two naturally compatible without any code changes.

**Priority**: Environment variables (`gitlab_profiles` injected) > `~/.claude/sdd-config.sh` (local default account) > Script built-in defaults

**Usage**:

```bash
# 1. Install gitlab_profiles (if not already installed)
bash gitlab_profiles/install.sh

# 2. Add account profiles (each person does this once)
gitlab-use add
# Follow prompts: profile name, GitLab URL, Personal Access Token, developer name

# 3. Switch to your account before use (before starting Claude Code, or in a new session)
gitlab-use alice      # Switch to Alice's account

# 4. Use SDD as normal (automatically uses Alice's URL and Token)
/sdd read <issue_url>
```

**Typical scenario (multiple people sharing one Mac)**:

| Operator | Action | Effect |
|----------|--------|--------|
| Alice | `gitlab-use alice` | `GITLAB_TOKEN` switches to Alice's Token |
| Bob | `gitlab-use bob` | `GITLAB_TOKEN` switches to Bob's Token |
| Anyone | No `gitlab-use` executed | Uses the default account in `~/.claude/sdd-config.sh` |

**Note**: The `gitlab-use` switch effect is limited to the current shell session. It automatically expires when the terminal is closed and does not affect other users.

> `~/.claude/sdd-config.sh` serves as a **default account** fallback for personal computers. When sharing a machine, it is recommended to keep `GITLAB_TOKEN="YOUR_TOKEN_HERE"` (no Token filled in) in the config file, forcing everyone to switch via `gitlab-use` before using, to avoid accidentally submitting under someone else's account.

### Uninstall

```bash
bash sdd_workflow/install.sh --uninstall
```

> Uninstalling removes the `~/.claude/skills/sdd/` directory but preserves the user configuration file `~/.claude/sdd-config.sh` (contains sensitive credentials; must be manually deleted).

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `GITLAB_URL` | `http://gitlab.example.com` | GitLab instance URL |
| `GITLAB_TOKEN` | — | Personal Access Token (required) |
| `DEVELOPER_NAME` | git config user.name | Developer name, used for branch naming |
| `DEFAULT_BASE_BRANCH` | `dev` | Default base branch (auto-detected: falls back to `master` if remote has no dev branch) |
| `DEFAULT_BRANCH_TYPE` | `dev` | Default branch type (dev/hotfix/feature) |
| `BRANCH_PATTERN_DEV` | `dev-{developer}-{issue_iid}` | dev branch naming pattern |
| `BRANCH_PATTERN_HOTFIX` | `hotfix-{developer}-{issue_iid}` | hotfix branch naming pattern |
| `BRANCH_PATTERN_FEATURE` | `feature-{developer}-{issue_iid}` | feature branch naming pattern |
| `MR_REMOVE_SOURCE_BRANCH` | `true` | Delete source branch after MR merge |
| `MR_SQUASH` | `true` | Squash commits on MR merge |
| `SDD_CACHE_TTL` | `300` | Branch detection cache TTL (seconds), set to 0 to disable caching |

Verify configuration:

```bash
bash ~/.claude/skills/sdd/scripts/config.sh --export
```

## Usage

Launch Claude Code in any GitLab project directory:

### Issue URL Shorthand

**You only need to specify the issue URL on the first operation in a session; subsequent operations can omit it**. Claude automatically retrieves issue information from the conversation context.

Three formats are supported:
| Format | Example | Description |
|--------|---------|-------------|
| Full URL | `/sdd read http://gitlab.example.com/mygroup/myproject/-/issues/8` | First use or when switching issues |
| Issue number | `/sdd read 8` | Auto-constructs full URL from git remote |
| Omit URL | `/sdd review` | Reuses the issue loaded in the session |

**Typical workflow (within a single session)**:
```
/sdd read http://gitlab.example.com/mygroup/myproject/-/issues/8   <- Specify full URL first time
(Discuss requirements with Claude)
/sdd refine                                                 <- URL omitted, auto-reused
/sdd review                                                 <- URL omitted, auto-reused
/sdd dev                                                    <- URL omitted, auto-reused
(Write code...)
/sdd submit                                                 <- URL omitted, auto-reused
```

> **Note**: Omitting the URL requires that a command with an issue URL has already been executed in the current session. For a new session, you need to specify the issue URL again.

### Create Issue

```
/sdd create http://gitlab.example.com/mygroup/myproject Optimize login flow, add captcha verification
```

Automatically generates a structured issue based on the description using the SDD template (background, requirements, acceptance criteria). Checks required section completeness before creation, creates in GitLab, and automatically adds the `workflow::backlog` label.

### Read Issue

```
/sdd read http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Parses issue markdown and displays a structured summary (background, requirements, acceptance criteria), checking spec completeness. If the issue contains a "Related Issues" section, automatically fetches each related issue's title and status for display. If the issue is in `workflow::backlog` status, automatically updates to `workflow::start`.

### Refine Issue

```
/sdd refine http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Reads discussion points from the issue, discusses with Claude, and updates conclusions back into the issue description. Supports two modes:

**Mode A: In-session discussion writeback** — If `read` has been executed in the current session with subsequent discussion, `refine` automatically reviews conversation history and incorporates discussion conclusions into the issue description. Typical usage:
```
/sdd read <url>          <- Read the issue
(Freely discuss requirements, technical approach, etc. with Claude)
/sdd refine <url>        <- Write discussion conclusions back to the issue
```

**Mode B: Structured discussion** — If there is no existing discussion context, `refine` extracts discussion points from the issue for item-by-item discussion:
- **`## Questions` section**: General questions; removed from the list once resolved
- **`<!-- TODO: xxx -->` inline markers**: Specific questions close to context; marker deleted and conclusion written in place once resolved

If the issue is in `workflow::backlog` status, refine automatically updates the label to `workflow::start`; issues already in later stages are not affected. Can be executed multiple times to progressively refine requirements, suitable for the requirement refinement phase after `read` and before `dev`.

### Review Issue Spec

```
/sdd review http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Reviews issue spec quality from a cold reader's perspective, outputting a structured review report. Checks dimensions including structural completeness, requirement clarity, and acceptance criteria coverage, providing a pass/fail conclusion with specific improvement suggestions.

Recommended to run in a new session after refine and before dev, for an unbiased review.

### Review MR Code Changes

```
/sdd review http://gitlab.example.com/mygroup/myproject/-/merge_requests/42
```

Performs a structured review of MR code changes. Automatically fetches the MR diff and reviews each file across dimensions including code quality, security, test coverage, and potential bugs, outputting an MR Review report. If the MR description references an issue (e.g., `Closes #N`), it also checks requirement coverage against the issue's acceptance criteria. The review conclusion is automatically posted as a comment on the MR for team visibility.

### Dev

```
/sdd dev http://gitlab.example.com/mygroup/myproject/-/issues/8
/sdd dev --type=hotfix http://gitlab.example.com/mygroup/myproject/-/issues/8
/sdd dev --type=feature http://gitlab.example.com/mygroup/myproject/-/issues/8
```

By default, creates a development branch `dev-{developer}-8` from the `dev` branch, updates the issue label to `workflow::in dev`, and writes code and tests based on requirements. If the issue contains Related Issues, it automatically fetches the related issues' requirements and technical notes as cross-repository context before coding begins (code changes are limited to the current repository). Supports hotfix (from master) and feature (from master) types.

### Submit MR

```
/sdd submit http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Pushes code to remote, performs a local review of changes (first displays file statistics summary, shows diff snippets only for files with issues), automatically creates an MR and sets reviewers, and updates the label to `workflow::evaluation`. For hotfix/feature types with a dev branch, two MRs are automatically created (dev + master), with the first MR set to not delete the source branch, ensuring both MRs can merge from the same source branch; the source branch is automatically deleted by the second MR after both are merged. Reviewers are automatically extracted from the `## Reviewer` section of the issue description, setting all reviewers at once and sending a single @mention comment notification.

### Done (Close Issue)

```
/sdd done http://gitlab.example.com/mygroup/myproject/-/issues/8
```

After MR merge, manually trigger this command to close the issue. Automatically checks the merge status of associated MRs:
- **All merged**: Automatically updates the issue label to `workflow::done` and closes the issue
- **Not yet merged**: Prompts the user to confirm whether to force close

After closing, if currently on an SDD development branch, prompts whether to switch back to the base branch and delete the local development branch.

### Add Issue Comment

```
/sdd update http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Adds a structured comment to the GitLab Issue comment section. After execution, Claude interactively asks what you want to record. Simply describe in natural language, and Claude will automatically format and publish to the Issue comment section.

**Interaction flow example**:
```
> /sdd update 8

Claude: What would you like to record? This can include: completed items, key decisions, TODOs, etc.

User: Finished login API development and unit tests, decided token expiry should be 24 hours,
      still need to add integration tests and API documentation

Claude: Comment added to Issue #8
```

The comment is published in structured format to GitLab, visible to team members directly on the Issue page:
```markdown
### Development Notes — 2026-03-03

**Phase**: In Development

**Completed**:
- Finished login API development
- Completed unit tests

**Key Decisions**:
- Token expiry set to 24 hours

**TODOs**:
- Add integration tests
- Write API documentation
```

#### Prompt Usage During the update Interaction Phase

Claude's formatting capability extends beyond manual input. When the session context is rich (e.g., after completing a development session or requirements discussion), you can have Claude extract and generate comments directly from the conversation, with better results.

**Auto-extract from context** (least effort, recommended)

Let Claude proactively review the current conversation and auto-generate structured comments:

```
Record the completed features and conversation context for me
```
```
Based on our conversation, summarize what was done today and what decisions were made
```
```
Record the technical approach we just discussed and the final decisions
```

> Best used at the end of a development session or discussion, when conversation context is richest and results are best.

**Extract from a specific angle**

When you only want to record a certain type of information:

```
Focus on recording the technical decisions we just made, keep other content brief
```
```
Record the problems we encountered and solutions as experience notes
```
```
Record current progress and next steps, keep completed items brief
```

**Context + manual additions**

Let Claude summarize context while adding extra content you want to include:

```
Summarize today's conversation, and add to TODOs: still need to add integration tests and documentation tomorrow
```
```
Record today's progress from the conversation, add to key decisions: batch operations not supported for now, deferred to next iteration
```

**Pure manual input**

Directly describe content for Claude to format, independent of context:

```
Finished login API and unit tests, decided token expiry is 24h, still need integration tests
```

| Scenario | Recommended Approach |
| ---------------------- | ---------------------------- |
| Rich conversation, too lazy to type | "Summarize the conversation" style |
| Only want to record certain info | "Focus on decisions/issues/progress" |
| Need to add extra content | "Summarize conversation + also add xxx" |
| Sparse conversation content | Directly dictate content for Claude to format |

### Link Issues (link)

```
/sdd link http://gitlab.example.com/mygroup/backend/-/issues/12 Backend API interface definition
/sdd link --issue=8 http://gitlab.example.com/mygroup/frontend/-/issues/5
```

Appends a related URL to the "Related Issues" section of a specified issue. The current issue is obtained from session context (requires prior execution of `read`/`dev`, etc.), or can be explicitly specified via `--issue=N`. Automatically validates that the related issue exists and checks for duplicates; creates the section if it doesn't exist. If no description text is provided, the related issue's title is automatically used.

### View Work Status

```
/sdd status
```

Displays a current SDD work status overview: current branch, branch type, associated issue title and workflow stage, local unstaged/staged/unpushed change statistics. Useful for quickly understanding the current development context in a new session.

### Reopen Issue

```
/sdd reopen http://gitlab.example.com/mygroup/myproject/-/issues/8
```

Reopens a closed issue and updates the label to `workflow::start`.

### Assign Issue

```
/sdd assign http://gitlab.example.com/mygroup/myproject/-/issues/8 alice
/sdd assign 8 alice bob
/sdd assign --clear
```

Assigns an issue to one or more project members. `--clear` removes all assignees. If the issue URL is omitted, it is automatically obtained from session context.

### View Issue Board

```
/sdd list
/sdd list http://gitlab.example.com/mygroup/myproject
```

Lists issues with `workflow::` labels in the current project (or a specified project), grouped by workflow stage (In Development > Evaluation > Planned > Backlog). Each issue displays its number, title, and assignee. Useful for quickly understanding overall project progress.

### View Template

```
/sdd template
```

Outputs the SDD issue spec template for reference when creating new requirement issues.

## Intent Inference and Action Chaining

Each SDD action (create, read, dev, submit, etc.) is **independent** — there is no automatic triggering mechanism between actions. However, Claude will infer from the user's original intent whether to continue executing the next action.

### Real-World Example

User executes:
```
/sdd create http://gitlab.example.com/mygroup/claudework Improve the gitlab_profiles tool and test successfully on the shared Mac
```

Claude's reasoning process:
1. Identifies as **create action** (project URL + description) -> Created Issue #9
2. Analyzes user's original intent: "**Improve**...and **test successfully** on the shared Mac" — expresses wanting to **complete the entire task**, not just create an issue
3. References the hint in SKILL.md's create action: `After creation, you can directly use /sdd dev <issue_url> to start development`
4. Determines user expects the full workflow -> Proactively continues with dev action

Throughout this process, the create action ended at step 6 (returning the issue URL); the subsequent dev was proactively initiated by Claude based on intent inference.

### How to Control This Behavior

| User Expression | Claude Behavior | Reason |
|-----------------|-----------------|--------|
| `Improve the gitlab_profiles tool and test successfully` | create -> auto-continues to dev | Intent clearly includes "develop and complete" |
| `Create an issue for me: improve the gitlab_profiles tool` | create only | Intent explicitly limited to "create an issue" |
| `Create an issue to track gitlab_profiles improvement plans` | create only | Intent is to record and track, not develop immediately |

### Design Principles

- **Action Independence**: Each action has clear start and end boundaries, tracks state via GitLab labels, and has no configuration-level automatic chain triggering
- **Intent-Driven**: Claude infers the next action based on the user's natural language input, rather than preset process orchestration
- **Predictability**: To precisely control execution scope, explicitly express intent boundaries in instructions (e.g., "create an issue" rather than "improve a feature")

## Git Branch Management

> For detailed branch specifications and flow diagrams, see `references/workflow-guide.md`.

The project uses a master + dev dual main-branch model (summary):

| Branch Type | Base | MR Target | Naming Convention | Purpose |
|-------------|------|-----------|-------------------|---------|
| dev (default) | `dev` | `dev` | `dev-{developer}-{iid}` | Regular iterative development |
| hotfix | `master` | `dev` + `master` | `hotfix-{developer}-{iid}` | Production hotfixes |
| feature | `master` | `dev` + `master` | `feature-{developer}-{iid}` | Urgent short-cycle new features |

- **master**: Production environment; code must never be modified directly
- **dev**: Development main line; MR target for regular development
- **hotfix/feature**: Merged to both dev and master upon completion

> **Projects without a dev branch**: Remote branches are auto-detected. If no `dev` branch exists, the default base falls back to `master`. In this case, dev-type base and MR target are both `master`, and hotfix/feature MR targets merge only to `master`. Suitable for utility projects with only a master branch; no manual configuration required.

## Workflow State Transitions (Issue Board Labels)

> For detailed operational steps at each stage, see `references/workflow-guide.md`.

```
workflow::backlog -> workflow::start -> workflow::in dev -> workflow::evaluation -> workflow::done -> Closed
       |                |                  |                   |                    |
     Backlog          Planned           In Development     Evaluation/QA          Done
```

> All labels are `workflow::` scoped labels. Within the same scope, only one label is retained at a time; GitLab automatically replaces them.

| Label | Description | SDD Action |
|-------|-------------|------------|
| `workflow::backlog` | Backlog, requirement collection | — |
| `workflow::start` | Planned, upcoming development | `/sdd read` or `/sdd refine` sets automatically |
| `workflow::in dev` | Currently in development | `/sdd dev` sets automatically |
| `workflow::evaluation` | Testing/evaluation in progress | `/sdd submit` sets automatically; use `/sdd review <mr_url>` to review MR |
| `workflow::done` | Evaluation complete, ready to close | `/sdd done` sets automatically and closes issue |

## Issue Spec

SDD requires issues to be written in a uniform format containing the following sections:

1. **Background** — Problem context and motivation (required)
2. **Requirements** — List of functional requirements (required)
3. **Acceptance Criteria** — Verifiable completion conditions (required)
4. **Related Issues** — Cross-repository related Issue URLs (optional, for cross-repo collaboration)
5. **Technical Notes** — Technical constraints and recommendations (optional)
6. **Test Plan** — Test strategy and edge cases (optional)
7. **Reviewer** — MR reviewer (optional, automatically set when submitting MR)
8. **Questions** — Questions pending discussion (optional, used with `/sdd refine`)
9. **Development Notes** — Development process records (filled during development)

See `examples/sample-issue.md` for a complete example.

### Related Issues (Cross-Repository Collaboration)

When a task spans multiple repositories, issues in each repository can reference each other through the "Related Issues" section, allowing Claude to gain cross-repository global context during development.

**Usage**: In the issue's `## Related Issues` section, list one Issue URL per line with an optional brief description:

```markdown
## Related Issues

- http://gitlab.example.com/mygroup/backend/-/issues/12 — Backend API interface definition
- http://gitlab.example.com/mygroup/frontend/-/issues/8 — Frontend page adaptation
```

**SDD action behaviors**:
- **create** — Generated issues include an empty Related Issues section for later population
- **read** — Automatically fetches related issues' titles and statuses, displayed in the summary
- **refine** — Preserves the Related Issues section when refining issue content; does not modify related entries
- **review** — In spec review, external references in Related Issues are treated as reasonable dependencies and do not affect self-containment scoring
- **dev** — Automatically fetches related issues' requirements and technical notes before coding begins, understanding interface contracts, data formats, and other dependencies (code changes are limited to the current repository)
- **submit** — Does not involve the Related Issues section; MR description links the current issue via `Closes #N`
- **done** — Closes the current issue; does not affect the status of issues referenced in Related Issues
- **update** — Adds comments; does not involve the Related Issues section
- **link** — Appends a related URL to the current issue; auto-validates, deduplicates, and creates the section
- **list** — Lists the issue board; does not involve Related Issues
- **template** — Output template includes Related Issues section placeholder
- **status** — Displays current work status; does not involve Related Issues
- **reopen** — Reopens issue; does not involve the Related Issues section
- **assign** — Assigns issue; does not involve the Related Issues section

**Design principle**: Related Issues is an optional section and is not included in required field checks. SDD maintains a single-repo, single-issue core model; Related Issues only provides cross-repository reference context.

## Documentation Notes

> **Single Source of Truth**: `skill/SKILL.md` + `skill/actions/*.md` are the authoritative definition of the SDD workflow. This document (features.md) is a user-facing feature description. In case of discrepancies, SKILL.md and action files take precedence.

## Design Principles

| Principle | Description |
|-----------|-------------|
| Spec-Driven | Uses issue requirements as the development basis; acceptance criteria as completion criteria |
| Explicit User Invocation | `disable-model-invocation: true`; all operations require user initiation |
| Automatic Project Detection | Parses project path from git remote; no manual specification needed |
| Configuration Separation | User configuration is independent of Skill files; not lost on reinstall |
| Label Transitions | Automatically manages development state through Issue Board labels |
| On-Demand Loading | SKILL.md is a lean router; action details are loaded on demand, saving context |

## Development and Testing

Run automated tests (for development use; the tests/ directory is not deployed to user environments):

```bash
bash sdd_workflow/tests/run_tests.sh
```

Test coverage:
- `test_json_helper.py` — json-helper.py all 14 actions (59 test cases)
- `test_issue_parser.py` — Issue markdown parsing, section mapping, code block handling, TODO extraction, Reviewer parsing, completeness checking
- `test_config_functions.sh` — Branch name generation, base branch, MR target, no_proxy deduplication, error codes
- `test_url_parsing.sh` — Issue/MR/project URL parsing, host validation, exit code verification

## Changelog

See [`CHANGELOG.md`](./CHANGELOG.md) for detailed update history.
