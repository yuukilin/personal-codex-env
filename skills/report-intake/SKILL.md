---
name: report-intake
description: >
  整理報告收件夾中的投資研究報告，建立 Obsidian 索引筆記、重新命名檔案、更新 MOC。
  使用者將報告（PDF、Word、Excel、圖片、.md 等任何格式）放進桌面的「報告收件夾」資料夾後，
  對 Claude 說「整理報告」，Claude 即掃描資料夾（含子資料夾）、讀取每份報告、
  產出詳細索引筆記到 Obsidian vault 的對應資料夾（依來源路由），並將原始檔案歸檔到 Attachments。
  此 Skill 僅在使用者明確說出「整理報告」「處理報告」「掃描報告」「報告整理」等關鍵字時觸發。
  若使用者說「寫週報」「ELN」「月報」「寫新聞」等其他 skill 的觸發詞，不要觸發此 Skill。
---

# Report Intake — 研究報告收件整理

## 核心任務

使用者是投資研究人員，會不定期收到各種研究報告。報告會先放在桌面的「報告收件夾」資料夾裡。你的工作是：

1. 掃描報告收件夾（含所有子資料夾）
2. 讀取每份報告的完整內容
3. 為每份報告在 Obsidian vault 建立一份詳細的索引筆記（含 themes、supply_chain、related_tickers 等跨報告連結欄位）
4. 將原始檔案重新命名為統一格式
5. 更新相關的 MOC（Map of Content），包含產業供應鏈索引
6. 建立或更新投資主題卡片（Theme Notes），偵測新興趨勢訊號
7. 將原始檔案歸檔到 vault `Attachments/`；若權限不足才請使用者授權或使用搬移腳本

---

## 環境與路徑

| 項目 | 路徑 |
|------|------|
| 報告收件夾（使用者電腦） | `~/Desktop/報告收件夾/` |
| 報告收件夾（Codex） | 優先嘗試直接讀取 `/Users/yuukilin/Desktop/報告收件夾/`。若沙盒或權限阻擋，向使用者要求授權；不要使用 Cowork 掛載工具。後續文件中以 `$INBOX_PATH` 代稱此路徑。 |
| Obsidian Vault 名稱 | 卡片筆記盒模板 |
| 索引筆記存放位置 | 依來源智慧路由，見 Step 4e 的路由規則 |
| 附件存放位置 | vault `Attachments/` |
| 搬移腳本位置 | `~/Desktop/搬移報告到Obsidian.command`（僅作權限不足時的 fallback） |
| MOC 位置 | vault `3 MOC/` |
| Ticker 總覽頁位置 | vault `3 MOC/Tickers/` |

**關鍵限制**：
1. Vault 讀寫優先使用 Obsidian MCP（`mcp__obsidian-mcp-tools__*`）。若本回合未提供 MCP、MCP timeout，且本機 vault 路徑可讀寫，可直接使用本機路徑 fallback，完成後再驗證檔案位置。
2. 此 skill 從 Cowork 搬到 Codex 後，不再使用 `mcp__cowork__request_cowork_directory` 或 `/sessions/<session-id>/mnt/...` 路徑。
3. 圖片讀取用 Codex 可用的圖片/文件工具；不要把「Read 工具」當成固定工具名稱。
4. 新索引筆記只可寫入 canonical 路徑：`2 Sources/定錨/`、`2 Sources/Research/`、`2 Sources/Reports/`。自動化逐字稿來源由各自管線寫入 `2 Sources/TW-Earnings/`、`2 Sources/US-Earnings/`、`2 Sources/Podcasts/`。
5. 禁止寫入或新建舊路徑：根目錄 `TW-Earnings/`、根目錄 `法說會/`、`0 Inbox/pending-analysis/`、`03-投資研究/`、`2 Sources/Transcripts/`、`2 Sources/Articles/`。

---

## 完整處理流程

### Step 0：確認報告收件夾

在做任何事之前，先確認使用者桌面上的報告收件夾是否存在。

1. 將 `$INBOX_PATH` 設為 `/Users/yuukilin/Desktop/報告收件夾`
2. 檢查資料夾是否存在且可讀
3. 若權限不足，向使用者要求授權讀取該資料夾
4. 若資料夾不存在，提示使用者確認桌面上是否存在「報告收件夾」資料夾

```
INBOX_PATH = /Users/yuukilin/Desktop/報告收件夾
```

### Step 1：掃描報告收件夾

用 Bash 掃描 `$INBOX_PATH/`，包含所有子資料夾。收集每個檔案的：
- 檔名
- 來源子資料夾（若在根目錄則標「根目錄」）
- 格式（副檔名）
- 檔案大小
- 初步判斷的來源機構（從檔名推測）
- 初步判斷的主題

掃描指令範例：
```bash
find "$INBOX_PATH" -type f \( -iname "*.pdf" -o -iname "*.doc" -o -iname "*.docx" -o -iname "*.pptx" -o -iname "*.ppt" -o -iname "*.xlsx" -o -iname "*.xls" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.heic" -o -iname "*.md" \) -exec ls -lh {} \;
```

### Step 2：增量處理——比對已存在的索引筆記

優先用 Obsidian MCP 的 `search_vault` 工具，搜尋 `2 Sources/` 底下所有子資料夾中已存在的索引筆記。若本回合沒有 MCP，改用本機 vault 路徑掃描 `2 Sources/`。比對原始檔名是否已出現在某份索引筆記的 frontmatter 或內文中（可搜尋重新命名後的檔名或原始檔名片段）。已處理過的檔案標記為「已處理，跳過」。

**定錨舊文改版例外（不可跳過）**：
- 定錨爬蟲會因為舊報告改版而把同一 URL 或同一檔名重新放回收件夾。
- 若收件夾檔案已存在於某份索引筆記的 `report_intake.original_url` 或 `report_intake.original_filename`，不要立刻跳過；先計算目前收件夾檔案清理後內容的 hash，並與既有索引的 `report_intake.content_hash` 比對。
- hash 相同：標記為「已處理，跳過」，並把收件夾檔案移到 `Attachments/已處理重複/` 或桌面已整理備份，避免下次重掃。
- hash 不同：標記為「舊文改版」，不可建立第二份重複索引。應先讀既有索引與新版原文，比對是否只是校字小修或有投資論點變化；小修可更新主附件並保留舊版備份，重大變化才重寫摘要、更新 `report_intake.content_hash` 與 Theme/Ticker/MOC。
- 回報時把這類檔案列為「版本更新」而非「新報告」。

### Step 3：自動處理（嚴格禁止要使用者確認）

掃描完報告收件夾後，自動跳過已處理檔，直接開始處理所有待處理檔。**禁止列清單給使用者確認，禁止問「要全部處理還是指定編號」**。

唯一需要呈現給使用者的是一句話的「掃描結果摘要」，僅供告知，不等回應，立即進入 Step 4：

```
本次掃描到 N 份報告：已處理 X 份（跳過），待處理 Y 份（開始處理中）。
```

例外狀況（這幾種才需要問使用者，其他一律不問）：
1. 某份檔案的「已處理 vs 待處理」判斷不確定（同主題不同日期，可能是新版報告）。把不確定的列出來，其他確定的繼續自動處理。
2. 報告收件夾掃描為空，或者所有檔案都已處理過（無事可做）。
3. 使用者在本次對話中明確說過要逐份確認。

除上述例外，一律自動處理，禁止再問「要不要全部處理」「要處理哪幾份」這類確認問題。

### Step 4：逐份讀取與建立索引筆記

對每份確認要處理的報告，依以下子步驟處理：

#### 4a. 讀取報告內容

- **PDF**：用可用的 PDF / 文件讀取工具讀取（路徑為 `$INBOX_PATH` 加上檔案相對路徑），大型 PDF 分批讀取
- **.md 檔案**：用本機讀檔方式直接讀取文字內容
- **Word (.docx)**：用 Bash 搭配 Python `python-docx` 讀取（需先 `pip install python-docx --break-system-packages`）
- **Word (.doc)**（舊版格式）：python-docx 不支援 .doc，改用 `libreoffice --headless --convert-to txt "/path/to/file.doc" --outdir /tmp/` 轉為純文字後讀取
- **Excel (.xlsx)**：用 Bash 搭配 Python `openpyxl` 讀取
- **PPT (.pptx)**：用 Bash 搭配 Python `python-pptx` 讀取
- **圖片（png/jpg/heic）**：用 Codex 可用的圖片檢視工具讀取並辨識內容
- **加密/損毀/無法讀取**：標記為「待手動處理」，記錄失敗原因，跳過此檔，繼續處理下一份

