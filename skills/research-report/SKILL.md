---
name: research-report
description: >
  撰寫「初步研究報告」「首次研究報告」「入門研究報告」：針對使用者第一次或早期研究的公司或投資主題，結合 Obsidian vault 歷史資料與網路公開資訊，建立完整背景認識、公司/產業地圖、供應鏈、競爭格局、財務概況、成長動能與風險，並存入 vault。
  支援兩種模式：初步個股研究（如家登、台積電）和初步產業主題研究（如先進封裝、AI 電力需求）。
  使用者明確提到「初步研究」「首次研究」「入門研究」「建立認識」「先研究一下」「初步研究報告」「首次研究報告」時使用本 skill。
  常見觸發語：「初步研究 家登」「首次研究報告 先進封裝」「入門研究 2330」「幫我建立 NVDA 的初步研究」「先研究一下 AI 電力」「初步研究 核能」。
  嚴格不觸發的情況：使用者要「進階研究」「詳細研究」「當下最新狀況」「要不要買」「要不要賣」「加碼或減碼」「買賣依據」「目前值不值得投資」「現在勝率高嗎」等決策型研究；這些情境應使用 advanced-research-report。
  若使用者只說「研究報告」而沒有初步/首次/入門或買賣決策語意，先簡短詢問要「初步研究」還是「進階買賣決策研究」，不要自行假設。
  不要與其他 skill 混淆：「整理報告」觸發 report-intake，「週報」「ELN」觸發 weekly-report，
  「月報」觸發 monthly-report，「框架」觸發 investment-thesis，「解釋」觸發 research-explainer。
  本 skill 是建立第一版研究底稿，不做買入、加碼、減碼、賣出等當下交易判斷。
---

# Research Report — 初步/首次研究報告產生器（v4）

## Codex 相容性

- 本 skill 的執行者是 Codex。
- 本 skill 中的 Chrome MCP 指可用的 Codex Chrome、Browser 或 Computer Use 工具；若登入狀態或動態表格需要真實瀏覽器，優先用 Chrome。
- 本 skill 中的 `web search` 指 Codex 可用的網路搜尋/瀏覽工具；涉及最新新聞、財報、股價、政策、產品規格時必須重新查證並附來源。
- 寫入 Obsidian 時優先使用 Obsidian MCP；若工具清單未露出，先用 `tool_search` 搜尋 `obsidian mcp tools` 載入 `mcp__obsidian_mcp_tools`，並呼叫 `get_server_info` 驗證。只有載入或驗證失敗時，才明確告知限制並改用允許的 fallback。

## 核心任務

使用者給出一個標的（公司名/代號/產業主題），Codex 需要建立第一版完整研究底稿，一口氣完成以下流程，中間不停下來問使用者：

1. 窮盡搜尋使用者 Obsidian vault 中的歷史研究資料（兩層搜尋全做完）
2. 用財報狗 + web search 補充 vault 中不足或過時的資訊；台股/美股個股都優先看財報狗
3. 根據實際掌握的財務數據和股價狀態，選取投資智慧卡片作為後續觀察框架
4. 整合所有資料，依對應模板撰寫 3000-6000 字的初步/首次研究報告
5. 按標準格式直接存入 Obsidian vault（不問使用者）

重要流程規則：
- 使用者說「初步研究 XXX」「首次研究 XXX」「入門研究 XXX」「建立認識 XXX」就是要一份完整初步研究底稿，從搜尋到動筆到產出，一路做到底
- 這份報告的用途是建立背景與研究地圖，不是當下買賣決策；若使用者要買、賣、加碼、減碼、續抱或最新勝率，改用 `advanced-research-report`
- vault 覆蓋度診斷寫在報告第十節裡面，不要在搜尋完後停下來問使用者「覆蓋夠不夠」「要不要繼續」
- 整個流程中不需要停下來問使用者，包括存檔——直接按標準格式存入 vault
- 如果 vault 搜不到任何資料，也不要停下來問，直接用網路資料寫，在報告中說明 vault 無相關資料即可

