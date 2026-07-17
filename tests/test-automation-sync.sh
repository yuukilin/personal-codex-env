#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "/private/tmp/codex-automation-sync-test.XXXXXX")"
trap 'rm -rf "${TMP_ROOT}"' EXIT

REPO="${TMP_ROOT}/repo"
TEST_HOME="${TMP_ROOT}/home-one"
CODEX_HOME_UNDER_TEST="${TEST_HOME}/.codex"
AGENTS_HOME_UNDER_TEST="${TEST_HOME}/.agents"
SECOND_HOME="${TMP_ROOT}/home-two"
SECOND_CODEX="${SECOND_HOME}/.codex"
SECOND_AGENTS="${SECOND_HOME}/.agents"
BACKUPS="${TMP_ROOT}/backups"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "expected file: $1"
}

assert_no_file() {
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "unexpected file: $1"
}

assert_content() {
  expected="$1"
  file="$2"
  actual="$(cat "${file}")"
  [ "${actual}" = "${expected}" ] || fail "unexpected content in ${file}: ${actual}"
}

file_hash() {
  shasum -a 256 "$1" | awk '{print $1}'
}

tree_hash() {
  tree_root="$1"
  (
    cd "${tree_root}"
    find . -type f -print | LC_ALL=C sort | while IFS= read -r tree_file; do
      shasum -a 256 "${tree_file}"
    done
  ) | shasum -a 256 | awk '{print $1}'
}

expect_failure() {
  output_file="$1"
  shift
  if "$@" >"${output_file}" 2>&1; then
    fail "command unexpectedly succeeded: $*"
  fi
}

command -v sqlite3 >/dev/null 2>&1 || \
  fail "sqlite3 is required for the automation registry safety suite"

mkdir -p "${REPO}/scripts" "${REPO}/tests"
mkdir -p "${REPO}/rules"
mkdir -p "${REPO}/skills/sample" "${REPO}/agents-skills/sample"
mkdir -p "${REPO}/automations-templates/sample-schedule"
mkdir -p "${REPO}/automation-tools/safe-tool/bin"
mkdir -p "${REPO}/automation-tools/seed-only-tool/bin"
mkdir -p "${REPO}/automation-tools/escape-tool/nested"

for script in backup-current.sh capture-automation-host-state.sh \
  validate-sync-layout.sh install-automation-tools.sh install-mac.sh \
  snapshot-from-local.sh collect-local-for-merge.sh audit-automation-sync.sh \
  restore-automation-runtime-missing-only.sh \
  seed-automation-runtime-missing-only.sh; do
  cp "${SOURCE_ROOT}/scripts/${script}" "${REPO}/scripts/${script}"
  chmod +x "${REPO}/scripts/${script}"
done
cp "${SOURCE_ROOT}/scripts/verify-automation-backup-consistency.py" \
  "${REPO}/scripts/verify-automation-backup-consistency.py"

printf 'shared agent rules\n' > "${REPO}/AGENTS.md"
printf 'shared command rule\n' > "${REPO}/rules/sample.rules"
printf 'skill payload\n' > "${REPO}/skills/sample/SKILL.md"
printf 'agent skill payload\n' > "${REPO}/agents-skills/sample/SKILL.md"
cat > "${REPO}/automations-templates/README.md" <<'EOF'
# Shared definitions
EOF
cat > "${REPO}/automations-templates/sample-schedule/automation.toml" <<'EOF'
version = 1
id = "sample-schedule"
kind = "cron"
name = "Sample Schedule"
prompt = "Run the sample."
rrule = "FREQ=DAILY;BYHOUR=8;BYMINUTE=30"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
EOF

printf 'portable tool\n' > "${REPO}/automation-tools/safe-tool/.portable-tool"
printf '#!/usr/bin/env bash\necho safe\n' > "${REPO}/automation-tools/safe-tool/bin/run.sh"
chmod +x "${REPO}/automation-tools/safe-tool/bin/run.sh"
printf 'repo seed must not replace existing memory\n' > \
  "${REPO}/automation-tools/safe-tool/memory.seed.md"
printf '{"seed":"manual-only"}\n' > \
  "${REPO}/automation-tools/safe-tool/manual-resolutions.seed.json"

printf 'portable tool\n' > "${REPO}/automation-tools/seed-only-tool/.portable-tool"
printf '#!/usr/bin/env bash\necho seed-only\n' > \
  "${REPO}/automation-tools/seed-only-tool/bin/run.sh"
printf 'initial tool memory\n' > \
  "${REPO}/automation-tools/seed-only-tool/memory.seed.md"

printf 'portable tool\n' > "${REPO}/automation-tools/escape-tool/.portable-tool"
printf 'repo escape payload\n' > \
  "${REPO}/automation-tools/escape-tool/nested/payload.txt"

git -C "${REPO}" init -q
git -C "${REPO}" config user.email test@example.invalid
git -C "${REPO}" config user.name "Automation Sync Test"
git -C "${REPO}" add .
git -C "${REPO}" commit -qm "fixture"

# An ordinary untracked skill draft is publish-review material, not install
# material. It must neither fail preflight nor reach the live skill directory.
printf 'draft not yet approved\n' > "${REPO}/skills/sample/local-draft.md"

mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/active-schedule"
mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/paused-schedule"
mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/victim"
mkdir -p "${CODEX_HOME_UNDER_TEST}/automation-tools/safe-tool/runs"
mkdir -p "${CODEX_HOME_UNDER_TEST}/rules"
mkdir -p "${CODEX_HOME_UNDER_TEST}/skills/.system"
mkdir -p "${AGENTS_HOME_UNDER_TEST}/skills"

cat > "${CODEX_HOME_UNDER_TEST}/automations/active-schedule/automation.toml" <<'EOF'
version = 1
id = "active-schedule"
kind = "cron"
name = "Active local schedule"
prompt = "run"
status = "ACTIVE"
cwds = ["/tmp/mac-one-active"]
rrule = "FREQ=DAILY"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
target = { type = "project", project_id = "/tmp/mac-one-active" }
created_at = 1
updated_at = 1
EOF
cat > "${CODEX_HOME_UNDER_TEST}/automations/paused-schedule/automation.toml" <<'EOF'
version = 1
id = "paused-schedule"
kind = "cron"
name = "Paused local schedule"
prompt = "run"
status = "PAUSED"
cwds = ["/tmp/mac-one-paused"]
rrule = "FREQ=DAILY"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
target = { type = "project", project_id = "/tmp/mac-one-paused" }
created_at = 1
updated_at = 1
EOF
cat > "${CODEX_HOME_UNDER_TEST}/automations/victim/automation.toml" <<'EOF'
version = 1
id = "victim"
kind = "cron"
name = "Victim schedule"
prompt = "run"
status = "ACTIVE"
cwds = ["/tmp/victim"]
rrule = "FREQ=DAILY"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
target = { type = "project", project_id = "/tmp/victim" }
created_at = 1
updated_at = 1
EOF
printf 'victim payload survives\n' > \
  "${CODEX_HOME_UNDER_TEST}/automations/victim/payload.txt"
