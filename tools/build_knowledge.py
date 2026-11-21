# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Build ``app/assets/generated/kb.sqlite`` (knowledge base) in one command.

    uv run --script tools/build_knowledge.py

Inputs: ``content/knowledge/**/*.md`` (chunk files, README/TOPICS skipped),
``content/knowledge/synonyms.tsv`` and the documents table in
``content/sources/SOURCES.md``. Schema: ``bezpiecznik/04-dane/kontrakty-tresci.md``
section "Baza wiedzy", plus extra ``chunks`` columns used by the app:
``original`` (verbatim passage for quote panel / validator), ``topics`` and
``keywords`` (JSON arrays), ``verify`` (0/1).

Indexing rule: ``text_norm = normalize(chapter + ' ' + text + ' ' + keywords)``
where ``chapter`` is the front-matter ``section``. Keywords (which contain
colloquial phrasings such as "wyje syrena") are indexed so informal queries
find the chunk; ``text`` itself stays the rewritten body only. Stopwords are
never applied at indexing time.

The file is built under a temporary name next to the target and renamed
atomically. ``meta``: version, built_at, issued (build date), chunk_count,
normalize_version.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import sqlite3
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kb_normalize import NORMALIZE_VERSION, normalize  # noqa: E402

KB_VERSION = 1  # bump when content or schema changes

ROOT = Path(__file__).resolve().parent.parent
KNOWLEDGE_DIR = ROOT / "content" / "knowledge"
SOURCES_MD = ROOT / "content" / "sources" / "SOURCES.md"
OUT = ROOT / "app" / "assets" / "generated" / "kb.sqlite"

SKIP_NAMES = {"README.md", "TOPICS.md"}

SCHEMA = """
CREATE TABLE documents (
  doc_id     TEXT PRIMARY KEY,
  title      TEXT NOT NULL,
  short      TEXT NOT NULL,
  publisher  TEXT NOT NULL,
  issued     TEXT NOT NULL,
  pdf_file   TEXT NOT NULL,
  pdf_sha256 TEXT NOT NULL
);

CREATE TABLE chunks (
  id         TEXT PRIMARY KEY,
  doc_id     TEXT NOT NULL REFERENCES documents(doc_id),
  page_label TEXT NOT NULL,
  pdf_page   INTEGER NOT NULL,
  chapter    TEXT,
  text       TEXT NOT NULL,
  text_norm  TEXT NOT NULL,
  rects      TEXT,
  original   TEXT,
  topics     TEXT,
  keywords   TEXT,
  verify     INTEGER
);

CREATE VIRTUAL TABLE chunks_fts USING fts5(
  text_norm,
  content = 'chunks', content_rowid = 'rowid',
  tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TABLE synonyms (
  term    TEXT NOT NULL,
  synonym TEXT NOT NULL,
  PRIMARY KEY (term, synonym)
);

CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
"""

_FRONT = re.compile(r"\A---\n(.*?)\n---\n(.*)\Z", re.DOTALL)
_ISSUED = re.compile(r"\d{4}(?:-\d{2})?")


def parse_chunk(text: str, path: str = "<chunk>") -> dict:
    """Parse one chunk file (YAML front matter + rewritten body)."""
    m = _FRONT.match(text)
    if not m:
        raise ValueError(f"{path}: no YAML front matter")
    meta = yaml.safe_load(m.group(1))
    if not isinstance(meta, dict):
        raise ValueError(f"{path}: front matter is not a mapping")
    for key in ("id", "doc_id", "pdf_page", "page_label"):
        if key not in meta:
            raise ValueError(f"{path}: missing front matter key {key!r}")
    body = m.group(2).strip()
    if not body:
        raise ValueError(f"{path}: empty body")
    return {
        "id": str(meta["id"]),
        "doc_id": str(meta["doc_id"]),
        "doc_short": str(meta.get("doc_short") or ""),
        "page_label": str(meta["page_label"]),
        "pdf_page": int(meta["pdf_page"]),
        "chapter": meta.get("section"),
        "text": body,
        "original": (meta.get("original") or "").strip() or None,
        "topics": list(meta.get("topics") or []),
        "keywords": [str(k) for k in (meta.get("keywords") or [])],
        "verify": 1 if meta.get("verify", True) else 0,
    }


def index_text(chunk: dict) -> str:
    """The string that is normalised and fed to FTS (see module docstring)."""
    return normalize(
        " ".join(
            [chunk["chapter"] or "", chunk["text"], " ".join(chunk["keywords"])]
        )
    )


def load_chunks(knowledge_dir: Path) -> list[dict]:
    chunks = []
    for p in sorted(knowledge_dir.rglob("*.md")):
        if p.name in SKIP_NAMES:
            continue
        chunks.append(parse_chunk(p.read_text("utf-8"), str(p)))
    ids = [c["id"] for c in chunks]
    dup = {i for i in ids if ids.count(i) > 1}
    if dup:
        raise ValueError(f"duplicate chunk ids: {sorted(dup)}")
    return sorted(chunks, key=lambda c: c["id"])