報告的核心價值：大量引用使用者自己的資料庫，串聯跨報告、跨時間的資訊，產出使用者獨有的第一版研究地圖。這不是一般的網路研究報告，而是從使用者累積的 500+ 份研究報告中提煉出的獨家整合分析。

---

## Step 0：判斷報告類型 + 初始化追蹤器

收到標的後，判斷屬於哪種類型：

初步個股研究報告 — 標的是一家特定公司（股票代號或公司名）
- 範例：家登、2330、NVDA、台積電、朋程(8255)

初步產業主題研究報告 — 標的是一個產業趨勢或技術主題
- 範例：先進封裝、AI 電力需求、CoWoS、核能復興、被動元件漲價

判斷方法：
- 股票代號（數字或英文大寫如 2330、NVDA）或明確公司名，走個股模式
- 產業名詞、技術名詞、趨勢概念，走產業主題模式
- 不確定時詢問使用者

### 初始化 Vault 覆蓋度追蹤器

在搜尋過程中邊搜邊記錄以下統計，寫報告第十節時直接填入，不用回頭再翻：

```
vault_stats = {
  deep_reports: 0,        # 深度個股報告份數
  deep_reports_latest: "", # 最新日期
  earnings_reports: 0,     # 法說會/財報摘要份數
  newsletter_mentions: 0,  # Newsletter 提及份數
  supply_chain_reports: 0, # 供應鏈上下游報告份數
  theme_cards: [],         # 涵蓋的 Theme 卡片名稱
  latest_anchor_date: "",  # 最後一次定錨研究日期
  sources_read: [],        # 實際讀取的報告名稱列表（用於引用）
}
```

判斷完後告知使用者：「這份是初步個股/產業主題研究報告，讓我開始搜集資料。」然後立刻進入 Step 1，不要等使用者回覆。

---

## Step 1：Vault 圖譜檢索（最重要的步驟——決定報告品質的關鍵）

這一步是整份報告最大的附加價值。不要把 Obsidian 當成單純檔案倉庫，也不要一開始就全庫全文搜尋。正確做法是：先找濃縮節點，再活用連結網路擴散，最後才下鑽 `2 Sources/` 來源層驗證。

核心順序：
1. 濃縮層起手：Ticker MOC / Theme Card / Analysis Signal / Daily mini-summary
2. 連結圖譜擴散：outgoing wikilinks / backlinks / frontmatter graph
3. 來源層驗證：只讀被圖譜指到、或高相關的 `2 Sources/` 筆記
4. 受限全文搜尋：只作補漏，限制資料夾與關鍵字，避免大 vault timeout

搜尋完直接進入 Step 2，不要停下來向使用者報告搜尋結果。

### 1a. 圖譜優先規則

每次初步研究報告都先建立一組「種子節點」，再從種子節點往外擴：

初步個股研究報告：
- 第一種子：`3 MOC/Tickers/[TICKER]-研究總整理.md`，含 `.TW` / `.T` 等後綴變體。
- 若沒有 Ticker 總整理頁，不代表 vault 沒資料。改查 frontmatter 中的 `tickers`、`related_tickers`、`companies_mentioned`，並找相關 Theme/Signal/mini-summary。
- 同時找公司名、產品名、同業名可能出現的 Theme，例如軟體公司可能連到 `Theme-ai-intangible-capital`、`Theme-agentic-ai-token-economics`、`Theme-ai-infrastructure`。

初步產業主題研究報告：
- 第一種子：`1 Cards/Theme-*.md`，優先讀「主題定義」與「趨勢演變紀錄」。
- 第二種子：`3 Analysis/Signals/` 中同主題的累積訊號。
- 第三種子：近期 `3 Analysis/Daily/` 與 `3 Analysis/Daily/_mini-summaries/`，用來找最新批次判斷與歷史比對。

### 1b. 連結圖譜擴散規則

從種子節點讀三種連結：