printf 'victim skill sentinel survives\n' > \
  "${CODEX_HOME_UNDER_TEST}/automations/victim/SKILL.md"
printf 'local schedule memory survives\n' > \
  "${CODEX_HOME_UNDER_TEST}/automations/active-schedule/memory.md"
printf 'local tool memory survives\n' > \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/safe-tool/memory.md"
printf 'local generated run survives\n' > \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/safe-tool/runs/local.txt"
printf 'old local rules\n' > "${CODEX_HOME_UNDER_TEST}/AGENTS.md"
printf 'old local command rule\n' > \
  "${CODEX_HOME_UNDER_TEST}/rules/sample.rules"
printf 'system skill survives\n' > "${CODEX_HOME_UNDER_TEST}/skills/.system/SKILL.md"

active_hash_before="$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/active-schedule/automation.toml")"
paused_hash_before="$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/paused-schedule/automation.toml")"
victim_hash_before="$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/victim/automation.toml")"
automation_tree_hash_before="$(tree_hash "${CODEX_HOME_UNDER_TEST}/automations")"

if command -v sqlite3 >/dev/null 2>&1; then
  mkdir -p "${CODEX_HOME_UNDER_TEST}/sqlite"
  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" <<'SQL'
CREATE TABLE automations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  prompt TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  next_run_at INTEGER,
  last_run_at INTEGER,
  cwds TEXT NOT NULL DEFAULT '[]',
  rrule TEXT NOT NULL,
  model TEXT,
  reasoning_effort TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  target_type TEXT,
  project_id TEXT
);
INSERT INTO automations VALUES (
  'active-schedule','Active local schedule','run','ACTIVE',1,0,'["/tmp/mac-one-active"]',
  'FREQ=DAILY','gpt-test','high',1,1,'project','/tmp/mac-one-active'
);
INSERT INTO automations VALUES (
  'paused-schedule','Paused local schedule','run','PAUSED',NULL,0,'["/tmp/mac-one-paused"]',
  'FREQ=DAILY','gpt-test','high',1,1,'project','/tmp/mac-one-paused'
);
INSERT INTO automations VALUES (
  'victim','Victim schedule','run','ACTIVE',1,0,'["/tmp/victim"]',
  'FREQ=DAILY','gpt-test','high',1,1,'project','/tmp/victim'
);
SQL
fi

HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" BACKUP_ROOT="${BACKUPS}" \
  BACKUP_STAMP="valid-install" bash "${REPO}/scripts/install-mac.sh" >/dev/null

assert_file "${CODEX_HOME_UNDER_TEST}/automation-tools/safe-tool/bin/run.sh"
assert_content "shared command rule" \
  "${CODEX_HOME_UNDER_TEST}/rules/sample.rules"
assert_no_file "${CODEX_HOME_UNDER_TEST}/automations/safe-tool/bin/run.sh"
assert_content "local tool memory survives" \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/safe-tool/memory.md"
assert_file "${CODEX_HOME_UNDER_TEST}/automation-tools/seed-only-tool/memory.seed.md"
assert_no_file "${CODEX_HOME_UNDER_TEST}/automation-tools/seed-only-tool/memory.md"
assert_content "local generated run survives" \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/safe-tool/runs/local.txt"
assert_file "${CODEX_HOME_UNDER_TEST}/automation-tools/safe-tool/manual-resolutions.seed.json"
assert_no_file "${CODEX_HOME_UNDER_TEST}/automation-tools/safe-tool/manual-resolutions.json"
assert_no_file "${CODEX_HOME_UNDER_TEST}/skills/sample/local-draft.md"
assert_file "${CODEX_HOME_UNDER_TEST}/skills/.system/SKILL.md"
assert_file "${CODEX_HOME_UNDER_TEST}/automation-templates/sample-schedule/automation.toml"
assert_file "${BACKUPS}/valid-install/automations-runtime/active-schedule/memory.md"
assert_content "old local command rule" \
  "${BACKUPS}/valid-install/codex-rules/sample.rules"
assert_file "${BACKUPS}/valid-install/automation-tools-runtime/safe-tool/memory.md"
assert_file "${BACKUPS}/valid-install/automations-host-state/index.tsv"
assert_file "${BACKUPS}/valid-install/POST-INSTALL-HOST-STATE.txt"
grep -F 'BASELINE_OK' \
  "${BACKUPS}/valid-install/POST-INSTALL-HOST-STATE.txt" >/dev/null || \
  fail "installer did not verify the exact pre-install host-state baseline"
[ "$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/active-schedule/automation.toml")" = "${active_hash_before}" ] || fail "ACTIVE schedule was changed"
[ "$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/paused-schedule/automation.toml")" = "${paused_hash_before}" ] || fail "PAUSED schedule was changed"
[ "$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/victim/automation.toml")" = "${victim_hash_before}" ] || fail "victim schedule was changed"
[ "$(tree_hash "${CODEX_HOME_UNDER_TEST}/automations")" = "${automation_tree_hash_before}" ] || fail "installer changed the live automation runtime tree"

if command -v sqlite3 >/dev/null 2>&1; then
  assert_file "${BACKUPS}/valid-install/sqlite/codex-dev.db"
  assert_file "${BACKUPS}/valid-install/sqlite/automations-registry.tsv"
  assert_file "${BACKUPS}/valid-install/sqlite/automations-registry.json"
  assert_file "${BACKUPS}/valid-install/sqlite/raw-forensics/codex-dev.db"
  [ "$(sqlite3 -readonly "${BACKUPS}/valid-install/sqlite/codex-dev.db" 'PRAGMA integrity_check;')" = "ok" ] || fail "SQLite online backup is invalid"
  grep -F 'active-schedule' "${BACKUPS}/valid-install/sqlite/automations-registry.tsv" >/dev/null || fail "registry TSV is incomplete"
  grep -F '"status":"ACTIVE"' "${BACKUPS}/valid-install/sqlite/automations-registry.json" >/dev/null || fail "registry JSON is incomplete"
  grep -Fx 'registry_window_check=stable' \
    "${BACKUPS}/valid-install/BACKUP-MANIFEST.txt" >/dev/null || \
    fail "backup did not prove a stable automation registry window"
  grep -Fx 'host_state_check=consistent' \
    "${BACKUPS}/valid-install/BACKUP-MANIFEST.txt" >/dev/null || \
    fail "backup did not prove DB/live/host-state consistency"
  cmp -s "${BACKUPS}/valid-install/sqlite/registry-window-before.tsv" \
    "${BACKUPS}/valid-install/sqlite/registry-window-after.tsv" || \
    fail "backup registry window changed"
