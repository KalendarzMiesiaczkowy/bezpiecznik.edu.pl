"""Self-check for content/sources: every SOURCES.md row has its file (or, for files kept out of
git, a sha256), sha256 matches, and pages.jsonl exists, is non-empty and valid.

Usage: python3 -I content/sources/check_sources.py   (exit code 1 on any problem)
"""
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REQUIRED = ["doc_id", "file", "title", "publisher", "date", "url", "downloaded",
            "licence basis", "sha256", "pages", "size", "covers"]


def parse_rows(md: str) -> list[dict[str, str]]:
    rows, header = [], None
    for line in md.splitlines():
        if not line.startswith("|"):
            if header and rows:
                break  # first table only
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            header = cells
        elif set("".join(cells)) <= set("-: "):
            continue
        else:
            rows.append(dict(zip(header, cells)))
    return rows


def main() -> int:
    errors: list[str] = []
    rows = parse_rows((ROOT / "SOURCES.md").read_text(encoding="utf-8"))
    if not rows:
        errors.append("SOURCES.md: no table rows")
    ignored = (ROOT / ".gitignore").read_text(encoding="utf-8")
    for r in rows:
        did = r.get("doc_id", "?")
        for col in REQUIRED:
            if not r.get(col):
                errors.append(f"{did}: empty column '{col}'")
        if not re.fullmatch(r"[0-9a-f]{64}", r.get("sha256", "")):
            errors.append(f"{did}: bad sha256")
        rel = r.get("file", "").strip("`")
        path = ROOT / rel
        if path.is_file():
            if hashlib.sha256(path.read_bytes()).hexdigest() != r.get("sha256"):
                errors.append(f"{did}: sha256 mismatch")
        elif rel not in ignored:  # out-of-git files must be listed in .gitignore
            errors.append(f"{did}: file {rel} missing and not git-ignored")
        pj = ROOT / did / "pages.jsonl"
        if not pj.is_file() or pj.stat().st_size == 0:
            errors.append(f"{did}: pages.jsonl missing or empty")
            continue
        n = with_text = 0
        for i, line in enumerate(pj.open(encoding="utf-8"), start=1):
            rec = json.loads(line)
            if rec.get("pdf_page") != i or "text" not in rec or "page_label" not in rec:
                errors.append(f"{did}: bad record at line {i}")
                break
            n += 1
            with_text += bool(rec["text"].strip())
        if with_text == 0:
            errors.append(f"{did}: no text extracted")
        if str(n) != r.get("pages"):
            errors.append(f"{did}: pages.jsonl has {n} pages, SOURCES.md says {r.get('pages')}")
    for d in sorted(p for p in ROOT.iterdir() if p.is_dir() and any(p.glob("*.pdf"))):
        if not any(r.get("doc_id") == d.name for r in rows):
            errors.append(f"{d.name}: directory not listed in SOURCES.md")
    for e in errors:
        print("ERROR:", e)
    print(f"checked {len(rows)} rows, {len(errors)} problems")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
