#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INCOMING_ROOT="${1:-${REPO_ROOT}/incoming}"
ERRORS=0

record_error() {
  echo "ERROR: $*" >&2
  ERRORS=$((ERRORS + 1))
}

if [ ! -e "${INCOMING_ROOT}" ] && [ ! -L "${INCOMING_ROOT}" ]; then
  echo "No incoming merge snapshots to validate."
  exit 0
fi

if [ -L "${INCOMING_ROOT}" ] || [ ! -d "${INCOMING_ROOT}" ]; then
  echo "ERROR: incoming root must be a real directory: ${INCOMING_ROOT}" >&2
  exit 1
fi

SNAPSHOT_COUNT=0
while IFS= read -r -d '' snapshot_dir; do
  SNAPSHOT_COUNT=$((SNAPSHOT_COUNT + 1))
  if [ -L "${snapshot_dir}" ] || [ ! -d "${snapshot_dir}" ]; then
    record_error "incoming snapshot must be a real directory: ${snapshot_dir}"
    continue
  fi

  while IFS= read -r -d '' top_entry; do
    top_name="$(basename "${top_entry}")"
    case "${top_name}" in
      AGENTS.md|README.md)
        if [ -L "${top_entry}" ] || [ ! -f "${top_entry}" ]; then
          record_error "incoming document must be a regular file: ${top_entry}"
        fi
        ;;
      rules|skills|agents-skills)
        if [ -L "${top_entry}" ] || [ ! -d "${top_entry}" ]; then
          record_error "incoming managed tree must be a real directory: ${top_entry}"
        fi
        ;;
      *)
        record_error "unsupported incoming top-level entry: ${top_entry}"
        ;;
    esac
  done < <(find "${snapshot_dir}" -mindepth 1 -maxdepth 1 -print0)

  while IFS= read -r -d '' incoming_entry; do
    if [ -L "${incoming_entry}" ]; then
      record_error "symlink is forbidden in incoming snapshots: ${incoming_entry}"
      continue
    fi

    entry_name="$(basename "${incoming_entry}")"
    case "${entry_name}" in
      automation.toml|memory.md|last-run.md|last-close.md|manual-resolutions.json|\
      auth.json|hosts.yml|credentials.json|client_secret*.json|service-account*.json|\
      config.toml|.env|.env.*|*.token|*.key|*.pem|*.p12|*.pfx|\
      id_rsa|id_ed25519|*.sqlite|*.sqlite-*|*.db|*.db-*|*.log|\
      .DS_Store|*.codex-sync.*|.git|.hg|.svn|.ssh|.aws|\
      automations|automations-host-state|automation-tools|runs|reports|snapshots|\
      backups|logs|cache|caches|sessions|sqlite|mcp)
        record_error "host-local, secret, or runtime entry is forbidden in incoming snapshots: ${incoming_entry}"
        ;;
    esac
  done < <(find "${snapshot_dir}" -mindepth 1 -print0)
done < <(find "${INCOMING_ROOT}" -mindepth 1 -maxdepth 1 -print0)

if [ "${ERRORS}" -ne 0 ]; then
  echo "Incoming merge validation failed with ${ERRORS} error(s)." >&2
  exit 1
fi

echo "Incoming merge validation passed for ${SNAPSHOT_COUNT} snapshot(s)."
