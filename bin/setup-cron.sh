#!/usr/bin/env bash
# setup-cron.sh — Install a cron job for cleanup-merged.sh
# Usage: setup-cron.sh [--install] [--uninstall] [--status]
#
# Default: --install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLEANUP_SCRIPT="$SCRIPT_DIR/cleanup-merged.sh"
CRON_TAG="# agent-swarm-dev cleanup"

# Detect project root
detect_project_root() {
  if [ -n "${SWARM_PROJECT_ROOT:-}" ]; then
    echo "$SWARM_PROJECT_ROOT"
  else
    # Try to find git repo from script location
    local dir="$SWARM_DIR"
    while [ "$dir" != "/" ]; do
      if [ -d "$dir/.git" ]; then
        echo "$dir"
        return
      fi
      dir="$(dirname "$dir")"
    done
    echo "Error: Cannot find git repo. Set SWARM_PROJECT_ROOT env variable."
    exit 1
  fi
}

CRON_MINUTES="${CRON_MINUTES:-*/5}"
CRON_HOUR="${CRON_HOUR:-2}"

crontab_line="$CRON_MINUTES $CRON_HOUR * * * SWARM_PROJECT_ROOT=\"$(detect_project_root)\" $CLEANUP_SCRIPT >> \"$SWARM_DIR/.swarm-cleanup.log\" 2>&1 $CRON_TAG"

show_status() {
  echo "=== agent-swarm-dev cleanup cron ==="
  if crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
    echo "Status: INSTALLED"
    echo "Schedule: $CRON_HOUR:$CRON_MINUTES daily"
    echo "Script:   $CLEANUP_SCRIPT"
    echo ""
    echo "Crontab entry:"
    crontab -l 2>/dev/null | grep "$CRON_TAG"
    echo ""
    echo "Log file: $SWARM_DIR/.swarm-cleanup.log"
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

  if [ ! -x "$CLEANUP_SCRIPT" ]; then
    echo "Error: cleanup-merged.sh not found or not executable at:"
    echo "  $CLEANUP_SCRIPT"
    exit 1
  fi

  # Add to crontab
  (crontab -l 2>/dev/null || true; echo "$crontab_line") | crontab -
  echo "✅ Cron job installed."
  echo "  Schedule: $CRON_HOUR:$CRON_MINUTES daily"
  echo "  Script:   $CLEANUP_SCRIPT"
  echo "  Log:      $SWARM_DIR/.swarm-cleanup.log"
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
  *)
    echo "Usage: $0 [--install] [--uninstall] [--status]"
    echo ""
    echo "Commands:"
    echo "  --install    Install daily cleanup cron (default)"
    echo "  --uninstall  Remove cleanup cron"
    echo "  --status     Show cron status"
    exit 1
    ;;
esac
