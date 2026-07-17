#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
TOOLS_TARGET="${CODEX_HOME}/automation-tools"
MODE="${1:---install}"

case "${MODE}" in
  --preflight|--install)
    ;;
  *)
    echo "Usage: $0 [--preflight|--install]" >&2
    exit 2
    ;;
esac

# Always validate the complete source and every existing destination path before
# creating a directory or copying a byte.
bash "${REPO_ROOT}/scripts/validate-sync-layout.sh"

if [ "${MODE}" = "--preflight" ]; then
  echo "Portable automation tool preflight passed."
  exit 0
fi

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

assert_destination_safe() {
  relative_path="$1"
  current="${TOOLS_TARGET}"
  if [ -L "${current}" ]; then
    echo "ERROR: destination symlink appeared after preflight: ${current}" >&2
    exit 1
  fi
  [ -n "${relative_path}" ] || return 0

  local IFS='/'
  local components=()
  local component
  read -r -a components <<< "${relative_path}"
  for component in "${components[@]}"; do
    [ -n "${component}" ] || continue
    case "${component}" in
      .|..)
        echo "ERROR: unsafe destination path component: ${relative_path}" >&2
        exit 1
        ;;
    esac
    current="${current}/${component}"
    if [ -L "${current}" ]; then
      echo "ERROR: destination symlink appeared after preflight: ${current}" >&2
      exit 1
    fi
  done
}

assert_absolute_target_root_safe() {
  checked_path="${TOOLS_TARGET}"
  current_path="/"
  local IFS='/'
  local components=()
  local component
  read -r -a components <<< "${checked_path}"
  for component in "${components[@]}"; do
    [ -n "${component}" ] || continue
    current_path="${current_path%/}/${component}"
    if [ -L "${current_path}" ]; then
      echo "ERROR: portable tool destination root contains a symlink component: ${current_path}" >&2
      exit 1
    fi
  done
}

atomic_copy() {
  source_path="$1"
  destination_path="$2"
  destination_relative="$3"
  assert_destination_safe "${destination_relative}"
  destination_parent="$(dirname "${destination_path}")"
  mkdir -p "${destination_parent}"
  assert_destination_safe "$(dirname "${destination_relative}")"

  if [ -e "${destination_path}" ] && [ ! -f "${destination_path}" ]; then
    echo "ERROR: destination payload is not a regular file: ${destination_path}" >&2
    exit 1
  fi

  temp_path="${destination_parent}/.$(basename "${destination_path}").codex-sync.$$"
  if [ -e "${temp_path}" ] || [ -L "${temp_path}" ]; then
    echo "ERROR: temporary install path already exists: ${temp_path}" >&2
    exit 1
  fi
  cp -p "${source_path}" "${temp_path}"
  mv -f "${temp_path}" "${destination_path}"
}

assert_absolute_target_root_safe
mkdir -p "${TOOLS_TARGET}"
assert_absolute_target_root_safe
assert_destination_safe ""

for tool_dir in "${REPO_ROOT}"/automation-tools/*; do
  [ -d "${tool_dir}" ] || continue
  name="$(basename "${tool_dir}")"
  relative="automation-tools/${name}"
  target="${TOOLS_TARGET}/${name}"
  deployed=0

  assert_destination_safe "${name}"
  mkdir -p "${target}"

  while IFS= read -r -d '' tracked_path; do
    payload_path="${tracked_path#${relative}/}"
    if [ "${payload_path}" = "${tracked_path}" ]; then
      continue
    fi
    if [ "$(basename "${payload_path}")" = ".DS_Store" ]; then
      echo "ERROR: tracked .DS_Store reached installer despite preflight: ${tracked_path}" >&2
      exit 1
    fi
    if runtime_path_forbidden "${payload_path}"; then
      echo "ERROR: runtime path reached installer despite preflight: ${tracked_path}" >&2
      exit 1
    fi

    source_path="${REPO_ROOT}/${tracked_path}"
    if [ ! -f "${source_path}" ] || [ -L "${source_path}" ]; then
      echo "ERROR: source payload became missing or unsafe after preflight: ${source_path}" >&2
      exit 1
    fi

    destination_path="${target}/${payload_path}"
    atomic_copy "${source_path}" "${destination_path}" "${name}/${payload_path}"
    deployed=$((deployed + 1))
  done < <(git -C "${REPO_ROOT}" ls-files -z -- "${relative}")

  # Seeds are portable inputs only. Reconcile must explicitly map a seed into a
  # schedule runtime with seed-automation-runtime-missing-only.sh; the generic
  # installer never invents or overwrites runtime state.
  echo "Installed portable tool ${name}: ${deployed} tracked file(s); no runtime seed was applied."
done
