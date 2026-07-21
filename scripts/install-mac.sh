#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
AGENTS_HOME="${AGENTS_HOME:-${HOME}/.agents}"
BACKUP_ROOT_EFFECTIVE="${BACKUP_ROOT:-${CODEX_BACKUP_ROOT:-${HOME}/.codex-env-backups}}"
INSTALL_BACKUP_STAMP="${BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}"
INSTALL_BACKUP_DIR="${BACKUP_ROOT_EFFECTIVE}/${INSTALL_BACKUP_STAMP}"

# This must remain the first operational step. It is read-only and rejects
# contaminated templates, untracked tool payloads, conflict copies, symlinks,
# and incomplete Git working trees before anything is written locally.
bash "${REPO_ROOT}/scripts/install-automation-tools.sh" --preflight

# A full local snapshot is mandatory before any installation write.
BACKUP_ROOT="${BACKUP_ROOT_EFFECTIVE}" BACKUP_STAMP="${INSTALL_BACKUP_STAMP}" \
  bash "${REPO_ROOT}/scripts/backup-current.sh"

# Portable helpers live outside ~/.codex/automations. The helper installer
# repeats preflight and deploys only Git-tracked, marker-approved files.
bash "${REPO_ROOT}/scripts/install-automation-tools.sh" --install

mkdir -p "${CODEX_HOME}/skills"
mkdir -p "${CODEX_HOME}/rules"
mkdir -p "${AGENTS_HOME}/skills"
mkdir -p "${CODEX_HOME}/automation-templates"

assert_no_symlink_components() {
  checked_path="$1"
  case "${checked_path}" in
    /*)
      current_path="/"
      ;;
    *)
      current_path=""
      ;;
  esac
  local IFS='/'
  local path_components=()
  local path_component
  read -r -a path_components <<< "${checked_path}"
  for path_component in "${path_components[@]}"; do
    [ -n "${path_component}" ] || continue
    if [ "${current_path}" = "/" ]; then
      current_path="/${path_component}"
    elif [ -n "${current_path}" ]; then
      current_path="${current_path}/${path_component}"
    else
      current_path="${path_component}"
    fi
    if [ -L "${current_path}" ]; then
      echo "ERROR: destination symlink appeared after preflight: ${current_path}" >&2
      exit 1
    fi
  done
}

atomic_install_file() {
  source_path="$1"
  destination_path="$2"

  if [ ! -f "${source_path}" ] || [ -L "${source_path}" ]; then
    echo "ERROR: tracked install source is missing, non-regular, or a symlink: ${source_path}" >&2
    exit 1
  fi
  assert_no_symlink_components "${destination_path}"
  if [ -e "${destination_path}" ] && [ ! -f "${destination_path}" ]; then
    echo "ERROR: tracked install destination is not a regular file: ${destination_path}" >&2
    exit 1
  fi

  # Most cross-Mac applies touch only a handful of files. Avoid replacing
  # hundreds of identical skill files, which needlessly wakes iCloud and can
  # turn a small rules update into a multi-minute install.
  if [ -f "${destination_path}" ] && cmp -s "${source_path}" "${destination_path}"; then
    if { [ -x "${source_path}" ] && [ -x "${destination_path}" ]; } || \
      { [ ! -x "${source_path}" ] && [ ! -x "${destination_path}" ]; }; then
      return 0
    fi
  fi

  destination_parent="$(dirname "${destination_path}")"
  mkdir -p "${destination_parent}"
  assert_no_symlink_components "${destination_parent}"
  temp_path="${destination_parent}/.$(basename "${destination_path}").codex-sync.$$"
  if [ -e "${temp_path}" ] || [ -L "${temp_path}" ]; then
    echo "ERROR: temporary install path already exists: ${temp_path}" >&2
    exit 1
  fi
  cp -p "${source_path}" "${temp_path}"
  mv -f "${temp_path}" "${destination_path}"
}

install_tracked_tree() {
  repo_prefix="$1"
  destination_root="$2"
  skip_system="${3:-0}"
  installed=0

  while IFS= read -r -d '' tracked_path; do
    relative_path="${tracked_path#${repo_prefix}/}"
    if [ "${relative_path}" = "${tracked_path}" ]; then
      continue
    fi
    if [ "$(basename "${relative_path}")" = ".DS_Store" ]; then
      continue
    fi
    if [ "${skip_system}" = "1" ]; then
      case "${relative_path}" in
        .system|.system/*)
          continue
          ;;
      esac
    fi

    atomic_install_file "${REPO_ROOT}/${tracked_path}" \
      "${destination_root}/${relative_path}"
    installed=$((installed + 1))
  done < <(git -C "${REPO_ROOT}" ls-files -z -- "${repo_prefix}")

  echo "Installed ${repo_prefix}: ${installed} Git-tracked file(s)."
}

if git -C "${REPO_ROOT}" ls-files --error-unmatch -- AGENTS.md >/dev/null 2>&1; then
  atomic_install_file "${REPO_ROOT}/AGENTS.md" "${CODEX_HOME}/AGENTS.md"
fi

install_tracked_tree rules "${CODEX_HOME}/rules" 0
install_tracked_tree skills "${CODEX_HOME}/skills" 1
install_tracked_tree agents-skills "${AGENTS_HOME}/skills" 0

# This is a read-only local cache of shared definitions. It never activates,
# pauses, retargets, or otherwise mutates the host's live schedule registry.
install_tracked_tree automations-templates "${CODEX_HOME}/automation-templates" 0

# Prove that this install transaction did not change the per-Mac schedule
# state. The same exact backup is also the required baseline for any later
# automation-tool reconciliation in this apply session.
POST_INSTALL_BASELINE_REPORT="${INSTALL_BACKUP_DIR}/POST-INSTALL-HOST-STATE.txt"
if [ -d "${INSTALL_BACKUP_DIR}/automations-host-state" ]; then
  if ! python3 "${REPO_ROOT}/scripts/verify-automation-backup-consistency.py" \
      --compare-baseline "${INSTALL_BACKUP_DIR}" \
      "${CODEX_HOME}/automations" "${CODEX_HOME}/sqlite/codex-dev.db" \
      "${REPO_ROOT}/automations-templates" \
      > "${POST_INSTALL_BASELINE_REPORT}" 2>&1; then
    cat "${POST_INSTALL_BASELINE_REPORT}" >&2
    echo "ERROR: post-install host-state differs from the pre-install baseline." >&2
    exit 1
  fi
else
  printf 'BASELINE_NOT_REQUIRED\tfresh_empty\n' > "${POST_INSTALL_BASELINE_REPORT}"
fi

echo "Installed Codex guidance, command rules, and skills from ${REPO_ROOT}"
echo "Installed approved portable automation tools under ${CODEX_HOME}/automation-tools."
echo "Copied shared automation definitions without changing local switches or targets."
echo "Verified post-install host state against: ${INSTALL_BACKUP_DIR}"
echo "Preserved Codex system skills under ${CODEX_HOME}/skills/.system when present."
echo "Before closing this apply, run:"
echo "${REPO_ROOT}/scripts/audit-automation-sync.sh --strict --baseline-backup ${INSTALL_BACKUP_DIR}"
echo "Restart Codex if the skill list does not refresh immediately."
echo "For Obsidian MCP on this Mac, run: ${REPO_ROOT}/scripts/setup-obsidian-mcp.sh"
