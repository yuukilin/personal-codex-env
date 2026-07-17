---
name: codex-env-sync
description: Synchronize the user's personal Codex rules, skills, portable automation tools, and shared automation definitions across two Macs through the private `personal-codex-env` Git repository while preserving each Mac's independent automation switches, targets, working directories, and runtime state. Use for "更新 skill", "同步 skill", "pull 下來", "另一台 Mac 套用", automation sync, or cross-Mac Codex environment repair.
---

# Codex Env Sync

## Goal

Use `~/Documents/Codex/personal-codex-env` as the private sync center for two Macs. The repo carries portable guidance, least-privilege command rules, skills, tools, and shared schedule definitions; live Codex files remain under `~/.codex/` and `~/.agents/`.

Never blend two meaningfully different same-name skills automatically. First show the difference and let the user choose which side is canonical.

Command rules are privilege boundaries. Install and snapshot only Git-tracked rule filenames. Never collect arbitrary local rules, GitHub tokens, `hosts.yml`, `GH_TOKEN`, or `GITHUB_TOKEN`; each Mac owns its own GitHub login.

## Automation Sync Model

The two Macs should contain the same set of schedules, but each Mac owns its own switch and host routing.

Shared automation fields stored in `automations-templates/<id>/automation.toml`:

- `version`, `id`, `kind`, `name`
- `prompt`, `rrule`, `model`, `reasoning_effort`
- `execution_environment`

Host-local fields that must never be copied from one Mac to the other:

- `status` (`ACTIVE` or `PAUSED`)
- `target`, `cwds`
- `created_at`, `updated_at`
- `memory.md`, `last-run.md`, `last-close.md`, `manual-resolutions.json`
- logs, runs, reports, snapshots, cache, auth, sessions, databases, and other runtime state

Existing schedules receive only shared-field updates. Their local `status`, target, and cwd remain unchanged. This is what allows a schedule to be active on one Mac and paused on the other.

Portable helper source belongs in the repo under `automation-tools/<tool-name>/` and installs only to `~/.codex/automation-tools/<tool-name>/`. Portable code must never be installed inside `~/.codex/automations/`. Every tool must contain `.portable-tool`; source and destination must contain no symlink; a tool directory must not share a name with a schedule. Seed files may initialize missing runtime state, but must never overwrite an existing runtime file.

## Non-Negotiable Safety Rules

1. Before every pull, publish, apply, merge review, or repair, run a full local
   backup. On a Mac with any existing automation state, the backup is valid only
   when its manifest reports an authoritative SQLite online backup, a stable
   registry window, and exact DB／live TOML／host-state consistency. DB-only,
   file-only, field drift, or any automation-state symlink must fail before
   install writes. Only a truly fresh Mac with neither registry nor live
   `automation.toml` may use the explicit `fresh_empty` exception.
2. Run sync-layout preflight before any install write. If it reports a template host field, untracked tool directory, missing marker, name collision, or unsafe runtime file, stop and repair the layout first.
3. Never install portable tools into `~/.codex/automations/`, and never use `rsync --delete` against live Codex state. Portable tools install additively under `~/.codex/automation-tools/`; only Git-tracked, marker-approved, regular non-runtime files may deploy, and any source or destination symlink aborts the whole install before writes.
4. Never copy a template TOML directly into `~/.codex/automations/`, and never edit the internal automation database. Create and update schedules only through the Codex automation tool.
5. Never snapshot raw live automation TOMLs back into shared templates. Shared template changes are intentional edits, not filesystem mirroring.
6. After any automation-tool reconciliation, run the strict audit against the exact pre-apply backup printed by `install-mac.sh`. Current DB/TOML agreement alone is not proof that this Mac's host-local fields were preserved.
7. Always show the final diff and obtain the user's confirmation before commit or push.

## Decide the Direction

- This Mac has the newer intended changes and the user says "更新／push"：use Publish Workflow.
- The other Mac already pushed and the user says "pull／套用最新"：use Apply Workflow.
- Both Macs may have changed：use Difference Review; do not install until source-of-truth choices are resolved.
- A schedule disappeared or status differs unexpectedly：use Automation Repair and Reconcile.

## Publish Workflow

Run on the Mac that contains the intended newer rules or skills.

1. Back up live state before touching Git.
2. Pull with `--ff-only`; if it fails, stop and use Difference Review.
3. Snapshot rules and skills. The snapshot script must not copy raw live automation TOMLs or runtime data.
4. If a shared automation definition intentionally changed, edit only its allowed shared fields in `automations-templates/`.
5. Run layout validation and inspect the complete diff.
6. Explain the changed behavior in plain language and ask the user to confirm.
7. Only after explicit confirmation, stage the intended sync-managed paths, commit, and push.

```bash
cd ~/Documents/Codex/personal-codex-env
./scripts/backup-current.sh
git pull --ff-only
./scripts/snapshot-from-local.sh
./scripts/validate-sync-layout.sh
git status --short -- AGENTS.md rules skills agents-skills automations-templates automation-tools scripts tests
git diff -- AGENTS.md rules skills agents-skills automations-templates automation-tools scripts tests
```

