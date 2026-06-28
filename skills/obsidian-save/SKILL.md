---
name: obsidian-save
description: >
  將研究內容存入使用者 Obsidian vault 並正確融入知識圖譜。
  處理 frontmatter metadata（tickers, sectors, themes, signal_tags, supply_chain 等）、
  資料夾路由、wikilink 連結、自動建立 Theme 卡片和 Ticker 總整理頁面、
  更新 Theme 趨勢演變紀錄。也支援「補充到 [筆記名]」和「搜尋筆記 [關鍵字]」。
  觸發時機：使用者說「存進 ob」「存進 Obsidian」「寫進筆記」「存檔」「存到 vault」
  「這個存一下」「幫我記起來」「補充到 [筆記名]」「搜尋筆記 [關鍵字]」，
  或在完成翻譯/摘要/分析後要求保存到 Obsidian 時觸發。
  不觸發：使用者只是討論 Obsidian 功能但無存檔意圖。
  不要與 report-intake 混淆（report-intake 是批次掃描報告收件夾，本 skill 是單篇存入）。
---

# Obsidian Save — 存入知識圖譜

## 模式判斷

根據使用者指令選擇模式：

- **存檔模式**：「存進 ob」「存檔」「寫進筆記」等 → 執行完整存檔流程
- **補充模式**：「補充到 [筆記名]」→ 搜尋該筆記，在尾端追加內容，加日期分隔線
- **搜尋模式**：「搜尋筆記 [關鍵字]」「看 ob [標的/主題]」→ 先用圖譜檢索找濃縮節點與連結，再列出結果摘要

以下為存檔模式的完整流程。

## Obsidian MCP 可用性

優先使用 Obsidian MCP。若工具清單未露出，先用 `tool_search` 搜尋 `obsidian mcp tools` 載入 `mcp__obsidian_mcp_tools`，並呼叫 `get_server_info` 驗證。只有載入失敗、驗證失敗或 timeout，才說 MCP 不可用並改用本機 vault fallback；不要只因工具未直接顯示就判定連不到。

---

## 存檔流程（7 步）

### Step 1：讀取參考文件

```
Read references/vault-schema.md
```

取得欄位定義、格式規則、frontmatter 模板。

### Step 2：動態掃描 vault 現有結構

每次存檔前必須執行，不可依賴記憶或靜態清單：

```
list_vault_files("1 Cards/")          → 取得所有 Theme 卡片
list_vault_files("3 MOC/Tickers/")    → 取得所有 Ticker 總整理頁面
```

將結果暫存為「現有 Theme 清單」和「現有 Ticker 清單」，後續步驟比對用。

### Step 3：判斷內容類型與路由

根據 vault-schema.md 的路由規則決定目標資料夾和檔名格式。

### Step 4：組裝 frontmatter

根據 vault-schema.md 的欄位定義填寫。關鍵注意：

- `themes` 欄位：比對 Step 2 的現有 Theme 清單，使用已存在的名稱。
  如果內容涉及新主題 → 見 Step 6 自動建立。
- `tickers` 欄位：美股純 ticker，台股加 .TW
- `signal_tags`：從詞彙表選取，2-5 個

### Step 5：撰寫正文（含積極 wikilink）

正文格式：繁體中文，禁用「」引號，→ 可用但 ← ↑ ↓ 避免。

**Wikilink 積極策略 — 所有值得連結的都連：**

- Theme 連結：`[[Theme-ai-datacenter-power]]` — 不管頁面是否已存在
- Ticker 連結：`[[IFX-研究總整理|IFX]]`（美股）、`[[2330.TW-研究總整理|台積電(2330)]]`（台股）— 不管頁面是否已存在
- 報告交叉連結：明確知道檔名時加 `[[完整檔名]]`

Obsidian 的未解析連結（unresolved link）是功能不是 bug，它幫助使用者在 Graph View 中看到哪些頁面值得建立。

### Step 6：自動建立新 Theme 卡片和 Ticker 頁面

**6A. 防重複比對（最關鍵）**

建立前必須比對 Step 2 掃描的清單，確認語意上不重複：

- 同概念不同語言：`Theme-nuclear-renaissance` 和 `Theme-核能復興` 是同一個 → 不重複建立
- 同概念不同措辭：`Theme-ev-adoption` 和 `Theme-電動車滲透` 是同一個 → 不重複建立
- 包含關係：如果已有 `Theme-ai-datacenter-power` 就不要再建 `Theme-ai-server-power` → 歸入已有的
- Ticker 同理：`IFX` 和 `IFNNY` 是同一家公司 → 用已存在的那個

比對方式：
1. 先看英文名稱是否語意相同
2. 再看中文名稱是否語意相同
3. 如果有任何疑似重複，歸入已存在的，不新建

**6B. 自動建立 Theme 卡片**

當內容涉及一個可追蹤的投資趨勢，且通過防重複比對確認不存在時，自動建立：

```markdown
---
type: theme-card
theme: [theme-slug]
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
status: active
---

# 投資主題：[主題中文名]

## 主題定義

[2-3 句定義該主題的核心內容和投資含義]

## 相關報告（自動）

\```dataview
TABLE source AS "來源", date AS "日期", key_thesis AS "核心論點"
FROM "2 Sources"
WHERE contains(themes, "[theme-slug]")
SORT date DESC
\```

## 相關標的（自動）

\```dataview
LIST tickers
FROM "2 Sources"
WHERE contains(themes, "[theme-slug]") AND tickers
SORT date DESC
\```

## 供應鏈節點（自動）

\```dataview
TABLE supply_chain.upstream AS "上游", supply_chain.midstream AS "中游", supply_chain.downstream AS "下游"
FROM "2 Sources"
WHERE contains(themes, "[theme-slug]") AND (supply_chain.upstream OR supply_chain.midstream OR supply_chain.downstream)
SORT date DESC
\```

## 趨勢演變紀錄

（首筆紀錄由觸發建立的筆記自動寫入）

## 我的觀察

（留空，供使用者手動記錄）
```

