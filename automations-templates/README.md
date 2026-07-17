# Automations Templates

這裡保存的是兩台 Mac 共用的 automation「定義」，不是任何一台 Mac 的完整 live 設定。

## 共用與本機欄位

模板只允許這些共用欄位：

- `version`
- `id`
- `kind`
- `name`
- `prompt`
- `rrule`
- `model`
- `reasoning_effort`
- `execution_environment`

以下欄位必須由每台 Mac 自己保存，不得 commit 到這個目錄：

- `status`：每台可獨立 `ACTIVE` 或 `PAUSED`
- `target`、`cwds`：每台可指向不同專案或工作目錄
- `created_at`、`updated_at`
- `memory.md`、`last-run.md`、`last-close.md`、`manual-resolutions.json`
- logs、runs、reports、snapshots、cache 與其他執行輸出

因此兩台 Mac 會擁有相同排程名稱、prompt、時間與模型，但開關、target 與 cwd 不會互相覆蓋。

## 套用規則

1. `pull/apply` 前先做完整備份，再跑同步 preflight；任何碰撞、空的未追蹤工具目錄或不合法欄位都要先停止。
2. 已存在的排程只更新共用欄位，保留該 Mac 原本的 `status`、`target` 與 `cwd`。
3. 模板 ID 在本機不存在時，先比對同名或相同 prompt 的 legacy 排程，避免建立重複排程。
4. 確認真的缺少時，先從本機 host-state／備份恢復；沒有任何本機狀態才以 `PAUSED` 建立。
5. 建立或更新排程一律使用 Codex automation tool；不要把模板 TOML 直接複製到 `~/.codex/automations/`，也不要直接改內部資料庫。
6. portable tool 只能增量部署 Git 已追蹤、無 symlink、無 runtime 狀態的檔案到 `~/.codex/automation-tools/`；不得再安裝進 `~/.codex/automations/`，也禁止用 `rsync --delete` 對任何 live 目錄做鏡像同步。
7. 若排程需要刪除／重建 ID，先把 runtime 備份到 automation 目錄之外；重建後只恢復缺少的 runtime 檔，不得覆寫新建的 `automation.toml`。

## 發布規則

不要用 raw live `automation.toml` 覆寫模板。若共用定義真的改變，明確編輯對應模板並驗證只含允許欄位；先備份並顯示差異，取得使用者確認後才能 commit／push。
