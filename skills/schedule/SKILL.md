---
name: schedule
description: 'Create, update, view, or delete Codex automations, recurring runs, reminders, monitors, and thread follow-ups. Use when the user says things like "every day", "each morning", "remind me in an hour", "run this at noon", "keep checking", "notify me", or wants to reschedule an existing task.'
---

# Codex Automations

Use the Codex automation tool for reminders, recurring work, monitors, and follow-ups. Do not write raw automation files or RRULE strings by hand for the user.

## First Decision

Decide whether the user wants:

- **Heartbeat follow-up** attached to the current thread: short reminders, "check back later", "continue this in 30 minutes", or anything that should wake up this conversation.
- **Cron automation** detached from the thread: recurring workspace jobs, monitors, daily/weekly reports, CI checks, or tasks that should run against files/repos.
- **Update/delete/view** of an existing automation.

Prefer heartbeat for follow-ups under one hour or when the user clearly wants this same thread to continue.

## Updating Existing Automations

If the user wants to reschedule, edit, pause, resume, view, or delete an existing automation:

1. Inspect `$CODEX_HOME/automations/*/automation.toml` to find the matching automation by name or prompt.
2. Prefer updating the existing automation over creating a duplicate.
3. Preserve existing fields unless the user asks to change them.
4. Use the automation tool with the resolved id.

## Creating New Automations

Draft a self-contained prompt for future runs. Future runs may not have this conversation, so avoid "above", "this chat", or unstated context.

Include:

- A clear objective.
- Specific paths, URLs, repositories, or data sources.
- Expected output.
- Constraints and user preferences.

Choose a short human-readable name.

For cron automations, interpret requested times in the user's locale. If a workspace setup config is needed, use a suggested create/update so the user can review it first.

Finally, call the Codex automation tool. For ambiguous schedules, ask one concise clarification question before creating anything.
