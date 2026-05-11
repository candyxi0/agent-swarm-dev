# 🐝 agent-swarm-dev

> Your little coding bees, working in parallel, minding their own hives ✨

Launch isolated coding agents (Claude Code) in git worktrees, each in its own tmux session. Agents code, commit, and push independently. A background monitor watches for completion and sends notifications via WeCom webhook. 🎉

Dispatch from Claude Code, OpenClaw, Codex, or any AI assistant that supports skills — the coding agents themselves always run Claude Code.

## 🚀 Quick Start

Navigate to your project and install:

```
cd /your/project
curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
```

This installs symlinks into `~/.openclaw/skills/` and/or `~/.claude/skills/` (whichever exist) and sets up a cron job for auto cleanup.

> **First run in a new project:** if no config exists, the skill will interactively guide you through creating one. If you're not in a git repo, it will ask you for a git URL to clone first.

## 🧠 How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                      🐝 agent-swarm-dev 🐝                      │
│                                                                  │
│  You say: "launch a coding bee to implement login"               │
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

## 🎮 What You Can Do

All interactions are through natural language — just tell your AI assistant:

| What you want | What to say |
|--------------|-------------|
| Launch a coding agent | "launch a coding bee" or "启动小蜜蜂" |
| Check agent status | "check agents" or "查看小蜜蜂状态" |
| View registered projects | "list projects" or "查看项目列表" |
| Stop an agent | "stop agent feat-login" or "停止agent" |
| Launch multiple agents | "launch agents for these tasks..." or "批量启动agent" |
| Clean up merged branches | "cleanup merged branches" or "清理分支" |

The skill handles the rest — worktree creation, tmux session, background monitoring, notifications.

## ⚙️ Configuration

Config files live in your **project directory** as `.agent-swarm-<project-name>.env`. If no config exists, the skill will interactively prompt you to create one on first run.

| Variable | Default | Purpose |
|----------|---------|---------|
| `SWARM_PROJECT_ROOT` | current dir | Git repo where agents create worktrees |
| `WECOM_WEBHOOK_URL` | (empty) | WeCom webhook URL |
| `GIT_AUTH_METHOD` | `none` | Git push auth: `token`, `ssh`, or `none` |
| `GIT_TOKEN` | (empty) | Personal access token (for `token` auth) |
| `GIT_SSH_KEY` | (empty) | SSH key path (for `ssh` auth) |
| `YUNXIAO_TOKEN` | (empty) | 云效 API token |
| `YUNXIAO_ORG_ID` | (empty) | 云效 org ID |
| `YUNXIAO_SPACE_ID` | (empty) | 云效 space ID |
| `YUNXIAO_REPO_ID` | (empty) | 云效 repo ID |
| `MAX_RETRIES` | `3` | Max retry attempts |
| `CHECK_INTERVAL_MINUTES` | `2` | Status check interval |

> 💡 **Minimum setup**: just set `SWARM_PROJECT_ROOT` to your git repo path. Everything else is optional — agents will work fine without it.

## 📁 Directory Structure

Project-level files (auto-created):

```
your-project/
├── .agent-swarm-<project>.env      ← Config (created interactively on first run)
├── .swarm-active-tasks.json        ← Active task records
├── .swarm-monitor.log              ← Monitor log
└── .swarm-worktrees/               ← Isolated worktree directories
```

## 🔄 Task Lifecycle

```
🚀 You ask to launch an agent
    ↓
📦  (first run) interactive config creation
    ↓
🏗️  Create worktree (.swarm-worktrees/<task-id>)
    ↓
📺  Create tmux session (swarm-<task-id>)
    ↓
🤖  Claude Code codes inside
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

Just pull the repo and all projects instantly pick up the changes via symlinks~

## 📦 Dependencies

- `git` — for worktree isolation
- `tmux` — for session management
- `jq` — for JSON task tracking
- `claude` (Claude Code CLI) — the coding agent

## ❓ Troubleshooting

| Problem | Fix |
|---------|-----|
| `SWARM_NOT_FOUND` | Make sure `bin/*.sh` are executable: `chmod +x bin/*.sh` |
| `jq not found` | `apt-get install -y jq` |
| `tmux not found` | `apt-get install -y tmux` |
| `claude not found` | Install Claude Code CLI |
| Agent already running | Ask your AI assistant to check status or stop the agent |
| Worktree/branch already exists | Pick a different task-id, or ask to clean up merged branches |
| No commits after finish | Check monitor log: look for `.swarm-monitor.log` in project root |
| No config found | The skill will interactively guide you through creating one on first run |
