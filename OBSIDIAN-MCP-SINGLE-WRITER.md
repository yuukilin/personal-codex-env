# 兩台 Mac 的 Obsidian MCP 單一寫入端說明

用途：這是使用者與 Codex 共用的操作規則。只要任務涉及 Obsidian MCP、人工編輯、批次寫入、tracker、日報或會修改 Obsidian 的排程，先讀本文件。

## 一句話原則

**兩台 Mac 都可以寫入 Obsidian，但任一時間只能有一台是「目前寫入端」；另一台在這段時間是「待命端」。這是可交接的暫時狀態，不是永久的主力／次要角色。**

## 兩台電腦的暫時分工

### 目前寫入端

- 可以人工編輯 Obsidian 筆記。
- 可以執行 Obsidian MCP 寫入。
- 可以執行會更新日報、tracker、MOC 或其他 Obsidian 筆記的排程。
- 可以更新會修改 vault 的 Local REST API 或 MCP Tools 外掛。
- 遇到 MCP 故障時，可以在本機修復與驗證。

### 待命端

- 照常同步 Codex rules、skills 與共用排程定義。
- 可以透過 iCloud 讀取 Obsidian 筆記。
- 不做人工編輯、MCP 寫入、本機 vault fallback 或其他會修改 vault 的操作。使用者改在這台發起一般人工／Codex 寫入，即視為該次工作的交接；若涉及自動排程、新 Mac 啟用或已有衝突跡象，才走完整交接流程。
- Obsidian 寫入型排程維持 `PAUSED`。
- 可以在 vault 外整理草稿，等取得寫入權後再正式寫回。

兩台 Mac 都具備成為寫入端的資格，也可以擁有相同的排程定義；`status`、target 與 cwd 是各自的本機狀態，不可用另一台的狀態覆寫。

## 本次寫入端如何決定

- 使用者在某台 Mac 要求人工或 Codex 寫入時，該請求本身就完成這次一般工作的交接，該台就是這次工作的目前寫入端；不需要永久角色標記，也不必只因找不到標記而停下。
- 使用者已明確說明兩台不會同時人工或透過 Codex 寫入，因此一般使用者發起的寫入任務不必每次重新詢問另一台是否停止。
- 只有出現具體衝突跡象時才停止並詢問，例如另一台正在寫入、兩台寫入型排程可能同時執行、iCloud 尚未同步或出現衝突副本。
- 自動排程沒有使用者在場協調，因此仍須遵守明確交接：先讓原端 `PAUSED` 並等工作與同步完成，才可讓新端 `ACTIVE`。
- 下方完整交接流程只用於切換寫入型排程、新 Mac 首次啟用寫入，或已出現具體跨 Mac 衝突；一般使用者發起的人工／Codex 寫入不用先跑完整流程。

## Codex 執行前判斷

Codex 在任何 Obsidian 寫入前，必須依序確認：

1. 這個任務只是讀取，還是會修改 vault？人工編輯、MCP、排程、本機路徑 fallback 與外掛更新都算寫入。
2. 使用者在本機要求寫入時，直接把本機視為這次工作的寫入端；不得因主機沒有永久角色標記就降為唯讀。
3. 檢查是否有具體跨 Mac 衝突跡象；若沒有，就繼續工作，不必為了角色標記再詢問。
4. 若要啟用或把寫入型排程切換到這台，必須先確認另一台相關排程為 `PAUSED`、前一輪工作已結束且 iCloud 已同步。
5. 發現具體衝突跡象時，在釐清前只能讀取或在 vault 外整理草稿。
6. 本機開始批次工作前，先實測 MCP 健康狀態。

不得用主機名稱、既有 MCP 設定或工具是否露出，推定這台目前擁有寫入權。

## 寫入端的健康檢查

正式批次寫入前，最少完成：

1. `get_server_info` 回傳 `status: OK` 與 `authenticated: true`。
2. MCP server 使用本機穩定路徑：`~/.codex/mcp/obsidian-mcp-tools/mcp-server`。
3. 執行檔簽章有效。
4. 以巢狀路徑建立一份小型測試筆記，讀回內容後刪除。
5. 大型日報任務曾發生逾時時，再做一次大型內容的建立、讀回比對與刪除。
6. 測試檔必須清除，不能留在 vault。

若建立成功但 MCP 沒有回應，不可直接重送整批內容；先確認檔案是否已落地，避免重複追加。

## 哪些東西可以同步

可以透過 `personal-codex-env` 同步：

- `AGENTS.md`
- rules 與 skills
- MCP setup／修復腳本
- 不含密鑰的安全設定範例
- automation 共用定義與可攜工具
- 本操作說明

