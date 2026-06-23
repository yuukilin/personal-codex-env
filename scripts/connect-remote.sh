#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: ./scripts/connect-remote.sh git@github.com:OWNER/personal-codex-env.git"
  echo "   or: ./scripts/connect-remote.sh https://github.com/OWNER/personal-codex-env.git"
  exit 2
fi

REMOTE_URL="$1"

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "${REMOTE_URL}"
else
  git remote add origin "${REMOTE_URL}"
fi

git push -u origin main