#### 通用預處理（所有格式的報告在摘要前都要做）

不論報告來自什麼來源、什麼格式，讀取完內容後，先做以下三件事：

1. 重建文件大綱
   - 找出原文的層級結構（H1/H2/H3 標題、編號系統、縮排層級、分頁符號等）
   - 如果原文沒有明確標題（例如純編號制），就用編號的層級關係重建大綱
   - 如果是 HTML-heavy 的 .md，用 margin-left 的數值判斷層級
   - 寫下這份報告的章節大綱（不需要輸出給使用者，自己心中建立即可）

2. 標記高價值段落
   - 掃描原文中是否有特殊標記（highlight、粗體、底色、框線、★ 等）
   - 這些標記通常代表來源機構認為最重要的判斷或獨家資訊
   - 在摘要中，這些段落用 ==highlight== 語法保留
   - 若原文用 `background-color:#ffffcc` 或類似 CSS 標記，視為 highlight

3. 偵測追記/更新
   - 檢查原文尾段是否有日期標記的追記或更新段落
   - 這些追記可能修正前文的預測值，必須在摘要中獨立呈現
   - 格式：用 `### 更新追記：YYYY/MM/DD` 標題區隔

#### 4b. 分析報告內容

讀完後判斷以下欄位：
- **source**：來源機構全名（Goldman Sachs、Morgan Stanley、JP Morgan、元大、凱基等）
- **date**：報告發布日期（從內文或檔名判斷）
- **report_type**：從以下類型中選擇最接近的：
  - `individual-stock`：個股研報（含評等、目標價）
  - `sector-report`：產業報告
  - `thematic-report`：主題報告（跨產業趨勢研究）
  - `macro-report`：總經報告
  - `market-commentary`：市場評論
  - `strategy-morning-note`：策略報告或晨報
  - `newsletter`：電子報、訂閱通訊（如狐說八道、Anduril、SemiAnalysis、Substrate Stack 等個人或媒體發行的定期通訊）
  - `earnings-presentation`：法說會簡報、財報簡報（公司自行發布的季度/年度業績發表投影片）
  - `index-factsheet`：指數說明書、指數方法論（如 S&P、DJSI、MSCI 等指數編制機構發布的 factsheet）
  - `academic-paper`：學術論文、研究院報告（如台綜院、工研院、大學研究報告等）
  - `financial-statement`：公司財務報表、年報、季報（公司自行發布的財務數據文件，非分析師研報）
- **tickers**：涉及的股票代碼列表
- **sectors**：涉及的產業（英文小寫）。常見值參考清單（非窮舉，可依報告內容新增）：
  - 科技類：semiconductor, software, cloud, cybersecurity, ai-infrastructure
  - 能源類：energy, utilities, nuclear, clean-energy, oil-gas, lng
  - 工業類：industrials, aerospace-defense, transportation, construction
  - 原物料：materials, mining, gold, copper, uranium, commodities
  - 金融類：financials, banking, insurance, real-estate
  - 消費類：consumer, retail, food-beverage, luxury
  - 醫療類：healthcare, biotech, pharma, medical-devices
  - 其他：macro, multi-sector, space, ev, agriculture
- **tags**：依報告內容決定（英文小寫）
- **rating**：評等（僅個股報告，如 Buy / Neutral / Sell）
- **target_price**：目標價（僅個股報告）
- **key_thesis**：一句話核心論點（繁體中文，方便未來 AI 檢索）
- **key_data**：關鍵數據列表（預測值、目標價、關鍵百分比等結構化數據）
- **themes**：從報告中抽取的投資主題標籤（英文小寫、用連字號連接），這些是跨產業的概念性主題，不同於 sectors。範例：ai-datacenter-power、ev-adoption、reshoring、interest-rate-cycle、commodity-supercycle、energy-transition、us-china-decoupling、grid-modernization。一份報告通常有 1-3 個主題。判斷原則：問自己「這篇報告在說哪個投資大趨勢」
- **supply_chain**：報告涉及的產業鏈上中下游關係。**格式必須是 YAML 物件，包含 upstream、midstream、downstream 三個子欄位，每個子欄位的值為 YAML 陣列**。嚴格禁止寫成字串或扁平列表。若報告不涉及供應鏈，則整個 supply_chain 欄位不要寫進 frontmatter（不是寫空物件 `{}`，是完全省略），這樣 Dataview 的 `WHERE supply_chain` 才能正確過濾。正確範例：
  ```yaml
  supply_chain:
    upstream: [polysilicon-producers, FSLR]
    midstream: [module-assembly, ENPH]
    downstream: [utility-scale-solar, NEE]
  ```
  錯誤範例（嚴格禁止）：
  ```yaml
  supply_chain: "上游原料 -> 中游製造 -> 下游應用"   # 禁止：不可寫成字串
  supply_chain:
    - upstream: xxx   # 禁止：不可寫成陣列套物件
  ```
- **related_tickers**：報告中提及但非主角的其他股票代碼。與 tickers（主角）區分。這些是報告順帶討論到的競爭對手、供應商、客戶等，用於跨報告連結
- **regions**：報告涉及的地理區域（英文小寫）。常見值參考清單（非窮舉，可依報告內容新增）：us, china, taiwan, japan, korea, europe, brazil, latam, india, southeast-asia, middle-east, africa, global。一份報告通常標 1-3 個。判斷原則：這篇報告的分析對象、市場或地緣影響主要涉及哪些區域。若為純總經報告且涵蓋全球，標 global
- **catalysts**：報告中提及的未來關鍵催化劑或事件節點。格式必須是 YAML 陣列，每個項目包含 `date`（YYYY-MM-DD 或 YYYY-MM 或 YYYY-QN，視報告精確度而定）和 `event`（繁體中文描述）。若報告未提及任何未來事件，整個 catalysts 欄位完全省略。正確範例：
  ```yaml
  catalysts:
    - date: 2026-05-12
      event: USDA 5月 WASDE 報告
    - date: 2026-Q2
      event: 台積電法說會，關注 AI 營收占比指引
    - date: 2026-06
      event: Fed 6月利率決議
  ```

#### 4b-extra. Theme 命名一致性驗證（極重要）

themes 的命名一致性是整個跨報告連結系統的命脈。如果同一個趨勢在不同報告被標成不同名稱（例如 `ai-datacenter-power` vs `ai-data-center` vs `datacenter-energy`），所有 Dataview 查詢和趨勢偵測都會失效。

**強制流程**：
1. 在為每份報告填寫 themes 之前，先用 Obsidian MCP 的 `search_vault` 搜尋 `1 Cards/` 資料夾中所有 `Theme-` 開頭的檔案，取得已存在的 theme 清單
2. 對每個你準備標記的 theme，先比對已存在的 theme 清單：
   - 若已存在完全匹配的 theme，直接使用（一個字母都不能改）
   - 若已存在語意相近但名稱不同的 theme（如你想標 `ai-power-demand`，但已有 `ai-datacenter-power`），必須使用已存在的那個名稱，不要建新的
   - 只有在確認 vault 中完全沒有相關 theme 時，才能建立新的 theme 名稱
3. 命名規則：全英文小寫，單詞間用連字號 `-` 連接，2-4 個單詞，要有辨識度但不過度細分

**常見 theme 參考清單**（非窮舉，可新增）：
- 能源/電力：energy-transition, grid-modernization, ai-datacenter-power, nuclear-renaissance, lng-expansion
- 電動車：ev-adoption, ev-battery-supply, charging-infrastructure
- 半導體：semiconductor-cycle, advanced-packaging, ai-chip-demand, mature-node-capacity
- 總經：interest-rate-cycle, us-china-decoupling, reshoring, commodity-supercycle, fiscal-expansion
- 科技：ai-infrastructure, cloud-capex-cycle, cybersecurity-spending, saas-consolidation
- 太空/國防：space-economy, defense-modernization
- 黃金/貴金屬：gold-as-reserve, central-bank-gold

