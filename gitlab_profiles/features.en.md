中文版: [features.md](features.md)

# GitLab Multi-Account Switching

Easily switch between multiple accounts on the same GitLab instance, affecting only the current shell session. The `gitlab-use` command switches with one command, overriding authentication identity for both the SDD workflow and git push.

---

## File Structure

```
gitlab_profiles/
├── features.md              # Feature documentation (Chinese)
├── features.en.md           # Feature documentation (this file)
├── install.sh               # One-click install script
├── lib/
│   └── functions.sh         # Core function library
└── templates/
    └── profile.sh.tpl       # Profile template
```

After installation:

```
~/.claude/gitlab-profiles/
├── .functions.sh            # Core function library (installed by install.sh)
├── .template                # Profile template (installed by install.sh)
├── alice.sh                 # Profile file
└── <other-user>.sh          # Other account profiles
```

---

## Installation

```bash
bash install.sh
```

The script automatically:

- Creates the `~/.claude/gitlab-profiles/` directory
- Installs the core function library `.functions.sh` and template `.template`
- Injects the `gitlab-use` function into `~/.zshrc` (supports upgrades: re-running updates to the latest version)
- If no profiles exist, automatically launches interactive creation of the first one

Installation is **idempotent** — re-running updates the function library and zshrc function without affecting existing profiles.

---

## Usage

### List Available Profiles

```bash
gitlab-use
# Current: alice
# Available profiles:
#   * alice  (active)
#     charlie
#
# Commands: gitlab-use <name> | add | remove <name> | info [name]
```

After entering a project directory, you can also use this command to see which GitLab account is active in the current session:

```bash
cd /path/to/project
gitlab-use
# Current: bob
```

### Switch Account

```bash
gitlab-use alice
# Switched to GitLab profile: alice (https://code.gitlab.example.com)
```

Token validity is automatically verified during switching; a warning is shown on failure but the switch still completes.

After switching, the following operations in the current shell session will use the new identity:

- **SDD workflow**: `GITLAB_TOKEN`, `GITLAB_URL`, `DEVELOPER_NAME` are updated
- **git commit**: `GIT_AUTHOR_NAME`/`GIT_COMMITTER_NAME`/`EMAIL` are set
- **git push**: credential helper injected via `GIT_CONFIG_COUNT` automatically provides the username and token

> **Note**: The credential helper only works with **HTTPS** protocol remotes. If a repository was checked out via SSH (`git@...`), push authentication still uses the SSH key, and `gitlab-use` account switching has **no effect** on push — though commit author information will still be set correctly.

### Add a New Profile

```bash
gitlab-use add
# === Add New GitLab Profile ===
#
# Profile name: charlie
# GitLab URL [https://code.gitlab.example.com]:
# Personal Access Token (api scope): glpat-xxxxxxxxxxxx
# Verifying Token... ✓ Valid (user: charlie)
# Developer name [charlie]:
# Git email [charlie@gitlab.example.com]:
#
# ✓ Profile 'charlie' created
#   Use gitlab-use charlie to switch
```

Interactive guided input with automatic Token validation and username retrieval from the GitLab API.

### Remove a Profile

```bash
gitlab-use remove charlie
# ✓ Profile 'charlie' removed
```

You cannot remove the currently active profile — switch to another profile first before removing.

### View Profile Details

```bash
gitlab-use info
# === Profile: alice ===
# Status:     ✓ Active
# GitLab URL: https://code.gitlab.example.com
# Token:      glpat-xxxx...xxxx
# Developer:  alice
# Email:      alice@gitlab.example.com
# Token:      ✓ Valid
```

```bash
gitlab-use info charlie    # View a specific profile (does not need to be active)
```

### Direct Source

You can also bypass the `gitlab-use` function and source a profile file directly:

```bash
source ~/.claude/gitlab-profiles/alice.sh
```

---

## HTTPS Usage Notes

`gitlab_profiles` push authentication relies on the HTTPS credential helper — **repository remotes must use the HTTPS protocol**.

### Cloning a New Repository (Recommended Workflow)

```bash
gitlab-use bob                                      # 1. Switch account first
git clone https://code.gitlab.example.com/group/repo.git          # 2. Then clone — authentication is automatic
```

> **Order matters**: `git clone` itself requires authentication, so you must run `gitlab-use` before cloning. If you clone a private repository first and then switch accounts, the clone will fail due to authentication errors.

### Existing Repository (SSH to HTTPS)

If a repository was already checked out via SSH, **you do not need to re-checkout** — just change the remote URL:

```bash
git remote set-url origin https://code.gitlab.example.com/mygroup/myproject.git
```

After changing, verify that the credential helper works:

```bash
echo -e "host=code.gitlab.example.com\nprotocol=https" | git credential fill
# Expected output includes username=bob and password=<token>
```

### SSH vs HTTPS Comparison

| Protocol | commit author | push auth             | gitlab-use effective?     |
| -------- | ------------- | --------------------- | ------------------------- |
| HTTPS    | ✓ bob   | ✓ bob token     | Fully effective           |
| SSH      | ✓ bob   | ✗ SSH key account     | Commit only               |

---

## Technical Details

### Problem

On macOS, git push defaults to the osxkeychain credential helper, which is global and caches credentials by domain. Multiple accounts under the same GitLab domain cannot be switched through conventional means — `GIT_ASKPASS` is not invoked when a credential helper is present.

### Solution

Use the `GIT_CONFIG_COUNT` environment variable to inject git configuration into the current session, overriding all existing credential helpers:

```bash
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0="credential.helper"
export GIT_CONFIG_VALUE_0=""                    # Clear all existing helpers (osxkeychain/store/cat)
export GIT_CONFIG_KEY_1="credential.helper"
export GIT_CONFIG_VALUE_1="!f() { ... }; f"    # Inject a helper that reads from environment variables
```

Key points:

- **`GIT_CONFIG_VALUE_0=""`**: An empty value clears the credential.helper chain, including osxkeychain
- **Second `credential.helper`**: After clearing, adds a custom helper that reads the token from environment variables
- **`GIT_TERMINAL_PROMPT=0`**: Fails fast on token errors instead of hanging for input
- **Session-scoped only**: All variables are `export`ed and automatically expire when the terminal is closed

### Command Invocation Flow

When a user runs `gitlab-use` in the terminal, the actual call chain is:

```
gitlab-use <args>
    ↓
gitlab-use() function defined in ~/.zshrc (thin wrapper)
    ↓
source ~/.claude/gitlab-profiles/.functions.sh   ← dynamically loaded on each invocation
    ↓
_gitlab_use_main "$@"   ← actual business logic entry point
```

The benefit of this design: `.functions.sh` is sourced on each invocation, so after reinstalling (`bash install.sh`) to update the function library, **there is no need to `source ~/.zshrc` — the next `gitlab-use` call automatically picks up the changes**. The wrapper function in `~/.zshrc` itself rarely changes and only needs reloading when install.sh has structural upgrades.

### Compatibility with SDD Workflow

SDD loads configuration via `~/.claude/sdd-config.sh`, where `GITLAB_URL`/`GITLAB_TOKEN`/`DEVELOPER_NAME` use the `${VAR:-default}` pattern — if environment variables are already set, they take priority. After a profile file `export`s these variables, SDD automatically uses the profile values without any modifications to sdd-config.sh.

---

## Verification

```bash
# 1. Install
bash gitlab_profiles/install.sh

# 2. Load shell configuration
source ~/.zshrc

# 3. List available profiles
gitlab-use

# 4. Add a new profile
gitlab-use add

# 5. Switch to alice
gitlab-use alice

# 6. View current profile details
gitlab-use info

# 7. Verify SDD variables
echo "GITLAB_TOKEN: ${GITLAB_TOKEN}"
echo "DEVELOPER_NAME: ${DEVELOPER_NAME}"
echo "GITLAB_URL: ${GITLAB_URL}"

# 8. Verify git push authentication
echo -e "host=code.gitlab.example.com\nprotocol=https" | git credential fill
# Expected output includes username=alice and password=<token>

# 9. Remove a test profile
gitlab-use remove test
```

---

## Design Principles

| Principle              | Implementation                                                                       |
| ---------------------- | ------------------------------------------------------------------------------------ |
| **Session isolation**  | All variables set via `export`, affecting only the current shell; expires on terminal close |
| **Zero intrusion**     | Does not modify `~/.gitconfig`, Keychain, or `sdd-config.sh`                         |
| **SDD compatible**     | Leverages the `${VAR:-default}` mechanism in SDD's config loader; environment variables take priority |
| **Idempotent install** | install.sh supports upgrades; re-running updates the function library and zshrc function |
| **Token validation**   | Automatically validates Token on add and switch; warns on failure without blocking    |
| **Interactive add**    | `gitlab-use add` guides input, auto-validates, and generates the profile             |
| **Modular**            | Core logic in a standalone function library; zshrc only injects a thin wrapper       |
