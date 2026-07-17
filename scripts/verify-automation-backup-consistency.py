#!/usr/bin/env python3
"""Fail closed unless live TOML, captured TOML, and the registry agree."""

from __future__ import annotations

from pathlib import Path
import hashlib
import json
import sqlite3
import sys
import tomllib


def fail(message: str) -> None:
    print(f"ERROR\t{message}")


SHARED_FIELDS = (
    "version",
    "id",
    "kind",
    "name",
    "prompt",
    "rrule",
    "model",
    "reasoning_effort",
    "execution_environment",
)


def compact(value: object) -> str:
    rendered = json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    )
    if len(rendered) > 240:
        digest = hashlib.sha256(rendered.encode("utf-8")).hexdigest()[:16]
        return f"sha256:{digest}:chars={len(rendered)}"
    return rendered


def canonical_target(data: dict) -> dict:
    target = data.get("target") or {}
    if not isinstance(target, dict):
        return {"__invalid__": target}
    return {
        "type": target.get("type", target.get("kind", "")) or "",
        "project_id": target.get(
            "project_id", target.get("projectId", "")
        ) or "",
    }


def db_target(row: sqlite3.Row) -> dict:
    return {
        "type": row["target_type"] or "",
        "project_id": row["project_id"] or "",
    }


def parse_manifest(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"baseline manifest is missing or unsafe: {path}")
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


def load_db_host_rows(db_path: Path) -> dict[str, dict]:
    connection = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    try:
        result = {}
        for row in connection.execute(
            "SELECT id,status,cwds,target_type,project_id,created_at,updated_at "
            "FROM automations ORDER BY id"
        ):
            try:
                cwds = json.loads(row["cwds"] or "[]")
            except Exception:
                cwds = row["cwds"]
            result[row["id"]] = {
                "status": row["status"] or "",
                "cwds": cwds,
                "target": db_target(row),
                "created_at": row["created_at"],
                "updated_at": row["updated_at"],
            }
        return result
    finally:
        connection.close()