1. Outgoing wikilinks：讀該筆記明確連出去的 Theme、Signal、日報、研究報告、Ticker 總整理。
2. Backlinks：查有哪些日報、mini-summary、Signal、Theme 或來源筆記反向連回該節點。這通常能找到最新觀點演變。
3. Frontmatter graph：沿 `themes`、`related_tickers`、`companies_mentioned`、`supply_chain`、`signal_tags`、`catalysts`、`conflict_flag`、`unmatched_terms` 找鄰近節點。

擴散深度限制：
- 第一層連結是核心脈絡，優先完整讀濃縮節點。
- 第二層只讀高價值節點，例如 Theme 趨勢演變、Signal 更新、同業對照、觀點衝突、催化劑。
- 不要看到連結就全部打開。若關聯只剩泛泛同產業或低訊號來源，停在摘要層。

Snowflake 類型範例：
- 若 `3 MOC/Tickers/SNOW-研究總整理.md` 不存在，不要直接全庫寬搜。
- 先查 `related_tickers: [SNOW]`、軟體/雲端/AI 資料平台相關 Theme、AI 軟體貨幣化 Signal、近期 mini-summary。
- 若發現 `Theme-ai-intangible-capital`、`Theme-agentic-ai-token-economics`、`AI軟體貨幣化`、GS 軟體報告與 NOW/PLTR/Databricks 對照，這些就是高價值圖譜脈絡。

### 1c. 搜尋關鍵字規則（避免假陽性）

台股四位數代號（如 2404、3680）容易誤中圖片尺寸、日期等無關數字。搜尋順序：

1. 優先搜公司中文名（如「漢唐」「家登」）——準確率最高
2. 再搜帶後綴格式（如「2404.TW」）——減少假陽性
3. 最後才搜純數字代號（如「2404」）——僅用於 frontmatter 的 tickers 欄位搜尋
4. 美股代號（如 NVDA、AAPL）直接搜，假陽性較少

全文搜尋補漏規則：
- 只有在濃縮節點、frontmatter graph、wikilink/backlink 都不足時才做。
- 優先限制資料夾，例如只搜 `2 Sources/Reports`、`2 Sources/Research`、`3 Analysis/Signals`、`3 Analysis/Daily/_mini-summaries`。
- 不要用過寬關鍵字掃整個 vault；大 vault 寬搜容易 timeout，也會把低相關日報全部拖進來。

### 1d. 報告讀取策略（省 token 關鍵）

搜尋到報告列表後，不要全部整份讀進來。分級處理：

高相關（主角報告、ticker 直接命中）：整份讀取
中相關（related_tickers 命中、同 theme 報告、backlink 命中）：先用 get_vault_file 只讀前 80 行（frontmatter + 摘要），判斷相關度後才決定是否讀全文
低相關（同 sector 但不同標的、反向搜尋命中）：只取 frontmatter 中的 key_thesis、key_data、themes、catalysts 欄位，不讀正文

判斷標準：如果報告的 key_thesis 或內文摘要直接提到本標的的公司名或產品，升級為高相關讀全文。否則維持中/低相關的簡讀策略。

### 1e. 個股模式的兩層圖譜搜尋

第一層：直接命中

1. Ticker 總整理頁：用 get_vault_file 讀取 3 MOC/Tickers/[TICKER]-研究總整理.md（注意有些帶 .TW 後綴如 2330.TW-研究總整理.md，搜不到就試另一種格式）
2. 主角報告：用 search_vault 搜尋 frontmatter 中 tickers 包含該代號的所有報告
3. 配角報告：用 search_vault 搜尋 frontmatter 中 related_tickers 包含該代號的報告
4. 連入搜尋：查哪些 Theme、Signal、日報、mini-summary、研究報告反向連到該公司、Ticker 或主角報告
5. 關鍵字補漏：用 Obsidian MCP 可用的搜尋工具（例如 `search_vault` 或等效搜尋）搜尋公司中文名或產品名，但要優先限制資料夾

第二層：沿 frontmatter 往外擴（從第一層找到的報告出發）

