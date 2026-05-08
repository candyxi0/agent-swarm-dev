#!/usr/bin/env bash
# install.sh — One-line installer for agent-swarm-dev
#
# Usage (one-line install):
#   cd /your/project && curl -fsSL https://raw.githubusercontent.com/candyxi0/agent-swarm-dev/main/bin/install.sh | bash
#
# Or if already cloned:
#   cd /your/project && ~/agent-swarm-dev/bin/install.sh

set -euo pipefail

REPO_URL="https://kkgithub.com/candyxi0/agent-swarm-dev.git"
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

# --- Detect platform skill directory ---
detect_skill_dir() {
  # Priority: OpenClaw > Claude Code > ask user
  if [ -d ".openclaw/skills" ]; then
    echo ".openclaw/skills/agent-swarm-dev"
    return
  fi
  if [ -d ".claude/skills" ]; then
    echo ".claude/skills/agent-swarm-dev"
    return
  fi

  # Neither exists — ask user
  echo "Which AI platform are you using?"
  echo "  1) OpenClaw"
  echo "  2) Claude Code"
  echo "  3) Other (specify directory)"
  echo -n "  Choose [1]: "
  read -r INPUT
  case "$INPUT" in
    1)
      echo ".openclaw/skills/agent-swarm-dev"
      ;;
    2)
      echo ".claude/skills/agent-swarm-dev"
      ;;
    3)
      echo -n "  Skill directory path: "
      read -r CUSTOM_DIR
      echo "$CUSTOM_DIR/agent-swarm-dev"
      ;;
    *)
      echo ".openclaw/skills/agent-swarm-dev"
      ;;
  esac
}

TARGET_DIR="$(detect_skill_dir)"
mkdir -p "$TARGET_DIR"

# Symlink SKILL.md
ln -sfn "$SWARM_DIR/SKILL.md" "$TARGET_DIR/SKILL.md"

# Symlink bin directory
ln -sfn "$SWARM_DIR/bin" "$TARGET_DIR/bin"

echo "Installed into $TARGET_DIR → $SWARM_DIR"
echo ""

# --- Interactive configuration ---
# Derive project name from current directory and use it as project root
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR" | tr ' ' '-' | tr -cd 'a-zA-Z0-9_-')"
ENV_FILE="$PROJECT_DIR/.agent-swarm.env"

echo "--- Setup ---"
echo ""
echo -n "Project name (SWARM_PROJECT_NAME) [$PROJECT_NAME]: "
read -r INPUT
PROJECT_NAME="${INPUT:-$PROJECT_NAME}"
if [ -n "$PROJECT_NAME" ]; then
  ENV_FILE="$PROJECT_DIR/.agent-swarm-${PROJECT_NAME}.env"
fi

if [ ! -f "$ENV_FILE" ]; then
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

  # Git authentication
  echo ""
  echo "Git push authentication — how agents authenticate when pushing:"
  echo "  1) Personal Access Token (recommended)"
  echo "  2) SSH key"
  echo "  3) Skip (use existing git config)"
  echo -n "  Choose [1]: "
  read -r INPUT
  GIT_AUTH_METHOD="${INPUT:-1}"

  GIT_TOKEN=""
  GIT_SSH_KEY=""
  case "$GIT_AUTH_METHOD" in
    1|*)
      echo -n "  GIT_TOKEN (GitHub/GitLab/云效 token): "
      read -r GIT_TOKEN
      GIT_TOKEN="${GIT_TOKEN:-}"
      GIT_AUTH_METHOD="token"
      ;;
    2)
      # Check if SSH key exists, if not offer to guide
      if [ ! -f ~/.ssh/id_ed25519 ] && [ ! -f ~/.ssh/id_rsa ]; then
        echo ""
        echo "  No SSH key found (~/.ssh/id_ed25519 or id_rsa)."
        echo -n "  Generate one now? (y/N): "
        read -r INPUT
        case "$INPUT" in
          y|Y)
            echo "  Generating SSH key..."
            ssh-keygen -t ed25519 -C "agent-swarm-dev" -f ~/.ssh/id_ed25519 -N "" -q
            echo "  SSH key generated at ~/.ssh/id_ed25519"
            echo "  Remember to add your public key to your Git hosting:"
            echo "    cat ~/.ssh/id_ed25519.pub"
            ;;
          *)
            GIT_AUTH_METHOD="ssh"
            ;;
        esac
      else
        GIT_AUTH_METHOD="ssh"
      fi
      ;;
    3)
      GIT_AUTH_METHOD="none"
      ;;
  esac

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
# agent-swarm-dev configuration — project: $PROJECT_NAME
SWARM_PROJECT_ROOT="$SWARM_PROJECT_ROOT"
YUNXIAO_TOKEN="$YUNXIAO_TOKEN"
YUNXIAO_ORG_ID="$YUNXIAO_ORG_ID"
YUNXIAO_SPACE_ID="$YUNXIAO_SPACE_ID"
YUNXIAO_REPO_ID="$YUNXIAO_REPO_ID"
WECOM_WEBHOOK_URL="$WECOM_WEBHOOK_URL"
GIT_AUTH_METHOD="$GIT_AUTH_METHOD"
GIT_TOKEN="$GIT_TOKEN"
MAX_RETRIES="$MAX_RETRIES"
CHECK_INTERVAL_MINUTES="$CHECK_INTERVAL_MINUTES"
EOF

  echo ""
  echo "Config saved to $ENV_FILE"

  # Cron setup (optional)
  echo ""
  echo "Auto cleanup of merged branches — schedule a periodic sweep?"
  echo -n "  Install cron job? (y/N): "
  read -r INPUT
  case "$INPUT" in
    y|Y)
      echo -n "  Schedule (minutes) [*/5]: "
      read -r CRON_MIN
      CRON_MINUTES="${CRON_MIN:-*/5}" "$SWARM_DIR/bin/setup-cron.sh" --install 2>/dev/null || echo "  (setup failed, you can install manually later)"
      ;;
    *)
      echo "  Skipped. Run './agent-swarm-dev/bin/setup-cron.sh --install' anytime."
      ;;
  esac
else
  echo "Config already exists at $ENV_FILE"
fi

echo ""
echo "Setup complete. Say '启动小蜜蜂' or 'launch a coding bee' to use agent-swarm-dev."
