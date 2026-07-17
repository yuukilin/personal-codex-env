#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
AGENTS_HOME="${AGENTS_HOME:-${HOME}/.agents}"

# Refuse to snapshot into a repository whose automation layout is unsafe. This
# check is read-only and deliberately runs before any repository write.
bash "${REPO_ROOT}/scripts/validate-sync-layout.sh"

mkdir -p "${REPO_ROOT}/skills"
mkdir -p "${REPO_ROOT}/agents-skills"
mkdir -p "${REPO_ROOT}/rules"

if [ -f "${CODEX_HOME}/AGENTS.md" ]; then
  cp -p "${CODEX_HOME}/AGENTS.md" "${REPO_ROOT}/AGENTS.md"
fi

# Command rules can affect privilege boundaries, so snapshot only filenames
# that are already approved and Git-tracked. Never import arbitrary local rules.
while IFS= read -r -d '' tracked_rule; do
  relative_rule="${tracked_rule#rules/}"
  local_rule="${CODEX_HOME}/rules/${relative_rule}"
  if [ -f "${local_rule}" ] && [ ! -L "${local_rule}" ]; then
    mkdir -p "$(dirname "${REPO_ROOT}/${tracked_rule}")"
    cp -p "${local_rule}" "${REPO_ROOT}/${tracked_rule}"
  fi
done < <(git -C "${REPO_ROOT}" ls-files -z -- rules)

if [ -d "${CODEX_HOME}/skills" ]; then
  rsync -a --exclude '.system' --exclude '.DS_Store' \
    "${CODEX_HOME}/skills/" "${REPO_ROOT}/skills/"
fi

if [ -d "${AGENTS_HOME}/skills" ]; then
  rsync -a --exclude '.DS_Store' \
    "${AGENTS_HOME}/skills/" "${REPO_ROOT}/agents-skills/"
fi

# Live automation.toml files, runtime memory, and tool state are intentionally
# not copied here. Shared automation definitions must be edited explicitly.
echo "Snapshot complete: ${REPO_ROOT}"
echo "Live schedules and automation runtime were intentionally left untouched."
