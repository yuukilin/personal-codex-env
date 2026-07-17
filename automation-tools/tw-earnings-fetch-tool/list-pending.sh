#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
REPO="${TW_EARNINGS_REPO:-${HOME}/Desktop/python/investment-data}"
AUTOMATION_DIR="${TW_EARNINGS_AUTO_DIR:-${CODEX_HOME}/automations/tw-earnings-fetch}"
LAST_RUN="$AUTOMATION_DIR/last-run.md"
MANUAL_RESOLUTIONS="${TW_EARNINGS_MANUAL_RESOLUTIONS:-${AUTOMATION_DIR}/manual-resolutions.json}"
SEED_RESOLUTIONS="${SCRIPT_DIR}/manual-resolutions.seed.json"
VAULT="${OBSIDIAN_VAULT_PATH:-${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/卡片筆記盒模板}"
REMOTE_PATH="sources/tw-earnings/pending-list.json"
REMOTE_REF="origin/main:$REMOTE_PATH"
NOW="$(TZ=Asia/Taipei date '+%Y-%m-%d %H:%M:%S')"
REMOTE_JSON="$(mktemp -t tw-earnings-pending.XXXXXX)"
FETCH_LOG="$(mktemp -t tw-earnings-fetch.XXXXXX)"

cleanup() {
  rm -f "$REMOTE_JSON" "$FETCH_LOG"
}
trap cleanup EXIT

mkdir -p "$AUTOMATION_DIR"

repo_status() {
  local branch counts ahead behind
  branch="$(git -C "$REPO" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached')"
  counts="$(git -C "$REPO" rev-list --left-right --count HEAD...origin/main 2>/dev/null || true)"
  if [[ "$counts" =~ ^([0-9]+)[[:space:]]+([0-9]+)$ ]]; then
    ahead="${BASH_REMATCH[1]}"
    behind="${BASH_REMATCH[2]}"
    printf '%s...origin/main [ahead %s; behind %s; working tree intentionally not scanned]\n' \
      "$branch" "$ahead" "$behind"
  else
    printf '%s [origin/main comparison unavailable; working tree intentionally not scanned]\n' \
      "$branch"
  fi
}

write_failure() {
  local reason="$1"
  local details="$2"
  local status
  status="$(repo_status)"
  {
    printf '# tw-earnings-fetch last run\n\n'
    printf -- '- 執行時間（Asia/Taipei）：%s\n' "$NOW"
    printf -- '- 結果：失敗；已停止，未使用本機 stale pending-list。\n'
    printf -- '- 原因：%s\n' "$reason"
    printf -- '- 範圍：只讀遠端與本機處理痕跡；未爬蟲、未開瀏覽器、未抓逐字稿、未跑 DeepSeek、未寫 Obsidian。\n\n'
    printf '## 失敗摘要\n\n'
    printf '```text\n%s\n```\n\n' "$details"
    printf '## Git 狀態\n\n'
    printf '```text\n%s\n```\n\n' "$status"
    printf '## 自我檢查\n\n'
    printf -- '- 關鍵事實是否有來源：有，來自 git fetch／git show 的實際錯誤。\n'
    printf -- '- 是否使用 stale fallback：否。\n'
  } > "$LAST_RUN"
}

for bin in git jq python3; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    write_failure "缺少必要工具：$bin" "請先安裝或修復 $bin，未繼續讀取待抓清單。"
    exit 1
  fi
done

if [[ ! -f "$MANUAL_RESOLUTIONS" ]]; then
  write_failure "runtime manual-resolutions.json 不存在，已 fail closed" "$MANUAL_RESOLUTIONS\n請由 $SEED_RESOLUTIONS 初始化缺少的 runtime 檔；不得用空清單取代或覆寫既有 runtime。"
  exit 1
fi

if ! jq -e '
  def resolution_items:
    if type == "array" then .
    elif type == "object" and (.resolutions | type == "array") then .resolutions
    else error("manual resolutions must be an array or an object with resolutions array")
    end;
  resolution_items as $items
  | ($items | all(.[]; (.id | type == "string") and (.id | length > 0)))
    and ([$items[].id] | length == (unique | length))
' "$MANUAL_RESOLUTIONS" >/dev/null 2>"$FETCH_LOG"; then
  write_failure "runtime manual-resolutions.json 格式錯誤或含重複 ID，已 fail closed" "$(sed -n '1,120p' "$FETCH_LOG")"
  exit 1
fi

if [[ ! -d "$REPO/.git" ]]; then
  write_failure "investment-data repo 不存在或不是 Git repo" "$REPO"
  exit 1
