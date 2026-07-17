#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
TOOLS_SOURCE="${REPO_ROOT}/automation-tools"
TOOLS_TARGET="${CODEX_HOME}/automation-tools"
TEMPLATES_ROOT="${REPO_ROOT}/automations-templates"
DB_PATH="${CODEX_HOME}/sqlite/codex-dev.db"
ERRORS=0
GIT_OK=1
TEMPLATE_IDS=""
TEMPLATE_NAMES=""
PYTHON_TOML_OK=1
AUTOMATION_DB_AVAILABLE=0

record_error() {
  echo "ERROR: $*" >&2
  ERRORS=$((ERRORS + 1))
}

list_contains() {
  list="$1"
  value="$2"
  [ -n "${list}" ] && printf '%s\n' "${list}" | grep -Fqx -- "${value}"
}

append_list() {
  list="$1"
  value="$2"
  if [ -z "${list}" ]; then
    printf '%s' "${value}"
  else
    printf '%s\n%s' "${list}" "${value}"
  fi
}

path_has_symlink_component() {
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
      return 0
    fi
  done
  return 1
}

runtime_path_forbidden() {
  path="$1"
  local IFS='/'
  local components=()
  local component
  read -r -a components <<< "${path}"
  for component in "${components[@]}"; do
    case "${component}" in
      automation.toml|memory.md|last-run.md|last-close.md|manual-resolutions.json|runs|reports|snapshots|backups|logs|cache|caches|sessions|*.log)
        return 0
        ;;
    esac
  done
  return 1
}

if ! git -C "${REPO_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  record_error "repository metadata is unavailable at ${REPO_ROOT}"
  GIT_OK=0
fi

if ! command -v python3 >/dev/null 2>&1 || \
  ! python3 -c 'import tomllib' >/dev/null 2>&1; then
  record_error "python3 with tomllib is required for fail-closed template validation"
  PYTHON_TOML_OK=0
fi

if path_has_symlink_component "${CODEX_HOME}"; then
  record_error "CODEX_HOME contains a symlink component: ${CODEX_HOME}"
fi
for protected_path in "${CODEX_HOME}/automations" "${CODEX_HOME}/sqlite" \
  "${DB_PATH}"; do
  if path_has_symlink_component "${protected_path}"; then
    record_error "automation state path contains a symlink component: ${protected_path}"
  fi
done

LIVE_CONFIG_COUNT=0
if [ -d "${CODEX_HOME}/automations" ]; then
  LIVE_CONFIG_COUNT="$(find "${CODEX_HOME}/automations" -mindepth 2 -maxdepth 2 \
    -name automation.toml -type f -print | wc -l | tr -d '[:space:]')"
fi
if [ -e "${DB_PATH}" ] || [ "${LIVE_CONFIG_COUNT}" -gt 0 ]; then
  if [ ! -f "${DB_PATH}" ] || [ -L "${DB_PATH}" ]; then
    record_error "automation registry is missing or unsafe while live schedules exist: ${DB_PATH}"
  elif ! command -v sqlite3 >/dev/null 2>&1; then
    record_error "sqlite3 is required to verify all live schedule ids before tool installation"
  elif ! sqlite3 -readonly "${DB_PATH}" \
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name='automations';" \
    2>/dev/null | grep -Fxq 1; then
    record_error "automation registry table is unavailable: ${DB_PATH}"
  else
    AUTOMATION_DB_AVAILABLE=1
  fi
fi
if path_has_symlink_component "${AGENTS_HOME:-${HOME}/.agents}"; then
  record_error "AGENTS_HOME contains a symlink component: ${AGENTS_HOME:-${HOME}/.agents}"
fi