此清單僅為參考起點。隨著報告累積，vault 中的 Theme 卡片就是活的詞彙表，每次處理報告時都要先查。

#### 4c. 決定檔名

**索引筆記檔名格式**：`YYYY-MM-DD-來源簡稱-報告標題中文 YYYY-M-D.md`

- 前面的日期（YYYY-MM-DD）= 加入 Obsidian 的日期，也就是今天的日期，月和日補零（如 04、07）
- 後面的日期（YYYY-M-D）= 報告本身的發佈日或完成日，月和日不補零（如 4、7）
- 如果報告中找不到發佈日或完成日，前後兩個日期都寫今天的日期
- 來源用簡稱（GS、MS、JPM、元大銀行、凱基等）
- 報告標題中文：將原始報告標題完整翻譯成繁體中文，保留股票代碼與括號
- 範例（假設今天是 2026-04-22）：
  - 報告發佈日 2026-04-15：`2026-04-22-GS-First Solar(FSLR)第三季財報更新 2026-4-15.md`
  - 報告發佈日 2025-11-01：`2026-04-22-元大銀行-2025年11月投資月報 2025-11-1.md`
  - 報告無發佈日：`2026-04-22-GS-銅礦產業分析 2026-4-22.md`
- 同一天同一來源有多份報告時，因標題不同自然不會重名，不需數字後綴

**原始檔案重新命名格式**（非 .md 格式）：`來源簡稱-主題摘要英文-YYYYMM.副檔名`
- 範例：`GS-Copper-Mining-202604.pdf`、`MS-TSMC-202604.pdf`

**.md 格式的報告**不重新命名，直接以原檔名或乾淨檔名放入 vault。

#### 4d. 重新命名原始檔案

用 Bash 在報告收件夾內重新命名：
```bash
mv "$INBOX_PATH/原檔名.pdf" "$INBOX_PATH/新檔名.pdf"
```

#### 4d-post. Embed 檔名一致性驗證（極重要，不可跳過）

**這是整個流程中最容易出錯的環節。** 重新命名後，你必須立刻記錄「這份檔案現在叫什麼」，並且在 Step 4e 建立索引筆記時，`![[]]` embed 必須使用**重新命名後的檔名**（即 Step 4d `mv` 指令的目標檔名）。

**強制驗證規則**：
1. 若 Step 4d 執行了 `mv old.pdf new.pdf`，則 embed 必須寫 `![[new.pdf]]`，嚴格禁止寫 `![[old.pdf]]`
2. 若 Step 4d 因為某些原因沒有重新命名（例如檔名已經符合格式、或 mv 失敗），則 embed 必須使用**目前實際存在的檔名**
3. 在寫出 `![[xxx]]` 之前，心中複述一次：「這個檔案在報告收件夾裡現在叫什麼？」——答案就是 embed 要用的檔名
4. 特別注意：有些原始檔名很長且包含特殊字元（空格、括號、底線等），重新命名後會變短。embed 必須用短的新名字，不能用長的舊名字

**錯誤範例**（嚴格禁止）：
```
# 原檔名：Carbonomics_ Deep dive into hydrogen fuel cell for AI data centers.pdf
# 重新命名為：GS-Carbonomics-FuelCell-AI-DataCenter-202510.pdf
# 錯誤的 embed（用了舊檔名）：
![[Carbonomics_ Deep dive into hydrogen fuel cell for AI data centers.pdf]]
# 正確的 embed（用了新檔名）：
![[GS-Carbonomics-FuelCell-AI-DataCenter-202510.pdf]]
```

#### 4e. 建立索引筆記

**索引筆記路由規則**：依據報告來源，將索引筆記寫入不同資料夾：

| 條件 | 目標資料夾 |
|------|-----------|
| 來源為「定錨産業筆記」（source 含「定錨」） | `2 Sources/定錨/` |
| Claude 自行產出的研究報告 | `2 Sources/Research/` |
| 其他所有外部機構報告（GS、MS、WGC、IEA、元大等） | `2 Sources/Reports/` |

注意：台股法說會逐字稿（TW-Earnings）、美股法說會逐字稿（US-Earnings）、Podcast 逐字稿由各自自動化管線處理，不經過 report-intake，分別寫入 `2 Sources/TW-Earnings/`、`2 Sources/US-Earnings/`、`2 Sources/Podcasts/`。

優先用 Obsidian MCP 的 `create_vault_file` 在上述對應資料夾建立索引筆記。若本回合沒有 MCP、但本機 vault 路徑可寫，直接用本機路徑建立檔案。

**重要**：使用 `create_vault_file` 而非 `patch_vault_file`，因為 patch 對中文標題有已知 bug。

**所有報告類型一律使用相同的完整模板結構**（見下方「索引筆記模板」章節）。不論 report_type 是 individual-stock、newsletter、earnings-presentation、index-factsheet 還是其他任何類型，都必須包含完整的：frontmatter、來源資訊引用區塊、`![[embed]]`、重點摘要、個股數據（若有）、原文重點段落、觀點衝突標記、我的筆記、相關連結 Dataview 區塊。嚴格禁止因為「這只是電子報」或「這只是 factsheet」就省略任何區塊。

索引筆記的完整格式見下方「索引筆記模板」章節。

#### 4f. 處理 .md 格式的報告

.md 格式的報告特殊處理：
- **不放進索引筆記的目標資料夾**，改放進 **`Attachments/`** 資料夾
- 用 Obsidian MCP 的 `create_vault_file` 將 .md 原文寫入 vault 的 `Attachments/原始檔名.md`
- 寫入前必須清理原文中的 HTML 殘留標籤（`<p>`、`<strong>`、`<span>` 等），轉換為乾淨的 Markdown 格式
- 原文中以 `background-color:#ffffcc` 標記的重點段落，轉換為 Obsidian 的 `==highlight==` 語法
- 原文中的圖片標籤（`<img>`）轉換為文字說明：`（原文附圖：檔名.png）`
- 索引筆記的「原始檔案」欄位用 wikilink 連結：`> 原始檔案為 .md 格式，完整原文見：[[原始檔名]]`
- 這樣使用者點進 wikilink 就能看到完整原文內容

#### 4g. 顯示處理進度

多份報告時，每開始處理一份就顯示進度：
```
正在處理第 3/8 份：GS-Copper-Report.pdf...
```

### Step 5：更新 MOC

所有報告處理完後，檢查以下 MOC 是否需要更新：

1. **`3 MOC/研究報告-產業索引.md`**：若新報告的 sector 不在現有 Dataview 區塊的分類中，用 Obsidian MCP 新增對應的 Dataview 區塊。現有區塊格式範例：
```
## 新分類名 English Name
\`\`\`dataview
TABLE source AS "來源", tickers AS "標的", date AS "日期", rating AS "評等"
FROM "2 Sources"
WHERE contains(sectors, "new-sector")
SORT date DESC
\`\`\`
```

2. **`3 MOC/研究報告-來源索引.md`**：若新報告的來源機構不在現有分類中，新增對應的 Dataview 區塊。

3. **`3 MOC/Tickers/XXX-研究總整理.md`**：若該 ticker 的總覽頁已存在，Dataview 會自動抓取新筆記，不需手動更新。若不存在且報告中有重要個股（出現在 2 份以上報告的 tickers 中），自動建立新的 Ticker 總覽頁。模板如下：

