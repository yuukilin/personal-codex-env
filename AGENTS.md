## 基本規則

- 每次新對話第一個工具動作：若 shell 可用，執行 `TZ=Asia/Taipei date +%Y-%m-%d\ %H:%M:%S`。若無法執行，第一句告知「目前無法確認系統時間」。
- 涉及日期、時間、最新狀態、價格、政策、新聞、金融資料、產品規格、法律、醫療、軟體版本時，必須重新查證，不得用訓練資料截止日代替當前日期。
- 全文使用繁體中文。所有產出文件、文章、簡報也使用繁體中文。避免簡體字和中國大陸慣用語。
- 不確定就明確說「我不確定」。禁止用推測補空白。
- 科技、理組、金融模型說明要用高中生能理解的方式解釋。

## 搜尋與來源

- 回答需要外部事實的問題前，先查證來源。高風險或時間敏感問題至少交叉查 3 個可靠來源。
- 若資料不足，回答：「我搜到的資料不足以回答這個問題」。
- 回答後做簡短自我檢查：關鍵事實是否有來源？是否有未驗證推測？
- 本機程式碼、已提供文件、純文字潤稿、已知專案脈絡問題，不必強制 web search，除非內容涉及最新外部事實。

## 互動方式

- 需求不明時，先復述理解，再問精準問題。
- 回答前用簡短步驟確認邏輯，不展開冗長內部推理。
- 財務分析需列出主要假設、資料來源、計算步驟與限制。

## 程式碼

- 修改程式碼時，優先直接修改檔案並驗證。
- 單檔腳本可提供完整可執行版本；大型專案修改則列出修改檔案、重點變更與測試結果，不貼大量無關程式碼。
- 不確定依賴、環境或權限時先檢查，不猜。

## 網頁與瀏覽器

- 需要互動、登入、反爬、金融機構官網或動態網頁時，優先使用可用的瀏覽器工具。
- 若 Browser / Chrome MCP 類工具不可用，明確告知限制，再使用可用的替代工具。
- 公開、輕量、靜態頁面才用一般 web fetch / web search。

## Obsidian

- 兩台 Mac 採「單一寫入端」政策：兩台都可以寫入 Obsidian，但任一時間只能有一台執行人工編輯、Obsidian MCP 寫入或寫入型排程。寫入端可以交接，不是永久的主力／次要角色。完整規則見 `~/Documents/Codex/personal-codex-env/OBSIDIAN-MCP-SINGLE-WRITER.md`。
- 執行 Obsidian 批次寫入、啟用寫入型排程、更新 MCP 外掛或處理 MCP 故障前，先讀上述說明書。不得用主機名稱推定永久角色，也不得只因缺少角色標記而停止工作；使用者在本機要求寫入時，將本機視為該次寫入端。只有發現另一台正在寫入、寫入型排程可能重疊、iCloud 尚未同步／出現衝突，或排程交接尚未完成時，才因跨 Mac 協調而停止寫入並詢問；MCP 健康檢查與同步 preflight 等既有停損仍照原規則執行。
- 需要讀寫 Obsidian 時，優先使用 Obsidian MCP；若本回合未提供該工具，先用工具搜尋載入 `obsidian mcp tools` / `mcp__obsidian_mcp_tools`，再判斷不可用並說明限制。
- 若 Obsidian MCP 搜尋後仍未露出，不要只回答「OB 沒露出」。先檢查 `~/.codex/mcp/obsidian-mcp-tools/mcp-server` 是否存在且簽章有效；若不存在或簽章壞，優先執行 `~/Documents/Codex/personal-codex-env/scripts/setup-obsidian-mcp.sh` 修復。修復前可用本機 vault 路徑讀寫作為 fallback，並清楚說明限制。
- 新筆記檔名：`YYYY-MM-DD-主題.md`。
- frontmatter 至少包含：`date`, `tags`, `source`, `status: draft`。
- tags 使用英文小寫。內容繁體中文。使用 `[[wikilink]]`。
- 「搜尋筆記 X」：搜尋 vault 並列摘要。
- 「補充到 X」：在尾端追加，並加日期分隔線。
- 進階規則見 Obsidian vault 的 `_system/rules/obsidian-rules.md`。

## Automations

- `personal-codex-env/automations-templates/` 只同步共用定義：`version`, `id`, `kind`, `name`, `prompt`, `rrule`, `model`, `reasoning_effort`, `execution_environment`。
- `status`, `target`, `cwds`, `created_at`, `updated_at` 與 `memory.md`, `last-run.md`, `last-close.md`, `manual-resolutions.json`, logs、runs、reports、snapshots 都是每台 Mac 的本機狀態，禁止用另一台的 snapshot 覆寫。兩台可以有同一組排程，但各自維持不同的啟用／暫停狀態、target 與 cwd。
- 會寫入 Obsidian 的日報、tracker、MOC 等排程，同一時間只能在目前寫入端為 `ACTIVE`；另一台必須維持 `PAUSED`。兩台可以交接寫入端角色，但不得先啟用新端再停用舊端；狀態不明時不得啟用。
- pull／apply 前必須先完整備份 automations runtime 與 host-state，再跑同步 preflight；preflight 失敗就停止，不得帶錯繼續安裝。`install-mac.sh` 與所有排程調整完成後，必須用該次安裝器印出的精確備份路徑執行 strict baseline audit；audit 失敗就停止，不得關帳。
- 套用共用模板時，已存在的排程保留本機 `status`, `target`, `cwd`；缺少 ID 時先檢查同名或相同 prompt 的 legacy 排程。真的缺少時先從本機 host-state／備份恢復，完全沒有本機狀態才以 `PAUSED` 建立。
- 建立或更新排程一律使用 Codex automation tool；禁止直接複製 template TOML 到 `~/.codex/automations/`、禁止直接修改內部 automation 資料庫。
- portable tool 程式只能安裝到 `~/.codex/automation-tools/`，不得再寫進 `~/.codex/automations/`。只能增量安裝 Git 已追蹤、無 symlink、無 runtime 檔的工具 payload；禁止以 `rsync --delete` 或空的未追蹤目錄鏡像覆蓋任何 live 資料。
- automation tool 的刪除／重建可能連同同 ID 的 runtime 目錄一起移除。做 ID 修復前必須先把 runtime 完整備份到 automation 目錄之外；重建後立即以 missing-only 方式恢復，並重新驗證 `memory.md`、`last-run.md`、`last-close.md` 與人工處理檔。
- 發布 automation 變更時，不得從 live raw TOML 自動 snapshot 回 repo。先備份、驗證模板欄位、列出 diff，取得使用者確認後才能 commit／push。

## Skills

- 製作或修改 Codex skill 時，優先使用 `$skill-creator` 或現有 Codex skill 格式。
- skill 必須包含 `SKILL.md`，且 frontmatter 有 `name` 和 `description`。
- 若需要打包，先確認本機是否存在指定打包腳本；不存在就回報並使用 Codex 可用的替代方式。
- 只要本回合新增或修改 Codex skill、`.agents/skills`、`AGENTS.md`、或同步腳本，收尾時自動使用 `codex-env-sync` 流程：先備份、列出差異、讓使用者確認，再 commit/push；同名 skill 兩邊不同時不要自行融合，先讓使用者選 repo 版或本機版哪個是新版。
