#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
MODE="--report"
BASELINE_BACKUP=""
DB_PATH="${CODEX_HOME}/sqlite/codex-dev.db"
DB_AVAILABLE=0
ISSUES=0
TEMPLATE_IDS=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --report|--strict)
      MODE="$1"
      shift
      ;;
    --baseline-backup)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "--baseline-backup requires an exact backup directory" >&2
        exit 2
      fi
      BASELINE_BACKUP="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--report|--strict] [--baseline-backup <backup-dir>]" >&2
      exit 2
      ;;
  esac
done

toml_string() {
  key="$1"
  file="$2"
  sed -E -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\\1/p" "${file}" | head -n 1
}

toml_rhs() {
  key="$1"
  file="$2"
  sed -E -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*(.*)$/\\1/p" "${file}" | head -n 1
}

local_project_scope() {
  file="$1"
  project_id="$(toml_string project_id "${file}")"
  if [ -z "${project_id}" ]; then
    project_id="$(toml_string projectId "${file}")"
  fi
  if [ -n "${project_id}" ]; then
    printf '%s\n' "${project_id}"
    return
  fi

  target_rhs="$(toml_rhs target "${file}")"
  inline_project_id="$(printf '%s\n' "${target_rhs}" | sed -E -n 's/.*(project_id|projectId)[[:space:]]*=[[:space:]]*"([^"]*)".*/\2/p')"
  if [ -n "${inline_project_id}" ]; then
    printf '%s\n' "${inline_project_id}"
  elif [ -n "${target_rhs}" ]; then
    printf '%s\n' "${target_rhs}" | sed -E 's/^"(.*)"$/\1/'
  fi
}

list_contains() {
  list="$1"
  value="$2"
  [ -n "${list}" ] && printf '%s\n' "${list}" | grep -Fqx -- "${value}"
}

append_unique() {
  list="$1"
  value="$2"
  if list_contains "${list}" "${value}"; then
    printf '%s' "${list}"
  elif [ -z "${list}" ]; then
    printf '%s' "${value}"
  else
    printf '%s\n%s' "${list}" "${value}"
  fi
}

sql_quote() {
  printf '%s' "$1" | sed "s/'/''/g"
}

db_row_for_id() {
  schedule_id="$(sql_quote "$1")"
  sqlite3 -readonly -separator $'\x1f' "${DB_PATH}" \
    "SELECT status,coalesce(project_id,''),cwds,name FROM automations WHERE id='${schedule_id}' LIMIT 1;"
}

identity_candidates() {
  template_path="$1"
  python3 - "${template_path}" "${CODEX_HOME}/automations" \
    "${DB_PATH}" "${DB_AVAILABLE}" <<'PY'
from pathlib import Path
import sqlite3
import sys
import tomllib

template_path = Path(sys.argv[1])
live_root = Path(sys.argv[2])
db_path = Path(sys.argv[3])
db_available = sys.argv[4] == "1"

def load(path: Path):
    return tomllib.loads(path.read_text(encoding="utf-8"))

def normalize_prompt(value):
    if not isinstance(value, str):
        return ""
    value = value.replace("\r\n", "\n").replace("\r", "\n").strip()
    return "\n".join(line.rstrip() for line in value.split("\n"))

template = load(template_path)
template_name = template.get("name")
template_prompt = normalize_prompt(template.get("prompt"))
records = {}

for path in sorted(live_root.glob("*/automation.toml")):
    schedule_id = path.parent.name
    data = load(path)
    records.setdefault(schedule_id, []).append(data)

if db_available:
    connection = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    for row in connection.execute(
        "SELECT id,name,prompt FROM automations ORDER BY id"
    ):
        records.setdefault(row["id"], []).append(dict(row))

for schedule_id in sorted(records):
    if any(character in schedule_id for character in ("\t", "\n", "\r")):
        raise SystemExit(f"unsafe local automation id: {schedule_id!r}")
    name_match = any(data.get("name") == template_name for data in records[schedule_id])
    prompt_match = bool(template_prompt) and any(
        normalize_prompt(data.get("prompt")) == template_prompt
        for data in records[schedule_id]
    )
    if name_match or prompt_match:
        reason = "both" if name_match and prompt_match else (
            "name" if name_match else "prompt"
        )
        print(f"{schedule_id}\t{reason}")
PY
}

bash "${REPO_ROOT}/scripts/validate-sync-layout.sh"

if command -v sqlite3 >/dev/null 2>&1 && [ -f "${DB_PATH}" ] && \
  sqlite3 -readonly "${DB_PATH}" \
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name='automations';" 2>/dev/null | grep -Fxq 1; then
  DB_AVAILABLE=1
fi

echo "Automation sync audit"
echo "Shared definitions: ${REPO_ROOT}/automations-templates"
echo "Local host state: ${CODEX_HOME}/automations"
if [ "${DB_AVAILABLE}" -eq 1 ]; then
  echo "Registry: ${DB_PATH} (read-only verification enabled)"
else
  echo "REGISTRY_UNAVAILABLE\t${DB_PATH}\tstrict verification cannot complete"
  ISSUES=$((ISSUES + 1))
fi

for template in "${REPO_ROOT}"/automations-templates/*/automation.toml; do
  [ -e "${template}" ] || continue
  template_id="$(basename "$(dirname "${template}")")"
  template_name="$(toml_string name "${template}")"
  TEMPLATE_IDS="$(append_unique "${TEMPLATE_IDS}" "${template_id}")"
  live_config="${CODEX_HOME}/automations/${template_id}/automation.toml"
  file_exists=0
  db_exists=0
  db_status=""
  db_project=""
  db_cwds=""
  db_name=""

  if [ -f "${live_config}" ]; then
    file_exists=1
  fi
  if [ "${DB_AVAILABLE}" -eq 1 ]; then
    db_row="$(db_row_for_id "${template_id}")"
    if [ -n "${db_row}" ]; then
      db_exists=1
      IFS=$'\x1f' read -r db_status db_project db_cwds db_name <<< "${db_row}"
    fi
  fi

  candidate_rows="$(identity_candidates "${template}")"
  candidates="$(printf '%s\n' "${candidate_rows}" | sed '/^$/d' | cut -f1)"

  other_candidates=""
  while IFS= read -r candidate_id; do
    [ -n "${candidate_id}" ] || continue
    [ "${candidate_id}" = "${template_id}" ] && continue
    other_candidates="$(append_unique "${other_candidates}" "${candidate_id}")"
  done <<EOF
${candidates}
EOF

  if [ "${file_exists}" -eq 1 ] && [ "${DB_AVAILABLE}" -eq 1 ] && [ "${db_exists}" -eq 0 ]; then
    printf 'FILE_ONLY_REGISTRY_MISSING\t%s\tfile=%s\n' "${template_id}" "${live_config}"
    ISSUES=$((ISSUES + 1))
  elif [ "${file_exists}" -eq 0 ] && [ "${db_exists}" -eq 1 ]; then
    printf 'DB_ONLY_FILE_MISSING\t%s\tstatus=%s\ttarget=%s\n' \
      "${template_id}" "${db_status:-UNKNOWN}" "${db_project:-LOCAL}"
    ISSUES=$((ISSUES + 1))
  elif [ "${file_exists}" -eq 1 ]; then
    local_status="$(toml_string status "${live_config}")"
    local_target="$(local_project_scope "${live_config}")"
    local_cwds="$(toml_rhs cwds "${live_config}")"
    printf 'OK\t%s\tstatus=%s\ttarget=%s\n' \
      "${template_id}" "${local_status:-UNKNOWN}" "${local_target:-LOCAL}"

    if [ "${db_exists}" -eq 1 ]; then
      if [ "${local_status}" != "${db_status}" ]; then
        printf 'REGISTRY_STATUS_MISMATCH\t%s\tfile=%s\tdb=%s\n' \
          "${template_id}" "${local_status:-UNKNOWN}" "${db_status:-UNKNOWN}"
        ISSUES=$((ISSUES + 1))
      fi
      if [ -n "${local_target}" ] && [ -n "${db_project}" ] && \
        [ "${local_target}" != "${db_project}" ]; then
        printf 'REGISTRY_TARGET_MISMATCH\t%s\tfile=%s\tdb=%s\n' \
          "${template_id}" "${local_target}" "${db_project}"
        ISSUES=$((ISSUES + 1))
      fi
      if [ -n "${local_cwds}" ] && [ -n "${db_cwds}" ] && \
        [ "${local_cwds}" != "${db_cwds}" ]; then
        printf 'REGISTRY_CWDS_MISMATCH\t%s\tfile=%s\tdb=%s\n' \
          "${template_id}" "${local_cwds}" "${db_cwds}"
        ISSUES=$((ISSUES + 1))
      fi
    fi
  else
    candidate_count="$(printf '%s\n' "${other_candidates}" | sed '/^$/d' | wc -l | tr -d '[:space:]')"
    if [ "${candidate_count}" -eq 1 ]; then
      legacy_reason="$(printf '%s\n' "${candidate_rows}" | \
        awk -F '\t' -v id="${other_candidates}" '$1 == id {print $2; exit}')"
      printf 'LEGACY_ALIAS\t%s\tlocal_id=%s\tmatch=%s\tpreserve local state; review before renaming\n' \
        "${template_id}" "${other_candidates}" "${legacy_reason:-unknown}"
    elif [ "${candidate_count}" -gt 1 ]; then
      printf 'AMBIGUOUS_LEGACY_ALIASES\t%s\tlocal_ids=%s\tdo not create a duplicate\n' \
        "${template_id}" "$(printf '%s' "${other_candidates}" | tr '\n' ',')"
      ISSUES=$((ISSUES + 1))
    else
      printf 'MISSING_LOCAL\t%s\tcreate through the Codex automation tool as PAUSED unless host state is recovered\n' \
        "${template_id}"
      ISSUES=$((ISSUES + 1))
    fi
  fi

  if [ -n "${other_candidates}" ] && { [ "${file_exists}" -eq 1 ] || [ "${db_exists}" -eq 1 ]; }; then
    printf 'DUPLICATE_NAME_OR_PROMPT\t%s\tother_local_ids=%s\treview legacy duplicate\n' \
      "${template_id}" "$(printf '%s' "${other_candidates}" | tr '\n' ',')"
    ISSUES=$((ISSUES + 1))
  fi
done

# Audit every remaining local schedule, not only definitions that happen to be
# shared in Git. A local-only reminder can suffer the same DB/TOML split.
ALL_LOCAL_IDS=""
for local_config in "${CODEX_HOME}"/automations/*/automation.toml; do
  [ -f "${local_config}" ] || continue
  local_id="$(basename "$(dirname "${local_config}")")"
  ALL_LOCAL_IDS="$(append_unique "${ALL_LOCAL_IDS}" "${local_id}")"
done
if [ "${DB_AVAILABLE}" -eq 1 ]; then
  while IFS= read -r local_id; do
    [ -n "${local_id}" ] || continue
    ALL_LOCAL_IDS="$(append_unique "${ALL_LOCAL_IDS}" "${local_id}")"
  done < <(sqlite3 -readonly "${DB_PATH}" 'SELECT id FROM automations ORDER BY id;')
fi

while IFS= read -r local_id; do
  [ -n "${local_id}" ] || continue
  if list_contains "${TEMPLATE_IDS}" "${local_id}"; then
    continue
  fi

  local_config="${CODEX_HOME}/automations/${local_id}/automation.toml"
  file_exists=0
  db_exists=0
  db_status=""
  db_project=""
  db_cwds=""
  db_name=""
  [ -f "${local_config}" ] && file_exists=1

  if [ "${DB_AVAILABLE}" -eq 1 ]; then
    db_row="$(db_row_for_id "${local_id}")"
    if [ -n "${db_row}" ]; then
      db_exists=1
      IFS=$'\x1f' read -r db_status db_project db_cwds db_name <<< "${db_row}"
    fi
  fi

  if [ "${DB_AVAILABLE}" -eq 0 ]; then
    printf 'LOCAL_REGISTRY_UNVERIFIED\t%s\tfile=%s\n' "${local_id}" "${local_config}"
    ISSUES=$((ISSUES + 1))
    continue
  fi
  if [ "${file_exists}" -eq 1 ] && [ "${db_exists}" -eq 0 ]; then
    printf 'LOCAL_FILE_ONLY_REGISTRY_MISSING\t%s\tfile=%s\n' "${local_id}" "${local_config}"
    ISSUES=$((ISSUES + 1))
    continue
  fi
  if [ "${file_exists}" -eq 0 ] && [ "${db_exists}" -eq 1 ]; then
    printf 'LOCAL_DB_ONLY_FILE_MISSING\t%s\tstatus=%s\ttarget=%s\n' \
      "${local_id}" "${db_status:-UNKNOWN}" "${db_project:-LOCAL}"
    ISSUES=$((ISSUES + 1))
    continue
  fi

  local_status="$(toml_string status "${local_config}")"
  local_target="$(local_project_scope "${local_config}")"
  local_cwds="$(toml_rhs cwds "${local_config}")"
  printf 'LOCAL_ONLY_OK\t%s\tstatus=%s\ttarget=%s\n' \
    "${local_id}" "${local_status:-UNKNOWN}" "${local_target:-LOCAL}"
  if [ "${local_status}" != "${db_status}" ]; then
    printf 'LOCAL_REGISTRY_STATUS_MISMATCH\t%s\tfile=%s\tdb=%s\n' \
      "${local_id}" "${local_status:-UNKNOWN}" "${db_status:-UNKNOWN}"
    ISSUES=$((ISSUES + 1))
  fi
  if [ -n "${local_target}" ] && [ -n "${db_project}" ] && \
    [ "${local_target}" != "${db_project}" ]; then
    printf 'LOCAL_REGISTRY_TARGET_MISMATCH\t%s\tfile=%s\tdb=%s\n' \
      "${local_id}" "${local_target}" "${db_project}"
    ISSUES=$((ISSUES + 1))
  fi
  if [ -n "${local_cwds}" ] && [ -n "${db_cwds}" ] && \
    [ "${local_cwds}" != "${db_cwds}" ]; then
    printf 'LOCAL_REGISTRY_CWDS_MISMATCH\t%s\tfile=%s\tdb=%s\n' \
      "${local_id}" "${local_cwds}" "${db_cwds}"
    ISSUES=$((ISSUES + 1))
  fi
done <<EOF
${ALL_LOCAL_IDS}
EOF

# Exact semantic gate. The shell report above stays human-readable, while this
# parser-backed pass closes gaps caused by textual TOML formatting, empty target
# fields, or a DB row whose shared fields drifted from its live file/template.
if [ "${DB_AVAILABLE}" -eq 1 ]; then
  semantic_output="$(python3 - "${TEMPLATES_ROOT:-${REPO_ROOT}/automations-templates}" \
    "${CODEX_HOME}" "${DB_PATH}" <<'PY'
from __future__ import annotations

from pathlib import Path
import hashlib
import json
import sqlite3
import sys
import tomllib

templates_root = Path(sys.argv[1])
codex_home = Path(sys.argv[2])
db_path = Path(sys.argv[3])
issues: list[str] = []

def compact(value):
    if isinstance(value, str) and len(value) > 120:
        digest = hashlib.sha256(value.encode("utf-8")).hexdigest()[:16]
        return f"sha256:{digest}:chars={len(value)}"
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))

