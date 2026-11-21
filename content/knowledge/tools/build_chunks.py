# /// script
# requires-python = ">=3.10"
# ///
"""Build content/knowledge/<doc_id>/<chunk_id>.md from specs in tools/specs/<doc_id>.py.

Each spec file defines SPECS (list of dicts). The rewritten body is hand-written in the
spec; the `original:` block is cut automatically from pages.jsonl (verbatim words, only
bullet glyphs / line breaks / split words cleaned) so it cannot drift from the source.

Run: uv run python -I content/knowledge/tools/build_chunks.py [doc_id ...]
"""
import json
import re
import runpy
import sys
from collections import Counter
from pathlib import Path

KB = Path(__file__).resolve().parents[1]
SOURCES = KB.parent / "sources"

DOCS = {
    "rcb-poradnik-2025": dict(
        doc_short="Poradnik RCB 2025",
        title="Poradnik bezpieczeństwa (publ. 1/2025)",
        publisher="RCB, MON, MSWiA",
        date="2025-08-28",
    ),
    "erc-2025-pierwsza-pomoc": dict(
        doc_short="ERC 2025 pierwsza pomoc",
        title="Wytyczne ERC 2025 - pierwsza pomoc (rozdział)",
        publisher="Europejska Rada Resuscytacji; Polska Rada Resuscytacji",
        date="2025-10",
    ),
    "erc-2025-kluczowe-pierwsza-pomoc": dict(
        doc_short="ERC 2025 pierwsza pomoc - kluczowe",
        title="Pierwsza pomoc - kluczowe informacje",
        publisher="Europejska Rada Resuscytacji; Polska Rada Resuscytacji",
        date="2025-10",
    ),
    "erc-2025-broszura-resuscytacja-dla-kazdego": dict(
        doc_short="ERC 2025 Resuscytacja dla każdego",
        title="Resuscytacja dla każdego (broszura ERC 2025, wersja polska)",
        publisher="Europejska Rada Resuscytacji; Polska Rada Resuscytacji",
        date="2025",
    ),
    "rcb-powodz-poradnik-2024": dict(
        doc_short="Powódź RCB 2024",
        title="Powódź. Poradnik na wypadek powodzi, wydanie II",
        publisher="Rządowe Centrum Bezpieczeństwa",
        date="2024",
    ),
    "akademia-nim-nadejdzie-dzien": dict(
        doc_short="Nim nadejdzie dzień",
        title="Nim nadejdzie dzień. Poradnik podstaw bezpieczeństwa",
        publisher="Akademia Pożarnicza (Warszawa)",
        date="2025-11",
    ),
    "psp-plecak-ewakuacyjny-lista": dict(
        doc_short="Plecak ewakuacyjny PSP",
        title="Plecak ewakuacyjny - lista kontrolna",
        publisher="Państwowa Straż Pożarna (KW PSP Poznań)",
        date="2025-11-10",
    ),
    "erc-2025-kluczowe-bls": dict(
        doc_short="ERC 2025 RKO dorośli - kluczowe",
        title="Podstawowe zabiegi resuscytacyjne u dorosłych - kluczowe informacje",
        publisher="Europejska Rada Resuscytacji; Polska Rada Resuscytacji",
        date="2025-10",
    ),
    "erc-2025-kluczowe-dzieci": dict(
        doc_short="ERC 2025 RKO dzieci - kluczowe",
        title="Zabiegi resuscytacyjne u dzieci - kluczowe informacje",
        publisher="Europejska Rada Resuscytacji; Polska Rada Resuscytacji",
        date="2025-10",
    ),
}

GLYPH_BULLETS = {"A", "◻", "■", "•", "●", "❍"}
TOKEN = re.compile(r"[^\W\d_]+", re.UNICODE)


