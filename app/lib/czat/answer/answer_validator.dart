/// Post-answer validation (odpowiedzi-tylko-ze-zrodel.md, warstwa 3): every
/// step / bullet is compared with the chunk it cites. The model writes, the
/// code decides.
library;

import '../retrieval/retriever.dart';
import '../retrieval/stopwords_fallback.dart';
import '../../ratunek/detect/normalize.dart';
import 'answer_text.dart';

/// Why one item was rejected.
enum RejectReason {
  emptyText,
  tooLong,
  unknownSource,
  invalidNumber,
  droppedNegation,
  addedNegation,
  lowOverlap,
}

class RejectedItem {
  const RejectedItem(this.text, this.sourceId, this.reason);
  final String text;
  final String? sourceId;
  final RejectReason reason;

  @override
  String toString() => '$reason: "$text" [$sourceId]';
}

/// Outcome of validating a whole model object.
class ValidatedAnswer {
  const ValidatedAnswer({required this.panels, required this.rejected});

  /// Panel JSON maps that survived: only `steps` / `bullets` with `items`
  /// and `quote`. Never contains other types.
  final List<Map<String, Object?>> panels;
  final List<RejectedItem> rejected;

  bool get hasContent => panels.isNotEmpty;
}

/// Max chars of one step (spec: up to 120; some slack for Polish inflection
/// the model adds, anything longer is not a single action).
const int kMaxItemChars = 240;
const int kMaxTitleChars = 30;
const int kMaxItemsPerPanel = 8;

/// Panel titles the UI may show (spec szablony-czatu.md examples + the
/// defaults). Anything else the model writes is replaced by a default, so a
/// title can never carry an invented instruction.
const List<String> kAllowedTitles = [
  'Teraz',
  'Kroki',
  'Co zrobić',
  'Najważniejsze',
  'Do zapamiętania',
  'Do plecaka',
  'RKO',
  'Gdy straci przytomność',
];

/// Spec limit for `title` (szablony-czatu.md: "Do 30 znaków").
const int kMaxTitleLength = 30;

/// The spec gives titles only as examples ("Teraz", "RKO", "Do plecaka",
/// "Gdy straci przytomność"), so besides the fixed list a title is accepted
/// when it is short and every content word of it occurs (5-character prefix,
/// Polish inflection) in the chunks the panel cites: a title can then never
/// carry an instruction the sources do not contain.
String _safeTitle(Object? raw, String type, Set<String> sourceWords) {
  if (raw is String) {
    final n = normalizePl(raw);
    for (final t in kAllowedTitles) {
      if (normalizePl(t) == n) return t;
    }
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty &&
        trimmed.length <= kMaxTitleLength &&
        _titleGrounded(n, sourceWords)) {
      return sentenceCase(trimmed);
    }
  }
  return type == 'steps' ? 'Co zrobić' : 'Najważniejsze';
}

/// "Sygnały Alarmowe" -> "Sygnały alarmowe": Polish sentence case, acronyms
/// ("RKO", "SOR") kept.
String sentenceCase(String s) => s
    .split(' ')
    .indexed
    .map((e) {
      final w = e.$2;
      if (w == w.toUpperCase()) return w;
      return e.$1 == 0 ? w : w.toLowerCase();
    })
    .join(' ');

bool _titleGrounded(String normalized, Set<String> sourceWords) {
  var content = 0;
  for (final w in normalized.split(' ')) {
    if (w.length < 3 || functionWords.contains(w)) continue;
    content++;
    final k = w.length < 5 ? w.length : 5;
    final stem = w.substring(0, k);
    if (!sourceWords.any((s) => s.startsWith(stem))) return false;
  }
  return content > 0;
}

class _ChunkFacts {
  _ChunkFacts(KbChunk c) {
    final text = [c.text, if (c.original != null) c.original!].join('\n');
    numbers = numberFacts(text);
    final scan = scanNegations(text);
    negated = scan.negated;
    affirmed = scan.affirmed;
    hasNegation = scan.hasNegation;
    words = tokens(text).toSet();
  }

  late final List<NumberFact> numbers;
  late final Set<String> negated;
  late final Set<String> affirmed;
  late final bool hasNegation;
  late final Set<String> words;
}

class AnswerValidator {
  AnswerValidator({Set<String>? stopwords})
    : _stop = stopwords ?? {for (final w in fallbackStopwords) normalizePl(w)};