# Finder/iCloud conflict copies are never an install source. New, intentionally
# untracked skills remain allowed for publish review, but ambiguous duplicate
# basenames fail the apply preflight before anything reaches the live machine.
for managed_root in AGENTS.md rules skills agents-skills automations-templates automation-tools scripts tests; do
  managed_path="${REPO_ROOT}/${managed_root}"
  [ -e "${managed_path}" ] || [ -L "${managed_path}" ] || continue
  if [ -d "${managed_path}" ] && [ ! -L "${managed_path}" ]; then
    while IFS= read -r -d '' conflict_path; do
      conflict_name="$(basename "${conflict_path}")"
      case "${conflict_name}" in
        *" 2."*|*" 2"|*"conflicted copy"*|*"Conflicted Copy"*|*"conflicted-copy"*)
          record_error "conflict-copy file is forbidden in sync-managed paths: ${conflict_path}"
          ;;
      esac
    done < <(find "${managed_path}" -mindepth 1 -print0)
  else
    conflict_name="$(basename "${managed_path}")"
    case "${conflict_name}" in
      *" 2."*|*" 2"|*"conflicted copy"*|*"Conflicted Copy"*|*"conflicted-copy"*)
        record_error "conflict-copy file is forbidden in sync-managed paths: ${managed_path}"
        ;;
    esac
  fi
done

# Catch root-level macOS/iCloud conflict copies such as "AGENTS 2.md". The
# managed-subtree scan above cannot see siblings of the canonical root files.
while IFS= read -r -d '' root_conflict_path; do
  root_conflict_name="$(basename "${root_conflict_path}")"
  case "${root_conflict_name}" in
    *" 2."*|*" 2"|*"conflicted copy"*|*"Conflicted Copy"*|*"conflicted-copy"*)
      record_error "conflict-copy file is forbidden at repository root: ${root_conflict_path}"
      ;;
  esac
done < <(find "${REPO_ROOT}" -mindepth 1 -maxdepth 1 ! -name .git -print0)

validate_tracked_install_tree() {
  repo_prefix="$1"
  destination_root="$2"
  skip_system="${3:-0}"

  if [ -L "${destination_root}" ]; then
    record_error "tracked install destination root is a symlink: ${destination_root}"
  elif [ -e "${destination_root}" ] && [ ! -d "${destination_root}" ]; then
    record_error "tracked install destination root is not a directory: ${destination_root}"
  elif [ -d "${destination_root}" ]; then
    while IFS= read -r -d '' destination_link; do
      case "${destination_link}" in
        "${destination_root}/.system"|"${destination_root}/.system/"*)
          if [ "${skip_system}" = "1" ]; then
            continue
          fi
          ;;
      esac
      record_error "symlink is forbidden in tracked install destination: ${destination_link}"
    done < <(find "${destination_root}" -type l -print0)
  fi

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

    source_path="${REPO_ROOT}/${tracked_path}"
    destination_path="${destination_root}/${relative_path}"
    if [ ! -f "${source_path}" ] || [ -L "${source_path}" ]; then
      record_error "tracked install source is missing, non-regular, or a symlink: ${source_path}"
    fi
    if path_has_symlink_component "${destination_path}"; then
      record_error "tracked install destination contains a symlink component: ${destination_path}"
    elif [ -e "${destination_path}" ] && [ ! -f "${destination_path}" ]; then
      record_error "tracked install destination is not a regular file: ${destination_path}"
    fi
  done < <(git -C "${REPO_ROOT}" ls-files -z -- "${repo_prefix}")
}

if [ "${GIT_OK}" -eq 1 ]; then
  validate_tracked_install_tree rules "${CODEX_HOME}/rules" 0
  validate_tracked_install_tree skills "${CODEX_HOME}/skills" 1
  validate_tracked_install_tree agents-skills "${AGENTS_HOME:-${HOME}/.agents}/skills" 0
  validate_tracked_install_tree automations-templates "${CODEX_HOME}/automation-templates" 0

  if git -C "${REPO_ROOT}" ls-files --error-unmatch -- AGENTS.md >/dev/null 2>&1; then
    if [ ! -f "${REPO_ROOT}/AGENTS.md" ] || [ -L "${REPO_ROOT}/AGENTS.md" ]; then
      record_error "tracked AGENTS.md is missing, non-regular, or a symlink"
    fi
    if path_has_symlink_component "${CODEX_HOME}/AGENTS.md"; then
      record_error "AGENTS.md destination contains a symlink component: ${CODEX_HOME}/AGENTS.md"
    elif [ -e "${CODEX_HOME}/AGENTS.md" ] && [ ! -f "${CODEX_HOME}/AGENTS.md" ]; then
      record_error "AGENTS.md destination is not a regular file: ${CODEX_HOME}/AGENTS.md"
    fi
  fi
