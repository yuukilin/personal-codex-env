# Daily Agri Check Reference

本檔提供每日農產品日報的模板、鮮度規則、報告排程與 tracker 欄位。主流程仍以 `SKILL.md` 為準。

## 目錄

1. 資料覆蓋檢查表
2. 鮮度與持續事件規則
3. 來源與證據分級
4. 報告排程表
5. 品種×產區×風險矩陣
6. 重大事件評分與深挖模板
7. 價格抓取與異常查因
8. 新聞搜尋規則
9. ENSO/IOD 判斷
10. 日報模板
11. Tracker 寫入規則

## 資料覆蓋檢查表

每次先建立覆蓋帳本，逐品種檢查下列六欄。主文可省略無變化項目，但附錄必須留下 `checked / new / active / unavailable / not-due`：

1. 價格與有效合約：糖、玉米、小麥、大豆、棉花、咖啡、可可、棕櫚油、WTI。
2. 官方供需／作況：該品種今天到期或漏接的報告。
3. 主要產區天氣與災害：最近48小時新事件＋最近7日仍有效事件。
4. 作物階段與病害：事件是否打到開花、結莢、灌漿、採收、乾燥或運輸。
5. 物流、政策與投入：道路／港口、出口政策、生質燃料、肥料、勞動力。
6. 需求與持倉：研磨、壓榨、出口、庫存、CFTC／交易所部位。

Obsidian 至少讀 `global-monitor-tracker` 的 Active Events、`enso-tracker`，以及有新訊號品種的 tracker。`ethanol-parity-tracker` 只讀不寫。

## 鮮度與持續事件規則

### 今日新訊號

一般事件必須同時符合：

- 發布時間距執行時間不超過48小時。
- 原始觀測日距執行時間不超過48小時。
- 可追到官方、交易所、產業協會、主要通訊社或具名資料商。

若事件較早發生，但48小時內出現新的官方災情、受災範圍、產量下修、預報延長、道路／港口影響或反證，只把「新增部分」算今日新訊號，並保留原始事件起始日。

### 持續重大事件

事件超過48小時，只要符合以下任一條件就繼續列入 Active Events，而不是刪除：

- 最新官方更新距今不超過7日。
- 氣象／災害預報仍在有效期。
- 作物影響尚未由到港量、作況、病害率或產量報告確認／否定。
- 事件仍在惡化、反覆發生，或尚未達成結案條件。

持續事件每天只需回答「變糟、持平、緩解或結案」，不可把同一舊事重複計為新訊號。

### 中期格局

超過7日且沒有新進展的資料，只能作結構背景並標日期。沒有新文章不等於風險消失；沒有有效更新則降低信心並列下一個檢查點。

## 來源與證據分級

- **A級**：政府／氣象局／農業部、交易所、港口、產業主管機關、官方作況與公司／協會原始報告。
- **B級**：Reuters、AP、Bloomberg、具名研究機構、具名分析師或可靠產業媒體，且能說明方法或引用原始資料。
- **C級**：Trading Economics、Barchart等市場彙整頁與未具名市場報導。可用來發現線索或取得參考價，不能單獨支撐重大產量結論。
- **D級**：社群貼文、論壇、未驗證圖片。只作線索，不進結論。

高影響事件至少需要一個A級來源加兩個獨立可靠來源；若官方資料不存在，至少需要兩個B級來源，並明確標示「尚無官方確認」。分析師預測必須保留機構、基期、年度與假設；未具名預測不得寫成市場共識。

## 報告排程表

