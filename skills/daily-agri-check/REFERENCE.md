# Daily Agri Check Reference

本檔提供每日農產品日報的模板、鮮度規則、報告排程與 tracker 欄位。主流程仍以 `SKILL.md` 為準。

## 資料覆蓋檢查表

每次執行至少檢查：
- 價格：糖、玉米、小麥、大豆、棉花、咖啡、可可、棕櫚油、WTI。
- 美國：USDA/NASS Crop Progress（週一美東下午）、WASDE（月報）、Grain Stocks / Acreage / Prospective Plantings（季節性）。
- 天氣：NOAA ENSO monthly / weekly、BOM ENSO/IOD、IMD monsoon press release / extended range。
- 軟商品：UNICA、MPOB、CEPEA、CFTC COT。
- Obsidian：`enso-tracker`、`sugar-tracker`、`global-monitor-tracker`、必要時 `palm-oil-tracker`、`crop-progress-tracker`、`wasde-tracker`、`plantings-stocks-tracker`。不得更新 `ethanol-parity-tracker`。

## 鮮度規則

新聞或事件要列為「今日新訊號」，必須同時符合：
- 發佈時間距執行時間不超過 48 小時。
- 原始觀測日距執行時間不超過 48 小時。
- 來源能追到官方、交易所、產業協會、主要通訊社或具名資料商。

不符合 48 小時但仍重要者，只能放在「中期格局」或附錄，不要算入今日新訊號。

## 報告排程表

| 報告 | 頻率/時間 | 搜尋窗口 | grace_days | 影響 |
|---|---:|---:|---:|---|
| USDA/NASS Crop Progress | 週一 16:00 ET 左右 | 週一晚至週二台北早 | 1 | ZC/ZS/ZW/CT |
| USDA WASDE | 每月約 9-12 日 12:00 ET | 發布日前後 2 天 | 1 | 穀物、糖、棉花 |
| USDA Acreage | 6/30 12:00 ET | 6/30-7/1 | 1 | ZC/ZS/ZW/CT |
| USDA Grain Stocks | 3/31、6/30、9/30、1/12 附近 | 發布日前後 1 天 | 1 | ZC/ZS/ZW |
| USDA Prospective Plantings | 3/31 12:00 ET 附近 | 發布日前後 1 天 | 1 | ZC/ZS/ZW/CT |
| CFTC COT | 週五 15:30 ET，部位日為週二 | 週五晚至週六台北 | 1 | 全品種持倉 |
| NOAA ENSO Diagnostic Discussion | 每月第二個週四附近 | 發布日起 2 天 | 2 | SB/FCPO/KC/CC/穀物 |
| NOAA Weekly ENSO | 每週一附近 | 發布日起 2 天 | 2 | ENSO 快速變化 |
| BOM ENSO/IOD | 每週或雙週 | 發布日起 2 天 | 2 | IOD/ENSO 交互作用 |
| IMD monsoon press release | 季風季近每日 | 每日 | 1 | SB/印度穀物 |
| IMD Extended Range Forecast | 週四附近 | 發布日起 3 天 | 2 | SB/印度雨量 |
| MPOB monthly palm oil | 每月 10 日左右 | 發布日前後 3 天 | 2 | FCPO |
| UNICA Center-South sugarcane | 4-11 月雙週 | 月初/月中後 5 天 | 3 | SB |
| CEPEA hydrous ethanol | 工作日/週值 | 近 7 天 | 3 | SB 乙醇平價背景 |
| CONAB grains/sugar/coffee | 每月 | 官方日程前後 5 天 | 3 | ZC/ZS/SB/KC |

若今天已超過搜尋窗口結束日加 grace_days，且 tracker 仍停在上一期，視為漏接並補搜一次。

## UNICA 判別規則

UNICA 只在官方或可靠二手來源明確寫出 Center-South、報告半月、壓榨量、糖產量、乙醇產量或糖佔比時，才升級為新供需訊號。只有媒體提到「巴西供給強/弱」但沒有半月數字時，只能放進背景。

糖佔比判斷：
- <45% 且連續下降：因素4偏多。
- 45-49%：中性偏多，需看乙醇平價與油價。
- >50%：偏空糖，代表巴西偏向做糖。

