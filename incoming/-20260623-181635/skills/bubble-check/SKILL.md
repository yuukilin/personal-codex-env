---
name: bubble-check
description: 手動執行 AI/美股泡沫檢查。當使用者說「泡沫檢查」「重跑泡沫」「Kindleberger 泡沫檢查」「AI 泡沫更新」「現在是不是泡沫」「泡沫框架」時，務必使用此 skill。此 skill 會先讀 Obsidian 的 Kindleberger 主框架與 Howard Marks 泡沫觀察卡，再搜尋最新市場數據，用 Displacement → Boom → Euphoria → Profit Taking → Panic 五階段定位，產出一篇 dated snapshot 並更新追蹤總表。這是手動 workflow，不要建立排程或自動化。
---

# Bubble Check

用 Kindleberger 五階段框架，定期重跑 AI/美股泡沫檢查。這個 skill 是「薄執行手冊」：Obsidian 筆記是 source of truth，skill 只負責觸發、讀檔、查最新資料、固定輸出格式與回寫規則。

## 核心原則

- 全文使用繁體中文。
- 這是手動觸發 workflow，不要建立 automation、reminder、monitor 或 recurring schedule。
- 不要覆蓋歷史快照。每次完整執行都建立新的 dated snapshot。
- 不要把舊 Obsidian 數據當成最新數據；凡涉及市場、估值、利率、IPO、信用、情緒、公司 capex/earnings，必須重新查證。
- 如果最新資料不足，明確寫「我搜到的資料不足以回答這個問題」，不要用推測補空白。
- 區分「已驗證最新資料」「Obsidian 舊框架資料」「自己的判斷」。
- 泡沫分數是判斷，不是事實；要標明主要假設與限制。

## 必讀 Obsidian 筆記

優先使用 Obsidian MCP 讀取。若 MCP 不可用或連不上，告知限制後改用本機 iCloud vault 路徑。

Vault 根目錄：

`/Users/yuukilin/Library/Mobile Documents/iCloud~md~obsidian/Documents/卡片筆記盒模板`

每次完整泡沫檢查都先讀：

1. `3 Analysis/2026-05-09-Dotcom-vs-AI-Kindleberger五階段泡沫分析.md`
   - 主框架：Displacement → Boom → Euphoria → Profit Taking → Panic。
   - 用於 Dot-com vs AI 比較、階段定義、歷史風險機制。

2. `3 Analysis/2026-05-09-Kindleberger泡沫框架即時市況更新.md`
   - 既有 snapshot 範例。
   - 用於延續格式、觀察哪些指標曾被追蹤。

3. `1 Cards/觀察泡沫 (On Bubble Watch).md`
   - Howard Marks 心理診斷。
   - 用於判斷 FOMO、「再貴都買」、「新故事」、「只會更好」等泡沫式思維。

如有追蹤總表，亦讀取：

`3 Analysis/Kindleberger泡沫框架追蹤總表.md`

若總表不存在，首次完整執行後建立。

## 最新資料搜尋

完整執行前先搜尋最新資料。高風險或時間敏感資料至少交叉查可靠來源。優先使用官方或原始來源，其次使用可信金融資料商或研究機構。

建議資料來源：

- 指數/波動/信用：FRED、CBOE、ICE BofA、S&P Dow Jones Indices。
- 估值：FactSet Earnings Insight、Goldman Sachs 公開研究、S&P、Robert Shiller/Multpl、YCharts/同級資料作輔助。
- 槓桿：FINRA Margin Statistics。
- 情緒/倉位：AAII、NAAIM、CFTC 或公開 fund flow 資料。
- IPO/供給：Renaissance Capital、SEC S-1、Dealogic/FactSet 若可得。
- AI capex/earnings：公司財報、10-Q/10-K、earnings call、官方 press release、可信賣方公開研究。
- 宏觀/利率/通膨：Fed、BEA、BLS、Treasury、FRED。

至少更新這些類別：

1. 市場水位：S&P 500、NASDAQ、Nasdaq 100 如可得。
2. 估值：Forward P/E、CAPE、P/S、Buffett Indicator 或可替代的總市值/GDP。
3. 集中度與廣度：Top 10 concentration、equal-weight vs cap-weight、52-week breadth。
4. 槓桿：FINRA margin debt，最好換算 GDP 或與去年同期比較。
5. 信用與波動：High yield OAS、VIX。
6. 情緒/倉位：AAII bullish/bearish、NAAIM exposure。
7. IPO 與供給：IPO 件數/募資額、mega IPO pipeline、lock-up 風險。
8. AI 基本面：hyperscaler capex、AI revenue/ROI、NVIDIA/semis earnings、循環融資跡象。

## 分析流程

### 1. 先復述任務

簡短說明本次是用 Obsidian 主框架重跑泡沫檢查，並列出資料更新日期。不要展開冗長推理。

### 2. 用 Howard Marks 做心理診斷

判斷市場是否出現：

- FOMO 擴散。
- 「再貴都值得買」。
- 新技術故事讓傳統估值失效的說法。
- 非投資圈大量加入。
- 對龍頭公司長期不敗的信念。
- 指數/被動資金造成不看價格的買盤。

結論分成：`未見極端心理`、`心理升溫`、`明顯狂熱`。

