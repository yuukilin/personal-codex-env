#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const cp = require("child_process");

const [
  pendingPath,
  repoDir,
  autoDir,
  vaultSourcesDir,
  baseUrl,
  summaryOut,
  markdownOut,
] = process.argv.slice(2);

const DEBUG = process.env.TW_EARNINGS_AUDIT_DEBUG === "1";
const SCAN_LOCAL_IDS = process.env.TW_EARNINGS_SCAN_LOCAL_IDS === "1";
const SCAN_ORIGIN_IDS = process.env.TW_EARNINGS_SCAN_ORIGIN_IDS === "1";
const SCAN_VAULT_IDS = process.env.TW_EARNINGS_SCAN_VAULT_IDS === "1";

if (!pendingPath || !repoDir || !autoDir || !vaultSourcesDir || !baseUrl || !summaryOut || !markdownOut) {
  console.error("Usage: audit-pending.js <pending.json> <repo-dir> <auto-dir> <vault-sources-dir> <base-url> <summary-out> <markdown-out>");
  process.exit(64);
}

function debug(message) {
  if (DEBUG) console.error(`[audit-pending] ${message}`);
}

function timed(label, fn) {
  const start = Date.now();
  const result = fn();
  debug(`${label}: ${Date.now() - start}ms`);
  return result;
}

function readJson(filePath, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return fallback;
  }
}

function listDirSafe(dirPath) {
  try {
    return fs.readdirSync(dirPath);
  } catch {
    return [];
  }
}