def parse_sources(md: str) -> dict[str, dict]:
    """Documents table of SOURCES.md -> {doc_id: row}."""
    docs: dict[str, dict] = {}
    header: list[str] | None = None
    for line in md.splitlines():
        if not line.startswith("|"):
            if header and docs:
                break  # first table ended
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if header is None:
            if cells and cells[0] == "doc_id":
                header = cells
            continue
        if set(line.replace("|", "").strip()) <= {"-", " ", ":"}:
            continue
        row = dict(zip(header, cells))
        doc_id = row["doc_id"]
        m = _ISSUED.search(row.get("date", ""))
        docs[doc_id] = {
            "doc_id": doc_id,
            "title": row["title"],
            "publisher": row["publisher"],
            "issued": m.group(0) if m else "",
            "pdf_file": row["file"].strip("`"),
            "pdf_sha256": row["sha256"],
        }
    return docs


def load_synonym_pairs(tsv: str) -> set[tuple[str, str]]:
    """Normalised pairs, both directions, no self pairs."""
    pairs: set[tuple[str, str]] = set()
    for line in tsv.splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        cols = line.split("\t")
        if len(cols) < 2:
            continue
        a, b = normalize(cols[0]), normalize(cols[1])
        if a and b and a != b:
            pairs.add((a, b))
            pairs.add((b, a))
    return pairs


def build(
    out: Path,
    chunks: list[dict],
    documents: dict[str, dict],
    synonym_pairs: set[tuple[str, str]],
    *,
    version: int = KB_VERSION,
    now: dt.datetime | None = None,
) -> dict[str, int]:
    """Write the database atomically; returns row counts."""
    now = now or dt.datetime.now(dt.timezone.utc)
    shorts: dict[str, str] = {}
    for c in chunks:
        shorts.setdefault(c["doc_id"], c["doc_short"])
    used = sorted({c["doc_id"] for c in chunks})
    missing = [d for d in used if d not in documents]
    if missing:
        raise ValueError(f"chunks reference documents missing in SOURCES.md: {missing}")

    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_name(out.name + f".tmp{os.getpid()}")
    tmp.unlink(missing_ok=True)
    try:
        conn = sqlite3.connect(tmp)
        conn.executescript(SCHEMA)
        conn.executemany(
            "INSERT INTO documents VALUES (?,?,?,?,?,?,?)",
            [
                (
                    d,
                    documents[d]["title"],
                    shorts[d] or documents[d]["title"],
                    documents[d]["publisher"],
                    documents[d]["issued"],
                    documents[d]["pdf_file"],
                    documents[d]["pdf_sha256"],
                )
                for d in used
            ],
        )
        conn.executemany(
            "INSERT INTO chunks (id, doc_id, page_label, pdf_page, chapter, text, "
            "text_norm, rects, original, topics, keywords, verify) "
            "VALUES (?,?,?,?,?,?,?,NULL,?,?,?,?)",
            [
                (
                    c["id"], c["doc_id"], c["page_label"], c["pdf_page"],
                    c["chapter"], c["text"], index_text(c), c["original"],
                    json.dumps(c["topics"], ensure_ascii=False),
                    json.dumps(c["keywords"], ensure_ascii=False),
                    c["verify"],
                )
                for c in chunks
            ],
        )
        conn.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')")
        conn.executemany(
            "INSERT INTO synonyms VALUES (?,?)", sorted(synonym_pairs)
        )
        conn.executemany(
            "INSERT INTO meta VALUES (?,?)",
            [
                ("version", str(version)),
                ("built_at", now.isoformat(timespec="seconds")),
                ("issued", now.date().isoformat()),
                ("chunk_count", str(len(chunks))),
                ("normalize_version", str(NORMALIZE_VERSION)),
            ],
        )
        conn.commit()
        counts = {
            "documents": conn.execute("SELECT count(*) FROM documents").fetchone()[0],
            "chunks": conn.execute("SELECT count(*) FROM chunks").fetchone()[0],
            "synonyms": conn.execute("SELECT count(*) FROM synonyms").fetchone()[0],
        }
        conn.execute("VACUUM")
        conn.close()
        os.replace(tmp, out)
    finally:
        tmp.unlink(missing_ok=True)
    return counts


def main() -> int:
    chunks = load_chunks(KNOWLEDGE_DIR)
    documents = parse_sources(SOURCES_MD.read_text("utf-8"))
    pairs = load_synonym_pairs((KNOWLEDGE_DIR / "synonyms.tsv").read_text("utf-8"))
    counts = build(OUT, chunks, documents, pairs)
    unused = sorted(set(documents) - {c["doc_id"] for c in chunks})
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")
    print(f"version={KB_VERSION} " + " ".join(f"{k}={v}" for k, v in counts.items()))
    if unused:
        print(f"documents without chunks (not stored): {', '.join(unused)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
