---
name: daily-agri-check
description: 每日農產品決策晨報：系統檢查價格、官方報告、主要產區天氣與災害、病害、物流、政策、持倉及供需轉折，產出繁體中文可讀日報並更新 Obsidian tracker。使用者要求每日農產品日報、農產品晨報、農產品檢查、重跑農產品報告，或追問日報漏掉重要農業事件時，都要使用此 skill。
---

每天產出能支援判斷的農產品晨報。目標不是羅列新聞，而是找出「哪個新事實改變供需、何時影響產量、證據有多硬、接下來看什麼確認」。

## 每次必讀

1. 先完整讀取本檔。
2. 再完整讀取同目錄 `REFERENCE.md`；它包含產區矩陣、來源分級、事件評分、排程與輸出模板。
3. 讀取同目錄 `agri-config.yaml`；檔案缺失時才使用本檔 fallback，不要搜尋舊 Claude Scheduled 路徑。
4. 需要讀寫 Obsidian 前，先讀 vault `_system/rules/obsidian-rules.md`，只在 `農產品追蹤/` 更新 tracker 與每日備份。

## Codex 相容性

- 動態、登入、反爬或金融／產業資料頁優先使用 Browser/Chrome。Browser/Chrome plugin 不會另外露出同名 MCP 工具；先讀當前已安裝的 Browser/Chrome skill，經 `node_repl` 載入該版本的 `browser-client.mjs`，執行 runtime setup 與 `agent.browsers.list()` 健檢。有可用 backend 就直接使用。版本目錄要動態尋找，不得硬編版本號；只有 setup/list 失敗才改用公開 web。不得用 raw Playwright 能否 launch 判斷 Browser/Chrome 是否可用。
- Obsidian 優先使用 MCP 並先驗證 `get_server_info`。若連不到 Local REST API，但 MCP 執行檔與簽章有效，先檢查 Obsidian 是否正在執行及 27123/27124 是否監聽；未執行就啟動 Obsidian、等待外掛載入後重試 MCP。只有重試仍失敗且本機 vault 可寫時，才使用本機路徑 fallback。執行檔缺失或簽章無效時，才執行 `~/Documents/Codex/personal-codex-env/scripts/setup-obsidian-mcp.sh` 修復；限制中記錄實際失敗點。
- 高時效、高影響事件至少交叉查三個可靠來源，其中盡量包含官方或第一手來源。一般市場敘事不可取代原始資料。

## 核心紀律

1. **覆蓋先於結論**：先完成全部品種的覆蓋帳本，再決定哪些值得寫。沒寫進主文不等於沒檢查。
2. **重大性高於48小時**：48小時只決定能否算「今日新訊號」，不能讓仍在發展的洪水、乾旱、病害、罷工或政策事件從報告消失。
3. **重大事件持續追蹤**：標記為 `new / worsening / unchanged / easing / closed`，每天更新最新官方狀態、有效預報與下一個確認點，直到達成結案條件。
4. **地理與作物階段必須對齊**：城市淹水不能直接等於農園減產。先確認是否重疊主要產區、道路／港口，以及開花、結莢、收割、乾燥等關鍵階段。
5. **分開事實與情境**：已發生損害、分析師預測、模型預報與價格敘事分開寫；未具名估計不得寫成共識或官方數字。
6. **價格只當警報器**：異常漲跌會觸發反向查因，但不能只改寫價格網站的市場敘事當基本面分析。
7. **沒有新數據就省略，沒有查到就揭露**：禁止用推測補空白；覆蓋失敗、來源衝突、動態頁不可讀都列入限制。

## Fallback 設定（agri-config.yaml 找不到時直接用）

先嘗試讀取同目錄 agri-config.yaml。讀取失敗或檔案不存在，不要搜尋，直接用以下預設值。

### ticker_map（只提供代碼與單位；合約月每次動態確認）
| 中文名 | 代碼 | 單位 | 交易所 |
|--------|------|------|--------|
| 糖 | SB | c/lb | ICE |
| 玉米 | ZC | c/bu | CBOT |
| 小麥 | ZW | c/bu | CBOT |
| 大豆 | ZS | c/bu | CBOT |
| 棉花 | CT | c/lb | ICE |
| 咖啡 | KC | c/lb | ICE |
| 可可 | CC | $/噸 | ICE |
| 棕櫚油 | FCPO | MYR/噸 | BMD |
| WTI原油 | CL | $/桶 | NYMEX |

