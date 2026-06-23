---
name: setup-cowork
description: "Audit and adapt a Claude Cowork setup for Codex. Use when the user asks about moving from Cowork/Claude to Codex, checking imported skills, CLAUDE.md/AGENTS.md rules, plugins, connectors, MCP tools, or migration compatibility."
---

# Cowork To Codex Setup Audit

Help the user verify that a Cowork or Claude setup works correctly in Codex. Focus on practical compatibility, not onboarding widgets.

## Audit Checklist

Check these areas:

1. **Global instructions**: `AGENTS.md`, imported `CLAUDE.md` content, language/date/source rules.
2. **Skills**: every `SKILL.md` has valid YAML frontmatter with `name` and `description`; no broken trigger descriptions.
3. **Claude-only assumptions**: references to Claude artifacts, Claude Code slash commands, old scheduled-task tools, `Read/Edit/Write` tool names, or automatic subagents.
4. **Codex tools**: Browser, Chrome, Computer Use, Google Drive, GitHub, Obsidian MCP, node_repl, automations, and any configured MCP servers.
5. **Connectors**: verify installed app connectors with available tools when safe and non-mutating.
6. **High-risk workflows**: Obsidian writes, web scraping, financial/news search, report generation, and recurring automations.

## How To Inspect

Use local file inspection first. Prefer `rg` and `find` for locating imported files and `ruby -ryaml` or an equivalent parser for YAML validation. Do not treat raw string matches like "Claude" as automatically broken; classify whether the reference is:

- **Blocking**: invalid YAML, missing `SKILL.md`, missing frontmatter, unavailable tool name, or workflow that cannot run in Codex.
- **Needs adaptation**: Claude/Cowork wording that would steer Codex toward the wrong tool, but is easy to rewrite.
- **Cosmetic**: "Claude" used as a generic assistant name in prose where behavior remains correct.

## Common Migration Fixes

- Convert `CLAUDE.md` guidance into `AGENTS.md` guidance.
- Replace old scheduled-task tools with Codex automations.
- Replace Claude artifacts with local HTML files, dev servers, or Codex app-renderable outputs.
- Replace "open a fresh Claude/subagent" instructions with inline review unless the user explicitly requests delegated agents.
- Replace Claude-specific connector setup instructions with available Codex plugins/connectors.
- For Obsidian, prefer the Obsidian MCP tools when available; otherwise clearly state the limitation.
- For browser work, prefer Browser/Chrome tools when available; use terminal-based Playwright only when that is the better fit.

## Output

Give the user a short status report:

- What works now.
- What was fixed.
- What still needs manual connection, login, or user approval.
- Any workflows that should be tested with a real prompt next.
