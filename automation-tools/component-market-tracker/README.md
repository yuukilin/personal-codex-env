# 元件供需雷達追蹤設計

本追蹤只比較兩組來源：

- Future Electronics Market Conditions Report：正式通路的交期、供需、價格慢訊號。
- 華強電子網：現貨市場的搜尋熱度、品牌/品類熱度、雲報價快訊號。

## 100 分版流程

1. 先做來源健康檢查，不急著寫結論。
   - HTTP 狀態碼、最終 URL、內容類型、內容長度、抓取時間。
   - Future PDF 的 `Last-Modified`、`ETag`、`content-length`、hash。
   - 華強電子網是否能抽到最新週期、榜單、雲報價 hidden 欄位。

2. 再做結構化快照。
   - Future：版本、更新日、PDF metadata、分類頁 JPG URL、分類頁圖片 OCR/視覺抽取結果。
   - 華強烽火指數：最新週期、型號熱度、品牌熱度、品類熱度、品類飆升。
   - 華強雲報價：今日熱料、型號、品牌、批號、封裝、起訂量、報價、品質與備註。

3. 最後才做比對與報告。
   - 同來源比前期：排名變化、百分比變化、lead time 變化、pricing/trend 方向變化。
   - 跨來源比對：Future 正式通路轉緊，華強現貨也轉熱，才列高優先 watchlist。
   - 若只有單邊訊號，放在「背離與限制」，不要硬下結論。
   - 若 Future 版本、Future 分類圖片、華強最新週期都未變，報告要明確寫「來源未更新，僅例行檢查」，不可製造新趨勢。

## 核心來源分層

| 層級 | 來源 | 用途 | 狀態 |
|---|---|---|---|
| A | Future 官方 landing page | 版本、更新日、PDF、分類頁入口 | 核心 |
| A | Future 分類頁 JPG | 分品類抽取，比 PDF 更適合做月度差異 | 核心 |
| A | Future PDF | 完整歸檔、metadata、fallback | 核心 |
| A | 華強電子網烽火指數 | 週期、型號/品牌/品類熱度 | 核心 |
| B | 華強電子網雲報價 | 熱門型號報價抽樣，不當全市場均價 | 輔助 |
| C | 華強商城 | 僅當華強電子網失效或需要交易頁交叉驗證 | 備援 |

## 訊號分數

每個品類或料號族群給一個 0-100 的追蹤分數：

- Future 正式通路分數 40 分：lead time 拉長、trend 轉緊、pricing 轉漲、EOL/註記。
- 華強烽火分數 35 分：排名上升、搜尋指數上升、品類熱度或飆升榜連續上榜。
- 華強雲報價分數 15 分：同型號可比報價、供應商數、報價時間、批號/封裝可比性。
- 可信度分數 10 分：兩來源同方向、欄位抽取成功、不是單一異常值。

70 分以上列入高優先 watchlist；50-69 分列入觀察；50 分以下只放背景。

## 檔案位置

- 可攜程式碼根目錄：`${CODEX_HOME:-$HOME/.codex}/automation-tools/component-market-tracker`
- 每台 Mac 的 runtime 根目錄：`${COMPONENT_MARKET_RUNTIME_DIR:-${CODEX_HOME:-$HOME/.codex}/automations/component-market-tracker}`
- 探測腳本：程式碼根目錄下的 `scripts/probe_sources.py`
- 報告生成腳本：程式碼根目錄下的 `scripts/generate_report.py`
- 來源對照：程式碼根目錄下的 `config/source-map.json`
- 報告：runtime 根目錄下的 `reports/YYYY-MM-DD-component-market-radar.md`
- 快照：runtime 根目錄下的 `snapshots/YYYY-MM-DD-snapshot.json`
- 原始抓取：runtime 根目錄下的 `runs/YYYY-MM-DD/raw/`
- 長期記憶：runtime 根目錄下的 `memory.md`
- Obsidian 時間軸：`/Users/yuukilin/Library/Mobile Documents/iCloud~md~obsidian/Documents/卡片筆記盒模板/2 Sources/Research/2026-07-01-元件供需雷達-Future-華強電子網-時間軸.md`

程式碼目錄只放可同步程式與來源對照；歷史報告、快照、原始資料與 `memory.md` 只放每台 Mac 自己的 runtime 根目錄。Obsidian 不保存每週完整長報告，只維護同一份活頁時間軸：

