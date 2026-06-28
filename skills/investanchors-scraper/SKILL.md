---
name: investanchors-scraper
description: >
  自動爬取定錨產業筆記 investanchors.com 的 VIP 文章，支援增量爬取。
  使用者只要說 撈定錨 撈定錨報告 爬定錨 定錨爬蟲 抓定錨文章 定錨更新 定錨報告，
  Claude 就自動執行爬蟲流程。嚴格不觸發：使用者沒提到上述關鍵字。
---

# 定錨產業筆記自動爬蟲 Skill

## 觸發條件
使用者說出 撈定錨/撈定錨報告/爬定錨/定錨爬蟲/抓定錨文章/定錨更新/定錨報告 時觸發。

## 前置條件
1. Chrome 已登入 investanchors.com
2. Codex 的 Chrome / Browser / Computer Use 工具至少一種可用；若都不可用，先告知限制

## Codex 相容性

- 原本寫作「Chrome MCP」的地方，在 Codex 中優先使用 Chrome 插件；若需要操作目前登入狀態或下載檔案，可改用 Computer Use。
- 如果沒有可互動瀏覽器工具，不要硬用一般 fetch 取代登入頁爬蟲，因為 VIP 內容需要登入狀態。
- 任何要寫入 Desktop、移動 ZIP、或更新本機指南檔的動作，先確認路徑存在；若遇到權限限制，請向使用者要求授權。
- 判斷新文/改版/跳過時，必須使用本 skill 的 deterministic helper：`scripts/classify_and_write.mjs`。不要臨場重寫 hash、清理、diff、寫檔邏輯。

## 執行流程

### 第零步：讀取上次爬取日期
用 osascript 讀取 /Users/yuukilin/Desktop/報告收件夾/定錨處理工具/定錨爬蟲指南.md
取 frontmatter 的 last_scraped_date

### 第一步：確認登入
用可用的 Chrome / Browser 工具 navigate 到 https://investanchors.com/user/vip_contents/investanchors_index
用 read_page 確認已登入

### 第二步：收集文章連結
用 javascript_tool 執行，SCRAPE_AFTER_DATE 填入 last_scraped_date：

**重要：不要只依日期停止。** 定錨會不定期修改舊報告，所以每次都要額外回看 VIP 清單最近 10 篇文章：
- 日期大於 `last_scraped_date` 的文章一律抓取
- 日期小於或等於 `last_scraped_date` 的文章，仍至少收集最近 10 篇作為 lookback
- lookback 文章抓完內容後計算 hash，與 `investment-data/sources/investanchors-web/state.json` 的 `content_hashes` 比對
- 只有新 URL 或 hash 變更的舊文章才輸出到報告收件夾；hash 相同者記錄為 skipped，不要重複輸出
- 若 `state.json` 與舊指南檔日期不一致，以 `state.json` 為準

```javascript
const SCRAPE_AFTER_DATE = "{{last_scraped_date}}";
const LOOKBACK_COUNT = 10;
(async function() {
  const cutoffDate = SCRAPE_AFTER_DATE ? new Date(SCRAPE_AFTER_DATE.replace(/\//g, "-")) : null;
  const allArticles = []; const seen = new Set(); let stopEarly = false; let recentSeen = 0;
  let lo = 1, hi = 100;
  while (lo < hi) {
    const mid = Math.ceil((lo + hi) / 2);
    const r = await fetch("/user/vip_contents/investanchors_index?page=" + mid);
    const t = await r.text();
    if (t.includes("/vip_contents/") && !t.includes("沒有資料") && t.includes("<tr")) { lo = mid; } else { hi = mid - 1; }
    await new Promise(r => setTimeout(r, 300));
  }
  for (let page = 1; page <= lo; page++) {
    if (stopEarly) break;
    const resp = await fetch("/user/vip_contents/investanchors_index?page=" + page);
    const html = await resp.text();
    const doc = new DOMParser().parseFromString(html, "text/html");
    doc.querySelectorAll("a[href*='/vip_contents/']").forEach(a => {
      const href = a.getAttribute("href") || "";
      if (href.includes("investanchors_index") || a.textContent.trim().length < 3) return;
      const normHref = href.replace(/^https?:\/\/[^/]+/, "").replace(/\/$/, "");
      if (seen.has(normHref)) return; seen.add(normHref);
      const row = a.closest("tr") || a.parentElement;
      const tds = row ? row.querySelectorAll("td") : [];
      const dateText = tds.length >= 2 ? tds[1].textContent.trim() : "";
      recentSeen++;
      if (cutoffDate && dateText && new Date(dateText.replace(/\//g, "-")) <= cutoffDate && recentSeen > LOOKBACK_COUNT) { stopEarly = true; return; }
      allArticles.push({ title: a.textContent.trim(), href: href.startsWith("http") ? href : "https://investanchors.com" + href, date: dateText });
    });
    await new Promise(r => setTimeout(r, 300));
  }
  window.__allArticles = allArticles;
  return JSON.stringify({ count: allArticles.length, cutoff: SCRAPE_AFTER_DATE });
})();
```

