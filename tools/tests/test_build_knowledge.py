"""Tests for tools/build_knowledge.py and tools/kb_normalize.py."""

from __future__ import annotations

import datetime as dt
import json
import re
import sqlite3
import sys
from pathlib import Path

import pytest

TOOLS = Path(__file__).resolve().parent.parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))

import build_knowledge as bk  # noqa: E402
import kb_normalize as kn  # noqa: E402

VECTORS = ROOT / "app" / "test" / "ratunek" / "detect" / "normalize_vectors.json"
DART = ROOT / "app" / "lib" / "ratunek" / "detect" / "normalize.dart"


def test_shared_vectors():
    vectors = json.loads(VECTORS.read_text("utf-8"))["vectors"]
    assert len(vectors) > 20
    for v in vectors:
        assert kn.normalize(v["input"]) == v["expected"], v["input"]


def test_fold_table_matches_dart():
    dart = dict(re.findall(r"'(.)': '(\w+)',", DART.read_text("utf-8")))
    assert dart == kn._FOLD


CHUNK_A = """---
id: doc-a-2025-s1-f1
doc_id: doc-a-2025
doc_short: "Dok A"
title: "Dokument A"
publisher: "Wydawca"
date: "2025-08-28"
pdf_page: 3
page_label: "1"
section: "Łódź: Powódź"
topics: [powodz]
keywords: ["zalało", "woda w piwnicy"]
verify: true
original: |
  Oryginalny tekst.
  Druga linia.
---
Gdy woda zalewa piwnicę, wyłącz prąd i uciekaj na wyższe piętro.
"""

CHUNK_B = """---
id: doc-a-2025-s2-f1
doc_id: doc-a-2025
doc_short: "Dok A"
pdf_page: 4
page_label: "2"
section: "Ewakuacja"
topics: []
keywords: ["plecak"]
verify: true
original: |
  Skrót.
---
Spakuj plecak ewakuacyjny z dokumentami.
"""

SOURCES = """# Sources

| doc_id | file | title | publisher | date | sha256 |
|---|---|---|---|---|---|
| doc-a-2025 | `doc-a-2025/a.pdf` | Dokument A | Wydawca | 2025-08-28 (PDF built 2025-08-27) | abc123 |
| doc-b | `doc-b/b.pdf` | Dokument B | Inny | ERC 2025-10; PL PDF 2026-07-10 | def456 |

## Missing
"""


def test_parse_chunk_front_matter():
    c = bk.parse_chunk(CHUNK_A)
    assert c["id"] == "doc-a-2025-s1-f1"
    assert c["pdf_page"] == 3 and c["page_label"] == "1"
    assert c["chapter"] == "Łódź: Powódź"
    assert c["topics"] == ["powodz"]
    assert c["keywords"] == ["zalało", "woda w piwnicy"]
    assert c["original"] == "Oryginalny tekst.\nDruga linia."
    assert c["text"].startswith("Gdy woda")
    assert c["verify"] == 1


def test_parse_chunk_errors():
    with pytest.raises(ValueError):
        bk.parse_chunk("no front matter")
    with pytest.raises(ValueError):
        bk.parse_chunk("---\nid: x\n---\nbody\n")


def test_parse_sources():
    docs = bk.parse_sources(SOURCES)
    assert set(docs) == {"doc-a-2025", "doc-b"}
    assert docs["doc-a-2025"]["issued"] == "2025-08"
    assert docs["doc-a-2025"]["pdf_file"] == "doc-a-2025/a.pdf"
    assert docs["doc-a-2025"]["pdf_sha256"] == "abc123"
    assert docs["doc-b"]["issued"] == "2025-10"


def test_synonym_pairs_both_directions_normalised():
    pairs = bk.load_synonym_pairs("# c\nprąd\tEnergia Elektryczna\nsame\tsame\n\n")
    assert pairs == {("prad", "energia elektryczna"), ("energia elektryczna", "prad")}


