English version: [features.en.md](features.en.md)

# GitLab 多账户切换

在同一个 GitLab 实例上方便地切换多个账户，仅影响当前 shell session。`gitlab-use` 命令一键切换，同时覆盖 SDD 工作流和 git push 的认证身份。

---

## 文件结构

```
gitlab_profiles/
├── features.md              # 功能文档（本文件）
├── install.sh               # 一键安装脚本
├── lib/
│   └── functions.sh         # 核心函数库
└── templates/
    └── profile.sh.tpl       # Profile 模板
```

安装后生成：

```
~/.claude/gitlab-profiles/
├── .functions.sh            # 核心函数库（由 install.sh 安装）
├── .template                # Profile 模板（由 install.sh 安装）
├── alice.sh                 # Profile 文件
└── <other-user>.sh          # 其他账户 profile
```

---

## 安装

```bash
bash install.sh
```

脚本会自动完成：

- 创建 `~/.claude/gitlab-profiles/` 目录
- 安装核心函数库 `.functions.sh` 和模板 `.template`
- 在 `~/.zshrc` 注入 `gitlab-use` 函数（支持升级：重复执行会更新为最新版）
- 若无任何 profile，自动引导交互式创建第一个

安装是**幂等**的，重复执行会更新函数库和 zshrc 函数，不影响已有 profile。

---

## 使用方式

### 查看可用 profile

```bash
gitlab-use
# 当前: alice
# 可用 profiles:
#   * alice  (active)
#     zhangsan
#
# 命令: gitlab-use <name> | add | remove <name> | info [name]
```

进入某个项目目录后，也可通过此命令查看当前 session 激活的是哪个 GitLab 账户：

```bash
cd /path/to/project
gitlab-use
# 当前: bob
```

### 切换账户

```bash
gitlab-use alice
# Switched to GitLab profile: alice (https://code.gitlab.example.com)
```

切换时会自动验证 Token 有效性，失败时给出警告但仍完成切换。

切换后，当前 shell session 中的以下操作都会使用新身份：

- **SDD 工作流**：`GITLAB_TOKEN`、`GITLAB_URL`、`DEVELOPER_NAME` 已更新
- **git commit**：`GIT_AUTHOR_NAME`/`GIT_COMMITTER_NAME`/`EMAIL` 已设置
- **git push**：通过 `GIT_CONFIG_COUNT` 注入的 credential helper 自动提供用户名和 token

> **注意**：credential helper 仅对 **HTTPS** 协议的 remote 生效。若仓库以 SSH 方式（`git@...`）checkout，push 认证仍使用 SSH key，`gitlab-use` 的账户切换对 push **无效**，commit author 信息仍会正确设置。

### 添加新 profile

```bash
gitlab-use add
# === 添加新 GitLab Profile ===
#
# Profile 名称: zhangsan
# GitLab URL [https://code.gitlab.example.com]:
# Personal Access Token (api scope): glpat-xxxxxxxxxxxx
# 验证 Token... ✓ 有效 (用户: zhangsan)
# 开发者名称 [zhangsan]:
# Git 邮箱 [zhangsan@gitlab.example.com]:
#
# ✓ Profile 'zhangsan' 已创建
#   使用 gitlab-use zhangsan 切换
```

交互式引导输入，自动验证 Token 有效性并从 GitLab API 获取用户名。

### 删除 profile

```bash
gitlab-use remove zhangsan
# ✓ Profile 'zhangsan' 已删除
```

不允许删除当前激活的 profile，需先切换到其他 profile 再删除。

### 查看 profile 详情

```bash
gitlab-use info
# === Profile: alice ===
# 状态:       ✓ 激活中
# GitLab URL: https://code.gitlab.example.com
# Token:      glpat-xxxx...xxxx
# 开发者:     alice
# 邮箱:       alice@gitlab.example.com
# Token 状态: ✓ 有效
```

```bash
gitlab-use info zhangsan    # 查看指定 profile（不需要激活）
```

### 直接 source

也可以不通过 `gitlab-use` 函数，直接 source profile 文件：

```bash
source ~/.claude/gitlab-profiles/alice.sh
```

---

## HTTPS 使用须知

`gitlab_profiles` 的 push 认证依赖 HTTPS credential helper，**仓库 remote 必须使用 HTTPS 协议**。

### 新克隆仓库（推荐流程）

```bash
gitlab-use bob                                      # 1. 先切换账户
git clone https://code.gitlab.example.com/group/repo.git          # 2. 再 clone，认证自动完成
```

> **顺序很重要**：`git clone` 本身就需要认证，必须先 `gitlab-use` 再 clone。若先 clone 私有仓库再切换账户，clone 会因认证失败而报错。

### 已有仓库（SSH 转 HTTPS）