fi

# A baseline catches host-local drift even when DB and TOML are changed
# together. Legitimate shared-field updates may advance updated_at.
BASELINE_BACKUP="${BACKUPS}/valid-install"
BASELINE_VERIFIER="${REPO}/scripts/verify-automation-backup-consistency.py"
python3 "${BASELINE_VERIFIER}" --compare-baseline \
  "${BASELINE_BACKUP}" "${CODEX_HOME_UNDER_TEST}/automations" \
  "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "${REPO}/automations-templates" > "${TMP_ROOT}/baseline-clean.out"
grep -F 'BASELINE_OK' "${TMP_ROOT}/baseline-clean.out" >/dev/null || \
  fail "clean baseline comparison did not pass"
baseline_audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/audit-automation-sync.sh" --report \
  --baseline-backup "${BASELINE_BACKUP}")"
printf '%s\n' "${baseline_audit_output}" | grep -F 'BASELINE_OK' >/dev/null || \
  fail "audit did not run the requested exact baseline verifier"

cp "${CODEX_HOME_UNDER_TEST}/automations/active-schedule/automation.toml" \
  "${TMP_ROOT}/active-baseline-original.toml"
sed -e 's/^prompt = "run"$/prompt = "run shared update"/' \
  -e 's/^rrule = "FREQ=DAILY"$/rrule = "FREQ=HOURLY"/' \
  -e 's/^updated_at = 1$/updated_at = 2/' \
  "${TMP_ROOT}/active-baseline-original.toml" \
  > "${CODEX_HOME_UNDER_TEST}/automations/active-schedule/automation.toml"
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "UPDATE automations SET prompt='run shared update', rrule='FREQ=HOURLY', updated_at=2 WHERE id='active-schedule';"
python3 "${BASELINE_VERIFIER}" --compare-baseline \
  "${BASELINE_BACKUP}" "${CODEX_HOME_UNDER_TEST}/automations" \
  "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "${REPO}/automations-templates" > "${TMP_ROOT}/baseline-shared-update.out"
grep -F $'BASELINE_SHARED_UPDATE_ALLOWED\tactive-schedule' \
  "${TMP_ROOT}/baseline-shared-update.out" >/dev/null || \
  fail "baseline rejected a legitimate shared-field update"

cp "${TMP_ROOT}/active-baseline-original.toml" \
  "${CODEX_HOME_UNDER_TEST}/automations/active-schedule/automation.toml"
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "UPDATE automations SET prompt='run', rrule='FREQ=DAILY', updated_at=1 WHERE id='active-schedule';"
sed 's/^updated_at = 1$/updated_at = 2/' \
  "${TMP_ROOT}/active-baseline-original.toml" \
  > "${CODEX_HOME_UNDER_TEST}/automations/active-schedule/automation.toml"
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "UPDATE automations SET updated_at=2 WHERE id='active-schedule';"
expect_failure "${TMP_ROOT}/baseline-touch-only.out" python3 \
  "${BASELINE_VERIFIER}" --compare-baseline "${BASELINE_BACKUP}" \
  "${CODEX_HOME_UNDER_TEST}/automations" \
  "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "${REPO}/automations-templates"
grep -F $'BASELINE_UPDATED_AT_CHANGED_WITHOUT_SHARED_UPDATE\tactive-schedule' \
  "${TMP_ROOT}/baseline-touch-only.out" >/dev/null || \
  fail "baseline missed unexplained updated_at drift"

sed -e 's/^status = "ACTIVE"$/status = "PAUSED"/' \
  -e 's#/tmp/mac-one-active#/tmp/other-mac#g' \
  -e 's/^created_at = 1$/created_at = 9/' \
  "${TMP_ROOT}/active-baseline-original.toml" \
  > "${CODEX_HOME_UNDER_TEST}/automations/active-schedule/automation.toml"
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "UPDATE automations SET status='PAUSED', next_run_at=NULL, cwds='[\"/tmp/other-mac\"]', project_id='/tmp/other-mac', created_at=9, updated_at=1 WHERE id='active-schedule';"
expect_failure "${TMP_ROOT}/baseline-host-drift.out" python3 \
  "${BASELINE_VERIFIER}" --compare-baseline "${BASELINE_BACKUP}" \
  "${CODEX_HOME_UNDER_TEST}/automations" \
  "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "${REPO}/automations-templates"
for protected_field in status target cwds created_at; do
  grep -F "field=${protected_field}" "${TMP_ROOT}/baseline-host-drift.out" >/dev/null || \
    fail "baseline missed host-local drift in ${protected_field}"
done

cp "${TMP_ROOT}/active-baseline-original.toml" \
  "${CODEX_HOME_UNDER_TEST}/automations/active-schedule/automation.toml"
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "UPDATE automations SET status='ACTIVE', next_run_at=1, cwds='[\"/tmp/mac-one-active\"]', project_id='/tmp/mac-one-active', created_at=1, updated_at=1 WHERE id='active-schedule';"

# A local-only/legacy schedule ID may collide with a portable tool even when no
# shared template has that ID. Preflight must stop before backup or install.
mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/safe-tool"
cat > "${CODEX_HOME_UNDER_TEST}/automations/safe-tool/automation.toml" <<'EOF'
version = 1
id = "safe-tool"
kind = "cron"
name = "Local safe tool schedule"
prompt = "local only"
status = "PAUSED"
cwds = []
rrule = "FREQ=DAILY"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
target = { type = "local" }
created_at = 1
updated_at = 1
EOF
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" <<'SQL'
INSERT INTO automations VALUES (
  'safe-tool','Local safe tool schedule','local only','PAUSED',NULL,0,'[]',
  'FREQ=DAILY','gpt-test','high',1,1,'local',NULL
);
SQL
expect_failure "${TMP_ROOT}/live-tool-collision.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" BACKUP_ROOT="${BACKUPS}" \
  BACKUP_STAMP="live-tool-collision" bash "${REPO}/scripts/install-mac.sh"
grep -F 'portable tool name collides with a live schedule id: safe-tool' \
  "${TMP_ROOT}/live-tool-collision.out" >/dev/null || \
  fail "preflight missed a local-only live schedule/tool collision"
assert_no_file "${BACKUPS}/live-tool-collision/BACKUP-MANIFEST.txt"
rm "${CODEX_HOME_UNDER_TEST}/automations/safe-tool/automation.toml"
rmdir "${CODEX_HOME_UNDER_TEST}/automations/safe-tool"
expect_failure "${TMP_ROOT}/db-tool-collision.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
grep -F 'portable tool name collides with a registry schedule id: safe-tool' \
  "${TMP_ROOT}/db-tool-collision.out" >/dev/null || \
  fail "preflight missed a DB-only schedule/tool collision"
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "DELETE FROM automations WHERE id='safe-tool';"

