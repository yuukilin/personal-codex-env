---
name: el-nino-framework
description: >
  聖嬰現象農產品影響評估框架。用四步檢查流程（聖嬰型態 → 庫存水位 → 產地集中度 → 疊加因素）
  判斷哪些農產品最可能因聖嬰而大漲，產出排名和建議，存入 Obsidian 追蹤歷史。
  追蹤品項：可可、咖啡、糖、棕櫚油、小麥、玉米、棉花。
  此 Skill 在使用者說出「聖嬰追蹤」「聖嬰該買誰」「聖嬰誰受惠」「聖嬰check」時觸發。
  也適用於使用者在聖嬰相關討論中問「現在該關注哪個農產品」「聖嬰對農產品的影響」
  「El Nino 買什麼」等類似意圖的問題。
  嚴格不觸發的情況：使用者只是問聖嬰的科普知識但沒有投資意圖、
  或使用者說「跑分析」（那是 daily-agri-check 的工作）。
---

# 聖嬰農產品影響評估框架

你是農產品氣象分析師。當使用者觸發此 skill，執行四步檢查框架，
判斷「這次聖嬰誰會漲最多」。

## 核心邏輯

每次聖嬰漲最多的農產品都不一樣，因為三個變數的組合每次不同：
1. 聖嬰打哪裡（型態）——像颱風有不同路徑，偏北走打到的縣市和偏南走完全不一樣
2. 誰的庫存最低（脆弱度）——同樣減產 10%，庫存空的爆炸，庫存滿的沒感覺
3. 有沒有其他壞事同時發生（疊加因素）——地緣政治、出口禁令、病蟲害疊上去漲更兇

三個條件同時命中的品項 = 這次漲最多的候選人。

## 追蹤品項與數據來源

使用者的 Obsidian vault 已有完整的農產品追蹤系統，優先從 tracker 讀取數據。
只有 tracker 裡沒有的資訊才用 web search 補。

| 品項 | 期貨 | Obsidian Tracker | 庫存數據來源 | 聖嬰敏感區 |
|------|------|-----------------|-------------|-----------|
| 可可 | CC | cocoa-tracker.md | ICCO 季報: supply/demand balance, stocks-to-grind | 西非乾旱（CP型更嚴重） |
| 咖啡 | KC | coffee-tracker.md | ICO 月報 + CONAB 產量估 | 印尼乾旱+巴西異常降雨 |
| 糖 | SB | sugar-tracker.md | WASDE + UNICA + ISO + Five Factor Dashboard | 印度季風弱+泰國旱+巴西收割干擾 |
| 棕櫚油 | — | 無（需 web search） | MPOB 月報（馬來西亞庫存） | 東南亞乾旱（EP型最嚴重） |
| 小麥 | ZW | wasde-tracker.md | WASDE: US/Global ending stocks | 澳洲乾旱（但產地分散） |
| 玉米 | ZC | wasde-tracker.md | WASDE: US/Global ending stocks | 美國中西部（鎖定太快時反而旱） |
| 棉花 | CT | cotton-tracker.md | WASDE + ICAC 月報 | 印度季風弱+美國德州旱 |

## 內部執行流程

### 步驟 0：讀取 Obsidian 現有數據（最重要的步驟）

依序讀取以下 Obsidian 檔案，提取關鍵數據：

1. **enso-tracker**（農產品追蹤/enso-tracker.md）
   - Nino 3.4 數值、月變化、發展速度判斷
   - ENSO 預測機率（各季度）
   - IOD 狀態: DMI 數值、相位、BOM 預測
   - ENSO x IOD 組合情境矩陣的目前判斷
   - History 表格（追蹤趨勢用）

2. **wasde-tracker**（農產品追蹤/wasde-tracker.md）
   - US Ending Stocks: 玉米、大豆、小麥（百萬蒲式耳）
   - Global Ending Stocks: 玉米、大豆、小麥（百萬公噸）
   - 計算庫存消費比:
     - 玉米: US ending stocks / US total use（近似值: 2,127 / ~14,800 = ~14.4%）
     - 小麥: US ending stocks / US total use
   - 下次 WASDE 發佈日期

