# 🐝 agent-swarm-dev

> Your little coding bees, working in parallel, minding their own hives ✨

Launch isolated coding agents (Claude Code) in git worktrees, each in its own tmux session. Agents code, commit, and push independently. A background monitor watches for completion and sends notifications via WeCom webhook. 🎉

## 🚀 Quick Start

Navigate to your project, one command to install:

```bash
cd /your/project
curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
```

### 🎯 Launch an Agent

```bash
# Via Claude Code skill
# Just say: "launch an agent to implement login"

# Or run directly
.claude/skills/agent-swarm-dev/bin/run-agent.sh feat-login "实现用户登录功能"
```

### 📋 Check Status

```bash
.claude/skills/agent-swarm-dev/bin/check-agents.sh
```

## 🧠 How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                      🐝 agent-swarm-dev 🐝                      │
│                                                                  │
│  You say: "launch an agent to implement login"                   │
│       ↓                                                          │
│  Claude Code → bin/run-agent.sh                                  │
│       ↓                                                          │
│  1. 🏗️  git worktree spins up an isolated workspace              │
│  2. 📺  tmux creates a background session                        │
│  3. 🤖  claude --print codes inside                              │
│  4. 👀  background monitor polls tmux status every 5s            │
│  5. 🎉 completion → check git → WeCom notify → tidy up           │
└─────────────────────────────────────────────────────────────────┘
```

Each agent is fully isolated: independent worktree + tmux session + git branch. No stepping on each other's toes~

## 📁 Directory Structure

```
agent-swarm-dev/
├── SKILL.md                    ← Claude Code skill document
├── SKILL.md.tmpl               ← Multi-host template (OpenClaw/Codex)
├── README.md                   ← This file (English)
├── README_zh.md                ← Chinese version
├── .agent-swarm.env            ← Config (auto-created on first run)
├── .swarm-active-tasks.json    ← Active task records (auto-created)
├── .swarm-monitor.log          ← Monitor log (auto-created)
└── bin/
    ├── install.sh              ← One-click install into any project 🛒
    ├── run-agent.sh            ← Core: launch a single agent 🚀
    ├── start-agent.sh          ← Launch wrapper with validation 📦
    ├── stop-agent.sh           ← Safely stop an agent 🛑
    ├── check-agents.sh         ← View all agent statuses 📋
    ├── swarm.sh                ← Batch launch multiple agents 🐝🐝🐝
    ├── cleanup-merged.sh       ← Clean up merged branches & worktrees 🧹
    └── setup-cron.sh           ← One-click setup of scheduled cleanup ⏰
```

## 🛠️ Installation

One-liner — just navigate to your project and run:

```bash
cd /your/project
curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
```

This clones the repo (if needed) and creates symlinks in `.claude/skills/`. All files are symlinked — edit the cloned repo once, every project picks up the changes automatically.

## ⚙️ Configuration

First run auto-creates `.agent-swarm.env` inside the skill directory. You can edit it:

| Variable | Default | Purpose |
|----------|---------|---------|
| `SWARM_PROJECT_ROOT` | `.` | Git repo where agents create worktrees |
| `YUNXIAO_TOKEN` | (empty) | 云效 API token |
| `YUNXIAO_ORG_ID` | (empty) | 云效 org ID |
| `YUNXIAO_SPACE_ID` | (empty) | 云效 space ID |
| `YUNXIAO_REPO_ID` | (empty) | 云效 repo ID |
| `WECOM_WEBHOOK_URL` | (empty) | WeCom webhook URL |
| `MAX_RETRIES` | `3` | Max retry attempts |
| `CHECK_INTERVAL_MINUTES` | `2` | Status check interval |

> 💡 **Minimum setup**: just set `SWARM_PROJECT_ROOT` to your git repo path. Everything else is optional — agents will work fine without it.

## 🎮 Usage

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

Stop it:

```bash
tmux kill-session -t swarm-feat-user-api
```

### 🐝🐝🐝 Batch Parallel Agents

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

All agents launch in parallel, each in its own worktree. No interference~

### 🛑 Stop an Agent

```bash
.claude/skills/agent-swarm-dev/bin/stop-agent.sh <task-id>
```

Terminates the tmux session, updates task status to `stopped` (record preserved for tracing).

### 📋 Check All Agent Statuses

```bash
.claude/skills/agent-swarm-dev/bin/check-agents.sh
```

Shows all active tasks, tmux sessions, and latest monitor logs.

### 🧹 Clean Up Merged Branches

After an agent pushes its branch is preserved (so you can create an MR). Once merged, use this to sweep up:

```bash
# Preview what would be cleaned
.claude/skills/agent-swarm-dev/bin/cleanup-merged.sh --dry-run