# The original incident shape (DB row survives, automation.toml disappears)
# and its inverse both abort backup/install before any live write.
printf 'preflight sentinel\n' > "${CODEX_HOME_UNDER_TEST}/AGENTS.md"
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" <<'SQL'
INSERT INTO automations VALUES (
  'preflight-db-only','Preflight DB only','run','PAUSED',NULL,0,'[]',
  'FREQ=DAILY','gpt-test','high',1,1,'local',NULL
);
SQL
expect_failure "${TMP_ROOT}/preflight-db-only.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" BACKUP_ROOT="${BACKUPS}" \
  BACKUP_STAMP="preflight-db-only" bash "${REPO}/scripts/install-mac.sh"
assert_content "preflight sentinel" "${CODEX_HOME_UNDER_TEST}/AGENTS.md"
grep -Fx 'host_state_check=inconsistent' \
  "${BACKUPS}/preflight-db-only/BACKUP-MANIFEST.txt" >/dev/null || \
  fail "DB-only preflight did not fail the three-way consistency gate"
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
  "DELETE FROM automations WHERE id='preflight-db-only';"

mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/preflight-file-only"
cat > "${CODEX_HOME_UNDER_TEST}/automations/preflight-file-only/automation.toml" <<'EOF'
version = 1
id = "preflight-file-only"
name = "Preflight file only"
status = "PAUSED"
EOF
expect_failure "${TMP_ROOT}/preflight-file-only.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" BACKUP_ROOT="${BACKUPS}" \
  BACKUP_STAMP="preflight-file-only" bash "${REPO}/scripts/install-mac.sh"
assert_content "preflight sentinel" "${CODEX_HOME_UNDER_TEST}/AGENTS.md"
grep -Fx 'host_state_check=inconsistent' \
  "${BACKUPS}/preflight-file-only/BACKUP-MANIFEST.txt" >/dev/null || \
  fail "file-only preflight did not fail the three-way consistency gate"
mv "${CODEX_HOME_UNDER_TEST}/automations/preflight-file-only" \
  "${TMP_ROOT}/preflight-file-only.saved"

# Seed deployment and runtime initialization are separate operations. Reconcile
# must name the exact schedule and allowlisted runtime file; a second call keeps
# the schedule's local memory authoritative.
mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/seed-runtime"
cat > "${CODEX_HOME_UNDER_TEST}/automations/seed-runtime/automation.toml" <<'EOF'
version = 1
id = "seed-runtime"
kind = "cron"
name = "Seed runtime"
prompt = "Run seed runtime."
status = "PAUSED"
cwds = []
rrule = "FREQ=DAILY"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
target = { type = "local" }
created_at = 1
updated_at = 1
EOF
expect_failure "${TMP_ROOT}/seed-without-registry.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/seed-automation-runtime-missing-only.sh" \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/seed-only-tool/memory.seed.md" \
  seed-runtime memory.md
assert_no_file "${CODEX_HOME_UNDER_TEST}/automations/seed-runtime/memory.md"
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" <<'SQL'
INSERT INTO automations VALUES (
  'seed-runtime','Seed runtime','Run seed runtime.','PAUSED',NULL,0,'[]',
  'FREQ=DAILY','gpt-test','high',1,1,'local',NULL
);
SQL
HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/seed-automation-runtime-missing-only.sh" \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/seed-only-tool/memory.seed.md" \
  seed-runtime memory.md >/dev/null
assert_content "initial tool memory" \
  "${CODEX_HOME_UNDER_TEST}/automations/seed-runtime/memory.md"
printf 'local reconciled memory wins\n' > \
  "${CODEX_HOME_UNDER_TEST}/automations/seed-runtime/memory.md"
HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/seed-automation-runtime-missing-only.sh" \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/seed-only-tool/memory.seed.md" \
  seed-runtime memory.md >/dev/null
assert_content "local reconciled memory wins" \
  "${CODEX_HOME_UNDER_TEST}/automations/seed-runtime/memory.md"

# Parent-directory and registry symlinks are rejected before an existing or
# missing runtime file can be touched.
ln -s "${CODEX_HOME_UNDER_TEST}" "${TMP_ROOT}/codex-home-link"
expect_failure "${TMP_ROOT}/seed-parent-link.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${TMP_ROOT}/codex-home-link" \
  bash "${REPO}/scripts/seed-automation-runtime-missing-only.sh" \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/seed-only-tool/memory.seed.md" \
  seed-runtime memory.md
rm "${TMP_ROOT}/codex-home-link"

DB_LINK_CODEX="${TMP_ROOT}/db-link-home/.codex"
mkdir -p "${DB_LINK_CODEX}/automations/db-link-schedule"
cat > "${DB_LINK_CODEX}/automations/db-link-schedule/automation.toml" <<'EOF'
version = 1
id = "db-link-schedule"
name = "DB link schedule"
status = "PAUSED"
EOF
ln -s "${CODEX_HOME_UNDER_TEST}/sqlite" "${DB_LINK_CODEX}/sqlite"
expect_failure "${TMP_ROOT}/seed-db-link.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${DB_LINK_CODEX}" \
  bash "${REPO}/scripts/seed-automation-runtime-missing-only.sh" \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/seed-only-tool/memory.seed.md" \
  db-link-schedule memory.md
assert_no_file "${DB_LINK_CODEX}/automations/db-link-schedule/memory.md"
expect_failure "${TMP_ROOT}/validate-db-link.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${DB_LINK_CODEX}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
grep -F 'automation state path contains a symlink component' \
  "${TMP_ROOT}/validate-db-link.out" >/dev/null || \
  fail "validator did not reject a linked automation registry"
expect_failure "${TMP_ROOT}/backup-db-link.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${DB_LINK_CODEX}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" BACKUP_ROOT="${BACKUPS}" \
  BACKUP_STAMP="db-link-backup" bash "${REPO}/scripts/backup-current.sh"
assert_no_file "${BACKUPS}/db-link-backup/BACKUP-MANIFEST.txt"

# A second Mac receives the same definitions and code but retains independent
# switch/target state. This Mac intentionally reverses ACTIVE/PAUSED.
mkdir -p "${SECOND_CODEX}/automations/active-schedule" \
  "${SECOND_CODEX}/automations/paused-schedule" "${SECOND_AGENTS}/skills"
