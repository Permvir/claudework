中文版: [workflow-guide.md](workflow-guide.md)

# SDD Workflow Stage Guide

## Overview

The SDD (Spec-Driven Development) workflow is driven by GitLab Issue Board labels:

```
workflow::backlog -> workflow::start -> workflow::in dev -> workflow::evaluation -> workflow::done -> Closed
       |                |                  |                   |                    |
       |                |                  |                   |                    └── Evaluation complete, ready to close
       |                |                  |                   └── Testing/evaluation in progress
       |                |                  └── In development (/sdd dev)
       |                └── Planned, upcoming development
       └── Backlog (requirement collection)
```

> `workflow::` is a GitLab scoped label; within the same scope, only one label is retained at a time.

## Git Branch Management Specification

### Branch Model

```
master (production) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━→
  |              ↑ hotfix merged        ↑ feature merged  ↑ release
  |              |                   |               |
  ├──→ hotfix-developer-iid ──→ merge to both dev + master
  ├──→ feature-developer-iid ──→ merge to both dev + master
  |
dev (development main line) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━→
  |            ↑ dev branch merged
  ├──→ dev-developer-iid ──→ MR to dev
```

> **Projects without a dev branch**: Remote branches are auto-detected. If no `dev` branch exists, the default base falls back to `master`. In this case, dev-type base and MR target are both `master`, and hotfix/feature MR targets merge only to `master`. Suitable for utility projects with only a master branch; no manual configuration required.

### Branch Type Details

#### master Branch
- The main branch for production-stable and deployed features
- After feature development is complete, code is merged to master during release, typically tagged with a version number
- **Code must never be modified directly at any time**
- Only accepts merges from dev (releases), hotfix (emergency fixes), and feature (urgent features)

#### dev Branch
- Maintains code for the next upcoming release
- Only code for the next upcoming release should be merged into this branch
- MR target branch for regular iterative development

#### hotfix Branch
- Used for emergency production bug fixes, or developing urgent features with higher priority than the current iteration
- **Branched from master**
- Naming: `hotfix-{developer}-{issue_iid}` or `hotfix-{developer}-{issue_description}`
- After completion, **merged to both dev and master** (master only when no dev branch exists)

#### feature Branch
- Used for developing urgent, short-cycle new features for immediate deployment
- **Branched from master**
- Naming: `feature-{developer}-{issue_iid}` or `feature-{developer}-{feature_description}`
- After completion, **merged to both dev and master** (master only when no dev branch exists)

### Branch Selection in SDD

| Scenario | Branch Type | Command |
|----------|-------------|---------|
| Regular iteration requirement | dev | `/sdd dev <url>` |
| Production emergency bug | hotfix | `/sdd dev --type=hotfix <url>` |
| Urgent small feature deployment | feature | `/sdd dev --type=feature <url>` |

## Stage Zero: Create (Create Issue)

**Corresponding command**: `/sdd create <project_url> <description>`

**Steps**:
1. Extract `project_path` from project URL (using `parse-project-url`)
2. Call `resolve-project-id` to get `project_id`
3. Claude generates structured content based on user description + project context, following the SDD issue template:
   - Title, background, requirements list, acceptance criteria, technical notes
4. Spec completeness check (required sections: background, requirements, acceptance criteria); prompt user if missing
5. Directly call `create-issue` to create the issue (no user confirmation needed), automatically adding `workflow::backlog` label
6. Return issue URL

**Output**: Successfully created issue URL, ready for subsequent `/sdd read <issue_url>` or `/sdd dev <issue_url>`

## Stage One: Read (Requirement Reading)

**Corresponding command**: `/sdd read <url>`

**Steps**:
1. Extract `project_path` and `issue_iid` from issue URL
2. Call `resolve-project-id` to get `project_id`
3. Call `get-issue` to fetch issue details
4. Parse markdown into structured JSON using `issue-parser.sh`
5. Display structured summary to user:
   - Title, labels, assignees
   - Background, requirements list, acceptance criteria
   - Technical notes (if any)
6. Check spec completeness, marking missing sections
7. Fetch issue comments (supplementary context)
8. If issue is in `workflow::backlog` status, prompt user for confirmation before updating label to `workflow::start` (user can skip)

**Output**: Structured requirement summary + spec completeness check results

## Stage 1.5: Refine (Requirement Refinement)

**Corresponding command**: `/sdd refine <url>`