| 報告 | 頻率/時間 | 搜尋窗口 | grace_days | 影響 |
|---|---:|---:|---:|---|
| USDA/NASS Crop Progress | 週一 16:00 ET 左右 | 週一晚至週二台北早 | 1 | ZC/ZS/ZW/CT |
| USDA WASDE | 每月約 9-12 日 12:00 ET | 發布日前後 2 天 | 1 | 穀物、糖、棉花 |
| USDA Acreage | 6/30 12:00 ET | 6/30-7/1 | 1 | ZC/ZS/ZW/CT |
| USDA Grain Stocks | 3/31、6/30、9/30、1/12 附近 | 發布日前後 1 天 | 1 | ZC/ZS/ZW |
| USDA Prospective Plantings | 3/31 12:00 ET 附近 | 發布日前後 1 天 | 1 | ZC/ZS/ZW/CT |
| USDA/FAS Export Sales | 每週四附近 | 發布日起 1 天 | 1 | ZC/ZS/ZW/CT |
| U.S. Drought Monitor／NOAA區域天氣 | 每週四＋重大天氣每日 | 發布日起 2 天 | 1 | ZC/ZS/ZW/CT |
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
| ICCO Quarterly Bulletin／Monthly Review | 季報約2/5/8/11月；月度市場回顧 | 官方發布日起 5 天 | 3 | CC |
| 象牙海岸 CCC 到港／銷售、迦納 COCOBOD 採購 | 週度或不定期 | 每週檢查；重大事件每日 | 3 | CC |
| SODEXAM／ONPC、GMet／NADMO 天氣與災情 | 警報與災情不定期 | 重大雨季／旱季每日 | 1 | CC/KC/FCPO及區域作物 |
| ICO Monthly Coffee Market Report | 每月 | 官方發布日起 5 天 | 3 | KC |
| Cecafe 巴西咖啡出口 | 每月 | 官方發布日起 5 天 | 3 | KC |
| GAPKI／印尼官方棕櫚油資料 | 每月／不定期 | 官方發布日起 7 天 | 5 | FCPO |

若今天已超過搜尋窗口結束日加 grace_days，且 tracker 仍停在上一期，視為漏接並補搜一次。

## 品種×產區×風險矩陣

廣掃時至少覆蓋下表；先做一輪跨品種搜尋，再對重大候選查地方官方來源。產區名稱是搜尋種子，不代表只有這些地區才重要。

| 品種 | 優先產區／節點 | 主要風險 | 優先來源 |
|---|---|---|---|
| 糖 | 巴西 Center-South、印度 Maharashtra／UP／Karnataka、泰國 | 乾旱、過量降雨、霜害、壓榨、糖醇比、港口物流 | UNICA、CONAB、INMET、IMD、印度／泰國糖業官方或協會 |
| 玉米 | 美國 Corn Belt、巴西 Safrinha、阿根廷 Pampas、黑海／歐洲 | 播種與授粉期熱旱、洪水、單產、出口政策 | USDA/NASS/FAS、NOAA、CONAB、INMET、SMN、歐盟／黑海官方資料 |
| 小麥 | 美國 Plains、黑海、歐盟、加拿大、澳洲 | 冬季凍害、乾旱、熱浪、收割品質、出口限制 | USDA、NOAA、EU MARS、各國農業／氣象機關 |
| 大豆 | 美國 Midwest、巴西 Mato Grosso／南部、阿根廷 | 種植／開花／結莢期天氣、壓榨、出口與中國需求 | USDA、CONAB、INMET、SMN、海關／壓榨協會 |
| 棉花 | 美國 Texas／Delta、印度 Gujarat／Maharashtra、中國新疆、巴西 | 乾旱、暴雨、蟲害、品質、出口與合纖替代 | USDA/NASS/FAS、IMD、各國棉業官方／協會 |
| 咖啡 | 巴西 Minas Gerais／Espírito Santo／São Paulo／Paraná、越南 Central Highlands、哥倫比亞 | 霜害、乾旱、開花雨、收割雨、銹病、出口物流 | CONAB、INMET、Cecafe、ICO、越南／哥倫比亞官方資料 |
| 可可 | 象牙海岸 Soubré／Daloa／Gagnoa／San-Pédro／Abengourou；迦納 Western／Western North／Ashanti／Ahafo／Central | 暴雨與洪水、黑莢病、乾燥與道路、哈麥丹乾熱、CSSVD、到港與採購 | ICCO、Conseil du Café-Cacao、COCOBOD、SODEXAM／ONPC、GMet／NADMO |
| 棕櫚油 | 馬來西亞 Sabah／Sarawak／Peninsula、印尼 Sumatra／Kalimantan | 洪水、乾旱與滯後單產、勞動力、出口、庫存、生質柴油政策 | MPOB、BMKG、GAPKI、印尼／馬來西亞官方資料 |
| WTI | OPEC+、美國供應、主要航道 | 供應政策、戰爭／航道、需求與庫存；作為糖醇與合纖成本背景 | EIA、OPEC、IEA、主要通訊社 |

