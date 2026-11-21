/// Local FTS5 retrieval over the knowledge base plus the refusal decision.
library;

import 'dart:convert';

import '../../ratunek/detect/normalize.dart';
import 'kb_database.dart';
import 'query_builder.dart';

/// Default bm25 floor: a best score above (i.e. weaker than) this value means
/// "no source". bm25 in SQLite is negative, more negative = better.
///
/// Rationale (`tools/kb_samples.md`): in-domain top-1 scores range from -2.13
/// ("ile wody na osobę") to -29.84; out-of-domain top-1 scores reach -5.43
/// ("kto wygra mecz"). The ranges overlap, so the score alone cannot separate
/// them: this floor only discards near-zero noise and the domain-vocabulary
/// gate ([Retriever.isDomainQuery]) does the off-topic separation.
const double kDefaultBm25Floor = -1.5;

/// Default number of chunks returned.
const int kDefaultTopK = 4;

/// Words that occur in chunk keywords but are ambiguous on their own
/// (event/weather smalltalk): they are removed from the domain vocabulary so
/// that "kto wygra mecz" and "pogoda jutro" are off-topic. A compound query
/// such as "alert pogodowy" is still in-domain through "alert". Normalised.
const Set<String> kAmbiguousDomainWords = {
  'mecz',
  'koncert',
  'pogoda',
  'pogody',
  'pogodowy',
  'pogodowe',
  'prognoza',
};

enum RetrievalDecision { found, noSource, offTopic }

/// One knowledge chunk with its document metadata.
class KbChunk {
  const KbChunk({
    required this.id,
    required this.docId,
    required this.docShort,
    required this.title,
    required this.publisher,
    required this.pageLabel,
    required this.pdfPage,
    required this.chapter,
    required this.text,
    required this.original,
    required this.topics,
    required this.verify,
    required this.score,
  });

  final String id;
  final String docId;
  final String docShort;
  final String title;
  final String publisher;
  final String pageLabel;
  final int pdfPage;
  final String? chapter;
  final String text;
  final String? original;
  final List<String> topics;
  final bool verify;

  /// bm25 (negative, lower is better); 0 when not produced by a ranked search.
  final double score;
}

class RetrievalResult {
  const RetrievalResult({
    required this.decision,
    required this.chunks,
    this.matchQuery,
  });

  final RetrievalDecision decision;

  /// Best first. Non-empty only when [decision] is [RetrievalDecision.found]
  /// (chunks of a refused query are not exposed to the model).
  final List<KbChunk> chunks;

  /// The FTS5 MATCH string that was run (null when nothing was searchable).
  final String? matchQuery;

  double? get bestScore => chunks.isEmpty ? null : chunks.first.score;
}

const String _chunkSelect =
    'SELECT c.id, c.doc_id, d.short AS doc_short, d.title, d.publisher, '
    'c.page_label, c.pdf_page, c.chapter, c.text, c.original, c.topics, '
    'c.verify';

class Retriever {
  Retriever(
    this._kb, {
    required Set<String> stopwords,
    this.floor = kDefaultBm25Floor,
    Iterable<String> extraVocabulary = const [],
  }) {
    final syn = <String, List<String>>{};
    final vocab = <String>{};
    for (final r in _kb.db.select(
      'SELECT term, synonym FROM synonyms ORDER BY term, synonym',
    )) {
      final term = r['term'] as String;
      final s = r['synonym'] as String;
      (syn[term] ??= []).add(s);
      _addWords(vocab, term);
      _addWords(vocab, s);
    }
    for (final r in _kb.db.select('SELECT topics, keywords FROM chunks')) {
      for (final col in const ['topics', 'keywords']) {
        final raw = r[col] as String?;
        if (raw == null || raw.isEmpty) continue;
        final list = jsonDecode(raw);
        if (list is List) {
          for (final e in list) {
            _addWords(vocab, e.toString());
          }
        }
      }
    }
    for (final e in extraVocabulary) {
      _addWords(vocab, e);
    }
    vocab.removeWhere(
      (w) => stopwords.contains(w) || kAmbiguousDomainWords.contains(w),
    );
    for (final w in vocab) {
      if (w.length >= 3) (_buckets[w.substring(0, 3)] ??= []).add(w);
    }
    _vocab = vocab;
    _builder = QueryBuilder(synonyms: syn, stopwords: stopwords);
  }

