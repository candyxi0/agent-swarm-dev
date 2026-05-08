---
name: agent-swarm-dev
version: 2.0.0
description: |
  Launch coding agents (Claude Code) in isolated git worktrees with tmux sessions,
  automatic monitoring, and completion notifications via WeCom webhook. All scripts
  are self-contained in this skill — no external dependencies. Use when asked
  to "run an agent", "start a coding agent", "launch a swarm agent", "create an agent",
  "spin up a worktree", "启动agent", "启动编码agent", or manage multi-agent coding workflows. (agent-swarm-dev)
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

```bash
# Derive the skill directory dynamically from the symlink location
if [ -L "${CLAUDE_SKILL_DIR:-.}/SKILL.md" ]; then
  SWARM_DIR="$(cd "$CLAUDE_SKILL_DIR" && pwd)"
elif [ -L ".claude/skills/agent-swarm-dev/SKILL.md" ]; then
  SWARM_DIR="$(cd ".claude/skills/agent-swarm-dev" && pwd -P)"
elif [ -d "$HOME/.claude/skills/agent-swarm-dev" ]; then
  SWARM_DIR="$(cd "$HOME/.claude/skills/agent-swarm-dev" && pwd -P)"
else
  SWARM_DIR=""
fi

if [ -n "$SWARM_DIR" ] && [ -x "$SWARM_DIR/bin/run-agent.sh" ] && command -v jq &>/dev/null && command -v tmux &>/dev/null; then
  echo "SWARM_DIR=$SWARM_DIR"
  echo "SWARM_READY"
else
  echo "SWARM_NOT_FOUND"
fi
```

If `SWARM_NOT_FOUND`: tell the user to install the skill:

```bash
cd /your/project
curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
```

## Routing

After SETUP above, determine what the user wants:

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

- **Cleanup** — if the user wants to clean up merged branches:
  1. Run `"$SWARM_DIR/bin/cleanup-merged.sh" --dry-run` first
  2. Show results and ask before running without `--dry-run`

If the user's intent doesn't match any of the above, show a brief summary of what this skill can do.

First run auto-creates `$SWARM_DIR/.agent-swarm.env`. Edit it:

```bash
vim "$SWARM_DIR/.agent-swarm.env"
```

| Variable | Default | Purpose |
|----------|---------|---------|
| `SWARM_PROJECT_ROOT` | `.` (current dir) | Git repo where agents create worktrees |
| `YUNXIAO_TOKEN` | (empty) | 云效 API token |
| `YUNXIAO_ORG_ID` | (empty) | 云效 org ID |
| `YUNXIAO_SPACE_ID` | (empty) | 云效 space ID |
| `YUNXIAO_REPO_ID` | (empty) | 云效 repo ID |
| `WECOM_WEBHOOK_URL` | (empty) | 企业微信 webhook for notifications |
| `GIT_AUTH_METHOD` | `token` | Git push auth: `token` (uses GIT_TOKEN), `ssh`, or `none` |
| `GIT_TOKEN` | (empty) | Personal Access Token for git push (used when GIT_AUTH_METHOD=token) |
| `MAX_RETRIES` | `3` | Max retry attempts |
| `CHECK_INTERVAL_MINUTES` | `2` | Status check interval |

**Minimal setup**: set `SWARM_PROJECT_ROOT` to your git repo path. If using token
auth (default), also set `GIT_TOKEN`. Notifications and YunXiao are optional.

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

1. **Loads** config from `$SWARM_DIR/.agent-swarm.env` (auto-creates on first run)
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
8. **Records** task in `$SWARM_DIR/.swarm-active-tasks.json`

## Task Files

All state files live in `$SWARM_DIR`:

| File | Purpose |
|------|---------|
| `.agent-swarm.env` | Per-project config (auto-created) |
| `.swarm-active-tasks.json` | Active task records |
| `.swarm-monitor.log` | Monitor script log |

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
| no .git in project root | Set `SWARM_PROJECT_ROOT` in `.agent-swarm.env` |
| claude CLI missing | Install Claude Code or set `SWARM_AGENT_CMD` in config |

## Completion Flow

1. Agent codes → commits → pushes → tmux session ends
2. Monitor detects session end
3. Checks: commits exist + pushed to remote
4. If yes: sends WeCom notification (if webhook configured)
5. Removes task from `.swarm-active-tasks.json`
6. Worktree stays on disk (branch preserved for MR)
7. User creates MR manually