fi

if ! GIT_TERMINAL_PROMPT=0 git -C "$REPO" fetch origin >"$FETCH_LOG" 2>&1; then
  if [[ "${TW_EARNINGS_ALLOW_CACHED_ORIGIN:-0}" != "1" ]]; then
    write_failure "git fetch origin 失敗" "$(sed -n '1,120p' "$FETCH_LOG")"
    exit 1
  fi
  FETCH_MODE="cached origin（使用者明確允許；可能 stale）"
else
  FETCH_MODE="origin/main 已即時 fetch"
fi

if ! git -C "$REPO" show "$REMOTE_REF" > "$REMOTE_JSON" 2>"$FETCH_LOG"; then
  write_failure "無法讀取 $REMOTE_REF" "$(sed -n '1,120p' "$FETCH_LOG")"
  exit 1
fi

if ! jq -e 'type == "array"' "$REMOTE_JSON" >/dev/null 2>"$FETCH_LOG"; then
  write_failure "遠端 pending-list.json 格式不是 JSON array" "$(sed -n '1,120p' "$FETCH_LOG")"
  exit 1
fi

ORIGIN_SHA="$(git -C "$REPO" rev-parse --short=12 origin/main 2>/dev/null || true)"
STATUS="$(repo_status)"

/usr/bin/env python3 - \
  "$REMOTE_JSON" \
  "$LAST_RUN" \
  "$REPO" \
  "$VAULT" \
  "$MANUAL_RESOLUTIONS" \
  "$NOW" \
  "$FETCH_MODE" \
  "$STATUS" \
  "$ORIGIN_SHA" <<'PY'
import json
import sys
from collections import Counter
from pathlib import Path

(
    remote_json,
    last_run,
    repo_root,
    vault_root,
    manual_resolutions,
    now,
    fetch_mode,
    repo_status,
    origin_sha,
) = sys.argv[1:]

repo = Path(repo_root)
vault = Path(vault_root)
with open(remote_json, "r", encoding="utf-8") as handle:
    items = json.load(handle)

status_counts = Counter(str(item.get("status", "unknown")) for item in items)
candidates = [
    item for item in items
    if item.get("status") in {"pending", "fetch_failed"}
]
candidates.sort(key=lambda item: (
    str(item.get("market", "")),
    str(item.get("audio_date", "")),
    str(item.get("stock_number", "")),
    str(item.get("stock_name", "")),
))

manual_path = Path(manual_resolutions)
manual_data = json.loads(manual_path.read_text(encoding="utf-8"))
if isinstance(manual_data, list):
    manual_items = manual_data
elif isinstance(manual_data, dict) and isinstance(manual_data.get("resolutions"), list):
    manual_items = manual_data["resolutions"]
else:
    raise ValueError("manual-resolutions.json must be an array or an object with resolutions array")

manual_ids = [str(item.get("id", "")) for item in manual_items if isinstance(item, dict)]
if not all(manual_ids) or len(manual_ids) != len(set(manual_ids)):
    raise ValueError("manual-resolutions.json contains empty or duplicate ids")

def manual_reason(item_id):
    def walk(value):
        if isinstance(value, dict):
            if str(value.get("id", "")) == item_id:
                for key in ("done_reason", "reason", "resolution", "note"):
                    if value.get(key):
                        return str(value[key])
                return "人工略過紀錄"
            if item_id in value:
                nested = value[item_id]
                if isinstance(nested, dict):
                    for key in ("done_reason", "reason", "resolution", "note"):
                        if nested.get(key):
                            return str(nested[key])
                if nested:
                    return str(nested)
            for nested in value.values():
                result = walk(nested)
                if result:
                    return result
        elif isinstance(value, list):
            for nested in value:
                result = walk(nested)
                if result:
                    return result
        return None

    return walk(manual_data)

search_roots = [
    (repo / "sources/tw-earnings/raw", "raw"),
    (repo / "output/pending", "output/pending"),
    (repo / "output/archive", "output/archive"),
    (vault / "2 Sources/TW-Earnings", "Obsidian TW-Earnings"),
    (vault / "2 Sources/US-Earnings", "Obsidian US-Earnings"),
]

file_indexes = {}
for root, label in search_roots:
    if root.exists():
        file_indexes[label] = [path.name for path in root.iterdir() if path.is_file()]
    else:
        file_indexes[label] = []

