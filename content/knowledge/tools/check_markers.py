# /// script
# requires-python = ">=3.10"
# ///
"""Diagnose spec markers: check_markers.py <doc_id>. Lists spec entries whose start/end are missing."""
import runpy
import sys
from pathlib import Path

T = Path(__file__).resolve().parent
g = runpy.run_path(str(T / "build_chunks.py"), run_name="lib")
doc = sys.argv[1]
pages = g["load_pages"](doc)
vocab = g["build_vocab"](pages)
specs = runpy.run_path(str(T / "specs" / f"{doc}.py"))["SPECS"]
for s in specs:
    text = g["trim_header"](g["clean"](pages[s["page"]]["text"], vocab, s.get("drop_letters", False), s.get("keep_lines", False)))
    for k in ("start", "end"):
        if s.get(k) and s[k] not in text:
            print(f"p{s['page']} n{s.get('n', 1)} {k} MISSING: {s[k]!r}")
            if len(sys.argv) > 2:
                print(text)
