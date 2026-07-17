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
    echo "ERROR: symlink component is forbidden during runtime seeding: ${checked_path}" >&2
    exit 1
  fi
}

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <seed-file> <schedule-id> <runtime-file-name>" >&2
  exit 2
fi

SEED_FILE="$1"
SCHEDULE_ID="$2"
RUNTIME_NAME="$3"

case "${SCHEDULE_ID}" in
  ''|*[!A-Za-z0-9._-]*)
    echo "ERROR: unsafe schedule id: ${SCHEDULE_ID}" >&2
    exit 2
    ;;
esac
case "${RUNTIME_NAME}" in
  memory.md|manual-resolutions.json)
    ;;
  *)
    echo "ERROR: runtime seed target is not allowlisted: ${RUNTIME_NAME}" >&2
    exit 2
    ;;
esac

if [ ! -f "${SEED_FILE}" ] || [ -L "${SEED_FILE}" ]; then
  echo "ERROR: seed is missing, non-regular, or a symlink: ${SEED_FILE}" >&2
  exit 1
fi

DEST_DIR="${CODEX_HOME}/automations/${SCHEDULE_ID}"
DEST_CONFIG="${DEST_DIR}/automation.toml"
DEST_FILE="${DEST_DIR}/${RUNTIME_NAME}"

assert_path_chain_safe "${CODEX_HOME}"
assert_path_chain_safe "${CODEX_HOME}/automations"
assert_path_chain_safe "${CODEX_HOME}/sqlite"
assert_path_chain_safe "${DB_PATH}"
assert_path_chain_safe "${DEST_DIR}"
assert_path_chain_safe "${DEST_CONFIG}"
assert_path_chain_safe "${DEST_FILE}"
assert_path_chain_safe "${SEED_FILE}"

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
  echo "ERROR: live automation registry is unavailable; refusing file-only seed: ${DB_PATH}" >&2
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
  echo "ERROR: symlink is forbidden during runtime seeding: ${unsafe_link}" >&2
  exit 1
done < <(find "${DEST_DIR}" -type l -print0)

if [ -e "${DEST_FILE}" ]; then
  if [ ! -f "${DEST_FILE}" ]; then
    echo "ERROR: existing runtime target is not a regular file: ${DEST_FILE}" >&2
    exit 1
  fi
  echo "Runtime seed preserved existing file: ${DEST_FILE}"
  exit 0
fi

temp_file="${DEST_DIR}/.${RUNTIME_NAME}.seed.$$"
assert_path_chain_safe "${DEST_DIR}"
assert_path_chain_safe "${DEST_FILE}"
assert_path_chain_safe "${SEED_FILE}"
if [ -e "${temp_file}" ] || [ -L "${temp_file}" ]; then
  echo "ERROR: temporary seed path already exists: ${temp_file}" >&2
  exit 1
fi
cp -p "${SEED_FILE}" "${temp_file}"
if ln "${temp_file}" "${DEST_FILE}" 2>/dev/null; then
  rm -f "${temp_file}"
  echo "Runtime seed initialized missing file: ${DEST_FILE}"
elif [ -f "${DEST_FILE}" ] && [ ! -L "${DEST_FILE}" ]; then
  rm -f "${temp_file}"
  echo "Runtime seed preserved file created concurrently: ${DEST_FILE}"
else
  rm -f "${temp_file}"
  echo "ERROR: runtime seed target appeared in an unsafe form: ${DEST_FILE}" >&2
  exit 1
fi