6. themes 擴展：提取所有找到報告的 themes 值，讀取對應的 1 Cards/Theme-[theme].md 主題卡片
7. supply_chain 追蹤：從報告的 supply_chain 欄位找到上下游公司，搜尋這些公司的報告
8. related_tickers 擴展：報告中的 related_tickers 是競爭對手、供應商、客戶，搜尋這些公司的 Ticker 總整理頁
9. sectors 同業：搜尋同 sector 但不同標的的報告，找出產業大環境
10. catalysts 整合：讀取 3 MOC/催化劑日曆.md（若存在）
11. conflict_flag 整合：若任何來源標記觀點衝突，讀衝突對象並在報告中列出分歧核心

注意：投資智慧卡片（1 Cards/）的搜尋移到 Step 2.5，等掌握完整財務數據後才做，搜尋更精準。

### 1f. 產業主題模式的兩層圖譜搜尋

第一層：直接命中

1. Theme 卡片：用 Obsidian MCP 可用的搜尋工具搜尋 Theme- 開頭的檔案，找到對應的卡片名，用 `get_vault_file` 讀取完整內容（特別注意「趨勢演變紀錄」區塊）
2. Signal 卡片：搜尋 `3 Analysis/Signals/` 中同主題的累積訊號，優先讀「訊號摘要」「本次證據」「更新判斷」「追蹤指標」
3. Daily / mini-summary：搜尋近期 `3 Analysis/Daily/` 與 `_mini-summaries/` 中同主題的 batch 判斷
4. 主題報告：用 search_vault 搜尋 frontmatter 中 themes 包含相關主題的所有報告
5. 產業報告：用 search_vault 搜尋 frontmatter 中 sectors 包含相關產業的報告
6. 關鍵字擴大搜尋：用 Obsidian MCP 可用的搜尋工具搜尋相關同義詞和子概念，但限制資料夾與結果數

第二層：沿 frontmatter 往外擴

7. tickers 高頻統計：統計所有找到報告中 tickers 和 related_tickers 的出現頻率，對高頻公司讀取其 Ticker 總整理頁
8. supply_chain 彙整：從所有報告的 supply_chain 欄位彙整完整的產業鏈地圖
9. 供應鏈索引 MOC：讀取 3 MOC/產業供應鏈索引.md（若存在）
10. 催化劑日曆：讀取 3 MOC/催化劑日曆.md（若存在）
11. 跨 Theme 交叉：從報告的 themes 欄位找出與本主題同時出現的其他 theme
12. backlinks 交叉：查哪些日報、mini-summary、Signal 反向連回本 Theme 或核心報告，找出最新觀點演變

### 1g. 時效性加權（強制規則）

搜尋到的所有報告，按日期分為四個權重等級：

- 1 個月內（高權重）：視為最新情報，直接引用，不加時效性警告
- 1-3 個月（中權重）：正常引用，標注日期
- 3-6 個月（低權重）：引用時標注「此報告已有 N 個月歷史，數據可能已更新」
- 超過 6 個月（極低權重）：僅用於歷史脈絡和結構性分析，具體數字一律不引用

但以下資料不受時效限制：
- 結構性投資主題（能源轉型、AI 電力需求等）
- 產業結構分析（供應鏈關係、技術路線）
- 1 Cards/ 裡的交易哲學和投資智慧
- 歷史類比（可作為當前判斷參考）

### 1h. 定錨報告特殊解讀規則

vault 中 95% 的報告來自定錨産業筆記，必須理解其特殊語法：

- 「定錨預估」「定錨認為」：定錨自己的獨立觀點，有份量
- 「根據定錨研調」：定錨自己的產業調查，通常含獨家資訊，權重最高
- 「經營層表示」：公司管理層說法，引用時標注「公司方面表示」以提醒可能有美化成分
- ==highlight 段落==：原文中被標記為特別重要的判斷，報告中應優先引用
- 「定錨預估，20XX年財測EPS上修至X.X元(前次預估X.X元)」：財測修正訊號，必須追蹤完整軌跡

財測追蹤方法：搜出同一 ticker 的所有報告，按 date 排序，從 key_data 和內文中提取各時期 EPS 財測數字，呈現修正軌跡：
- 連續上修：基本面持續超預期
- 連續下修：基本面惡化
- 反覆修正：能見度低