cat > "${SECOND_CODEX}/automations/active-schedule/automation.toml" <<'EOF'
version = 1
id = "active-schedule"
kind = "cron"
name = "Active local schedule"
prompt = "run"
status = "PAUSED"
cwds = ["/tmp/mac-two-paused"]
rrule = "FREQ=DAILY"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
target = { type = "project", project_id = "/tmp/mac-two-paused" }
created_at = 1
updated_at = 1
EOF
cat > "${SECOND_CODEX}/automations/paused-schedule/automation.toml" <<'EOF'
version = 1
id = "paused-schedule"
kind = "cron"
name = "Paused local schedule"
prompt = "run"
status = "ACTIVE"
cwds = ["/tmp/mac-two-active"]
rrule = "FREQ=DAILY"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
target = { type = "project", project_id = "/tmp/mac-two-active" }
created_at = 1
updated_at = 1
EOF
mkdir -p "${SECOND_CODEX}/sqlite"
sqlite3 "${SECOND_CODEX}/sqlite/codex-dev.db" <<'SQL'
CREATE TABLE automations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  prompt TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'ACTIVE',
  next_run_at INTEGER,
  last_run_at INTEGER,
  cwds TEXT NOT NULL DEFAULT '[]',
  rrule TEXT NOT NULL,
  model TEXT,
  reasoning_effort TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  target_type TEXT,
  project_id TEXT
);
INSERT INTO automations VALUES (
  'active-schedule','Active local schedule','run','PAUSED',NULL,0,
  '["/tmp/mac-two-paused"]','FREQ=DAILY','gpt-test','high',1,1,
  'project','/tmp/mac-two-paused'
);
INSERT INTO automations VALUES (
  'paused-schedule','Paused local schedule','run','ACTIVE',1,0,
  '["/tmp/mac-two-active"]','FREQ=DAILY','gpt-test','high',1,1,
  'project','/tmp/mac-two-active'
);
SQL
second_active_before="$(file_hash "${SECOND_CODEX}/automations/active-schedule/automation.toml")"
second_paused_before="$(file_hash "${SECOND_CODEX}/automations/paused-schedule/automation.toml")"
second_tree_before="$(tree_hash "${SECOND_CODEX}/automations")"
HOME="${SECOND_HOME}" CODEX_HOME="${SECOND_CODEX}" AGENTS_HOME="${SECOND_AGENTS}" \
  BACKUP_ROOT="${BACKUPS}" BACKUP_STAMP="second-mac" \
  bash "${REPO}/scripts/install-mac.sh" >/dev/null
[ "$(file_hash "${SECOND_CODEX}/automations/active-schedule/automation.toml")" = "${second_active_before}" ] || fail "Mac two PAUSED state changed"
[ "$(file_hash "${SECOND_CODEX}/automations/paused-schedule/automation.toml")" = "${second_paused_before}" ] || fail "Mac two ACTIVE state changed"
[ "$(tree_hash "${SECOND_CODEX}/automations")" = "${second_tree_before}" ] || fail "Mac two automation runtime tree changed"

# A truly fresh Mac has neither registry nor live schedule TOML. Installing
# definitions/tools is allowed, but it still does not manufacture live files.
FRESH_HOME="${TMP_ROOT}/fresh-home"
FRESH_CODEX="${FRESH_HOME}/.codex"
FRESH_AGENTS="${FRESH_HOME}/.agents"
mkdir -p "${FRESH_CODEX}" "${FRESH_AGENTS}"
HOME="${FRESH_HOME}" CODEX_HOME="${FRESH_CODEX}" AGENTS_HOME="${FRESH_AGENTS}" \
  BACKUP_ROOT="${BACKUPS}" BACKUP_STAMP="fresh-empty" \
  bash "${REPO}/scripts/install-mac.sh" >/dev/null
assert_file "${FRESH_CODEX}/automation-templates/sample-schedule/automation.toml"
assert_no_file "${FRESH_CODEX}/automations/sample-schedule/automation.toml"
grep -Fx 'host_state_check=fresh_empty' \
  "${BACKUPS}/fresh-empty/BACKUP-MANIFEST.txt" >/dev/null || \
  fail "fresh empty install did not use its explicit first-install exception"

# Untracked conflict copies abort before backup or any live write.
printf 'conflict copy\n' > "${REPO}/skills/sample/SKILL 2.md"
printf 'sentinel rules\n' > "${CODEX_HOME_UNDER_TEST}/AGENTS.md"
expect_failure "${TMP_ROOT}/skill-conflict.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" BACKUP_ROOT="${BACKUPS}" \
  BACKUP_STAMP="skill-conflict" bash "${REPO}/scripts/install-mac.sh"
assert_content "sentinel rules" "${CODEX_HOME_UNDER_TEST}/AGENTS.md"
assert_no_file "${CODEX_HOME_UNDER_TEST}/skills/sample/SKILL 2.md"
assert_no_file "${BACKUPS}/skill-conflict/BACKUP-MANIFEST.txt"
rm "${REPO}/skills/sample/SKILL 2.md"

# Any untracked portable payload, including a nested regular file, is fatal.
printf 'untracked payload\n' > "${REPO}/automation-tools/safe-tool/bin/untracked.txt"
expect_failure "${TMP_ROOT}/untracked-tool.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" BACKUP_ROOT="${BACKUPS}" \
  BACKUP_STAMP="untracked-tool" bash "${REPO}/scripts/install-mac.sh"
assert_no_file "${CODEX_HOME_UNDER_TEST}/automation-tools/safe-tool/bin/untracked.txt"
assert_no_file "${BACKUPS}/untracked-tool/BACKUP-MANIFEST.txt"
rm "${REPO}/automation-tools/safe-tool/bin/untracked.txt"

# The template directory is a strict one-file allowlist.
printf 'ambiguous template\n' > \
  "${REPO}/automations-templates/sample-schedule/automation 2.toml"
expect_failure "${TMP_ROOT}/template-extra.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
rm "${REPO}/automations-templates/sample-schedule/automation 2.toml"

sed 's/^id = "sample-schedule"$/id = "safe-tool"/' \
  "${REPO}/automations-templates/sample-schedule/automation.toml" \
  > "${TMP_ROOT}/tool-template-collision.toml"
mv "${TMP_ROOT}/tool-template-collision.toml" \
  "${REPO}/automations-templates/sample-schedule/automation.toml"
expect_failure "${TMP_ROOT}/tool-template-collision.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
grep -F 'portable tool name collides with a shared template id: safe-tool' \
  "${TMP_ROOT}/tool-template-collision.out" >/dev/null || \
  fail "validator missed a shared template/tool name collision"
git -C "${REPO}" checkout -q -- automations-templates/sample-schedule/automation.toml

# Newly invented or dotted host fields fail closed.
printf '\nfuture_host_switch = true\n' >> \
  "${REPO}/automations-templates/sample-schedule/automation.toml"
expect_failure "${TMP_ROOT}/unknown-template-key.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
git -C "${REPO}" checkout -q -- automations-templates/sample-schedule/automation.toml
printf '\ntarget.project_id = "/must-not-travel"\n' >> \
  "${REPO}/automations-templates/sample-schedule/automation.toml"
expect_failure "${TMP_ROOT}/dotted-template-key.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
git -C "${REPO}" checkout -q -- automations-templates/sample-schedule/automation.toml

