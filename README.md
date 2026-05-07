# agent-swarm-dev

Launch isolated coding agents (Claude Code) in git worktrees, each in its own tmux session.
Agents code, commit, and push independently. A background monitor watches for completion
and sends notifications via WeCom webhook.

## Quick Start

### 1. Clone

```bash
git clone https://github.com/candyxi0/agent-swarm-dev.git
cd agent-swarm-dev && chmod +x bin/*.sh
```

### 2. Install into your project

```bash
cd /your/project
/path/to/agent-swarm-dev/bin/install.sh
```

### 3. Launch an agent

```bash
# Via skill trigger (in Claude Code)
# Just say: "launch an agent to implement X"

# Or run directly
.claude/skills/agent-swarm-dev/bin/run-agent.sh feat-login "实现用户登录功能"
```

### 4. Check status

```bash
.claude/skills/agent-swarm-dev/bin/check-agents.sh
```

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    /agent-swarm-dev skill                    │
│                                                              │
│  You say: "launch an agent to implement login"              │
│       ↓                                                      │
│  Claude Code → bin/run-agent.sh                              │
│       ↓                                                      │
│  1. git worktree creates isolated workspace                   │
│  2. tmux creates background session                          │
│  3. claude --print codes inside                              │
│  4. Background monitor polls tmux status every 5s             │
│  5. On completion → check git → WeCom notify → cleanup       │
└─────────────────────────────────────────────────────────────┘
```

Each agent is fully isolated: independent worktree + tmux session + git branch.

## Directory Structure

```
agent-swarm-dev/
├── SKILL.md              ← Claude Code skill document
├── SKILL.md.tmpl         ← Multi-host template (generates OpenClaw/Codex versions)
├── README.md             ← This file (English)
├── README_zh.md          ← Chinese version
├── .agent-swarm.env      ← Config file (auto-created on first run)
├── .swarm-active-tasks.json  ← Active task records (auto-created)
├── .swarm-monitor.log    ← Monitor log (auto-created)
└── bin/
    ├── install.sh        ← One-click install into any project
    ├── run-agent.sh      ← Core: launch a single agent
    ├── start-agent.sh    ← Launch wrapper with validation
    ├── stop-agent.sh     ← Safely stop an agent
    ├── check-agents.sh   ← View all agent statuses
    └── swarm.sh          ← Batch launch multiple agents in parallel
```

## Installation

```bash
# 1. Clone the repo
git clone https://github.com/candyxi0/agent-swarm-dev.git
cd agent-swarm-dev && chmod +x bin/*.sh

# 2. Install into your project
cd /your/project
/path/to/agent-swarm-dev/bin/install.sh
```

All files are symlinked — edit the cloned repo once, every project picks up the changes.

## Configuration

First run auto-creates `.agent-swarm.env` inside the skill directory. Edit it:

| Variable | Default | Purpose |
|----------|---------|---------|
| `SWARM_PROJECT_ROOT` | `.` | Git repo where agents create worktrees |
| `YUNXIAO_TOKEN` | (empty) | 云效 API token |
| `YUNXIAO_ORG_ID` | (empty) | 云效 org ID |
| `YUNXIAO_SPACE_ID` | (empty) | 云效 space ID |
| `YUNXIAO_REPO_ID` | (empty) | 云效 repo ID |
| `WECOM_WEBHOOK_URL` | (empty) | 企业微信 webhook URL |
| `MAX_RETRIES` | `3` | Max retry attempts |
| `CHECK_INTERVAL_MINUTES` | `2` | Status check interval |

**Minimum setup**: set `SWARM_PROJECT_ROOT` to your git repo. Everything else is optional.

## Usage

### Single Agent

```bash
.claude/skills/agent-swarm-dev/bin/run-agent.sh <task-id> "<prompt>"
```

Example:

```bash
.claude/skills/agent-swarm-dev/bin/run-agent.sh feat-user-api "实现用户CRUD API"
```

Watch in real-time:

```bash
tmux attach -t swarm-feat-user-api
```

### Batch Agents

```bash
cat > /tmp/tasks.json << 'EOF'
[
  {"id": "feat-api",    "prompt": "实现用户CRUD API"},
  {"id": "feat-auth",   "prompt": "实现JWT认证中间件"},
  {"id": "feat-db",     "prompt": "实现数据库模型和迁移"}
]
EOF

.claude/skills/agent-swarm-dev/bin/swarm.sh /tmp/tasks.json
```

All agents launch in parallel, each in its own worktree.

### Stop an Agent

```bash
.claude/skills/agent-swarm-dev/bin/stop-agent.sh <task-id>
```

### Check Status

```bash
.claude/skills/agent-swarm-dev/bin/check-agents.sh
```

## Dependencies

- `git` — for worktrees
- `tmux` — for session management
- `jq` — for JSON task tracking
- `claude` (Claude Code CLI) — the coding agent

```bash
apt-get install -y jq tmux
# Claude Code: https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview
```

## Task Lifecycle

```
Launch agent → create worktree → start tmux → claude codes → commit → push
                                                                        ↓
Worktree kept (for MR) ← remove task record ← send WeCom notify ← monitor detects completion ← tmux ends
```

## Branch & Directory Naming

| Item | Pattern | Example |
|------|---------|---------|
| Branch | `swarm/<task-id>` | `swarm/feat-login` |
| Worktree | `.swarm-worktrees/<task-id>` | `.swarm-worktrees/feat-login` |
| Tmux session | `swarm-<task-id>` | `swarm-feat-login` |

The `swarm/` prefix avoids conflicts with your project's existing branches.

## Updating

```bash
cd /path/to/agent-swarm-dev
git pull
```

That's it. All projects instantly pick up the changes via symlinks.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `SWARM_NOT_FOUND` | Run `chmod +x bin/*.sh` in the cloned repo |
| `jq not found` | `apt-get install -y jq` |
| `tmux not found` | `apt-get install -y tmux` |
| `claude not found` | Install Claude Code CLI |
| Agent already running | `tmux attach -t swarm-<id>` to view, or `stop-agent.sh <id>` to kill |
| Worktree exists already | Pick a different task-id, or `git worktree remove` |
| No commits after finish | Check monitor log: `tail .agent-swarm.env`'s dir for `.swarm-monitor.log` |