```markdown
---
type: ticker-overview
ticker: TSMC
company_name: 台灣積體電路製造股份有限公司
exchange: TWSE
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
---

# TSMC 研究總整理

## 公司簡介

（用 2-3 句繁體中文描述公司主要業務與市場地位，根據報告內容撰寫）

## 評等與目標價歷史（自動）

\`\`\`dataview
TABLE source AS "來源", date AS "日期", rating AS "評等", target_price AS "目標價", key_thesis AS "論點"
FROM "2 Sources"
WHERE contains(tickers, "TSMC")
SORT date DESC
\`\`\`

## 相關主題（自動）

\`\`\`dataview
LIST themes
FROM "2 Sources"
WHERE contains(tickers, "TSMC") AND themes
SORT date DESC
\`\`\`

## 供應鏈定位（自動）

\`\`\`dataview
TABLE supply_chain.upstream AS "上游", supply_chain.midstream AS "中游", supply_chain.downstream AS "下游"
FROM "2 Sources"
WHERE contains(tickers, "TSMC") AND (supply_chain.upstream OR supply_chain.midstream OR supply_chain.downstream)
SORT date DESC
\`\`\`

## 被其他報告提及（自動）

\`\`\`dataview
TABLE source AS "來源", date AS "日期", tickers AS "主角標的", key_thesis AS "論點"
FROM "2 Sources"
WHERE contains(related_tickers, "TSMC") AND !contains(tickers, "TSMC")
SORT date DESC
\`\`\`

## 即將到來的催化劑（自動）

\`\`\`dataview
TABLE catalysts.date AS "日期", catalysts.event AS "事件"
FROM "2 Sources"
WHERE contains(tickers, "TSMC") AND catalysts
FLATTEN catalysts
SORT catalysts.date ASC
\`\`\`

## 觀點衝突歷史

\`\`\`dataview
TABLE source AS "來源", date AS "日期", rating AS "評等", target_price AS "目標價"
FROM "2 Sources"
WHERE contains(tickers, "TSMC") AND conflict_flag = true
SORT date DESC
\`\`\`

## 我的觀察

（留空，供使用者手動記錄對此標的的整體判斷與追蹤要點）
```

建立時將模板中所有 `TSMC` 替換為實際的 ticker 代碼，`company_name` 和 `exchange` 根據報告內容填寫。

4. **`3 MOC/產業供應鏈索引.md`**：若此 MOC 尚不存在，在首次有報告包含 `supply_chain` 欄位時自動建立。此 MOC 用 Dataview 自動彙整所有報告中的上中下游關係。格式如下：

```markdown
---
type: moc
created: YYYY-MM-DD
---

# 產業供應鏈索引

此頁面自動彙整研究報告中標記的產業鏈上中下游關係，幫助辨識跨產業的投資機會。

## 半導體供應鏈

\`\`\`dataview
TABLE supply_chain.upstream AS "上游", supply_chain.midstream AS "中游", supply_chain.downstream AS "下游", tickers AS "主角標的"
FROM "2 Sources"
WHERE (supply_chain.upstream OR supply_chain.midstream OR supply_chain.downstream) AND contains(sectors, "semiconductor")
SORT date DESC
\`\`\`

## 能源供應鏈

\`\`\`dataview
TABLE supply_chain.upstream AS "上游", supply_chain.midstream AS "中游", supply_chain.downstream AS "下游", tickers AS "主角標的"
FROM "2 Sources"
WHERE (supply_chain.upstream OR supply_chain.midstream OR supply_chain.downstream) AND contains(sectors, "energy")
SORT date DESC
\`\`\`

## 原物料供應鏈

\`\`\`dataview
TABLE supply_chain.upstream AS "上游", supply_chain.midstream AS "中游", supply_chain.downstream AS "下游", tickers AS "主角標的"
FROM "2 Sources"
WHERE (supply_chain.upstream OR supply_chain.midstream OR supply_chain.downstream) AND contains(sectors, "materials")
SORT date DESC
\`\`\`

## 所有供應鏈關係（全覽）

\`\`\`dataview
TABLE sectors AS "產業", supply_chain.upstream AS "上游", supply_chain.midstream AS "中游", supply_chain.downstream AS "下游"
FROM "2 Sources"
WHERE supply_chain.upstream OR supply_chain.midstream OR supply_chain.downstream
SORT sectors ASC, date DESC
\`\`\`
```

若已存在，檢查是否需要新增該 sector 的 Dataview 區塊（邏輯同「研究報告-產業索引.md」的新增方式）。

5. **`3 MOC/研究報告-地區索引.md`**：若此 MOC 尚不存在，在首次有報告包含 `regions` 欄位時自動建立。格式如下：

```markdown
---
type: moc
created: YYYY-MM-DD
---

# 研究報告 — 地區索引

依報告涉及的地理區域分類，快速找到特定市場的研究。

## 美國 US

\`\`\`dataview
TABLE source AS "來源", tickers AS "標的", date AS "日期", key_thesis AS "論點"
FROM "2 Sources"
WHERE contains(regions, "us")
SORT date DESC
\`\`\`

## 台灣 Taiwan

\`\`\`dataview
TABLE source AS "來源", tickers AS "標的", date AS "日期", key_thesis AS "論點"
FROM "2 Sources"
WHERE contains(regions, "taiwan")
SORT date DESC
\`\`\`

## 拉丁美洲 Latin America

\`\`\`dataview
TABLE source AS "來源", tickers AS "標的", date AS "日期", key_thesis AS "論點"
FROM "2 Sources"
WHERE contains(regions, "latam") OR contains(regions, "brazil")
SORT date DESC
\`\`\`

## 中國 China

\`\`\`dataview
TABLE source AS "來源", tickers AS "標的", date AS "日期", key_thesis AS "論點"
FROM "2 Sources"
WHERE contains(regions, "china")
SORT date DESC
\`\`\`

## 歐洲 Europe

\`\`\`dataview
TABLE source AS "來源", tickers AS "標的", date AS "日期", key_thesis AS "論點"
FROM "2 Sources"
WHERE contains(regions, "europe")
SORT date DESC
\`\`\`

## 全球 Global

\`\`\`dataview
TABLE source AS "來源", tickers AS "標的", date AS "日期", key_thesis AS "論點"
FROM "2 Sources"
WHERE contains(regions, "global")
SORT date DESC
\`\`\`
```

若已存在，檢查是否需要新增新區域的 Dataview 區塊（邏輯同產業索引的新增方式）。

6. **`3 MOC/催化劑日曆.md`**：若此 MOC 尚不存在，在首次有報告包含 `catalysts` 欄位時自動建立。此 MOC 用 Dataview 自動彙整所有報告中提及的未來事件節點，讓使用者一頁看到所有即將到來的催化劑。格式如下：

```markdown
---
type: moc
created: YYYY-MM-DD
---

# 催化劑日曆

此頁面自動彙整所有研究報告中提及的未來關鍵事件與催化劑，按日期排序。幫助追蹤即將到來的財報、政策決議、產業事件等。

## 所有催化劑（按日期排序）

\`\`\`dataview
TABLE catalysts.date AS "日期", catalysts.event AS "事件", tickers AS "相關標的", source AS "來源"
FROM "2 Sources"
WHERE catalysts
FLATTEN catalysts
SORT catalysts.date ASC
\`\`\`

## 依標的篩選催化劑

（使用者可自行新增特定標的的 Dataview 區塊，範例：）

### TSMC

\`\`\`dataview
TABLE catalysts.date AS "日期", catalysts.event AS "事件", source AS "來源"
FROM "2 Sources"
WHERE contains(tickers, "TSMC") AND catalysts
FLATTEN catalysts
SORT catalysts.date ASC
\`\`\`
```

若已存在，Dataview 會自動抓取新報告的催化劑，不需手動更新。

7. **`3 MOC/研究儀表板.md`**：若此 MOC 尚不存在，在首次執行整理報告時自動建立。此頁面是整個研究資料庫的首頁，一頁看到全局狀態。格式如下：

