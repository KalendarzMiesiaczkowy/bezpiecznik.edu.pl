# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]  # imported by build_knowledge (parse_sources)
# ///
"""Copy the readable source guides (PDF) into the app and write their manifest.

    uv run --script tools/build_guides.py

Output, both git-ignored like the other generated assets:

* ``app/assets/generated/guide-<doc_id>.pdf`` (flat: Flutter does not bundle
  sub-directories of an asset directory),
* ``app/assets/generated/guides.json``: ``{"version": 1, "guides": [{id,
  title, publisher, year, pages, bytes, file}]}`` in reading order.

Only the guides written for the public are bundled (``GUIDES`` below). The
long professional ERC guideline chapters and the English handbook stay out:
they would double the size of the APK. Every guide must be a document of
``content/sources/SOURCES.md``; the page count comes from ``pages.jsonl``.
Nothing is downloaded.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_knowledge import parse_sources  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "content" / "sources"
OUT = ROOT / "app" / "assets" / "generated"

# Reading order: general guide first, then by situation, then first aid.
# (doc_id, title, publisher, year): the names shown in the app, as printed on
# the documents; SOURCES.md carries editorial notes in those columns. The
# flood leaflet is undated (its PDF metadata says 2010), so it gets no year.
GUIDES = [
    ("rcb-poradnik-2025", "Poradnik bezpieczeństwa", "RCB, MON, MSWiA", "2025"),
    ("akademia-nim-nadejdzie-dzien", "Nim nadejdzie dzień. Poradnik podstaw bezpieczeństwa",
     "Akademia Pożarnicza", "2025"),
    ("psp-kompendium-poradnik-2025", "Poradnik bezpieczeństwa: kompendium wiedzy",
     "Państwowa Straż Pożarna", "2025"),
    ("rcb-powodz-poradnik-2024", "Powódź. Poradnik na wypadek powodzi",
     "Rządowe Centrum Bezpieczeństwa", "2024"),
    ("psp-powodz-ulotka", "W obliczu powodzi (ulotka)", "Komenda Główna PSP", None),
    ("psp-plecak-ewakuacyjny-lista", "Plecak ewakuacyjny: lista kontrolna",
     "Państwowa Straż Pożarna", "2025"),
    ("erc-2025-broszura-resuscytacja-dla-kazdego", "Resuscytacja dla każdego",
     "Europejska i Polska Rada Resuscytacji", "2025"),
    ("erc-2025-kluczowe-pierwsza-pomoc", "Pierwsza pomoc: kluczowe informacje",
     "Europejska i Polska Rada Resuscytacji", "2025"),
    ("erc-2025-kluczowe-bls", "Resuscytacja dorosłych: kluczowe informacje",
     "Europejska i Polska Rada Resuscytacji", "2025"),
    ("erc-2025-kluczowe-dzieci", "Resuscytacja dzieci: kluczowe informacje",
     "Europejska i Polska Rada Resuscytacji", "2025"),
]


def main() -> int:
    documents = parse_sources((SOURCES / "SOURCES.md").read_text("utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    for stale in OUT.glob("guide-*.pdf"):
        stale.unlink()

    guides = []
    for doc_id, title, publisher, year in GUIDES:
        if doc_id not in documents:
            print(f"unknown doc_id in SOURCES.md: {doc_id}", file=sys.stderr)
            return 1
        pdfs = sorted((SOURCES / doc_id).glob("*.pdf"))
        if len(pdfs) != 1:
            print(f"{doc_id}: expected one PDF, found {len(pdfs)}", file=sys.stderr)
            return 1
        pages_file = SOURCES / doc_id / "pages.jsonl"
        pages = sum(1 for line in pages_file.read_text("utf-8").splitlines() if line.strip())
        name = f"guide-{doc_id}.pdf"
        shutil.copyfile(pdfs[0], OUT / name)
        guides.append({
            "id": doc_id,
            "title": title,
            "publisher": publisher,
            "year": year,
            "pages": pages,
            "bytes": pdfs[0].stat().st_size,
            "file": name,
        })

    (OUT / "guides.json").write_text(
        json.dumps({"version": 1, "guides": guides}, ensure_ascii=False, indent=2) + "\n", "utf-8"
    )
    total = sum(g["bytes"] for g in guides)
    print(f"wrote {len(guides)} guides, {total / 1e6:.1f} MB, to {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