---

## Step 2：網路補充搜尋

Step 1 搜完後直接進入此步驟，不要停下來。根據 Step 1 搜尋結果中發現的缺口，用財報狗 + web search 補充。

### 2a. 個股模式：財報狗數據抓取（優先）

台股與美股個股報告都優先使用財報狗（statementdog.com）抓取結構化財務數據。財報狗可以看到股價、財報、財務指標、估值資料；美股若有法說會逐字稿，也優先使用財報狗。財報狗可見的資料視為可信來源，不需要為同一數字再交叉驗證 3 個來源。

必須使用可互動的 Codex Browser/Chrome 工具開啟財報狗頁面；不要只靠一般 web fetch。財報狗動態頁採標準讀取流程：先用登入狀態開頁，等資料載入約 5 秒，看畫面是否有圖表或「詳細數據」，再讀文字層。若文字層抽不到但畫面有表格，改用表格區截圖/視覺讀表；DOM row/table count 只能輔助，不能當作資料不存在的判斷。若一種方法失敗，不要反覆重試同一招，直接換下一種方法。只有畫面與替代讀法都看不到核心資料，才停止並告知使用者；不要用其他來源假裝補完。

台股 URL 常見格式：
https://statementdog.com/analysis/{股票代號}/{頁面路徑}

核心必訪頁面（依優先順序，至少訪問前 5 個）：

1. /profit-margin — 獲利能力：毛利率、營業利益率、稅前/稅後淨利率的季度趨勢。用來填寫報告第五節財務分析。子選單還有：營業費用率拆解、業外佔比、ROE/ROA、杜邦分析、經營週轉能力、合約負債佔營收比例、現金股利發放率
2. /pe — 本益比評價：PE 歷史數據和月度 PE。用來填寫估值分析、判斷股價位階。子選單還有：PB 河流圖、現金股利殖利率
3. /monthly-revenue — 每月營收：月營收絕對值和 YoY 成長率。用來填寫財務表現和成長趨勢
4. /monthly-revenue-growth-rate — 月營收成長率：單月 YoY%，搭配股價走勢判斷動能。子選單還有：營收/毛利/營業利益/稅後淨利/EPS 各項成長率
5. /eps — 每股盈餘：季度 EPS 歷史，搭配定錨財測做交叉驗證

條件補充頁面（能讀到資料才引用；讀不到時改用公司原始資料補）：

6. /product-revenue — 產品組合：各業務線的季度營收拆解。此頁可能受方案限制；若顯示需要升級方案，改用公司 IR、年報/10-K、法說或公開資訊觀測站。
7. /financial-structure-ratio — 安全性分析：負債比趨勢。子選單有：流動比率、利息保障倍數、現金流量分析
8. /long-term-and-short-term-monthly-revenue-yoy — 關鍵指標：3/6/12 月累計營收 YoY，判斷長短期動能。子選單有：自由現金流報酬率、Piotroski F 分數、彼得林區評價、現金流折現評價、大股東持股比率
9. /dividend-policy — 股利政策：歷年股利數據
10. /broker-trading — 分點籌碼：券商買賣超與分點籌碼動向，只作波段交易參考，不等於董監持股或公司基本面。

抓取方式：先看畫面，再讀文字。等載入後，多數核心頁可直接從文字層讀到「詳細數據」。若文字層讀不到，但畫面表格可見，截取表格區讀表。只截表格區，避免 AI 聊天泡泡、工具列或偵錯橫幅遮住數字。每個頁面的數據表格通常在圖表下方，預設顯示季報，可切換為年報。表格下方若有產業排名比較，也值得記錄。

