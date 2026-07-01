# 另一台 Mac Codex 交接指令

用途：把另一台 Mac 的 Codex rules / skills 收集起來，準備跟主 repo 融合。

重要：先不要執行 `./scripts/install-mac.sh`。那是安裝/覆蓋用的，不是融合用的。

## 給使用者的簡單步驟

1. 到另一台 Mac。
2. 打開 Codex。
3. 開一個新對話。
4. 把下面「請直接貼給另一台 Mac 的 Codex」整段貼給它。
5. 等它完成後，回到原本這台 Mac 的 Codex 說：`另一台已 push merge-from-other-mac`。

## 請直接貼給另一台 Mac 的 Codex

```text
我現在要把這台 Mac 的 Codex rules / skills 跟主 repo 融合。

請你一步一步幫我做，但注意：
- 不要執行 ./scripts/install-mac.sh
- 不要覆蓋我這台 Mac 現有的 ~/.codex/skills
- 只做備份、收集、建立融合分支、push
- 全程用繁體中文跟我回報

請先執行台北時間檢查：
TZ=Asia/Taipei date +%Y-%m-%d\ %H:%M:%S

然後做以下事情：

1. 確認 git 可用。
2. 建立資料夾 ~/Documents/Codex。
3. 如果 ~/Documents/Codex/personal-codex-env 不存在，就 clone：
   git clone https://github.com/yuukilin/personal-codex-env.git ~/Documents/Codex/personal-codex-env
4. 進入 repo：
   cd ~/Documents/Codex/personal-codex-env
5. 確認在最新 main：
   git switch main
   git pull
6. 建立融合分支：
   git switch -c merge-from-other-mac
   如果分支已存在，就改用：
   git switch merge-from-other-mac
7. 執行備份：
   ./scripts/backup-current.sh
8. 收集這台 Mac 的 Codex rules / skills：
   ./scripts/collect-local-for-merge.sh
9. 檢查有哪些 incoming 檔案：
   git status --short
10. 把 incoming 加進分支並 commit：
   git add incoming
   git commit -m "Collect Codex skills from other Mac"
   如果顯示 nothing to commit，就告訴我沒有新差異，不要硬做 commit。
11. push 到 GitHub：
   git push -u origin merge-from-other-mac

完成後請明確回覆我：
- 有沒有成功 push
- incoming 資料夾名稱
- 有沒有遇到登入或權限問題
- 再提醒我回原本那台 Mac 的 Codex 說：另一台已 push merge-from-other-mac
```

## 如果另一台 Mac 卡住

把錯誤訊息原文貼回原本這台 Mac 的 Codex。

最常見狀況：

- GitHub 要求登入。
- git clone 失敗，因為 private repo 沒有權限。
- 另一台 Mac 沒有 git。
- 分支已經存在。

遇到這些都不要自己亂按，直接把錯誤貼回來。


## 讓另一台 Mac 啟用 Obsidian MCP

如果另一台 Mac 已經套用這個 repo，還需要在那台 Mac 本機建立自己的 Obsidian MCP server。不要同步 `~/.codex/mcp/` 裡的 binary，也不要同步真實 `config.toml` 或 API key。

在另一台 Mac 的 repo 目錄執行：

```bash
./scripts/setup-obsidian-mcp.sh
```

如果 vault 不在預設路徑，改用：

```bash
OBSIDIAN_VAULT_PATH="/你的/Obsidian/vault/路徑" ./scripts/setup-obsidian-mcp.sh
```

完成後重開 Codex。這樣每台 Mac 都使用自己的 `~/.codex/mcp/obsidian-mcp-tools/mcp-server`，不會互相覆蓋。