  final KbDatabase _kb;

  /// bm25 floor (see [kDefaultBm25Floor]).
  final double floor;

  late final QueryBuilder _builder;
  late final Set<String> _vocab;
  final Map<String, List<String>> _buckets = {};

  /// Number of distinct normalised words in the domain vocabulary.
  int get vocabularySize => _vocab.length;

  QueryBuilder get queryBuilder => _builder;

  static void _addWords(Set<String> into, String phrase) {
    for (final w in normalizePl(phrase).split(' ')) {
      if (w.isNotEmpty) into.add(w);
    }
  }

  /// True when [token] (normalised) matches a domain word: equal, or sharing
  /// a prefix of at least 3 characters that leaves at most 2 characters of
  /// the longer word unmatched (Polish inflection, typos in endings). This is
  /// deliberately tighter than the FTS prefix rule so that "pogoda" does not
  /// match "pogotowie".
  bool _isDomainWord(String token) {
    if (_vocab.contains(token)) return true;
    if (token.length < 3) return false;
    final bucket = _buckets[token.substring(0, 3)];
    if (bucket == null) return false;
    for (final w in bucket) {
      final shorter = token.length < w.length ? token.length : w.length;
      final longer = token.length < w.length ? w.length : token.length;
      var cp = 3;
      while (cp < shorter && token.codeUnitAt(cp) == w.codeUnitAt(cp)) {
        cp++;
      }
      if (cp >= longer - 2) return true;
    }
    return false;
  }

  /// Query tokens (after stopwords) that are domain words.
  List<String> domainTokens(String question) =>
      _builder.contentTokens(question).where(_isDomainWord).toList();

  /// Whether [question] contains at least one domain word.
  bool isDomainQuery(String question) => domainTokens(question).isNotEmpty;

  Future<RetrievalResult> search(
    String question, {
    int k = kDefaultTopK,
  }) async {
    if (!isDomainQuery(question)) {
      return const RetrievalResult(
        decision: RetrievalDecision.offTopic,
        chunks: [],
      );
    }
    final match = _builder.build(question);
    if (match == null) {
      return const RetrievalResult(
        decision: RetrievalDecision.noSource,
        chunks: [],
      );
    }
    final rows = _kb.db.select(
      '$_chunkSelect, bm25(chunks_fts) AS score '
      'FROM chunks_fts JOIN chunks c ON c.rowid = chunks_fts.rowid '
      'JOIN documents d ON d.doc_id = c.doc_id '
      'WHERE chunks_fts MATCH ? ORDER BY score LIMIT ?',
      [match, k],
    );
    final chunks = [
      for (final r in rows) _chunk(r, (r['score'] as num).toDouble()),
    ];
    final ok = chunks.isNotEmpty && chunks.first.score <= floor;
    return RetrievalResult(
      decision: ok ? RetrievalDecision.found : RetrievalDecision.noSource,
      chunks: ok ? chunks : const [],
      matchQuery: match,
    );
  }

  /// Chunks by id (quote panel). Unknown ids are absent from the map.
  Future<Map<String, KbChunk>> sourcesFor(List<String> chunkIds) async {
    if (chunkIds.isEmpty) return const {};
    final marks = List.filled(chunkIds.length, '?').join(',');
    final rows = _kb.db.select(
      '$_chunkSelect FROM chunks c JOIN documents d ON d.doc_id = c.doc_id '
      'WHERE c.id IN ($marks)',
      chunkIds,
    );
    return {for (final r in rows) r['id'] as String: _chunk(r, 0)};
  }

  static KbChunk _chunk(Map<String, Object?> r, double score) {
    List<String> topics = const [];
    final raw = r['topics'] as String?;
    if (raw != null && raw.isNotEmpty) {
      final d = jsonDecode(raw);
      if (d is List) topics = [for (final e in d) e.toString()];
    }
    return KbChunk(
      id: r['id'] as String,
      docId: r['doc_id'] as String,
      docShort: r['doc_short'] as String,
      title: r['title'] as String,
      publisher: r['publisher'] as String,
      pageLabel: r['page_label'] as String,
      pdfPage: r['pdf_page'] as int,
      chapter: r['chapter'] as String?,
      text: r['text'] as String,
      original: r['original'] as String?,
      topics: topics,
      verify: (r['verify'] as int? ?? 1) != 0,
      score: score,
    );
  }
}
