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

if [ -d "${HOME}/.codex/automations" ]; then
  mkdir -p "${BACKUP_DIR}/automations-templates"
  for file in "${HOME}"/.codex/automations/*/automation.toml; do
    [ -e "${file}" ] || continue
    name="$(basename "$(dirname "${file}")")"
    mkdir -p "${BACKUP_DIR}/automations-templates/${name}"
    cp "${file}" "${BACKUP_DIR}/automations-templates/${name}/automation.toml"
  done
fi

TRACKER_SRC="${HOME}/.codex/automations/component-market-tracker"

if [ -d "${TRACKER_SRC}" ]; then
  mkdir -p "${BACKUP_DIR}/automation-tools/component-market-tracker"
  rsync -a \
    --exclude '.DS_Store' \
    --exclude '__pycache__' \
    --exclude 'runs/' \
    --exclude 'reports/' \
    --exclude 'snapshots/' \
    "${TRACKER_SRC}/" "${BACKUP_DIR}/automation-tools/component-market-tracker/"
fi

echo "Backup created: ${BACKUP_DIR}"
