/// Exact Dart port of `build_match_query` in `tools/kb_normalize.py`.
///
/// Pipeline: normalise -> tokens -> synonym expansion (phrase match of 1..4
/// contiguous tokens, one level; both directions live in the `synonyms` table)
/// -> drop stopwords (query side only) -> stem truncation + `*` prefix ->
/// OR-join. Every emitted token is `[a-z0-9]+` so user input can never inject
/// FTS5 syntax (operators, quotes, parentheses, `NEAR`, `-`).
/// Tokens are lowercase and FTS5 operators are only recognised in UPPERCASE, so the
/// string stays identical to the Python pipeline.
library;

import '../../ratunek/detect/normalize.dart';

/// Prefix length kept for [token] (crude Polish inflection tolerance).
int stemLen(String token) {
  final n = token.length;
  if (n <= 3) return n;
  if (n <= 5) return n - 1;
  return n - 2;
}

/// The stem of a normalised [token] (without the prefix star).
String stemOf(String token) => token.substring(0, stemLen(token));

class QueryBuilder {
  QueryBuilder({
    required this.synonyms,
    required this.stopwords,
    this.maxNgram = 4,
  });

  final Map<String, List<String>> synonyms;
  final Set<String> stopwords;
  final int maxNgram;

  /// Normalised tokens of [query] (no stopword removal).
  static List<String> tokens(String query) {
    final n = normalizePl(query);
    return n.isEmpty ? const [] : n.split(' ');
  }

  /// Tokens of [query] that survive stopword removal (deduplicated, in order).
  List<String> contentTokens(String query) {
    final seen = <String>{};
    return [
      for (final t in tokens(query))
        if (!stopwords.contains(t) && seen.add(t)) t,
    ];
  }

  /// Original tokens plus tokens of every synonym phrase whose term occurs as
  /// a contiguous token sequence in the query.
  List<String> expandTokens(List<String> toks) {
    final result = [...toks];
    for (var n = 1; n <= maxNgram; n++) {
      for (var i = 0; i + n <= toks.length; i++) {
        final syns = synonyms[toks.sublist(i, i + n).join(' ')];
        if (syns == null) continue;
        for (final s in syns) {
          result.addAll(s.split(' ').where((p) => p.isNotEmpty));
        }
      }
    }
    return result;
  }

  /// FTS5 MATCH expression for [query] or null when nothing is left.
  String? build(String query) {
    final seen = <String>{};
    final parts = <String>[];
    for (final tok in expandTokens(tokens(query))) {
      if (stopwords.contains(tok) || !seen.add(tok)) continue;
      final stem = stemOf(tok);
      if (stem.length >= 3) {
        parts.add('$stem*');
      } else {
        parts.add(stem);
      }
    }
    return parts.isEmpty ? null : parts.join(' OR ');
  }
}

/// Parses `stopwords.txt` (one word per line) into a normalised set.
Set<String> parseStopwords(String content) => {
  for (final line in content.split('\n'))
    if (normalizePl(line).isNotEmpty) normalizePl(line),
};
