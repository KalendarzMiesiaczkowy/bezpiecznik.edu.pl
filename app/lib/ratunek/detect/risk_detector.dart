import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

import 'normalize.dart';

/// Result of a rescue-card detection.
class DetectionResult {
  const DetectionResult({
    required this.cardId,
    required this.variant,
    required this.matchedPhrase,
    this.nextStep,
    this.alsoCardIds = const [],
  });

  /// Winning card (lowest `priority` number among matched cards).
  final String cardId;

  /// `adult` / `child` / `infant`, or null when the card has no variants.
  final String? variant;

  /// Normalised phrase from the index that matched.
  final String matchedPhrase;

  /// UI hint from the index, e.g. `check_breathing`.
  final String? nextStep;

  /// Other matched cards (for "Też: {name}" buttons), in priority order.
  final List<String> alsoCardIds;

  @override
  String toString() =>
      'DetectionResult($cardId, $variant, "$matchedPhrase", $nextStep, $alsoCardIds)';
}

class _Tok {
  const _Tok(this.text, this.exact);
  final String text;
  final bool exact;
}

class _Phrase {
  _Phrase(this.normalized, this.tokens);
  final String normalized;
  final List<_Tok> tokens;
}

class _Card {
  _Card(this.id, this.priority, this.variants, this.nextStep, this.phrases);
  final String id;
  final int priority;
  final List<String> variants;
  final String? nextStep;
  final List<_Phrase> phrases;
}

/// Pure-Dart phrase matcher for risk phrases and rescue-card triggers.
///
/// Matching is token based on [normalizePl] output, with Damerau-Levenshtein
/// typo tolerance (see README in assets/phrases). Run on the user's message
/// only, never on retrieved chunks or model output.
class RiskDetector {
  RiskDetector({
    required Map<String, dynamic> risk,
    required Map<String, dynamic> cardsIndex,
  }) : _risk = _parsePhrases((risk['phrases'] as List).cast<String>()),
       _cards = _parseCards(cardsIndex),
       _variantWords = _parseVariantWords(cardsIndex);

  /// Loads `assets/phrases/risk.json` and `cards_index.json` from [bundle]
  /// (pass `rootBundle`).
  static Future<RiskDetector> load(AssetBundle bundle) async {
    final risk = jsonDecode(
      await bundle.loadString('assets/phrases/risk.json'),
    );
    final cards = jsonDecode(
      await bundle.loadString('assets/phrases/cards_index.json'),
    );
    return RiskDetector(
      risk: risk as Map<String, dynamic>,
      cardsIndex: cards as Map<String, dynamic>,
    );
  }

  /// Max filler tokens allowed between two consecutive phrase tokens.
  static const int maxGap = 2;

  final List<_Phrase> _risk;
  final List<_Card> _cards;
  final Map<String, List<_Tok>> _variantWords;

  /// Best matching rescue card for [userMessage], or null.
  DetectionResult? detectCard(String userMessage) {
    final tokens = _tokenize(userMessage);
    if (tokens.isEmpty) return null;
    _Card? best;
    String? bestPhrase;
    final also = <String>[];
    for (final card in _cards) {
      final hit = _firstHit(card.phrases, tokens);
      if (hit == null) continue;
      if (best == null) {
        best = card;
        bestPhrase = hit;
      } else {
        also.add(card.id);
      }
    }
    if (best == null) return null;
    return DetectionResult(
      cardId: best.id,
      variant: best.variants.isEmpty ? null : _variant(tokens, best.variants),
      matchedPhrase: bestPhrase!,
      nextStep: best.nextStep,
      alsoCardIds: also,
    );
  }

  /// `infant` / `child` when [userMessage] names an age group, else null.
  /// For cards without variants whose links lead to an aged card (RKO).
  String? ageVariant(String userMessage) {
    final tokens = _tokenize(userMessage);
    if (tokens.isEmpty) return null;
    final v = _variant(tokens, const ['infant', 'child']);
    return _hasAge(tokens, v) ? v : null;
  }

  bool _hasAge(List<String> tokens, String v) => tokens.any(
    (w) => _variantWordsOf(v).any((t) => _tokenMatches(t, w)),
  );

  /// True when [userMessage] should get the `call` template: a risk phrase or
  /// any rescue-card phrase matches.
  bool isRisk(String userMessage) {
    final tokens = _tokenize(userMessage);
    if (tokens.isEmpty) return false;
    if (_firstHit(_risk, tokens) != null) return true;
    for (final card in _cards) {
      if (_firstHit(card.phrases, tokens) != null) return true;
    }
    return false;
  }

  // ---- parsing ----

  static List<_Phrase> _parsePhrases(List<String> raw) {
    final out = <_Phrase>[];
    for (final p in raw) {
      final toks = <_Tok>[];
      for (final part in p.trim().split(RegExp(r'\s+'))) {
        if (part.isEmpty) continue;
        final exact = part.startsWith('=');
        final n = normalizePl(exact ? part.substring(1) : part);
        for (final t in n.split(' ')) {
          if (t.isNotEmpty) toks.add(_Tok(t, exact));
        }
      }
      if (toks.isNotEmpty) {
        out.add(_Phrase(toks.map((t) => t.text).join(' '), toks));
      }
    }
    return out;
  }

