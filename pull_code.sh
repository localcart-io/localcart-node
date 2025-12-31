#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/localcart-node"
BRANCH="${1:-main}"   # optionally allow: ./pull_code.sh main

cd "$REPO_DIR"

# Update remote refs (does not change working tree)
git fetch origin "$BRANCH"

LOCAL_SHA="$(git rev-parse HEAD)"
REMOTE_SHA="$(git rev-parse "origin/$BRANCH")"

if [ "$LOCAL_SHA" = "$REMOTE_SHA" ]; then
  echo "No update needed (already at $LOCAL_SHA)."
  exit 0
fi

echo "Update available:"
echo "  local : $LOCAL_SHA"
echo "  remote: $REMOTE_SHA"
echo "Applying update..."

# Force working tree to exactly match the remote branch
git reset --hard "origin/$BRANCH"

# Remove untracked files/dirs but keep device identity + logs
git clean -fd -e device-id.txt -e run.log

echo "Code updated to $REMOTE_SHA. Rebooting…"
sudo reboot