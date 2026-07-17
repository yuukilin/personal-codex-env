#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
DB_PATH="${CODEX_HOME}/sqlite/codex-dev.db"

path_has_symlink_component() {
  checked_path="$1"
  case "${checked_path}" in
    /*) current_path="/" ;;
    *) current_path="" ;;
  esac
  local IFS='/'
  local components=()
  local component
  read -r -a components <<< "${checked_path}"
  for component in "${components[@]}"; do
    [ -n "${component}" ] || continue
    if [ "${current_path}" = "/" ]; then
      current_path="/${component}"
    elif [ -n "${current_path}" ]; then
      current_path="${current_path}/${component}"
    else
      current_path="${component}"
    fi
    [ ! -L "${current_path}" ] || return 0
  done
  return 1
}

assert_path_chain_safe() {
  checked_path="$1"
  if path_has_symlink_component "${checked_path}"; then
    echo "ERROR: symlink component is forbidden during runtime restore: ${checked_path}" >&2
    exit 1
  fi
}

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <backup-automations-runtime-dir> <schedule-id>" >&2
  exit 2
fi

SOURCE_ROOT="$1"
SCHEDULE_ID="$2"

case "${SCHEDULE_ID}" in
  ''|*[!A-Za-z0-9._-]*)
    echo "ERROR: unsafe schedule id: ${SCHEDULE_ID}" >&2
    exit 2
    ;;
esac

SOURCE_DIR="${SOURCE_ROOT}/${SCHEDULE_ID}"
DEST_DIR="${CODEX_HOME}/automations/${SCHEDULE_ID}"
DEST_CONFIG="${DEST_DIR}/automation.toml"

assert_path_chain_safe "${SOURCE_ROOT}"
assert_path_chain_safe "${SOURCE_DIR}"
assert_path_chain_safe "${CODEX_HOME}"
assert_path_chain_safe "${CODEX_HOME}/automations"
assert_path_chain_safe "${CODEX_HOME}/sqlite"
assert_path_chain_safe "${DB_PATH}"
assert_path_chain_safe "${DEST_DIR}"
assert_path_chain_safe "${DEST_CONFIG}"

if [ ! -d "${SOURCE_DIR}" ] || [ -L "${SOURCE_DIR}" ]; then
  echo "ERROR: backup schedule runtime is missing or unsafe: ${SOURCE_DIR}" >&2
  exit 1
fi
if [ ! -f "${DEST_CONFIG}" ] || [ -L "${DEST_CONFIG}" ]; then
  echo "ERROR: live schedule must first be recreated through the Codex automation tool: ${DEST_CONFIG}" >&2
  exit 1
fi

live_id="$(sed -E -n 's/^[[:space:]]*id[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "${DEST_CONFIG}" | head -n 1)"
if [ "${live_id}" != "${SCHEDULE_ID}" ]; then
  echo "ERROR: live schedule id '${live_id}' does not match requested '${SCHEDULE_ID}'" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1 || [ ! -f "${DB_PATH}" ]; then
  echo "ERROR: live automation registry is unavailable; refusing file-only restore: ${DB_PATH}" >&2
  exit 1
fi
assert_path_chain_safe "${CODEX_HOME}/sqlite"
assert_path_chain_safe "${DB_PATH}"
db_id="$(sqlite3 -readonly "${DB_PATH}" \
  "SELECT id FROM automations WHERE id='${SCHEDULE_ID}' LIMIT 1;" 2>/dev/null || true)"
if [ "${db_id}" != "${SCHEDULE_ID}" ]; then
  echo "ERROR: schedule is missing from the live automation registry: ${SCHEDULE_ID}" >&2
  exit 1
fi

while IFS= read -r -d '' unsafe_link; do
  echo "ERROR: symlink is forbidden during runtime restore: ${unsafe_link}" >&2
  exit 1
done < <(find "${SOURCE_DIR}" "${DEST_DIR}" -type l -print0)

restore_log="$(mktemp "${TMPDIR:-/tmp}/automation-runtime-restore.XXXXXX")"
cleanup() {
  rm -f "${restore_log}"
}
trap cleanup EXIT

# --ignore-existing is the central safety property: local files created by the
# newly restored schedule remain authoritative. The source is also a strict
# runtime allowlist, so an old backup can never reintroduce scripts/config/tool
# markers into ~/.codex/automations.
assert_path_chain_safe "${SOURCE_ROOT}"
assert_path_chain_safe "${SOURCE_DIR}"
assert_path_chain_safe "${DEST_DIR}"
assert_path_chain_safe "${DEST_CONFIG}"
rsync -rti --ignore-existing --omit-dir-times \
  --include '/memory.md' \
  --include '/last-run.md' \
  --include '/last-close.md' \
  --include '/manual-resolutions.json' \
  --include '/*.log' \
  --include '/runs/***' \
  --include '/reports/***' \
  --include '/snapshots/***' \
  --include '/backups/***' \
  --include '/logs/***' \
  --include '/cache/***' \
  --include '/caches/***' \
  --include '/sessions/***' \
  --exclude '*' \
  "${SOURCE_DIR}/" "${DEST_DIR}/" > "${restore_log}"

restored_count="$(grep -cE '^>f|^cd|^cL|^cD' "${restore_log}" || true)"
echo "Missing-only runtime restore complete: schedule=${SCHEDULE_ID}, restored_entries=${restored_count}"
if [ -s "${restore_log}" ]; then
  cat "${restore_log}"
fi

while IFS= read -r source_entry; do
  [ -n "${source_entry}" ] || continue
  source_name="$(basename "${source_entry}")"
  case "${source_name}" in
    automation.toml|.DS_Store|memory.md|last-run.md|last-close.md|manual-resolutions.json|runs|reports|snapshots|backups|logs|cache|caches|sessions|*.log)
      ;;
    *)
      printf 'Skipped non-runtime backup entry: %s\n' "${source_entry}"
      ;;
  esac
done < <(find "${SOURCE_DIR}" -mindepth 1 -maxdepth 1 -print)