  final Set<String> _stop;

  /// Checks one item; returns null when it is covered by [chunk].
  RejectReason? checkItem(String text, KbChunk chunk) =>
      _check(text, _ChunkFacts(chunk));

  bool _isContent(String w) =>
      w.length >= 3 &&
      numericValue(w) == null &&
      !functionWords.contains(w) &&
      !_stop.contains(w) &&
      !isNegationWord(w);

  RejectReason? _check(String text, _ChunkFacts f) {
    final t = text.trim();
    if (t.isEmpty) return RejectReason.emptyText;
    if (t.length > kMaxItemChars) return RejectReason.tooLong;

    // Numbers, doses and times: each number must be in the chunk, bound to
    // the same unit / counted noun ("30 razy" is not "30 oddechów").
    for (final n in numberFacts(t)) {
      final cands = f.numbers.where((c) => c.value == n.value);
      if (cands.isEmpty) return RejectReason.invalidNumber;
      if (n.following.isEmpty) continue;
      final ok = cands.any(
        (c) => c.following.isEmpty || anySame(c.following, n.following.first),
      );
      if (!ok) return RejectReason.invalidNumber;
    }

    // Negations.
    final item = scanNegations(t);
    // A clause that uses a word the source only mentions under a negation
    // must itself negate it (any verb form, any word order).
    for (final clause in clauses(t)) {
      final neg = negatedIn(clause);
      for (final w in clause) {
        if (w.length < 3 || functionWords.contains(w) || isNegationWord(w)) continue;
        if (anySame(f.negated, w) && !anySame(f.affirmed, w) && !neg.contains(w)) {
          return RejectReason.droppedNegation;
        }
      }
    }
    for (final w in item.negated) {
      if (anySame(f.affirmed, w) && !anySame(f.negated, w)) {
        return RejectReason.addedNegation;
      }
    }
    if (item.hasNegation && !f.hasNegation) return RejectReason.addedNegation;

    // Coverage: every content word of the item must occur in the chunk.
    for (final w in tokens(t)) {
      if (!_isContent(w)) continue;
      if (!anySame(f.words, w)) return RejectReason.lowOverlap;
    }
    return null;
  }

  /// Validates the parsed model object against the retrieved [chunks].
  /// Unknown panel types are dropped; items without a known `source_id` or
  /// without coverage are removed; empty panels are removed.
  ValidatedAnswer validate(Map<String, Object?> json, List<KbChunk> chunks) {
    final byId = {for (final c in chunks) c.id: c};
    final facts = <String, _ChunkFacts>{};
    final rejected = <RejectedItem>[];
    final out = <Map<String, Object?>>[];
    final quoted = <String>{};

    final rawPanels = json['panels'];
    if (rawPanels is! List) return ValidatedAnswer(panels: out, rejected: rejected);

    for (final p in rawPanels) {
      if (p is! Map) continue;
      final type = p['type'];
      if (type == 'quote') {
        final id = p['source_id'];
        if (id is String && byId.containsKey(id) && quoted.add(id)) {
          out.add({'type': 'quote', 'source_id': id});
        }
        continue;
      }
      if (type != 'steps' && type != 'bullets') continue;
      final items = p['items'];
      if (items is! List) continue;
      final kept = <Map<String, Object?>>[];
      for (final e in items) {
        if (e is! Map) continue;
        final text = e['text'];
        final id = e['source_id'];
        if (text is! String) continue;
        final chunk = id is String ? byId[id] : null;
        if (chunk == null) {
          rejected.add(RejectedItem(text, id is String ? id : null, RejectReason.unknownSource));
          continue;
        }
        final reason = _check(text, facts.putIfAbsent(chunk.id, () => _ChunkFacts(chunk)));
        if (reason != null) {
          rejected.add(RejectedItem(text, chunk.id, reason));
          continue;
        }
        kept.add({'text': text.trim(), 'source_id': chunk.id});
        if (kept.length >= kMaxItemsPerPanel) break;
      }
      if (kept.isEmpty) continue;
      final sourceWords = <String>{
        for (final k in kept) ...facts[k['source_id']]!.words,
      };
      final title = _safeTitle(p['title'], type as String, sourceWords);
      out.add({'type': type, 'title': title, 'items': kept});
    }
    return ValidatedAnswer(panels: out, rejected: rejected);
  }
}
