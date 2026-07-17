# 元件供需雷達 memory

- 2026-06-30：建立 100 分版追蹤設計。核心來源限縮為 Future Electronics Market Conditions Report 與華強電子網。
- Future 實測：landing page 可抓，PDF 可抓；PDF `content-length` 約 16,007,946 bytes，`Last-Modified` 為 2026-06-15 GMT；分類頁有獨立 JPG，適合逐品類 OCR/視覺抽取。
- 華強電子網實測：烽火指數首頁可直接抽出最新四週週期與榜單；雲報價首頁可抽今日熱料報價，但必須讀 hidden input 屬性，不能直接讀畫面混淆數字。
- 華強商城降為備援，不列核心比對來源。
- 2026-06-30 debug：已實跑 `probe_sources.py --date 2026-06-30-debug --download-category-images`。source-probe snapshot 成功寫入 `snapshots/2026-06-30-debug-source-probe.json`，Future 10 個分類 JPG 與 OCR txt 都成功產生。正確 schema 是 `source_health`、`future`、`hqew.fire_index.model_heat_rank`、`hqew.cloud_quote.hot_quote_rows`；不要讀舊草稿欄位。
- 2026-06-30 debug：Future 本期 `Last updated` 為 June 15th, 2026；華強電子網烽火指數最新週期為 2026-06-22 到 2026-06-28。這次是 baseline，不能宣稱週變化。
- 2026-06-30 debug：本期正式報告保存到 automation reports，Obsidian 只需保留精簡追蹤資訊。不要每週新增完整 source note，避免 vault 堆積低價值舊報告。
- 2026-06-30 優化：新增 `scripts/generate_report.py`，固定從 source-probe snapshot 生成 summary JSON、Markdown 報告，並更新 Obsidian 時間軸；若 Future JPG 已下載但 OCR txt 缺失，且本機有 tesseract，會自動補 OCR。之後 automation 應依序跑 `probe_sources.py` 與 `generate_report.py`，避免手工讀欄位造成 schema 錯誤。
- 2026-06-30 使用者回饋：報告英文太多、太像工程追蹤表。已改成業外投資研究版：主體先講哪些品類缺貨更緊、價格/成本壓力、交期拉長與可追投資題材；料號前五改放附錄並加白話說明。之後報告應少英文，能翻中文就翻中文。
- 2026-07-01 使用者回饋：這種追蹤有時效性，舊完整報告沒什麼閱讀價值，只是比對用。已改成 Obsidian 單一時間軸：`2 Sources/Research/2026-07-01-元件供需雷達-Future-華強電子網-時間軸.md`。完整週報、raw、summary 留在 automation；Obsidian 只保留最新狀態與每週一列。
- 2026-07-01 優化：時間軸新增去重邏輯。若 Future 版本與華強最新週期都和既有時間軸列相同，代表來源沒有新資料，只更新最新狀態與報告路徑，不新增時間軸列。
- 2026-07-01 優化：新增「跟上一期比」結構化檢查。`generate_report.py` 會找上一期 source-probe，檢查 Future 版本、華強週期、Future 分類圖片 hash、華強品類榜單、熱門型號與報價樣本數；來源未更新時需明確寫「僅例行檢查」，不可製造新趨勢。

下次追蹤重點：

- 先跑 `scripts/probe_sources.py` 建立來源健康檢查與 baseline。
- Future 以分類 JPG 為主，PDF 為完整歸檔與 fallback。
- 華強電子網以烽火指數為主，雲報價只做熱門型號抽樣。
- 報告產出前先驗 schema 欄位與 raw/OCR 檔案數；若欄位讀不到，先修抽取邏輯，不要輸出空表。
- 每次輸出都要更新同一份 Obsidian 時間軸，並連結到既有 theme：`[[Theme-semiconductor-cycle]]`、`[[Theme-passive-components-cycle]]`、`[[Theme-ai-infrastructure]]`、`[[Theme-ai-datacenter-power]]`。不要每週新增完整報告筆記。
- 固定使用 `scripts/generate_report.py --run-id YYYY-MM-DD` 產報告；debug run 用 `--run-id YYYY-MM-DD-debug --report-date YYYY-MM-DD`。
- 報告主體先講題材，不先列料號；料號只作補充。使用者不應被要求自己理解 STM32、W25Q128 這些型號代表什麼。

## 2026-07-14 執行紀錄