  static List<_Card> _parseCards(Map<String, dynamic> index) {
    final cards = <_Card>[];
    for (final c in (index['cards'] as List).cast<Map<String, dynamic>>()) {
      cards.add(
        _Card(
          c['id'] as String,
          c['priority'] as int,
          ((c['variants'] as List?) ?? const []).cast<String>(),
          c['next_step'] as String?,
          _parsePhrases((c['phrases'] as List).cast<String>()),
        ),
      );
    }
    cards.sort((a, b) => a.priority.compareTo(b.priority));
    return cards;
  }

  static Map<String, List<_Tok>> _parseVariantWords(
    Map<String, dynamic> index,
  ) {
    final vw = (index['variant_words'] as Map?) ?? const {};
    return {
      for (final e in vw.entries)
        e.key as String: [
          for (final p in _parsePhrases((e.value as List).cast<String>()))
            ...p.tokens,
        ],
    };
  }

  // ---- matching ----

  static List<String> _tokenize(String s) {
    final n = normalizePl(s);
    return n.isEmpty ? const [] : n.split(' ');
  }

  static String? _firstHit(List<_Phrase> phrases, List<String> msg) {
    for (final p in phrases) {
      if (_phraseMatches(p, msg)) return p.normalized;
    }
    return null;
  }

  static bool _phraseMatches(_Phrase p, List<String> msg) {
    final first = p.tokens.first;
    final startsWithNie = first.text == 'nie';
    for (var i = 0; i < msg.length; i++) {
      if (!_tokenMatches(first, msg[i])) continue;
      // Negation guard: "nie krwawi" must not match the phrase "krwawi".
      if (!startsWithNie && _negatedBefore(msg, i)) continue;
      if (_matchFrom(p, 1, msg, i)) return true;
    }
    return false;
  }

  static const _copulas = {'jest', 'byl', 'byla', 'bylo', 'sie', 'ma'};

  /// "nie X" or "nie jest/byl/sie X" directly before message index [i].
  /// Deliberately narrow: a missed rescue is worse than a false trigger.
  static bool _negatedBefore(List<String> msg, int i) {
    if (i > 0 && msg[i - 1] == 'nie') return true;
    return i > 1 && msg[i - 2] == 'nie' && _copulas.contains(msg[i - 1]);
  }

  /// Matches phrase tokens from index [pi] given that token pi-1 matched at
  /// message index [prev].
  static bool _matchFrom(_Phrase p, int pi, List<String> msg, int prev) {
    if (pi == p.tokens.length) return true;
    final gap = p.tokens[pi - 1].text == 'nie' ? 0 : maxGap;
    final last = prev + 1 + gap;
    for (var j = prev + 1; j <= last && j < msg.length; j++) {
      if (_tokenMatches(p.tokens[pi], msg[j]) &&
          _matchFrom(p, pi + 1, msg, j)) {
        return true;
      }
    }
    return false;
  }

  static int _tolerance(int len) => len >= 8 ? 2 : (len >= 4 ? 1 : 0);

  static bool _tokenMatches(_Tok t, String word) {
    if (t.text == word) return true;
    if (t.exact) return false;
    final tol = _tolerance(t.text.length);
    if (tol == 0) return false;
    return _within(t.text, word, tol);
  }

  String _variant(List<String> msg, List<String> allowed) {
    bool has(String v) {
      if (!allowed.contains(v)) return false;
      final words = _variantWordsOf(v);
      for (final w in msg) {
        for (final t in words) {
          if (_tokenMatches(t, w)) return true;
        }
      }
      return false;
    }

    // Both matched: infant wins (szablony-czatu.md#warianty).
    if (has('infant')) return 'infant';
    if (has('child')) return 'child';
    return allowed.first;
  }

  List<_Tok> _variantWordsOf(String v) => _variantWords[v] ?? const [];
}

/// Optimal-string-alignment (restricted Damerau-Levenshtein) distance check:
/// true when distance(a, b) <= max.
bool _within(String a, String b, int max) {
  final la = a.length, lb = b.length;
  if ((la - lb).abs() > max) return false;
  var prev2 = List<int>.filled(lb + 1, 0);
  var prev = List<int>.generate(lb + 1, (j) => j);
  var cur = List<int>.filled(lb + 1, 0);
  for (var i = 1; i <= la; i++) {
    cur[0] = i;
    for (var j = 1; j <= lb; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var v = prev[j] + 1;
      if (cur[j - 1] + 1 < v) v = cur[j - 1] + 1;
      if (prev[j - 1] + cost < v) v = prev[j - 1] + cost;
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1) &&
          prev2[j - 2] + 1 < v) {
        v = prev2[j - 2] + 1;
      }
      cur[j] = v;
    }
    final t = prev2;
    prev2 = prev;
    prev = cur;
    cur = t;
  }
  return prev[lb] <= max;
}

/// Exposed for tests.
bool editDistanceWithin(String a, String b, int max) => _within(a, b, max);