若仓库已通过 SSH 方式 checkout，**不需要重新 checkout**，直接改 remote URL 即可：

```bash
git remote set-url origin https://code.gitlab.example.com/mygroup/myproject.git
```

改完后验证 credential helper 是否生效：

```bash
echo -e "host=code.gitlab.example.com\nprotocol=https" | git credential fill
# 预期输出包含 username=bob 和 password=<token>
```

### SSH vs HTTPS 对比

| 协议    | commit author | push 认证           | gitlab-use 是否生效 |
| ----- | ------------- | ----------------- | --------------- |
| HTTPS | ✓ bob   | ✓ bob token | 完全生效            |
| SSH   | ✓ bob   | ✗ SSH key 账户      | 仅 commit 生效     |

---

## 技术原理

### 问题

macOS 上 git push 默认使用 osxkeychain credential helper，全局生效且按域名缓存凭据。同一 GitLab 域名下的多个账户无法通过常规方式切换——`GIT_ASKPASS` 在有 credential helper 时不会被调用。

### 解决方案

使用 `GIT_CONFIG_COUNT` 环境变量在当前 session 注入 git 配置，覆盖所有已有的 credential helper：

```bash
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0="credential.helper"
export GIT_CONFIG_VALUE_0=""                    # 清空所有已有 helper（osxkeychain/store/cat）
export GIT_CONFIG_KEY_1="credential.helper"
export GIT_CONFIG_VALUE_1="!f() { ... }; f"    # 注入读取环境变量的 helper
```

关键点：

- **`GIT_CONFIG_VALUE_0=""`**：空值会清空 credential.helper 链，包括 osxkeychain
- **第二条 `credential.helper`**：在清空后添加自定义 helper，从环境变量读取 token
- **`GIT_TERMINAL_PROMPT=0`**：token 错误时快速报错，不挂起等待输入
- **仅影响当前 session**：所有变量都是 `export`，关闭终端后自动失效

### 命令调用流程

用户在终端执行 `gitlab-use` 时，实际调用链如下：

```
gitlab-use <args>
    ↓
~/.zshrc 中定义的 gitlab-use() 函数（thin wrapper）
    ↓
source ~/.claude/gitlab-profiles/.functions.sh   ← 每次调用时动态加载
    ↓
_gitlab_use_main "$@"   ← 真正的业务逻辑入口
```

这种设计的好处：`.functions.sh` 是每次调用时才 source 的，因此重新安装（`bash install.sh`）更新函数库后，**无需 `source ~/.zshrc`，下次执行 `gitlab-use` 即自动生效**。`~/.zshrc` 中的 wrapper 函数本身极少变化，只在 install.sh 有结构性升级时才需要重载。

### 与 SDD 工作流的兼容

SDD 通过 `~/.claude/sdd-config.sh` 加载配置，其中 `GITLAB_URL`/`GITLAB_TOKEN`/`DEVELOPER_NAME` 使用 `${VAR:-default}` 模式——如果环境变量已设置则优先使用。Profile 文件 `export` 这些变量后，SDD 会自动使用 profile 中的值，无需修改 sdd-config.sh。

---

## 验证方式

```bash
# 1. 安装
bash gitlab_profiles/install.sh

# 2. 加载 shell 配置
source ~/.zshrc

# 3. 查看可用 profile
gitlab-use

# 4. 添加新 profile
gitlab-use add

# 5. 切换到 alice
gitlab-use alice

# 6. 查看当前 profile 详情
gitlab-use info

# 7. 验证 SDD 变量
echo "GITLAB_TOKEN: ${GITLAB_TOKEN}"
echo "DEVELOPER_NAME: ${DEVELOPER_NAME}"
echo "GITLAB_URL: ${GITLAB_URL}"

# 8. 验证 git push 认证
echo -e "host=code.gitlab.example.com\nprotocol=https" | git credential fill
# 预期输出包含 username=alice 和 password=<token>

# 9. 删除测试 profile
gitlab-use remove test
```

---

## 设计原则

| 原则             | 实现方式                                          |
| -------------- | --------------------------------------------- |
| **Session 隔离** | 所有变量通过 `export` 设置，仅影响当前 shell，关闭终端自动失效       |
| **零侵入**        | 不修改 `~/.gitconfig`、Keychain 或 `sdd-config.sh` |
| **SDD 兼容**     | 利用 SDD 配置加载器的 `${VAR:-default}` 机制，环境变量优先     |
| **幂等安装**       | install.sh 支持升级，重复执行更新函数库和 zshrc 函数           |
| **Token 验证**   | 添加和切换时自动验证 Token 有效性，失败时警告但不阻塞                |
| **交互式添加**      | `gitlab-use add` 引导输入，自动验证并生成 profile         |
| **模块化**        | 核心逻辑在独立函数库中，zshrc 仅注入 thin wrapper            |
