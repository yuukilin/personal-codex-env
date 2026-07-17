#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
AGENTS_HOME="${AGENTS_HOME:-${HOME}/.agents}"
BACKUP_ROOT="${BACKUP_ROOT:-${CODEX_BACKUP_ROOT:-${HOME}/.codex-env-backups}}"
STAMP="${BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}"
BACKUP_DIR="${BACKUP_ROOT}/${STAMP}"
SQLITE_BACKUP_MODE="absent"
SQLITE_FORENSICS_MODE="absent"
REGISTRY_WINDOW_CHECK="not_available"
HOST_STATE_CHECK="not_available"
AUTOMATION_STATE_PRESENT=0
LIVE_CONFIG_COUNT=0
CAPTURE_STARTED_AT=""
CAPTURE_FINISHED_AT=""
REGISTRY_QUERY='SELECT id,name,prompt,status,rrule,model,reasoning_effort,target_type,project_id,cwds,next_run_at,last_run_at,created_at,updated_at FROM automations ORDER BY id;'

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

if [ -e "${BACKUP_DIR}" ]; then
  echo "Backup destination already exists; refusing to overwrite: ${BACKUP_DIR}" >&2
  exit 1
fi

mkdir -p "${BACKUP_DIR}"

source_db="${CODEX_HOME}/sqlite/codex-dev.db"
for protected_path in "${CODEX_HOME}" "${CODEX_HOME}/automations" \
  "${CODEX_HOME}/sqlite" "${source_db}"; do
  if path_has_symlink_component "${protected_path}"; then
    echo "Unsafe symlink component in automation backup source: ${protected_path}" >&2
    exit 1
  fi
done

if [ -d "${CODEX_HOME}/automations" ]; then
  LIVE_CONFIG_COUNT="$(find "${CODEX_HOME}/automations" -mindepth 2 -maxdepth 2 \
    -name automation.toml -print | wc -l | tr -d '[:space:]')"
fi
if [ "${LIVE_CONFIG_COUNT}" -gt 0 ] || [ -e "${source_db}" ]; then
  AUTOMATION_STATE_PRESENT=1
else
  REGISTRY_WINDOW_CHECK="fresh_empty"
  HOST_STATE_CHECK="fresh_empty"
fi

if [ -f "${CODEX_HOME}/AGENTS.md" ]; then
  cp -p "${CODEX_HOME}/AGENTS.md" "${BACKUP_DIR}/AGENTS.md"
fi

if [ -d "${CODEX_HOME}/rules" ]; then
  mkdir -p "${BACKUP_DIR}/codex-rules"
  rsync -a "${CODEX_HOME}/rules/" "${BACKUP_DIR}/codex-rules/"
fi

if [ -d "${CODEX_HOME}/skills" ]; then
  mkdir -p "${BACKUP_DIR}/codex-skills"
  rsync -a "${CODEX_HOME}/skills/" "${BACKUP_DIR}/codex-skills/"
fi

if [ -d "${AGENTS_HOME}/skills" ]; then
  mkdir -p "${BACKUP_DIR}/agents-skills"
  rsync -a "${AGENTS_HOME}/skills/" "${BACKUP_DIR}/agents-skills/"
fi

# Open a read-only registry window before copying any schedule runtime. The
# matching query below is repeated after the SQLite online backup. If the two
# live views or the authoritative backup disagree, the backup is preserved for
# forensics but the caller fails closed and must retry before installation.
if [ "${AUTOMATION_STATE_PRESENT}" -eq 1 ] && \
  [ -f "${source_db}" ] && command -v sqlite3 >/dev/null 2>&1; then
  mkdir -p "${BACKUP_DIR}/sqlite"
  CAPTURE_STARTED_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"
  sqlite3 -readonly -header -separator $'\t' "${source_db}" \
    ".timeout 5000" "${REGISTRY_QUERY}" \
    > "${BACKUP_DIR}/sqlite/registry-window-before.tsv"
  REGISTRY_WINDOW_CHECK="pending"
elif [ "${AUTOMATION_STATE_PRESENT}" -eq 1 ]; then
  REGISTRY_WINDOW_CHECK="registry_unavailable"
  HOST_STATE_CHECK="registry_unavailable"