### 五因素 Dashboard（糖市專用）
| # | 因素 | 偏多觸發條件 |
|---|------|-------------|
| 1 | El Nino 發展 | Nino 3.4 >= +1.0C 且預測持續 |
| 2 | 印度季風偏弱 | IMD/Skymet 預報 < 96% LPA |
| 3 | 泰國乾旱 | 榨季產量 YoY 下滑 > 5% |
| 4 | 巴西糖佔比下滑 | UNICA 糖佔比 < 45% 且持續下降 |
| 5 | 巴西物流瓶頸 | Santos 排隊天數 > 30 天 或 運費異常 |

### 乙醇平價公式
CEPEA(US$/m3) x 0.030 + 2.5 = 公式平價 (c/lb)

---

## 執行步驟（8 步）

### Step 1：建立今日基準
```bash
TZ=Asia/Taipei date +%Y-%m-%d\ %A\ %H:%M:%S
```
記下48小時與7日事件回看起點。

- 讀最近兩份每日報告，列出昨天的主要判斷、未完成項目與應續追事件。
- 讀 `global-monitor-tracker` 的 `Active Events`，以及各品種 `Latest Data`；只在需要比對時讀長篇 History／News Log。
- 讀 `ethanol-parity-tracker` 作為背景，但不得更新。
- 建立覆蓋帳本：每個品種至少包含價格、官方報告、主要產區天氣／災害、病害／作物階段、物流／政策、持倉／需求六欄，狀態只能是 `checked / new / active / unavailable / not-due`。

### Step 2：官方報告與漏接檢查

- 依 `REFERENCE.md` 排程表檢查 USDA、ICCO、ICO、CONAB、UNICA、MPOB、CFTC、NOAA、BOM、IMD及其他品種專屬來源。
- 報告日期新於 tracker `last_update` 才算新資料。預定發布但尚未出現的報告標示 `scheduled but not yet published`。
- 超過搜尋窗口與 grace period 且 tracker 仍停在上一期時，補搜一次並列為漏接。
- 可批次合併同一份報告涵蓋的品種，但每個品種仍要在覆蓋帳本留下結果。

### Step 3：價格抓取

**主要方法：有效主力合約＋可靠行情來源**

優先順序：交易所或可確認合約的結算資料 → 可靠行情頁 → Trading Economics CFD／參考價。動態頁需要互動時使用 Browser/Chrome；公開可讀頁可用網路搜尋／讀取。可批次取得多品種，但每筆都保留來源、合約月、報價日期與單位。

**驗證**：抓完後跟 tracker History 最後一行比對。閾值規則見 REFERENCE.md。

**嚴格規則**：
- 日% 必須從網站讀取，禁止自行計算
- 合約月依來源的有效主力合約、成交量與最後交易日確認；不得盲用 config 固定月份
- 優先使用收盤／結算價；若只能取得CFD／參考價，必須明標，不能稱為交易所結算
- 合約成交量為 0 或已過期時，依交易所合約序列換到下一個有效月份
- 週末或休市標示最後交易日，不把舊價格當今日變動
- 達 `agri-config.yaml` 異常波動門檻時啟動反向查因：至少查官方／第一手來源、主要通訊社或具名研究，以及產區天氣／供需資料，判斷是基本面、部位、流動性或舊聞重播

**COT 持倉**（僅週五/週六）：搜尋最新 CFTC COT。百分位必標明來源。

### Step 4：兩階段事件雷達

**Pass A：全面廣掃**

- 依 `REFERENCE.md` 的「品種×產區×風險矩陣」逐品種搜尋最近48小時新聞，以及最近7日仍有效的天氣、災害、病害、物流、政策與產量預測。
- 同時掃官方災害／氣象警報。重要農產新聞可能先出現在政府災情、道路、港口或地方氣象資料，而不是商品頁。
- 對 `Active Events` 逐一查最新狀態，不因今天沒有新媒體文章就省略。

**Pass B：重大候選深挖**

- 依 `REFERENCE.md` 事件評分選出重大候選，完整讀取來源上下文。
- 至少回答：哪裡、影響哪個品種、產區重疊度、作物階段、已發生損害、可能傳導、持續多久、量化資料、反證、下一個確認指標。
- 高影響事件交叉查至少三個來源；若仍無受災面積、產量損失或官方確認，就明說無法量化。

### Step 5：事件資格卡與持續追蹤

對重大事件建立或更新事件卡：

- `event / commodity / regions / crop_stage`
- `status / event_start / latest_update / forecast_valid_until`
- `evidence_grade / materiality_score / confidence`
- `confirmed_damage / scenario_estimates / counterevidence`
- `transmission_chain / expected_timing / next_check / closure_condition`