def normalize_prompt(value):
    if not isinstance(value, str):
        return ""
    value = value.replace("\r\n", "\n").replace("\r", "\n").strip()
    return "\n".join(line.rstrip() for line in value.split("\n"))

def load_toml(path: Path, label: str):
    try:
        return tomllib.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        issues.append(f"TOML_PARSE_ERROR\t{label}\tfile={path}\terror={exc}")
        return None

templates = {}
for path in sorted(templates_root.glob("*/automation.toml")):
    data = load_toml(path, f"template:{path.parent.name}")
    if data is not None:
        templates[str(data.get("id", path.parent.name))] = data

live = {}
live_paths = {}
for path in sorted((codex_home / "automations").glob("*/automation.toml")):
    directory_id = path.parent.name
    data = load_toml(path, f"live:{directory_id}")
    if data is not None:
        live[directory_id] = data
        live_paths[directory_id] = path
        if data.get("id") != directory_id:
            issues.append(
                "LIVE_ID_MISMATCH\t"
                f"{directory_id}\tfile_id={compact(data.get('id'))}\tfile={path}"
            )

con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
con.row_factory = sqlite3.Row
db_rows = {row["id"]: row for row in con.execute(
    "SELECT id,name,prompt,status,next_run_at,cwds,rrule,model,"
    "reasoning_effort,target_type,project_id,created_at,updated_at "
    "FROM automations ORDER BY id"
)}