```markdown
---
type: moc
created: YYYY-MM-DD
---

# 研究儀表板

## 最近 14 天新增的報告

\`\`\`dataview
TABLE source AS "來源", tickers AS "標的", report_type AS "類型", key_thesis AS "論點"
FROM "2 Sources"
WHERE date >= date(today) - dur(14 days)
SORT date DESC
\`\`\`

## 活躍趨勢訊號

\`\`\`dataview
TABLE theme AS "主題", trend_detected_date AS "偵測日期"
FROM "1 Cards"
WHERE type = "theme-card" AND trend_signal = true
SORT trend_detected_date DESC
\`\`\`

## 未解決的觀點衝突

\`\`\`dataview
TABLE source AS "來源", tickers AS "標的", date AS "日期", rating AS "評等"
FROM "2 Sources"
WHERE conflict_flag = true
SORT date DESC
\`\`\`

## 即將到來的催化劑（未來 60 天）

\`\`\`dataview
TABLE catalysts.date AS "日期", catalysts.event AS "事件", tickers AS "標的", source AS "來源"
FROM "2 Sources"
WHERE catalysts
FLATTEN catalysts
WHERE catalysts.date >= date(today) AND catalysts.date <= date(today) + dur(60 days)
SORT catalysts.date ASC
\`\`\`

## 各產業報告數量

\`\`\`dataview
TABLE length(rows) AS "報告數"
FROM "2 Sources"
FLATTEN sectors AS sector
GROUP BY sector
SORT length(rows) DESC
\`\`\`

## 各地區報告數量

\`\`\`dataview
TABLE length(rows) AS "報告數"
FROM "2 Sources"
FLATTEN regions AS region
GROUP BY region
SORT length(rows) DESC
\`\`\`

## 快速導航

- [[研究報告-產業索引]]
- [[研究報告-來源索引]]
- [[研究報告-地區索引]]
- [[產業供應鏈索引]]
- [[催化劑日曆]]
```

若已存在，Dataview 會自動更新內容，不需手動修改。

### Step 5b：建立或更新投資主題卡片（Theme Notes）

對這批報告中出現的每個 `themes` 標籤，在 `1 Cards/` 資料夾檢查是否已有對應的主題卡片。

**主題卡片檔名格式**：`Theme-主題名稱.md`（如 `Theme-ai-datacenter-power.md`、`Theme-ev-adoption.md`）

#### 若卡片不存在，用 `create_vault_file` 建立新卡片：

```markdown
---
type: theme-card
theme: ai-datacenter-power
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
status: active
---

# 投資主題：AI 資料中心電力需求

## 主題定義

（用 2-3 句繁體中文描述這個投資主題的核心邏輯，根據觸發此主題建立的報告內容撰寫）

## 相關報告（自動）

\`\`\`dataview
TABLE source AS "來源", date AS "日期", key_thesis AS "核心論點"
FROM "2 Sources"
WHERE contains(themes, "ai-datacenter-power")
SORT date DESC
\`\`\`

## 相關標的（自動）

\`\`\`dataview
LIST tickers
FROM "2 Sources"
WHERE contains(themes, "ai-datacenter-power") AND tickers
SORT date DESC
\`\`\`

## 供應鏈節點（自動）

\`\`\`dataview
TABLE supply_chain.upstream AS "上游", supply_chain.midstream AS "中游", supply_chain.downstream AS "下游"
FROM "2 Sources"
WHERE contains(themes, "ai-datacenter-power") AND (supply_chain.upstream OR supply_chain.midstream OR supply_chain.downstream)
SORT date DESC
\`\`\`

## 趨勢演變紀錄

（留空，每次有新報告更新此主題時，Claude 在此追加一條時間軸記錄）

## 我的觀察

（留空，供使用者手動記錄）
```

#### 若卡片已存在，用 `get_vault_file` 讀取後，在「趨勢演變紀錄」區塊尾端追加一條記錄：

```
- YYYY-MM-DD：[[新索引筆記名稱]] — 一句話摘要此報告對此主題的新資訊或觀點變化
```

同時更新 frontmatter 的 `last_updated` 日期。使用 `create_vault_file` 覆寫整份檔案（因 patch 有中文 bug）。

**注意**：Dataview 區塊中的 theme 名稱必須與報告 frontmatter 中的 themes 值完全一致（英文小寫、連字號），否則查詢會失效。

### Step 5c：趨勢偵測（Trend Detection）

所有報告處理完後，統計這批新報告 + vault 既有報告中，各 theme 出現的報告數量。

偵測方法：
1. 對這批報告中出現的每個 theme，用 Obsidian MCP 的 `search_vault` 搜尋 `themes` 欄位包含該 theme 的所有報告
2. 計算該 theme 在過去 90 天內出現在幾份不同報告中
3. 若同一 theme 在 90 天內出現在 3 份以上（含）報告中，標記為「新興趨勢訊號」

偵測到趨勢訊號時：
1. 在對應的 Theme 卡片（`1 Cards/Theme-xxx.md`）的 frontmatter 加上 `trend_signal: true` 和 `trend_detected_date: YYYY-MM-DD`
2. 在「趨勢演變紀錄」區塊最上方加上醒目提示：
```
> [!important] 新興趨勢訊號
> 此主題在過去 90 天內已出現在 N 份報告中（截至 YYYY-MM-DD），密度超過門檻，建議使用者深入研究。
```
3. 在 Step 7 完成回報中列出所有趨勢訊號

### Step 6：歸檔原始檔案

所有索引筆記建完後，將非 .md 原始檔案歸檔到 vault `Attachments/`。優先由 Codex 直接移動檔案；若沙盒權限不足，向使用者要求授權。只有在無法取得授權或使用者明確要手動處理時，才提示使用者執行桌面搬移腳本。

```
索引筆記已全部建立完成。
原始報告檔案已歸檔到 Obsidian vault 的 Attachments 資料夾。
（.md 格式的報告已直接寫入 vault，不需要搬移。）
```

### Step 7：完成回報

輸出完成摘要，格式如下：

```
## 處理完成摘要

| 編號 | 索引筆記 | 原始檔案（重新命名後）| 報告類型 | 核心主題 |
|------|----------|----------------------|----------|----------|
| 1 | [[2026-04-22-GS-銅礦產業-總經波動下的好壞與偏好 2026-4-13]] | GS-Copper-Mining-202604.pdf | 產業報告 | 銅礦產業總經影響 |
| 2 | [[2026-04-22-MS-台積電評等調升至加碼 2026-4-13]] | MS-TSMC-202604.pdf | 個股研報 | 台積電評等調升 |

### 處理失敗
- encrypted-report.pdf：PDF 加密，無法讀取（待手動處理）

### 觀點衝突
- [[2026-04-13-GS]] vs [[2026-04-13-MS]]：對銅價展望看法分歧（GS 看多 vs MS 中性）

### MOC 更新
- 研究報告-產業索引.md：新增「工業」分類
- 研究報告-來源索引.md：新增「Barclays」區塊
- 研究報告-地區索引.md：新增「中東」區塊
- 催化劑日曆.md：Dataview 自動更新
- 研究儀表板.md：Dataview 自動更新

### 新興趨勢訊號
- Theme: ai-datacenter-power — 過去 90 天內出現在 5 份報告中，已標記於 [[Theme-ai-datacenter-power]]
- Theme: energy-transition — 過去 90 天內出現在 3 份報告中，已標記於 [[Theme-energy-transition]]
（若無趨勢訊號則顯示「本批無新興趨勢訊號」）

### 投資主題卡片異動
- 新建：[[Theme-ev-adoption]]（首次出現）
- 更新：[[Theme-ai-datacenter-power]]（趨勢演變紀錄 +1）
（若無異動則顯示「無主題卡片異動」）

### Ticker 總覽頁異動
- 新建：[[TSMC-研究總整理]]（已出現在 3 份報告中，自動建立）
- 既有：[[CF-研究總整理]]（Dataview 自動更新）
（若無異動則顯示「無 Ticker 總覽頁異動」）

### 催化劑摘要
- 2026-05-12：USDA 5月 WASDE 報告（相關標的：CF, ADM）
- 2026-Q2：台積電法說會（相關標的：TSMC）
（若本批報告無催化劑則顯示「本批報告未提及未來催化劑」）
```

---

## 索引筆記模板

### Frontmatter