必須由每台 Mac 本機保存，禁止跨機複製：

- `~/.codex/mcp/` 的 MCP binary
- 真實 `~/.codex/config.toml`
- Obsidian API key
- Codex 登入、session、cache 與資料庫
- automation 的 `status`、target、cwd、memory、last-run、logs、reports、snapshots

## 新 Mac 的預設做法

1. 先按照 `codex-env-sync` 流程安裝 rules 與 skills。
2. 新 Mac 的 Obsidian 寫入型排程預設為 `PAUSED`，直到確認另一台已停止寫入並完成交接。
3. 兩台都可以在本機安裝 MCP server 並檢查執行檔與簽章；但外掛更新若會修改 vault，必須由目前寫入端執行。
4. 建立、讀取、刪除實測會修改 vault，必須先完成寫入端交接再執行；測試通過後，才可啟用這台的寫入型排程。

## 交接目前寫入端

必須依序完成，不能兩台同時切換：

1. 用 Codex automation tool 暫停原寫入端的所有 Obsidian 寫入型排程。
2. 停止原寫入端的人工編輯，等待執行中任務結束，確認沒有未完成寫入。
3. 等待 iCloud 同步完成；必要時關閉原寫入端的 Obsidian，避免交接期間又產生新寫入。
4. 在新寫入端開啟 Obsidian，確認最新 tracker／日報與其他近期修改都已同步。
5. 確認新寫入端的 MCP 本機設定正常；若尚未設定，執行 `./scripts/setup-obsidian-mcp.sh` 並重開 Codex。
6. 完成 MCP 健康檢查。
7. 用 Codex automation tool 啟用新寫入端需要的寫入型排程。
8. 原寫入端維持 `PAUSED`，直到下一次完成反向交接。

順序必須是「原端 `PAUSED` → 工作結束 → iCloud 同步 → 新端確認 → 新端 `ACTIVE`」，不得先啟用新端。

## 更新 Obsidian 外掛

1. 由目前寫入端更新 Local REST API 或 MCP Tools。
2. 更新前確認待命端沒有人工編輯、MCP 寫入或寫入型排程執行中。
3. 更新完成後等待 iCloud 同步，再讓待命端重新載入 vault。
4. 在需要使用 MCP 的電腦重新執行 `./scripts/setup-obsidian-mcp.sh` 並重開 Codex。
5. 由目前寫入端重新做 MCP 建立、讀取、刪除測試；待命端只檢查本機 binary、簽章與連線，等日後成為本次寫入端或完成排程交接後再做會寫入 vault 的測試。

外掛更新可能覆蓋本機相容修補；若巢狀路徑或大型寫入再次逾時，必須重新做根因檢查，不可只把 timeout 調大。

## MCP 故障時的處理順序

1. 搜尋並載入 Obsidian MCP 工具。
2. 呼叫 `get_server_info`。
3. 檢查 Local REST API 是否啟用、認證是否成功。
4. 檢查 `~/.codex/config.toml` 的 command 是否指向本機穩定路徑。
5. 檢查 MCP binary 是否存在且簽章有效。
6. binary 缺失或簽章損壞時，執行 `~/Documents/Codex/personal-codex-env/scripts/setup-obsidian-mcp.sh`。
7. 重開 Codex，先驗證 `initialize` 與 `tools/list`；若本機已是本次寫入端，再做建立、讀取與刪除測試，否則延後寫入測試。
8. MCP 暫時不可用但任務必須繼續時，只有目前寫入端可以使用本機 vault 路徑作為 fallback；必須明確回報哪些寫回已完成、哪些仍未完成。

## 必須停止並請使用者決定的情況

- 有具體跡象顯示另一台仍在人工、Codex、MCP 或排程寫入。
- 發現兩台寫入型排程都為 `ACTIVE` 或都在執行。
- iCloud 出現衝突副本或尚未同步完成。
- MCP 未認證、binary 簽章無效，或建立／讀回／刪除測試失敗。
- 外掛版本或本機相容修補狀態不一致。
- `codex-env-sync` preflight 失敗。

發現兩台同時具有寫入活動時，不再開始任何新寫入；先停止兩端的寫入型排程，保留現有檔案並檢查同步衝突，再由使用者指定接下來由哪台接手。

## 完成時的回報格式

Codex 應簡短回報：

- 本次工作：本機為寫入端／本次未寫入
- MCP 狀態：正常／異常／未啟用
- 具體跨 Mac 衝突跡象：無／有（有則簡述）
- 寫入型排程：ACTIVE／PAUSED
- 最近一次建立、讀取、刪除測試結果
- 是否仍需要使用者操作
