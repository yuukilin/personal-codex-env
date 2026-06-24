# Merge Report 2026-06-24

來源分支：`merge-from-other-mac`

incoming 快照：`incoming/-20260623-181635`

## 已合併

### 新增 skill

- `skills/english-echo-coach/`

### 吸收另一台 Mac 的小幅更新

- `skills/investanchors-scraper/SKILL.md`
  - 加入最近 10 篇 lookback。
  - 加入 hash 去重與舊文改版判斷。
- `skills/opus-analysis/SKILL.md`
  - 將日報分析納入範圍調整為最近 60 天，待重分析區段不受限制。
- `skills/report-intake/SKILL.md`
  - 加入定錨舊文改版例外，避免 hash 不同的舊文被當成已處理而跳過。

### 新增 automation 模板

- `automations-templates/english-voice-lesson/automation.toml`
  - 由另一台 Mac 的 `automation` 模板改名而來。
  - `id` 改為 `english-voice-lesson`。
  - `status` 先設為 `PAUSED`，避免兩台 Mac 同時跑。

## 保留目前主版本

- `skills/eln-report/SKILL.md`
  - 另一台 Mac 版本是大幅改寫，且仍有 `Claude` 字樣。
  - 目前主版本是 Codex 版 ELN 寫作引擎，保留較安全。
  - 若之後要改字數規則，可單獨調整，不在本次融合中整份覆蓋。

## 未採用

- incoming 的 `automations-templates/automation/` 原資料夾名太模糊，已改成 `english-voice-lesson/`。
- incoming 缺少本機已有的 `skills/market-news-short-commentary/`，主版本保留。
- incoming 缺少本機已有的 `agents-skills/investanchors-scraper/`，主版本保留。

## 下一步

1. 驗證所有 `SKILL.md` frontmatter。
2. 做敏感資訊掃描。
3. commit 並 push 到 `main`。