**Prerequisites**: `read` has been executed; issue contains discussion points

**Two modes**:

**Mode A — In-session discussion writeback** (auto-triggered when current session has read + discussion):
1. Re-fetch latest issue description
2. Review post-read conversation in current session, extracting conclusions
3. Generate updated description (conclusions incorporated into corresponding sections)
4. Display diff comparison, directly call `update-issue-description` to write back to GitLab (no user confirmation needed)

**Mode B — Structured discussion** (standard flow):
1. Same as read steps 1-4: fetch and parse issue, save original description
2. Extract discussion points:
   - Question list from `## Questions` section (`questions` / `questions_list`)
   - `<!-- TODO: xxx -->` inline markers (`todos`, with line numbers and context)
3. Display discussion points overview, then discuss item by item
   - Supports "skip" and "skip all"
   - Claude can read project code to answer technical questions
4. Generate updated description:
   - Resolved questions removed from `## Questions` (entire section deleted if all resolved)
   - Resolved TODO markers deleted, conclusions written in place
   - Unresolved items remain unchanged
5. Display diff comparison, directly call `update-issue-description` to write back to GitLab (no user confirmation needed)

**Output**: Updated issue description

**Notes**:
- If issue is in `workflow::backlog` status, refine automatically updates the label to `workflow::start`; issues already in later stages are not affected
- Can be executed multiple times to progressively refine requirements
- If issue has no discussion points, can enter free discussion mode

## Stage 1.7: Review (Spec Review)

`review` automatically selects the review mode based on URL type.

### Issue Spec Review

**Corresponding command**: `/sdd review <issue_url>`

**Prerequisites**: Refine has been executed to improve requirements (or issue spec is ready)

**Recommendation**: Execute in a new Claude session for a cold-reader perspective review

**Steps**:
1. Same as read steps 1-4: fetch and parse issue
2. Fetch issue comments as supplementary context
3. Review spec quality across dimensions (structural completeness, requirement clarity, acceptance criteria coverage, consistency, etc.)
4. Output structured review report with pass/fail conclusion

**Output**: Review report (blockers + suggestions + dimension evaluation table)

**Next steps**:
- Pass -> Proceed to `/sdd dev <url>`
- Fail -> Return to `/sdd refine <url>` to fix, then re-review

### MR Code Review

**Corresponding command**: `/sdd review <mr_url>`

**Prerequisites**: MR has been created (typically after `/sdd submit`)

**Steps**:
1. Parse MR URL, extract `project_path` and `mr_iid`
2. Get `project_id`
3. Fetch MR details (title, description, source/target branch)
4. Fetch MR changes (all file diffs)
5. Extract associated issue from MR description (if any), fetch issue details as requirement context
6. Review diff file by file: code quality, requirement coverage, security, test coverage, potential bugs
7. Output MR Review report
8. Automatically add review report as a comment on the MR

**Output**: MR Review report (must-fix items + suggested improvements + dimension evaluation table + change summary), also written to MR comments

## Stage Two: Dev (Development)

**Corresponding command**: `/sdd dev [--type=dev|hotfix|feature] <url>`

**Prerequisites**: `read` has been executed; requirements understood

**Steps**:
1. Parse issue URL, get project_id and issue information
2. Determine branch type (default dev), load corresponding branch configuration
3. Create development branch from the correct base branch (base determined by `get_base_branch()`):
   - dev type: `git checkout -b dev-developer-iid origin/dev` (`origin/master` when no dev branch)
   - hotfix type: `git checkout -b hotfix-developer-iid origin/master`
   - feature type: `git checkout -b feature-developer-iid origin/master`
4. Update issue label: add `workflow::in dev` (GitLab automatically removes old labels in the same scope)
5. Develop based on requirements:
   - Write code implementation
   - Write/update tests
   - Ensure tests pass
6. Commit code to development branch
7. Push branch to remote

**Notes**:
- During development, you can use `/sdd update <url>` at any time to add Issue comments recording progress
- Branch names are auto-generated from developer name and issue number

## Stage Three: Submit (Submission)

**Corresponding command**: `/sdd submit <url>`

**Prerequisites**: Development complete; code pushed to remote branch