0 篇則告知使用者並結束。

### 第二步後：固定正文抽取與 hash 去重

爬取文章內容後、寫入報告收件夾前，必須先建立 scraped payload，再交給 `scripts/classify_and_write.mjs` 分類與寫檔。

固定規則：
- 正文只取文章容器 `#inves_content` 或 `.investanchors_content` 的 `innerText`
- 不要用整頁 `body.innerText`、`documentElement.innerHTML` 或原始 HTML 當正文 hash 來源
- hash version 固定為 `investanchors_inves_content_v1`
- 對每篇文章用 canonical URL 當 key，對 canonical 正文計算穩定 hash
- 若 URL 不存在於 `content_hashes`：標記為 `new`
- 若 URL 存在且 hash 相同：標記為 `skipped_unchanged`
- 若 URL 存在但 hash 不同，先與 Obsidian `Attachments/` 既有同名原文做 normalized diff
- 若正文完全相同，只是舊 hash baseline 不同：標記為 `skipped_baseline_drift`，只更新 state baseline，不輸出到報告收件夾
- 若正文真的新增、刪除、改寫段落：標記為 `updated`
- 只將 `new` 與 `updated` 寫入 `/Users/yuukilin/Desktop/報告收件夾/定錨產業筆記`
- 回報時分列 `new_articles`、`updated_articles`、`skipped_unchanged`、`skipped_baseline_drift`、`errors`
- 更新 `state.json.content_hashes[url] = hash`、`state.json.content_hash_versions[url] = investanchors_inves_content_v1`，並保留 `processed_articles`

### 第三步：爬取文章內容
優先用 Chrome/Browser 的頁面控制逐篇打開文章，並從 DOM 取固定文章容器。若頁面環境支援 `fetch`，也仍要用 DOMParser 解析後只取 `#inves_content` 或 `.investanchors_content`；若不支援 `fetch`，就逐篇 navigate。

```javascript
window.__scrapedArticles=[]; window.__scrapeErrors=[];
window.__scrapeProgress={current:0,total:window.__allArticles.length,running:true};
window.__stopScraping=false;
function extractArticle(doc, fallbackTitle){
  const el = doc.querySelector("#inves_content") || doc.querySelector(".investanchors_content");
  if (!el) throw new Error("article container #inves_content not found");
  const h1 = doc.querySelector("h1");
  return { pageTitle: h1 ? h1.textContent.trim() : fallbackTitle, content: el.innerText };
}
async function scrapeOne(a){
  const r = await fetch(a.href.replace(/^https?:\/\/[^/]+/,""));
  const html = await r.text();
  const doc = new DOMParser().parseFromString(html, "text/html");
  return {title:a.title, href:a.href.replace(/\/$/,""), url:a.href.replace(/\/$/,""), date:a.date, ...extractArticle(doc, a.title)};
}
(async()=>{const arts=window.__allArticles;
  for(let i=0;i<arts.length;i+=2){
    if(window.__stopScraping)break;
    const batch=arts.slice(i,Math.min(i+2,arts.length));
    const results=await Promise.all(batch.map(async a=>{try{return{data:await scrapeOne(a),ok:true};}catch(e){return{data:{title:a.title,href:a.href,error:e.message},ok:false};}}));
    results.forEach(r=>{if(r.ok)window.__scrapedArticles.push(r.data);else window.__scrapeErrors.push(r.data);});
    window.__scrapeProgress.current=Math.min(i+2,arts.length);
    await new Promise(r=>setTimeout(r,1500));
  }
  window.__scrapeProgress.running=false;
})();
"started "+window.__allArticles.length;
```