事件卡寫入 `global-monitor-tracker` 的 `Active Events`；品種專屬數據再寫入對應 tracker。舊事件有新官方災情、產區擴大、預報延長、分析師下修或反證時，新增部分可以算今日新訊號。

### Step 6：ENSO/IOD 與跨品種判斷

**ENSO 觸發條件**（三個之一滿足才輸出完整段落）：
(a) NOAA Weekly Update 觀測週日期 > enso-tracker last_ENSO_update
(b) NOAA Monthly Discussion 官方發佈日 > last_monthly_update
(c) NMME/IRI 新版本且預測中位數變化 >= 0.2C
不觸發 -> 整段省略，可在「中期格局」放一行狀態。

觸發後執行：
- 讀 enso-tracker 上月 Nino 3.4，計算月變化（< 0.3C 緩慢 / 0.3-0.5C 正常 / > 0.5C 危險）
- 比較 Nino 1+2/3/3.4/4 判斷類型（東太型/Modoki/Coastal，細則見 REFERENCE.md）
- 評估糖市影響（印度季風、泰國乾旱、巴西收割干擾）

**IOD**：48小時內有新資料才算今日新訊號；較舊但仍有效的官方狀態可放中期格局並標日期。
交互作用：正IOD 削弱聖嬰衝擊 / 中性維持原判 / 負IOD 最危險（雙重壓制季風）

**綜合判斷**：形成三層結論——今天新增什麼、既有事件變好或變壞、價格已反映多少。ENSO 必須落到實際產區與季節，不使用「聖嬰＝所有農產品上漲」的捷徑。

### Step 7：輸出完整晨報

- `今日新訊號 N` 只計算符合鮮度規則的新增事實；另列 `持續重大事件 M`。
- 主文先寫「今天真正改變判斷的三件事」與重大風險雷達，再寫品種方向；價格表、排程、覆蓋帳本與限制放附錄。
- 事件重大性分數 >= 8 必須進前三重點；>= 6 至少進重大風險雷達，即使價格尚未反應。
- N=0 代表沒有新事實，不代表沒有重大風險；仍要更新 Active Events。
- 使用 `REFERENCE.md` 固定模板，全文繁體中文、白話但不失真。

### Step 8：更新、交付與驗證

**批次更新原則（省 token 關鍵）**：
同一個 tracker 檔案的所有更新合併成盡量少的 patch_vault_file 呼叫。
每次 patch 會回傳整份檔案，所以呼叫越少越好。

合併策略：
- frontmatter last_update + News Log 追加 → 分 2 次（不同 targetType）
- 同一個 heading 下的多條追加 → 合併成一次 patch，內容用換行串接
- History 表格追加 + Latest Data 更新 → 如果是不同 heading，無法避免多次

**News Log 歸檔規則**：
每月 1 日執行時，把 global-monitor-tracker 中超過 30 天的 News Log 條目搬到：
`農產品追蹤/archive/news-log-YYYY-MM.md`
用 create_vault_file 建歸檔檔，再用 patch_vault_file replace 清理主檔 News Log。
其他日子不執行歸檔。

**更新清單**：
- frontmatter last_update → 今天日期
- 對應 tracker 的 News Log / History 追加新數據
- sugar-tracker 五因素狀態（如有變化）
- 不更新 ethanol-parity-tracker（由 ethanol-parity-check 任務負責）
- 建立每日完整備份檔：`農產品追蹤/daily-report/YYYY-MM-DD-農產品日報.md`
  - 這份檔案保存 Step 7 的完整晨報，方便之後回溯當天判斷；它不是主要給使用者閱讀的交付物。
  - 檔案必須包含 frontmatter：`date`, `tags`, `source`, `status: draft`。
  - 建議 frontmatter：
    ```yaml
    ---
    date: YYYY-MM-DD
    tags: [agriculture, daily-report, commodities]
    source: daily-agri-check
    status: draft
    ---
    ```
  - 內文第一段保留 Step 7 完整日報，不要只存摘要。
  - 若同名檔已存在，先檢查是否為同一天同一輪內容；若只是重跑修正，更新同檔，不要建立 `copy` 或亂加後綴。
- Tracker section 標題一律用英文（Latest Data, History, Key Background, News Log, Active Events, Five Factor Dashboard）

各 tracker 的欄位細則見 REFERENCE.md。

最後重新讀取三個交付面，確認日期與「今日一句話」一致：聊天主交付、automation `last-run.md`、Obsidian daily-report。任一失敗都列入未完成項目，不得只說「已完成」。