```yaml
---
date: YYYY-MM-DD
tags: [依報告內容決定，用英文小寫]
source: 來源機構全名
tickers: [相關股票代碼]
sectors: [相關產業，英文小寫，見 4b 的 sectors 參考清單]
report_type: individual-stock / sector-report / thematic-report / macro-report / market-commentary / strategy-morning-note / newsletter / earnings-presentation / index-factsheet / academic-paper / financial-statement
rating: 評等（僅個股報告，無則留空）
target_price: 目標價（僅個股報告，無則留空）
key_thesis:
  - 核心論點 1（繁體中文，一句話概括一個論點）
  - 核心論點 2
  - 核心論點 3（通常 2-4 個論點）
key_data:
  - 關鍵數據 1（如 目標價 $150）
  - 關鍵數據 2（如 2026E EPS $5.20）
  - 關鍵數據 3（所有具體數字都要列入）
themes: # 必須先查 vault 既有 Theme 卡片，確保命名一致，見 4b-extra 步驟
  - 投資主題 1（英文小寫，如 ai-datacenter-power、ev-adoption、reshoring、commodity-supercycle）
  - 投資主題 2（概念性的跨產業主題，不是產業名稱）
supply_chain: # 若不涉及供應鏈，整個 supply_chain 欄位不要寫，完全省略此區塊。格式必須是物件套陣列，見 4b 的正確/錯誤範例
  upstream: [上游公司或環節，如 polysilicon-producers、FSLR]
  midstream: [中游公司或環節，如 module-assembly、ENPH]
  downstream: [下游公司或環節，如 utility-scale-solar、NEE]
related_tickers: [報告中提及但非主角的相關股票代碼，用於跨報告連結]
regions: [報告涉及的地理區域，英文小寫，如 us、taiwan、brazil、global，見 4b 的 regions 參考清單]
catalysts: # 若報告未提及未來事件，整個 catalysts 欄位完全省略。見 4b 的格式範例
  - date: YYYY-MM-DD
    event: 催化劑事件描述（繁體中文）
conflict_flag: false
status: draft
---
```

### 正文結構

**所有報告類型（individual-stock、sector-report、newsletter、earnings-presentation、index-factsheet 等）一律使用此完整結構，不可省略任何區塊。**

```markdown
# 來源簡稱 主題摘要標題

> 原始報告：來源機構全名 - 報告原標題
> 日期：YYYY-MM-DD

![[重新命名後的檔名.pdf]]

---

## 重點摘要

（依報告類型使用對應的摘要結構，見下方「依報告類型的摘要結構」章節）

---

## 個股數據

（若報告中有個股評等、目標價、財務數據等，用表格整理）

| 股票 | 評等 | 目標價 | 關鍵指標 |
|------|------|--------|----------|
| XXX | Buy | $150 | ... |

（無相關數據則省略此區塊）

---

## 原文重點段落

（直接引用原文中最重要的 2-5 個段落，保留原文語言。每段後附繁體中文翻譯。）

### 段落 1
> [原文段落，保留原始語言]

翻譯：[繁體中文翻譯]

### 段落 2
> [原文段落，保留原始語言]

翻譯：[繁體中文翻譯]

（若原文本身為繁體中文，則只引用不需翻譯）

---

## 觀點衝突標記

- 衝突對象：（若與 vault 中其他報告有明顯觀點衝突，記錄在此）
- 本報告觀點：
- 對方觀點：
- 分歧關鍵：

（無衝突則保留空白區塊）

---

## 我的筆記

（留空，供使用者日後手動記錄）

---

## 相關連結（自動）

### 同標的報告
\`\`\`dataview
TABLE source AS "來源", date AS "日期", rating AS "評等", key_thesis AS "論點"
FROM "2 Sources"
WHERE file.name != this.file.name AND any(tickers, (t) => contains(this.tickers, t))
SORT date DESC
LIMIT 10
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

### 同地區報告
\`\`\`dataview
TABLE source AS "來源", date AS "日期", tickers AS "標的", key_thesis AS "論點"
FROM "2 Sources"
WHERE file.name != this.file.name AND any(regions, (r) => contains(this.regions, r))
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

**注意：若為 .md 格式報告**，將 `![[重新命名後的檔名.pdf]]` 替換為：
```
> 原始檔案為 .md 格式，完整原文見：[[原始檔名]]
```
（原文已清理 HTML 後寫入 `Attachments/原始檔名.md`，wikilink 可直接點開閱讀）

---

## 依報告類型的摘要結構

### 摘要深度要求（最高優先級）

使用者一般不會回去讀原文，只會讀索引筆記中的摘要。因此摘要必須做到**零資訊遺漏**：

- 篇幅不設上限，品質優先於精簡
- 可以直接引用原文段落（特別是數據密集、精確措辭、分析師關鍵判斷的段落）
- 英文報告的關鍵段落保留英文並附繁體中文翻譯，不要全部翻掉丟失原意
- 具體數字一個都不能漏：百分比、金額、日期、預測值、目標價全部要寫進摘要
- 每個小節用 `###` 三級標題區隔

#### 逐章自我檢查（每寫完一個 ### 區塊就做一次）

問自己以下五個問題，任何一個答案是「否」就要回去補：

1. 原文這個章節中的所有具體數字（金額、百分比、日期、預測值），
   是否全部出現在我的摘要中？

2. 原文這個章節中提到的所有公司名/人名/產品名，
   是否全部出現在我的摘要中？

3. 原文這個章節中的因果邏輯鏈（因為 A 所以 B 導致 C），
   是否在摘要中完整呈現，而不是只寫了結論 C？

4. 如果這個章節有 highlight 段落，
   我是否用 ==highlight== 完整保留了內容？

5. 如果使用者只讀我寫的這段摘要，
   他能不能完整理解原文這個章節在說什麼？
   （最關鍵的問題——如果不能，代表漏了東西）

#### 圖表處理（通用規則）

- 原文的 `<img>` 標籤：轉為（原文附圖：ALT 文字或檔名）
- 原文的表格（HTML table 或 Markdown table）：
  - 若表格行數 <= 10 行：用 Markdown 表格完整保留
  - 若表格行數 > 10 行：提取最關鍵的欄位和行，用精簡表格呈現，
    並註明（完整表格見原始報告）
- 原文的 Exhibit/圖表標題：必須在摘要中以文字提及
  （如 Exhibit 5 顯示核能容量因數高達 93%，為所有發電類型最高）
- 絕對不能只寫「詳見 Exhibit 5」而不寫 Exhibit 5 的內容

---

### 摘要結構的決定邏輯（最高優先級，覆蓋所有報告類型模板）

摘要的章節標題怎麼定？按以下優先順序：

1. 首選：跟著原文結構走
   - 原文有幾個章節，摘要就有幾個 `###` 標題
   - 標題名稱翻譯自原文章節標題（英文報告翻成繁體中文）
   - 原文沒有標題但有明確的編號段落，每個主編號（1. 2. 3.）對應一個標題
   - 這樣做的好處：使用者未來回頭找資訊時，摘要結構和原文一致，定位最快

2. 次選：原文結構太零散時，用報告類型模板整理
   - 只有當原文完全沒有結構（例如純段落、沒有標題也沒有編號）時，
     才使用下方各報告類型的模板框架來組織摘要
   - 使用模板時，跳過原文中沒有對應內容的標題，不要硬湊

3. 禁止：模板標題數 < 原文章節數
   - 如果原文有 12 個獨立章節，摘要不可以只有 7 個標題
   - 模板的標題數量是下限，不是上限
   - 永遠寧可標題多一點（每個都短），也不要標題少（每個都塞太多東西）

---

### 個股研報（report_type: individual-stock）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。每個項目用 `###` 標題：

### 1. 評級與目標價變動
新評級 vs 舊評級，新目標價 vs 舊目標價，調升/調降的核心原因。

### 2. 核心投資論點
bull case 和 bear case 分別是什麼。

### 3. 最新財報或營運數據重點
營收、EPS、毛利率等關鍵數字。必須有「預期 vs 實際」的對比，標明優於或低於市場預期。

### 4. 估值方法與關鍵假設
分析師用什麼方法估值（DCF、本益比、EV/EBITDA 等），關鍵假設是什麼。

### 5. 產業趨勢或競爭格局對個股的影響
所處產業的大環境如何影響這家公司。

### 6. 風險因素
分析師列出的主要風險。

### 7. 分析師的關鍵判斷語句
保留原文引用。英文報告保留英文並附翻譯。

---

### 產業報告（report_type: sector-report）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。

### 1. 產業現況與趨勢總覽
這個產業目前怎麼了，大方向往哪走。

### 2. 供需分析
供給端有什麼變化，需求端的驅動力是什麼。

