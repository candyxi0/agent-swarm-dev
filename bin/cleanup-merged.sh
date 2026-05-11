#!/usr/bin/env bash
# cleanup-merged.sh — Remove worktrees and branches for merged swarm tasks
# Usage:
#   cleanup-merged.sh                     # single project (auto-detect or SWARM_PROJECT_ROOT)
#   cleanup-merged.sh --dry-run           # single project dry run
#   cleanup-merged.sh --all               # iterate all registered projects from PROJECT_LIST
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ALL_MODE=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --all)     ALL_MODE=true ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

if [ "$ALL_MODE" = true ]; then
  # Unified mode: iterate all registered projects
  if [ -z "${PROJECT_LIST:-}" ]; then
    PROJECT_LIST="$HOME/.agent-swarm-dev/.swarm-projects.list"
  fi
  if [ ! -f "$PROJECT_LIST" ]; then
    echo "No project registry found at $PROJECT_LIST"
    exit 0
  fi

  TOTAL=0
  while IFS= read -r project_root; do
    [ -z "$project_root" ] && continue
    [ ! -d "$project_root/.git" ] && { echo "Skip (not a git repo): $project_root"; continue; }
    echo ""
    echo ">>> Project: $project_root <<<"
    SWARM_PROJECT_ROOT="$project_root" SWARM_DIR="$SWARM_DIR" "$0" --single $([ "$DRY_RUN" = true ] && echo "--dry-run")
    TOTAL=$((TOTAL + $?))
  done < "$PROJECT_LIST"
  echo ""
  echo "=== Done. $TOTAL project(s) processed. ==="
  exit 0
fi

# ---- Single project cleanup ----

TASK_FILE="$SWARM_DIR/.swarm-active-tasks.json"

echo "=== Cleaning up merged swarm branches ==="
echo ""

# Detect project root from env or git
if [ -n "${SWARM_PROJECT_ROOT:-}" ]; then
  PROJECT_ROOT="$SWARM_PROJECT_ROOT"
else
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd)"
  if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "Error: Cannot find git repo root."
    exit 1
  fi
fi

cd "$PROJECT_ROOT"

# Fetch latest to ensure we have up-to-date branch info
echo "Fetching latest remote state..."
git fetch --prune --quiet

# Get all swarm branches
SWARM_BRANCHES=$(git branch -r --list 'origin/swarm/*' | sed 's|  origin/||')
if [ -z "$SWARM_BRANCHES" ]; then
  echo "No swarm branches found."
  exit 0
fi

echo "Found $(echo "$SWARM_BRANCHES" | wc -l) swarm branch(es) on remote."
echo ""

CLEANED=0

while IFS= read -r remote_branch; do
  task_id="${remote_branch#swarm/}"

  # Check if branch is merged into origin/main (or origin/master)
  MAIN_BRANCH="origin/main"
  if ! git rev-parse --verify "$MAIN_BRANCH" &>/dev/null; then
    MAIN_BRANCH="origin/master"
  fi

  if git merge-base --is-ancestor "$remote_branch" "$MAIN_BRANCH" 2>/dev/null; then
    prefix="[DRY RUN] "
    if [ "$DRY_RUN" = true ]; then
      prefix="[DRY RUN] "
    fi

    echo "  Merged: $remote_branch"

    # Check for local worktree
    WORKTREE="$PROJECT_ROOT/.swarm-worktrees/$task_id"
    if [ -d "$WORKTREE" ]; then
      echo "    ${prefix}Removing worktree: $WORKTREE"
      if [ "$DRY_RUN" = false ]; then
        git worktree remove --quiet "$WORKTREE" 2>/dev/null || rm -rf "$WORKTREE"
      fi
    fi

    # Check for local branch
    local_branch="swarm/$task_id"
    if git rev-parse --verify "$local_branch" &>/dev/null; then
      echo "    ${prefix}Deleting local branch: $local_branch"
      if [ "$DRY_RUN" = false ]; then
        git branch -D "$local_branch" 2>/dev/null || true
      fi
    fi

    # Delete remote branch
    echo "    ${prefix}Deleting remote branch: origin/$remote_branch"
    if [ "$DRY_RUN" = false ]; then
      git push origin --delete "$remote_branch" 2>/dev/null || echo "    Failed to delete remote branch"
    fi

    # Remove from task file if present
    if [ -f "$TASK_FILE" ] && command -v jq &>/dev/null; then
      HAS_TASK=$(jq --arg id "$task_id" '.tasks[] | select(.id == $id) | .id' "$TASK_FILE" 2>/dev/null || true)
      if [ -n "$HAS_TASK" ]; then
        echo "    ${prefix}Removing task record: $task_id"
        if [ "$DRY_RUN" = false ]; then
          jq --arg id "$task_id" 'del(.tasks[] | select(.id == $id))' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
        fi
      fi
    fi

    CLEANED=$((CLEANED + 1))
  fi
done <<< "$SWARM_BRANCHES"

echo ""
if [ "$CLEANED" -eq 0 ]; then
  echo "No merged swarm branches to clean up."
else
  if [ "$DRY_RUN" = true ]; then
    echo "Dry run complete. $CLEANED merged branch(es) would be cleaned."
  else
    echo "Cleanup complete. Removed $CLEANED merged branch(es) and worktree(s)."
  fi
fi