for schedule_id in sorted(set(live) & set(db_rows)):
    data = live[schedule_id]
    row = db_rows[schedule_id]
    target = data.get("target") or {}
    if not isinstance(target, dict):
        issues.append(
            f"REGISTRY_FIELD_MISMATCH\t{schedule_id}\tfield=target\t"
            f"file={compact(target)}\tdb=object"
        )
        target = {}
    file_target_type = target.get("type", target.get("kind", "")) or ""
    file_project_id = target.get("project_id", target.get("projectId", "")) or ""
    try:
        db_cwds = json.loads(row["cwds"] or "[]")
    except Exception:
        db_cwds = row["cwds"]

    comparisons = {
        "status": (data.get("status", ""), row["status"] or ""),
        "target_type": (file_target_type, row["target_type"] or ""),
        "project_id": (file_project_id, row["project_id"] or ""),
        "cwds": (data.get("cwds", []), db_cwds),
        "name": (data.get("name", ""), row["name"] or ""),
        "prompt": (data.get("prompt", ""), row["prompt"] or ""),
        "rrule": (data.get("rrule", ""), row["rrule"] or ""),
        "model": (data.get("model", ""), row["model"] or ""),
        "reasoning_effort": (
            data.get("reasoning_effort", ""), row["reasoning_effort"] or ""
        ),
        "created_at": (data.get("created_at"), row["created_at"]),
        "updated_at": (data.get("updated_at"), row["updated_at"]),
    }
    for field, (file_value, db_value) in comparisons.items():
        if file_value != db_value:
            issues.append(
                f"REGISTRY_FIELD_MISMATCH\t{schedule_id}\tfield={field}\t"
                f"file={compact(file_value)}\tdb={compact(db_value)}"
            )
    if row["status"] == "ACTIVE" and row["next_run_at"] is None:
        issues.append(f"ACTIVE_NEXT_RUN_MISSING\t{schedule_id}")

