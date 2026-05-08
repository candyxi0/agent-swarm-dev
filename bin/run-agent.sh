#!/usr/bin/env bash
# run-agent.sh — Launch a coding agent in an isolated git worktree
#
# Usage: run-agent.sh <task-id> <prompt>
# Example: run-agent.sh feat-login "实现用户登录功能"
#
# Configuration: reads from <script-dir>/.agent-swarm.env
# If .agent-swarm.env doesn't exist, creates it from defaults on first run.

set -euo pipefail

##############################################################################
# Resolve directories
##############################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"          # resolves to ~/agent-swarm-dev/

##############################################################################
# Auto-detect project config
# Priority: SWARM_PROJECT_NAME env > match SWARM_PROJECT_ROOT to cwd > fallback
##############################################################################
find_project_config() {
  local cwd="$(pwd)"

  # 1) Explicit project name from env
  if [ -n "${SWARM_PROJECT_NAME:-}" ]; then
    local cfg="$SWARM_DIR/.agent-swarm-${SWARM_PROJECT_NAME}.env"
    if [ -f "$cfg" ]; then echo "$cfg"; return; fi
  fi

  # 2) Scan all project configs, match by SWARM_PROJECT_ROOT
  for cfg in "$SWARM_DIR"/.agent-swarm-*.env; do
    [ -f "$cfg" ] || continue
    # Extract SWARM_PROJECT_ROOT value (handle quoted strings)
    local root
    root=$(grep "^SWARM_PROJECT_ROOT=" "$cfg" 2>/dev/null | head -1 | cut -d= -f2- | sed 's/^"//;s/"$//' || true)
    if [ -n "$root" ]; then
      # Resolve to absolute if relative
      case "$root" in
        /*) ;;
        *) root="" ;;
      esac
      # Check if cwd is under this project root
      if [ -n "$root" ] && [[ "$cwd" == "$root"* ]]; then
        echo "$cfg"
        return
      fi
    fi
  done

  # 3) Fallback to default (backward compatible)
  if [ -f "$SWARM_DIR/.agent-swarm.env" ]; then
    echo "$SWARM_DIR/.agent-swarm.env"
    return
  fi

  # No config found
  echo ""
}

SWARM_CONFIG="$(find_project_config)"

if [ -z "$SWARM_CONFIG" ]; then
  echo "Error: No project configuration found."
  echo "Run 'bash bin/install.sh' inside your project directory first."
  exit 1
fi

##############################################################################
# Load or create config
##############################################################################
if [ ! -f "$SWARM_CONFIG" ]; then
  # Try to migrate from old .clawdbot/.env if it exists
  OLD_ENV="${SWARM_MIGRATE_FROM:-/root/txl/my-project/.clawdbot/.env}"

  # Extract known keys from old env or use empty defaults
  _YUNXIAO_TOKEN=""
  _YUNXIAO_ORG_ID=""
  _YUNXIAO_SPACE_ID=""
  _YUNXIAO_REPO_ID=""
  _WECOM_WEBHOOK_URL=""
  _GIT_TOKEN=""
  _MAX_RETRIES=""
  _CHECK_INTERVAL=""
  MIGRATED_MSG=""

  if [ -f "$OLD_ENV" ]; then
    _YUNXIAO_TOKEN=$(grep "^YUNXIAO_TOKEN=" "$OLD_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)
    _YUNXIAO_ORG_ID=$(grep "^YUNXIAO_ORG_ID=" "$OLD_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)
    _YUNXIAO_SPACE_ID=$(grep "^YUNXIAO_SPACE_ID=" "$OLD_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)
    _YUNXIAO_REPO_ID=$(grep "^YUNXIAO_REPO_ID=" "$OLD_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)
    _WECOM_WEBHOOK_URL=$(grep "^WECOM_WEBHOOK_URL=" "$OLD_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)
    _GIT_TOKEN=$(grep "^GIT_TOKEN=" "$OLD_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)
    _MAX_RETRIES=$(grep "^MAX_RETRIES=" "$OLD_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)
    _CHECK_INTERVAL=$(grep "^CHECK_INTERVAL_MINUTES=" "$OLD_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true)
    MIGRATED_MSG="[agent-swarm] Migrated settings from $OLD_ENV"
  fi

  cat > "$SWARM_CONFIG" << EOF
# agent-swarm-dev configuration
# Edit these values for your project.

# Project root (the git repo where agents will create worktrees)
SWARM_PROJECT_ROOT="\${SWARM_PROJECT_ROOT:-.}"

# YunXiao (云效) config — optional
YUNXIAO_TOKEN="\${YUNXIAO_TOKEN:-$_YUNXIAO_TOKEN}"
YUNXIAO_ORG_ID="\${YUNXIAO_ORG_ID:-$_YUNXIAO_ORG_ID}"
YUNXIAO_SPACE_ID="\${YUNXIAO_SPACE_ID:-$_YUNXIAO_SPACE_ID}"
YUNXIAO_REPO_ID="\${YUNXIAO_REPO_ID:-$_YUNXIAO_REPO_ID}"

# WeCom (企业微信) webhook for completion notifications
WECOM_WEBHOOK_URL="\${WECOM_WEBHOOK_URL:-$_WECOM_WEBHOOK_URL}"

# Git push authentication: "ssh", "token", or "none"
GIT_AUTH_METHOD="\${GIT_AUTH_METHOD:-token}"
GIT_TOKEN="\${GIT_TOKEN:-$_GIT_TOKEN}"

# Agent tuning
MAX_RETRIES="\${MAX_RETRIES:-${_MAX_RETRIES:-3}}"
CHECK_INTERVAL_MINUTES="\${CHECK_INTERVAL_MINUTES:-${_CHECK_INTERVAL:-2}}"
EOF
  echo "[agent-swarm] Created default config at $SWARM_CONFIG"
  if [ -n "$MIGRATED_MSG" ]; then
    echo "$MIGRATED_MSG"
  fi
fi

source "$SWARM_CONFIG"

##############################################################################
# Parse arguments
##############################################################################
TASK_ID="${1:-}"
PROMPT="${2:-}"

if [[ -z "$TASK_ID" || -z "$PROMPT" ]]; then
  echo "Usage: $0 <task-id> <prompt>"
  echo "Example: $0 feat-login '实现用户登录功能'"
  exit 1
fi

##############################################################################
# Resolve project root
##############################################################################
# SWARM_PROJECT_ROOT can be absolute or relative; resolve to absolute
if [[ "$SWARM_PROJECT_ROOT" != /* ]]; then
  PROJECT_ROOT="$(cd "$SWARM_PROJECT_ROOT" 2>/dev/null && pwd)" || {
    echo "Error: SWARM_PROJECT_ROOT '$SWARM_PROJECT_ROOT' is not a valid directory."
    exit 1
  }
else
  PROJECT_ROOT="$SWARM_PROJECT_ROOT"
fi

if [ ! -d "$PROJECT_ROOT/.git" ]; then
  echo "Error: $PROJECT_ROOT does not appear to be a git repository (no .git)."
  exit 1
fi

WORKTREE_DIR="$PROJECT_ROOT/.swarm-worktrees"
WORKTREE_PATH="$WORKTREE_DIR/$TASK_ID"
TMUX_SESSION="swarm-$TASK_ID"
BRANCH_NAME="swarm/$TASK_ID"

mkdir -p "$WORKTREE_DIR"

##############################################################################
# Check if already running
##############################################################################
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "⚠️  Agent $TASK_ID is already running (tmux: $TMUX_SESSION)"
  exit 1
fi

##############################################################################
# Create git worktree
##############################################################################
echo "Creating git worktree: $WORKTREE_PATH (branch: $BRANCH_NAME)"
cd "$PROJECT_ROOT"

# Auto-detect default branch
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
if [ -z "$DEFAULT_BRANCH" ]; then
  # Fallback: try master first, then main
  if git rev-parse --verify origin/master &>/dev/null; then
    DEFAULT_BRANCH="master"
  elif git rev-parse --verify origin/main &>/dev/null; then
    DEFAULT_BRANCH="main"
  else
    DEFAULT_BRANCH=$(git branch --format='%(refname:short)' | head -1)
  fi
fi

echo "📥 Fetching latest origin/$DEFAULT_BRANCH..."
git fetch origin "$DEFAULT_BRANCH" 2>/dev/null || echo "(fetch failed, continuing with local branch)"

git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" "origin/$DEFAULT_BRANCH" 2>/dev/null || {
  # Branch might already exist — reuse it
  git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" 2>/dev/null || {
    echo "Error: Could not create worktree. Branch '$BRANCH_NAME' or path '$WORKTREE_PATH' may already exist."
    exit 1
  }
}

##############################################################################
# Configure git authentication inside worktree
##############################################################################
cd "$WORKTREE_PATH"

GIT_AUTH_METHOD="${GIT_AUTH_METHOD:-none}"
case "$GIT_AUTH_METHOD" in
  token)
    # Set up credential helper that uses the token
    git config credential.helper '!f() { echo "username=x-access-token"; echo "password='"$GIT_TOKEN"'"; }; f'
    git config credential.helperStore '' 2>/dev/null || true
    ;;
  ssh)
    # Use SSH for remote — only affects this worktree
    if [ -n "${GIT_SSH_KEY:-}" ]; then
      git config core.sshCommand "ssh -i $GIT_SSH_KEY"
    fi
    ;;
  none)
    # Rely on system-wide git config (existing SSH key, credential helper, etc.)
    ;;
esac

##############################################################################
# Build the agent prompt
##############################################################################
TMUX_PROMPT="
请在当前目录完成以下任务：

$PROMPT

要求：
1. 创建必要的文件和目录
2. 代码要符合项目规范
3. 完成后用 git commit 提交更改
4. 推送到远程分支

⚠️ 重要约束：
- 只在当前 worktree 目录下编写代码
- 禁止修改 $SWARM_DIR/ 目录中的任何文件
- 禁止创建或修改 $SWARM_DIR/ 下的任何文件
- 编码任务完成后只需 git commit + push，状态更新由外部监控脚本处理
"

##############################################################################
# Create monitor script
##############################################################################
MONITOR_SCRIPT=$(mktemp /tmp/swarm-monitor-XXXXXX.sh)
cat > "$MONITOR_SCRIPT" << MONITOR_EOF
#!/bin/bash
# Monitor script: waits for agent to finish, checks commits, notifies.
# Do NOT use set -e — avoid premature exit.

TASK_ID="$TASK_ID"
TMUX_SESSION="$TMUX_SESSION"
BRANCH="$BRANCH_NAME"
WORKTREE="$WORKTREE_PATH"
WECOM_WEBHOOK_URL="${WECOM_WEBHOOK_URL:-}"
PROJECT_ROOT="$PROJECT_ROOT"
TASK_FILE="$SWARM_DIR/.swarm-active-tasks.json"
LOG_FILE="$SWARM_DIR/.swarm-monitor.log"

log() {
  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> "\$LOG_FILE"
}

log "🔍 Monitor started: \$TASK_ID (tmux: \$TMUX_SESSION)"

# Wait for tmux session to end
while tmux has-session -t "\$TMUX_SESSION" 2>/dev/null; do
  sleep 5
done

log "✅ Agent \$TASK_ID session ended, checking commits..."
sleep 10

if [[ -d "\$WORKTREE" ]]; then
  cd "\$WORKTREE"
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-master}"
  COMMITS=\$(git log --oneline "origin/\$DEFAULT_BRANCH"..\$BRANCH 2>/dev/null | wc -l)
  UNPUSHED=\$(git log --oneline \$BRANCH --not --remotes 2>/dev/null | wc -l)

  log "📊 Branch: \$BRANCH | Commits: \$COMMITS | Unpushed: \$UNPUSHED"

  if [[ "\$COMMITS" -gt 0 && "\$UNPUSHED" -eq 0 ]]; then
    log "🎉 Agent completed coding and pushed!"

    if [[ -n "\$WECOM_WEBHOOK_URL" ]]; then
      curl -s -X POST "\$WECOM_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d '{"msgtype":"markdown","markdown":{"content":"### 🎉 Agent 编码完成\n\n**任务**: '"\$TASK_ID"'\n**分支**: '"\$BRANCH"'\n**提交数**: '"\$COMMITS"'\n\n✅ 代码已推送"}}' \
        >> "\$LOG_FILE" 2>/dev/null || true
      log "📢 WeCom notification sent"
    fi

    # Remove task from active tasks
    if [[ -f "\$TASK_FILE" ]]; then
      if command -v jq &>/dev/null; then
        jq 'del(.tasks[] | select(.id == "'"\$TASK_ID"'"))' "\$TASK_FILE" > "\$TASK_FILE.tmp" && mv "\$TASK_FILE.tmp" "\$TASK_FILE"
      fi
      log "✅ Task removed from active-tasks"
    fi

    log "🏁 Task complete! Branch \$BRANCH is ready for MR."
  elif [[ "\$UNPUSHED" -gt 0 ]]; then
    log "⚠️ Has unpushed commits, keeping task record"
  else
    log "⚠️ No new commits, keeping task record"
  fi
else
  log "⚠️ Worktree does not exist"
fi

rm -f "\$MONITOR_SCRIPT"
MONITOR_EOF
chmod +x "$MONITOR_SCRIPT"

##############################################################################
# Launch tmux + agent
##############################################################################
echo "Launching agent (tmux: $TMUX_SESSION)..."
tmux new-session -d -s "$TMUX_SESSION" -c "$WORKTREE_PATH"

# Determine the agent command
# Prefer 'claude' (CLI), fallback to checking PATH
if command -v claude &>/dev/null; then
  AGENT_CMD="claude --print"
else
  echo "Error: 'claude' CLI not found in PATH."
  echo "Install Claude Code or set SWARM_AGENT_CMD in .agent-swarm.env"
  exit 1
fi

# Escape the prompt for tmux send-keys (use heredoc approach to avoid quoting issues)
PROMPT_FILE=$(mktemp /tmp/swarm-prompt-XXXXXX.txt)
cat > "$PROMPT_FILE" << 'PROMPT_INNER_EOF'
PROMPT_PLACEHOLDER
PROMPT_INNER_EOF
sed -i "s|PROMPT_PLACEHOLDER|$(echo "$TMUX_PROMPT" | sed 's/[&/\]/\\&/g; s/$/\\n/' | tr -d '\n')|" "$PROMPT_FILE" 2>/dev/null || true

tmux send-keys -t "$TMUX_SESSION" "cd $WORKTREE_PATH && $AGENT_CMD \"$(cat "$PROMPT_FILE")\"; exit" Enter
rm -f "$PROMPT_FILE"

##############################################################################
# Start monitor in background
##############################################################################
"$MONITOR_SCRIPT" &

##############################################################################
# Record task
##############################################################################
TASK_FILE="$SWARM_DIR/.swarm-active-tasks.json"
TIMESTAMP=$(date +%s%3N)

if [[ ! -f "$TASK_FILE" ]]; then
  echo '{"tasks": []}' > "$TASK_FILE"
fi

if command -v jq &>/dev/null; then
  jq --arg id "$TASK_ID" \
     --arg tmux "$TMUX_SESSION" \
     --arg worktree "$WORKTREE_PATH" \
     --arg branch "$BRANCH_NAME" \
     --arg desc "$PROMPT" \
     --argjson ts "$TIMESTAMP" \
     '.tasks += [{
         "id": $id,
         "tmuxSession": $tmux,
         "agent": "claude",
         "model": "claude-code",
         "description": $desc,
         "worktree": $worktree,
         "branch": $branch,
         "startedAt": $ts,
         "status": "running",
         "retries": 0,
         "notifyOnComplete": true
     }]' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
fi

echo ""
echo "✅ Agent launched successfully!"
echo "   Task ID:  $TASK_ID"
echo "   Tmux:     $TMUX_SESSION"
echo "   Worktree: $WORKTREE_PATH"
echo "   Branch:   $BRANCH_NAME"
echo ""
echo "📋 Flow: Agent codes → git commit + push → auto-cleanup → notification"
echo ""
echo "View output:  tmux attach -t $TMUX_SESSION"
echo "Stop agent:   tmux kill-session -t $TMUX_SESSION"