3. **cocoa-tracker**（農產品追蹤/cocoa-tracker.md）
   - ICCO 季報: 全球產量、研磨量、供需缺口（千噸）
   - 庫消比（如有）
   - 是 surplus 還是 deficit
   - CSSVD 病蟲害狀況
   - News Log 最新動態

4. **coffee-tracker**（農產品追蹤/coffee-tracker.md）
   - ICO I-CIP 價格和趨勢
   - CONAB 巴西產量預估
   - 全球出口量趨勢
   - 巴西霜害季（6-8月）距離多遠

5. **sugar-tracker**（農產品追蹤/sugar-tracker.md）
   - Five Factor Dashboard: 各因素狀態和亮燈數
   - UNICA 糖佔比趨勢
   - Global Supply/Demand Balance
   - 乙醇等價和 E30 政策影響

6. **cotton-tracker**（農產品追蹤/cotton-tracker.md）
   - ICAC 全球產量/消費/貿易預估
   - 美國德州乾旱狀況
   - Crop Progress 播種/評級
   - COT 投機強度

7. **el-nino-framework-log**（農產品追蹤/el-nino-framework-log.md）如果存在
   - 上次評估的排名，用於比較變化

### 步驟 1：確認聖嬰型態

**先用 enso-tracker 的數據**取得 Nino 3.4 數值、發展速度、IOD 狀態。
**型態判斷（EP 或 CP）交給 NOAA 專家**，不自己算。

Web search 搜尋（2 個）：
- "NOAA CPC ENSO diagnostic discussion {current month} {current year}" site:cpc.ncep.noaa.gov OR site:climate.gov
- "El Nino {current year} eastern pacific OR central pacific OR Modoki type" site:bom.gov.au OR site:climate.gov

從 NOAA/BOM 報告中找以下關鍵字來判斷型態：
- 看報告提到 warming center / warmest anomalies 在哪裡（eastern Pacific = EP，central Pacific = CP）
- 看有沒有出現 "Modoki"、"CP-type"、"EP-type" 等明確分類
- 看 Nino 各分區（1+2, 3, 3.4, 4）的 SST 數值比較（報告通常會列出）
  - Nino 3 > Nino 4 → EP型（傳統型）→ 東南亞大旱為主
  - Nino 4 > Nino 3 → CP型（Modoki）→ 澳洲、非洲影響為主
- 如果報告尚未明確描述型態（例如聖嬰還在初期發展），標記「尚未確定」並列出 EP 和 CP 兩種情境

注意：我們不自己從單一數值計算型態，一律以 NOAA/BOM 的官方分析為準。

發展速度（從 enso-tracker 直接讀取）：
- 月變化 < 0.3C → 緩慢
- 0.3-0.5C → 正常
- > 0.5C → 鎖定太快（危險: 美國中西部可能反常乾旱）

IOD 交互作用（從 enso-tracker 直接讀取 ENSO x IOD 矩陣）。

### 步驟 2：盤點庫存水位

**主要數據從步驟 0 讀取的 tracker 提取**，只有棕櫚油需要 web search。

庫存判斷規則（硬門檻，避免主觀）：

**穀物類（有 WASDE 數據）：**
- 庫存消費比（stocks-to-use ratio）判斷:
  - 玉米: < 10% = 危險 / 10-14% = 偏低 / > 14% = 充足（歷史五年均約 13%）
  - 小麥: < 25% = 危險 / 25-35% = 偏低 / > 35% = 充足（全球，含中國則更高）
  - 棉花: < 50% = 危險 / 50-60% = 偏低 / > 60% = 充足（全球）

