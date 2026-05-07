#!/usr/bin/env bash
# swarm.sh — Launch multiple agents in parallel
# Usage: swarm.sh <task-file.json>
#
# task-file.json format:
# [
#   {"id": "feat-login", "prompt": "实现用户登录功能"},
#   {"id": "feat-api", "prompt": "实现用户CRUD API"}
# ]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_AGENT="$SCRIPT_DIR/run-agent.sh"

TASK_FILE="${1:-}"
if [ -z "$TASK_FILE" ]; then
  echo "Usage: $0 <task-file.json>"
  echo ""
  echo "task-file.json format:"
  echo '[{"id": "feat-login", "prompt": "实现用户登录功能"}, ...]'
  exit 1
fi

if [ ! -f "$TASK_FILE" ]; then
  echo "Error: task file not found: $TASK_FILE"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  exit 1
fi

if [ ! -x "$RUN_AGENT" ]; then
  echo "Error: run-agent.sh not found at $RUN_AGENT"
  exit 1
fi

TASK_COUNT=$(jq 'length' "$TASK_FILE")
echo "Launching $TASK_COUNT agents in parallel..."
echo ""

PIDS=()
for i in $(seq 0 $((TASK_COUNT - 1))); do
  ID=$(jq -r ".[$i].id" "$TASK_FILE")
  PROMPT=$(jq -r ".[$i].prompt" "$TASK_FILE")

  echo "[$((i+1))/$TASK_COUNT] Starting: $ID"
  "$RUN_AGENT" "$ID" "$PROMPT" &
  PIDS+=($!)
done

echo ""
echo "All agents launched. Waiting for completion..."
echo ""

FAILED=0
SUCCEEDED=0
for pid in "${PIDS[@]}"; do
  if wait "$pid" 2>/dev/null; then
    SUCCEEDED=$((SUCCEEDED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=== Swarm Complete ==="
echo "Succeeded: $SUCCEEDED"
echo "Failed:    $FAILED"
echo "Total:     $TASK_COUNT"
