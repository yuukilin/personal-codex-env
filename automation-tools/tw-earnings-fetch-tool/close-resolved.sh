#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
AUTO_DIR="${TW_EARNINGS_AUTO_DIR:-${CODEX_HOME}/automations/tw-earnings-fetch}"
REPO_DIR="${TW_EARNINGS_REPO:-${TW_EARNINGS_REPO_DIR:-${HOME}/Desktop/python/investment-data}}"
VAULT_ROOT="${OBSIDIAN_VAULT_PATH:-${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/卡片筆記盒模板}"
VAULT_SOURCES_DIR="${TW_EARNINGS_VAULT_SOURCES_DIR:-${VAULT_ROOT}/2 Sources}"
PENDING_REL="sources/tw-earnings/pending-list.json"
BASE_URL="https://www.alphamemo.ai/free-transcripts"
AUDIT_HELPER="$SCRIPT_DIR/audit-pending.js"
CLOSE_HELPER="$SCRIPT_DIR/close-resolved.js"
MANUAL_RESOLUTIONS="${TW_EARNINGS_MANUAL_RESOLUTIONS:-${AUTO_DIR}/manual-resolutions.json}"
SEED_RESOLUTIONS="$SCRIPT_DIR/manual-resolutions.seed.json"
LAST_CLOSE="$AUTO_DIR/last-close.md"

mkdir -p "$AUTO_DIR"

run_time="$(TZ=Asia/Taipei date '+%Y-%m-%d %H:%M:%S')"
tmp_dir=""

