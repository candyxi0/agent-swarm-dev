#!/usr/bin/env bash
# install.sh — Install agent-swarm-dev skill into the current project
#
# Usage:
#   1. Clone this repo
#   2. Run from your project root:
#      /path/to/agent-swarm-dev/bin/install.sh
#
# Or pipe directly:
#   curl -fsSL https://raw.githubusercontent.com/YOU/agent-swarm-dev/main/bin/install.sh | bash
#
# This script derives its own location — no hardcoded paths.

set -euo pipefail

# Derive SWARM_DIR from this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_DIR=".claude/skills/agent-swarm-dev"

if [ ! -d ".claude" ]; then
  mkdir -p .claude
fi

mkdir -p "$TARGET_DIR"

# Symlink SKILL.md
ln -sfn "$SWARM_DIR/SKILL.md" "$TARGET_DIR/SKILL.md"

# Symlink bin directory
ln -sfn "$SWARM_DIR/bin" "$TARGET_DIR/bin"

echo "agent-swarm-dev installed into $TARGET_DIR"
echo ""
echo "Source: $SWARM_DIR"
echo ""
echo "Available commands:"
echo "  /agent-swarm-dev    - invoke the skill in Claude Code"
echo "  $TARGET_DIR/bin/run-agent.sh    - launch an agent"
echo "  $TARGET_DIR/bin/check-agents.sh - view all agents"
echo "  $TARGET_DIR/bin/stop-agent.sh   - stop an agent"
echo "  $TARGET_DIR/bin/swarm.sh        - batch launch agents"
echo ""
echo "First run will auto-create .agent-swarm.env config file."
