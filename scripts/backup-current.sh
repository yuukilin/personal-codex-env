#!/usr/bin/env bash
set -euo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${HOME}/.codex-env-backups/${STAMP}"

mkdir -p "${BACKUP_DIR}"

if [ -f "${HOME}/.codex/AGENTS.md" ]; then
  cp "${HOME}/.codex/AGENTS.md" "${BACKUP_DIR}/AGENTS.md"
fi

if [ -d "${HOME}/.codex/skills" ]; then
  mkdir -p "${BACKUP_DIR}/codex-skills"
  rsync -a --exclude '.system' --exclude '.DS_Store' "${HOME}/.codex/skills/" "${BACKUP_DIR}/codex-skills/"
fi

if [ -d "${HOME}/.agents/skills" ]; then
  mkdir -p "${BACKUP_DIR}/agents-skills"
  rsync -a --exclude '.DS_Store' "${HOME}/.agents/skills/" "${BACKUP_DIR}/agents-skills/"
fi

echo "Backup created: ${BACKUP_DIR}"
