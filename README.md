# personal-codex-env

這個 repo 用來同步兩台 Mac 的 Codex guidance、最小權限 command rules、skills、可攜 automation 工具與排程共用定義。

它只保存可攜帶的文字規則與 skill，不保存登入狀態、API key、session、logs、cache 或本機資料庫。

## 內容

```text
AGENTS.md                 # Codex 全域規則
OBSIDIAN-MCP-SINGLE-WRITER.md # 兩台 Mac 的 Obsidian MCP 單一寫入端規則
rules/                    # 可攜且最小權限的 ~/.codex/rules；不含 token
skills/                   # ~/.codex/skills 的 user skills，不含 .system
agents-skills/            # ~/.agents/skills 的遷移 skills
automations-templates/    # 排程共用定義，不含每台 Mac 的開關、target、cwd 或時間戳
automation-tools/         # 可攜 automation 程式碼，不放 memory、last-run、reports 等執行狀態
config.template.toml      # 安全版 Codex config 範例，不含 token
scripts/install-mac.sh    # 在另一台 Mac 套用 rules / skills / automation 工具包
scripts/backup-current.sh # 套用前備份並核對 DB、live TOML、host-state
scripts/validate-incoming-merge.sh # incoming commit 前檢查已知 host-state、runtime 與秘密檔名
```

## 不同步

```text
auth.json
~/.config/gh/hosts.yml 與 macOS 鑰匙圈中的 GitHub OAuth 權杖
config.toml 原檔
sessions/
logs_*.sqlite
state_*.sqlite
goals_*.sqlite
cache/
plugins/cache/
shell_snapshots/
automation live TOML、memory、last-run、reports、snapshots 與其他每台 Mac runtime
*.token
*.key
.env
```

## 在新 Mac 使用

先 clone 這個 private repo，然後執行：

```bash
./scripts/backup-current.sh
./scripts/install-mac.sh
# 將下一行路徑換成 install-mac.sh 剛印出的精確備份目錄
./scripts/audit-automation-sync.sh --strict --baseline-backup /path/to/exact-backup
```

安裝後需要手動處理：

1. 登入 Codex。
2. `install-mac.sh` 會安裝 repo 已追蹤的最小權限 command rules；若要使用 GitHub CLI，另在這台 Mac 執行 `gh auth login`。OAuth 權杖只留在本機鑰匙圈，不進 repo。
3. 先讀 `OBSIDIAN-MCP-SINGLE-WRITER.md`。兩台 Mac 都可以執行 `./scripts/setup-obsidian-mcp.sh`，在本機建立並重新簽章 Obsidian MCP server；新 Mac 的寫入型排程預設為 `PAUSED`，完成寫入端交接後才啟用。
4. 依照 `config.template.toml` 建立或調整 `~/.codex/config.toml`。
5. 確認 Obsidian Local REST API 的 API key 與 vault 路徑。
6. 重新啟動 Codex，讓 command rules、MCP tools 與 skills 重新載入。
7. `install-mac.sh` 只安裝可攜工具與共用模板，不直接改 live 排程，並會印出這次的本機 baseline 備份路徑；每次 apply 關帳前都必須用該路徑跑 strict baseline audit。若其後又由 Codex automation tool 補齊或更新排程，則在全部調整完成後再跑一次，以最後結果關帳。
8. 兩台 Mac 應有同一組排程，但各自保存 `ACTIVE`／`PAUSED`、target 與 cwd；任何一台的開關都不得覆寫另一台。會寫入 Obsidian 的排程同一時間只在目前寫入端啟用，另一台維持 `PAUSED`。

既有機器在安裝前必須通過三方一致性門檻：automation 資料庫、live
`automation.toml` 與本機 host-state 的排程集合和欄位要完全一致，而且 SQLite
備份期間不得發生變動。DB-only、file-only、欄位漂移或 symlink 都會在任何安裝
寫入前中止；只有完全沒有資料庫也沒有 live 排程檔的新機器可走首次安裝例外。

## Obsidian MCP 單一寫入端

- Rules 與 skills 同步兩台。
- Obsidian 筆記透過 iCloud 同步。
- MCP binary、真實 config 與 API key 留在各自本機，不進 repo。
- 兩台 Mac 都可以寫入，但同一時間只允許一台執行人工編輯、Obsidian MCP 寫入與相關排程。
- 寫入端是可交接的暫時狀態；新 Mac 的寫入型排程預設為 `PAUSED`。交接、更新外掛與故障修復流程見 `OBSIDIAN-MCP-SINGLE-WRITER.md`。