sed 's/^version = 1$/version = "1"/' \
  "${REPO}/automations-templates/sample-schedule/automation.toml" \
  > "${TMP_ROOT}/wrong-template-type.toml"
mv "${TMP_ROOT}/wrong-template-type.toml" \
  "${REPO}/automations-templates/sample-schedule/automation.toml"
expect_failure "${TMP_ROOT}/wrong-template-type.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
grep -F 'wrong type for version' "${TMP_ROOT}/wrong-template-type.out" >/dev/null || \
  fail "validator did not report the TOML type error"
git -C "${REPO}" checkout -q -- automations-templates/sample-schedule/automation.toml

printf '\nprompt = "unterminated\n' >> \
  "${REPO}/automations-templates/sample-schedule/automation.toml"
expect_failure "${TMP_ROOT}/malformed-template.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
grep -F 'invalid TOML' "${TMP_ROOT}/malformed-template.out" >/dev/null || \
  fail "validator did not report malformed TOML"
git -C "${REPO}" checkout -q -- automations-templates/sample-schedule/automation.toml

# Runtime-looking paths are forbidden at every source depth; seeds remain legal.
mkdir -p "${REPO}/automation-tools/safe-tool/nested"
printf 'must not deploy\n' > "${REPO}/automation-tools/safe-tool/nested/memory.md"
git -C "${REPO}" add automation-tools/safe-tool/nested/memory.md
expect_failure "${TMP_ROOT}/nested-runtime.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
git -C "${REPO}" reset -q HEAD -- automation-tools/safe-tool/nested/memory.md
rm "${REPO}/automation-tools/safe-tool/nested/memory.md"
rmdir "${REPO}/automation-tools/safe-tool/nested"

# Git-tracked symlinks and tracked-but-missing payloads both fail preflight.
ln -s run.sh "${REPO}/automation-tools/safe-tool/bin/run-link.sh"
git -C "${REPO}" add automation-tools/safe-tool/bin/run-link.sh
expect_failure "${TMP_ROOT}/tracked-source-link.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
git -C "${REPO}" reset -q HEAD -- automation-tools/safe-tool/bin/run-link.sh
rm "${REPO}/automation-tools/safe-tool/bin/run-link.sh"

mv "${REPO}/automation-tools/seed-only-tool" "${TMP_ROOT}/seed-only-tool.saved"
expect_failure "${TMP_ROOT}/tracked-missing.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/validate-sync-layout.sh"
mv "${TMP_ROOT}/seed-only-tool.saved" "${REPO}/automation-tools/seed-only-tool"

# A nested destination symlink cannot redirect portable code into a schedule.
mv "${CODEX_HOME_UNDER_TEST}/automation-tools/escape-tool/nested" \
  "${TMP_ROOT}/escape-target.saved"
ln -s "${CODEX_HOME_UNDER_TEST}/automations/victim" \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/escape-tool/nested"
victim_payload_before="$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/victim/payload.txt")"
expect_failure "${TMP_ROOT}/tool-destination-link.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" BACKUP_ROOT="${BACKUPS}" \
  BACKUP_STAMP="tool-destination-link" bash "${REPO}/scripts/install-mac.sh"
[ "$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/victim/automation.toml")" = "${victim_hash_before}" ] || fail "tool symlink escape changed victim automation.toml"
[ "$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/victim/payload.txt")" = "${victim_payload_before}" ] || fail "tool symlink escape changed victim payload"
assert_no_file "${BACKUPS}/tool-destination-link/BACKUP-MANIFEST.txt"
rm "${CODEX_HOME_UNDER_TEST}/automation-tools/escape-tool/nested"
mv "${TMP_ROOT}/escape-target.saved" \
  "${CODEX_HOME_UNDER_TEST}/automation-tools/escape-tool/nested"

# The same parent-chain rule protects skills and template caches before the tool
# installer can write anything, preventing a partial install.
mv "${CODEX_HOME_UNDER_TEST}/skills/sample" "${TMP_ROOT}/skill-target.saved"
ln -s "${CODEX_HOME_UNDER_TEST}/automations/victim" \
  "${CODEX_HOME_UNDER_TEST}/skills/sample"
victim_skill_before="$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/victim/SKILL.md")"
expect_failure "${TMP_ROOT}/skill-destination-link.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" BACKUP_ROOT="${BACKUPS}" \
  BACKUP_STAMP="skill-destination-link" bash "${REPO}/scripts/install-mac.sh"
[ "$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/victim/automation.toml")" = "${victim_hash_before}" ] || fail "skill symlink escape changed victim automation.toml"
[ "$(file_hash "${CODEX_HOME_UNDER_TEST}/automations/victim/SKILL.md")" = "${victim_skill_before}" ] || fail "skill symlink escape changed victim skill sentinel"
assert_no_file "${BACKUPS}/skill-destination-link/BACKUP-MANIFEST.txt"
rm "${CODEX_HOME_UNDER_TEST}/skills/sample"
mv "${TMP_ROOT}/skill-target.saved" "${CODEX_HOME_UNDER_TEST}/skills/sample"

# Missing-only runtime restore is safe after an automation-tool recreate: it
# excludes automation.toml and never replaces any file already present locally.
RESTORE_SOURCE="${TMP_ROOT}/restore-backup/automations-runtime/sample-schedule"
RESTORE_LIVE="${CODEX_HOME_UNDER_TEST}/automations/sample-schedule"
mkdir -p "${RESTORE_SOURCE}/reports" "${RESTORE_SOURCE}/scripts" \
  "${RESTORE_SOURCE}/config" "${RESTORE_LIVE}"
cat > "${RESTORE_SOURCE}/automation.toml" <<'EOF'
version = 1
id = "sample-schedule"
status = "ACTIVE"
target = { kind = "project", project_id = "/old-machine" }
EOF
printf 'old memory must not overwrite\n' > "${RESTORE_SOURCE}/memory.md"
printf 'recovered last run\n' > "${RESTORE_SOURCE}/last-run.md"
printf '{"resolutions":[{"id":"one"}]}\n' > \
  "${RESTORE_SOURCE}/manual-resolutions.json"
printf 'recovered report\n' > "${RESTORE_SOURCE}/reports/one.md"
printf 'portable marker must not restore\n' > "${RESTORE_SOURCE}/.portable-tool"
printf 'legacy helper must not restore\n' > "${RESTORE_SOURCE}/scripts/tool.sh"
printf 'legacy config must not restore\n' > "${RESTORE_SOURCE}/config/settings.json"
cat > "${RESTORE_LIVE}/automation.toml" <<'EOF'
version = 1
id = "sample-schedule"
kind = "cron"
name = "Sample Schedule"
prompt = "Run the sample."
status = "PAUSED"
cwds = ["/this-machine"]
rrule = "FREQ=DAILY;BYHOUR=8;BYMINUTE=30"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
target = { type = "project", project_id = "/this-machine" }
created_at = 1
updated_at = 1
EOF
printf 'new local memory wins\n' > "${RESTORE_LIVE}/memory.md"
restore_config_hash="$(file_hash "${RESTORE_LIVE}/automation.toml")"
restore_memory_hash="$(file_hash "${RESTORE_LIVE}/memory.md")"
expect_failure "${TMP_ROOT}/restore-without-registry.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/restore-automation-runtime-missing-only.sh" \
  "${TMP_ROOT}/restore-backup/automations-runtime" sample-schedule