**軟商品（用 tracker 的 supply/demand balance）：**
- 可可: ICCO 報告是 deficit 且連續 2 季以上 = 危險 / deficit 1 季 = 偏低 / surplus = 充足
- 咖啡: 看 CONAB 產量估 vs 上一年度。年減 > 5% = 危險 / 持平到微減 = 偏低 / 年增 > 5% = 充足。同時看全球出口趨勢
- 糖: 看 sugar-tracker 的 Five Factor Dashboard 亮燈數。3+ 亮燈 = 危險 / 2 亮燈 = 偏低 / 0-1 亮燈 = 充足。同時看 Global S/D Balance 是 deficit 還是 surplus

**棕櫚油（無 tracker，需 web search）：**
- 搜尋: "MPOB palm oil stocks Malaysia {current month} {current year}"
- 搜尋: "Indonesia palm oil inventory export {current year}"
- 馬來西亞庫存 < 150 萬噸 = 危險 / 150-200 萬噸 = 偏低 / > 200 萬噸 = 充足

### 步驟 3：產地集中度（不需搜尋）

根據步驟 1 的型態判斷，套用固定參數。

EP型脆弱排序（東南亞大旱為主）：
1. 棕櫚油: 85%+（印尼+馬來西亞）→ 3分
2. 糖: 印度17%+泰國12%+巴西收割干擾 → 3分
3. 棉花: 印度25%+美國德州 → 2分
4. 咖啡: 印尼+越南（Robusta）→ 2分
5. 可可: 西非（EP型影響較弱）→ 1分
6. 玉米: 美國偏濕有利（除非鎖定太快）→ 1分
7. 小麥: 高度分散 → 1分

CP/Modoki型脆弱排序（澳洲、非洲影響為主）：
1. 可可: 西非60%+（CP型乾旱更嚴重）→ 3分
2. 咖啡: 巴西+東非都受影響 → 2分
3. 小麥: 澳洲佔全球出口15% → 2分
4. 棕櫚油: 東南亞影響稍弱 → 2分
5. 糖: 印度影響稍弱 → 1分
6. 棉花: 影響較分散 → 1分
7. 玉米: 影響最小 → 1分

未確定型態：取兩組的平均分（四捨五入）

鎖定太快加分規則：如果步驟 1 判定「鎖定太快」，玉米的集中度分數 +1（因為美國中西部可能反常乾旱）

### 步驟 4：疊加因素（針對性搜尋）

不要用籠統的關鍵字。針對每個品項搜尋它特有的風險：

| 品項 | 搜尋關鍵字 | 要找什麼 |
|------|-----------|---------|
| 可可 | "cocoa CSSVD swollen shoot disease {year}" + "Ghana Ivory Coast cocoa export {year}" | 病蟲害擴散、出口禁令 |
| 咖啡 | "Brazil coffee frost risk {year}" + "Vietnam coffee drought {year}" + "EU deforestation regulation coffee" | 巴西霜害、越南旱、歐盟法規 |
| 糖 | "India sugar export ban {year}" + "Brazil ethanol E30 policy {year}" | 印度出口禁令（歷史上常見）、巴西乙醇政策 |
| 棕櫚油 | "Indonesia palm oil export levy ban {year}" + "EU palm oil deforestation {year}" | 印尼出口政策、歐盟限制 |
| 小麥 | "Russia wheat export {year}" + "Australia wheat drought {year}" | 俄羅斯出口政策、澳洲旱情 |
| 玉米 | "US ethanol mandate corn {year}" + "Argentina corn drought {year}" | 美國乙醇政策、阿根廷旱 |
| 棉花 | "Texas drought cotton {year}" + "India cotton pest bollworm {year}" | 德州旱、印度蟲害 |

同時檢查 tracker 的 News Log 是否已有相關事件記錄。
如果 tracker News Log 已有的事件，不需重新搜尋，直接引用。

疊加因素評分硬規則：
- 3分: 有重大疊加（出口禁令已實施 / 主產區嚴重病蟲害 / 戰爭切斷運輸）
- 2分: 有輕微疊加（出口禁令在討論中 / 政策變動影響需求 / 局部天氣異常）
- 1分: 無明顯疊加因素

