# Manifest

更新日期：2026-07-16

## 已納入

| 類別 | 數量 | 來源 |
|---|---:|---|
| Codex 全域規則 | 1 | `~/.codex/AGENTS.md` |
| Codex command rules | 1 | `rules/gh-automation.rules`；不含 token，安裝到 `~/.codex/rules/` |
| Codex user skills | 44 | `~/.codex/skills`，排除 `.system` |
| `.agents` skills | 8 | `~/.agents/skills` |
| Automation 共用定義 | 7 | `automations-templates/`；只含 allowlist 欄位，不從 live TOML 自動同步 |
| Automation 可攜工具包 | 2 | `automation-tools/`；安裝到 `~/.codex/automation-tools/`，不與 live schedules 共用目錄 |
| Automation 本機狀態 | 每台獨立 | `~/.codex/automations/`；只做本機備份與 host-state 檢查，不進 main |
| 安裝/備份/驗證/稽核/融合/遠端連接/Obsidian MCP 修復腳本 | 13 | `scripts/` |

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
- automation live TOML 與執行輸出，例如 `memory.md`、`last-run.md`、`manual-resolutions.json`
- component-market-tracker 的 `runs/`、`reports/`、`snapshots/`、`__pycache__/`
- API key、token、`.env`
- `~/.codex/mcp/obsidian-mcp-tools/mcp-server` 為每台 Mac 本機重建，不放入 repo。

## 安全檢查

- live Obsidian API key 未放入 repo。
- GitHub CLI 權杖未放入 repo；兩台 Mac 各自登入並保存在本機鑰匙圈。
- `config.template.toml` 只保留 placeholder。
- 所有 `SKILL.md` 已檢查 frontmatter，至少包含 `name` 與 `description`。
- 既有 automation state 必須通過 DB／live TOML／host-state 三方一致性與穩定
  SQLite 視窗；DB-only、file-only、欄位漂移或 symlink 會在安裝前中止。

## 下一台 Mac 套用順序

1. Clone private repo。
2. 執行 `./scripts/backup-current.sh`。
3. 執行 `./scripts/install-mac.sh`。
4. 若要使用 GitHub CLI，在這台 Mac 執行 `gh auth login`；command rule 已由 installer 安裝，權杖不會同步。
5. 執行 `./scripts/setup-obsidian-mcp.sh`，建立本機簽章版 Obsidian MCP server。
6. 手動檢查 `~/.codex/config.toml` 或從 `config.template.toml` 改寫。
7. 登入 Codex 並確認 Obsidian MCP API key。
8. 記下 `install-mac.sh` 印出的精確 baseline 備份路徑；由 Codex automation tool 補齊或更新排程後，執行 `./scripts/audit-automation-sync.sh --strict --baseline-backup <該路徑>`。禁止直接複製 template TOML 或修改內部資料庫。
9. 兩台 Mac 保有相同排程集合，但各自維持 `ACTIVE`／`PAUSED`、target 與 cwd。
