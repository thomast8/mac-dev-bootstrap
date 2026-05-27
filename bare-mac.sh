#!/usr/bin/env bash
# bare-mac.sh - bootstrap entry point for a fresh macOS (no git, no Homebrew, no CLT).
# Fetched and run raw (it predates everything else), so it is NOT rendered and takes
# its one personal input via the ORCH_REPO env var:
#
#   ORCH_REPO=you/your-orchestrator /bin/bash -c \
#     "$(curl -fsSL https://raw.githubusercontent.com/<acct>/mac-dev-bootstrap/main/bare-mac.sh)"
#
# It installs just enough (Xcode CLT, Homebrew, gh) to authenticate and clone your
# PRIVATE orchestrator, then hands off to its setup. Pass extra args (e.g. --with-work)
# and they are forwarded to setup. Idempotent; safe to re-run.
set -euo pipefail

ORCH_REPO="${ORCH_REPO:-}"
if [ -z "$ORCH_REPO" ]; then
  cat >&2 <<'MSG'
ORCH_REPO is not set. Point it at your private orchestrator repo, e.g.:
  ORCH_REPO=you/your-orchestrator /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/<acct>/mac-dev-bootstrap/main/bare-mac.sh)" -- --with-work
MSG
  exit 1
fi
GIT_REPOS="${GIT_REPOS:-$HOME/GitRepos}"
ORCH_DIR="$GIT_REPOS/$(basename "$ORCH_REPO")"

# 1. Xcode Command Line Tools (provides git). The installer is an async GUI; if it
#    was just triggered, finish it and re-run this script.
if ! xcode-select -p >/dev/null 2>&1; then
  echo ">> Installing Xcode Command Line Tools - accept the GUI prompt, then re-run this." >&2
  xcode-select --install || true
  exit 1
fi

# 2. Homebrew
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true

# 3. gh - needed to authenticate before cloning the private orchestrator
command -v gh >/dev/null 2>&1 || brew install gh

# 4. Authenticate (interactive) the account that owns the orchestrator
gh auth status >/dev/null 2>&1 || gh auth login
gh auth setup-git

# 5. Clone the orchestrator. Use authenticated HTTPS here because a fresh Mac may
#    not have its SSH signing or auth keys restored until the orchestrator runs.
mkdir -p "$GIT_REPOS"
if [ ! -d "$ORCH_DIR/.git" ]; then
  if [ -e "$ORCH_DIR" ]; then
    printf 'Orchestrator path exists but is not a git repo: %s\n' "$ORCH_DIR" >&2
    printf 'Move it aside, or remove it if it is an empty failed clone, then re-run.\n' >&2
    exit 1
  fi
  git clone "https://github.com/${ORCH_REPO}.git" "$ORCH_DIR"
fi

# 6. Hand off (forward any extra args, e.g. --with-work)
exec "$ORCH_DIR/setup" "$@"
