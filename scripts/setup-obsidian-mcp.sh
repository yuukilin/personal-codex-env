#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-${HOME}/.codex}"
VAULT_PATH="${OBSIDIAN_VAULT_PATH:-${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/卡片筆記盒模板}"
SOURCE="${VAULT_PATH}/.obsidian/plugins/mcp-tools/bin/mcp-server"
DEST_DIR="${CODEX_HOME}/mcp/obsidian-mcp-tools"
DEST="${DEST_DIR}/mcp-server"
CONFIG="${CODEX_CONFIG:-${CODEX_HOME}/config.toml}"
STAMP="$(TZ=Asia/Taipei date +%Y%m%d-%H%M%S)"
PYTHON_BIN="$(command -v python3 || true)"

if [ ! -f "${SOURCE}" ]; then
  echo "找不到 Obsidian MCP server：${SOURCE}" >&2
  echo "請先確認 Obsidian 已安裝並啟用 mcp-tools 外掛，或設定 OBSIDIAN_VAULT_PATH。" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
cp "${SOURCE}" "${DEST}"
chmod 755 "${DEST}"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "${DEST}" >/dev/null
  codesign --verify --deep --strict --verbose=2 "${DEST}"
else
  echo "找不到 codesign，已略過簽章；macOS 上通常需要簽章才穩。" >&2
fi

API_KEY="${OBSIDIAN_API_KEY:-}"
REST_DATA="${VAULT_PATH}/.obsidian/plugins/obsidian-local-rest-api/data.json"
if [ -z "${API_KEY}" ] && [ -n "${PYTHON_BIN}" ] && [ -f "${REST_DATA}" ]; then
  API_KEY="$(${PYTHON_BIN} - "${REST_DATA}" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    print(data.get('apiKey',''))
except Exception:
    print('')
PY
)"
fi

if [ -f "${CONFIG}" ]; then
  cp "${CONFIG}" "${CONFIG}.bak-obsidian-mcp-${STAMP}"
elif [ -f "${REPO_ROOT}/config.template.toml" ]; then
  mkdir -p "$(dirname "${CONFIG}")"
  cp "${REPO_ROOT}/config.template.toml" "${CONFIG}"
fi

if [ -n "${PYTHON_BIN}" ] && [ -f "${CONFIG}" ]; then
  CONFIG="${CONFIG}" DEST="${DEST}" API_KEY="${API_KEY}" HOME_DIR="${HOME}" ${PYTHON_BIN} <<'PY'
import os
from pathlib import Path

config = Path(os.environ['CONFIG'])
dest = os.environ['DEST']
api_key = os.environ.get('API_KEY', '')
home = os.environ.get('HOME_DIR', str(Path.home()))
text = config.read_text()
text = text.replace('/Users/YOUR_USERNAME', home)

lines = text.splitlines()

def find_section(header):
    start = None
    for i, line in enumerate(lines):
        if line.strip() == header:
            start = i
            break
    if start is None:
        return None, None
    end = len(lines)
    for j in range(start + 1, len(lines)):
        s = lines[j].strip()
        if s.startswith('[') and s.endswith(']'):
            end = j
            break
    return start, end

def ensure_section(header):
    start, end = find_section(header)
    if start is None:
        if lines and lines[-1].strip():
            lines.append('')
        lines.append(header)
        start, end = len(lines) - 1, len(lines)
    return start, end

def set_key(header, key, value, quote=True, only_if_missing=False):
    start, end = ensure_section(header)
    prefix = f'{key} = '
    rendered = f'{key} = "{value}"' if quote else f'{key} = {value}'
    for i in range(start + 1, end):
        if lines[i].strip().startswith(prefix):
            if only_if_missing and 'PUT_YOUR_' not in lines[i] and 'YOUR_' not in lines[i]:
                return
            lines[i] = rendered
            return
    lines.insert(start + 1, rendered)

set_key('[mcp_servers.obsidian-mcp-tools]', 'command', dest)
set_key('[mcp_servers.obsidian-mcp-tools]', 'default_tools_approval_mode', 'auto')
set_key('[mcp_servers.obsidian-mcp-tools]', 'tool_timeout_sec', '120', quote=False)
set_key('[mcp_servers.obsidian-mcp-tools.env]', 'OBSIDIAN_USE_HTTP', 'true')
if api_key:
    set_key('[mcp_servers.obsidian-mcp-tools.env]', 'OBSIDIAN_API_KEY', api_key)
else:
    set_key('[mcp_servers.obsidian-mcp-tools.env]', 'OBSIDIAN_API_KEY', 'PUT_YOUR_LOCAL_OBSIDIAN_API_KEY_HERE', only_if_missing=True)

for tool in ['get_server_info','get_vault_file','list_vault_files','search_vault_simple','create_vault_file','append_to_vault_file']:
    set_key(f'[mcp_servers.obsidian-mcp-tools.tools.{tool}]', 'approval_mode', 'auto')

config.write_text('\n'.join(lines) + '\n')
PY
else
  echo "無法自動更新 ${CONFIG}；請手動把 Obsidian MCP command 設成：${DEST}" >&2
fi

echo "Obsidian MCP server 已安裝到：${DEST}"
echo "Codex config 已指向本機穩定路徑；請重開 Codex 讓 MCP 工具重新載入。"