shared_fields = (
    "version", "id", "kind", "name", "prompt", "rrule", "model",
    "reasoning_effort", "execution_environment",
)
for template_id, template in sorted(templates.items()):
    actual_id = template_id if template_id in live else None
    legacy = False
    if actual_id is None:
        template_prompt = normalize_prompt(template.get("prompt"))
        matches = [
            live_id for live_id, data in live.items()
            if data.get("name") == template.get("name") or (
                bool(template_prompt)
                and normalize_prompt(data.get("prompt")) == template_prompt
            )
        ]
        if len(matches) == 1:
            actual_id = matches[0]
            legacy = True
    if actual_id is None:
        continue
    data = live[actual_id]
    for field in shared_fields:
        if legacy and field == "id":
            continue
        if template.get(field) != data.get(field):
            issues.append(
                f"SHARED_FIELD_MISMATCH\t{template_id}\tlocal_id={actual_id}\t"
                f"field={field}\ttemplate={compact(template.get(field))}\t"
                f"live={compact(data.get(field))}"
            )

for issue in issues:
    print(issue)
print(f"__SEMANTIC_ISSUES__\t{len(issues)}")
PY
)"
  semantic_count="$(printf '%s\n' "${semantic_output}" | \
    sed -n 's/^__SEMANTIC_ISSUES__[[:space:]]*//p' | tail -n 1)"
  if ! [[ "${semantic_count}" =~ ^[0-9]+$ ]]; then
    printf 'SEMANTIC_AUDIT_ERROR\tunable to parse semantic audit result\n'
    ISSUES=$((ISSUES + 1))
  else
    printf '%s\n' "${semantic_output}" | sed '/^__SEMANTIC_ISSUES__[[:space:]]/d'
    ISSUES=$((ISSUES + semantic_count))
  fi
