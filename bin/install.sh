#!/usr/bin/env bash
# install.sh — One-line installer for agent-swarm-dev
#
# Usage (one-line install):
#   cd /your/project && curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
#
# Or if already cloned:
#   cd /your/project && ~/agent-swarm-dev/bin/install.sh

set -euo pipefail

REPO_URL="https://kkgithub.com/candyxi0/agent-swarm-dev.git"
BRANCH="main"
SWARM_DIR="$HOME/agent-swarm-dev"

# Detect if already cloned (script is inside agent-swarm-dev)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ "$(basename "$PARENT_DIR")" = "agent-swarm-dev" ] && [ -f "$PARENT_DIR/SKILL.md" ]; then
  SWARM_DIR="$PARENT_DIR"
fi

# If not already cloned, clone it
if [ ! -f "$SWARM_DIR/SKILL.md" ]; then
  echo "Cloning agent-swarm-dev..."
  git clone -b "$BRANCH" "$REPO_URL" "$SWARM_DIR" 2>/dev/null || git clone -b "$BRANCH" "https://$REPO_URL" "$SWARM_DIR"
fi

# Check if we're in a git project
if ! git rev-parse --git-dir &>/dev/null; then
  echo "Warning: current directory is not a git repository."
  echo "This skill works best inside a git project."
  echo ""
fi

# --- Detect platform skill directory ---
INSTALLED=false

# Check ~/.openclaw
if [ -d "$HOME/.openclaw" ]; then
  mkdir -p "$HOME/.openclaw/skills"
  TARGET_DIR="$HOME/.openclaw/skills/agent-swarm-dev"
  mkdir -p "$TARGET_DIR"
  ln -sfn "$SWARM_DIR/SKILL.md" "$TARGET_DIR/SKILL.md"
  ln -sfn "$SWARM_DIR/bin" "$TARGET_DIR/bin"
  echo "Installed into $TARGET_DIR → $SWARM_DIR"
  INSTALLED=true
fi

# Check ~/.claude
if [ -d "$HOME/.claude" ]; then
  mkdir -p "$HOME/.claude/skills"
  TARGET_DIR="$HOME/.claude/skills/agent-swarm-dev"
  mkdir -p "$TARGET_DIR"
  ln -sfn "$SWARM_DIR/SKILL.md" "$TARGET_DIR/SKILL.md"
  ln -sfn "$SWARM_DIR/bin" "$TARGET_DIR/bin"
  echo "Installed into $TARGET_DIR → $SWARM_DIR"
  INSTALLED=true
fi

if [ "$INSTALLED" = false ]; then
  echo "未检测到支持的 AI 助手（~/.openclaw 或 ~/.claude），跳过 skill 安装。"
  exit 0
fi

echo ""

# --- Force install cron ---
echo "Installing cron job for merged branch cleanup..."
CRON_SCHEDULE="*/5 * * * *" "$SWARM_DIR/bin/setup-cron.sh" --install 2>/dev/null || echo "(cron install failed, you can install manually later)"
PROJECT_DIR="$(pwd)"
"$SWARM_DIR/bin/setup-cron.sh" --add "$PROJECT_DIR" 2>/dev/null || true

echo ""
echo "Setup complete. Say '启动小蜜蜂' or 'launch a coding bee' to use agent-swarm-dev."