### 災害地理檢查

1. 先區分城市／人口災情與農業產區災情。
2. 檢查受災行政區是否與主要產區、集貨道路、乾燥場或出口港重疊。
3. 沒有受災農園面積、果莢／單產損失或到港異常時，不把死亡人數直接換算成減產。
4. 人道災情可以非常嚴重，但農產品重大性分數仍需依產區重疊與傳導證據評估；兩者分開呈現。

## 重大事件評分與深挖模板

每項0–2分，合計10分：

| 面向 | 0分 | 1分 | 2分 |
|---|---|---|---|
| 全球供給權重 | 非主要來源 | 次要產區／物流節點 | 全球主要產國或關鍵出口節點 |
| 空間重疊 | 都市或泛區域、未證實農業重疊 | 部分產區／道路可能受影響 | 核心產區、港口或農園直接受影響 |
| 作物階段 | 非敏感期 | 次要階段或影響不明 | 開花、結莢、灌漿、採收、乾燥等關鍵期 |
| 持續與展望 | 已結束且無後效 | 可能反覆或影響短暫 | 預報延續、病害／物流後效或轉為另一種極端天氣 |
| 證據強度 | 未具名／單一彙整 | 兩個可靠二手來源 | 官方量化＋獨立來源交叉確認 |

- 8–10分：必進前三重點，完整深挖。
- 6–7分：進重大風險雷達並持續追蹤。
- 4–5分：放觀察清單；出現新量化資料再升級。
- 0–3分：背景或雜訊，不進主文。

### 事件深挖必答

1. 事件何時開始、最新更新與預報有效到何時？
2. 受影響地區是否真的重疊主要產區或物流？
3. 當前作物階段是什麼，傳導鏈為何？
4. 已確認損害與分析師情境各是多少？基期、年度與口徑是否一致？
5. 有哪些反證，例如到港量仍強、降雨對土壤有利、需求轉弱？
6. 影響何時可從作況、病害率、出口、到港、研磨或官方產量看到？
7. 什麼條件代表 worsening、easing 或 closed？

標準傳導鏈：`天氣／災害 → 產區與作物階段 → 直接生理／採收／物流影響 → 可量化指標 → 供需平衡 → 價格與反證`。

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

### Pass A：全面發現

- 每個品種至少做一次最近48小時廣搜，查價格之外的 `production crop weather flood drought disease harvest transport port policy export demand`。
- 依產區矩陣加入地名與當地語言關鍵字；暴雨、洪水、山火、颱風、霜害等事件再掃國家氣象／災害機關。
- 查 Active Events 的事件名、地區與下一個確認指標，避免只因今天價格沒動就漏掉。
- 週末／休市的廣掃仍要執行；價格沒更新不代表農業事件停止。

### Pass B：驗證與升級

- 先找A級來源，再用B級來源交叉查。Trading Economics／Barchart只作線索或參考價。
- 看到「分析師估產量」時追姓名／機構、原始報告、基期、作物年度與下修理由；追不到就標未具名。
- 看到「洪水影響農業」時分別搜尋城市災情、產區災情、道路／港口、官方農損與未來降雨；不得只引用同一篇文章的轉載。
- 來源互相矛盾時並列，不用模糊語句消掉衝突。