# Actually do it
.claude/skills/agent-swarm-dev/bin/cleanup-merged.sh
```

Scans all `swarm/*` branches and cleans up merged ones — branches, worktrees, and task records in one go~

### ⏰ Scheduled Cleanup (Optional)

Don't want to remember? Set up a daily cron job to auto-sweep:

```bash
# Install cron (defaults to 2:30 AM daily)
.claude/skills/agent-swarm-dev/bin/setup-cron.sh --install

# Uninstall
.claude/skills/agent-swarm-dev/bin/setup-cron.sh --uninstall

# Check status
.claude/skills/agent-swarm-dev/bin/setup-cron.sh --status
```

Cleanup logs land in `.swarm-cleanup.log` for you to peek at anytime~

### 🤖 Trigger via Skill

After installation, trigger agent-swarm-dev in Claude Code by saying any of these:

- "launch an agent"
- "start a coding agent"
- "launch swarm agent"

## 📦 Dependencies

- `git` — for worktree isolation
- `tmux` — for session management
- `jq` — for JSON task tracking
- `claude` (Claude Code CLI) — the coding agent

```bash
apt-get install -y jq tmux
# Claude Code: https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview
```

## 🔄 Task Lifecycle

```
🚀 Launch agent
    ↓
🏗️  Create worktree (.swarm-worktrees/<task-id>)
    ↓
📺  Create tmux session (swarm-<task-id>)
    ↓
🤖  claude --print codes inside
    ↓
📝  git commit + git push
    ↓
🔚  tmux session ends
    ↓
👀  Background monitor detects completion
    ↓
✅  Checks: new commits exist + pushed to remote
    ↓
📢  Send WeCom notification (if webhook configured)
    ↓
🧹  Clean task record from .swarm-active-tasks.json
    ↓
📦  Worktree kept on disk (branch preserved for MR)
```

## 🏷️ Branch & Directory Naming

| Item | Pattern | Example |
|------|---------|---------|
| Git branch | `swarm/<task-id>` | `swarm/feat-login` |
| Worktree directory | `.swarm-worktrees/<task-id>` | `.swarm-worktrees/feat-login` |
| Tmux session | `swarm-<task-id>` | `swarm-feat-login` |

The `swarm/` prefix avoids conflicts with your project's existing branches~

## 📜 Agent Constraints

Each agent receives these constraints at startup:

1. 🏠 Code only within the current worktree directory
2. 📐 Follow project coding conventions
3. 📝 Commit changes via `git commit` when done
4. 📤 Push to the remote branch
5. 🚫 **DO NOT** modify any files in the skill directory
6. 🤐 Just code & commit — status updates are handled by the background monitor

## 🔄 Updating

```bash
cd ~/agent-swarm-dev
git pull
```

That's it. All projects instantly pick up the changes via symlinks~

## ❓ Troubleshooting

| Problem | Fix |
|---------|-----|
| `SWARM_NOT_FOUND` | Make sure `bin/*.sh` are executable: `chmod +x bin/*.sh` |
| `jq not found` | `apt-get install -y jq` |
| `tmux not found` | `apt-get install -y tmux` |
| `claude not found` | Install Claude Code CLI |
| Agent already running | `tmux attach -t swarm-<id>` to watch, or `stop-agent.sh <id>` to kill |
| Worktree/branch already exists | Pick a different task-id, or `git worktree remove` manually |
| No commits after finish | Check monitor log: look for `.swarm-monitor.log` in the skill directory |
| Commits exist but not pushed | Task record stays; push manually or check why agent failed to push |
| No .git found | Set the correct `SWARM_PROJECT_ROOT` in `.agent-swarm.env` |

## 📝 Monitor Log

All events are recorded in `.swarm-monitor.log` (in the skill directory):

```bash
# Watch live
tail -f ~/agent-swarm-dev/.swarm-monitor.log

# Recent entries
tail -20 ~/agent-swarm-dev/.swarm-monitor.log
```

Log includes:
- Monitor start/stop times ⏱️
- Agent session end detection 🔍
- Git commit & push check results 📊
- WeCom notification delivery status 📢
- Task cleanup status 🧹