## GitHub CLI 與兩台 Mac

- 兩台 Mac 可以登入同一個 GitHub 帳號，但各自透過 `gh auth login` 取得自己的 OAuth 權杖。
- `rules/gh-automation.rules` 只允許登入檢查、明確觸發 workflow，以及查看 workflow/run；不開放全部 `gh` 指令。
- installer 只部署 Git 已追蹤、無 symlink 的 rule 檔；不會同步權杖、`hosts.yml`、`auth.json`、`GH_TOKEN` 或 `GITHUB_TOKEN`。
- 若沙盒內顯示 token invalid，先在核准的沙盒外環境重跑 `gh auth status`；macOS 鑰匙圈在沙盒內不可讀時可能造成假性失敗。

## 更新流程

你可以直接對 Codex 說：

- `更新 skill`：表示這台 Mac 剛改完，要 snapshot、commit、push 到 GitHub。
- `另一台 Mac 更新 skill，幫我 pull 下來`：表示 GitHub 已有新版本，這台要 pull、backup、install。
- `兩台 Mac 的 skill 都有改`：先不要安裝，請 Codex 走融合流程。

另一台 Mac 第一次還沒有拿到 `codex-env-sync` 這個 skill 時，請先把這段貼給那台 Mac 的 Codex：

```text
請先執行這段，取得最新 personal-codex-env，備份目前設定，並安裝最新 Codex skills。完成後如果 skill 清單沒刷新，請提醒我重開 Codex。
```

然後讓它執行：

```bash
cd ~/Documents/Codex/personal-codex-env
./scripts/backup-current.sh
git pull --ff-only
./scripts/install-mac.sh
# 將下一行路徑換成 install-mac.sh 剛印出的精確備份目錄
./scripts/audit-automation-sync.sh --strict --baseline-backup /path/to/exact-backup
```

這次完成後，另一台 Mac 也會有 `codex-env-sync`，以後就可以用同一套說法同步。

手動操作版如下。

在改完 skill 的那台 Mac：

```bash
cd ~/Documents/Codex/personal-codex-env
./scripts/backup-current.sh
git pull --ff-only
./scripts/snapshot-from-local.sh
./scripts/validate-sync-layout.sh
./tests/test-automation-sync.sh
git status --short -- AGENTS.md OBSIDIAN-MCP-SINGLE-WRITER.md rules skills agents-skills automations-templates automation-tools scripts tests README.md MANIFEST.md OTHER-MAC-CODEX-HANDOFF.md
git diff -- AGENTS.md OBSIDIAN-MCP-SINGLE-WRITER.md rules skills agents-skills automations-templates automation-tools scripts tests README.md MANIFEST.md OTHER-MAC-CODEX-HANDOFF.md
```

先讓使用者確認完整差異；確認後才執行，而且只加入這次確定要發布的檔案，禁止使用 `git add .`：

```bash
git add <本次確認過的檔案>
git commit -m "Update Codex skills"
git push
```

在要接收更新的另一台 Mac：

```bash
cd ~/Documents/Codex/personal-codex-env
./scripts/backup-current.sh
git pull --ff-only
./scripts/install-mac.sh
# 將下一行路徑換成 install-mac.sh 剛印出的精確備份目錄
./scripts/audit-automation-sync.sh --strict --baseline-backup /path/to/exact-backup
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

這會把另一台 Mac 的 `AGENTS.md`、repo 已追蹤名稱的 command rules、`~/.codex/skills` 與 `~/.agents/skills` 收集到 `incoming/`，方便之後比較。完整 automation host-state 會另存到該台 Mac 的 `~/.codex-env-backups/merge-review/`，不會進 Git，也不得安裝到另一台。`git add incoming` 前必須先執行 `./scripts/validate-incoming-merge.sh`；已知 host-state／runtime 路徑、常見秘密檔名或 symlink 都會令檢查失敗，但仍須人工檢查實際內容。確認要保留哪些規則或 skill 差異後，再把需要的檔案合併回 `rules/`、`skills/`、`agents-skills/` 或 `AGENTS.md`；共用排程定義必須另外明確編輯並驗證。

只有在合併完成、repo 已確認是你要的版本之後，才執行：

```bash
./scripts/install-mac.sh
# 將下一行路徑換成 install-mac.sh 剛印出的精確備份目錄
./scripts/audit-automation-sync.sh --strict --baseline-backup /path/to/exact-backup
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
