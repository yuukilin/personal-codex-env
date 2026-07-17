#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
BACKUP_ROOT="${BACKUP_ROOT:-${CODEX_BACKUP_ROOT:-${HOME}/.codex-env-backups}}"
STAMP="${HOST_STATE_STAMP:-$(date +%Y%m%d-%H%M%S)}"

if command -v scutil >/dev/null 2>&1; then
  HOST_NAME="${CODEX_HOST_NAME:-$(scutil --get ComputerName 2>/dev/null || hostname)}"
else
  HOST_NAME="${CODEX_HOST_NAME:-$(hostname)}"
fi

SAFE_HOST="$(printf '%s' "${HOST_NAME}" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//;s/-$//')"
if [ -z "${SAFE_HOST}" ]; then
  SAFE_HOST="unknown-host"
fi

OUT_DIR="${1:-${BACKUP_ROOT}/automation-host-state/${SAFE_HOST}/${STAMP}}"
if [ -e "${OUT_DIR}" ]; then
  echo "Host-state destination already exists; refusing to overwrite: ${OUT_DIR}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
INDEX_FILE="${OUT_DIR}/index.tsv"
printf 'directory\tstatus\ttarget_or_project_id\tcwds\tcreated_at\tupdated_at\n' > "${INDEX_FILE}"

for config in "${CODEX_HOME}"/automations/*/automation.toml; do
  [ -e "${config}" ] || continue
  directory="$(basename "$(dirname "${config}")")"
  destination="${OUT_DIR}/${directory}"
  mkdir -p "${destination}"
  cp -p "${config}" "${destination}/automation.toml"

  status="$(sed -E -n 's/^[[:space:]]*status[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "${config}" | head -n 1)"
  target="$(sed -E -n 's/^[[:space:]]*target[[:space:]]*=[[:space:]]*(.*)$/\1/p' "${config}" | head -n 1)"
  if [ -z "${target}" ]; then
    target="$(sed -E -n 's/^[[:space:]]*(project_id|projectId)[[:space:]]*=[[:space:]]*(.*)$/\2/p' "${config}" | head -n 1)"
  fi
  cwds="$(sed -E -n 's/^[[:space:]]*cwds[[:space:]]*=[[:space:]]*(.*)$/\1/p' "${config}" | head -n 1)"
  created_at="$(sed -E -n 's/^[[:space:]]*created_at[[:space:]]*=[[:space:]]*(.*)$/\1/p' "${config}" | head -n 1)"
  updated_at="$(sed -E -n 's/^[[:space:]]*updated_at[[:space:]]*=[[:space:]]*(.*)$/\1/p' "${config}" | head -n 1)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${directory}" "${status}" "${target}" "${cwds}" \
    "${created_at}" "${updated_at}" >> "${INDEX_FILE}"
done

cat > "${OUT_DIR}/README.md" <<EOF
# Per-Mac automation host state

Captured from: ${HOST_NAME}
Captured at: $(date '+%Y-%m-%d %H:%M:%S %z')

These are exact local automation.toml records for recovery and human review.
They are not portable templates. Do not install them on another Mac and do not
commit their status, target, cwds, created_at, or updated_at fields as shared
automation definitions.
EOF

echo "Automation host state captured: ${OUT_DIR}"
