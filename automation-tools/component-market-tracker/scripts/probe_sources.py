#!/usr/bin/env python3
"""Probe Future Electronics and HQEW public sources for component-market tracking.

This script intentionally uses only Python standard-library modules so scheduled
Codex runs can execute it without installing dependencies.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "config" / "source-map.json"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 Chrome/125 Safari/537.36"
)


class TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.tables: list[list[list[str]]] = []
        self._in_table = False
        self._in_row = False
        self._in_cell = False
        self._cur_table: list[list[str]] = []
        self._cur_row: list[str] = []
        self._cur_cell: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag == "table":
            self._in_table = True
            self._cur_table = []
        elif self._in_table and tag == "tr":
            self._in_row = True
            self._cur_row = []
        elif self._in_table and tag in {"td", "th"}:
            self._in_cell = True
            self._cur_cell = []

    def handle_data(self, data: str) -> None:
        if self._in_cell:
            text = data.strip()
            if text:
                self._cur_cell.append(text)

    def handle_endtag(self, tag: str) -> None:
        if self._in_table and tag in {"td", "th"} and self._in_cell:
            self._cur_row.append(" ".join(self._cur_cell))
            self._in_cell = False
        elif self._in_table and tag == "tr" and self._in_row:
            if self._cur_row:
                self._cur_table.append(self._cur_row)
            self._in_row = False
        elif tag == "table" and self._in_table:
            self.tables.append(self._cur_table)
            self._in_table = False


def taipei_today() -> str:
    tz = dt.timezone(dt.timedelta(hours=8))
    return dt.datetime.now(tz).strftime("%Y-%m-%d")


def sha256_head(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fetch(url: str, max_bytes: int | None = None) -> dict:
    headers = {
        "User-Agent": USER_AGENT,
        "Accept-Language": "zh-TW,zh;q=0.9,en;q=0.7",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,application/pdf;q=0.8,*/*;q=0.7",
    }
    request = urllib.request.Request(url, headers=headers)
    started = time.time()
    result: dict = {"url": url, "ok": False}
    try:
        with urllib.request.urlopen(request, timeout=35, context=ssl.create_default_context()) as response:
            if max_bytes is None:
                data = response.read()
                truncated = False
            else:
                data = response.read(max_bytes + 1)
                truncated = len(data) > max_bytes
                data = data[:max_bytes]
            result.update(
                {
                    "ok": True,
                    "status": getattr(response, "status", None),
                    "final_url": response.geturl(),
                    "seconds": round(time.time() - started, 2),
                    "content_type": response.headers.get("content-type"),
                    "content_length": response.headers.get("content-length"),
                    "last_modified": response.headers.get("last-modified"),
                    "etag": response.headers.get("etag"),
                    "bytes_read": len(data),
                    "truncated": truncated,
                    "sha256": sha256_head(data),
                    "data": data,
                }
            )
    except Exception as exc:  # noqa: BLE001 - probe should record any failure.
        result.update({"error": f"{type(exc).__name__}: {exc}", "seconds": round(time.time() - started, 2)})
    return result


def text_from_bytes(data: bytes, fallback: str = "utf-8") -> str:
    return data.decode(fallback, errors="ignore")


def strip_data(meta: dict) -> dict:
    return {k: v for k, v in meta.items() if k != "data"}


def parse_future_landing(source_html: str, base_url: str) -> dict:
    title = re.search(r"<title>(.*?)</title>", source_html, re.I | re.S)
    last_updated = re.search(r"Last updated:\s*([^<]+(?:<sup>.*?</sup>)?,?\s*\d{4})", source_html, re.I | re.S)
    pdf = re.search(r'href="([^"]*Market-Conditions-Report\.pdf)"', source_html, re.I)
    banner = re.search(r'alt="(Market Conditions Report - [^"]+)"', source_html)
    category_links = sorted(
        set(
            urllib.parse.urljoin(base_url, match)
            for match in re.findall(r'href="(/resources/market-conditions-report/[^"]+)"', source_html)
        )
    )
    clean_updated = None
    if last_updated:
        clean_updated = re.sub(r"<[^>]+>", "", last_updated.group(1))
        clean_updated = html.unescape(re.sub(r"\s+", " ", clean_updated)).strip()
    return {
        "title": html.unescape(title.group(1)).strip() if title else None,
        "banner": html.unescape(banner.group(1)).strip() if banner else None,
        "last_updated": clean_updated,
        "pdf_url": urllib.parse.urljoin(base_url, pdf.group(1)) if pdf else None,
        "category_links": category_links,
    }


def safe_url(url: str) -> str:
    parts = urllib.parse.urlsplit(url)
    path = urllib.parse.quote(parts.path, safe="/")
    query = urllib.parse.quote(parts.query, safe="=&?/:,+%")
    return urllib.parse.urlunsplit((parts.scheme, parts.netloc, path, query, parts.fragment))


def parse_future_category(source_html: str, page_url: str) -> dict:
    images = []
    for title, src in re.findall(r'<img[^>]+title="([^"]*Market Conditions[^"]*)"[^>]+src="([^"]+)"', source_html):
        if "Report - Q" in title:
            continue
        image_url = urllib.parse.urljoin(page_url, src)
        images.append({"title": html.unescape(title), "url": image_url, "safe_url": safe_url(image_url)})
    return {"images": images}


def parse_hqew_fire(source_html: str) -> dict:
    periods = [
        {
            "label": html.unescape(label).strip(),
            "begin": begin,
            "end": end,
        }
        for begin, end, label in re.findall(
            r'data-begindate="([^"]+)"\s+data-enddate="([^"]+)">([^<]+)</option>',
            source_html,
        )
    ]
    parser = TableParser()
    parser.feed(source_html)
    tables = parser.tables

    def normalize_table(rows: list[list[str]]) -> list[dict]:
        if not rows:
            return []
        headers = rows[0]
        out = []
        for idx, row in enumerate(rows[1:], start=1):
            fixed = row + [""] * max(0, len(headers) - len(row))
            item = {headers[i] or f"col_{i}": fixed[i] for i in range(len(headers))}
            if item.get("排名") == "":
                item["排名"] = str(idx)
            out.append(item)
        return out

    return {
        "periods": periods,
        "model_heat_rank": normalize_table(tables[0]) if len(tables) > 0 else [],
        "brand_heat_rank": (normalize_table(tables[1]) if len(tables) > 1 else [])
        + (normalize_table(tables[2]) if len(tables) > 2 else []),
        "category_heat_rank": normalize_table(tables[3]) if len(tables) > 3 else [],
        "category_rising_rank": normalize_table(tables[4]) if len(tables) > 4 else [],
    }


def parse_attrs(tag: str) -> dict:
    return {k: html.unescape(v) for k, v in re.findall(r'([A-Za-z0-9_-]+)="([^"]*)"', tag)}


def parse_hqew_quote(source_html: str) -> dict:
    scale_match = re.search(r"共([\d.]+万条).*?(\d+(?:\.\d+)?万个型号).*?(\d+(?:\.\d+)?万家供应商)", source_html, re.S)
    quote_rows = []
    for tag in re.findall(r'<input class="list-data"[^>]+>', source_html):
        attrs = parse_attrs(tag)
        if not attrs.get("pmodel"):
            continue
        quote_rows.append(
            {
                "model": attrs.get("pmodel"),
                "brand": attrs.get("pproductor"),
                "batch": attrs.get("pproductDate"),
                "package": attrs.get("ppackage"),
                "quote_num": attrs.get("quoteNum"),
                "quotation_price": attrs.get("quotationPrice"),
                "quality": attrs.get("quality"),
                "remark": attrs.get("remark"),
            }
        )
    return {
        "platform_scale": {
            "quotes": scale_match.group(1) if scale_match else None,
            "models": scale_match.group(2) if scale_match else None,
            "suppliers": scale_match.group(3) if scale_match else None,
        },
        "hot_quote_rows": quote_rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", default=taipei_today())
    parser.add_argument("--download-category-images", action="store_true")
    args = parser.parse_args()

    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    raw_dir = ROOT / "runs" / args.date / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    (ROOT / "snapshots").mkdir(exist_ok=True)

    snapshot: dict = {
        "date": args.date,
        "generated_at_taipei": dt.datetime.now(dt.timezone(dt.timedelta(hours=8))).isoformat(),
        "source_health": {},
        "future": {},
        "hqew": {},
    }

    future_page = fetch(config["core_sources"]["future"]["landing_url"])
    snapshot["source_health"]["future_landing"] = strip_data(future_page)
    if future_page.get("ok"):
        landing_html = text_from_bytes(future_page["data"])
        (raw_dir / "future_landing.html").write_text(landing_html, encoding="utf-8")
        future_meta = parse_future_landing(landing_html, config["core_sources"]["future"]["landing_url"])
        snapshot["future"].update(future_meta)

        pdf_url = future_meta.get("pdf_url") or config["core_sources"]["future"]["pdf_url"]
        pdf_probe = fetch(pdf_url, max_bytes=2_000_000)
        snapshot["source_health"]["future_pdf"] = strip_data(pdf_probe)

        categories = {}
        for category_url in future_meta.get("category_links", []):
            slug = category_url.rstrip("/").split("/")[-1]
            page = fetch(category_url)
            snapshot["source_health"][f"future_category_{slug}"] = strip_data(page)
            if not page.get("ok"):
                continue
            category_html = text_from_bytes(page["data"])
            (raw_dir / f"future_category_{slug}.html").write_text(category_html, encoding="utf-8")
            parsed = parse_future_category(category_html, category_url)
            if args.download_category_images:
                for index, image in enumerate(parsed["images"], start=1):
                    image_probe = fetch(image.get("safe_url") or image["url"])
                    image["probe"] = strip_data(image_probe)
                    if image_probe.get("ok"):
                        suffix = ".jpg"
                        raw_image_path = raw_dir / f"future_category_{slug}_{index}{suffix}"
                        raw_image_path.write_bytes(image_probe["data"])
                        image["local_path"] = str(raw_image_path)
            categories[slug] = parsed
        snapshot["future"]["categories"] = categories

    fire = fetch(config["core_sources"]["hqew"]["fire_index_url"])
    snapshot["source_health"]["hqew_fire_index"] = strip_data(fire)
    if fire.get("ok"):
        fire_html = text_from_bytes(fire["data"])
        (raw_dir / "hqew_fire.html").write_text(fire_html, encoding="utf-8")
        snapshot["hqew"]["fire_index"] = parse_hqew_fire(fire_html)

    quote = fetch(config["core_sources"]["hqew"]["cloud_quote_url"])
    snapshot["source_health"]["hqew_cloud_quote"] = strip_data(quote)
    if quote.get("ok"):
        quote_html = text_from_bytes(quote["data"])
        (raw_dir / "hqew_quote.html").write_text(quote_html, encoding="utf-8")
        snapshot["hqew"]["cloud_quote"] = parse_hqew_quote(quote_html)

    out_path = ROOT / "snapshots" / f"{args.date}-source-probe.json"
    out_path.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2), encoding="utf-8")

    fire_period = (
        snapshot.get("hqew", {})
        .get("fire_index", {})
        .get("periods", [{}])[0]
        .get("label")
    )
    print(json.dumps({
        "snapshot": str(out_path),
        "future_last_updated": snapshot.get("future", {}).get("last_updated"),
        "future_pdf_ok": snapshot["source_health"].get("future_pdf", {}).get("ok"),
        "hqew_latest_period": fire_period,
        "hqew_model_rows": len(snapshot.get("hqew", {}).get("fire_index", {}).get("model_heat_rank", [])),
        "hqew_quote_rows": len(snapshot.get("hqew", {}).get("cloud_quote", {}).get("hot_quote_rows", [])),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