def compare_baseline(
    backup_root: Path, live_root: Path, db_path: Path, templates_root: Path
) -> int:
    errors: list[str] = []
    notices: list[str] = []
    try:
        if backup_root.is_symlink() or not backup_root.is_dir():
            raise ValueError(f"baseline root is missing or unsafe: {backup_root}")
        manifest = parse_manifest(backup_root / "BACKUP-MANIFEST.txt")
        stable_existing = (
            manifest.get("sqlite_consistency") == "authoritative_online_backup"
            and manifest.get("registry_window_check") == "stable"
            and manifest.get("host_state_check") == "consistent"
        )
        fresh_empty = (
            manifest.get("sqlite_consistency") == "absent"
            and manifest.get("registry_window_check") == "fresh_empty"
            and manifest.get("host_state_check") == "fresh_empty"
        )
        if not stable_existing and not fresh_empty:
            errors.append(
                "BASELINE_MANIFEST_INVALID\t"
                f"sqlite_consistency={manifest.get('sqlite_consistency')!r}\t"
                f"registry_window_check={manifest.get('registry_window_check')!r}\t"
                f"host_state_check={manifest.get('host_state_check')!r}"
            )
        baseline, _ = load_view(
            backup_root / "automations-host-state", "baseline-host-state"
        )
        db_before = load_db_host_rows(db_path)
        live, _ = load_view(live_root, "current-live")
        template_ids = {
            path.parent.name
            for path in templates_root.glob("*/automation.toml")
            if path.is_file() and not path.is_symlink()
        }
        db_after = load_db_host_rows(db_path)
    except (ValueError, OSError, sqlite3.Error) as exc:
        fail(f"BASELINE_READ_FAILED\t{exc}")
        return 1

    if db_before != db_after:
        errors.append("BASELINE_REGISTRY_WINDOW_CHANGED\tretry required")
    db_rows = db_after
    if set(live) != set(db_rows):
        errors.append(
            "BASELINE_CURRENT_DB_LIVE_IDS_DIFFER\t"
            f"live={sorted(live)!r}\tdb={sorted(db_rows)!r}"
        )

    missing_ids = sorted(set(baseline) - set(live))
    for schedule_id in missing_ids:
        errors.append(f"BASELINE_SCHEDULE_MISSING\t{schedule_id}")

    new_ids = sorted(set(live) - set(baseline))
    for schedule_id in new_ids:
        status = live[schedule_id].get("status", "")
        if schedule_id in template_ids and status == "PAUSED":
            notices.append(f"BASELINE_NEW_PAUSED_TEMPLATE\t{schedule_id}")
        else:
            errors.append(
                f"BASELINE_UNAPPROVED_NEW_SCHEDULE\t{schedule_id}\t"
                f"status={status!r}\ttemplate={schedule_id in template_ids}"
            )

    for schedule_id in sorted(set(baseline) & set(live)):
        before = baseline[schedule_id]
        current = live[schedule_id]
        exact_fields = {
            "status": (before.get("status", ""), current.get("status", "")),
            "target": (canonical_target(before), canonical_target(current)),
            "cwds": (before.get("cwds", []), current.get("cwds", [])),
            "created_at": (before.get("created_at"), current.get("created_at")),
        }
        for field, (baseline_value, current_value) in exact_fields.items():
            if baseline_value != current_value:
                errors.append(
                    f"BASELINE_HOST_FIELD_CHANGED\t{schedule_id}\tfield={field}\t"
                    f"baseline={compact(baseline_value)}\tcurrent={compact(current_value)}"
                )

        changed_shared = [
            field
            for field in SHARED_FIELDS
            if before.get(field) != current.get(field)
        ]
        before_updated = before.get("updated_at")
        current_updated = current.get("updated_at")
        if not isinstance(before_updated, int) or not isinstance(current_updated, int):
            errors.append(
                f"BASELINE_TIMESTAMP_INVALID\t{schedule_id}\tfield=updated_at\t"
                f"baseline={compact(before_updated)}\tcurrent={compact(current_updated)}"
            )
        elif changed_shared:
            if current_updated <= before_updated:
                errors.append(
                    f"BASELINE_UPDATED_AT_NOT_ADVANCED\t{schedule_id}\t"
                    f"baseline={before_updated}\tcurrent={current_updated}\t"
                    f"shared_fields={','.join(changed_shared)}"
                )
            else:
                notices.append(
                    f"BASELINE_SHARED_UPDATE_ALLOWED\t{schedule_id}\t"
                    f"fields={','.join(changed_shared)}\t"
                    f"updated_at={before_updated}->{current_updated}"
                )
        elif current_updated != before_updated:
            errors.append(
                f"BASELINE_UPDATED_AT_CHANGED_WITHOUT_SHARED_UPDATE\t{schedule_id}\t"
                f"baseline={before_updated}\tcurrent={current_updated}"
            )

    for schedule_id in sorted(set(live) & set(db_rows)):
        current = live[schedule_id]
        db_row = db_rows[schedule_id]
        comparisons = {
            "status": (current.get("status", ""), db_row["status"]),
            "target": (canonical_target(current), db_row["target"]),
            "cwds": (current.get("cwds", []), db_row["cwds"]),
            "created_at": (current.get("created_at"), db_row["created_at"]),
            "updated_at": (current.get("updated_at"), db_row["updated_at"]),
        }
        for field, (file_value, db_value) in comparisons.items():
            if file_value != db_value:
                errors.append(
                    f"BASELINE_CURRENT_DB_FIELD_DIFFERS\t{schedule_id}\tfield={field}\t"
                    f"file={compact(file_value)}\tdb={compact(db_value)}"
                )

    for notice in notices:
        print(notice)
    for error in errors:
        fail(error)
    if errors:
        print(f"__BASELINE_ISSUES__\t{len(errors)}")
        return 1
    print(
        f"BASELINE_OK\tconfigs={len(live)}\t"
        f"shared_updates={sum(1 for item in notices if item.startswith('BASELINE_SHARED_UPDATE_ALLOWED'))}"
    )
    print("__BASELINE_ISSUES__\t0")
    return 0


def load_view(root: Path, label: str) -> tuple[dict[str, dict], dict[str, bytes]]:
    records: dict[str, dict] = {}
    payloads: dict[str, bytes] = {}
    if root.is_symlink():
        raise ValueError(f"{label} root is a symlink: {root}")
    if not root.exists():
        return records, payloads
    if not root.is_dir():
        raise ValueError(f"{label} root is not a directory: {root}")

    for path in sorted(root.glob("*/automation.toml")):
        directory_id = path.parent.name
        if path.parent.is_symlink() or path.is_symlink() or not path.is_file():
            raise ValueError(f"{label} config is unsafe: {path}")
        payload = path.read_bytes()
        try:
            data = tomllib.loads(payload.decode("utf-8"))
        except Exception as exc:
            raise ValueError(f"{label} TOML parse failed for {path}: {exc}") from exc
        if data.get("id") != directory_id:
            raise ValueError(
                f"{label} id mismatch: directory={directory_id}, file_id={data.get('id')!r}"
            )
        records[directory_id] = data
        payloads[directory_id] = payload
    return records, payloads