Do not run `git add`, `git commit`, or `git push` until the user has reviewed this diff and confirmed. If there are no changes, do not create an empty commit.

## Apply Workflow

Run on the Mac receiving the repo version.

1. Back up live state before pulling.
2. Check for meaningful unsynced same-name skill or command-rule changes. If present, stop and use Difference Review.
3. Pull latest `main` with `--ff-only`.
4. Run the installer. It must repeat preflight before writes and create another
   post-pull backup before installing; a failed three-way consistency gate stops
   the apply.
5. Record the exact post-pull backup path printed by the installer; this is the apply baseline.
6. Audit shared definitions against this Mac's live schedules.
7. Reconcile schedules using the automation tool while preserving host-local fields.
8. Run strict baseline audit with that exact backup before closing the apply.

```bash
cd ~/Documents/Codex/personal-codex-env
./scripts/backup-current.sh
git pull --ff-only
./scripts/install-mac.sh
./scripts/audit-automation-sync.sh --strict --baseline-backup <install-mac 印出的備份目錄>
```

If pull histories diverge, preflight fails, or a newer local same-name skill exists, do not install.

## Automation Repair and Reconcile

For every shared template:

1. Inspect the live schedule through the Codex automation tool and the local host-state backup.
2. If the exact template ID exists, update only shared fields through the automation tool. Preserve local `status`, target, and cwd exactly.
3. If the ID is missing, search live schedules for the same `name` or materially identical `prompt`. Treat a match as a legacy ID candidate; do not create a duplicate until it is reviewed.
4. If truly missing, recover `status`, target, and cwd from the newest local host-state or backup, then create it through the automation tool.
5. If no local host-state exists anywhere, create the missing schedule as `PAUSED` and report that the user must choose its target/cwd and whether to activate it.
6. Re-run the strict audit with the exact pre-apply backup. Verify the live registry plus schedule files agree and the baseline reports no host-local drift. A directory alone is not proof that a schedule exists.

The baseline freezes `status`, full target, `cwds`, and `created_at` for existing schedules. `updated_at` may advance only when shared fields actually changed. A genuinely new template schedule with no recoverable local state may appear only as `PAUSED`; any other unbaselined schedule is a hard stop.

Before deleting or recreating any schedule ID, keep a full runtime copy outside `~/.codex/automations/<id>/`. The Codex automation tool may remove that directory even when cleaning up a ghost ID. After recreation, restore only missing runtime files from the verified backup, never overwrite the new `automation.toml`, and verify memory, last-run, last-close, manual state, DB status, and next run again.

For runtime seeds such as `manual-resolutions.seed.json`, copy the seed to the schedule runtime name only when that runtime file does not exist. Existing runtime state is authoritative and must never be overwritten by install or pull.

For `tw-earnings-fetch`, if the schedule is missing and `~/.codex/automations/tw-earnings-fetch/manual-resolutions.json` is also missing, first validate `~/.codex/automation-tools/tw-earnings-fetch-tool/manual-resolutions.seed.json`, then copy it once to the runtime path. Never replace an existing runtime file. Only after that state check passes may the automation tool restore the saved host status or create a no-host-state schedule as `PAUSED`.

For `component-market-tracker`, portable code lives under `~/.codex/automation-tools/component-market-tracker/`, while historical state remains under `~/.codex/automations/component-market-tracker/`. If the runtime `memory.md` is missing, validate the code-side `memory.seed.md` and copy it once to the runtime directory. The installer must not create a code-root `memory.md`, and must never overwrite existing runtime memory, reports, runs, or snapshots.

## Difference Review

Before any install, compare repo and local copies. Ignore empty local folders without a `SKILL.md`; do not ignore meaningful content differences.

For each same-name difference report:

```text
差異清單：
1. skill-name
   - repo：一句話說明 repo 版行為
   - 本機：一句話說明本機版行為
   - 建議：repo / 本機 / 需要你決定

請選：
A. 用 repo 版
B. 用本機版
C. 先不要動
```

Timestamps are only a weak clue. Do not combine two versions unless the user explicitly requests a merge.

## First-Time Setup on the Other Mac

The other Mac may not know this skill yet. After cloning the private repo, run:

```bash
cd ~/Documents/Codex/personal-codex-env
./scripts/backup-current.sh
git pull --ff-only
./scripts/install-mac.sh
./scripts/audit-automation-sync.sh --strict --baseline-backup <install-mac 印出的備份目錄>
```

Then use Automation Repair and Reconcile to create only genuinely missing schedules. Missing schedules without recoverable local host-state start paused. Restart Codex if the skill list does not refresh.

The installer deploys only tracked command rules. If GitHub CLI is needed, run `gh auth login` separately on that Mac; authentication state never comes from this repo.

## User-Facing Explanation

Use plain language:

- "排程內容會同步，但每台電腦的開關、target 和工作目錄各自保存。"
- "套用前會先備份與檢查；安裝不會再用空目錄刪 live 排程。"
- "缺少排程會先找舊 ID 與本機備份，找不到狀態才用暫停建立。"
- "我會先給你看完整差異；你確認後才 commit／push。"