fi

# Preserve the entire automation runtime. This intentionally includes local
# switches, prompts, memories, manual resolutions, logs, reports, and snapshots.
if [ -d "${CODEX_HOME}/automations" ]; then
  mkdir -p "${BACKUP_DIR}/automations-runtime"
  rsync -a "${CODEX_HOME}/automations/" "${BACKUP_DIR}/automations-runtime/"
  bash "${SCRIPT_DIR}/capture-automation-host-state.sh" \
    "${BACKUP_DIR}/automations-host-state"
fi

# Portable tools have their own root so installer code can never collide with a
# live schedule directory. Preserve tool-local memory and any generated state.
if [ -d "${CODEX_HOME}/automation-tools" ]; then
  mkdir -p "${BACKUP_DIR}/automation-tools-runtime"
  rsync -a "${CODEX_HOME}/automation-tools/" \
    "${BACKUP_DIR}/automation-tools-runtime/"
fi

if [ -d "${CODEX_HOME}/automation-templates" ]; then
  mkdir -p "${BACKUP_DIR}/automation-templates-cache"
  rsync -a "${CODEX_HOME}/automation-templates/" \
    "${BACKUP_DIR}/automation-templates-cache/"
fi

# Use SQLite's online backup API when available so the registry is one atomic,
# consistent snapshot even while Codex has a WAL open. Export human-readable
# TSV/JSON inventories as an additional DB-only/file-only recovery aid.
if [ -d "${CODEX_HOME}/sqlite" ]; then
  mkdir -p "${BACKUP_DIR}/sqlite"
  backup_db="${BACKUP_DIR}/sqlite/codex-dev.db"
  if [ -f "${source_db}" ] && command -v sqlite3 >/dev/null 2>&1; then
    partial_db="${backup_db}.partial.$$"
    sqlite3 "file:${source_db}?mode=ro" \
      ".timeout 5000" ".backup '${partial_db}'"
    if [ "$(sqlite3 -readonly "${partial_db}" 'PRAGMA integrity_check;')" != "ok" ]; then
      rm -f "${partial_db}"
      echo "SQLite backup integrity check failed; refusing installation." >&2
      exit 1
    fi
    mv "${partial_db}" "${backup_db}"

    sqlite3 -readonly -header -separator $'\t' "${backup_db}" \
      "${REGISTRY_QUERY}" > "${BACKUP_DIR}/sqlite/automations-registry.tsv"
    sqlite3 -readonly "${backup_db}" '.mode json' \
      "${REGISTRY_QUERY}" > "${BACKUP_DIR}/sqlite/automations-registry.json"
    printf 'sqlite_online_backup\n' > "${BACKUP_DIR}/sqlite/BACKUP-MODE.txt"
    SQLITE_BACKUP_MODE="authoritative_online_backup"

    mkdir -p "${BACKUP_DIR}/sqlite/raw-forensics"
    for db_file in codex-dev.db codex-dev.db-wal codex-dev.db-shm; do
      if [ -f "${CODEX_HOME}/sqlite/${db_file}" ]; then
        cp -p "${CODEX_HOME}/sqlite/${db_file}" \
          "${BACKUP_DIR}/sqlite/raw-forensics/${db_file}" || true
      fi
    done
    SQLITE_FORENSICS_MODE="forensic_best_effort"

    if [ "${REGISTRY_WINDOW_CHECK}" = "pending" ]; then
      sqlite3 -readonly -header -separator $'\t' "${source_db}" \
        ".timeout 5000" "${REGISTRY_QUERY}" \
        > "${BACKUP_DIR}/sqlite/registry-window-after.tsv"
      CAPTURE_FINISHED_AT="$(date '+%Y-%m-%d %H:%M:%S %z')"
      if cmp -s "${BACKUP_DIR}/sqlite/registry-window-before.tsv" \
          "${BACKUP_DIR}/sqlite/registry-window-after.tsv" && \
        cmp -s "${BACKUP_DIR}/sqlite/registry-window-before.tsv" \
          "${BACKUP_DIR}/sqlite/automations-registry.tsv"; then
        REGISTRY_WINDOW_CHECK="stable"
      else
        REGISTRY_WINDOW_CHECK="changed_retry_required"
        {
          printf 'Automation registry changed while runtime and SQLite were being captured.\n'
          printf 'This backup is retained for forensics only. Retry before installation.\n'
        } > "${BACKUP_DIR}/sqlite/REGISTRY-WINDOW-MISMATCH.txt"
      fi
    fi

    if command -v python3 >/dev/null 2>&1 && \
      python3 -c 'import tomllib' >/dev/null 2>&1; then
      if python3 "${SCRIPT_DIR}/verify-automation-backup-consistency.py" \
        "${CODEX_HOME}/automations" \
        "${BACKUP_DIR}/automations-runtime" \
        "${BACKUP_DIR}/automations-host-state" \
        "${backup_db}" \
        > "${BACKUP_DIR}/sqlite/HOST-STATE-CONSISTENCY.txt" 2>&1; then
        HOST_STATE_CHECK="consistent"
      else
        HOST_STATE_CHECK="inconsistent"
      fi
    else
      HOST_STATE_CHECK="verifier_unavailable"
      printf 'python3 with tomllib is required for host-state verification.\n' \
        > "${BACKUP_DIR}/sqlite/HOST-STATE-CONSISTENCY.txt"
    fi
  else
    for db_file in codex-dev.db codex-dev.db-wal codex-dev.db-shm; do
      if [ -f "${CODEX_HOME}/sqlite/${db_file}" ]; then
        cp -p "${CODEX_HOME}/sqlite/${db_file}" "${BACKUP_DIR}/sqlite/${db_file}"
      fi
    done
    printf 'raw_copy_sqlite3_unavailable\n' > "${BACKUP_DIR}/sqlite/BACKUP-MODE.txt"
    SQLITE_BACKUP_MODE="raw_only_best_effort"
    SQLITE_FORENSICS_MODE="not_separate"
  fi
