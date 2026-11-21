# /// script
# requires-python = ">=3.10"
# ///
"""Print page text of a source document: dump_pages.py <doc_id> [first] [last]."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "sources"


def main() -> None:
    doc = sys.argv[1]
    lo = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    hi = int(sys.argv[3]) if len(sys.argv) > 3 else 10**6
    for line in (ROOT / doc / "pages.jsonl").read_text(encoding="utf-8").split("\n"):
        if not line.strip():
            continue
        p = json.loads(line)
        if lo <= p["pdf_page"] <= hi:
            print(f"=== PAGE {p['pdf_page']} label={p['page_label']}")
            print(p["text"])


main()