存放位置：`1 Cards/Theme-[theme-slug].md`

**6C. 自動建立 Ticker 研究總整理頁面**

當筆記的主角標的在 `3 MOC/Tickers/` 不存在時（且通過防重複比對），自動建立：

```markdown
---
type: ticker-overview
ticker: [TICKER]
company_name: [公司全名]
exchange: [交易所]
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
---

# [TICKER] [公司中文名] 研究總整理

## 公司簡介

[2-3 句簡介公司主要業務和市場定位]

## 評等與目標價歷史（自動）

\```dataview
TABLE source AS "來源", date AS "日期", rating AS "評等", target_price AS "目標價", key_thesis AS "論點"
FROM "2 Sources"
WHERE contains(tickers, "[TICKER]")
SORT date DESC
\```

## 相關主題（自動）

\```dataview
LIST themes
FROM "2 Sources"
WHERE contains(tickers, "[TICKER]") AND themes
SORT date DESC
\```

## 供應鏈定位（自動）

\```dataview
TABLE supply_chain.upstream AS "上游", supply_chain.midstream AS "中游", supply_chain.downstream AS "下游"
FROM "2 Sources"
WHERE contains(tickers, "[TICKER]") AND (supply_chain.upstream OR supply_chain.midstream OR supply_chain.downstream)
SORT date DESC
\```

## 被其他報告提及（自動）

\```dataview
TABLE source AS "來源", date AS "日期", tickers AS "主角標的", key_thesis AS "論點"
FROM "2 Sources"
WHERE contains(related_tickers, "[TICKER]") AND !contains(tickers, "[TICKER]")
SORT date DESC
\```

## 即將到來的催化劑（自動）

\```dataview
TABLE catalysts.date AS "日期", catalysts.event AS "事件"
FROM "2 Sources"
WHERE contains(tickers, "[TICKER]") AND catalysts
FLATTEN catalysts
SORT catalysts.date ASC
\```

## 觀點衝突歷史

\```dataview
TABLE source AS "來源", date AS "日期", rating AS "評等", target_price AS "目標價"
FROM "2 Sources"
WHERE contains(tickers, "[TICKER]") AND conflict_flag = true
SORT date DESC
\```

## 我的觀察

（留空，供使用者手動記錄）
```

存放位置：`3 MOC/Tickers/[TICKER]-研究總整理.md`

### Step 7：直接執行、完成後回報

**不需要事前確認，直接執行。完成後告知使用者建了哪些檔案即可。**

**7A. 執行順序**

1. 先建新 Theme 卡片（如有）
2. 再建新 Ticker 頁面（如有）
3. 建立主筆記
4. 更新相關 Theme 卡片的趨勢演變紀錄

**7B. 自動更新 Theme 趨勢演變紀錄**

用 `append_to_vault_file` 或 `patch_vault_file` 在對應 Theme 卡片的「趨勢演變紀錄」段落追加：

```
- YYYY-MM-DD：[[筆記檔名]] -- 一句話描述該筆記帶來的新資訊
```

---

## 品質自查（執行後）

建完所有檔案後自查：
1. 主筆記 frontmatter 的 `themes` 每一項是否都有對應的 Theme 卡片（已存在或剛建立）
2. 主筆記 frontmatter 的 `tickers` 格式是否正確（美股純 ticker，台股 .TW）
3. 正文中的 wikilink 格式是否一致
4. 沒有建立語意重複的 Theme 或 Ticker 頁面

---

## 補充模式

使用者說「補充到 [筆記名]」時：
1. 用 `search_vault_simple` 搜尋筆記名
2. 找到後用 `append_to_vault_file` 在尾端追加
3. 追加內容前加日期分隔線：`\n---\n### YYYY-MM-DD 補充\n`

## 搜尋模式

使用者說「搜尋筆記 [關鍵字]」時：
1. 先判斷關鍵字是個股、主題、產業、近期趨勢、農產品或技術知識。
2. 找種子節點：
   - 個股 → `3 MOC/Tickers/`；若無總整理頁，查 `tickers`、`related_tickers`、`companies_mentioned`。
   - 主題 → `1 Cards/Theme-*.md`，優先讀「主題定義」與「趨勢演變紀錄」。
   - 近期趨勢 → `3 Analysis/Daily/`、`3 Analysis/Daily/_mini-summaries/`、`3 Analysis/Signals/`。
3. 順著三種連結擴散：
   - outgoing wikilinks：種子節點明確連出去的筆記。
   - backlinks：反向連回種子節點的日報、mini-summary、Signal、Theme 或來源筆記。
   - frontmatter graph：`themes`、`related_tickers`、`companies_mentioned`、`supply_chain`、`signal_tags`、`catalysts`、`conflict_flag`。
4. 只走 1-2 層，高價值節點優先；不要看到連結就全部打開。
5. 若仍不足，再用 `search_vault_simple` 作受限全文搜尋，優先限制在 `1 Cards/`、`3 MOC/`、`3 Analysis/`、`2 Sources/Reports`、`2 Sources/Research` 等相關資料夾。
6. 列出結果摘要：檔名、路徑、日期、為什麼相關、可順著哪些連結繼續看。

---

## 參考文件

- **欄位定義與格式規則**：`references/vault-schema.md` — 每次存檔前 Step 1 必讀