### 3. 產業鏈關鍵環節與瓶頸
哪些環節最重要，哪裡卡住了。

### 4. 關鍵玩家與競爭格局
主要公司有哪些，彼此關係如何。

### 5. 價格或獲利展望
產品價格或企業獲利的預測。

### 6. 政策或法規影響
政府政策、法規、關稅等如何影響產業。

### 7. 投資機會與風險
哪些標的值得關注，風險在哪。

---

### 主題報告（report_type: thematic-report）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。

### 1. 主題定義與背景
這個主題是什麼，為什麼現在重要。

### 2. 驅動因素與催化劑
推動此趨勢的核心力量：技術突破、政策變動、需求轉移等。

### 3. 市場規模與成長預測
TAM/SAM 數字、CAGR、滲透率預估等量化數據。

### 4. 產業鏈受惠環節
哪些環節最受惠，哪些可能被淘汰。上中下游各自的機會與風險。

### 5. 關鍵公司與標的
分析師點名的受惠公司，各自的定位與競爭優勢。

### 6. 時間軸與發展階段
目前在什麼階段（萌芽/成長/成熟），預計何時進入下一階段。

### 7. 風險與不確定性
技術風險、政策風險、執行風險、估值風險。

---

### 市場評論（report_type: market-commentary）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。

### 1. 事件或情境描述
發生了什麼事，或者分析師在討論什麼情境假設。

### 2. 對市場的直接衝擊
短期內對股市、債市、匯率、商品的影響判斷。

### 3. 歷史類比或情境對比
分析師引用的歷史先例或可類比的過往事件。

### 4. 受影響的產業與標的
哪些產業/公司最受影響（正面或負面）。

### 5. 投資策略建議
分析師建議的應對方式：加碼/減碼/避險/觀望。

### 6. 後續觀察重點
接下來要追蹤的指標或事件節點。

---

### 總經報告（report_type: macro-report）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。

### 1. 核心經濟數據與趨勢
GDP、就業、通膨、PMI 等最新數據。

### 2. 央行政策動向
利率決策、QE/QT、前瞻指引。

### 3. 地緣政治或貿易影響
戰爭、關稅、制裁等如何影響經濟。

### 4. 各資產類別影響
對股票、債券、外匯、商品的影響。

### 5. 情境分析
base case / bull case / bear case 分別是什麼。

### 6. 時間軸與關鍵觀察點
未來幾週/幾月要注意哪些事件或數據發布。

---

### 策略報告/晨報（report_type: strategy-morning-note）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。

### 1. 隔夜市場回顧
昨晚各市場發生了什麼。

### 2. 各市場/資產表現數據
指數漲跌、匯率、商品價格等具體數字。

### 3. 今日關注事件與數據
今天有什麼重要事件或經濟數據要公布。

### 4. 策略師核心觀點
策略師怎麼看當前市場。

### 5. 部位建議或調整
建議的投資部位變動。

---

### 電子報（report_type: newsletter）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。

### 1. 本期主題與核心論述
這期電子報在談什麼，作者的核心觀點是什麼。

### 2. 關鍵事實與數據
文中引用的重要數字、統計、事件。

### 3. 作者的分析與推論
作者如何從事實推導出結論，邏輯鏈是什麼。

### 4. 涉及的公司或產業
文中討論到哪些公司、產業、技術。

### 5. 投資啟示或行動建議
作者明示或暗示的投資機會、風險提醒。

---

### 法說會簡報（report_type: earnings-presentation）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。

### 1. 財務表現總覽
營收、毛利、淨利、EPS 等關鍵數字，與去年同期及市場預期的對比。

### 2. 各事業部或產品線表現
分部門的營收貢獻、成長率、毛利率。

### 3. 管理層展望與指引
下一季或全年的營收/獲利指引，管理層對未來的看法。

### 4. 資本支出與策略方向
Capex 計畫、併購、新產品、市場擴張等策略。

### 5. 關鍵營運指標
訂單量、產能利用率、客戶數、backlog 等非財務指標。

---

### 指數說明書（report_type: index-factsheet）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。

### 1. 指數定義與編制方法
這個指數追蹤什麼、怎麼選股、怎麼加權。

### 2. 成分股與權重分布
前十大成分股、產業分布、地區分布。

### 3. 歷史績效與風險指標
報酬率、波動度、Sharpe ratio、最大回撤等。

### 4. 與基準指數的比較
跟大盤或相關指數比起來表現如何。

### 5. 再平衡規則與時程
多久調整一次成分股，調整的規則是什麼。

---

### 學術論文/研究院報告（report_type: academic-paper）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。

### 1. 研究問題與目的
這篇研究要回答什麼問題。

### 2. 研究方法與資料
用什麼方法、什麼資料來回答問題。

### 3. 核心發現與結論
研究的主要結果是什麼。

### 4. 政策意涵或產業影響
這些發現對政策制定或產業發展有什麼意義。

### 5. 限制與未來研究方向
研究的限制是什麼，還有哪些問題待解答。

---

### 公司財務報表（report_type: financial-statement）

以下為 fallback 框架——僅當原文完全沒有結構時才使用，否則跟著原文結構走。

### 1. 財務摘要
營收、毛利、營業利益、淨利、EPS 等關鍵數字。

### 2. 各業務部門表現
分部門的營收、獲利、成長率。

### 3. 資產負債表重點
現金、負債、股東權益、關鍵比率。

### 4. 現金流量表重點
營運現金流、投資現金流、自由現金流。

### 5. 管理層說明或附註重點
財報附註中的重要揭露事項。

---

## 觀點衝突偵測

處理多份報告時，Claude 應主動比對各報告之間是否有觀點衝突。偵測邏輯：

- 同一 ticker 的不同評等（一個 Buy 一個 Sell）
- 同一商品/指數的不同方向預測
- 同一總經議題的不同判斷

也要與 vault 中已存在的報告比對（透過 Obsidian MCP 搜尋相同 ticker 或 sector 的既有筆記）。

偵測到衝突時：
1. 在兩份索引筆記的「觀點衝突標記」區塊都記錄
2. 將兩份筆記的 `conflict_flag` 設為 `true`
3. 在 Step 7 完成回報中列出衝突對

---

## 搬移腳本 fallback 說明

搬移腳本位於使用者桌面：`~/Desktop/搬移報告到Obsidian.command`

此腳本的功能：
- 遞迴掃描 `~/Desktop/報告收件夾/` 內所有子資料夾
- 將所有非 .md 格式的報告檔案搬移到 vault 的 `Attachments/` 資料夾
- .md 檔案不搬移（因為已透過 Obsidian MCP 直接寫入 vault）
- 搬移後清空子資料夾（若子資料夾內已無檔案則刪除空資料夾）
- 支援的格式：pdf, doc, docx, pptx, ppt, xlsx, xls, png, jpg, jpeg, heic

Codex 優先自行歸檔原始檔案。只有在本機權限不足、且無法透過授權完成歸檔時，才在 Step 6 提示使用者雙擊腳本。

若腳本不存在或使用者回報腳本有問題，Claude 應在 Desktop 重新建立腳本（見下方完整腳本內容）。

### 搬移腳本完整內容

```bash
#!/bin/bash
# 把報告收件夾裡的所有報告檔案（含子資料夾）搬到 Obsidian Vault 的 Attachments 資料夾
# .md 檔案不搬移（已透過 Obsidian MCP 直接寫入 vault）
SRC="$HOME/Desktop/報告收件夾"
DEST="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/卡片筆記盒模板/Attachments"

if [ ! -d "$SRC" ]; then
  echo "錯誤：找不到報告收件夾 ($SRC)"
  echo "按任意鍵關閉..."
  read -n 1
  exit 1
fi

if [ ! -d "$DEST" ]; then
  echo "錯誤：找不到 Obsidian Attachments 資料夾 ($DEST)"
  echo "按任意鍵關閉..."
  read -n 1
  exit 1
fi

count=0
skip_md=0

# 遞迴搜尋所有支援的格式（排除 .md）
while IFS= read -r -d '' f; do
  filename=$(basename "$f")
  mv "$f" "$DEST/$filename"
  echo "已搬移: $filename"
  count=$((count + 1))
done < <(find "$SRC" -type f \( -iname "*.pdf" -o -iname "*.doc" -o -iname "*.docx" -o -iname "*.pptx" -o -iname "*.ppt" -o -iname "*.xlsx" -o -iname "*.xls" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.heic" \) -print0)

# 計算跳過的 .md 檔案數
skip_md=$(find "$SRC" -type f -iname "*.md" | wc -l | tr -d ' ')

# 清除空的子資料夾
find "$SRC" -mindepth 1 -type d -empty -delete 2>/dev/null

echo ""
echo "完成！共搬移 $count 個檔案到 Obsidian Attachments。"
if [ "$skip_md" -gt 0 ]; then
  echo "跳過 $skip_md 個 .md 檔案（已透過 Claude 直接寫入 vault）。"
fi
echo "按任意鍵關閉..."
read -n 1
```

