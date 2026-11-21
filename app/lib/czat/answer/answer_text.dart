/// Text helpers shared by the validator (pure Dart).
library;

import '../../ratunek/detect/normalize.dart';

/// Words that negate the following verb / noun (normalised).
bool isNegationWord(String t) =>
    t == 'nie' ||
    t == 'nigdy' ||
    t == 'zakaz' ||
    t.startsWith('zakaz') ||
    t.startsWith('zabron') ||
    t.startsWith('zabrania');

/// Prefix-stem of a normalised token (Polish inflection tolerant).
String stem(String t) => t.length <= 5 ? t : t.substring(0, 5);

/// Normalised tokens of one clause.
List<String> tokens(String s) =>
    normalizePl(s).split(' ').where((e) => e.isNotEmpty).toList();

final RegExp _clauseSplit = RegExp(r'[.,;:!?()\[\]\n\r]|\s[-–—]\s|\s•\s');

/// Clauses of [s], each a token list. Negation never crosses a clause.
List<List<String>> clauses(String s) => [
  for (final part in s.split(_clauseSplit))
    if (tokens(part).isNotEmpty) tokens(part),
];

/// Result of scanning negations in a text.
class NegationScan {
  NegationScan(this.negated, this.affirmed, this.hasNegation);

  /// Stems that follow a negation word within two content tokens.
  final Set<String> negated;

  /// Stems that occur outside any negation window.
  final Set<String> affirmed;

  /// Whether any negation word occurs.
  final bool hasNegation;
}

const int _window = 2;

NegationScan scanNegations(String text) {
  final negated = <String>{};
  final affirmed = <String>{};
  var any = false;
  for (final clause in clauses(text)) {
    var remaining = 0;
    for (final t in clause) {
      if (isNegationWord(t)) {
        any = true;
        remaining = _window;
        continue;
      }
      if (t.length < 3) continue;
      if (remaining > 0) {
        negated.add(stem(t));
        remaining--;
      } else {
        affirmed.add(stem(t));
      }
    }
  }
  return NegationScan(negated, affirmed, any);
}

final RegExp _number = RegExp(r'\d+(?:[.,]\d+)?');

/// Numbers in [s], decimal comma normalised to a dot.
Set<String> numbersIn(String s) => {
  for (final m in _number.allMatches(s)) m.group(0)!.replaceAll(',', '.'),
};

/// Numerals spelled out (normalised). Spelled-out amounts are checked like
/// digits; "jeden/jedna/pierwszy" are deliberately not here.
const Set<String> numeralWords = {
  'dwa', 'dwie', 'dwoch', 'dwoje', 'trzy', 'trzech', 'troje', 'cztery',
  'czterech', 'piec', 'pieciu', 'szesc', 'szesciu', 'siedem', 'siedmiu',
  'osiem', 'osmiu', 'dziewiec', 'dziewieciu', 'dziesiec', 'dziesieciu',
  'dwadziescia', 'trzydziesci', 'czterdziesci', 'piecdziesiat', 'sto',
  'tysiac', 'pol', 'polowa',
};