@pytest.fixture()
def db(tmp_path):
    chunks = [bk.parse_chunk(CHUNK_A), bk.parse_chunk(CHUNK_B)]
    docs = bk.parse_sources(SOURCES)
    pairs = bk.load_synonym_pairs("zalało\twoda\nprąd\telektryczność\n")
    out = tmp_path / "gen" / "kb.sqlite"
    now = dt.datetime(2026, 1, 2, 3, 4, 5, tzinfo=dt.timezone.utc)
    counts = bk.build(out, chunks, docs, pairs, version=7, now=now)
    assert counts == {"documents": 1, "chunks": 2, "synonyms": 4}
    assert [p.name for p in out.parent.iterdir()] == ["kb.sqlite"]  # no temp left
    conn = sqlite3.connect(out)
    yield conn
    conn.close()


def test_meta_and_columns(db):
    meta = dict(db.execute("SELECT key, value FROM meta"))
    assert meta["version"] == "7"
    assert meta["built_at"] == "2026-01-02T03:04:05+00:00"
    assert meta["chunk_count"] == "2"
    assert meta["normalize_version"] == str(kn.NORMALIZE_VERSION)
    row = db.execute(
        "SELECT chapter, original, topics, keywords, verify, rects FROM chunks WHERE id = ?",
        ("doc-a-2025-s1-f1",),
    ).fetchone()
    assert row[0] == "Łódź: Powódź" and row[1].startswith("Oryginalny")
    assert json.loads(row[2]) == ["powodz"]
    assert json.loads(row[3]) == ["zalało", "woda w piwnicy"]
    assert row[4] == 1 and row[5] is None
    assert db.execute("SELECT short FROM documents").fetchone()[0] == "Dok A"


def test_text_norm_includes_chapter_keywords(db):
    norm = db.execute(
        "SELECT text_norm FROM chunks WHERE id = 'doc-a-2025-s1-f1'"
    ).fetchone()[0]
    assert norm.startswith("lodz powodz gdy woda zalewa piwnice")
    assert norm.endswith("zalalo woda w piwnicy")


def test_fts_query_with_l_and_missing_diacritics(db):
    syn, stop = kn.load_synonym_map(db), kn.load_stopwords()
    for q in ("łódź", "lodz", "LODZ powodz", "powódź"):
        hits = kn.search(db, q, syn, stop)
        assert hits and hits[0][0] == "doc-a-2025-s1-f1", q
    hits = kn.search(db, "co zrobić z plecaka", syn, stop)
    assert hits[0][0] == "doc-a-2025-s2-f1"
    assert kn.search(db, "jak i co", syn, stop) == []  # only stopwords


def test_synonym_expansion(db):
    syn, stop = kn.load_synonym_map(db), kn.load_stopwords()
    assert "woda" in syn["zalalo"] and "zalalo" in syn["woda"]
    q = kn.build_match_query("prąd", syn, stop)
    assert q == "pra* OR elektryczno*"  # elektrycznosc only via the synonym
    assert kn.build_match_query("zalało", syn, stop) == "zala* OR wod*"
    hits = kn.search(db, "elektryczność", syn, stop)  # chunk says "prąd"
    assert hits[0][0] == "doc-a-2025-s1-f1"


def test_stopwords_keep_negation():
    stop = kn.load_stopwords()
    assert "nie" not in stop and {"jak", "co", "gdy", "sie", "na", "w", "z", "i"} <= stop


def test_unknown_document_rejected(tmp_path):
    chunk = bk.parse_chunk(CHUNK_A)
    with pytest.raises(ValueError):
        bk.build(tmp_path / "kb.sqlite", [chunk], {}, set())
    assert list(tmp_path.iterdir()) == []


def test_real_content_parses():
    chunks = bk.load_chunks(ROOT / "content" / "knowledge")
    assert len(chunks) > 50
    assert all(c["original"] and c["keywords"] for c in chunks)
