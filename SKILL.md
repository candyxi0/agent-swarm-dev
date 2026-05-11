---
name: agent-swarm-dev
version: 2.0.0
description: |
  Launch coding agents (Claude Code) in isolated git worktrees with tmux sessions,
  automatic monitoring, and completion notifications via WeCom webhook. All scripts
  are self-contained in this skill — no external dependencies. Use when asked
  to "run an agent", "start a coding agent", "launch a swarm agent", "create an agent",
  "spin up a worktree", "启动agent", "启动编码agent", "启动小蜜蜂", or manage multi-agent coding workflows. (agent-swarm-dev)
triggers:
  - run an agent
  - start a coding agent
  - launch swarm agent
  - create agent task
  - start worktree agent
  - launch an agent
  - launch a coding agent
  - launch swarm
  - start an agent
  - run a coding agent
  - start a swarm agent
  - launch worktree agent
  - start a coding bee
  - coding agent
  - swarm agent
  - worktree agent
  - multi-agent
  - parallel agent
  - 启动 agent
  - 启动一个 agent
  - 启动编码 agent
  - 启动 swarm agent
  - 启动小蜜蜂
  - 启动 worktree agent
  - 运行 agent
  - 运行一个 agent
  - 创建 agent 任务
  - 启动并行 agent
  - 启动多 agent
  - 编码 agent
  - 开启编码代理
  - check agents
  - check agent status
  - agent status
  - swarm status
  - list agents
  - show agents
  - view active tasks
  - 查看 agent 状态
  - 查看小蜜蜂状态
  - 查看任务状态
  - 查看活跃任务
  - 检查 agent 状态
  - agent 状态
  - 任务状态
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# agent-swarm-dev: Multi-Agent Coding Workflow

All scripts are self-contained in this skill. No external project dependencies.

## SETUP (run first)

### Step 1: Locate the skill directory

```bash
# Derive the skill directory dynamically from the symlink location
if [ -L "${CLAUDE_SKILL_DIR:-.}/SKILL.md" ]; then
  SWARM_DIR="$(cd "$CLAUDE_SKILL_DIR" && pwd)"
elif [ -L ".openclaw/plugin-skills/agent-swarm-dev/SKILL.md" ]; then
  SWARM_DIR="$(cd ".openclaw/plugin-skills/agent-swarm-dev" && pwd -P)"
elif [ -L ".claude/skills/agent-swarm-dev/SKILL.md" ]; then
  SWARM_DIR="$(cd ".claude/skills/agent-swarm-dev" && pwd -P)"
elif [ -d "$HOME/.openclaw/plugin-skills/agent-swarm-dev" ]; then
  SWARM_DIR="$(cd "$HOME/.openclaw/plugin-skills/agent-swarm-dev" && pwd -P)"
elif [ -d "$HOME/.claude/skills/agent-swarm-dev" ]; then
  SWARM_DIR="$(cd "$HOME/.claude/skills/agent-swarm-dev" && pwd -P)"
else
  SWARM_DIR=""
fi

if [ -z "$SWARM_DIR" ] || [ ! -x "$SWARM_DIR/bin/run-agent.sh" ]; then
  echo "SWARM_NOT_FOUND"
  echo "Tell the user to install first:"
  echo '  cd /your/project && curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash'
  # STOP — do not continue
fi

echo "SWARM_DIR=$SWARM_DIR"
echo "SWARM_READY"
```

### Step 2: Detect git repo + config, create if needed

If `SWARM_READY` above, run the following detection flow.

**CRITICAL**: Only check the current working directory (`$(pwd)`). Never scan parent directories, never fall back to other projects. The flow must strictly follow:

```bash
CWD="$(pwd)"

# Check if current directory ITSELF is a git repo (not a parent)
if [ -d "$CWD/.git" ]; then
  IS_GIT_REPO="yes"
  PROJECT_ROOT="$CWD"
  # Derive project name from git remote
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
  if [ -n "$REMOTE_URL" ]; then
    PROJECT_NAME="${REMOTE_URL%.git}"
    PROJECT_NAME="${PROJECT_NAME##*/}"
    PROJECT_NAME=$(echo "$PROJECT_NAME" | tr ' ' '-' | tr -cd 'a-zA-Z0-9_.-')
  fi
  if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME=$(basename "$PROJECT_ROOT" | tr ' ' '-' | tr -cd 'a-zA-Z0-9_.-')
  fi
else
  IS_GIT_REPO="no"
  PROJECT_ROOT=""
  PROJECT_NAME=""
fi

echo "IS_GIT_REPO=$IS_GIT_REPO"
echo "PROJECT_ROOT=$PROJECT_ROOT"
echo "PROJECT_NAME=$PROJECT_NAME"
```

**If `IS_GIT_REPO=no`**: The current directory is not a git repository.
1. Ask the user: "当前目录不是一个 git 仓库，请提供一个仓库地址"
2. Use `git clone <url>` to clone the repo into the current directory
3. Set `PROJECT_ROOT` to the newly cloned directory path and `cd` into it
4. Derive `PROJECT_NAME` from the repo name as above

**If `IS_GIT_REPO=yes`**: Check for config in the current directory ONLY — no parent scanning:

```bash
CONFIG_FILE="$PROJECT_ROOT/.agent-swarm-${PROJECT_NAME}.env"
if [ ! -f "$CONFIG_FILE" ]; then
  CONFIG_FILE="$PROJECT_ROOT/.agent-swarm.env"
fi

if [ -f "$CONFIG_FILE" ]; then
  echo "CONFIG_EXISTS=$CONFIG_FILE"
else
  echo "NO_CONFIG"
fi
```

**If `CONFIG_EXISTS`**: Config found. Source it and proceed to Routing.

**If `NO_CONFIG`**: No config found. Use `AskUserQuestion` to collect all config values from the user:

1. Ask the user for each value using `AskUserQuestion` with "Other" option for free text:
   - **Git 仓库路径** (`SWARM_PROJECT_ROOT`): default to `$PROJECT_ROOT`
   - **Git 推送认证方式**: token / ssh / 跳过
   - **GIT_TOKEN** (if token selected, optional)
   - **GIT_SSH_KEY** (if ssh selected, optional)
   - **企业微信 Webhook URL** (optional)
   - **云效 Token** (optional, skip all YunXiao fields if empty)
   - **云效 Org/Space/Repo ID** (only if Token provided)
   - **最大重试次数**: default 3
   - **检查间隔分钟数**: default 2

2. After collecting all values, write the config file:

```bash
cat > "$PROJECT_ROOT/.agent-swarm-${PROJECT_NAME}.env" << EOF
# agent-swarm-dev configuration — project: $PROJECT_NAME
SWARM_PROJECT_ROOT="$SWARM_PROJECT_ROOT"
YUNXIAO_TOKEN="$YUNXIAO_TOKEN"
YUNXIAO_ORG_ID="$YUNXIAO_ORG_ID"
YUNXIAO_SPACE_ID="$YUNXIAO_SPACE_ID"
YUNXIAO_REPO_ID="$YUNXIAO_REPO_ID"
WECOM_WEBHOOK_URL="$WECOM_WEBHOOK_URL"
GIT_AUTH_METHOD="$GIT_AUTH_METHOD"
GIT_TOKEN="$GIT_TOKEN"
GIT_SSH_KEY="$GIT_SSH_KEY"
MAX_RETRIES="$MAX_RETRIES"
CHECK_INTERVAL_MINUTES="$CHECK_INTERVAL_MINUTES"
EOF
```

3. Register project in unified cleanup registry and install cron if needed:

```bash
# Add project to unified project list
"$SWARM_DIR/bin/setup-cron.sh" --add "$SWARM_PROJECT_ROOT"

# Install unified cron if not already present
"$SWARM_DIR/bin/setup-cron.sh" --install
```

This ensures every project shares a single cron job. The cron iterates all registered projects from `~/.agent-swarm-dev/.swarm-projects.list` and cleans up each one independently.

4. Tell the user the config has been saved and proceed to Routing.

After the config is created, proceed to Routing.

## Routing

After SETUP above (SWARM_DIR located, config created/verified), determine what the user wants:

- **Check status / view agents** — if the user asks about agent status, active tasks, swarm status, or 查看状态/查看小蜜蜂:
  ```bash
  "$SWARM_DIR/bin/check-agents.sh"
  ```
  Also show `jq '.' "$SWARM_DIR/.swarm-active-tasks.json"` if check-agents.sh fails.

- **Launch a new agent** — if the user wants to start a coding agent, create a task, or 启动agent/启动小蜜蜂:
  1. Ask the user for the task ID and what to implement (unless already provided)
  2. Run `"$SWARM_DIR/bin/run-agent.sh" <task-id> "<prompt>"`

- **Stop an agent** — if the user wants to stop/kill an agent:
  1. Ask which task-id
  2. Run `"$SWARM_DIR/bin/stop-agent.sh" <task-id>`

- **Batch launch** — if the user wants multiple agents in parallel:
  1. Ask for the list of tasks
  2. Write them to a JSON file and run `"$SWARM_DIR/bin/swarm.sh" <json-file>`

- **New repo + workspace** — if the user wants to create a new code repository and start a fresh workspace:
  1. Ask the user for:
     - **Repository name** (becomes the directory name)
     - **Git remote URL** (optional — skip to create a local-only repo)
     - **Project description** (optional — used for initial README)
  2. Create a new directory and initialize it as a git repo:
     ```bash
     mkdir -p "<repo-name>"
     cd "<repo-name>"
     git init
     ```
  3. If a remote URL was provided, set it:
     ```bash
     git remote add origin <remote-url>
     ```
  4. Derive `PROJECT_NAME` and `PROJECT_ROOT` from the new directory
  5. Create a new config file `.agent-swarm-${PROJECT_NAME}.env` interactively using `AskUserQuestion` (same flow as NO_CONFIG in SETUP section)
  6. Register the project in the cleanup registry:
     ```bash
     "$SWARM_DIR/bin/setup-cron.sh" --add "$SWARM_PROJECT_ROOT"
     ```
  7. Tell the user the new workspace is ready, then proceed to **Launch a new agent** flow

- **Cleanup** — if the user wants to clean up merged branches:
  1. Run `"$SWARM_DIR/bin/cleanup-merged.sh" --dry-run` first
  2. Show results and ask before running without `--dry-run`

If the user's intent doesn't match any of the above, show a brief summary of what this skill can do.

Project-local config is stored as `$PROJECT_ROOT/.agent-swarm-<name>.env` (or `.agent-swarm.env`).

| Variable | Default | Purpose |
|----------|---------|---------|
| `SWARM_PROJECT_ROOT` | `.` (current dir) | Git repo where agents create worktrees |
| `YUNXIAO_TOKEN` | (empty) | 云效 API token |
| `YUNXIAO_ORG_ID` | (empty) | 云效 org ID |
| `YUNXIAO_SPACE_ID` | (empty) | 云效 space ID |
| `YUNXIAO_REPO_ID` | (empty) | 云效 repo ID |
| `WECOM_WEBHOOK_URL` | (empty) | 企业微信 webhook for notifications |
| `GIT_AUTH_METHOD` | `none` | Git push auth: `token`, `ssh`, or `none` |
| `GIT_TOKEN` | (empty) | Personal Access Token for git push (used when GIT_AUTH_METHOD=token) |
| `GIT_SSH_KEY` | (empty) | SSH key path for git push (used when GIT_AUTH_METHOD=ssh) |
| `MAX_RETRIES` | `3` | Max retry attempts |
| `CHECK_INTERVAL_MINUTES` | `2` | Status check interval |

**Minimal setup**: set `SWARM_PROJECT_ROOT` to your git repo path. Notifications and YunXiao are optional.

## Core Command

```bash
"$SWARM_DIR/bin/run-agent.sh" <task-id> <prompt>
```

| Parameter | Description | Example |
|-----------|-------------|---------|
| `<task-id>` | Unique task ID (becomes branch `swarm/<id>`) | `feat-login` |
| `<prompt>` | What to implement (Chinese or English) | `实现用户登录功能` |

### Quick Start