def processed_reasons(item):
    date = str(item.get("audio_date", ""))
    code = str(item.get("stock_number", ""))
    if not date or not code:
        return []
    prefix = f"{date}-{code}-"
    reasons = []
    for label, names in file_indexes.items():
        if any(name.startswith(prefix) for name in names):
            reasons.append(label)
    return reasons

pending = []
processed = []
skipped = []
for item in candidates:
    item_id = str(item.get("id", ""))
    reason = manual_reason(item_id)
    if reason:
        skipped.append((item, reason))
        continue
    reasons = processed_reasons(item)
    if reasons:
        processed.append((item, "、".join(reasons)))
    else:
        pending.append(item)

def esc(value):
    return str(value or "-").replace("|", "\\|").replace("\n", " ")

def table_header(include_reason=False):
    if include_reason:
        return [
            "| # | 市場 | 公司 | 代號 | 日期 | 遠端狀態 | 排除原因 | AlphaMemo |",
            "|---:|---|---|---|---|---|---|---|",
        ]
    return [
        "| # | 市場 | 公司 | 代號 | 日期 | 狀態 | AlphaMemo |",
        "|---:|---|---|---|---|---|---|",
    ]

def item_row(index, item, reason=None):
    url = f"https://www.alphamemo.ai/free-transcripts/{item.get('id', '')}"
    fields = [
        str(index),
        esc(item.get("market")),
        esc(item.get("stock_name")),
        esc(item.get("stock_number")),
        esc(item.get("audio_date")),
        esc(item.get("status")),
    ]
    if reason is not None:
        fields.append(esc(reason))
    fields.append(f"[開啟]({url})")
    return "| " + " | ".join(fields) + " |"

lines = [
    "# tw-earnings-fetch last run",
    "",
    f"- 執行時間（Asia/Taipei）：{now}",
    "- 任務：台股／國際公司法說會待抓取清單通知。",
    f"- 遠端來源：`origin/main:sources/tw-earnings/pending-list.json`（`{origin_sha or 'unknown'}`）。",
    f"- 讀取模式：{fetch_mode}。",
    "- 範圍：只讀遠端與本機處理痕跡；未爬蟲、未開瀏覽器、未抓逐字稿、未跑 DeepSeek、未寫 Obsidian。",
    f"- 遠端總數：{len(items)}；候選 pending／fetch_failed：{len(candidates)}。",
    f"- 分桶：真正待抓 {len(pending)}、已處理但遠端未關閉 {len(processed)}、人工略過 {len(skipped)}。",
    "",
    "## 真正待抓",
    "",
]

if not pending:
    lines.append("今天沒有新的法說會需要下載。")
else:
    lines.append("請到 AlphaMemo 頁面點「下載 TXT」，下載後交給後續處理流程。")
    lines.append("")
    lines.extend(table_header())
    lines.extend(item_row(i, item) for i, item in enumerate(pending, 1))

lines.extend(["", "## 已處理但遠端狀態未關閉", ""])
if processed:
    lines.extend(table_header(include_reason=True))
    lines.extend(item_row(i, item, reason) for i, (item, reason) in enumerate(processed, 1))
else:
    lines.append("無。")

lines.extend(["", "## 已依人工紀錄略過但遠端仍 pending", ""])
if skipped:
    lines.extend(table_header(include_reason=True))
    lines.extend(item_row(i, item, reason) for i, (item, reason) in enumerate(skipped, 1))
else:
    lines.append("無。")

ordered_statuses = sorted(status_counts.items(), key=lambda pair: pair[0])
status_text = "、".join(f"{name} {count}" for name, count in ordered_statuses)
lines.extend([
    "",
    "## 遠端狀態統計",
    "",
    f"- {status_text}",
    "",
    "## Git 狀態",
    "",
    "```text",
    repo_status,
    "```",
    "",
    "## 自我檢查",
    "",
    "- 關鍵事實是否有來源：有，候選來自即時 fetch 後的 `origin/main`；排除原因來自 raw、output、vault 與人工紀錄。",
    "- 是否有未驗證推測：沒有；檔案存在只表示已處理痕跡，不代表內容品質已重新驗證。",
    "- 是否使用本機 stale pending-list：否。" if "即時 fetch" in fetch_mode else "- 是否使用本機 stale pending-list：未使用本機檔，但本次使用 cached origin，可能 stale。",
    "",
])

Path(last_run).write_text("\n".join(lines), encoding="utf-8")
print(json.dumps({
    "remote_total": len(items),
    "candidates": len(candidates),
    "pending": len(pending),
    "processed": len(processed),
    "skipped": len(skipped),
    "last_run": last_run,
}, ensure_ascii=False))
PY