def main() -> int:
    if len(sys.argv) == 6 and sys.argv[1] == "--compare-baseline":
        return compare_baseline(*map(Path, sys.argv[2:]))
    if len(sys.argv) != 5:
        print(
            "usage: verify-automation-backup-consistency.py "
            "<live-root> <runtime-backup-root> <host-state-root> <db-path>\n"
            "   or: verify-automation-backup-consistency.py --compare-baseline "
            "<backup-root> <live-root> <db-path> <templates-root>",
            file=sys.stderr,
        )
        return 2

    live_root, runtime_root, host_root, db_path = map(Path, sys.argv[1:])
    errors: list[str] = []
    try:
        live, live_payloads = load_view(live_root, "live")
        runtime, runtime_payloads = load_view(runtime_root, "runtime-backup")
        host, host_payloads = load_view(host_root, "host-state")
    except ValueError as exc:
        fail(str(exc))
        return 1

    live_ids = set(live)
    for label, records in (("runtime-backup", runtime), ("host-state", host)):
        if set(records) != live_ids:
            errors.append(
                f"{label} id set differs: live={sorted(live_ids)!r}, "
                f"{label}={sorted(records)!r}"
            )
    for schedule_id in sorted(live_ids & set(runtime) & set(host)):
        if runtime_payloads[schedule_id] != live_payloads[schedule_id]:
            errors.append(f"runtime-backup TOML differs from live: {schedule_id}")
        if host_payloads[schedule_id] != live_payloads[schedule_id]:
            errors.append(f"host-state TOML differs from live: {schedule_id}")

    try:
        connection = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        connection.row_factory = sqlite3.Row
        rows = {
            row["id"]: row
            for row in connection.execute(
                "SELECT id,name,prompt,status,next_run_at,cwds,rrule,model,"
                "reasoning_effort,target_type,project_id,created_at,updated_at "
                "FROM automations ORDER BY id"
            )
        }
    except Exception as exc:
        errors.append(f"registry read failed: {db_path}: {exc}")
        rows = {}

    if set(rows) != live_ids:
        errors.append(
            f"registry/live id set differs: live={sorted(live_ids)!r}, "
            f"registry={sorted(rows)!r}"
        )

    for schedule_id in sorted(live_ids & set(rows)):
        data = live[schedule_id]
        row = rows[schedule_id]
        target = data.get("target") or {}
        if not isinstance(target, dict):
            errors.append(f"live target is not an object: {schedule_id}")
            target = {}
        try:
            db_cwds = json.loads(row["cwds"] or "[]")
        except Exception:
            db_cwds = row["cwds"]
        comparisons = {
            "name": (data.get("name", ""), row["name"] or ""),
            "prompt": (data.get("prompt", ""), row["prompt"] or ""),
            "status": (data.get("status", ""), row["status"] or ""),
            "cwds": (data.get("cwds", []), db_cwds),
            "rrule": (data.get("rrule", ""), row["rrule"] or ""),
            "model": (data.get("model", ""), row["model"] or ""),
            "reasoning_effort": (
                data.get("reasoning_effort", ""),
                row["reasoning_effort"] or "",
            ),
            "target_type": (
                target.get("type", target.get("kind", "")) or "",
                row["target_type"] or "",
            ),
            "project_id": (
                target.get("project_id", target.get("projectId", "")) or "",
                row["project_id"] or "",
            ),
            "created_at": (data.get("created_at"), row["created_at"]),
            "updated_at": (data.get("updated_at"), row["updated_at"]),
        }
        for field, (file_value, db_value) in comparisons.items():
            if file_value != db_value:
                errors.append(
                    f"registry/live field differs: id={schedule_id}, "
                    f"field={field}, live={file_value!r}, registry={db_value!r}"
                )
        if row["status"] == "ACTIVE" and row["next_run_at"] is None:
            errors.append(f"ACTIVE schedule has no next_run_at: {schedule_id}")

    for error in errors:
        fail(error)
    if errors:
        return 1
    print(f"CONSISTENCY_OK\tconfigs={len(live_ids)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
