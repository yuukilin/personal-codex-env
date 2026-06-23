# Vault Schema 參考文件

定義 Obsidian vault 的欄位格式、路由規則、詞彙表。
Theme 和 Ticker 的「現有清單」不在本文件中——每次存檔前必須動態掃描 vault 取得最新清單。

---

## 1. 資料夾路由規則

| 內容類型 | 目標資料夾 | 檔名格式 |
|----------|-----------|----------|
| 美股法說會 | `2 Sources/US-Earnings/` | `YYYY-MM-DD-TICKER-CompanyName-us-earnings.md` |
| 台股法說會 | `2 Sources/TW-Earnings/` | `YYYY-MM-DD-TICKER-CompanyName-tw-earnings.md` |
| 研究報告 | `2 Sources/Reports/` | `YYYY-MM-DD-Source-標題關鍵字.md` |
| Podcast | `2 Sources/Podcasts/` | `YYYY-MM-DD-EPxxx-來源名.md` |
| 定錨投顧 | `2 Sources/定錨/` | `YYYY-MM-DD-定錨-標題.md` |
| 書籍 | `2 Sources/Books/` | 依書名 |
| 自主研究 | `2 Sources/Research/` | `YYYY-MM-DD-主題.md` |
| Theme 卡片 | `1 Cards/` | `Theme-[slug].md` |
| Ticker 總整理 | `3 MOC/Tickers/` | `TICKER-研究總整理.md` |

### 路由判斷

- 法說會看上市地：美股/國際股 → `2 Sources/US-Earnings/`，台股 → `2 Sources/TW-Earnings/`
- 德國（XETRA）、荷蘭、日本等非美股的國際公司法說會 → 也歸 `2 Sources/US-Earnings/`
- 不確定時 → 先明確說「我不確定這篇應該歸哪裡」，列出候選路徑並詢問；不要先丟到 Inbox
- 禁止寫入舊路徑：根目錄 `TW-Earnings/`、根目錄 `法說會/`、`0 Inbox/pending-analysis/`、`03-投資研究/`、`2 Sources/Transcripts/`、`2 Sources/Articles/`

---

## 2. Frontmatter 模板

### 2A. 法說會

```yaml
date: YYYY-MM-DD
source: us-earnings                    # 或 tw-earnings
company: Company Name English
ticker: TICKER
sectors: [sector1, sector2]
themes: [theme-slug-1, theme-slug-2]
signal_tags: [tag1, tag2]
companies_mentioned: [Co1, Co2]
industries_mentioned: [產業1, 產業2]   # 繁體中文
unmatched_terms: [term1, term2]        # 無對應 tag 的重要專有名詞
tags: [us-earnings]                    # 或 [tw-earnings]
status: pending-analysis
fiscal_year: 2026
fiscal_quarter: 2
```

### 2B. 研究報告

```yaml
type: source-note
source: Source Name
date: YYYY-MM-DD
report_type: sector-report             # 見 report_type 詞彙表
tickers: [TICKER1, TICKER2]            # 主角標的（陣列）
sectors: [sector1]
tags: [tag1, tag2]
rating: "評等文字"                      # 如 "Buy PT$85"
key_thesis: "一句話核心論點"
key_data:
  - "關鍵數據 1"
  - "關鍵數據 2"
themes: [theme-slug-1]
supply_chain:
  upstream: [supplier1]
  midstream: [maker1]
  downstream: [customer1]
related_tickers: [TICK1]               # 被提及但非主角
regions: [taiwan, us]
conflict_flag: false
status: processed
```

### 2C. Podcast

```yaml
date: YYYY-MM-DD
source: podcast-來源名
episode: EPxxx
tags: [podcast]
tickers_mentioned: [TICK1]
themes: [theme-slug-1]
status: processed
```

---

## 3. 詞彙表（固定值）

### sectors

```
semiconductor, ai-infrastructure, networking, ev, energy, utilities,
clean-energy, oil-gas, materials, cloud, software, financials, biotech,
consumer, macro, space, aerospace-defense, industrials, agriculture,
automotive, telecom, real-estate, healthcare
```

選 1-4 個最相關。如需新增，直接使用英文小寫 kebab-case。

### signal_tags

```
guidance-change          # 財測上調或下調
capacity-expansion       # 產能擴建/新廠
demand-shift             # 需求結構性轉移
supply-chain-signal      # 供應鏈變動
price-increase           # 漲價
price-decrease           # 降價壓力
inventory-change         # 庫存水位變動
margin-expansion         # 利潤率擴張
margin-compression       # 利潤率壓縮
market-share-shift       # 市佔率變動
restructuring            # 組織重組/業務重整
m-and-a                  # 併購
new-product              # 新產品
management-change        # 管理層異動
regulatory-change        # 法規/政策變動
```

選 2-5 個。如需新增，使用英文小寫 kebab-case。

### report_type

```
sector-report, company-report, earnings-update, initiation,
macro-report, strategy-report, commodity-report, academic-paper,
index-factsheet
```

### regions

```
taiwan, us, china, japan, korea, india, europe, brazil, latam,
middle-east, southeast-asia, global
```

---

## 4. Ticker 格式

| 市場 | 格式 | 範例 |
|------|------|------|
| 美股 | 純 ticker | AAPL, NVDA |
| 台股 | 數字.TW | 2330.TW |
| 港股 | 數字.HK | 0700.HK |
| 國際股 | 最通用的 ticker | IFX, ASML |

Ticker 總整理頁面檔名：`TICKER-研究總整理.md`（台股用 `2330.TW-研究總整理.md`）

---

## 5. Wikilink 格式

| 類型 | 格式 | 範例 |
|------|------|------|
| Theme | `[[Theme-slug]]` | `[[Theme-ai-datacenter-power]]` |
| 美股/國際 Ticker | `[[TICKER-研究總整理\|TICKER]]` | `[[IFX-研究總整理\|IFX]]` |
| 台股 Ticker | `[[NUM.TW-研究總整理\|中文名(NUM)]]` | `[[2330.TW-研究總整理\|台積電(2330)]]` |
| 報告交叉引用 | `[[完整檔名]]` | `[[2025-09-15-元大投顧-功率半導體...]]` |

所有連結都積極建立，不管目標頁面是否已存在。

---

## 6. 正文規則

- 全文繁體中文
- 禁用「」引號
- 禁用 ← ↑ ↓（→ 可用）
- 數據保留原始單位（EUR, USD, TWD）
- 使用 Markdown 標題、表格、粗體

---

## 7. Theme slug 命名規則

- 英文小寫 kebab-case：`solid-state-transformer`
- 盡量簡潔但要能辨識主題
- 如果概念偏中文語境且無簡潔英文，可用中文：`半導體微影技術競爭`
- 建立前必須語意比對現有 Theme，避免同概念重複命名
