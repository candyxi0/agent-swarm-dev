#!/usr/bin/env bash
# install.sh — One-line installer for agent-swarm-dev
#
# Usage (one-line install):
#   cd /your/project && curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
#
# Or if already cloned:
#   cd /your/project && ~/agent-swarm-dev/bin/install.sh

set -euo pipefail

REPO_URL="https://github.com/candyxi0/agent-swarm-dev.git"
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

TARGET_DIR=".claude/skills/agent-swarm-dev"
mkdir -p "$TARGET_DIR"

# Symlink SKILL.md
ln -sfn "$SWARM_DIR/SKILL.md" "$TARGET_DIR/SKILL.md"

# Symlink bin directory
ln -sfn "$SWARM_DIR/bin" "$TARGET_DIR/bin"

echo "Installed into $TARGET_DIR → $SWARM_DIR"
echo ""
echo "In Claude Code, say 'launch an agent' to use /agent-swarm-dev"
