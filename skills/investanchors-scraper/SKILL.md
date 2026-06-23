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

## 執行流程

### 第零步：讀取上次爬取日期
用 osascript 讀取 /Users/yuukilin/Desktop/報告收件夾/定錨處理工具/定錨爬蟲指南.md
取 frontmatter 的 last_scraped_date

### 第一步：確認登入
用可用的 Chrome / Browser 工具 navigate 到 https://investanchors.com/user/vip_contents/investanchors_index
用 read_page 確認已登入

### 第二步：收集文章連結
用 javascript_tool 執行，SCRAPE_AFTER_DATE 填入 last_scraped_date：
```javascript
const SCRAPE_AFTER_DATE = "{{last_scraped_date}}";
(async function() {
  const cutoffDate = SCRAPE_AFTER_DATE ? new Date(SCRAPE_AFTER_DATE.replace(/\//g, "-")) : null;
  const allArticles = []; const seen = new Set(); let stopEarly = false;
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
      if (cutoffDate && dateText && new Date(dateText.replace(/\//g, "-")) <= cutoffDate) { stopEarly = true; return; }
      allArticles.push({ title: a.textContent.trim(), href: href.startsWith("http") ? href : "https://investanchors.com" + href, date: dateText });
    });
    await new Promise(r => setTimeout(r, 300));
  }
  window.__allArticles = allArticles;
  return JSON.stringify({ count: allArticles.length, cutoff: SCRAPE_AFTER_DATE });
})();
```

0 篇則告知使用者並結束。

### 第三步：爬取文章內容
用 fire-and-forget 模式，腳本立即返回，爬蟲背景跑。

```javascript
window.__scrapedArticles=[]; window.__scrapeErrors=[];
window.__scrapeProgress={current:0,total:window.__allArticles.length,running:true};
window.__stopScraping=false;
function cleanExtract(h){
  let cc=h.indexOf("我要留言"); if(cc>0)h=h.substring(0,cc);
  let rc=h.indexOf("回覆 ·"); if(rc>500)h=h.substring(0,rc);
  let t=h;
  while(t.includes("<\\/")){let s=t.indexOf("<\\/"),e=t.indexOf(">",s); if(e>s)t=t.substring(0,s)+"\n"+t.substring(e+1);else break;}
  while(t.includes("<")){let s=t.indexOf("<"),e=t.indexOf(">",s); if(e>s&&(e-s)<100)t=t.substring(0,s)+t.substring(e+1);else break;}
  t=t.replace(/\\n/g,"\n").replace(/\\t/g,"\t").replace(/\\r/g,"");
  t=t.replace(/&nbsp;/g," ").replace(/&amp;/g,"&").replace(/&lt;/g,"<").replace(/&gt;/g,">").replace(/&quot;/g,'"').replace(/&#39;/g,"'");
  let de=t.indexOf("再謹慎做出決策。");
  if(de>0&&de<1500){t=t.substring(de+"再謹慎做出決策。".length);}
  else{let rp=t.indexOf("收件者："); if(rp>0&&rp<500){let nl=t.indexOf("\n",rp); if(nl>0)t=t.substring(nl+1);}}
  return t.replace(/\n{3,}/g,"\n\n").trim();
}
async function scrapeOne(a){const r=await fetch(a.href.replace(/^https?:\/\/[^/]+/,"")); return{title:a.title,href:a.href,date:a.date,content:cleanExtract(await r.text())};}
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

### 第四步：打包 ZIP
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
