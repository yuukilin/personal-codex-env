#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
AGENTS_HOME="${AGENTS_HOME:-${HOME}/.agents}"
STAMP="${COLLECT_STAMP:-$(date +%Y%m%d-%H%M%S)}"
LOCAL_STATE_ROOT="${CODEX_MERGE_STATE_ROOT:-${HOME}/.codex-env-backups/merge-review}"

if [ -n "${CODEX_HOST_NAME:-}" ]; then
  HOST_NAME="${CODEX_HOST_NAME}"
elif command -v scutil >/dev/null 2>&1; then
  HOST_NAME="$(scutil --get ComputerName 2>/dev/null || hostname)"
else
  HOST_NAME="$(hostname)"
fi

SAFE_HOST="$(printf '%s' "${HOST_NAME}" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//;s/-$//')"
if [ -z "${SAFE_HOST}" ]; then
  SAFE_HOST="unknown-host"
fi

OUT_DIR="${REPO_ROOT}/incoming/${SAFE_HOST}-${STAMP}"
LOCAL_HOST_STATE_DIR="${LOCAL_STATE_ROOT}/${SAFE_HOST}-${STAMP}/automations-host-state"

if [ -e "${OUT_DIR}" ]; then
  echo "Collection destination already exists; refusing to overwrite: ${OUT_DIR}" >&2
  exit 1
fi
if [ -e "${LOCAL_HOST_STATE_DIR}" ]; then
  echo "Local host-state destination already exists; refusing to overwrite: ${LOCAL_HOST_STATE_DIR}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

if [ -f "${CODEX_HOME}/AGENTS.md" ]; then
  cp -p "${CODEX_HOME}/AGENTS.md" "${OUT_DIR}/AGENTS.md"
fi

# Collect only already-tracked command-rule names. Arbitrary local privilege
# rules are intentionally excluded from a branch that may be pushed.
while IFS= read -r -d '' tracked_rule; do
  relative_rule="${tracked_rule#rules/}"
  local_rule="${CODEX_HOME}/rules/${relative_rule}"
  if [ -f "${local_rule}" ] && [ ! -L "${local_rule}" ]; then
    mkdir -p "$(dirname "${OUT_DIR}/${tracked_rule}")"
    cp -p "${local_rule}" "${OUT_DIR}/${tracked_rule}"
  fi
done < <(git -C "${REPO_ROOT}" ls-files -z -- rules)

if [ -d "${CODEX_HOME}/skills" ]; then
  mkdir -p "${OUT_DIR}/skills"
  rsync -a --exclude '.system' --exclude '.DS_Store' \
    "${CODEX_HOME}/skills/" "${OUT_DIR}/skills/"
fi

if [ -d "${AGENTS_HOME}/skills" ]; then
  mkdir -p "${OUT_DIR}/agents-skills"
  rsync -a --exclude '.DS_Store' \
    "${AGENTS_HOME}/skills/" "${OUT_DIR}/agents-skills/"
fi

# Full local TOMLs are useful for same-host recovery, but they contain
# machine-specific status/target/cwd/timestamps. Keep them physically outside
# the Git repository so `git add incoming` can never publish them.
if [ -d "${CODEX_HOME}/automations" ]; then
  bash "${REPO_ROOT}/scripts/capture-automation-host-state.sh" \
    "${LOCAL_HOST_STATE_DIR}"
fi

cat > "${OUT_DIR}/README.md" <<EOF
# Incoming Codex environment snapshot

Collected from: ${HOST_NAME}
Collected at: ${STAMP}

This folder is for rules and skills merge review only. Do not install it
directly. Command rules are limited to filenames already tracked by the
private repo. Full automation host-state is deliberately stored outside this
Git repository and must stay on the Mac that created it.
EOF

echo "Collected local Codex environment for merge review:"
echo "${OUT_DIR}"
if [ -d "${LOCAL_HOST_STATE_DIR}" ]; then
  echo "Local-only automation host-state (never commit or copy to another Mac):"
  echo "${LOCAL_HOST_STATE_DIR}"
fi
