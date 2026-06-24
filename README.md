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

你可以直接對 Codex 說：

- `更新 skill`：表示這台 Mac 剛改完，要 snapshot、commit、push 到 GitHub。
- `另一台 Mac 更新 skill，幫我 pull 下來`：表示 GitHub 已有新版本，這台要 pull、backup、install。
- `兩台 Mac 的 skill 都有改`：先不要安裝，請 Codex 走融合流程。

手動操作版如下。

在改完 skill 的那台 Mac：

```bash
cd ~/Documents/Codex/personal-codex-env
./scripts/snapshot-from-local.sh
git status
git add .
git commit -m "Update Codex skills"
git push
```

在要接收更新的另一台 Mac：

```bash
cd ~/Documents/Codex/personal-codex-env
git pull --ff-only
./scripts/backup-current.sh
./scripts/install-mac.sh
```

如果 `git pull --ff-only` 失敗，代表兩邊可能都改過；先停下來，不要跑 `install-mac.sh`。

## 另一台 Mac 的 skills 不一樣時

不要先跑 `install-mac.sh`，那會把 repo 版本裝到本機，可能蓋掉另一台 Mac 的差異。

先在另一台 Mac 做融合用快照：

```bash
./scripts/backup-current.sh
./scripts/collect-local-for-merge.sh
git status
```

這會把另一台 Mac 的 `AGENTS.md`、`~/.codex/skills`、`~/.agents/skills`、automation 模板收集到 `incoming/`，方便之後比較與合併。確認要保留哪些差異後，再把需要的檔案合併回 `skills/`、`agents-skills/` 或 `AGENTS.md`。

只有在合併完成、repo 已確認是你要的版本之後，才執行：

```bash
./scripts/install-mac.sh
```

## 建立遠端 private repo

目前這個 repo 已經是本機 Git repo。遠端 GitHub repo 建好後，在本資料夾執行：

```bash
./scripts/connect-remote.sh git@github.com:OWNER/personal-codex-env.git
```

或：

```bash
./scripts/connect-remote.sh https://github.com/OWNER/personal-codex-env.git
```

遠端 repo 必須是 private，而且建議先建立空 repo，不要勾選 README / .gitignore / license，避免第一次 push 要處理 merge。