**Steps**:
1. Parse issue URL, get project_id
2. Auto-identify branch type (dev/hotfix/feature) from current branch name
3. Determine MR target branch (decided by `get_primary_mr_target()`; with dev branch, hotfix/feature need to merge to both dev and master; without dev branch, all types merge to master only)
4. Check working directory: if there are uncommitted changes, prompt user to commit or stash first
5. Ensure code is pushed to remote
6. Local code review:
   - Get all change diffs
   - Review code quality, security, acceptance criteria compliance
   - Show review results to user
7. Generate MR description: fill template with issue information and change summary
8. Display MR creation plan and wait for user confirmation
9. Auto-create MR (using `mr-helper.sh create`), extract MR URL from API response
10. Set Reviewers: parse reviewer usernames from issue description, call `mr-helper.sh batch-notify-reviewers` to set all reviewers at once and send a single @mention comment
11. Update issue label: add `workflow::evaluation`

**Output**: MR creation result (URL) + Review summary

**hotfix/feature follow-up reminders**:
- With dev branch: hotfix/feature submit auto-creates two MRs for dev and master; first MR set to not delete source branch
- Without dev branch: all types create only one MR to master

## Stage Four: Update (Add Issue Comment)

**Corresponding command**: `/sdd update <url>`

**Steps**:
1. Parse issue URL
2. Interactively ask user what to record; user replies in natural language
3. Format user reply into structured comment per `dev-notes-template.md` (auto-categorized into completed items, key decisions, TODOs)
4. Call `add-issue-note` to add to GitLab Issue comment section
5. Confirm completion, display comment summary

**Output**: A new structured comment in the Issue comment section, viewable by team members directly on the GitLab Issue page

## Stage Five: Done (Close Issue)

**Corresponding command**: `/sdd done <url>`

**Prerequisites**: MR has been merged (typically after submit and passing review)

**Steps**:
1. Parse issue URL, get project_id and issue_iid
2. Call `list-issue-related-mrs` to get associated MR list
3. Check MR merge status:
   - **All merged** -> Proceed directly to step 4
   - **Unmerged MRs exist** -> Prompt user to confirm whether to still close
   - **No associated MRs** -> Prompt user to confirm whether to still close
4. Update label to `workflow::done`, close issue
5. Clean up local branch (optional): if currently on an SDD development branch, prompt user whether to switch back to base branch and delete local development branch

**Output**: Issue close confirmation, label updated to `workflow::done`

## Appendix: Status (Status Overview)

**Corresponding command**: `/sdd status`

**Steps**:
1. Parse branch type and issue number from current git branch name
2. Get project information from git remote
3. If issue_iid is parsed, query issue status (title, labels, workflow stage)
4. Get local change statistics (unstaged, staged, unpushed commits)
5. Display status overview

**Output**: Current branch, associated issue, workflow stage, local change statistics

## Appendix: Reopen (Reopen Issue)

**Corresponding command**: `/sdd reopen <issue_url>`

**Steps**:
1. Parse issue URL, get project_id and issue_iid
2. Fetch issue details, check if current state is closed
3. Confirm operation with user
4. Call `reopen-issue` to reopen the issue
5. Update label to `workflow::start`

**Output**: Issue reopen confirmation, label updated to `workflow::start`

**Note**: Only executes on issues in closed state; after reopening, you can continue using `/sdd dev` for development or `/sdd assign` for assignment

## Appendix: Assign (Assign Issue)

**Corresponding command**: `/sdd assign <issue_url> <username1> [username2 ...]`

**Steps**:
1. Parse issue URL, get project_id and issue_iid
2. Fetch issue details, display current assignees
3. Parse usernames, get user_id via `resolve-user-id`
4. Call `update-issue-assignees` to set assignees

**Output**: Assignee update confirmation

**Options**:
- `--clear`: Remove all assignees (mutually exclusive with usernames)
- This operation replaces all assignees rather than appending
- Does not modify issue labels or status

## Appendix: List (Issue Board)

**Corresponding command**: `/sdd list [project_url]`

**Steps**:
1. Determine project: get project path from parameter URL or git remote
2. Call `list-project-issues` to fetch all opened issues
3. Filter issues with `workflow::` labels, group by workflow stage (In Development > Evaluation > Planned > Backlog)
4. Display grouped results; each issue shows number, title, and assignee

**Output**: Issue board grouped by workflow stage

**Note**: Read-only operation; does not modify any content

## Appendix: Template (Template Output)

**Corresponding command**: `/sdd template`

**Steps**:
1. Read `templates/issue-spec-template.md`
2. Output template content for reference when creating new issues