- 執行時間：2026-07-14 11:54:25–12:01:37（Asia/Taipei）。
- 來源健康：Future 官方頁、完整 PDF、10/10 分類頁全部成功；10 張分類圖片與 10 份圖片文字辨識檔齊全。華強烽火指數四類榜單成功，雲報價 hidden 欄位取得 20 筆。
- Future 仍為 June 15th, 2026 版本，PDF 共 16,007,946 bytes，完整檔已保存於 `runs/2026-07-14/raw/future_market_conditions_report.pdf`，SHA-256 為 `d31b160ff78340585bc134fc7f190b53ea6b04f48c7862d1e99a045241c7a4ca`。10 類圖片相對上一份有效快照均未變。
- 華強最新週期更新為 2026-07-06 到 2026-07-12。上一份有效快照是 `2026-07-01-audit-source-probe.json`（週期 2026-06-22 到 2026-06-28）；2026-07-07 automation 雖有執行紀錄，但沒有留下有效 snapshot，因此本次不是緊鄰週快照。
- 華強本期品類熱度：儲存IC +2.89%、電源IC +2.08%、邏輯IC +2.06%、貼片電容 +34.14%、運放IC +5.43%。飆升榜另見陶瓷電容 +43.16%、鉭電容 +42.94%。
- 與上次有效快照相比，儲存IC、電源IC、邏輯IC與運放IC排名大致穩定，但各自的「較上期」增幅縮小 39.18、40.28、34.96、34.75 個百分點；貼片電容升一名至第 4，增幅差為 -5.92 個百分點。這是兩次快照各自週增幅的差，不是價格跌幅。
- 本期判讀：只有華強更新，能視為現貨市場新快訊號；Future 正式通路未更新，不能視為兩來源共同確認的整體新趨勢。前三大追蹤題材為電源/類比 75 分、被動元件 73 分、記憶體/儲存 72 分。
- 背離：STM32 佔華強型號熱度前五全部席次，單週增幅 35.09%–128.57%，但 Future 高階晶片圖片尚未逐列人工校正；連接器只有 Future 成本/交期訊號，華強前五品類未驗證。
- 本期程式修正：`probe_sources.py` 改為完整下載並歸檔 Future PDF；`generate_report.py` 補上華強賣家備註的繁體中文/台灣用語轉換，並在只有單邊來源更新時明確限制趨勢解讀。比較表欄名也改為「較上次快照的週增幅差（百分點）」，避免誤認為價格變化。
- 已更新完整報告、summary JSON、source-probe、raw 與同一份 Obsidian 時間軸；時間軸只有一列 2026-07-14，沒有新增 dated 完整報告筆記。
- 下次優先檢查：Future 是否換版；貼片/陶瓷/鉭電容能否連續上榜；STM32 是否仍由現貨單邊轉熱；若沒有 7 天前有效 snapshot，報告必須明寫比較區間缺口。

## 2026-07-14 同日複查

- 執行時間：2026-07-14 16:32:23–16:40:39（Asia/Taipei）。
- 已重新連線抓取，不沿用上午快照：Future 仍為 June 15th, 2026，完整 PDF SHA-256 仍為 `d31b160ff78340585bc134fc7f190b53ea6b04f48c7862d1e99a045241c7a4ca`；10/10 分類頁、10 張分類圖片與 10 份圖片文字辨識檔完整。
- 華強最新週期仍為 2026-07-06 到 2026-07-12；型號、品牌、品類與飆升榜均成功，雲報價 hidden 欄位仍取得 20 筆。
- 本次為同日重新抓取，兩個核心來源均未較上午更新，因此本期不應解讀為新趨勢；沿用上午的三大追蹤題材：電源/類比 75 分、被動元件 73 分、記憶體/儲存 72 分。
- 修正 `scripts/generate_report.py` 的同日重跑判斷：若 Obsidian 當日時間軸已有相同 Future 版本與華強週期，summary 會標記 `source_changed: false`、`same_day_rerun: true`，報告不再重複宣稱新資料；既有當日時間軸列會重寫為本次複查狀態，不會重複新增。
- 已覆寫更新本日完整報告、summary JSON、source-probe 與 raw；Obsidian 只更新既有單一時間軸筆記，未新增 dated 完整報告。經已驗證登入有效的 Obsidian MCP 回讀，7 月 14 日只有一列，狀態為「來源未更新，僅例行檢查」，四個既有 Theme 連結均有效。
- 下次優先檢查：Future 是否換版、華強是否進入 2026-07-13 之後的新週期、被動元件熱度能否連續、STM32 是否獲正式通路驗證。
