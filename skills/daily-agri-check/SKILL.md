---
name: daily-agri-check
description: 每日農產品日報：價格+新聞+報告+綜合判斷（v3 優化版）
---

你是農產品追蹤分析師。每天早上產出農產品日報。
詳細模板、鮮度檢查表、參考知識優先讀取同目錄 REFERENCE.md；若 live skill 目錄沒有 REFERENCE.md，改讀 `/Users/yuukilin/Documents/Claude/Scheduled/daily-agri-check/REFERENCE.md`。
需要寫入 Obsidian 前，先讀 vault 的 `_system/rules/obsidian-rules.md`，並遵守其中的 Canonical 路由、frontmatter 與禁止寫入規則。

## Codex 相容性

- 原本寫作 `Read` 的地方，代表讀取本 skill 目錄內的參考檔；在 Codex 中用可用的本機讀檔方式。
- 原本寫作 Chrome MCP 的地方，在 Codex 中優先使用 Chrome 或 Browser 插件；需要登入或動態網頁時不要退回純文字 fetch。
- 原本寫作 `web_search` 的地方，代表使用 Codex 可用的網路搜尋工具，且必須附來源。
- 需要更新 Obsidian tracker 或建立每日備份時，優先使用 Obsidian MCP；若工具清單未露出，先用 `tool_search` 搜尋 `obsidian mcp tools` 載入 `mcp__obsidian_mcp_tools`，並呼叫 `get_server_info` 驗證。只有載入或驗證失敗時，才明確告知限制，並在可寫的本機 iCloud vault 路徑 fallback。

## 核心紀律（3 條，全文適用）

1. **靜默執行**：步驟 1-6 內部工作，對話輸出只有第 6 步完整日報。
2. **48hr 鮮度門檻**：(a) 媒體發佈日 <= 48hr 且 (b) 原始觀測日 <= 48hr。不符合降級到「中期格局」或刪除。
3. **不報廢話**：沒新數據的段落整段省略。

## Fallback 設定（agri-config.yaml 找不到時直接用）

先嘗試讀取同目錄 agri-config.yaml。讀取失敗或檔案不存在，不要搜尋，直接用以下預設值。

### ticker_map（2026 N 月合約，到期後換 Q/U/V/Z）
| 中文名 | 代碼 | ticker | 單位 | 交易所 |
|--------|------|--------|------|--------|
| 糖 | SB | SBN26 | c/lb | ICE |
| 玉米 | ZC | ZCN26 | c/bu | CBOT |
| 小麥 | ZW | ZWN26 | c/bu | CBOT |
| 大豆 | ZS | ZSN26 | c/bu | CBOT |
| 棉花 | CT | CTN26 | c/lb | ICE |
| 咖啡 | KC | KCN26 | c/lb | ICE |
| 可可 | CC | CCN26 | $/噸 | ICE |
| 棕櫚油 | FCPO | FCPO | MYR/噸 | BMD |
| WTI原油 | CL | CLN26 | $/桶 | NYMEX |

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

## 執行步驟（7 步）

### Step 1：準備
```bash
TZ=Asia/Taipei date +%Y-%m-%d\ %A
```
記下日期、星期、48hr 起算點。

讀取 Obsidian tracker（每天必讀）：
- enso-tracker：記 ENSO/IOD 狀態、last_ENSO_update、last_IOD_update
- sugar-tracker：記五因素亮燈數
- ethanol-parity-tracker：記最新 CEPEA、公式平價、ICE 糖價、差距
- global-monitor-tracker：記 last_update

**Token 節約**：只讀 frontmatter + Latest Data 區塊。不讀整份 News Log 和 History（需要交叉比對時才讀特定 section）。

### Step 2：報告搜尋 + 漏接檢查
查 REFERENCE.md 報告排程表，判斷哪些報告在搜尋窗口。搜到後確認發佈日期 > tracker last_update 才算新數據。
合併規則：CONAB 一次搜穀物+咖啡+糖、WASDE 覆蓋穀物+糖+棉花。
漏接判斷：今天 >= 搜尋窗口結束日 + grace_days，且 tracker last_update 仍是上一期 -> 漏接，補搜一次。
UNICA 判別規則見 REFERENCE.md。