fi

{
  printf 'created_at=%s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  printf 'source_codex_home=%s\n' "${CODEX_HOME}"
  printf 'source_agents_home=%s\n' "${AGENTS_HOME}"
  printf 'codex_rules=%s\n' "$([ -d "${BACKUP_DIR}/codex-rules" ] && printf present || printf absent)"
  printf 'automations_runtime=%s\n' "$([ -d "${BACKUP_DIR}/automations-runtime" ] && printf present || printf absent)"
  printf 'automation_tools_runtime=%s\n' "$([ -d "${BACKUP_DIR}/automation-tools-runtime" ] && printf present || printf absent)"
  printf 'automation_host_state=%s\n' "$([ -d "${BACKUP_DIR}/automations-host-state" ] && printf present || printf absent)"
  printf 'sqlite_registry=%s\n' "$([ -f "${BACKUP_DIR}/sqlite/codex-dev.db" ] && printf present || printf absent)"
  printf 'sqlite_consistency=%s\n' "${SQLITE_BACKUP_MODE}"
  printf 'sqlite_raw_forensics=%s\n' "${SQLITE_FORENSICS_MODE}"
  printf 'registry_window_check=%s\n' "${REGISTRY_WINDOW_CHECK}"
  printf 'host_state_check=%s\n' "${HOST_STATE_CHECK}"
  printf 'live_automation_configs=%s\n' "${LIVE_CONFIG_COUNT}"
  printf 'capture_started_at=%s\n' "${CAPTURE_STARTED_AT:-not_available}"
  printf 'capture_finished_at=%s\n' "${CAPTURE_FINISHED_AT:-not_available}"
} > "${BACKUP_DIR}/BACKUP-MANIFEST.txt"

if [ "${AUTOMATION_STATE_PRESENT}" -eq 1 ] && \
  { [ "${SQLITE_BACKUP_MODE}" != "authoritative_online_backup" ] || \
    [ "${REGISTRY_WINDOW_CHECK}" != "stable" ] || \
    [ "${HOST_STATE_CHECK}" != "consistent" ]; }; then
  echo "Automation backup could not prove DB/live/host-state consistency; refusing installation until a stable retry succeeds: ${BACKUP_DIR}" >&2
  exit 1
fi

echo "Backup created: ${BACKUP_DIR}"
