#!/usr/bin/env bash
# start-agent.sh — Validated wrapper for run-agent.sh
# Usage: start-agent.sh [task-id] [prompt]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_AGENT="$SCRIPT_DIR/run-agent.sh"
SWARM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TASK_FILE="$SWARM_DIR/.swarm-active-tasks.json"

if [ ! -x "$RUN_AGENT" ]; then
  echo "Error: run-agent.sh not found at $RUN_AGENT"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  exit 1
fi

TASK_ID="${1:-}"
PROMPT="${2:-}"

if [ -z "$PROMPT" ]; then
  echo "Error: prompt is required."
  echo "Usage: $0 <task-id> <prompt>"
  exit 1
fi

if [ -z "$TASK_ID" ]; then
  HASH=$(echo "$PROMPT$(date +%s)" | md5sum | cut -c1-8)
  TASK_ID="task-${HASH:0:6}"
  echo "Generated task-id: $TASK_ID"
fi

if [ -f "$TASK_FILE" ]; then
  EXISTING=$(jq -r --arg id "$TASK_ID" '.tasks[] | select(.id == $id) | .id' "$TASK_FILE" 2>/dev/null || true)
  if [ -n "$EXISTING" ]; then
    echo "Error: task '$TASK_ID' already exists."
    jq --arg id "$TASK_ID" '.tasks[] | select(.id == $id) | {id, status, branch}' "$TASK_FILE"
    exit 1
  fi
fi

TMUX_SESSION="swarm-$TASK_ID"
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "Error: tmux session '$TMUX_SESSION' already exists."
  exit 1
fi

echo "Starting agent..."
"$RUN_AGENT" "$TASK_ID" "$PROMPT"