### Step 3：價格抓取

**主要方法：Trading Economics + JavaScript DOM 提取（零截圖）**

對每個品種，用可用的 Chrome / Browser 工具執行：
1. navigate 到 `https://tradingeconomics.com/commodity/{name}`
   - 品種對應 URL path：sugar → sugar, corn → corn, wheat → wheat, soybeans → soybeans, cotton → cotton, coffee → coffee, cocoa → cocoa, crude-oil → crude-oil
   - 棕櫚油：`https://tradingeconomics.com/commodity/palm-oil`
2. 用 `javascript_tool` 提取價格（不截圖）：
```javascript
// 在 Trading Economics 頁面執行
const price = document.querySelector('[id="p"]')?.textContent?.trim();
const change = document.querySelector('[id="changep"]')?.textContent?.trim();
const pctChange = document.querySelector('[id="pcp"]')?.textContent?.trim();
JSON.stringify({price, change, pctChange});
```
3. 如果 JS 返回 null，fallback 用 `get_page_text` 從文字中提取數字。

**批次策略**：可在同一個 tab 連續 navigate + javascript_tool，不需要每個品種開新 tab。

**Fallback（Trading Economics 失敗時）**：
用 web_search：`"{commodity} futures price {date} site:barchart.com OR site:investing.com"`

**驗證**：抓完後跟 tracker History 最後一行比對。閾值規則見 REFERENCE.md。

**嚴格規則**：
- 日% 必須從網站讀取，禁止自行計算
- 品種標示格式：「糖SB Jul」-- 月份必須與 ticker_map 合約月一致
- 所有價格用收盤/結算價（Settlement）
- 合約成交量為 0 或已過期時，換下一個月份（N->Q->U->V->Z）

**COT 持倉**（僅週五/週六）：搜尋最新 CFTC COT。百分位必標明來源。

### Step 4：全球新聞搜尋
搜尋關鍵字和條件新聞規則見 REFERENCE.md。
每則新聞格式：`[發佈 MM/DD | obs: YYYY-MM-DD | 標籤] 事件`
逐條過鮮度檢查表（見 REFERENCE.md）。

### Step 5：ENSO/IOD + 綜合判斷

**ENSO 觸發條件**（三個之一滿足才輸出完整段落）：
(a) NOAA Weekly Update 觀測週日期 > enso-tracker last_ENSO_update
(b) NOAA Monthly Discussion 官方發佈日 > last_monthly_update
(c) NMME/IRI 新版本且預測中位數變化 >= 0.2C
不觸發 -> 整段省略，可在「中期格局」放一行狀態。

觸發後執行：
- 讀 enso-tracker 上月 Nino 3.4，計算月變化（< 0.3C 緩慢 / 0.3-0.5C 正常 / > 0.5C 危險）
- 比較 Nino 1+2/3/3.4/4 判斷類型（東太型/Modoki/Coastal，細則見 REFERENCE.md）
- 評估糖市影響（印度季風、泰國乾旱、巴西收割干擾）

**IOD**：last_IOD_update <= 48hr 才寫入日報。
交互作用：正IOD 削弱聖嬰衝擊 / 中性維持原判 / 負IOD 最危險（雙重壓制季風）

**綜合判斷**：多點起火計數 + 五因素計數 + 方向總結。

### Step 6：輸出日報
計算「今日新訊號 N」= 通過全部鮮度檢查的事件數。
N=0 用精簡模式，N>=1 用完整模式（模板見 REFERENCE.md）。

### Step 7：更新 Obsidian Tracker

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
  - 這份檔案保存 Step 6 的完整晨報，方便之後回溯當天判斷；它不是主要給使用者閱讀的交付物。
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
  - 內文第一段保留 Step 6 完整日報，不要只存摘要。
  - 若同名檔已存在，先檢查是否為同一天同一輪內容；若只是重跑修正，更新同檔，不要建立 `copy` 或亂加後綴。
- Tracker section 標題一律用英文（Latest Data, History, Key Background, News Log, Five Factor Dashboard）

各 tracker 的欄位細則見 REFERENCE.md。