---

## 錯誤容錯

- 某份報告讀取失敗（加密、損毀、格式不支援）時，標記為「待手動處理」，跳過此檔，繼續處理下一份
- 不要因為一份檔案失敗就中斷整個流程
- 在 Step 7 完成回報中統一列出所有處理失敗的檔案及失敗原因
- Obsidian MCP 的 `patch_vault_file` 對中文標題有已知 bug，一律使用 `create_vault_file` 建立或覆寫整份檔案
- `create_vault_file` 對含全形冒號（：）的檔名可能在 vault 根目錄產生空白副本。建立 .md 原文到 Attachments/ 後，必須用 `search_vault_simple` 確認 vault 根目錄沒有同名空檔，若有則用 `delete_vault_file` 刪除
- 若 Obsidian MCP 連線失敗，提示使用者確認 Obsidian 是否已開啟且 Local REST API plugin 是否啟用

---

## 禁用事項（不可違反）

1. **禁止使用簡體字或中國大陸用語**：全程繁體中文
2. **禁止使用「」引號**：引用原文直接融入句子，不加任何引號或書名號
3. **禁止使用箭頭符號**：包括 →、➜、➡、⇒、▸、►、> 等方向符號，用文字連接詞（故、因此、帶動、導致等）代替
4. **禁止粗體**：索引筆記內文不使用 `**` 粗體標記（Markdown 標題 `#` 和 frontmatter 除外）
5. **禁止自行編造數據**：索引筆記中的所有數字必須來自原始報告，不可憑 Claude 自身知識補充
6. **禁止跳過數據**：原文中出現的具體數字（百分比、金額、日期、預測值、目標價）全部要寫進摘要，一個都不能漏
7. **禁止上網搜尋補充內容**：索引筆記的所有內容必須來自原始報告本身

---

## 觸發關鍵字

以下關鍵字觸發此 Skill：
- 「整理報告」「處理報告」「掃描報告」「報告整理」
- 「報告收件夾」（提到這個資料夾名稱時）
- 「幫我整理報告」「報告進來了」「新報告」

以下關鍵字**不觸發**此 Skill（屬於其他 skill）：
- 「寫週報」「ELN」「月報」：觸發 weekly-report 或 monthly-report
- 「寫新聞」「新聞評論」：觸發 news-commentary
- 「框架」：觸發 investment-thesis
- 「幫我整理」「幫我摘要」（不含「報告」二字時）：不觸發任何 skill


---

## 定錨産業筆記専用處理流程

當報告收件夾內出現大量 .md 格式的定錨産業筆記（檔名含「定錨」或放在「定錨産業筆記」子資料夾）時，不使用標準 Step 1-7 流程，改用以下専用流程。

### 工具位置

Python 處理腳本放在使用者的工作資料夾：

  報告收件夾/定錨工具/extract_anchor_v2.py
  報告收件夾/定錨工具/gen_notes_v2.py
  報告收件夾/定錨工具/定錨筆記處理指南.md

重要：在 Codex 中直接使用 `$INBOX_PATH/定錨工具/`。若讀取 Desktop 路徑被沙盒阻擋，先向使用者要求授權，不要改用 Cowork 掛載流程。

### 執行步驟

1. 找到腳本：確認 `$INBOX_PATH/定錨工具/` 內有兩個 .py 檔
2. 複製到 /tmp/（避免在掛載目錄直接執行）：
     cp "$INBOX_PATH/定錨工具/extract_anchor_v2.py" /tmp/
     cp "$INBOX_PATH/定錨工具/gen_notes_v2.py" /tmp/
3. 執行 extract_anchor_v2.py（每批 100 筆）：
     python3 /tmp/extract_anchor_v2.py \
       --inbox "$INBOX_PATH/定錨産業筆記" \
       --workdir /tmp \
       --batch-start 0 --batch-size 100
   輸出：/tmp/batch_clean.json
4. 執行 gen_notes_v2.py：
     python3 /tmp/gen_notes_v2.py --input /tmp/batch_clean.json
   輸出：/tmp/batch_final.json
5. 寫回清洗後原文到 vault Attachments/（取代亂碼原檔）：
   讀取 batch_clean.json，逐筆用 mcp__obsidian-mcp-tools__create_vault_file 將清洗後的 .md 寫入 vault 的 Attachments/ 資料夾。
   這一步確保 vault 中的原始附件是乾淨版本，使用者點進 wikilink 看到的不會是亂碼。

   逐筆呼叫 Obsidian MCP 時：
   - path 參數：Attachments/{filename}（filename 來自 batch_clean.json 的 filename 欄位，即原始 .md 檔名）
   - content 參數：該筆的 clean_text 欄位（清洗後的內容）
   - 若 Attachments/ 裡已有同名檔案，create_vault_file 會覆寫，這是預期行為
   - 寫入後用 search_vault_simple 確認 vault 根目錄沒有產生同名空檔（全形冒號 bug），若有則刪除

   Python 讀取範例：
     import json
     with open('/tmp/batch_clean.json', 'r') as f:
         items = json.load(f)
     for item in items:
         filename = item['filename']      # 原始 .md 檔名
         clean_text = item['clean_text']   # 清洗後的純文字內容
         # 用 Obsidian MCP create_vault_file 寫入 Attachments/{filename}

6. 逐筆上傳索引筆記到 Obsidian vault：讀取 batch_final.json，用 mcp__obsidian-mcp-tools__create_vault_file 寫入每筆筆記

### 批次進度（持續更新）

Batch 1 | 000-099 | 完成
Batch 2 | 100-199 | 待處理
Batch 3 | 200-299 | 待處理
Batch 4 | 300-399 | 待處理
Batch 5 | 400-457 | 待處理

詳細說明請讀：報告收件夾/定錨工具/定錨筆記處理指南.md


---

## 定錨工具防呆檢查（必須在任何定錨批次處理前執行）

觸發定錨専用流程的第一件事，必須執行以下防呆檢查，不可跳過：

### 防呆 Step 0：確認工具資料夾存在

用 Bash 執行：
  ls "$INBOX_PATH/定錨工具/extract_anchor_v2.py" 2>/dev/null

（若 `$INBOX_PATH` 尚未設定，先設為 `/Users/yuukilin/Desktop/報告收件夾`）

情況 A：找到檔案 → 繼續正常流程

情況 B：找不到檔案 → 立即執行下列兩個動作，不要繼續處理：
  1. 檢查 `/Users/yuukilin/Desktop/報告收件夾/定錨工具/` 是否存在
  2. 若仍找不到，提示使用者確認定錨工具是否放在桌面「報告收件夾/定錨工具」內

情況 C：Desktop 路徑被沙盒阻擋 → 向使用者要求授權讀取該資料夾

### 防呆邏輯的實際 Bash 寫法

TOOL_CHECK=$(find "$INBOX_PATH" -name "extract_anchor_v2.py" -path "*/定錨工具/*" 2>/dev/null | head -1)
if [ -z "$TOOL_CHECK" ]; then
  # 工具不存在，通知使用者檢查桌面報告收件夾
  echo "MISSING"
else
  echo "$TOOL_CHECK"
fi

若輸出 MISSING，停止定錨流程並提示使用者。
若輸出路徑，從路徑自動推算 TOOL_DIR 和 INBOX_DIR，繼續執行。