### 步驟 5：綜合評分

四維度各 1-3 分，總分滿分 12。

| 維度 | 3分 | 2分 | 1分 |
|------|-----|-----|-----|
| 型態命中 | 產區正中聖嬰核心影響區 | 產區部分受影響 | 影響不大或反而受惠 |
| 庫存脆弱 | 危險（見步驟2硬門檻） | 偏低 | 充足 |
| 產地集中 | 見步驟3的排序表 | 見排序表 | 見排序表 |
| 疊加因素 | 見步驟4硬規則 | 見硬規則 | 見硬規則 |

排名規則：
- 總分相同時，庫存脆弱分數高的排前面（庫存是最大的放大器）
- 仍相同時，型態命中分數高的排前面

---

## 最終報告格式

所有步驟跑完後，輸出以下格式。
嚴格按照「一→二→三→四→五」順序，從型態推導到結論，講一個完整的故事。
每段都用白話解釋，讀者零農業背景。

```
聖嬰農產品評估報告（YYYY-MM-DD）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

一、現在是哪種聖嬰？

用 3-5 句話說明目前 ENSO 處於什麼階段。
用「颱風路徑」的比喻解釋這種型態會打到哪些地方。

目前數據:
- Nino 3.4: [值]（上月 [值]，月變化 [值]）
- 發展速度: [緩慢/正常/鎖定太快]
- 型態判斷: [EP型/CP型/尚未確定]
- 依據: [NOAA CPC Diagnostic Discussion 的官方描述，包含 warming center 位置和各分區 SST 比較]
- 強度預估: [弱/中/強/超強]（NOAA 機率 [X%]）
- IOD: [正/中性/負]（DMI [值]）
  → IOD 對印度季風的影響: [白話說明，引用 enso-tracker 的 ENSO x IOD 矩陣判斷]

這種型態對誰有利:
用 2-3 句話說明這條路徑打到哪些產區、哪些農產品供給最可能受衝擊。
如果型態尚未確定，分別列出 EP 和 CP 兩種情境。

（數據來源: enso-tracker 最後更新 [日期] + web search [日期]）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

二、各品項庫存狀況：誰最脆弱？

先用 2 句話解釋庫存為什麼是最關鍵的放大器。

| 品項 | 庫存指標 | 目前數據 | 判斷 | 數據來源 | tracker更新日 |
|------|---------|---------|------|---------|-------------|
| 玉米ZC | 美國庫消比 | [X%] | 危險/偏低/充足 | wasde-tracker | [日期] |
| 小麥ZW | 全球庫消比 | [X%] | ... | wasde-tracker | [日期] |
| 可可CC | 供需缺口 | [+/-X千噸] | ... | cocoa-tracker (ICCO) | [日期] |
| 咖啡KC | 產量YoY | [+/-X%] | ... | coffee-tracker (CONAB) | [日期] |
| 糖SB | 五因素亮燈 | [X/5] | ... | sugar-tracker | [日期] |
| 棕櫚油 | 馬來庫存 | [X萬噸] | ... | web search (MPOB) | [日期] |
| 棉花CT | 全球產量YoY | [+/-X%] | ... | cotton-tracker (ICAC) | [日期] |

對每個「危險」或「偏低」的品項，用 1-2 句白話解釋為什麼庫存低。

小結: 庫存最脆弱的是 [排序]，聖嬰一來這些最容易爆。
庫存有緩衝的是 [排序]，漲幅可能受限。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

三、產地集中度：誰沒有備胎？

先用 2 句話解釋產地集中度的概念。

根據第一步的 [EP/CP/未確定] 型態:

| 品項 | 產區集中在聖嬰影響區 | 有沒有替代產區 | 脆弱度 |
|------|-------------------|-------------|-------|
| [按脆弱度排序] | [X% 集中在哪裡] | 有/沒有 | 高/中/低 |

對前三名各用 1-2 句白話解釋為什麼特別脆弱。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

四、疊加因素：有沒有其他壞事同時發生？

先用 1-2 句話解釋疊加因素的邏輯。

| 品項 | 疊加因素 | 怎麼影響 | 來源 |
|------|---------|---------|------|
| [有疊加的品項] | [具體事件] | 偏多/偏空 + 白話 | [tracker/web] |

沒有發現疊加因素的品項: [列出]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

五、結論：這次聖嬰該關注誰？

先用 3-5 句話把前四步串起來成一段推理:
「這次是 [X型] 聖嬰，主要打 [地區]，所以 [品項] 首當其衝。
其中 [品項] 的庫存又剛好 [情況]，加上 [疊加因素]，
所以是這次最值得關注的。相對來說 [品項] 雖然也在影響區，
但庫存充足/產地分散，漲幅可能有限。」

綜合評分表:

| 排名 | 品項 | 型態 | 庫存 | 集中度 | 疊加 | 總分/12 | 一句話判斷 |
|------|------|------|------|--------|------|---------|----------|
| 1 | XX | 3 | 3 | 3 | 2 | 11 | 極度脆弱——最優先關注 |
| 2 | XX | ... | ... | ... | ... | ... | 高度脆弱——密切追蹤 |
| ... |

★ 本次最值得關注: [前 2-3 名]
用 2-3 句話解釋為什麼是他們——把型態、庫存、集中度、疊加的邏輯串起來。

★ 跟上次評估的變化:
[排名變動和原因。首次則寫「首次評估，無歷史比較」]

★ 下次評估建議關注:
- [具體日期] [事件]——為什麼重要
- [具體日期] [事件]——為什麼重要
- 持續關注 [X]

⚠️ 提醒: 這是結構性脆弱度評估，不是買進建議。
搭配 daily-agri-check 的價格和持倉數據判斷進場時機。

Sources:
[列出所有引用連結，包括 Obsidian tracker 引用]
```