```bash
# Launch an agent
"$SWARM_DIR/bin/run-agent.sh" feat-login "实现用户登录功能，包括JWT token生成和验证"

# Watch it in real-time
tmux attach -t swarm-feat-login

# Stop it
tmux kill-session -t swarm-feat-login
```

## What run-agent.sh Does

1. **Loads** project-local config: `.agent-swarm-<name>.env` (project root, name from git remote) → `.agent-swarm.env` (current dir) → `$SWARM_DIR/` (fallback)
2. **Resolves** project root from `SWARM_PROJECT_ROOT` (defaults to `.`)
3. **Creates** git worktree at `$PROJECT_ROOT/.swarm-worktrees/<task-id>` on branch `swarm/<task-id>` from `main`
4. **Fetches** latest `origin/main`
5. **Launches** detached tmux session `swarm-<task-id>`
6. **Sends** structured prompt to `claude --print` inside tmux
7. **Spawns** background monitor that:
   - Watches tmux session
   - Checks for commits + push status
   - Sends WeCom notification (if configured)
   - Removes task from task file
8. **Records** task in `$PROJECT_ROOT/.swarm-active-tasks.json`

## Task Files

All state files live in `$PROJECT_ROOT` (the git repo root):

| File | Purpose |
|------|---------|
| `.agent-swarm-<name>.env` | Per-project config |
| `.swarm-active-tasks.json` | Active task records (per-project) |
| `.swarm-monitor.log` | Monitor script log (per-project) |

### View Active Tasks

```bash
"$SWARM_DIR/bin/check-agents.sh"
```

Or manually:

```bash
jq '.' "$SWARM_DIR/.swarm-active-tasks.json"
```

## Batch / Parallel Agents

```bash
# Option 1: use swarm.sh with a JSON file
cat > /tmp/tasks.json << 'EOF'
[
  {"id": "feat-user-api", "prompt": "实现用户CRUD API"},
  {"id": "feat-auth", "prompt": "实现认证和授权中间件"},
  {"id": "feat-db", "prompt": "实现数据库模型和迁移"}
]
EOF
"$SWARM_DIR/bin/swarm.sh" /tmp/tasks.json

# Option 2: launch manually in parallel
"$SWARM_DIR/bin/run-agent.sh" feat-user-api "实现用户CRUD API" &
"$SWARM_DIR/bin/run-agent.sh" feat-auth "实现认证和授权中间件" &
wait
```

Each agent gets its own worktree + tmux session + branch. Fully independent.

## Monitoring

### Check all agents

```bash
"$SWARM_DIR/bin/check-agents.sh"
```

Shows task status, tmux sessions, and recent monitor logs.

### Check single agent

```bash
tmux has-session -t swarm-<task-id> && echo "running" || echo "not running"
```

### View all swarm sessions

```bash
tmux ls | grep swarm-
```

### View monitor log

```bash
tail -f "$SWARM_DIR/.swarm-monitor.log"
```

## Agent Constraints

Every agent receives these constraints in its prompt:
1. Work only in the current worktree directory
2. Follow project conventions
3. Commit changes when done
4. Push to remote branch
5. **DO NOT** modify the skill directory or any skill files
6. Just commit + push; external monitor handles status updates

## Stop an Agent

```bash
"$SWARM_DIR/bin/stop-agent.sh" <task-id>
```

Stops tmux session, updates task status to "stopped". Task record is preserved
so you can see what happened.

## Error Cases

| Situation | Resolution |
|-----------|-----------|
| tmux session exists | Agent already running. `tmux attach -t swarm-<id>` |
| worktree/branch exists | Reuse or pick a new task-id |
| no new commits | Agent finished but didn't commit. Check tmux log. |
| unpushed commits | Task record stays. Push manually if needed. |
| no config found | Run the skill in your project directory; it will guide you through setup |
| claude CLI missing | Install Claude Code or set `SWARM_AGENT_CMD` in config |

## Completion Flow

1. Agent codes → commits → pushes → tmux session ends
2. Monitor detects session end
3. Checks: commits exist + pushed to remote
4. If yes: sends WeCom notification (if webhook configured)
5. Removes task from `.swarm-active-tasks.json`
6. Worktree stays on disk (branch preserved for MR)
7. User creates MR manually
