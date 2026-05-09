# 🐝 agent-swarm-dev

> Your little coding bees, working in parallel, minding their own hives ✨

Launch isolated coding agents (Claude Code) in git worktrees, each in its own tmux session. Agents code, commit, and push independently. A background monitor watches for completion and sends notifications via WeCom webhook. 🎉

Dispatch from Claude Code, OpenClaw, Codex, or any AI assistant that supports skills — the coding agents themselves always run Claude Code.

## 🚀 Quick Start

Navigate to your project, one command to install:

```bash
cd /your/project
curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
```

This installs symlinks into `~/.openclaw/skills/` and/or `~/.claude/skills/` (whichever exist) and force-installs a cron job for auto cleanup.

### 🎯 Launch an Agent

Just tell your AI assistant:

```
launch a coding bee
```

Or run directly:

```bash
./agent-swarm-dev/bin/run-agent.sh feat-login "implement user login"
```

> **First run in a new project:** if no config exists, `run-agent.sh` will interactively guide you through creating one. If you're not in a git repo, it will ask you for a git URL to clone first.

### 📋 Check Status

Just tell your AI assistant:

```
check agents
```

or

```
swarm status
```

## 🧠 How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                      🐝 agent-swarm-dev 🐝                      │
│                                                                  │
│  You run: bin/run-agent.sh feat-login "implement login"          │
│       ↓                                                          │
│  0. 📦  (first run) interactive config setup if no .env exists   │
│  1. 🏗️  git worktree spins up an isolated workspace              │
│  2. 📺  tmux creates a background session                        │
│  3. 🤖  Claude Code codes inside                                  │
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

Project-level files (auto-created):

```
your-project/
├── .agent-swarm-<project>.env      ← Config (created interactively on first run)
├── .swarm-active-tasks.json        ← Active task records
├── .swarm-monitor.log              ← Monitor log
└── .swarm-worktrees/               ← Isolated worktree directories
```

## 🛠️ Installation

One-liner — just navigate to your project and run:

```bash
cd /your/project
curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
```

This detects platform directories (`~/.openclaw` and `~/.claude`), creates `skills/` subdirectories if needed, symlinks `SKILL.md` and `bin/` into each detected platform, and installs a cron job for merged branch cleanup. All files are symlinked — edit the cloned repo once, every project picks up the changes automatically.

If neither `~/.openclaw` nor `~/.claude` exists, the script exits with a message indicating no supported AI platform was found.

## ⚙️ Configuration

Config files live in your **project directory** as `.agent-swarm-<project-name>.env`. If no config exists, `run-agent.sh` will interactively prompt you to create one on first run. All fields are free-text input — no menus or options.

| Variable | Default | Purpose |
|----------|---------|---------|
| `SWARM_PROJECT_ROOT` | current dir | Git repo where agents create worktrees |
| `YUNXIAO_TOKEN` | (empty) | 云效 API token |
| `YUNXIAO_ORG_ID` | (empty) | 云效 org ID |
| `YUNXIAO_SPACE_ID` | (empty) | 云效 space ID |
| `YUNXIAO_REPO_ID` | (empty) | 云效 repo ID |
| `WECOM_WEBHOOK_URL` | (empty) | WeCom webhook URL |
| `GIT_AUTH_METHOD` | `none` | Git push auth: `token`, `ssh`, or `none` |
| `GIT_TOKEN` | (empty) | Personal access token (for `token` auth) |
| `GIT_SSH_KEY` | (empty) | SSH key path (for `ssh` auth) |
| `MAX_RETRIES` | `3` | Max retry attempts |
| `CHECK_INTERVAL_MINUTES` | `2` | Status check interval |

> 💡 **Minimum setup**: just set `SWARM_PROJECT_ROOT` to your git repo path. Everything else is optional — agents will work fine without it.

## 🎮 Usage

### Single Agent

```bash
./agent-swarm-dev/bin/run-agent.sh <task-id> "<prompt>"
```

Example:

```bash
./agent-swarm-dev/bin/run-agent.sh feat-user-api "implement user CRUD API"
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
  {"id": "feat-api",    "prompt": "implement user CRUD API"},
  {"id": "feat-auth",   "prompt": "implement JWT auth middleware"},
  {"id": "feat-db",     "prompt": "implement database models and migrations"}
]
EOF

./agent-swarm-dev/bin/swarm.sh /tmp/tasks.json
```

All agents launch in parallel, each in its own worktree. No interference~

### 🛑 Stop an Agent

```bash
./agent-swarm-dev/bin/stop-agent.sh <task-id>
```

Terminates the tmux session, updates task status to `stopped` (record preserved for tracing).

### 📋 Check All Agent Statuses

```bash
./agent-swarm-dev/bin/check-agents.sh
```

Shows all active tasks, tmux sessions, and latest monitor logs.

### 🧹 Clean Up Merged Branches

After an agent pushes its branch is preserved (so you can create an MR). Once merged, use this to sweep up:

```bash
# Preview what would be cleaned
./agent-swarm-dev/bin/cleanup-merged.sh --dry-run

# Actually do it
./agent-swarm-dev/bin/cleanup-merged.sh
```

Scans all `swarm/*` branches and cleans up merged ones — branches, worktrees, and task records in one go~

### ⏰ Scheduled Cleanup

The install script automatically sets up a cron job that runs every 5 minutes to clean merged branches across all registered projects:

```bash
# Install cron (defaults to every 5 minutes)
./agent-swarm-dev/bin/setup-cron.sh --install

# Uninstall
./agent-swarm-dev/bin/setup-cron.sh --uninstall

# Check status
./agent-swarm-dev/bin/setup-cron.sh --status
```

Projects are auto-registered when `run-agent.sh` creates a config file. Cleanup logs land in `~/.agent-swarm-dev/.swarm-cleanup.log`.

## 📦 Dependencies

- `git` — for worktree isolation
- `tmux` — for session management
- `jq` — for JSON task tracking
- `claude` (Claude Code CLI) — the coding agent

```bash
apt-get install -y jq tmux
```

## 🔄 Task Lifecycle

```
🚀 Run run-agent.sh
    ↓
📦  (first run) interactive config creation
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
| No commits after finish | Check monitor log: look for `.swarm-monitor.log` in project root |
| Commits exist but not pushed | Task record stays; push manually or check why agent failed to push |
| No .git found | `run-agent.sh` will prompt you to clone a repo, or set `SWARM_PROJECT_ROOT` in config |
| No config found | `run-agent.sh` interactively creates `.agent-swarm-<project>.env` on first run |

## 📝 Monitor Log

All events are recorded in `.swarm-monitor.log` (in the **project root**):

```bash
# Watch live
tail -f /your/project/.swarm-monitor.log

# Recent entries
tail -20 /your/project/.swarm-monitor.log
```

Log includes:
- Monitor start/stop times ⏱️
- Agent session end detection 🔍
- Git commit & push check results 📊
- WeCom notification delivery status 📢
- Task cleanup status 🧹
