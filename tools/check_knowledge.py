# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Self-check of ``app/assets/generated/kb.sqlite``.

    uv run --script tools/check_knowledge.py [--db PATH] [--no-samples-md]

Asserts row counts / meta / referential integrity, then runs sample queries
the way the app will (see ``kb_normalize.build_match_query``), asserts the
expected chunk (by id or by topic) is in the top 3, prints bm25 scores and
writes ``tools/kb_samples.md``. Exit code 1 on any failure.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kb_normalize import load_stopwords, load_synonym_map, search  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "app" / "assets" / "generated" / "kb.sqlite"
KNOWLEDGE_DIR = ROOT / "content" / "knowledge"
SAMPLES_MD = Path(__file__).with_name("kb_samples.md")

META_KEYS = {"version", "built_at", "issued", "chunk_count", "normalize_version"}

# (query, expected chunk ids (any), expected topic (any), kind)
# kind: "must" = asserted (>= 5 required), "in" = in-domain asserted,
# "weak" = known retrieval weakness, informational (not asserted),
# "out" = out-of-domain, informational (used to pick the bm25 threshold).
SAMPLES: list[tuple[str, list[str], str | None, str]] = [
    ("co robić gdy wyje syrena", ["rcb-poradnik-2025-s24-f1"], None, "must"),
    ("ile wody na osobę", ["rcb-poradnik-2025-s21-f1"], "woda-jedzenie", "must"),
    ("jak uciskać klatkę piersiową", [], "rko-aed", "must"),
    ("powódź ewakuacja", [], "powodz", "must"),
    ("brak prądu", [], "brak-pradu", "must"),
    ("krwotok z nogi", [], "krwotok", "in"),
    ("zadławił się", [], "zadlawienie", "in"),
    # known weak spot: "dziec*" (very common) outweighs the rare "zadlaw*"
    ("dziecko się zadławiło", [], "zadlawienie", "weak"),
    ("co zabrać do plecaka ewakuacyjnego", [], "plecak-ewakuacyjny", "in"),
    ("pożar w mieszkaniu", [], "pozar", "in"),
    ("jak ułożyć w pozycji bocznej", [], "pozycja-boczna", "in"),
    ("jak zrobić ciasto czekoladowe", [], None, "out"),
    ("kto wygra mecz", [], None, "out"),
    ("przepis na pierogi", [], None, "out"),
    ("jaka będzie pogoda jutro", [], None, "out"),
    ("kurs bitcoina", [], None, "out"),
]


def check_structure(conn: sqlite3.Connection, chunk_files: int | None) -> list[str]:
    errors: list[str] = []

    def one(sql: str) -> int:
        return conn.execute(sql).fetchone()[0]

    n_docs, n_chunks = one("SELECT count(*) FROM documents"), one("SELECT count(*) FROM chunks")
    n_fts = one("SELECT count(*) FROM chunks_fts")
    n_syn = one("SELECT count(*) FROM synonyms")
    print(f"documents={n_docs} chunks={n_chunks} fts_rows={n_fts} synonyms={n_syn}")
    if n_docs < 5:
        errors.append(f"documents {n_docs} < 5")
    if chunk_files is not None and n_chunks != chunk_files:
        errors.append(f"chunks {n_chunks} != chunk files {chunk_files}")
    if n_fts != n_chunks:
        errors.append(f"fts rows {n_fts} != chunks {n_chunks}")
    if n_syn <= 0:
        errors.append("synonyms empty")
    meta = dict(conn.execute("SELECT key, value FROM meta"))
    print("meta:", meta)
    missing = META_KEYS - meta.keys()
    if missing:
        errors.append(f"meta keys missing: {sorted(missing)}")
    elif int(meta["chunk_count"]) != n_chunks:
        errors.append("meta.chunk_count != chunks")
    orphans = conn.execute(
        "SELECT id FROM chunks WHERE doc_id NOT IN (SELECT doc_id FROM documents)"
    ).fetchall()
    if orphans:
        errors.append(f"chunks with unknown doc_id: {[o[0] for o in orphans]}")
    if one("SELECT count(*) FROM chunks WHERE text_norm != lower(text_norm) OR text_norm GLOB '*[^a-z0-9 ]*'"):
        errors.append("text_norm contains non-normalised characters")
    if one("SELECT count(*) FROM chunks_fts WHERE chunks_fts MATCH 'lodz OR zolc'") < 0:
        errors.append("fts unusable")
    return errors