def load_pages(doc_id):
    pages = {}
    raw = (SOURCES / doc_id / "pages.jsonl").read_text(encoding="utf-8")
    for line in raw.split("\n"):
        if line.strip():
            p = json.loads(line)
            pages[p["pdf_page"]] = p
    return pages


_GLOBAL = None


def build_vocab(pages=None):
    """Token counts (interior tokens of lines only) over all Polish sources."""
    global _GLOBAL
    if _GLOBAL is None:
        c = Counter()
        for f in sorted(SOURCES.glob("*/pages.jsonl")):
            if f.parent.name.endswith("-en"):
                continue
            for line in f.read_text(encoding="utf-8").split("\n"):
                if not line.strip():
                    continue
                for tl in json.loads(line)["text"].split("\n"):
                    toks = TOKEN.findall(tl.lower())
                    for t in toks[1:-1]:
                        c[t] += 1
        _GLOBAL = c
    return _GLOBAL


def clean(text, vocab, drop_letters=False, keep_lines=False):
    text = text.replace("\ufb01", "fi").replace("\ufb02", "fl")
    lines = []
    pending = False
    pending_num = None
    raw_lines = text.split("\n")
    while raw_lines and (not raw_lines[0].strip() or re.fullmatch(r"\d{1,3}", raw_lines[0].strip())):
        raw_lines.pop(0)
        if raw_lines and re.fullmatch(r"\d{1,3}", raw_lines[0].strip()):
            continue
    for raw in raw_lines:
        s = raw.replace("\t", " ").strip()
        if not s:
            continue
        if re.fullmatch(r"str\.\d+", s):
            continue
        if drop_letters and s in {"A", "B", "C", "D", "F"}:
            continue
        if s in GLYPH_BULLETS:
            pending = True
            continue
        if re.fullmatch(r"\d{1,2}", s) and len(lines) >= 0:
            pending_num = s
            continue
        if pending_num:
            s = pending_num + ". " + s
            pending_num = None
        m = re.match(r"^(?:A|◻|■|●)\s+(.*)$", s)
        if m and (raw.lstrip("\t ").startswith("◻") or len(s.split()) > 1 and s[1:3] == "  "):
            s = m.group(1)
            pending = True
        elif s.startswith("◻"):
            s = s.lstrip("◻").strip()
            pending = True
        if pending:
            s = "- " + s
            pending = False
        lines.append(s)
    # drop leading bare page number
    if lines and re.fullmatch(r"\d{1,3}", lines[0]):
        lines.pop(0)
    out = []
    for s in lines:
        if keep_lines:
            out.append(s)
            continue
        if out and s.startswith("-") and not s.startswith("- ") and len(s) > 1:
            out[-1] = out[-1] + s
            continue
        if out and not s.startswith("- ") and not re.match(r"^\d{1,2}[.\s]", s):
            prev = out[-1]
            first = s[0]
            if first.islower() or (first == "(" and not prev.endswith((".", ":", ";", "!", "?"))):
                if prev.endswith("-") and not prev.endswith(" -") and len(prev) > 1:
                    cand = prev[:-1] + s
                    out[-1] = cand
                    continue
                a = TOKEN.findall(prev.lower())
                b = TOKEN.findall(s.lower())
                joined = False
                if a and b and not prev.endswith((".", ":", ";", "!", "?", ",")):
                    ta, tb = a[-1], b[0]
                    if vocab.get(ta + tb, 0) >= 1 and min(vocab.get(ta, 0), vocab.get(tb, 0)) < 5:
                        out[-1] = prev + s
                        joined = True
                if not joined:
                    out[-1] = prev + " " + s
                continue
        out.append(s)
    return "\n".join(out)


