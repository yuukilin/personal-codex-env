# Manifest

更新日期：2026-07-15

## 已納入

| 類別 | 數量 | 來源 |
|---|---:|---|
| Codex 全域規則 | 1 | `~/.codex/AGENTS.md` |
| Codex command rules | 1 | `~/.codex/rules/gh-automation.rules`，不含 token |
| Codex user skills | 42 | `~/.codex/skills`，排除 `.system` |
| `.agents` skills | 8 | `~/.agents/skills` |
| Automation 模板 | 自動同步 | `~/.codex/automations/*/automation.toml` 與另一台 Mac incoming |
| Automation 可攜工具包 | 1 | `~/.codex/automations/component-market-tracker`，排除 raw/reports/snapshots |
| 安裝/備份/融合/遠端連接/Obsidian MCP 修復腳本 | 6 | `scripts/` |

## 已排除

- `~/.codex/auth.json`
- `~/.config/gh/hosts.yml` 與 macOS 鑰匙圈中的 GitHub OAuth 權杖
- `~/.codex/config.toml` 原檔
- `~/.codex/sessions`
- `~/.codex/logs_*.sqlite*`
- `~/.codex/state_*.sqlite*`
- `~/.codex/goals_*.sqlite*`
- `~/.codex/cache`
- `~/.codex/plugins/cache`
- `~/.codex/skills/.system`
- automation 執行輸出，例如 `last-run.md`
- component-market-tracker 的 `runs/`、`reports/`、`snapshots/`、`__pycache__/`
- API key、token、`.env`
- `~/.codex/mcp/obsidian-mcp-tools/mcp-server` 為每台 Mac 本機重建，不放入 repo。

## 安全檢查

- live Obsidian API key 未放入 repo。
- GitHub CLI 權杖未放入 repo；兩台 Mac 各自登入並保存在本機鑰匙圈。
- `config.template.toml` 只保留 placeholder。
- 所有 `SKILL.md` 已檢查 frontmatter，至少包含 `name` 與 `description`。

## 下一台 Mac 套用順序

1. Clone private repo。
2. 執行 `./scripts/backup-current.sh`。
3. 執行 `./scripts/install-mac.sh`。
4. 執行 `mkdir -p ~/.codex/rules && cp rules/gh-automation.rules ~/.codex/rules/gh-automation.rules`。
5. 若要使用 GitHub CLI，執行 `gh auth login`；每台 Mac 各自登入一次。
6. 執行 `./scripts/setup-obsidian-mcp.sh`，建立本機簽章版 Obsidian MCP server。
7. 手動檢查 `~/.codex/config.toml` 或從 `config.template.toml` 改寫。
8. 登入 Codex 並確認 Obsidian MCP API key。
9. 重新啟動 Codex，載入 command rules 與 MCP tools。
10. `install-mac.sh` 只會把 automation templates 複製到 `~/.codex/automation-templates`，不會自動啟用排程。
11. 只選一台 Mac 啟用 automations。
