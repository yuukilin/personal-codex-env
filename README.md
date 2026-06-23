# personal-codex-env

這個 repo 用來同步兩台 Mac 的 Codex rules / skills。

它只保存可攜帶的文字規則與 skill，不保存登入狀態、API key、session、logs、cache 或本機資料庫。

## 內容

```text
AGENTS.md                 # Codex 全域規則
skills/                   # ~/.codex/skills 的 user skills，不含 .system
agents-skills/            # ~/.agents/skills 的遷移 skills
automations-templates/    # Codex automation 設定模板，只放 automation.toml
config.template.toml      # 安全版 Codex config 範例，不含 token
scripts/install-mac.sh    # 在另一台 Mac 套用 rules / skills
scripts/backup-current.sh # 套用前備份當前本機設定
```

## 不同步

```text
auth.json
config.toml 原檔
sessions/
logs_*.sqlite
state_*.sqlite
goals_*.sqlite
cache/
plugins/cache/
shell_snapshots/
*.token
*.key
.env
```

## 在新 Mac 使用

先 clone 這個 private repo，然後執行：

```bash
./scripts/backup-current.sh
./scripts/install-mac.sh
```

安裝後需要手動處理：

1. 登入 Codex。
2. 依照 `config.template.toml` 建立或調整 `~/.codex/config.toml`。
3. 重新設定 Obsidian MCP 的 API key。
4. 確認 Obsidian vault 路徑。
5. 只在一台 Mac 啟用 automations。

## 更新流程

在主要 Mac 改完 skill 後：

```bash
./scripts/snapshot-from-local.sh
git status
git add .
git commit -m "Update Codex skills"
git push
```

在另一台 Mac：

```bash
git pull
./scripts/install-mac.sh
```
