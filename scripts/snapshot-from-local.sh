#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "${REPO_ROOT}/skills"
mkdir -p "${REPO_ROOT}/agents-skills"
mkdir -p "${REPO_ROOT}/automations-templates"
mkdir -p "${REPO_ROOT}/automation-tools"

if [ -f "${HOME}/.codex/AGENTS.md" ]; then
  cp "${HOME}/.codex/AGENTS.md" "${REPO_ROOT}/AGENTS.md"
fi

if [ -d "${HOME}/.codex/skills" ]; then
  rsync -a --delete --exclude '.system' --exclude '.DS_Store' "${HOME}/.codex/skills/" "${REPO_ROOT}/skills/"
fi

if [ -d "${HOME}/.agents/skills" ]; then
  rsync -a --delete --exclude '.DS_Store' "${HOME}/.agents/skills/" "${REPO_ROOT}/agents-skills/"
fi

if [ -d "${HOME}/.codex/automations" ]; then
  # Live schedules are host-specific and may be paused or intentionally absent
  # on this Mac. Preserve repo-only templates; explicit deletion must be manual.
  for file in "${HOME}"/.codex/automations/*/automation.toml; do
    [ -e "${file}" ] || continue
    name="$(basename "$(dirname "${file}")")"
    mkdir -p "${REPO_ROOT}/automations-templates/${name}"
    cp "${file}" "${REPO_ROOT}/automations-templates/${name}/automation.toml"
  done
fi

TRACKER_SRC="${HOME}/.codex/automations/component-market-tracker"
TRACKER_DEST="${REPO_ROOT}/automation-tools/component-market-tracker"

if [ -d "${TRACKER_SRC}" ]; then
  mkdir -p "${TRACKER_DEST}"
  rsync -a --delete \
    --exclude '.DS_Store' \
    --exclude '__pycache__' \
    --exclude 'runs/' \
    --exclude 'reports/' \
    --exclude 'snapshots/' \
    "${TRACKER_SRC}/" "${TRACKER_DEST}/"
fi

echo "Snapshot complete: ${REPO_ROOT}"
