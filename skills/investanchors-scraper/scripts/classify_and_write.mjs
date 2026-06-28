#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";

const HASH_VERSION = "investanchors_inves_content_v1";

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) continue;
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) args[key] = true;
    else {
      args[key] = next;
      i++;
    }
  }
  return args;
}

function requireArg(args, key) {
  if (!args[key]) throw new Error(`Missing required --${key}`);
  return args[key];
}

function yamlEscape(value) {
  return String(value || "").replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

function sanitizeFilename(value) {
  return String(value || "untitled")
    .replace(/[\/\\:*?"<>|]/g, "-")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 80) || "untitled";
}

function canonicalUrl(url) {
  return String(url || "").replace(/\/$/, "");
}

function articleFilename(article) {
  const date = String(article.date || "").replace(/\//g, "-");
  return `${date ? `${date}-` : ""}${sanitizeFilename(article.title)}.md`;
}

function stripFrontmatter(markdown) {
  return String(markdown || "").replace(/^---\n[\s\S]*?\n---\n?/, "");
}

function stripHeading(markdown) {
  return String(markdown || "").replace(/^# .+\n+/, "");
}

function decodeHtmlEntities(text) {
  return String(text || "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

export function canonicalizeContent(input) {
  let text = decodeHtmlEntities(String(input || ""));

  text = text.replace(/^# .+\n+/, "");

  text = text.replace(/\\"?\s*style=\\"?[^>\n]*>/g, "");
  text = text.replace(/<[^>]{1,200}>/g, "");

  const warning = "再謹慎做出決策。";
  const warningIndex = text.indexOf(warning);
  if (warningIndex >= 0 && warningIndex < 2000) {
    text = text.slice(warningIndex + warning.length);
  }

  const commentIndex = text.search(/\n\s*留言\s*\n/);
  if (commentIndex > 0) text = text.slice(0, commentIndex);

  const replyIndex = text.indexOf("回覆 ·");
  if (replyIndex > 500) text = text.slice(0, replyIndex);

  return text
    .replace(/\r/g, "")
    .replace(/\u00a0/g, " ")
    .split("\n")
    .map((line) => line.trimEnd())
    .join("\n")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function canonicalizeMarkdown(markdown) {
  return canonicalizeContent(stripHeading(stripFrontmatter(markdown)));
}

function hashContent(content) {
  return crypto.createHash("sha256").update(canonicalizeContent(content), "utf8").digest("hex").slice(0, 12);
}

async function readJson(filePath, fallback) {
  try {
    return JSON.parse(await fs.readFile(filePath, "utf8"));
  } catch (error) {
    if (error && error.code === "ENOENT") return fallback;
    throw error;
  }
}

async function readExistingAttachment(attachmentsDir, article) {
  if (!attachmentsDir) return null;
  const filePath = path.join(attachmentsDir, articleFilename(article));
  try {
    const raw = await fs.readFile(filePath, "utf8");
    return { filePath, canonical: canonicalizeMarkdown(raw) };
  } catch (error) {
    if (error && error.code === "ENOENT") return null;
    throw error;
  }
}

function firstDiff(a, b) {
  const left = String(a || "");
  const right = String(b || "");
  let prefix = 0;
  while (prefix < left.length && prefix < right.length && left[prefix] === right[prefix]) prefix++;
  let suffix = 0;
  while (
    suffix < left.length - prefix &&
    suffix < right.length - prefix &&
    left[left.length - 1 - suffix] === right[right.length - 1 - suffix]
  ) suffix++;
  return {
    common_prefix: prefix,
    common_suffix: suffix,
    old_preview: right.slice(Math.max(0, prefix - 80), Math.min(right.length, prefix + 220)),
    new_preview: left.slice(Math.max(0, prefix - 80), Math.min(left.length, prefix + 220)),
  };
}

function markdownFor(article, status) {
  const date = String(article.date || "").replace(/\//g, "-");
  return [
    "---",
    `title: "${yamlEscape(article.title)}"`,
    `date: ${date}`,
    `source: ${article.url}`,
    "tags: [investanchors]",
    "status: draft",
    `content_hash: ${article.content_hash}`,
    `hash_version: ${HASH_VERSION}`,
    `scrape_status: ${status}`,
    "---",
    "",
    `# ${String(article.title || "")}`,
    "",
    canonicalizeContent(article.content),
    "",
  ].join("\n");
}

function ensureStateShape(state) {
  state.content_hashes = state.content_hashes || {};
  state.content_hash_versions = state.content_hash_versions || {};
  state.content_lengths = state.content_lengths || {};
  state.last_seen_at_by_url = state.last_seen_at_by_url || {};
  state.last_changed_at_by_url = state.last_changed_at_by_url || {};
  state.processed_articles = Array.isArray(state.processed_articles) ? state.processed_articles : [];
  state.hash_method = HASH_VERSION;
  return state;
}

function nowTaipeiIso() {
  return (
    new Intl.DateTimeFormat("sv-SE", {
      timeZone: "Asia/Taipei",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    })
      .format(new Date())
      .replace(" ", "T") + "+0800"
  );
}

async function main() {
  const args = parseArgs(process.argv);
  const payloadPath = requireArg(args, "payload");
  const statePath = requireArg(args, "state");
  const outputDir = requireArg(args, "output-dir");
  const resultPath = args.result || "";
  const attachmentsDir = args["attachments-dir"] || "";
  const write = Boolean(args.write);

  const payload = await readJson(payloadPath, {});
  const articles = Array.isArray(payload.articles) ? payload.articles : [];
  const state = ensureStateShape(await readJson(statePath, {}));
  const runAt = nowTaipeiIso();
  const processed = new Set(state.processed_articles);

  const result = {
    hash_version: HASH_VERSION,
    run_at: runAt,
    output_dir: outputDir,
    state_path: statePath,
    new_articles: [],
    updated_articles: [],
    skipped_unchanged: [],
    skipped_baseline_drift: [],
    errors: Array.isArray(payload.errors) ? payload.errors : [],
    written: [],
  };

  let latestDate = state.last_scraped_date || "";

  for (const input of articles) {
    const url = canonicalUrl(input.url || input.href);
    const content = canonicalizeContent(input.content);
    const hash = hashContent(content);
    const article = {
      ...input,
      url,
      href: url,
      content,
      content_hash: hash,
      hash_version: HASH_VERSION,
      filename: articleFilename(input),
    };

    const previousHash = state.content_hashes[url] || null;
    const previousVersion = state.content_hash_versions[url] || null;
    const attachment = await readExistingAttachment(attachmentsDir, article);
    const attachmentSame = Boolean(attachment && attachment.canonical === content);
    const date = String(article.date || "").replace(/\//g, "-");
    if (date && date > latestDate) latestDate = date;

    let status;
    if (!previousHash && attachmentSame) {
      status = "skipped_baseline_drift";
      result.skipped_baseline_drift.push({ ...article, previous_hash: previousHash, previous_version: previousVersion, attachment: attachment.filePath, reason: "attachment_same_no_state" });
    } else if (!previousHash) {
      status = "new";
      result.new_articles.push(article);
    } else if (previousHash === hash) {
      status = "skipped_unchanged";
      result.skipped_unchanged.push({ ...article, previous_hash: previousHash, previous_version: previousVersion });
    } else if (attachmentSame) {
      status = "skipped_baseline_drift";
      result.skipped_baseline_drift.push({ ...article, previous_hash: previousHash, previous_version: previousVersion, attachment: attachment.filePath, reason: "attachment_same_hash_mismatch" });
    } else {
      status = "updated";
      const diff = attachment ? firstDiff(content, attachment.canonical) : null;
      result.updated_articles.push({ ...article, previous_hash: previousHash, previous_version: previousVersion, attachment: attachment ? attachment.filePath : null, diff });
    }

    state.content_hashes[url] = hash;
    state.content_hash_versions[url] = HASH_VERSION;
    state.content_lengths[url] = content.length;
    state.last_seen_at_by_url[url] = runAt;
    if (status === "new" || status === "updated") state.last_changed_at_by_url[url] = runAt;
    if (!processed.has(url)) {
      state.processed_articles.push(url);
      processed.add(url);
    }
  }

  state.last_scraped_date = latestDate;
  state.last_run = runAt;

  if (write) {
    await fs.mkdir(outputDir, { recursive: true });
    for (const [status, items] of [
      ["new", result.new_articles],
      ["updated", result.updated_articles],
    ]) {
      for (const article of items) {
        const filePath = path.join(outputDir, article.filename);
        await fs.writeFile(filePath, markdownFor(article, status), "utf8");
        result.written.push({ status, title: article.title, date: article.date, url: article.url, filename: article.filename, path: filePath, hash: article.content_hash });
      }
    }
    await fs.writeFile(statePath, JSON.stringify(state, null, 2) + "\n", "utf8");
  }

  const output = JSON.stringify(result, null, 2) + "\n";
  if (resultPath) await fs.writeFile(resultPath, output, "utf8");
  process.stdout.write(output);
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
