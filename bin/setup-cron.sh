#!/usr/bin/env bash
# setup-cron.sh — Install a unified cron job that cleans up ALL registered projects
# Usage: setup-cron.sh [--install] [--uninstall] [--status] [--add <project-root>] [--remove <project-root>] [--list]
#
# Projects are registered in ~/.agent-swarm-dev/.swarm-projects.list (one path per line)
# The cron runs cleanup-merged.sh for each registered project.
#
# Default: --install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY_DIR="$HOME/.agent-swarm-dev"
PROJECT_LIST="$REGISTRY_DIR/.swarm-projects.list"
CRON_TAG="# agent-swarm-dev unified cleanup"
CRON_SCHEDULE="${CRON_SCHEDULE:-*/5 * * * *}"

mkdir -p "$REGISTRY_DIR"

# Build crontab line
crontab_line="$CRON_SCHEDULE SWARM_DIR=\"$SWARM_DIR\" PROJECT_LIST=\"$PROJECT_LIST\" $SCRIPT_DIR/cleanup-merged.sh --all >> \"$REGISTRY_DIR/.swarm-cleanup.log\" 2>&1 $CRON_TAG"

show_status() {
  echo "=== agent-swarm-dev unified cleanup cron ==="
  if crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
    echo "Status: INSTALLED"
    echo "Schedule: $CRON_SCHEDULE"
    echo "Registry: $PROJECT_LIST"
    echo "Log file: $REGISTRY_DIR/.swarm-cleanup.log"
    echo ""
    echo "Registered projects:"
    if [ -f "$PROJECT_LIST" ]; then
      while IFS= read -r line; do
        [ -n "$line" ] && echo "  - $line"
      done < "$PROJECT_LIST"
    else
      echo "  (none)"
    fi
  else
    echo "Status: NOT INSTALLED"
  fi
}

install_cron() {
  if crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
    echo "Cron job already installed."
    echo "Run with --uninstall first to reinstall."
    exit 0
  fi

  (crontab -l 2>/dev/null || true; echo "$crontab_line") | crontab -
  echo "✅ Cron job installed."
  echo "  Schedule: $CRON_SCHEDULE"
  echo "  Registry: $PROJECT_LIST"
  echo "  Log:      $REGISTRY_DIR/.swarm-cleanup.log"
  echo ""
  echo "Edit schedule with: crontab -e"
  echo "Remove with:        $0 --uninstall"
}

uninstall_cron() {
  if ! crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
    echo "Cron job not found."
    exit 0
  fi

  crontab -l 2>/dev/null | grep -v "$CRON_TAG" | crontab -
  echo "✅ Cron job removed."
}

add_project() {
  local path="$1"
  # Resolve to absolute
  case "$path" in
    /*) ;;
    *) path="$(cd "$path" 2>/dev/null && pwd 2>/dev/null || echo "$path")" ;;
  esac

  if [ -f "$PROJECT_LIST" ] && grep -qFx "$path" "$PROJECT_LIST" 2>/dev/null; then
    echo "Project already registered: $path"
    exit 0
  fi

  echo "$path" >> "$PROJECT_LIST"
  echo "✅ Project registered: $path"
}

remove_project() {
  local path="$1"
  case "$path" in
    /*) ;;
    *) path="$(cd "$path" 2>/dev/null && pwd 2>/dev/null || echo "$path")" ;;
  esac

  if [ ! -f "$PROJECT_LIST" ]; then
    echo "No projects registered."
    exit 0
  fi

  if ! grep -qFx "$path" "$PROJECT_LIST" 2>/dev/null; then
    echo "Project not found: $path"
    exit 0
  fi

  local tmp
  tmp=$(mktemp)
  grep -vFx "$path" "$PROJECT_LIST" > "$tmp" || true
  mv "$tmp" "$PROJECT_LIST"
  echo "✅ Project removed: $path"
}

list_projects() {
  echo "=== Registered projects ==="
  if [ -f "$PROJECT_LIST" ] && [ -s "$PROJECT_LIST" ]; then
    cat "$PROJECT_LIST"
  else
    echo "(none)"
  fi
}

# Parse args
case "${1:---install}" in
  --install|install)
    install_cron
    ;;
  --uninstall|uninstall)
    uninstall_cron
    ;;
  --status|status)
    show_status
    ;;
  --add)
    [ -z "${2:-}" ] && { echo "Usage: $0 --add <project-root>"; exit 1; }
    add_project "$2"
    ;;
  --remove)
    [ -z "${2:-}" ] && { echo "Usage: $0 --remove <project-root>"; exit 1; }
    remove_project "$2"
    ;;
  --list)
    list_projects
    ;;
  *)
    echo "Usage: $0 [--install] [--uninstall] [--status] [--add <root>] [--remove <root>] [--list]"
    echo ""
    echo "Commands:"
    echo "  --install    Install unified cleanup cron (default)"
    echo "  --uninstall  Remove cleanup cron"
    echo "  --status     Show cron + project status"
    echo "  --add <root> Register a project for cleanup"
    echo "  --remove <root> Unregister a project"
    echo "  --list       List registered projects"
    echo ""
    echo "Registry file: $PROJECT_LIST"
    exit 1
    ;;
esac
