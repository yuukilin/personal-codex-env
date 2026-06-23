#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

if command -v scutil >/dev/null 2>&1; then
  HOST_NAME="$(scutil --get ComputerName 2>/dev/null || hostname)"
else
  HOST_NAME="$(hostname)"
fi

SAFE_HOST="$(printf "%s" "${HOST_NAME}" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//;s/-$//')"
OUT_DIR="${REPO_ROOT}/incoming/${SAFE_HOST}-${STAMP}"

mkdir -p "${OUT_DIR}"

if [ -f "${HOME}/.codex/AGENTS.md" ]; then
  cp "${HOME}/.codex/AGENTS.md" "${OUT_DIR}/AGENTS.md"
fi

if [ -d "${HOME}/.codex/skills" ]; then
  mkdir -p "${OUT_DIR}/skills"
  rsync -a --exclude '.system' --exclude '.DS_Store' "${HOME}/.codex/skills/" "${OUT_DIR}/skills/"
fi

if [ -d "${HOME}/.agents/skills" ]; then
  mkdir -p "${OUT_DIR}/agents-skills"
  rsync -a --exclude '.DS_Store' "${HOME}/.agents/skills/" "${OUT_DIR}/agents-skills/"
fi

if [ -d "${HOME}/.codex/automations" ]; then
  mkdir -p "${OUT_DIR}/automations-templates"
  for file in "${HOME}"/.codex/automations/*/automation.toml; do
    [ -e "${file}" ] || continue
    name="$(basename "$(dirname "${file}")")"
    mkdir -p "${OUT_DIR}/automations-templates/${name}"
    cp "${file}" "${OUT_DIR}/automations-templates/${name}/automation.toml"
  done
fi

cat > "${OUT_DIR}/README.md" <<EOF
# Incoming Codex environment snapshot

Collected from: ${HOST_NAME}
Collected at: ${STAMP}

This folder is for merge review only. Do not install it directly.
EOF

echo "Collected local Codex environment for merge review:"
echo "${OUT_DIR}"