注意事項：
- 頁面剛開時可能只顯示載入中，先等約 5 秒再判斷，不要一進頁就抽資料。
- 頁面可開不等於資料可讀；但判定不可讀前，必須先做畫面確認，不要只相信 DOM 抽取結果。
- `broker-trading` 沒有「詳細數據」也可能有可讀資料，例如主力淨買賣超與券商買賣清單。
- 核心必訪頁若無法讀取，停止並告知使用者；條件補充頁若無法讀取，標註缺口並改用公司原始資料補足。
- 財報狗首頁通常可看到最新股價、漲跌幅、主要指標概覽
- 每個分析頁面都有「產業排名」區塊，可用來填寫第三節競爭格局
- 數據來源為公開資訊觀測站，可信度高

美股法說會逐字稿：
- 在美股個股頁進入「財務報表 > 電子書」。
- 找「法說會逐字稿」清單；連結通常是 `/analysis/TICKER/earnings_calls/{id}`。
- 點入後讀內容摘要、成長動能/風險、法人問答、完整譯文與英文原文/中譯對照。
- 正式引用時優先看英文原文；中文摘要與 AI 翻譯只作輔助。

### 2b. 個股模式其他需要補充的資訊

除了財報狗數據外，仍需用 web search 補充：
- 近期重大新聞或事件（財報狗不提供新聞）
- 同業最新動態或競爭格局變化
- 法人最新看法（目標價、評等）
- 台股可搜尋 MoneyDJ、CMoney、證交所等來源

### 2c. 產業主題模式需要補充的資訊

- 最新產業數據（市場規模、成長率、滲透率）
- 近期政策或法規變動
- 最新技術發展
- 近期重大併購或投資案
- 主要研究機構的最新預測

### 2d. 搜尋策略

- 台股公司：先用可互動瀏覽器工具開財報狗抓取結構化財務數據，再用 web search 補充新聞和法人觀點，優先找 MoneyDJ、CMoney、證交所等來源
- 美股公司：先用可互動瀏覽器工具開財報狗抓取股價、財報、估值與法說逐字稿；財報狗不足時再補公司 IR、SEC、交易所、可靠新聞或分析來源
- 產業主題：同時搜中英文，找產業研究報告、新聞、分析

---

## Step 2.5：投資智慧卡片作為觀察框架（Step 2 完成後才做）

此步驟必須在 Step 1（vault 搜尋）和 Step 2（財務數據抓取）都完成後才執行。這裡的投資智慧卡片只用來建立後續追蹤與觀察框架，不做買入、加碼、減碼或賣出判斷。若使用者要當下買賣決策，改用 `advanced-research-report`。

根據 Step 1 和 Step 2 取得的實際數據，描述當前股票/主題的狀態，然後搜尋可作為觀察框架的卡片：

個股模式——根據實際財務數據判斷：
- 定錨連續上修 EPS：搜尋「獲利擊敗預期」「盈餘的突破」
- 月營收 YoY 大幅成長（財報狗數據）：搜尋「營收上升」「第二階段」
- PE 在歷史高位或快速擴張（財報狗 PE 頁）：搜尋「本益比」「強勢股的本益比」
- 股價剛從盤整突破（財報狗股價走勢）：搜尋「突破」「洗盤」
- 領導股特徵明顯：搜尋「領導股」「領先大盤」
- 股價生命週期判斷：搜尋「股價生命循環」「買在上升階段」

產業主題模式——根據產業階段判斷：
- 產業景氣初升段：搜尋「多頭初期」「領導類股」
- 產業景氣持續擴張：搜尋「多頭在第三年」「營收上升存貨上升」
- 產業景氣過熱跡象：搜尋「崩盤通常以暴漲為前導」

用 Obsidian MCP 可用的搜尋工具搜尋關鍵字找到相關卡片，每張只需讀取核心觀點（通常很短），不用讀整篇。挑選 2-4 張最適用的卡片即可，不用全部找出來。

---

## Step 3：撰寫報告

網路搜尋和卡片套用完後直接開始寫，不要停下來。

報告結構直接按以下核心框架寫，不需要再去讀 references/ 下的模板檔案（框架已內嵌於此）：

### 個股報告核心結構（11 節）