### 3. 用 Kindleberger 五階段定位

逐階段判斷：

- `Displacement`：真實技術/政策衝擊是否仍成立。
- `Boom`：資本流入、capex、融資、正向回饋是否加速。
- `Euphoria`：估值、情緒、敘事、集中度、槓桿是否進入極端。
- `Profit Taking`：內部人、機構、龍頭、融資方是否開始降曝險。
- `Panic`：是否出現連鎖賣壓、信用收縮、敘事反轉。

輸出目前階段，例如：

`目前定位：Euphoria 後段，尚未正式進入 Profit Taking。`

若階段不確定，明確說明分歧證據。

### 4. 更新 Dot-com vs AI 比較表

至少包含：

| 維度 | Dot-com 峰值 | AI/當前現況 | 判讀 |
|---|---:|---:|---|
| Shiller CAPE | | | |
| Buffett Indicator 或替代指標 | | | |
| S&P 500 P/S | | | |
| Margin Debt/GDP 或 YoY | | | |
| 市場集中度 | | | |
| NASDAQ/AI 龍頭 P/E | | | |
| 龍頭公司盈利能力 | | | |
| IPO 狂熱 | | | |
| 循環融資 | | | |
| 散戶情緒 | | | |
| VIX/信用利差 | | | |
| Fed/利率環境 | | | |

若某資料搜不到，欄位填 `資料不足`，不要硬補。

### 5. 給分與判斷

給三個結論：

- `泡沫風險分數`：0-10。
- `市場狀態`：健康牛市偏貴 / 局部泡沫 / 全面泡沫 / 泡沫破裂初期。
- `最重要一句話`：一句可直接貼給使用者的市場語言。

分數參考：

- 0-3：正常或低風險。
- 4-6：偏貴但仍有基本面支撐。
- 7-8：局部泡沫或 Euphoria 後段。
- 9-10：全面泡沫或 Profit Taking/Panic 明顯。

### 6. 列追蹤訊號

固定列三組：

- `惡化訊號`：例如 capex 下修、AI ROI 證偽、HY OAS 擴大、margin debt 去槓桿、mega IPO lock-up 到期。
- `反證訊號`：例如 AI revenue 快速追上 capex、EPS 上修擴散到非 AI、估值靠獲利消化、廣度改善。
- `下一次最該盯`：3-5 個具體指標。

## Obsidian 回寫規則

完整執行時，除非使用者明確說「只要聊天回答，不要存」，否則回寫 Obsidian。

### 快照

建立新檔，不覆蓋舊檔：

`3 Analysis/YYYY-MM-DD-Kindleberger泡沫框架即時市況更新.md`

frontmatter 至少包含：

```yaml
---
date: YYYY-MM-DD
tags: [macro, equity, bubble, ai, valuation, kindleberger]
source: 多來源即時數據彙整
status: draft
related: "[[2026-05-09-Dotcom-vs-AI-Kindleberger五階段泡沫分析]]"
---
```

### 追蹤總表

若不存在，建立：

`3 Analysis/Kindleberger泡沫框架追蹤總表.md`

總表只放精簡追蹤，不放長文。每次追加一列：

| 日期 | 階段定位 | 泡沫分數 | 最大風險 | 反證訊號 | 下一次最該盯 |
|---|---|---:|---|---|---|

## 快照輸出模板

```markdown
# Kindleberger 泡沫框架即時市況更新（YYYY-MM-DD）

以 [[2026-05-09-Dotcom-vs-AI-Kindleberger五階段泡沫分析]] 為基礎，用最新資料重新定位 AI/美股週期在 Kindleberger 五階段中的位置。

## 一、最重要結論

- 目前定位：
- 泡沫風險分數：
- 一句話：

## 二、Howard Marks 心理診斷

## 三、逐階段定位

### Displacement
### Boom
### Euphoria
### Profit Taking
### Panic

## 四、Dot-com vs AI 最新比較

| 維度 | Dot-com 峰值 | AI/當前現況 | 判讀 |
|---|---:|---:|---|

## 五、這次新增的關鍵變化

## 六、惡化訊號與反證訊號

### 惡化訊號
### 反證訊號
### 下一次最該盯

## 七、資料來源與限制

## 自我檢查

- 關鍵事實是否有來源：
- 是否有未驗證推測：
- 哪些資料不足：

相關連結：[[泡沫理論]] [[Kindleberger]] [[AI投資週期]] [[Dot-com泡沫]] [[Buffett Indicator]] [[Shiller CAPE]] [[循環融資]]
```

## 聊天回覆格式

回覆使用者時先給短版結論，不要把整篇 Obsidian 快照完整貼滿，除非使用者要求。

建議格式：

```markdown
一句話：

目前定位：
泡沫分數：
最大變化：
我最擔心：
反證條件：

已存入：
[Obsidian 檔名]
```

## 不要做的事

- 不要建立排程；使用者會手動跑。
- 不要只用舊 Obsidian 數字回答最新市況。
- 不要把所有高估值都直接稱為泡沫；要檢查心理、槓桿、供需與獲利。
- 不要只給投資建議；這是框架定位與風險檢查，不是買賣建議。
- 不要覆蓋主框架筆記或歷史快照。
