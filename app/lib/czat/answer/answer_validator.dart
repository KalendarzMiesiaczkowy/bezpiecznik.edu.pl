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

/// Minimum share of an item's content stems that must occur in the cited chunk.
const double kMinOverlap = 0.5;

class _ChunkFacts {
  _ChunkFacts(KbChunk c) {
    final text = [c.text, if (c.original != null) c.original!].join('\n');
    numbers = numbersIn(text);
    final scan = scanNegations(text);
    negated = scan.negated;
    affirmed = scan.affirmed;
    hasNegation = scan.hasNegation;
    for (final t in tokens(text)) {
      words.add(t);
      stems.add(stem(t));
    }
  }

  late final Set<String> numbers;
  late final Set<String> negated;
  late final Set<String> affirmed;
  late final bool hasNegation;
  final Set<String> words = {};
  final Set<String> stems = {};
}

class AnswerValidator {
  AnswerValidator({Set<String>? stopwords})
    : _stop = stopwords ?? {for (final w in fallbackStopwords) normalizePl(w)};

  final Set<String> _stop;

  /// Checks one item; returns null when it is covered by [chunk].
  RejectReason? checkItem(String text, KbChunk chunk) =>
      _check(text, _ChunkFacts(chunk));

  RejectReason? _check(String text, _ChunkFacts f) {
    final t = text.trim();
    if (t.isEmpty) return RejectReason.emptyText;
    if (t.length > kMaxItemChars) return RejectReason.tooLong;

    // Numbers, doses and times: every digit string must be in the chunk.
    for (final n in numbersIn(t)) {
      if (!f.numbers.contains(n)) return RejectReason.invalidNumber;
    }
    final toks = tokens(t);
    for (final w in toks) {
      if (numeralWords.contains(w) && !f.words.contains(w)) {
        return RejectReason.invalidNumber;
      }
    }

    // Negations.
    final item = scanNegations(t);
    for (final s in item.affirmed) {
      if (f.negated.contains(s) && !f.affirmed.contains(s)) {
        return RejectReason.droppedNegation;
      }
    }
    for (final s in item.negated) {
      if (f.affirmed.contains(s) && !f.negated.contains(s)) {
        return RejectReason.addedNegation;
      }
    }
    if (item.hasNegation && !f.hasNegation) return RejectReason.addedNegation;

    // Keyword coverage.
    final content = {
      for (final w in toks)
        if (w.length >= 4 && !_stop.contains(w) && !isNegationWord(w)) stem(w),
    };
    if (content.isNotEmpty) {
      final hit = content.where(f.stems.contains).length;
      if (hit / content.length < kMinOverlap) return RejectReason.lowOverlap;
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
      var title = (p['title'] is String ? (p['title'] as String).trim() : '');
      if (title.length > kMaxTitleChars) title = title.substring(0, kMaxTitleChars).trim();
      if (title.isEmpty) title = type == 'steps' ? 'Co zrobić' : 'Najważniejsze';
      out.add({'type': type, 'title': title, 'items': kept});
    }
    return ValidatedAnswer(panels: out, rejected: rejected);
  }
}