# Split words left by the PDF layout (reviewed by hand against the pages).
FIXES = [
    ("dowie dzieć", "dowiedzieć"), ("aler giczną", "alergiczną"), ("częs totliwości", "częstotliwości"),
    ("uspo kój", "uspokój"), ("dła wiącej", "dławiącej"), ("ła pała", "łapała"),
    ("niebie skawe", "niebieskawe"), ("rozpo znawane", "rozpoznawane"), ("poka zano", "pokazano"),
    ("nienatu ralnie", "nienaturalnie"), ("mimowol ne", "mimowolne"), ("my lony", "mylone"),
    ("tele fonicznie", "telefonicznie"), ("ofia ra", "ofiara"), ("sięgnię cie", "sięgnięcie"),
    ("zloka lizowaniu", "zlokalizowaniu"), ("pro mieniować", "promieniować"),
    ("nie zwłocznym", "niezwłocznym"), ("ta kim", "takim"), ("rozma wiaj", "rozmawiaj"),
    ("moż liwa", "możliwa"), ("Zastosowa nie", "Zastosowanie"), ("jakąkol wiek", "jakąkolwiek"),
    ("licz bie", "liczbie"), ("oddycha nie", "oddychanie"), ("przyklejo nych", "przyklejonych"), ("oddy chaniem", "oddychaniem"),
]


def apply_fixes(text):
    for bad, good in FIXES:
        text = text.replace(bad, good)
    return text


def trim_header(text):
    """Drop running page headers (chapter tag and heading printed twice)."""
    lines = text.split("\n")
    while lines and lines[0] in ("Reagowanie", "Przygotowanie"):
        lines.pop(0)
    if len(lines) > 2 and lines[0] in lines[1:3]:
        lines.pop(0)
    return "\n".join(lines)


def cut(text, start, end):
    if start:
        i = text.find(start)
        if i < 0:
            raise SystemExit(f"start marker not found: {start!r}")
        text = text[i:]
    if end:
        j = text.find(end)
        if j < 0:
            raise SystemExit(f"end marker not found: {end!r}")
        text = text[:j]
    return text.strip()


def yq(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(doc_id, meta, spec, page, orig):
    n = spec.get("n", 1)
    cid = f"{doc_id}-s{spec['page']}-f{n}"
    label = spec.get("label") or page["page_label"] or str(page["pdf_page"])
    fm = [
        "---",
        f"id: {cid}",
        f"doc_id: {doc_id}",
        f"doc_short: {yq(meta['doc_short'])}",
        f"title: {yq(meta['title'])}",
        f"publisher: {yq(meta['publisher'])}",
        f"date: {yq(meta['date'])}",
        f"pdf_page: {spec['page']}",
        f"page_label: {yq(str(label))}",
        f"section: {yq(spec['section'])}",
        "topics: [" + ", ".join(spec["topics"]) + "]",
        "keywords: [" + ", ".join(yq(k) for k in spec["keywords"]) + "]",
        "verify: true",
        "original: |",
    ]
    fm += ["  " + l if l else "" for l in orig.split("\n")]
    fm.append("---")
    return cid, "\n".join(fm) + "\n" + spec["body"].strip() + "\n"


def main():
    only = sys.argv[1:]
    specs_dir = Path(__file__).resolve().parent / "specs"
    for path in sorted(specs_dir.glob("*.py")):
        doc_id = path.stem
        if only and doc_id not in only:
            continue
        meta = DOCS[doc_id]
        pages = load_pages(doc_id)
        vocab = build_vocab(pages)
        specs = runpy.run_path(str(path))["SPECS"]
        outdir = KB / doc_id
        outdir.mkdir(exist_ok=True)
        for old in outdir.glob("*.md"):
            old.unlink()
        for spec in specs:
            page = pages[spec["page"]]
            text = clean(page["text"], vocab, spec.get("drop_letters", False), spec.get("keep_lines", False))
            orig = apply_fixes(cut(trim_header(text), spec.get("start"), spec.get("end")))
            cid, md = render(doc_id, meta, spec, page, orig)
            (outdir / f"{cid}.md").write_text(md, encoding="utf-8")
        print(doc_id, len(specs), "chunks")


if __name__ == "__main__":
    main()