## 價格抓取與驗證

優先順序：
1. Browser/Chrome DOM 抽取 Trading Economics 頁面 `#p`, `#changep`, `#pcp`。
2. 若瀏覽器工具不可用，使用公開 web fetch/search 讀 Trading Economics、Barchart、Investing、交易所或 USDA/ICE/CBOT 可讀頁。
3. 若是 CFD/參考價，日報必須標註「參考價，不等於交易所官方結算價」。

閾值：
- 糖、棉花、咖啡：跨來源差距 >0.3 c/lb 要標記不確定。
- 玉米、小麥、大豆：差距 >5 c/bu 要標記不確定。
- 可可：差距 >100 USD/t 要標記不確定。
- FCPO：差距 >80 MYR/t 要標記不確定。
- WTI：差距 >1.5 USD/bbl 要標記不確定。

日漲跌幅必須來自來源，不可自行計算後當成網站日變動。

## 新聞搜尋規則

優先查：
- 官方：USDA/NASS/FAS、NOAA/CPC、BOM、IMD、MPOB、CFTC、CONAB、UNICA。
- 市場：Trading Economics、Reuters、Bloomberg、Dow Jones、Successful Farming、Farm Progress、AgriCensus、Barchart。
- 區域：印度季風可用 IMD 官方優先，輔以 Economic Times / Times of India 且需標明是媒體引述。

格式：
`[發佈 MM/DD | obs: YYYY-MM-DD | 標籤] 事件 — 影響`

## ENSO/IOD 判斷

觸發完整 ENSO 段落的條件：
- NOAA weekly 觀測週日期新於 tracker。
- NOAA monthly 發布日新於 tracker。
- BOM/IRI/NMME 新版本使 Nino 3.4 或 IOD 判斷變化達 0.2C 以上。

型態判斷：
- Nino 1+2 明顯高於 Nino 4：東太型/傳統型傾向。
- Nino 4 明顯高於 Nino 1+2：中太型/Modoki 傾向。
- Coastal 升溫強但 Nino 3.4 未跟上：沿岸型，對全球農業衝擊較不穩。

IOD 讀法：
- 正 IOD：部分抵消 El Nino 對印度季風壓制。
- 中性：維持 ENSO 原判。
- 負 IOD：與 El Nino 疊加，印度季風風險升高。

## 日報模板

### N=0 精簡模式

```markdown
**每日農產品晨報｜YYYY-MM-DD（週X）**

> 今日一句話：一句話講清楚沒有新訊號時，最重要的延續判斷。

**今日重點**

1. ...
2. ...
3. ...

**今日判斷**

| 品種 | 今日方向 | 理由 |
|---|---|---|

**接下來最該盯**

| 觀察點 | 判斷門檻 |
|---|---|

**附錄收斂版**

價格、作況、ENSO/IOD、資料限制、來源。
```

### N>=1 完整模式

```markdown
**每日農產品晨報｜YYYY-MM-DD（週X）**

> 今日一句話：先講今天真正改變判斷的訊號。

**今日重點**

1. 新訊號與影響。
2. 延續中的舊故事。
3. 最需要驗證的風險。
4. 今日不要過度解讀的雜訊。

**今日判斷**

| 品種 | 今日方向 | 理由 |
|---|---|---|

**接下來最該盯**

| 觀察點 | 為什麼重要 | 判斷門檻 |
|---|---|---|

**附錄收斂版**

價格、ENSO/IOD、COT、報告排程、限制與來源。
```

## Tracker 寫入規則

所有農產品 tracker 與每日備份只寫 `農產品追蹤/`。

每日備份：
- 路徑：`農產品追蹤/daily-report/YYYY-MM-DD-農產品日報.md`
- frontmatter：`date`, `tags`, `source`, `status: draft`
- 內文保存完整 Step 6 晨報，不可只存摘要。

Tracker section 標題一律用英文：
- `Latest Data`
- `History`
- `Key Background`
- `News Log`
- `Sugar Bull Case: Five Factor Dashboard`

同日 rerun 先更新同一份每日備份與同一日 tracker 區段，不建立 copy 或亂加後綴。
