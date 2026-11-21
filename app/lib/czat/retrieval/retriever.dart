/// Local FTS5 retrieval over the knowledge base plus the refusal decision.
library;

import 'dart:convert';

import '../../ratunek/detect/normalize.dart';
import '../../ratunek/detect/risk_detector.dart' show editDistanceWithin;
import 'kb_database.dart';
import 'query_builder.dart';
import 'safety_vocabulary.dart';

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
  'prawo',
  'koncert',
  'pogoda',
  'pogody',
  'pogodowy',
  'pogodowe',
  'prognoza',
};

/// Safety words describing a person's state, not a topic: their absence from
/// the KB says nothing ("ranny mocno krwawi" must not be refused for "ranny").
/// Normalised.
const Set<String> kStateWords = {
  'ranny',
  'ranni',
  'rannego',
  'rannej',
  'poparzony',
  'nieprzytomny',
  'oddycha',
  'umiera',
  'umierajacy',
  'cierpi',
  'zemdlal',
  'tonie',
  'zaginiony',
  'uwieziony',
  'zasypany',
  'zawalony',
  'zagrozone',
  'topielec',
};

/// Core resuscitation words: never "generic" ([Retriever.kGenericDocSpread]).
/// The KB's ERC documents (three of them one-chunk summaries) plus the RCB
/// guide all mention RKO, so the doc-spread rule refused "rko" and
/// "resuscytacja" as if they were "przy". Normalised.
// ponytail: explicit list; replace the doc-spread rule if more topics hit it.
const Set<String> kCoreTopicWords = {
  'rko',
  'resuscytacja',
  'resuscytacji',
  'resuscytacje',
  'reanimacja',
  'reanimacji',
  'reanimowac',
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
    // Health/safety words: in-domain even when the KB has no chunk (BG03).
    final safety = <String>{};
    for (final e in kSafetyVocabulary) {
      _addWords(vocab, e);
      _addWords(safety, e);
    }
    _safety = safety;
    for (final e in extraVocabulary) {
      _addWords(vocab, e);
    }
    // BG91: every word the KB or the query pipeline knows, for typo repair.
    final known = <String>{...vocab, ...stopwords, ...kAmbiguousDomainWords};
    for (final r in _kb.db.select('SELECT text_norm FROM chunks')) {
      _addWords(known, r['text_norm'] as String);
    }
    _known = known;
    _stopwords = stopwords;
    vocab.removeWhere(
      (w) => stopwords.contains(w) || kAmbiguousDomainWords.contains(w),
    );
    for (final w in vocab) {
      if (w.length >= 3) (_buckets[w.substring(0, 3)] ??= []).add(w);
    }
    _vocab = vocab;
    for (final w in known) {
      if (w.length >= 3 &&
          !kAmbiguousDomainWords.contains(w) &&
          (stopwords.contains(w) || _isDomainWord(w))) {
        (_targets[w[0]] ??= []).add(w);
      }
    }
    _builder = QueryBuilder(synonyms: syn, stopwords: stopwords);
  }

  final KbDatabase _kb;

  /// bm25 floor (see [kDefaultBm25Floor]).
  final double floor;

  late final QueryBuilder _builder;
  late final Set<String> _vocab;
  final Map<String, List<String>> _buckets = {};
  late final Set<String> _safety;
  late final Set<String> _known;
  late final Set<String> _stopwords;

  /// Typo-repair targets by first letter: domain words and stopwords.
  final Map<String, List<String>> _targets = {};

  /// A question word may be generic when its FTS match spans at least this
  /// many documents (e.g. "przy", "podczas"): it cannot ground a hit.
  static const int kGenericDocSpread = 5;

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
      // Long shared stem, short ending on the shorter word ("-iach" plurals).
      if (cp >= 7 && cp >= shorter - 1) return true;
    }
    return false;
  }

  /// Query tokens (after stopwords) that are domain words.
  List<String> domainTokens(String question) => _builder
      .contentTokens(question)
      .where((t) => !kAmbiguousDomainWords.contains(t) && _isDomainWord(t))
      .toList();

  /// Whether [question] contains at least one domain word.
  bool isDomainQuery(String question) => domainTokens(question).isNotEmpty;

  /// Searches [question]; when that finds nothing, retries once with typos
  /// repaired (BG91, [_correctTypos]). The retry is kept when it is a hit, or
  /// a "no source" for a question that was off-topic only through its typos
  /// ("ugryzenie weza"); it never turns a refusal into off-topic.
  Future<RetrievalResult> search(
    String question, {
    int k = kDefaultTopK,
  }) async {
    final exact = _search(question, k);
    if (exact.decision == RetrievalDecision.found) return exact;
    final fixed = _correctTypos(question);
    if (fixed == null) return exact;
    final retry = _search(fixed, k);
    return retry.decision == RetrievalDecision.offTopic ? exact : retry;
  }

  /// [question] normalised with unknown words replaced by their closest KB
  /// word ([_repair]), or null when nothing was repaired.
  String? _correctTypos(String question) {
    final toks = QueryBuilder.tokens(question);
    final fixed = [for (final t in toks) _repair(t) ?? t].join(' ');
    return fixed == toks.join(' ') ? null : fixed;
  }

  /// Domain word (or stopword) that an unknown [t] is a typo of, or null.
  /// Only typo shapes that inflection does not produce are accepted, so a
  /// real word missing from the KB ("bloku", "kinie", "pranie") is not
  /// rewritten: a Polish nasal spelled phonetically ("prundu" -> "pradu"),
  /// missing letters (1 for 4-6 letters, 2 for 7+; "prdu" -> "pradu"), an
  /// adjacent swap ("robci" -> "robic"), and for 7+ letters any single edit
  /// ("krwotik"). The first letter must match. Several candidates resolve
  /// only when all are stopwords; otherwise the word stays and the query is
  /// refused as before (when in doubt: no source).
  String? _repair(String t) {
    if (t.length < 4 || _known.contains(t) || _isDomainWord(t)) return null;
    for (final m in RegExp('[ou][nm]|e[nm]').allMatches(t)) {
      final v = t.replaceRange(m.start, m.end, t[m.start] == 'e' ? 'e' : 'a');
      if (_vocab.contains(v)) return v;
    }
    final cands = [
      for (final w in _targets[t[0]] ?? const <String>[])
        if (_isInsertion(t, w, t.length >= 7 ? 2 : 1) ||
            _isSwap(t, w) ||
            (t.length >= 7 && editDistanceWithin(t, w, 1)))
          w,
    ];
    if (cands.length == 1) return cands.first;
    if (cands.isNotEmpty && cands.every(_stopwords.contains)) {
      return cands.first;
    }
    return null;
  }

  /// [w] is [t] with 1..[max] letters inserted.
  static bool _isInsertion(String t, String w, int max) {
    final extra = w.length - t.length;
    if (extra < 1 || extra > max) return false;
    var i = 0;
    for (var j = 0; j < w.length && i < t.length; j++) {
      if (w.codeUnitAt(j) == t.codeUnitAt(i)) i++;
    }
    return i == t.length;
  }

  /// [w] is [t] with two adjacent letters swapped.
  static bool _isSwap(String t, String w) {
    if (t.length != w.length) return false;
    var i = 0;
    while (i < t.length && t.codeUnitAt(i) == w.codeUnitAt(i)) {
      i++;
    }
    return i + 1 < t.length &&
        t[i] == w[i + 1] &&
        t[i + 1] == w[i] &&
        t.substring(i + 2) == w.substring(i + 2);
  }

  RetrievalResult _search(String question, int k) {
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
    // A health/safety word of the question that no chunk mentions means the
    // KB does not cover the topic ("ugryzienie węża", "trzęsienie ziemi"):
    // other words ("co robić przy") must not turn it into a hit.
    if (_hasAbsentSafetyTopic(question)) {
      return RetrievalResult(
        decision: RetrievalDecision.noSource,
        chunks: const [],
        matchQuery: match,
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
    // BG03: a hit produced only by a non-domain token (e.g. "weza" -> "wezwij")
    // is not a source: keep chunks that match a domain token (or its synonyms).
    final domainMatch = _builder.build(
      domainTokens(question).where((t) => !_isGeneric(t)).join(' '),
    );
    final grounded = <String>{};
    if (domainMatch != null && chunks.isNotEmpty) {
      final marks = List.filled(chunks.length, '?').join(',');
      for (final r in _kb.db.select(
        'SELECT c.id FROM chunks_fts JOIN chunks c ON c.rowid = chunks_fts.rowid '
        'WHERE chunks_fts MATCH ? AND c.id IN ($marks)',
        [domainMatch, for (final c in chunks) c.id],
      )) {
        grounded.add(r['id'] as String);
      }
    }
    final kept = [
      for (final c in chunks)
        if (grounded.contains(c.id)) c,
    ];
    final ok = kept.isNotEmpty && kept.first.score <= floor;
    return RetrievalResult(
      decision: ok ? RetrievalDecision.found : RetrievalDecision.noSource,
      chunks: ok ? kept : const [],
      matchQuery: match,
    );
  }

  bool _isSafetyWord(String token) {
    if (_safety.contains(token)) return true;
    if (token.length < 3) return false;
    for (final w in _safety) {
      if (w.length < 3 || w.codeUnitAt(0) != token.codeUnitAt(0)) continue;
      final shorter = token.length < w.length ? token.length : w.length;
      final longer = token.length < w.length ? w.length : token.length;
      var cp = 0;
      while (cp < shorter && token.codeUnitAt(cp) == w.codeUnitAt(cp)) {
        cp++;
      }
      if (cp >= 4 && (cp >= longer - 2 || (cp == shorter && cp >= 5))) {
        return true;
      }
    }
    return false;
  }

  String? _tokenMatch(String token) {
    final stem = token.length <= 5 ? token : stemOf(token);
    // Normalised tokens are letters only, so the raw prefix is safe in MATCH.
    return RegExp(r'^[a-z0-9]+$').hasMatch(stem) ? '$stem*' : null;
  }

  /// True when a safety word of [question] has no chunk in the KB, so the
  /// topic is not covered. BG12: one absent word does not refuse a question
  /// whose other, specific safety words (at least two, not generic like
  /// "pomoc", not person states) all occur together in a single chunk ("ból
  /// przy oparzeniu i wstrząsie, czy to padaczka?" is answered from the burn
  /// and shock chunk). A single present word keeps the refusal ("atak
  /// padaczki" must not be answered from a chunk about attacks).
  bool _hasAbsentSafetyTopic(String question) {
    var absent = false;
    final present = <String>[];
    for (final t in domainTokens(question)) {
      if (kStateWords.contains(t) || !_isSafetyWord(t)) continue;
      final m = _tokenMatch(t);
      if (m == null) continue;
      final hit = _kb.db.select(
        'SELECT 1 FROM chunks_fts WHERE chunks_fts MATCH ? LIMIT 1',
        [m],
      );
      if (hit.isEmpty) {
        absent = true;
      } else if (!_isGeneric(t)) {
        present.add(m);
      }
    }
    if (!absent) return false;
    if (present.length < 2) return true;
    final both = _kb.db.select(
      'SELECT 1 FROM chunks_fts WHERE chunks_fts MATCH ? LIMIT 1',
      [present.join(' AND ')],
    );
    return both.isEmpty;
  }

  final Map<String, bool> _genericCache = {};

  bool _isGeneric(String token) => _genericCache.putIfAbsent(token, () {
    if (kCoreTopicWords.contains(token)) return false;
    final m = _builder.build(token);
    if (m == null) return false;
    final rows = _kb.db.select(
      'SELECT COUNT(DISTINCT c.doc_id) AS n FROM chunks_fts '
      'JOIN chunks c ON c.rowid = chunks_fts.rowid WHERE chunks_fts MATCH ?',
      [m],
    );
    return (rows.first['n'] as int) >= kGenericDocSpread;
  });

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