一、公司概覽（基本資訊表 + 核心業務描述）
二、營收結構與產品線（營收拆解表 + 各產品線說明 + 客戶地區分布）
三、產業地位與競爭格局（產業概況 + 競爭對手比較表 + 護城河分析）
四、供應鏈定位（產業鏈位置 + 供應鏈風險與機會）
五、財務分析（近期財務表現表 + 定錨財測追蹤 + 歷史評等目標價 + 估值分析）
六、成長動能與催化劑（短期催化劑 + 中長期成長動能 + vault 觀點演變）
七、風險因素（基本面風險 + 外部風險 + vault 衝突觀點）
八、投資智慧觀察框架（股價生命週期線索 + 可追蹤的交易哲學 2-3 張卡片，不做買賣建議）
九、跨報告發現（多報告交叉驗證 + 跨主題意外連結 + 觀點衝突彙整 + 資訊缺口）
十、Vault 資料庫覆蓋度診斷（直接填入 Step 0 的追蹤器數據）
十一、結論與觀察（5-8 句總結）

附錄：Dataview 相關連結區塊（自動生成，見 Step 3a）

### 產業主題報告核心結構

參照 references/industry-theme-template.md，需要時再讀取。

### 3a. Dataview 區塊自動生成

報告最後的「相關連結」區塊是固定的 Dataview 查詢語法，只需要帶入 frontmatter 值即可。直接套用以下模板，不用每次手寫：

```
## 相關連結（自動）

### 同標的報告
\`\`\`dataview
TABLE source AS "來源", date AS "日期", rating AS "評等", key_thesis AS "論點"
FROM "2 Sources"
WHERE file.name != this.file.name AND any(tickers, (t) => contains(this.tickers, t))
SORT date DESC
LIMIT 15
\`\`\`

### 同主題報告
\`\`\`dataview
TABLE source AS "來源", date AS "日期", key_thesis AS "論點"
FROM "2 Sources"
WHERE file.name != this.file.name AND any(themes, (t) => contains(this.themes, t))
SORT date DESC
LIMIT 10
\`\`\`

### 供應鏈相關報告
\`\`\`dataview
TABLE source AS "來源", date AS "日期", tickers AS "標的"
FROM "2 Sources"
WHERE file.name != this.file.name AND (any(tickers, (t) => contains(this.related_tickers, t)) OR any(related_tickers, (t) => contains(this.tickers, t)))
SORT date DESC
LIMIT 10
\`\`\`

### 投資主題卡片
\`\`\`dataview
LIST
FROM "1 Cards"
WHERE type = "theme-card" AND contains(this.themes, theme)
\`\`\`
```

### 撰寫原則（兩種模式通用）

1. Vault 資料為主體：報告中至少 60% 的內容要來自 vault，用 [[wikilink]] 標注引用來源
2. 網路資料為補充：標注「根據網路資料」並附來源連結
3. 財報狗資料標注：標注「根據財報狗數據，截至 YYYY-MM-DD」
4. 時效性加權：嚴格按 Step 1e 的四級權重處理
5. 定錨語法解讀：嚴格按 Step 1f 的規則處理定錨報告
6. 觀點演變：如果 vault 中不同時期有不同看法，要呈現完整演變軌跡
7. 跨報告串聯：主動找出不同報告之間的交叉點和矛盾
8. 投資智慧套用：在適用的段落引用 1 Cards/ 中的投資哲學卡片，用 [[wikilink]] 連結，但只作觀察框架，不作買賣判斷
9. 篇幅 3000-6000 字：完整深度但不灌水
10. 繁體中文：全文繁體中文，技術術語附英文原文
11. 技術概念白話解釋：所有理工技術用高中生聽得懂的方式說明
12. 禁止箭頭符號：不使用任何方向符號，用文字連接詞代替
13. 禁止粗體：不使用 ** 粗體（Markdown 標題 # 除外）

### Markdown 表格防呆（強制）

