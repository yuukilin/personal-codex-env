#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "${REPO_ROOT}/skills"
mkdir -p "${REPO_ROOT}/agents-skills"

if [ -f "${HOME}/.codex/AGENTS.md" ]; then
  cp "${HOME}/.codex/AGENTS.md" "${REPO_ROOT}/AGENTS.md"
fi

if [ -d "${HOME}/.codex/skills" ]; then
  rsync -a --delete --exclude '.system' --exclude '.DS_Store' "${HOME}/.codex/skills/" "${REPO_ROOT}/skills/"
fi

if [ -d "${HOME}/.agents/skills" ]; then
  rsync -a --delete --exclude '.DS_Store' "${HOME}/.agents/skills/" "${REPO_ROOT}/agents-skills/"
fi

echo "Snapshot complete: ${REPO_ROOT}"