function walkFiles(dirPath) {
  const out = [];
  function walk(current) {
    let entries;
    try {
      entries = fs.readdirSync(current, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else {
        out.push(full);
      }
    }
  }
  walk(dirPath);
  return out;
}

function readFileStart(filePath, byteLimit = 64 * 1024) {
  let fd;
  try {
    fd = fs.openSync(filePath, "r");
    const buffer = Buffer.alloc(byteLimit);
    const bytesRead = fs.readSync(fd, buffer, 0, byteLimit, 0);
    return buffer.subarray(0, bytesRead).toString("utf8");
  } catch {
    return "";
  } finally {
    if (fd !== undefined) {
      try {
        fs.closeSync(fd);
      } catch {}
    }
  }
}

function gitList(prefix) {
  try {
    return cp
      .execFileSync("git", ["-C", repoDir, "-c", "core.quotepath=false", "ls-tree", "-r", "--name-only", "origin/main", prefix], {
        encoding: "utf8",
        maxBuffer: 100 * 1024 * 1024,
      })
      .split("\n")
      .filter(Boolean)
      .map((name) => path.basename(name));
  } catch {
    return [];
  }
}

function gitGrepIds(prefix, pattern, lineParser) {
  try {
    return new Set(
      cp
        .execFileSync("git", ["-C", repoDir, "grep", "-h", pattern, "origin/main", "--", prefix], {
          encoding: "utf8",
          maxBuffer: 100 * 1024 * 1024,
        })
        .split("\n")
        .map(lineParser)
        .filter(Boolean)
    );
  } catch {
    return new Set();
  }
}

function rawIdSet(dirPath) {
  const ids = new Set();
  for (const fileName of listDirSafe(dirPath)) {
    if (!fileName.endsWith(".json")) continue;
    const data = readJson(path.join(dirPath, fileName), null);
    if (data?.id) ids.add(data.id);
  }
  return ids;
}

function markdownIdSet(dirPath) {
  const ids = new Set();
  for (const fileName of listDirSafe(dirPath)) {
    if (!fileName.endsWith(".md")) continue;
    const content = readFileStart(path.join(dirPath, fileName));
    const frontmatterMatch = content.match(/^alphamemo_id:\s*([0-9a-f-]+)/m);
    if (frontmatterMatch) ids.add(frontmatterMatch[1]);
    const urlMatch = content.match(/alphamemo\.ai\/free-transcripts\/([0-9a-f-]+)/);
    if (urlMatch) ids.add(urlMatch[1]);
  }
  return ids;
}

function itemKey(item) {
  return item.id || `${item.audio_date || ""}|${item.stock_number || ""}|${item.stock_name || ""}`;
}

function hasPrefix(files, item, ext) {
  const code = String(item.stock_number || "").trim();
  const date = String(item.audio_date || "").trim();
  if (!code || !date) return false;
  const prefix = `${date}-${code}-`;
  return files.some((file) => file.startsWith(prefix) && (!ext || file.endsWith(ext)));
}

function loadManualResolutions() {
  const resolutions = new Map();

  function add(id, source, reason, resolvedAt) {
    if (!id || resolutions.has(id)) return;
    resolutions.set(id, {
      source,
      reason: reason || "manual_resolution",
      resolved_at: resolvedAt || "",
    });
  }

  const manualPath = path.join(autoDir, "manual-resolutions.json");
  if (!fs.existsSync(manualPath)) {
    throw new Error(`runtime manual resolutions missing; refusing fail-open audit: ${manualPath}`);
  }

  let manual;
  try {
    manual = JSON.parse(fs.readFileSync(manualPath, "utf8"));
  } catch (error) {
    throw new Error(`runtime manual resolutions invalid JSON; refusing fail-open audit: ${error.message}`);
  }

  const manualItems = Array.isArray(manual)
    ? manual
    : Array.isArray(manual?.resolutions)
      ? manual.resolutions
      : null;
  if (!manualItems) {
    throw new Error("runtime manual resolutions must be an array or an object with a resolutions array");
  }

  const manualIds = manualItems.map((item) => String(item?.id || ""));
  if (manualIds.some((id) => !id) || new Set(manualIds).size !== manualIds.length) {
    throw new Error("runtime manual resolutions contains empty or duplicate ids; refusing fail-open audit");
  }

  for (const item of manualItems) {
    add(item.id, path.relative(autoDir, manualPath), item.reason || item.done_reason || item.status, item.resolved_at || item.processed_at);
  }

  const manualSources = Array.isArray(manual?.resolution_sources) ? manual.resolution_sources : [];
  for (const source of manualSources) {
    if (!source.path) continue;
    const sourcePath = path.isAbsolute(source.path) ? source.path : path.join(autoDir, source.path);
    const items = readJson(sourcePath, []);
    if (!Array.isArray(items)) continue;
    for (const item of items) {
      const isUserSkipped =
        item.done_reason === source.reason ||
        item.done_reason === "not_provided_by_user_marked_done" ||
        item.processed_at === source.resolved_at;
      if (isUserSkipped) {
        add(item.id, path.relative(autoDir, manualPath), source.reason || item.done_reason, source.resolved_at || item.processed_at);
      }
    }
  }

  const backupDir = path.join(autoDir, "backups");
  for (const file of walkFiles(backupDir)) {
    if (!/pending-list.*\.json$/.test(path.basename(file))) continue;
    const items = readJson(file, []);
    if (!Array.isArray(items)) continue;
    for (const item of items) {
      const isUserSkipped =
        item.done_reason === "not_provided_by_user_marked_done" ||
        item.processed_at === "2026-06-15 15:20:45";
      if (isUserSkipped) {
        add(item.id, path.relative(autoDir, file), item.done_reason || "not_provided_by_user_marked_done", item.processed_at);
      }
    }
  }

  return resolutions;
}

function evidenceFor(item, sources) {
  const evidence = [];
  const id = item.id;
  if (id && sources.localRawIds.has(id)) evidence.push("local_raw_id");
  else if (hasPrefix(sources.localRaw, item, ".json")) evidence.push("local_raw_name");

  if (id && sources.originRawIds.has(id)) evidence.push("origin_raw_id");
  else if (hasPrefix(sources.originRaw, item, ".json")) evidence.push("origin_raw_name");

  if (id && sources.localOutputIds.has(id)) evidence.push("local_output_id");
  else if (hasPrefix(sources.localOutput, item, ".md")) evidence.push("local_output_name");

  if (id && sources.originOutputIds.has(id)) evidence.push("origin_output_id");
  else if (hasPrefix(sources.originOutput, item, ".md")) evidence.push("origin_output_name");

  if (id && sources.vaultTwIds.has(id)) evidence.push("vault_tw_id");
  else if (hasPrefix(sources.vaultTw, item, ".md")) evidence.push("vault_tw_name");

  if (id && sources.vaultUsIds.has(id)) evidence.push("vault_us_id");
  else if (hasPrefix(sources.vaultUs, item, ".md")) evidence.push("vault_us_name");

  return evidence;
}

function company(item) {
  return `${item.stock_name || ""}（${item.stock_number || ""}）`;
}

function link(item) {
  return `[連結](${baseUrl}/${item.id})`;
}

function sortRows(rows) {
  return rows.sort((a, b) => {
    const dateCmp = String(b.item.audio_date || "").localeCompare(String(a.item.audio_date || ""));
    if (dateCmp) return dateCmp;
    return company(a.item).localeCompare(company(b.item), "zh-Hant");
  });
}

function renderTable(title, rows, columns, emptyText) {
  const lines = ["", `## ${title}`, ""];
  if (rows.length === 0) {
    lines.push(emptyText, "");
    return lines.join("\n");
  }
  lines.push(columns.header);
  lines.push(columns.sep);
  rows.forEach((row, index) => {
    lines.push(columns.render(row, index));
  });
  lines.push("");
  return lines.join("\n");
}

const pending = readJson(pendingPath, []);
if (!Array.isArray(pending)) {
  console.error(`pending-list is not a JSON array: ${pendingPath}`);
  process.exit(65);
}

const candidates = pending.filter((item) => item.status === "pending" || item.status === "fetch_failed");
const manualResolutions = timed("manual resolutions", loadManualResolutions);
const sources = {
  localRaw: timed("local raw list", () => listDirSafe(path.join(repoDir, "sources/tw-earnings/raw"))),
  localOutput: timed("local output list", () => listDirSafe(path.join(repoDir, "output/pending"))),
  originRaw: timed("origin raw list", () => gitList("sources/tw-earnings/raw")),
  originOutput: timed("origin output list", () => gitList("output/pending")),
  vaultTw: timed("vault TW list", () => listDirSafe(path.join(vaultSourcesDir, "TW-Earnings"))),
  vaultUs: timed("vault US list", () => listDirSafe(path.join(vaultSourcesDir, "US-Earnings"))),
  localRawIds: timed("local raw ids", () => SCAN_LOCAL_IDS ? rawIdSet(path.join(repoDir, "sources/tw-earnings/raw")) : new Set()),
  localOutputIds: timed("local output ids", () => SCAN_LOCAL_IDS ? markdownIdSet(path.join(repoDir, "output/pending")) : new Set()),
  originRawIds: timed("origin raw ids", () => SCAN_ORIGIN_IDS ? gitGrepIds("sources/tw-earnings/raw", '"id":', (line) => line.match(/"id":\s*"([^"]+)"/)?.[1]) : new Set()),
  originOutputIds: timed("origin output ids", () => SCAN_ORIGIN_IDS ? gitGrepIds("output/pending", "alphamemo_id:", (line) => line.match(/alphamemo_id:\s*([0-9a-f-]+)/)?.[1]) : new Set()),
  vaultTwIds: timed("vault TW ids", () => SCAN_VAULT_IDS ? markdownIdSet(path.join(vaultSourcesDir, "TW-Earnings")) : new Set()),
  vaultUsIds: timed("vault US ids", () => SCAN_VAULT_IDS ? markdownIdSet(path.join(vaultSourcesDir, "US-Earnings")) : new Set()),
};

const warnings = [];
if (!fs.existsSync(path.join(vaultSourcesDir, "TW-Earnings"))) warnings.push("找不到 vault 2 Sources/TW-Earnings，已無法用台股 Obsidian 檔案做排除");
if (!fs.existsSync(path.join(vaultSourcesDir, "US-Earnings"))) warnings.push("找不到 vault 2 Sources/US-Earnings，已無法用美股 Obsidian 檔案做排除");

const actionable = [];
const artifactResolved = [];
const manualResolved = [];

for (const item of candidates) {
  const evidence = evidenceFor(item, sources);
  const manual = manualResolutions.get(itemKey(item));
  const row = { item, evidence, manual };
  if (evidence.length > 0) {
    artifactResolved.push(row);
  } else if (manual) {
    manualResolved.push(row);
  } else {
    actionable.push(row);
  }
}

sortRows(actionable);
sortRows(artifactResolved);
sortRows(manualResolved);

const markdown = [
  renderTable(
    "真正待抓取與抓取失敗清單",
    actionable,
    {
      header: "| # | 公司 | 日期 | 遠端狀態 | AlphaMemo |",
      sep: "|---:|---|---|---|---|",
      render: (row, index) => `| ${index + 1} | ${company(row.item)} | ${row.item.audio_date || ""} | ${row.item.status || ""} | ${link(row.item)} |`,
    },
    "交叉比對後，沒有真正待抓取或抓取失敗項目。"
  ),
  renderTable(
    "已處理但遠端狀態未關閉",
    artifactResolved,
    {
      header: "| # | 公司 | 日期 | 遠端狀態 | 已找到處理痕跡 | AlphaMemo |",
      sep: "|---:|---|---|---|---|---|",
      render: (row, index) =>
        `| ${index + 1} | ${company(row.item)} | ${row.item.audio_date || ""} | ${row.item.status || ""} | ${row.evidence.join(", ")} | ${link(row.item)} |`,
    },
    "沒有發現已處理但遠端仍 pending 的項目。"
  ),
  renderTable(
    "已依使用者指示略過但遠端仍 pending",
    manualResolved,
    {
      header: "| # | 公司 | 日期 | 遠端狀態 | 解析來源 | AlphaMemo |",
      sep: "|---:|---|---|---|---|---|",
      render: (row, index) =>
        `| ${index + 1} | ${company(row.item)} | ${row.item.audio_date || ""} | ${row.item.status || ""} | ${row.manual.reason}; ${row.manual.source} | ${link(row.item)} |`,
    },
    "沒有發現已依使用者指示略過但遠端仍 pending 的項目。"
  ),
].join("\n");

const summary = {
  candidate_total: candidates.length,
  actionable_count: actionable.length,
  artifact_resolved_count: artifactResolved.length,
  manual_resolved_count: manualResolved.length,
  manual_resolution_count: manualResolutions.size,
  warnings,
  sources: {
    local_raw_files: sources.localRaw.length,
    local_output_files: sources.localOutput.length,
    origin_raw_files: sources.originRaw.length,
    origin_output_files: sources.originOutput.length,
    vault_tw_files: sources.vaultTw.length,
    vault_us_files: sources.vaultUs.length,
    local_raw_ids: sources.localRawIds.size,
    local_output_ids: sources.localOutputIds.size,
    origin_raw_ids: sources.originRawIds.size,
    origin_output_ids: sources.originOutputIds.size,
    vault_tw_ids: sources.vaultTwIds.size,
    vault_us_ids: sources.vaultUsIds.size,
  },
  actionable: actionable.map(serializeRow),
  artifact_resolved: artifactResolved.map(serializeRow),
  manual_resolved: manualResolved.map(serializeRow),
};

fs.writeFileSync(summaryOut, `${JSON.stringify(summary, null, 2)}\n`);
fs.writeFileSync(markdownOut, markdown);

function serializeRow(row) {
  return {
    item: row.item,
    evidence: row.evidence,
    manual: row.manual || null,
  };
}