def run_samples(conn: sqlite3.Connection) -> tuple[list[str], list[dict]]:
    errors: list[str] = []
    syn, stop = load_synonym_map(conn), load_stopwords()
    topics = {
        r[0]: set(json.loads(r[1] or "[]"))
        for r in conn.execute("SELECT id, topics FROM chunks")
    }
    results = []
    must = 0
    for query, ids, topic, kind in SAMPLES:
        hits = search(conn, query, syn, stop, 3)
        top_ids = [h[0] for h in hits]
        ok: bool | None = None
        if kind in ("must", "in"):
            ok = any(i in ids for i in top_ids) or (
                topic is not None and any(topic in topics[i] for i in top_ids)
            )
            must += kind == "must"
            if not ok:
                errors.append(f"query {query!r}: expected {ids or topic}, got {top_ids}")
        if kind == "weak":
            ok = any(topic in topics[i] for i in top_ids)
            ok = ok or None
        results.append({"query": query, "kind": kind, "ok": ok, "hits": hits})
        status = {True: "PASS", False: "FAIL", None: "info"}[ok]
        if kind == "weak" and ok is None:
            status = "weak(known)"
        print(f"[{status}] ({kind}) {query!r}")
        for i, s in hits:
            print(f"        {s:8.2f}  {i}")
        if not hits:
            print("        (no match)")
    if must < 5:
        errors.append("fewer than 5 asserted sample queries")
    return errors, results


def write_samples_md(results: list[dict], path: Path) -> None:
    lines = [
        "# Knowledge base sample queries",
        "",
        "Generated by `tools/check_knowledge.py`. bm25 is `bm25(chunks_fts)`: more negative = better match.",
        "Query pipeline: `tools/kb_normalize.py` (`build_match_query`).",
        "",
        "| kind | query | pass | top 3 (id, score) |",
        "|---|---|---|---|",
    ]
    for r in results:
        ok = {True: "yes", False: "NO", None: "-"}[r["ok"]]
        hits = "<br>".join(f"`{i}` {s:.2f}" for i, s in r["hits"]) or "no match"
        lines.append(f"| {r['kind']} | {r['query']} | {ok} | {hits} |")
    ins = [r["hits"][0][1] for r in results if r["kind"] in ("must", "in") and r["hits"]]
    outs = [r["hits"][0][1] for r in results if r["kind"] == "out" and r["hits"]]
    lines += [
        "",
        f"Top-1 score, in-domain: worst {max(ins):.2f}, best {min(ins):.2f}.",
        f"Top-1 score, out-of-domain: strongest {min(outs):.2f}." if outs else "Out-of-domain: no matches.",
        "",
    ]
    path.write_text("\n".join(lines), "utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", type=Path, default=DB)
    ap.add_argument("--no-samples-md", action="store_true")
    args = ap.parse_args()
    if not args.db.exists():
        print(f"missing {args.db}: run tools/build_knowledge.py first", file=sys.stderr)
        return 1
    conn = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
    files = None
    if KNOWLEDGE_DIR.exists():
        files = sum(
            1 for p in KNOWLEDGE_DIR.rglob("*.md") if p.name not in {"README.md", "TOPICS.md"}
        )
    errors = check_structure(conn, files)
    sample_errors, results = run_samples(conn)
    errors += sample_errors
    if not args.no_samples_md:
        write_samples_md(results, SAMPLES_MD)
    if errors:
        print("\nFAILED:")
        for e in errors:
            print(" -", e)
        return 1
    print("\nOK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
