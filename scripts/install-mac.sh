#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "${HOME}/.codex/skills"
mkdir -p "${HOME}/.agents/skills"

if [ -f "${REPO_ROOT}/AGENTS.md" ]; then
  cp "${REPO_ROOT}/AGENTS.md" "${HOME}/.codex/AGENTS.md"
fi

if [ -d "${REPO_ROOT}/skills" ]; then
  rsync -a --delete --filter 'P .system/***' --exclude '.system' --exclude '.DS_Store' "${REPO_ROOT}/skills/" "${HOME}/.codex/skills/"
fi

if [ -d "${REPO_ROOT}/agents-skills" ]; then
  rsync -a --delete --exclude '.DS_Store' "${REPO_ROOT}/agents-skills/" "${HOME}/.agents/skills/"
fi

echo "Installed Codex rules and skills from ${REPO_ROOT}"
echo "Preserved Codex system skills under ${HOME}/.codex/skills/.system when present."
echo "Restart Codex if the skill list does not refresh immediately."
echo "For Obsidian MCP on this Mac, run: ${REPO_ROOT}/scripts/setup-obsidian-mcp.sh"
