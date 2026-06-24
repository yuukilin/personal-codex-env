---
name: codex-env-sync
description: Synchronize the user's personal Codex environment across two Macs through the private `personal-codex-env` Git repository. Use when the user says things like "更新 skill", "同步 skill", "我改了 skill", "把 skill push 上去", "另一台 Mac 更新 skill", "pull 下來", "套用最新 Codex skills", or asks how to keep Codex rules, skills, `.agents/skills`, and automation templates synced between Macs.
---

# Codex Env Sync

## Overview

Help the user keep two Macs on the same Codex rules and skills by using the private Git repo at `~/Documents/Codex/personal-codex-env`.

Treat this repo as the sync center. The live files are still under `~/.codex/` and `~/.agents/`; the repo only stores the portable copy.

## First-Time Setup on the Other Mac

If the other Mac has not installed the latest repo version yet, it will not know this skill. In that case, give that Mac's Codex this exact message:

```text
請先執行這段，取得最新 personal-codex-env，備份目前設定，並安裝最新 Codex skills。完成後如果 skill 清單沒刷新，請提醒我重開 Codex。
```

Then run:

```bash
cd ~/Documents/Codex/personal-codex-env
git pull --ff-only
./scripts/backup-current.sh
./scripts/install-mac.sh
```

After this one-time install, the other Mac can use the same natural-language triggers such as "更新 skill" and "另一台 Mac 更新 skill，幫我 pull 下來".

## Decide the Direction

First identify what the user means:

- If the user changed skills on this Mac and says "更新 skill" or "push 上去", run the publish workflow.
- If another Mac already pushed changes and the user says "pull 下來", "套用最新", or "另一台 Mac 更新 skill", run the apply workflow.
- If both Macs may have changed skills, do not overwrite. Run the merge-safety workflow and explain that manual fusion is needed.

Default repo path:

```bash
~/Documents/Codex/personal-codex-env
```

## Publish Workflow

Use this on the Mac where the user just changed live skills/rules.

1. Go to the repo.
2. Snapshot live Codex files into the repo.
3. Show `git status` to confirm what changed.
4. Commit and push.

Commands:

```bash
cd ~/Documents/Codex/personal-codex-env
./scripts/snapshot-from-local.sh
git status
git add .
git commit -m "Update Codex skills"
git push
```

If there are no changes after the snapshot, do not commit. Tell the user there was nothing new to sync.

## Apply Workflow

Use this on the Mac that should receive the latest skills from GitHub.

1. Go to the repo.
2. Pull the latest main branch.
3. Back up current live Codex files.
4. Install repo files into `~/.codex/` and `~/.agents/`.

Commands:

```bash
cd ~/Documents/Codex/personal-codex-env
git pull --ff-only
./scripts/backup-current.sh
./scripts/install-mac.sh
```

If `git pull --ff-only` fails because histories diverged, stop. Do not run `install-mac.sh`; switch to merge-safety workflow.

## Merge-Safety Workflow

Use this when the user says both Macs have different skills, or when pull/commit shows conflicts.

Rules:

- Do not run `install-mac.sh` until the merge is resolved.
- Do not overwrite live `~/.codex/skills` without first running `backup-current.sh`.
- Preserve `~/.codex/skills/.system`; it contains Codex system skills and must not be copied into the repo or deleted during install.
- Use `collect-local-for-merge.sh` on the Mac with unsynced local changes.
- Compare `incoming/` against `skills/`, `agents-skills/`, `AGENTS.md`, and `automations-templates/`.
- Preserve host-specific automation status and schedules unless the user explicitly asks to change them.
- Keep secrets out of the repo: never commit `auth.json`, live `config.toml`, API keys, tokens, sessions, logs, cache, or local state databases.

Commands for collecting local differences:

```bash
cd ~/Documents/Codex/personal-codex-env
./scripts/backup-current.sh
./scripts/collect-local-for-merge.sh
git status
```

After fusion is complete, commit and push the merged repo. Only then run the apply workflow on the other Mac.

## User-Facing Explanation

Explain it simply:

- "改完的人負責 snapshot、commit、push。"
- "另一台只要 pull、backup、install。"
- "兩台都改過就先不要 install，要先融合。"
- "Git repo 是同步中心；真正 Codex 在用的是 `~/.codex/skills`。"