優先來源：

- 官方：USDA/NASS/FAS、NOAA/CPC、各國氣象與災害機關、ICCO、ICO、MPOB、CFTC、CONAB、UNICA、產業主管機關、港口／到港資料。
- 市場驗證：Reuters、AP、Bloomberg、Dow Jones、具名研究機構、可靠產業媒體。
- 區域媒體：只在它明確引述當地官方或提供可驗證現場資料時使用，並標示媒體轉述。

格式：

`[發佈 MM/DD | 事件始於 YYYY-MM-DD | 更新 YYYY-MM-DD | 狀態 | 證據級別] 事件 — 已確認影響／未確認情境／下一個檢查點`

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

N=0 與 N>=1 使用同一骨架。N=0 可縮短「今天真正改變判斷」段落，但不得省略仍在追蹤的重大事件、覆蓋帳本或資料缺口。

```markdown
**每日農產品晨報｜YYYY-MM-DD（週X）**

> 今日一句話：先講今天真正改變判斷的訊號；若沒有新訊號，講最重要的持續風險與它今天是否變化。

**今日新訊號 N｜持續重大事件 M**

**今天真正改變判斷的三件事**

1. 新事實 → 影響品種 → 為何改變判斷 → 信心。
2. 持續事件今天變糟／持平／緩解之處。
3. 最大反證或尚不能確認的地方。

**重大風險雷達**

| 事件 | 品種／產區 | 狀態 | 分數／證據 | 已確認影響 | 尚未確認 | 下一個檢查點 |
|---|---|---|---|---|---|---|

只列重大性 >= 6 的事件；人道災情與農業影響分開寫。

**今日判斷**

| 品種 | 相較昨日 | 今日方向 | 核心理由 | 已反映程度／信心 |
|---|---|---|---|---|

**接下來最該盯**

| 觀察點 | 為什麼重要 | 判斷門檻 |
|---|---|---|

**附錄收斂版**

1. 價格與有效合約、報價日期。
2. 覆蓋帳本：每個品種六欄的 checked/new/active/unavailable/not-due。
3. 官方報告與漏接狀態。
4. Active Events 完整狀態與結案條件。
5. ENSO/IOD、COT與跨品種背景。
6. 來源、來源衝突、未完成項目與替代資料。
7. 寫入驗證：chat／last-run／Obsidian daily-report 是否一致。
```

## Tracker 寫入規則

所有農產品 tracker 與每日備份只寫 `農產品追蹤/`。

每日備份：
- 路徑：`農產品追蹤/daily-report/YYYY-MM-DD-農產品日報.md`
- frontmatter：`date`, `tags`, `source`, `status: draft`
- 內文保存完整 Step 7 晨報，不可只存摘要。

Tracker section 標題一律用英文：
- `Latest Data`
- `History`
- `Key Background`
- `News Log`
- `Active Events`
- `Sugar Bull Case: Five Factor Dashboard`

`global-monitor-tracker` 的 Active Events 每筆至少保留：事件、品種、地區、狀態、開始日、最新更新、預報有效期、證據級別、重大性分數、已確認損害、未確認情境、反證、下一個檢查點與結案條件。狀態沒有變化時只更新 `latest_checked`，不要每天複製一筆相同事件。

有品種專屬新數據時同步更新對應 tracker，例如 `cocoa-tracker`、`coffee-tracker`、`cotton-tracker`、`palm-oil-tracker`、`crop-progress-tracker`、`wasde-tracker`、`export-sales-tracker`、`drought-monitor-tracker`。不要只把所有事件塞進 global-monitor 而讓品種 tracker 長期過期。

同日 rerun 先更新同一份每日備份與同一日 tracker 區段，不建立 copy 或亂加後綴。