- 在 Markdown 表格儲存格內，禁止使用帶 alias 的 Obsidian wikilink，例如 `[[6525.TW|捷敏-KY]]`。其中的 `|` 會被 Markdown 表格解析成欄位分隔符，導致表格破裂。
- 表格內若需要顯示公司名稱，改用純文字，例如 `捷敏-KY（6525.TW）`；若一定要連結，只用不含 alias 的 wikilink，例如 `[[6525.TW-研究總整理]]`。
- 需要漂亮顯示名稱時，把 alias wikilink 放在表格外的補充段落或列表中，例如 `相關標的：[[6525.TW|捷敏-KY]]`。
- 寫完含表格的 Obsidian 筆記後，自我檢查每一列的欄位數一致，且表格儲存格內沒有 `[[...|...]]`。

---

## Step 4：存入 Obsidian Vault

報告寫完後，直接按以下標準格式存檔，不需要停下來問使用者確認。

### 檔名格式

YYYY-MM-DD-初步研究-[標的名稱].md

- 日期用今天的日期
- 個股範例：2026-04-22-初步研究-家登(3680).md
- 主題範例：2026-04-22-初步研究-先進封裝.md

### 存放位置

2 Sources/Research/

### 直接存檔

用 `mcp__obsidian_mcp_tools.append_to_vault_file` 對新檔名寫入完整內容；此工具可建立新筆記或追加既有筆記。不問使用者檔名或路徑。若工具未露出，先依 Codex 相容性規則載入並驗證；存完後進入 Step 5。

---

## Step 5：完成回報

存檔後，輸出簡短摘要：

1. 報告標題與 [[wikilink]]
2. 引用了多少份 vault 資料（列出關鍵的 3-5 份）
3. 參考了哪些投資智慧卡片作為後續觀察框架
4. 網路補充了哪些資訊
5. 3 句話摘要報告核心結論
6. 跨報告訊號或觀點衝突提醒

注意：vault 覆蓋度診斷已經寫在報告第十節裡面了，完成回報時不需要再重複一次。

---

## Frontmatter 格式

```yaml
---
date: YYYY-MM-DD
tags: [initial-research-report, research-report, 其他相關 tag]
source: Codex 初步研究
tickers: [相關股票代碼]
sectors: [相關產業]
report_type: individual-stock 或 thematic-report
key_thesis:
  - 核心論點 1
  - 核心論點 2
  - 核心論點 3
key_data:
  - 關鍵數據 1
  - 關鍵數據 2
themes:
  - 相關主題 1
  - 相關主題 2
supply_chain:
  upstream: [上游]
  midstream: [中游]
  downstream: [下游]
related_tickers: [相關但非主角的標的]
regions: [相關地區]
catalysts:
  - date: YYYY-MM-DD
    event: 催化劑事件描述
status: draft
---
```

themes 命名必須先查 vault 中 1 Cards/ 的 Theme 卡片，確保與既有命名一致。
若報告不涉及供應鏈，supply_chain 欄位完全省略。
若無催化劑，catalysts 欄位完全省略。

---

## 禁用事項

1. 禁止使用簡體字或中國大陸用語
2. 禁止箭頭符號（用文字連接詞代替）
3. 禁止粗體（Markdown 標題除外）
4. 禁止編造數據（不確定就說不確定）
5. 禁止只用網路資料而忽略 vault（vault 是主體，60% 以上內容必須來自 vault）
6. 存檔一律按標準格式直接存，不問使用者
7. 禁止引用超過 6 個月的具體數字（股價、目標價、EPS）而不附時效性警告
8. 禁止 vault 搜尋不完整就開始動筆（兩層搜尋每一層都要做）
9. 禁止在搜尋完後停下來問使用者「覆蓋夠不夠」「要不要繼續寫」（直接寫）
10. 禁止對低相關報告整份讀取（只讀 frontmatter，按 Step 1b 分級策略）
11. 禁止在未取得財務數據前就搜尋投資智慧卡片（必須等 Step 2 完成後才做 Step 2.5）；初步研究中的投資智慧卡片只能作觀察框架，不做買賣決策
12. 禁止在 Markdown 表格儲存格內使用 `[[頁面|顯示文字]]` 形式的 alias wikilink；表格內改用純文字或不含 alias 的 wikilink