cleanup() {
  if [ "${TW_EARNINGS_KEEP_CLOSE_TMP:-0}" != "1" ] && [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    rm -rf "$tmp_dir"
  fi
}
trap cleanup EXIT

fail() {
  local message="$1"
  cat >"$LAST_CLOSE" <<EOF
# tw-earnings close resolved

- 執行時間（Asia/Taipei）：${run_time}
- 結果：失敗
- 原因：${message}

本輪未修改遠端。
EOF
  cat "$LAST_CLOSE"
  exit 1
}

for bin in git jq mktemp node; do
  command -v "$bin" >/dev/null 2>&1 || fail "缺少必要工具：$bin"
done

[ -d "$REPO_DIR/.git" ] || fail "repo 目錄不存在或不是 git repo：$REPO_DIR"
[ -f "$AUDIT_HELPER" ] || fail "缺少 audit helper：$AUDIT_HELPER"
[ -f "$CLOSE_HELPER" ] || fail "缺少 close helper：$CLOSE_HELPER"
[ -f "$MANUAL_RESOLUTIONS" ] || fail "runtime manual-resolutions.json 不存在，已 fail closed：$MANUAL_RESOLUTIONS；請由 $SEED_RESOLUTIONS 初始化缺少檔案，不得以空清單取代"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/tw-earnings-close.XXXXXX")"
pending_json="$tmp_dir/pending-list.origin.json"
audit_json="$tmp_dir/audit.json"
audit_md="$tmp_dir/audit.md"
audit_log="$tmp_dir/audit.log"
apply_json="$tmp_dir/apply.json"
clone_dir="$tmp_dir/investment-data-clean"
fetch_log="$tmp_dir/fetch.log"
push_log="$tmp_dir/push.log"

echo "[close-resolved] fetch source origin" >&2
if ! GIT_TERMINAL_PROMPT=0 git -C "$REPO_DIR" fetch origin >"$fetch_log" 2>&1; then
  fail "git fetch origin 失敗：$(tr '\n' ' ' <"$fetch_log" | sed 's/[[:space:]]\+/ /g')"
fi

if ! git -C "$REPO_DIR" show "origin/main:$PENDING_REL" >"$pending_json" 2>/dev/null; then
  fail "無法讀取 origin/main:$PENDING_REL"
fi

echo "[close-resolved] audit resolved buckets" >&2
if ! node "$AUDIT_HELPER" "$pending_json" "$REPO_DIR" "$AUTO_DIR" "$VAULT_SOURCES_DIR" "$BASE_URL" "$audit_json" "$audit_md" >"$audit_log" 2>&1; then
  fail "audit 失敗：$(tr '\n' ' ' <"$audit_log" | sed 's/[[:space:]]\+/ /g')"
fi

actionable_count="$(jq -r '.actionable_count' "$audit_json")"
artifact_resolved_count="$(jq -r '.artifact_resolved_count' "$audit_json")"
manual_resolved_count="$(jq -r '.manual_resolved_count' "$audit_json")"

if [ "$actionable_count" != "0" ] && [ "${TW_EARNINGS_CLOSE_WITH_ACTIONABLE:-0}" != "1" ]; then
  fail "仍有真正待抓 ${actionable_count} 筆，拒絕自動關帳；請先處理待抓項目"
fi

if [ "$artifact_resolved_count" = "0" ] && [ "$manual_resolved_count" = "0" ]; then
  cat >"$LAST_CLOSE" <<EOF
# tw-earnings close resolved

- 執行時間（Asia/Taipei）：${run_time}
- 結果：無需關帳
- 真正待抓：${actionable_count}
- 已處理但遠端未關閉：0
- 已依使用者指示略過但遠端仍 pending：0

遠端沒有需要自動關帳的項目。
EOF
  cat "$LAST_CLOSE"
  exit 0
fi

remote_url="$(git -C "$REPO_DIR" config --get remote.origin.url || true)"
[ -n "$remote_url" ] || fail "無法取得 remote.origin.url"

echo "[close-resolved] create clean clone" >&2
git clone --shared --no-checkout "$REPO_DIR" "$clone_dir" >/dev/null 2>&1 || fail "建立乾淨 clone 失敗"
git -C "$clone_dir" remote set-url origin "$remote_url"
echo "[close-resolved] fetch clean clone origin/main" >&2
if ! GIT_TERMINAL_PROMPT=0 git -C "$clone_dir" fetch origin main >"$fetch_log" 2>&1; then
  fail "乾淨 clone fetch origin main 失敗：$(tr '\n' ' ' <"$fetch_log" | sed 's/[[:space:]]\+/ /g')"
fi
git -C "$clone_dir" sparse-checkout init --cone >/dev/null 2>&1 || fail "sparse-checkout init 失敗"
git -C "$clone_dir" sparse-checkout set sources/tw-earnings output/pending >/dev/null 2>&1 || fail "sparse-checkout set 失敗"
git -C "$clone_dir" checkout -B tw-earnings-close origin/main >/dev/null 2>&1 || fail "checkout origin/main 失敗"

echo "[close-resolved] apply close changes" >&2
node "$CLOSE_HELPER" "$audit_json" "$REPO_DIR" "$clone_dir" "$run_time" >"$apply_json"

changed="$(jq -r '.changed' "$apply_json")"
if [ "$changed" != "true" ]; then
  cat >"$LAST_CLOSE" <<EOF
# tw-earnings close resolved

- 執行時間（Asia/Taipei）：${run_time}
- 結果：無需提交
- apply 結果：$(tr '\n' ' ' <"$apply_json" | sed 's/[[:space:]]\+/ /g')
EOF
  cat "$LAST_CLOSE"
  exit 0
fi

echo "[close-resolved] stage changes" >&2
git -C "$clone_dir" add sources/tw-earnings/pending-list.json sources/tw-earnings/state.json sources/tw-earnings/raw output/pending

if git -C "$clone_dir" diff --cached --quiet; then
  cat >"$LAST_CLOSE" <<EOF
# tw-earnings close resolved

- 執行時間（Asia/Taipei）：${run_time}
- 結果：無需提交
- 原因：關帳 helper 執行後沒有 staged diff。
EOF
  cat "$LAST_CLOSE"
  exit 0
fi

echo "[close-resolved] commit changes" >&2
git -C "$clone_dir" commit -m "Close resolved TW earnings pending items" >/dev/null
commit_sha="$(git -C "$clone_dir" rev-parse --short HEAD)"

echo "[close-resolved] push origin/main" >&2
if ! GIT_TERMINAL_PROMPT=0 git -C "$clone_dir" push origin HEAD:main >"$push_log" 2>&1; then
  fail "push 失敗：$(tr '\n' ' ' <"$push_log" | sed 's/[[:space:]]\+/ /g')"
fi

cat >"$LAST_CLOSE" <<EOF
# tw-earnings close resolved

- 執行時間（Asia/Taipei）：${run_time}
- 結果：成功
- commit：${commit_sha}
- 真正待抓：${actionable_count}
- 已處理但遠端未關閉，本次關帳：${artifact_resolved_count}
- 已依使用者指示略過但遠端仍 pending，本次關帳：${manual_resolved_count}
- apply 結果：$(tr '\n' ' ' <"$apply_json" | sed 's/[[:space:]]\+/ /g')

已從乾淨 clone 更新 origin/main，未修改本機 dirty worktree。
EOF

cat "$LAST_CLOSE"
