# Manifest

更新日期：2026-06-30

## 已納入

| 類別 | 數量 | 來源 |
|---|---:|---|
| Codex 全域規則 | 1 | `~/.codex/AGENTS.md` |
| Codex user skills | 42 | `~/.codex/skills`，排除 `.system` |
| `.agents` skills | 8 | `~/.agents/skills` |
| Automation 模板 | 6 | `~/.codex/automations/*/automation.toml` 與另一台 Mac incoming |
| 安裝/備份/融合/遠端連接/Obsidian MCP 修復腳本 | 6 | `scripts/` |

## 已排除

- `~/.codex/auth.json`
- `~/.codex/config.toml` 原檔
- `~/.codex/sessions`
- `~/.codex/logs_*.sqlite*`
- `~/.codex/state_*.sqlite*`
- `~/.codex/goals_*.sqlite*`
- `~/.codex/cache`
- `~/.codex/plugins/cache`
- `~/.codex/skills/.system`
- automation 執行輸出，例如 `last-run.md`、`memory.md`
- API key、token、`.env`
- `~/.codex/mcp/obsidian-mcp-tools/mcp-server` 為每台 Mac 本機重建，不放入 repo。

## 安全檢查

- live Obsidian API key 未放入 repo。
- `config.template.toml` 只保留 placeholder。
- 所有 `SKILL.md` 已檢查 frontmatter，至少包含 `name` 與 `description`。

## 下一台 Mac 套用順序

1. Clone private repo。
2. 執行 `./scripts/backup-current.sh`。
3. 執行 `./scripts/install-mac.sh`。
4. 執行 `./scripts/setup-obsidian-mcp.sh`，建立本機簽章版 Obsidian MCP server。
5. 手動檢查 `~/.codex/config.toml` 或從 `config.template.toml` 改寫。
6. 登入 Codex 並確認 Obsidian MCP API key。
7. 只選一台 Mac 啟用 automations。
