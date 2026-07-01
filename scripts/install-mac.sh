#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "${HOME}/.codex/skills"
mkdir -p "${HOME}/.agents/skills"
mkdir -p "${HOME}/.codex/automation-templates"

if [ -f "${REPO_ROOT}/AGENTS.md" ]; then
  cp "${REPO_ROOT}/AGENTS.md" "${HOME}/.codex/AGENTS.md"
fi

if [ -d "${REPO_ROOT}/skills" ]; then
  rsync -a --delete --filter 'P .system/***' --exclude '.system' --exclude '.DS_Store' "${REPO_ROOT}/skills/" "${HOME}/.codex/skills/"
fi

if [ -d "${REPO_ROOT}/agents-skills" ]; then
  rsync -a --delete --exclude '.DS_Store' "${REPO_ROOT}/agents-skills/" "${HOME}/.agents/skills/"
fi

if [ -d "${REPO_ROOT}/automation-tools" ]; then
  mkdir -p "${HOME}/.codex/automations"
  for tool_dir in "${REPO_ROOT}"/automation-tools/*; do
    [ -d "${tool_dir}" ] || continue
    name="$(basename "${tool_dir}")"
    mkdir -p "${HOME}/.codex/automations/${name}"
    rsync -a --delete \
      --exclude '.DS_Store' \
      --exclude '__pycache__' \
      "${tool_dir}/" "${HOME}/.codex/automations/${name}/"
  done
fi

if [ -d "${REPO_ROOT}/automations-templates" ]; then
  rsync -a --delete --exclude '.DS_Store' "${REPO_ROOT}/automations-templates/" "${HOME}/.codex/automation-templates/"
fi

echo "Installed Codex rules and skills from ${REPO_ROOT}"
echo "Installed portable automation tools into ~/.codex/automations."
echo "Copied automation templates into ~/.codex/automation-templates only; enable schedules manually on one Mac."
echo "Preserved Codex system skills under ${HOME}/.codex/skills/.system when present."
echo "Restart Codex if the skill list does not refresh immediately."
echo "For Obsidian MCP on this Mac, run: ${REPO_ROOT}/scripts/setup-obsidian-mcp.sh"