每15-30秒檢查: `JSON.stringify(window.__scrapeProgress)`

### 第三步後：用 deterministic helper 分類、寫檔、更新 state

將瀏覽器抓到的文章存成 payload JSON：

```json
{
  "articles": [
    {"title": "...", "date": "2026-06-28", "url": "https://investanchors.com/user/vip_contents/...", "content": "..."}
  ],
  "errors": []
}
```

然後執行：

```bash
node /Users/yuukilin/.codex/skills/investanchors-scraper/scripts/classify_and_write.mjs \
  --payload /tmp/investanchors_scrape_payload.json \
  --state /Users/yuukilin/Documents/Claude/Projects/報告匯流中心/investment-data/sources/investanchors-web/state.json \
  --output-dir /Users/yuukilin/Desktop/報告收件夾/定錨產業筆記 \
  --attachments-dir "/Users/yuukilin/Library/Mobile Documents/iCloud~md~obsidian/Documents/卡片筆記盒模板/Attachments" \
  --result /tmp/investanchors_scrape_result.json \
  --write
```

這個 helper 是唯一允許更新 `state.json`、輸出 Markdown、判斷 baseline drift 的程式。

### 第四步：打包 ZIP
除非 Browser/Chrome 只能用下載檔案交付，否則不要再用 ZIP 路徑。預設改用 `scripts/classify_and_write.mjs --write` 直接寫入報告收件夾。

```javascript
(async function(){const map=new Map();window.__scrapedArticles.forEach(a=>{const k=a.href.replace(/^https?:\/\/[^/]+/,"").replace(/\/$/,"");if(!map.has(k)||(a.content||"").length>(map.get(k).content||"").length)map.set(k,a);});const articles=Array.from(map.values());if(typeof JSZip==="undefined"){await new Promise((res,rej)=>{const s=document.createElement("script");s.src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js";s.onload=res;s.onerror=rej;document.head.appendChild(s);});}const zip=new JSZip();const today=new Date().toISOString().split("T")[0];let latestDate="";articles.forEach((art,idx)=>{if(art.date&&art.date>latestDate)latestDate=art.date;let fn=(art.date?art.date.replace(/\//g,"-")+"-":"")+(art.title||"untitled-"+idx).replace(/[\/\\:*?"<>|]/g,"-").replace(/\s+/g," ").trim().substring(0,80)+".md";zip.file(fn,["---",'title: "'+(art.title||"").replace(/"/g,'\\"')+'"',"date: "+(art.date||"").replace(/\//g,"-"),"source: "+art.href,"tags: [investanchors]","status: draft","---","","# "+art.title,"",art.content||""].join("\n"));});const blob=await zip.generateAsync({type:"blob"});const a=document.createElement("a");a.href=URL.createObjectURL(blob);a.download="investanchors_articles_"+today+".zip";document.body.appendChild(a);a.click();document.body.removeChild(a);return JSON.stringify({count:articles.length,latestDate,filename:"investanchors_articles_"+today+".zip"});})();
```

### 第五步：更新日期+搬移
用 osascript sed 更新 last_scraped_date 為本次最新日期。
用 osascript unzip 到 ~/Desktop/報告收件夾/定錨產業筆記/

### 第六步：回報結果
告知篇數、最新日期、檔案位置、日期已更新。

## 錯誤處理
- Chrome / Browser 工具不可用：提醒使用者開啟或授權
- 未登入：提醒先登入
- javascript_tool 超時：爬蟲仍在背景跑
- 0 篇：告知使用者

## 注意事項
- 每批2篇間隔1.5秒，不加快
- 增量模式通常很快
- 全量約15-20分鐘