- 最新狀態
- 目前優先題材
- 每週一列時間軸
- 完整報告與 summary JSON 路徑

舊資料的用途是比對趨勢，不是拿來閱讀；不要每週新增一篇完整 source note。

若 Future 版本與華強最新週期都和時間軸既有列相同，代表來源沒有新資料；此時只更新「最新狀態」與完整報告路徑，不新增時間軸列。

`generate_report.py` 會自動尋找上一期 source-probe snapshot，輸出「跟上一期比」區塊，至少包含：

- Future 版本是否變動
- 華強週期是否變動
- Future 分類圖片 hash 是否變動
- 華強品類榜單是否有排名或百分比明顯變化
- 華強熱門型號是否新增

## 實際快照 schema

`probe_sources.py` 產生的 source-probe snapshot 目前使用下列頂層欄位：

- `date`
- `generated_at_taipei`
- `source_health`
- `future`
- `hqew`

重要子欄位：

- `future.last_updated`
- `future.categories`
- `source_health.future_pdf`
- `source_health.future_category_<slug>`
- `source_health.hqew_fire_index`
- `source_health.hqew_cloud_quote`
- `hqew.fire_index.periods`
- `hqew.fire_index.model_heat_rank`
- `hqew.fire_index.brand_heat_rank`
- `hqew.fire_index.category_heat_rank`
- `hqew.fire_index.category_rising_rank`
- `hqew.cloud_quote.hot_quote_rows`

後續自動化報告必須讀這些實際欄位，不要假設存在 `sources`、`future.landing.last_updated_text`、`hqew.fire_index.model_heat` 這類舊草稿欄位。

## 重要限制

- Future 的分類資料是圖片，不是 HTML 表格；需用分類 JPG OCR/視覺檢查，PDF 作備援。
- Future OCR 對文字與 lead time 可用，但箭頭方向、趨勢符號容易誤讀；正式報告必須標記 OCR/視覺信心，低信心欄位不能當成趨勢結論。
- 華強雲報價的畫面數字有混淆，必須優先讀 hidden input 屬性，不要直接讀表格文字。
- 華強報價是現貨平台樣本，不等於原廠報價、EMS/ODM 長約價格或全市場均價。
- 原始 HTML 噪音很高，不適合直接全文搜尋做結論；比對應以 snapshot JSON、Future OCR txt、正式報告與上期 summary 為主。

## 報告語氣

使用者是業外投資研究者，不是電子零件採購或硬體工程師。正式報告主體要先回答：

- 哪些品類看起來缺貨更緊？
- 哪些品類有漲價或成本上升壓力？
- 哪些品類只是現貨市場很熱、正式通路還未確認？
- 對投資研究可以延伸成哪些題材？

英文只保留來源名稱、必要縮寫、品牌和料號。凡是能翻中文的術語都要翻，例如：

- pricing upward pressure：價格上漲壓力
- allocation：配貨/限量供應
- lead time：交期
- significant cost increases：成本明顯上升
- monthly pricing：每月重新報價
- raw materials：原材料
- tariffs：關稅
- OCR：圖片文字辨識
- baseline：基準期
- watchlist：追蹤清單

型號熱度榜不可放在主結論前面；應放在附錄，並加上白話說明，例如微控制器、快閃記憶體、感測器、電能計量晶片。主結論要聚焦題材，不要要求使用者自己從料號猜產業。

## 建議執行指令

例行追蹤時依序執行：

1. `${CODEX_HOME:-$HOME/.codex}/automation-tools/component-market-tracker/scripts/probe_sources.py --date YYYY-MM-DD --download-category-images`
2. `${CODEX_HOME:-$HOME/.codex}/automation-tools/component-market-tracker/scripts/generate_report.py --run-id YYYY-MM-DD`

Debug run 可用：

1. `${CODEX_HOME:-$HOME/.codex}/automation-tools/component-market-tracker/scripts/probe_sources.py --date YYYY-MM-DD-debug --download-category-images`
2. `${CODEX_HOME:-$HOME/.codex}/automation-tools/component-market-tracker/scripts/generate_report.py --run-id YYYY-MM-DD-debug --report-date YYYY-MM-DD`

`generate_report.py` 會讀取實際 snapshot schema、補 missing OCR、與上一期比較、輸出 automation report、summary JSON，並更新同一份 Obsidian 時間軸。
