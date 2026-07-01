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