assert_no_file "${RESTORE_LIVE}/last-run.md"
sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" <<'SQL'
INSERT INTO automations VALUES (
  'sample-schedule','Sample Schedule','Run the sample.','PAUSED',NULL,0,
  '["/this-machine"]','FREQ=DAILY;BYHOUR=8;BYMINUTE=30',
  'gpt-test','high',1,1,'project','/this-machine'
);
SQL
HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/restore-automation-runtime-missing-only.sh" \
  "${TMP_ROOT}/restore-backup/automations-runtime" sample-schedule \
  > "${TMP_ROOT}/restore.out"
[ "$(file_hash "${RESTORE_LIVE}/automation.toml")" = "${restore_config_hash}" ] || fail "runtime restore overwrote automation.toml"
[ "$(file_hash "${RESTORE_LIVE}/memory.md")" = "${restore_memory_hash}" ] || fail "runtime restore overwrote existing memory"
assert_content "recovered last run" "${RESTORE_LIVE}/last-run.md"
assert_file "${RESTORE_LIVE}/manual-resolutions.json"
assert_content "recovered report" "${RESTORE_LIVE}/reports/one.md"
assert_no_file "${RESTORE_LIVE}/.portable-tool"
assert_no_file "${RESTORE_LIVE}/scripts/tool.sh"
assert_no_file "${RESTORE_LIVE}/config/settings.json"
grep -F 'Skipped non-runtime backup entry:' "${TMP_ROOT}/restore.out" >/dev/null || \
  fail "runtime restore did not report skipped legacy code/config"

printf 'newer live last run\n' > "${RESTORE_LIVE}/last-run.md"
last_run_hash="$(file_hash "${RESTORE_LIVE}/last-run.md")"
HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/restore-automation-runtime-missing-only.sh" \
  "${TMP_ROOT}/restore-backup/automations-runtime" sample-schedule >/dev/null
[ "$(file_hash "${RESTORE_LIVE}/last-run.md")" = "${last_run_hash}" ] || fail "second runtime restore was not missing-only"

ln -s "${TMP_ROOT}/restore-backup/automations-runtime" \
  "${TMP_ROOT}/restore-source-link"
expect_failure "${TMP_ROOT}/restore-source-link.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/restore-automation-runtime-missing-only.sh" \
  "${TMP_ROOT}/restore-source-link" sample-schedule
rm "${TMP_ROOT}/restore-source-link"

mkdir -p "${TMP_ROOT}/db-link-restore/db-link-schedule"
printf 'must not restore through linked registry\n' > \
  "${TMP_ROOT}/db-link-restore/db-link-schedule/memory.md"
expect_failure "${TMP_ROOT}/restore-db-link.out" env \
  HOME="${TEST_HOME}" CODEX_HOME="${DB_LINK_CODEX}" \
  bash "${REPO}/scripts/restore-automation-runtime-missing-only.sh" \
  "${TMP_ROOT}/db-link-restore" db-link-schedule
assert_no_file "${DB_LINK_CODEX}/automations/db-link-schedule/memory.md"

# The read-only audit detects the exact split that caused this incident: a DB
# row without TOML, a TOML without DB row, status drift, and legacy duplicates.
if command -v sqlite3 >/dev/null 2>&1; then
  mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/file-only-local"
  cat > "${CODEX_HOME_UNDER_TEST}/automations/file-only-local/automation.toml" <<'EOF'
version = 1
id = "file-only-local"
name = "File only local"
status = "PAUSED"
EOF
  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
    "DELETE FROM automations WHERE id='sample-schedule';"
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'FILE_ONLY_REGISTRY_MISSING\tsample-schedule' >/dev/null || \
    fail "audit missed file-only schedule state"
  printf '%s\n' "${audit_output}" | grep -F $'LOCAL_FILE_ONLY_REGISTRY_MISSING\tfile-only-local' >/dev/null || \
    fail "global audit missed a local-only file/DB split"

  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" <<'SQL'
INSERT INTO automations VALUES (
  'sample-schedule','Sample Schedule','Run the sample.','PAUSED',NULL,0,
  '["/this-machine"]','FREQ=DAILY;BYHOUR=8;BYMINUTE=30',
  'gpt-test','high',1,1,'project','/this-machine'
);
SQL

  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" <<'SQL'
INSERT INTO automations VALUES (
  'orphan-db-only','Orphan DB only','run','PAUSED',1,0,'[]',
  'FREQ=DAILY','gpt-test','high',1,1,'project','/orphan'
);
SQL
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'LOCAL_DB_ONLY_FILE_MISSING\torphan-db-only' >/dev/null || \
    fail "global audit missed a local-only DB/file split"

  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
    "UPDATE automations SET status='ACTIVE', next_run_at=1 WHERE id='sample-schedule';"
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'REGISTRY_STATUS_MISMATCH\tsample-schedule' >/dev/null || \
    fail "audit missed DB/file status drift"

  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
    "UPDATE automations SET next_run_at=NULL WHERE id='sample-schedule';"
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'ACTIVE_NEXT_RUN_MISSING\tsample-schedule' >/dev/null || \
    fail "semantic audit missed ACTIVE schedule without next_run_at"
  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
    "UPDATE automations SET next_run_at=1, project_id='' WHERE id='sample-schedule';"
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'REGISTRY_FIELD_MISMATCH\tsample-schedule\tfield=project_id' >/dev/null || \
    fail "semantic audit missed normalized empty target drift"
  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
    "UPDATE automations SET project_id='/this-machine' WHERE id='sample-schedule';"

  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
    "UPDATE automations SET updated_at=2 WHERE id='sample-schedule';"
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'REGISTRY_FIELD_MISMATCH\tsample-schedule\tfield=updated_at' >/dev/null || \
    fail "semantic audit missed DB/live updated_at drift"
  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
    "UPDATE automations SET updated_at=1 WHERE id='sample-schedule';"

  cp "${RESTORE_LIVE}/automation.toml" "${TMP_ROOT}/sample-semantic.saved"
  sed 's/^prompt = "Run the sample\."$/prompt = "Drifted prompt"/' \
    "${TMP_ROOT}/sample-semantic.saved" > "${RESTORE_LIVE}/automation.toml"
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'SHARED_FIELD_MISMATCH\tsample-schedule\tlocal_id=sample-schedule\tfield=prompt' >/dev/null || \
    fail "semantic audit missed shared prompt drift"
  cp "${TMP_ROOT}/sample-semantic.saved" "${RESTORE_LIVE}/automation.toml"

  sed 's/^id = "sample-schedule"$/id = "wrong-live-id"/' \
    "${TMP_ROOT}/sample-semantic.saved" > "${RESTORE_LIVE}/automation.toml"
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'LIVE_ID_MISMATCH\tsample-schedule' >/dev/null || \
    fail "semantic audit missed live id/directory drift"
  cp "${TMP_ROOT}/sample-semantic.saved" "${RESTORE_LIVE}/automation.toml"

  mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/legacy-sample"
  cat > "${CODEX_HOME_UNDER_TEST}/automations/legacy-sample/automation.toml" <<'EOF'
