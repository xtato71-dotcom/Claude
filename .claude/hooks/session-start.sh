#!/bin/bash
# Installs the Composio CLI and signs it in with $COMPOSIO_USER_API_KEY
# at the start of every Claude Code cloud session.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

COMPOSIO_VERSION=0.6.0
BIN_DIR="$HOME/.local/bin"
export PATH="$BIN_DIR:$PATH"

# Make the CLI available to the session's shell.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Install the pinned CLI version only if it is missing or different.
if [ "$(composio --version 2>/dev/null || true)" != "$COMPOSIO_VERSION" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL https://composio.dev/install -o "$tmp/install.sh"
  (cd "$tmp" && COMPOSIO_INSTALL_VERSION="$COMPOSIO_VERSION" \
    COMPOSIO_INSTALL_SHELL=none COMPOSIO_INSTALL_PLUGINS=0 \
    bash "$tmp/install.sh") >&2 || true
  # The installer can fail on optional agent setup; only the binary matters.
  [ "$(composio --version 2>/dev/null || true)" = "$COMPOSIO_VERSION" ] || {
    echo "Composio CLI $COMPOSIO_VERSION installation failed" >&2
    exit 1
  }
fi

# Sign in only if not already signed in. The CLI also reads
# COMPOSIO_USER_API_KEY from the environment and then reports success for any
# value, so check the saved login with that variable unset.
if ! env -u COMPOSIO_USER_API_KEY composio whoami >/dev/null 2>&1; then
  if [ -z "${COMPOSIO_USER_API_KEY:-}" ]; then
    echo "COMPOSIO_USER_API_KEY is not set: Composio CLI installed but not signed in" >&2
    exit 0
  fi
  composio login --user-api-key "$COMPOSIO_USER_API_KEY" -y --no-skill-install >/dev/null 2>&1 || {
    echo "Composio login failed: check COMPOSIO_USER_API_KEY" >&2
    exit 1
  }
fi
