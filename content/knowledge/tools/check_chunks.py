# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml"]
# ///
"""Validate content/knowledge/**/*.md chunks. Exit code 1 on any error.

Run: uv run python -I content/knowledge/tools/check_chunks.py
"""
import json
import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path

import yaml

KB = Path(__file__).resolve().parents[1]
SOURCES = KB.parent / "sources"
REQUIRED = ["id", "doc_id", "doc_short", "title", "publisher", "date", "pdf_page", "page_label",
            "section", "topics", "keywords", "verify", "original"]
ID_RE = re.compile(r"^(?P<doc>.+)-s(?P<page>\d+)-f(?P<n>\d+)$")
TOKEN = re.compile(r"[^\W\d_]+", re.UNICODE)
NUMBER = re.compile(r"\d+(?:[.,]\d+)?")
COPYRIGHTED = ("erc-", "akademia-")
ORIG_MAX_COPYRIGHTED = 140


def norm(s):
    s = unicodedata.normalize("NFKC", s).lower()
    return s.replace("ł", "l")


def squash(s):
    return re.sub(r"[\W_]+", "", norm(s))


def load_pages(doc):
    pages = {}
    for line in (SOURCES / doc / "pages.jsonl").read_text(encoding="utf-8").split("\n"):
        if line.strip():
            p = json.loads(line)
            pages[p["pdf_page"]] = p["text"]
    return pages


def topics_list():
    out = set()
    for line in (KB / "TOPICS.md").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^- `([a-z0-9-]+)`", line)
        if m:
            out.add(m.group(1))
    return out


def main():
    topics_ok = topics_list()
    errors = []
    per_doc = Counter()
    per_topic = Counter()
    ids = set()
    page_cache = {}
    files = sorted(KB.glob("*/*.md"))
    for f in files:
        rel = f.relative_to(KB)
        def err(msg):
            errors.append(f"{rel}: {msg}")
        raw = f.read_text(encoding="utf-8")
        m = re.match(r"^---\n(.*?)\n---\n(.*)$", raw, re.S)
        if not m:
            err("no front matter")
            continue
        try:
            fm = yaml.safe_load(m.group(1))
        except yaml.YAMLError as e:
            err(f"YAML error: {e}")
            continue
        body = m.group(2).strip()
        missing = [k for k in REQUIRED if k not in fm or fm[k] in (None, "", [])]
        if missing:
            err(f"missing fields {missing}")
            continue
        if fm["verify"] is not True:
            err("verify must be true")
        cid = fm["id"]
        mm = ID_RE.match(cid)
        if not mm:
            err(f"bad id {cid}")
            continue
        if cid != f.stem:
            err(f"id {cid} != filename {f.stem}")
        if f.parent.name != fm["doc_id"] or mm["doc"] != fm["doc_id"]:
            err("doc_id mismatch with id/folder")
        if int(mm["page"]) != fm["pdf_page"]:
            err("pdf_page mismatch with id")
        if cid in ids:
            err("duplicate id")
        ids.add(cid)
        doc = fm["doc_id"]
        if doc not in page_cache:
            if not (SOURCES / doc / "pages.jsonl").exists():
                err("unknown doc")
                continue
            page_cache[doc] = load_pages(doc)
        pages = page_cache[doc]
        if fm["pdf_page"] not in pages:
            err(f"pdf_page {fm['pdf_page']} not in pages.jsonl")
            continue
        page_text = pages[fm["pdf_page"]]
        sq = squash(page_text)
        orig = fm["original"]
        otoks = [t for t in TOKEN.findall(norm(orig)) if len(t) >= 3]
        if not otoks:
            err("original empty")
            continue
        hit = sum(1 for t in otoks if t in sq)
        ratio = hit / len(otoks)
        if ratio < 0.8:
            err(f"original only {ratio:.0%} found on page")
        owords = len(orig.split())
        if doc.startswith(COPYRIGHTED) and owords > ORIG_MAX_COPYRIGHTED:
            err(f"original too long for copyrighted source ({owords} words)")
        bwords = len(body.split())
        min_w = 150 if owords >= 220 else max(15, int(0.7 * owords))
        if bwords < min_w or bwords > 450:
            err(f"body {bwords} words, allowed {min_w}-450 (original {owords})")
        allowed_nums = set(NUMBER.findall(orig)) | set(NUMBER.findall(page_text))
        for n in NUMBER.findall(body):
            if n not in allowed_nums:
                err(f"number {n} in body not found in original or on page")
        bad_t = [t for t in fm["topics"] if t not in topics_ok]
        if bad_t:
            err(f"unknown topics {bad_t}")
        if not (5 <= len(fm["keywords"]) <= 12):
            err(f"keywords count {len(fm['keywords'])} not in 5-12")
        if str(fm["page_label"]) != fm["page_label"]:
            err("page_label must be a string")
        per_doc[doc] += 1
        for t in fm["topics"]:
            per_topic[t] += 1
    print("chunks per document")
    for d, n in sorted(per_doc.items()):
        print(f"  {d}: {n}")
    print("chunks per topic")
    for t in sorted(topics_ok):
        print(f"  {t}: {per_topic.get(t, 0)}")
    unused = [t for t in topics_ok if per_topic.get(t, 0) == 0]
    print(f"total chunks: {len(files)}; topics without chunks: {unused}")
    if errors:
        print(f"\n{len(errors)} ERROR(S)")
        for e in errors:
            print("  " + e)
        sys.exit(1)
    print("OK")


main()