fi

# The template tree is deliberately tiny and closed. Conflict copies such as
# "automation 2.toml" must never become an alternate source of truth.
if [ ! -d "${TEMPLATES_ROOT}" ] || [ -L "${TEMPLATES_ROOT}" ]; then
  record_error "automations-templates must be a real directory: ${TEMPLATES_ROOT}"
else
  while IFS= read -r -d '' root_entry; do
    root_name="$(basename "${root_entry}")"
    if [ "${root_name}" = "README.md" ] && [ -f "${root_entry}" ] && [ ! -L "${root_entry}" ]; then
      continue
    fi
    if [ -d "${root_entry}" ] && [ ! -L "${root_entry}" ]; then
      case "${root_name}" in
        .*)
          record_error "hidden template directory is forbidden: ${root_entry}"
          ;;
        *)
          continue
          ;;
      esac
    fi
    record_error "unsupported entry at automations-templates root: ${root_entry}"
  done < <(find "${TEMPLATES_ROOT}" -mindepth 1 -maxdepth 1 -print0)

  for template_dir in "${TEMPLATES_ROOT}"/*; do
    [ -d "${template_dir}" ] || continue
    template_directory="$(basename "${template_dir}")"
    template="${template_dir}/automation.toml"

    while IFS= read -r -d '' template_entry; do
      if [ "${template_entry}" = "${template}" ] && [ -f "${template_entry}" ] && [ ! -L "${template_entry}" ]; then
        continue
      fi
      record_error "template directory may contain only automation.toml: ${template_entry}"
    done < <(find "${template_dir}" -mindepth 1 -print0)

    if [ ! -f "${template}" ] || [ -L "${template}" ]; then
      record_error "template directory has no regular automation.toml: ${template_dir}"
      continue
    fi

    if [ "${GIT_OK}" -eq 1 ] && ! git -C "${REPO_ROOT}" ls-files --error-unmatch -- \
      "automations-templates/${template_directory}/automation.toml" >/dev/null 2>&1; then
      record_error "shared template is not Git-tracked: ${template}"
    fi

    template_id=""
    template_name=""
    if [ "${PYTHON_TOML_OK}" -eq 1 ]; then
      if parsed_template="$(python3 - "${template}" <<'PY'
from pathlib import Path
import sys
import tomllib

path = Path(sys.argv[1])
try:
    data = tomllib.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    raise SystemExit(f"invalid TOML: {exc}")

required = {
    "version": int,
    "id": str,
    "kind": str,
    "name": str,
    "prompt": str,
    "rrule": str,
    "model": str,
    "reasoning_effort": str,
    "execution_environment": str,
}
if set(data) != set(required):
    missing = sorted(set(required) - set(data))
    extra = sorted(set(data) - set(required))
    raise SystemExit(f"top-level keys mismatch: missing={missing}, extra={extra}")
for key, expected_type in required.items():
    value = data[key]
    if type(value) is not expected_type:
        raise SystemExit(
            f"wrong type for {key}: expected {expected_type.__name__}, "
            f"got {type(value).__name__}"
        )
    if expected_type is str and not value:
        raise SystemExit(f"empty string is forbidden for {key}")
if "\n" in data["id"] or "\n" in data["name"]:
    raise SystemExit("id and name must be single-line strings")
print(data["id"])
print(data["name"])
PY
)"; then
        template_id="$(printf '%s\n' "${parsed_template}" | sed -n '1p')"
        template_name="$(printf '%s\n' "${parsed_template}" | sed -n '2p')"
      else
        record_error "shared template failed TOML parse/type validation: ${template}: ${parsed_template}"
        continue
      fi
    else
      continue
    fi

    if [ -z "${template_id}" ]; then
      record_error "shared template has no parseable id: ${template}"
    else
      case "${template_id}" in
        *[!A-Za-z0-9._-]*)
          record_error "shared template id contains unsafe characters '${template_id}': ${template}"
          ;;
      esac
      if [ "${template_directory}" != "${template_id}" ]; then
        record_error "shared template directory '${template_directory}' does not match TOML id '${template_id}': ${template}"
      fi
      if list_contains "${TEMPLATE_IDS}" "${template_id}"; then
        record_error "duplicate shared template id '${template_id}': ${template}"
      else
        TEMPLATE_IDS="$(append_list "${TEMPLATE_IDS}" "${template_id}")"
      fi
    fi

    if [ -z "${template_name}" ]; then
      record_error "shared template has no parseable name: ${template}"
    elif list_contains "${TEMPLATE_NAMES}" "${template_name}"; then
      record_error "duplicate shared template name '${template_name}': ${template}"
    else
      TEMPLATE_NAMES="$(append_list "${TEMPLATE_NAMES}" "${template_name}")"
    fi

    line_number=0
    while IFS= read -r template_line || [ -n "${template_line}" ]; do
      line_number=$((line_number + 1))
      case "${template_line}" in
        ''|[[:space:]]\#*)
          continue
          ;;
      esac
      if ! [[ "${template_line}" =~ ^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*= ]]; then
        record_error "unsupported TOML syntax at ${template}:${line_number}; only simple top-level assignments are allowed"
      fi
    done < "${template}"

    template_keys="$(sed -E -n 's/^[[:space:]]*([A-Za-z0-9_-]+)[[:space:]]*=.*/\1/p' "${template}")"
    while IFS= read -r template_key; do
      [ -n "${template_key}" ] || continue
      case "${template_key}" in
        version|id|kind|name|prompt|rrule|model|reasoning_effort|execution_environment)
          ;;
        *)
          record_error "shared template contains unsupported top-level key '${template_key}': ${template}"
          ;;
      esac
    done <<EOF
