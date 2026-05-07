#!/usr/bin/env bash
# stop-agent.sh — Stop a running agent
# Usage: stop-agent.sh <task-id>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TASK_FILE="$SWARM_DIR/.swarm-active-tasks.json"

TASK_ID="${1:-}"
if [ -z "$TASK_ID" ]; then
  echo "Usage: $0 <task-id>"
  exit 1
fi

TMUX_SESSION="swarm-$TASK_ID"

if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "Agent '$TASK_ID' is not running (no tmux session: $TMUX_SESSION)"
  exit 0
fi

echo "Stopping agent '$TASK_ID'..."
tmux kill-session -t "$TMUX_SESSION"
echo "Tmux session terminated."

if [ -f "$TASK_FILE" ] && command -v jq &>/dev/null; then
  HAS_TASK=$(jq --arg id "$TASK_ID" '.tasks[] | select(.id == $id) | .id' "$TASK_FILE" 2>/dev/null || true)
  if [ -n "$HAS_TASK" ]; then
    jq --arg id "$TASK_ID" '
      .tasks |= map(if .id == $id then .status = "stopped" else . end)
    ' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
    echo "Task status updated to 'stopped'."
  fi
fi

echo "Done."