fi

# A current DB and live TOML can agree with each other after both were
# accidentally overwritten. Compare them with the exact pre-apply backup to
# protect this Mac's switch, routing, working directories, and timestamps.
if [ -n "${BASELINE_BACKUP}" ]; then
  baseline_status=0
  baseline_output="$(python3 \
    "${REPO_ROOT}/scripts/verify-automation-backup-consistency.py" \
    --compare-baseline "${BASELINE_BACKUP}" \
    "${CODEX_HOME}/automations" "${DB_PATH}" \
    "${REPO_ROOT}/automations-templates")" || baseline_status=$?
  printf '%s\n' "${baseline_output}"
  baseline_count="$(printf '%s\n' "${baseline_output}" | \
    sed -n 's/^__BASELINE_ISSUES__[[:space:]]*//p' | tail -n 1)"
  if [[ "${baseline_count}" =~ ^[0-9]+$ ]]; then
    ISSUES=$((ISSUES + baseline_count))
  elif [ "${baseline_status}" -ne 0 ]; then
    printf 'BASELINE_AUDIT_ERROR\tunable to parse baseline verifier result\n'
    ISSUES=$((ISSUES + 1))
  fi
fi

# Portable helpers used to be installed inside the live schedule namespace.
# Detect those legacy code directories so they can be reviewed/quarantined only
# after every schedule prompt points at the new, isolated automation-tools root.
for tool_dir in "${REPO_ROOT}"/automation-tools/*; do
  [ -d "${tool_dir}" ] || continue
  tool_name="$(basename "${tool_dir}")"
  legacy_dir="${CODEX_HOME}/automations/${tool_name}"
  [ -d "${legacy_dir}" ] || continue

  entry_count=0
  legacy_code_path=""
  while IFS= read -r legacy_entry; do
    [ -n "${legacy_entry}" ] || continue
    entry_count=$((entry_count + 1))
    legacy_name="$(basename "${legacy_entry}")"
    case "${legacy_name}" in
      memory.md|last-run.md|last-close.md|manual-resolutions.json|runs|reports|snapshots|backups|logs|cache|caches|sessions|*.log)
        ;;
      automation.toml)
        ;;
      *)
        legacy_code_path="${legacy_entry}"
        ;;
    esac
  done < <(find "${legacy_dir}" -mindepth 1 -maxdepth 1 -print)

  if [ -f "${legacy_dir}/automation.toml" ]; then
    printf 'LEGACY_TOOL_SCHEDULE_COLLISION\t%s\tpath=%s\treview before any quarantine\n' \
      "${tool_name}" "${legacy_dir}"
    ISSUES=$((ISSUES + 1))
  elif [ "${entry_count}" -eq 0 ]; then
    printf 'LEGACY_TOOL_EMPTY_GHOST\t%s\tpath=%s\tquarantine after backup\n' \
      "${tool_name}" "${legacy_dir}"
    ISSUES=$((ISSUES + 1))
  elif [ -n "${legacy_code_path}" ]; then
    printf 'LEGACY_TOOL_LOCATION\t%s\tpath=%s\tfirst_code_path=%s\tnew_path=%s\n' \
      "${tool_name}" "${legacy_dir}" "${legacy_code_path}" \
      "${CODEX_HOME}/automation-tools/${tool_name}"
    ISSUES=$((ISSUES + 1))
  fi
done

echo "Audit complete. This command made no changes. issues=${ISSUES}"
if [ "${MODE}" = "--strict" ] && [ "${ISSUES}" -ne 0 ]; then
  exit 1
fi