${template_keys}
EOF

    for required_key in version id kind name prompt rrule model reasoning_effort execution_environment; do
      required_count="$(printf '%s\n' "${template_keys}" | grep -Fxc -- "${required_key}" || true)"
      if [ "${required_count}" -ne 1 ]; then
        record_error "shared template must contain '${required_key}' exactly once: ${template}"
      fi
    done
  done
fi

if [ -d "${TOOLS_SOURCE}" ] && [ "${GIT_OK}" -eq 1 ]; then
  while IFS= read -r -d '' source_link; do
    record_error "symlink is forbidden in automation-tools source: ${source_link}"
  done < <(find "${TOOLS_SOURCE}" -type l -print0)

  # Every filesystem payload must be tracked. This catches nested conflict files,
  # empty ghost directories, and a local file that Git pull would not control.
  while IFS= read -r -d '' source_entry; do
    relative_entry="${source_entry#${REPO_ROOT}/}"
    entry_name="$(basename "${source_entry}")"
    if [ "${entry_name}" = ".DS_Store" ]; then
      continue
    fi
    if runtime_path_forbidden "${relative_entry#automation-tools/}"; then
      record_error "runtime path is forbidden anywhere in portable source: ${relative_entry}"
    fi
    if [ -d "${source_entry}" ] && [ ! -L "${source_entry}" ]; then
      tracked_under="$(git -C "${REPO_ROOT}" ls-files -- "${relative_entry}" | wc -l | tr -d '[:space:]')"
      if [ "${tracked_under}" -eq 0 ]; then
        record_error "untracked or empty automation-tools directory: ${relative_entry}"
      fi
    elif ! git -C "${REPO_ROOT}" ls-files --error-unmatch -- "${relative_entry}" >/dev/null 2>&1; then
      record_error "untracked automation-tools payload: ${relative_entry}"
    fi
  done < <(find "${TOOLS_SOURCE}" -mindepth 1 -print0)

  # Git's index can still name a file deleted from the working tree. Reject it
  # explicitly so installation never produces a partial tool version.
  while IFS= read -r -d '' tracked_path; do
    source_path="${REPO_ROOT}/${tracked_path}"
    if [ ! -e "${source_path}" ] && [ ! -L "${source_path}" ]; then
      record_error "Git-tracked automation-tools payload is missing from the working tree: ${tracked_path}"
      continue
    fi
    if [ -L "${source_path}" ]; then
      record_error "Git-tracked symlink is forbidden in automation-tools: ${tracked_path}"
    fi
    if [ "$(basename "${tracked_path}")" = ".DS_Store" ]; then
      record_error "tracked .DS_Store is forbidden in automation-tools: ${tracked_path}"
    fi
    if runtime_path_forbidden "${tracked_path#automation-tools/}"; then
      record_error "Git-tracked runtime path is forbidden in automation-tools: ${tracked_path}"
    fi
  done < <(git -C "${REPO_ROOT}" ls-files -z -- automation-tools)

  for tool_dir in "${TOOLS_SOURCE}"/*; do
    [ -d "${tool_dir}" ] || continue
    name="$(basename "${tool_dir}")"
    case "${name}" in
      *[!A-Za-z0-9._-]*)
        record_error "portable tool directory contains unsafe characters: ${name}"
        ;;
    esac
    relative="automation-tools/${name}"
    tracked_count="$(git -C "${REPO_ROOT}" ls-files -- "${relative}" | wc -l | tr -d '[:space:]')"

    if [ "${tracked_count}" -eq 0 ]; then
      record_error "untracked automation-tools directory: ${relative}"
      continue
    fi

    if [ ! -f "${tool_dir}/.portable-tool" ] || [ -L "${tool_dir}/.portable-tool" ]; then
      record_error "portable tool marker is missing or unsafe: ${relative}/.portable-tool"
    elif ! git -C "${REPO_ROOT}" ls-files --error-unmatch -- \
      "${relative}/.portable-tool" >/dev/null 2>&1; then
      record_error "portable tool marker is not Git-tracked: ${relative}/.portable-tool"
    fi

    if list_contains "${TEMPLATE_IDS}" "${name}"; then
      record_error "portable tool name collides with a shared template id: ${name}"
    fi

    # A local-only or legacy schedule may not exist in the shared templates.
    # Check both live TOML and the registry before any tool payload is written.
    live_schedule_config="${CODEX_HOME}/automations/${name}/automation.toml"
    if [ -e "${live_schedule_config}" ] || [ -L "${live_schedule_config}" ]; then
      record_error "portable tool name collides with a live schedule id: ${name}"
    fi
    if [ "${AUTOMATION_DB_AVAILABLE}" -eq 1 ] && \
      sqlite3 -readonly "${DB_PATH}" \
        "SELECT 1 FROM automations WHERE id='${name}' LIMIT 1;" 2>/dev/null | \
        grep -Fxq 1; then
      record_error "portable tool name collides with a registry schedule id: ${name}"
    fi
  done
fi

# Portable code is installed outside the live schedule tree. Refuse any existing
# destination symlink so a path cannot escape back into automations or elsewhere.
if [ -L "${TOOLS_TARGET}" ]; then
  record_error "portable tool destination root is a symlink: ${TOOLS_TARGET}"
elif [ -e "${TOOLS_TARGET}" ] && [ ! -d "${TOOLS_TARGET}" ]; then
  record_error "portable tool destination root is not a directory: ${TOOLS_TARGET}"
elif [ -d "${TOOLS_TARGET}" ]; then
  while IFS= read -r -d '' destination_link; do
    record_error "symlink is forbidden in portable tool destination: ${destination_link}"
  done < <(find "${TOOLS_TARGET}" -type l -print0)
fi

if [ "${ERRORS}" -ne 0 ]; then
  echo "Sync layout validation failed with ${ERRORS} error(s). No installation is safe." >&2
  exit 1
fi

echo "Sync layout validation passed."
