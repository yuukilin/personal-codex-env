#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const [auditPath, localRepoDir, worktreeDir, runTime] = process.argv.slice(2);

if (!auditPath || !localRepoDir || !worktreeDir || !runTime) {
  console.error("Usage: close-resolved.js <audit-json> <local-repo-dir> <clean-worktree-dir> <run-time>");
  process.exit(64);
}

const PENDING_REL = "sources/tw-earnings/pending-list.json";
const STATE_REL = "sources/tw-earnings/state.json";
const RAW_REL = "sources/tw-earnings/raw";
const OUTPUT_REL = "output/pending";

function readJson(filePath, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return fallback;
  }
}

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function listDirSafe(dirPath) {
  try {
    return fs.readdirSync(dirPath);
  } catch {
    return [];
  }
}

function hasActionable(audit) {
  return Number(audit.actionable_count || 0) > 0;
}

function itemPrefix(item) {
  const code = String(item?.stock_number || "").trim();
  const date = String(item?.audio_date || "").trim();
  if (!code || !date) return "";
  return `${date}-${code}-`;
}

function findByPrefix(dirPath, item, ext) {
  const prefix = itemPrefix(item);
  if (!prefix) return "";
  const fileName = listDirSafe(dirPath).find((name) => name.startsWith(prefix) && name.endsWith(ext));
  return fileName ? path.join(dirPath, fileName) : "";
}

function copyIfFound(source, destDir, copied, missing, label, id) {
  if (!source) {
    missing.push(`${label}:${id}`);
    return;
  }
  fs.mkdirSync(destDir, { recursive: true });
  const dest = path.join(destDir, path.basename(source));
  fs.copyFileSync(source, dest);
  copied.push(path.relative(worktreeDir, dest));
}

function normalizePendingItem(remoteItem, localItem, status) {
  if (status === "artifact") {
    const merged = localItem && !["pending", "fetch_failed"].includes(localItem.status)
      ? { ...remoteItem, ...localItem }
      : { ...remoteItem, status: "fetched", fetched_at: runTime };
    delete merged.fail_reason;
    return merged;
  }

  const manual = { ...remoteItem };
  manual.status = "done";
  manual.processed_at = localItem?.processed_at || runTime;
  manual.done_reason = localItem?.done_reason || "not_provided_by_user_marked_done";
  delete manual.fail_reason;
  return manual;
}

const audit = readJson(auditPath, null);
if (!audit) {
  console.error(`cannot read audit json: ${auditPath}`);
  process.exit(65);
}

if (hasActionable(audit) && process.env.TW_EARNINGS_CLOSE_WITH_ACTIONABLE !== "1") {
  console.error("refuse to close resolved rows while actionable rows remain; set TW_EARNINGS_CLOSE_WITH_ACTIONABLE=1 to override");
  process.exit(75);
}

const artifactRows = Array.isArray(audit.artifact_resolved) ? audit.artifact_resolved : [];
const manualRows = Array.isArray(audit.manual_resolved) ? audit.manual_resolved : [];
if (artifactRows.length === 0 && manualRows.length === 0) {
  console.log(JSON.stringify({ changed: false, reason: "no resolved remote rows" }, null, 2));
  process.exit(0);
}

const workPendingPath = path.join(worktreeDir, PENDING_REL);
const workStatePath = path.join(worktreeDir, STATE_REL);
const localPending = readJson(path.join(localRepoDir, PENDING_REL), []);
const workPending = readJson(workPendingPath, []);
const state = readJson(workStatePath, { processed_ids: [] });

if (!Array.isArray(localPending) || !Array.isArray(workPending)) {
  console.error("pending-list must be a JSON array");
  process.exit(65);
}

if (!Array.isArray(state.processed_ids)) state.processed_ids = [];

const localById = new Map(localPending.map((item) => [item.id, item]).filter(([id]) => id));
const workIndexById = new Map(workPending.map((item, index) => [item.id, index]).filter(([id]) => id));
const processedSet = new Set(state.processed_ids);
const copied = [];
const missing = [];
const closedArtifactIds = [];
const closedManualIds = [];

for (const row of artifactRows) {
  const id = row.item?.id;
  if (!id || !workIndexById.has(id)) continue;
  const index = workIndexById.get(id);
  workPending[index] = normalizePendingItem(workPending[index], localById.get(id), "artifact");
  processedSet.add(id);
  closedArtifactIds.push(id);
  copyIfFound(findByPrefix(path.join(localRepoDir, RAW_REL), row.item, ".json"), path.join(worktreeDir, RAW_REL), copied, missing, "raw", id);
  copyIfFound(findByPrefix(path.join(localRepoDir, OUTPUT_REL), row.item, ".md"), path.join(worktreeDir, OUTPUT_REL), copied, missing, "output", id);
}

for (const row of manualRows) {
  const id = row.item?.id;
  if (!id || !workIndexById.has(id)) continue;
  const index = workIndexById.get(id);
  const manualLocal = {
    processed_at: row.manual?.resolved_at || runTime,
    done_reason: row.manual?.reason || "not_provided_by_user_marked_done",
  };
  workPending[index] = normalizePendingItem(workPending[index], manualLocal, "manual");
  processedSet.add(id);
  closedManualIds.push(id);
}

state.processed_ids = Array.from(processedSet);
writeJson(workPendingPath, workPending);
writeJson(workStatePath, state);

const statusCounts = workPending.reduce((acc, item) => {
  const key = item.status || "unknown";
  acc[key] = (acc[key] || 0) + 1;
  return acc;
}, {});

const result = {
  changed: closedArtifactIds.length > 0 || closedManualIds.length > 0 || copied.length > 0,
  closed_artifact: closedArtifactIds.length,
  closed_manual: closedManualIds.length,
  copied_files: copied.length,
  missing_files: missing,
  status_counts: statusCounts,
};

console.log(JSON.stringify(result, null, 2));
