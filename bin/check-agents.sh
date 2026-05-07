#!/usr/bin/env bash
# check-agents.sh — Show all running agents at a glance
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TASK_FILE="$SWARM_DIR/.swarm-active-tasks.json"
LOG_FILE="$SWARM_DIR/.swarm-monitor.log"

if [ ! -f "$TASK_FILE" ]; then
  echo "No active tasks found."
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  exit 1
fi

TASK_COUNT=$(jq '.tasks | length' "$TASK_FILE")
if [ "$TASK_COUNT" -eq 0 ]; then
  echo "No active tasks."
  exit 0
fi

echo "=== Agent Swarm Status ==="
echo ""

jq -r '.tasks[] |
  "Task:       \(.id)
Status:     \(.status)
Agent:      \(.agent) (\(.model))
Branch:     \(.branch)
Worktree:   \(.worktree)
Started:    \(.startedAt / 1000 | todate)
Tmux:       \(.tmuxSession)
Retries:    \(.retries)
---"' "$TASK_FILE"

echo ""
echo "=== Tmux Sessions ==="
tmux ls 2>/dev/null | grep swarm- || echo "(no swarm tmux sessions running)"

echo ""
echo "=== Recent Monitor Log ==="
if [ -f "$LOG_FILE" ]; then
  tail -10 "$LOG_FILE"
else
  echo "(no monitor log yet)"
fi
