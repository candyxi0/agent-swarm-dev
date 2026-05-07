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

# --- Interactive configuration ---
ENV_FILE="$SWARM_DIR/.agent-swarm.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "--- Setup ---"
  echo ""

  # SWARM_PROJECT_ROOT (required)
  echo -n "Git repo path for agents (SWARM_PROJECT_ROOT) [$(pwd)]: "
  read -r INPUT
  SWARM_PROJECT_ROOT="${INPUT:-$(pwd)}"
  # Resolve to absolute path
  case "$SWARM_PROJECT_ROOT" in
    /*) ;;
    *) SWARM_PROJECT_ROOT="$(cd "$SWARM_PROJECT_ROOT" 2>/dev/null && pwd 2>/dev/null || echo "$SWARM_PROJECT_ROOT")" ;;
  esac

  # YUNXIAO (optional)
  echo ""
  echo "云效 (Aliyun YunXiao) integration — optional, leave blank to skip:"
  echo -n "  YUNXIAO_TOKEN: "
  read -r YUNXIAO_TOKEN
  YUNXIAO_TOKEN="${YUNXIAO_TOKEN:-}"
  if [ -n "$YUNXIAO_TOKEN" ]; then
    echo -n "  YUNXIAO_ORG_ID: "
    read -r YUNXIAO_ORG_ID
    YUNXIAO_ORG_ID="${YUNXIAO_ORG_ID:-}"
    echo -n "  YUNXIAO_SPACE_ID: "
    read -r YUNXIAO_SPACE_ID
    YUNXIAO_SPACE_ID="${YUNXIAO_SPACE_ID:-}"
    echo -n "  YUNXIAO_REPO_ID: "
    read -r YUNXIAO_REPO_ID
    YUNXIAO_REPO_ID="${YUNXIAO_REPO_ID:-}"
  else
    YUNXIAO_ORG_ID=""
    YUNXIAO_SPACE_ID=""
    YUNXIAO_REPO_ID=""
  fi

  # WeCom notification (optional)
  echo ""
  echo "企业微信 (WeCom) notification — optional, leave blank to skip:"
  echo -n "  WECOM_WEBHOOK_URL: "
  read -r WECOM_WEBHOOK_URL
  WECOM_WEBHOOK_URL="${WECOM_WEBHOOK_URL:-}"

  # Retry & interval
  echo ""
  echo -n "Max retries (MAX_RETRIES) [3]: "
  read -r INPUT
  MAX_RETRIES="${INPUT:-3}"
  echo -n "Check interval in minutes (CHECK_INTERVAL_MINUTES) [2]: "
  read -r INPUT
  CHECK_INTERVAL_MINUTES="${INPUT:-2}"

  # Write env file
  cat > "$ENV_FILE" <<EOF
# agent-swarm-dev configuration
SWARM_PROJECT_ROOT="$SWARM_PROJECT_ROOT"
YUNXIAO_TOKEN="$YUNXIAO_TOKEN"
YUNXIAO_ORG_ID="$YUNXIAO_ORG_ID"
YUNXIAO_SPACE_ID="$YUNXIAO_SPACE_ID"
YUNXIAO_REPO_ID="$YUNXIAO_REPO_ID"
WECOM_WEBHOOK_URL="$WECOM_WEBHOOK_URL"
MAX_RETRIES="$MAX_RETRIES"
CHECK_INTERVAL_MINUTES="$CHECK_INTERVAL_MINUTES"
EOF

  echo ""
  echo "Config saved to $ENV_FILE"
else
  echo "Config already exists at $ENV_FILE"
fi

echo ""
echo "In Claude Code, say 'launch an agent' to use /agent-swarm-dev"
