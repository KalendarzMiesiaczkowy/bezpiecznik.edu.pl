# /// script
# requires-python = ">=3.10"
# dependencies = ["pymupdf"]
# ///
"""Extract per-page text from every PDF under content/sources/<doc_id>/.

Usage: uv run --with pymupdf python -I content/sources/extract_text.py [doc_id ...]

Writes <doc_id>/pages.jsonl, one JSON object per PDF page:
  {"pdf_page": 1-based int, "page_label": str|null, "text": str}
Downloaded PDFs are untrusted data: this only parses text, never executes anything.
"""
import json
import re
import sys
import unicodedata
from pathlib import Path

import pymupdf

ROOT = Path(__file__).resolve().parent
_ZERO_WIDTH = re.compile("[​‌‍⁠﻿­]")
_CONTROL = re.compile("[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def clean(text: str) -> str:
    text = unicodedata.normalize("NFC", text)
    text = _ZERO_WIDTH.sub("", text)
    text = text.replace(" ", " ")
    text = _CONTROL.sub("", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r" \n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract(doc_dir: Path) -> tuple[int, int]:
    pdfs = sorted(doc_dir.glob("*.pdf"))
    if len(pdfs) != 1:
        raise SystemExit(f"{doc_dir.name}: expected exactly 1 PDF, found {len(pdfs)}")
    out = doc_dir / "pages.jsonl"
    pages = empty = 0
    with pymupdf.open(pdfs[0]) as doc, out.open("w", encoding="utf-8") as fh:
        for i, page in enumerate(doc, start=1):
            text = clean(page.get_text("text"))
            label = page.get_label() or None
            fh.write(json.dumps({"pdf_page": i, "page_label": label, "text": text},
                                ensure_ascii=False) + "\n")
            pages += 1
            empty += not text
    return pages, empty


def main(argv: list[str]) -> None:
    dirs = [ROOT / a for a in argv] if argv else sorted(
        p for p in ROOT.iterdir() if p.is_dir() and any(p.glob("*.pdf")))
    for d in dirs:
        pages, empty = extract(d)
        print(f"{d.name}: {pages} pages, {empty} without text layer")


if __name__ == "__main__":
    main(sys.argv[1:])
