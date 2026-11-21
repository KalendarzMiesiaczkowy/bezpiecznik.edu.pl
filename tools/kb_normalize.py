"""Shared helpers for the knowledge base build and its checks.

``normalize()`` is a line-by-line port of ``normalizePl`` in
``app/lib/ratunek/detect/normalize.dart`` (contract: lowercase, fold Latin
diacritics to ASCII incl. l-stroke -> l, drop combining marks U+0300..U+036F,
every other char outside [a-z0-9] becomes a space, collapse and trim).
Shared vectors: ``app/test/ratunek/detect/normalize_vectors.json``.

Query building (``build_match_query``) is what the app must reproduce:
normalise -> tokens -> synonym expansion (phrase match on the full normalised
query, one level, both directions are stored in ``synonyms``) -> drop
stopwords (``tools/kb_stopwords.txt``, query side only, never at indexing) ->
stem-truncate + prefix star -> OR-join. Rank with ``bm25(chunks_fts)``
(lower, i.e. more negative, is better).
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

NORMALIZE_VERSION = 1

_FOLD = {
    "ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n", "ó": "o", "ś": "s",
    "ź": "z", "ż": "z", "à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a",
    "å": "a", "ā": "a", "ă": "a", "ç": "c", "č": "c", "ď": "d", "đ": "d",
    "è": "e", "é": "e", "ê": "e", "ë": "e", "ē": "e", "ė": "e", "ě": "e",
    "ğ": "g", "ì": "i", "í": "i", "î": "i", "ï": "i", "ī": "i", "ı": "i",
    "ĺ": "l", "ľ": "l", "ñ": "n", "ň": "n", "ò": "o", "ô": "o", "õ": "o",
    "ö": "o", "ø": "o", "ō": "o", "ő": "o", "ř": "r", "ş": "s", "š": "s",
    "ť": "t", "ù": "u", "ú": "u", "û": "u", "ü": "u", "ū": "u", "ů": "u",
    "ű": "u", "ý": "y", "ÿ": "y", "ß": "ss", "æ": "ae", "œ": "oe",
}

STOPWORDS_FILE = Path(__file__).with_name("kb_stopwords.txt")


def normalize(text: str) -> str:
    out: list[str] = []
    pending_space = False
    for ch in text.lower():
        if 0x300 <= ord(ch) <= 0x36F:
            continue
        for c in _FOLD.get(ch, ch):
            if ("a" <= c <= "z") or ("0" <= c <= "9"):
                if pending_space and out:
                    out.append(" ")
                pending_space = False
                out.append(c)
            else:
                pending_space = True
    return "".join(out)


def load_stopwords(path: Path = STOPWORDS_FILE) -> frozenset[str]:
    return frozenset(
        w for w in (normalize(l) for l in path.read_text("utf-8").splitlines()) if w
    )


def stem_len(token: str) -> int:
    """Prefix length kept for a token (crude Polish inflection tolerance)."""
    n = len(token)
    if n <= 3:
        return n
    if n <= 5:
        return n - 1
    return n - 2


def load_synonym_map(conn: sqlite3.Connection) -> dict[str, list[str]]:
    m: dict[str, list[str]] = {}
    for term, syn in conn.execute("SELECT term, synonym FROM synonyms ORDER BY term, synonym"):
        m.setdefault(term, []).append(syn)
    return m


def expand_tokens(
    tokens: list[str], syn: dict[str, list[str]], max_ngram: int = 4
) -> list[str]:
    """Original tokens plus tokens of every synonym phrase whose term occurs
    as a contiguous token sequence in the query."""
    result = list(tokens)
    for n in range(1, max_ngram + 1):
        for i in range(len(tokens) - n + 1):
            for s in syn.get(" ".join(tokens[i : i + n]), ()):
                result.extend(s.split())
    return result


def build_match_query(
    query: str, syn: dict[str, list[str]], stopwords: frozenset[str]
) -> str | None:
    """FTS5 MATCH expression for ``query`` or None when nothing is left."""
    tokens = normalize(query).split()
    seen: set[str] = set()
    parts: list[str] = []
    for tok in expand_tokens(tokens, syn):
        if tok in stopwords or tok in seen:
            continue
        seen.add(tok)
        stem = tok[: stem_len(tok)]
        parts.append(f"{stem}*" if len(stem) >= 3 else stem)
    return " OR ".join(parts) if parts else None


def search(
    conn: sqlite3.Connection,
    query: str,
    syn: dict[str, list[str]],
    stopwords: frozenset[str],
    limit: int = 3,
) -> list[tuple[str, float]]:
    match = build_match_query(query, syn, stopwords)
    if match is None:
        return []
    rows = conn.execute(
        "SELECT c.id, bm25(chunks_fts) AS score FROM chunks_fts "
        "JOIN chunks c ON c.rowid = chunks_fts.rowid "
        "WHERE chunks_fts MATCH ? ORDER BY score LIMIT ?",
        (match, limit),
    ).fetchall()
    return [(r[0], r[1]) for r in rows]