version = 1
id = "legacy-sample"
kind = "cron"
name = "Renamed legacy schedule"
prompt = "Run the sample."
status = "PAUSED"
rrule = "FREQ=DAILY;BYHOUR=8;BYMINUTE=30"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
EOF
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'DUPLICATE_NAME_OR_PROMPT\tsample-schedule' >/dev/null || \
    fail "audit missed a prompt-only legacy duplicate"

  mv "${RESTORE_LIVE}/automation.toml" "${TMP_ROOT}/sample-config.saved"
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'DB_ONLY_FILE_MISSING\tsample-schedule' >/dev/null || \
    fail "audit missed DB-only schedule state"
  mv "${TMP_ROOT}/sample-config.saved" "${RESTORE_LIVE}/automation.toml"

  sqlite3 "${CODEX_HOME_UNDER_TEST}/sqlite/codex-dev.db" \
    "DELETE FROM automations WHERE id='sample-schedule';"
  mv "${RESTORE_LIVE}/automation.toml" "${TMP_ROOT}/sample-config.saved"
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'LEGACY_ALIAS\tsample-schedule\tlocal_id=legacy-sample\tmatch=prompt' >/dev/null || \
    fail "audit did not preserve a prompt-only legacy-id candidate"

  mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/legacy-name-only"
  cat > "${CODEX_HOME_UNDER_TEST}/automations/legacy-name-only/automation.toml" <<'EOF'
version = 1
id = "legacy-name-only"
kind = "cron"
name = "Sample Schedule"
prompt = "Different prompt"
status = "PAUSED"
rrule = "FREQ=DAILY"
model = "gpt-test"
reasoning_effort = "high"
execution_environment = "local"
EOF
  audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
  printf '%s\n' "${audit_output}" | grep -F $'AMBIGUOUS_LEGACY_ALIASES\tsample-schedule' >/dev/null || \
    fail "audit missed name/prompt legacy ambiguity"
  rm "${CODEX_HOME_UNDER_TEST}/automations/legacy-name-only/automation.toml"
  rmdir "${CODEX_HOME_UNDER_TEST}/automations/legacy-name-only"
  expect_failure "${TMP_ROOT}/strict-audit.out" env \
    HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
    AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
    bash "${REPO}/scripts/audit-automation-sync.sh" --strict
  mv "${TMP_ROOT}/sample-config.saved" "${RESTORE_LIVE}/automation.toml"
fi

mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/safe-tool"
printf 'legacy helper copy\n' > \
  "${CODEX_HOME_UNDER_TEST}/automations/safe-tool/legacy-helper.sh"
legacy_audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
printf '%s\n' "${legacy_audit_output}" | grep -F $'LEGACY_TOOL_LOCATION\tsafe-tool' >/dev/null || \
  fail "audit missed legacy portable code in automations namespace"
rm "${CODEX_HOME_UNDER_TEST}/automations/safe-tool/legacy-helper.sh"
printf 'runtime memory stays local\n' > \
  "${CODEX_HOME_UNDER_TEST}/automations/safe-tool/memory.md"
mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/safe-tool/reports"
runtime_only_audit_output="$(HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/audit-automation-sync.sh" --report)"
if printf '%s\n' "${runtime_only_audit_output}" | grep -E \
  $'LEGACY_TOOL_(LOCATION|EMPTY_GHOST|SCHEDULE_COLLISION)\tsafe-tool' >/dev/null; then
  fail "audit misclassified an intentional runtime-only directory as legacy code"
fi

# Snapshot/merge collection must not manufacture shared templates from live TOML.
mkdir -p "${CODEX_HOME_UNDER_TEST}/automations/local-only"
cat > "${CODEX_HOME_UNDER_TEST}/automations/local-only/automation.toml" <<'EOF'
version = 1
id = "local-only"
name = "Local only"
status = "PAUSED"
target = { kind = "project", project_id = "/tmp/example-project" }
EOF
HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/snapshot-from-local.sh" >/dev/null
assert_no_file "${REPO}/automations-templates/local-only/automation.toml"
printf 'locally reviewed command rule\n' > \
  "${CODEX_HOME_UNDER_TEST}/rules/sample.rules"
HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" \
  bash "${REPO}/scripts/snapshot-from-local.sh" >/dev/null
assert_content "locally reviewed command rule" "${REPO}/rules/sample.rules"
HOME="${TEST_HOME}" CODEX_HOME="${CODEX_HOME_UNDER_TEST}" \
  AGENTS_HOME="${AGENTS_HOME_UNDER_TEST}" CODEX_HOST_NAME="test-host" \
  CODEX_MERGE_STATE_ROOT="${TMP_ROOT}/merge-review" \
  COLLECT_STAMP="review" bash "${REPO}/scripts/collect-local-for-merge.sh" >/dev/null
assert_file "${TMP_ROOT}/merge-review/test-host-review/automations-host-state/local-only/automation.toml"
assert_no_file "${REPO}/incoming/test-host-review/automations-host-state/local-only/automation.toml"
assert_content "locally reviewed command rule" \
  "${REPO}/incoming/test-host-review/rules/sample.rules"
assert_no_file "${REPO}/incoming/test-host-review/automations-templates/local-only/automation.toml"

# Guard against reintroducing destructive mirror semantics in any current or
# future shell writer, including runtime restore/seed helpers.
if find "${REPO}/scripts" -type f -name '*.sh' \
  -exec grep -n -- '--delete' {} + >/dev/null; then
  fail "destructive rsync option was reintroduced"
fi

# The earnings notifier must never scan the large investment-data worktree just
# to render diagnostics. On this user's repo, `git status` can block the daily
# automation for minutes even though fetch/show and the actual audit are fine.
if grep -E 'git[^[:cntrl:]]+[[:space:]]status([[:space:]]|$)' \
  "${SOURCE_ROOT}/automation-tools/tw-earnings-fetch-tool/list-pending.sh" >/dev/null; then
  fail "blocking git status was reintroduced into tw-earnings-fetch"
fi

echo "PASS: automation sync adversarial hardening suite"
