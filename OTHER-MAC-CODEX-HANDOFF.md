# 另一台 Mac Codex 交接指令

用途：把另一台 Mac 的 Codex rules / skills 收集起來，準備跟主 repo 比對；automation host-state 只留在原 Mac 的 repo 外備份。

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
- automation host-state 必須留在這台 Mac 的 ~/.codex-env-backups/merge-review，不能進 incoming、不能 commit，也不能拿去覆寫另一台 Mac
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
   ./scripts/backup-current.sh
   git pull --ff-only
6. 建立融合分支：
   git switch -c merge-from-other-mac
   如果分支已存在，就改用：
   git switch merge-from-other-mac
7. 再次確認同步 layout：
   ./scripts/validate-sync-layout.sh
8. 收集這台 Mac 的 Codex rules / skills；腳本會把 host-state 另存到 repo 外：
   ./scripts/collect-local-for-merge.sh
9. 檢查 incoming 不含已知 host-state／runtime 路徑、常見秘密檔名或 symlink，再人工查看內容：
   ./scripts/validate-incoming-merge.sh
   git status --short -- incoming
10. 檢查通過後，才把 incoming 加進分支並 commit：
   git add incoming
   git commit -m "Collect Codex skills from other Mac"
   如果顯示 nothing to commit，就告訴我沒有新差異，不要硬做 commit。
11. push 到 GitHub：
   git push -u origin merge-from-other-mac

完成後請明確回覆我：
- 有沒有成功 push
- incoming 資料夾名稱
- 本機 automation host-state 備份路徑
- 確認 incoming 與 commit 完全沒有 automation.toml，或 automation host-state 的 status、target、cwd、created_at、updated_at
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


## 兩台都可安裝 Obsidian MCP，但同時只能一台寫入

先讀 `OBSIDIAN-MCP-SINGLE-WRITER.md`。兩台 Mac 都可以在本機建立自己的 Obsidian MCP server，但新 Mac 的寫入型排程預設為 `PAUSED`。完成交接、確認另一台停止人工與排程寫入並完成 iCloud 同步後，這台才成為目前寫入端。不要同步 `~/.codex/mcp/` 裡的 binary，也不要同步真實 `config.toml` 或 API key。

在另一台 Mac 的 repo 目錄執行：

```bash
./scripts/setup-obsidian-mcp.sh
```

如果 vault 不在預設路徑，改用：

```bash
OBSIDIAN_VAULT_PATH="/你的/Obsidian/vault/路徑" ./scripts/setup-obsidian-mcp.sh
```

完成後重開 Codex。若要把寫入工作交接到這台，先暫停另一台的 Obsidian 寫入型排程、等待執行中工作結束並完成 iCloud 同步；接著在這台做建立、讀取與刪除健康檢查，通過後才用 Codex automation tool 啟用這台的寫入型排程。兩台不得同時寫入。