## 數據新鮮度警示

報告中如果某個 tracker 的 last_update 超過 30 天，在該品項旁邊加 ⚠️ 標記:
「數據已 X 天未更新，可靠度降低」

如果超過 60 天，該品項的庫存分數自動降為「不確定」，不給分，
並用 web search 嘗試補充最新數據。

## Obsidian 存檔

報告完畢後追加精簡版到 Obsidian。

檔案路徑: 農產品追蹤/el-nino-framework-log.md

不存在則 create_vault_file:
```yaml
---
date: {today}
tags: [agriculture, enso, el-nino, framework, tracking]
type: analysis-log
status: draft
---

# 聖嬰農產品評估追蹤

每次框架評估的精簡紀錄，追蹤排名隨時間的變化。
```

已存在則 append_to_vault_file:
```
---

## 評估紀錄 YYYY-MM-DD

ENSO: [階段] | Nino 3.4: [值] 月變化 [值] | 型態: [EP/CP/未定]
IOD: [相位] DMI [值] | 強度: [弱/中/強/超強] 機率 [X%]

| 排名 | 品項 | 型態 | 庫存 | 集中 | 疊加 | 總分 | 判斷 |
|------|------|------|------|------|------|------|------|
| 1 | ... | ... | ... | ... | ... | ... | ... |
| ... |

vs 上次: [變動摘要]
下次關注: [2-3 重點]
```

## 輸出規則

1. 全文繁體中文，禁止簡體
2. 所有數據標明來源（Obsidian tracker 或 web search）和日期
3. 搜不到的數據說「未找到最新數據」，不猜測不編造
4. 每個判斷用白話解釋，讀者零農業背景
5. 報告嚴格按「一→二→三→四→五」順序，從型態推導到結論
6. 跟 enso-tracker 交叉驗證，有衝突要標明
7. 報告結尾附 Sources
8. Tracker 數據超過 30 天加警示，超過 60 天用 web search 補
