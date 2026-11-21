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

/// Whether two normalised tokens are inflections of the same word. Strict on
/// purpose (a false match lets invented content through): short words must be
/// equal (3 chars) or share all but one char (4 chars); longer words must
/// share a prefix of at least 4 chars and all but two chars of the shorter.
bool sameWord(String a, String b) {
  if (a == b) return true;
  final m = a.length < b.length ? a.length : b.length;
  var p = 0;
  while (p < m && a.codeUnitAt(p) == b.codeUnitAt(p)) {
    p++;
  }
  if (m <= 3) return false; // equal already handled
  if (m == 4) return p >= 3;
  final need = m - 2 > 4 ? m - 2 : 4;
  return p >= need;
}

/// Whether [t] matches any token of [set].
bool anySame(Iterable<String> set, String t) {
  for (final s in set) {
    if (sameWord(s, t)) return true;
  }
  return false;
}

/// Function words and connectors that carry no checkable content (normalised).
/// Deliberately small; verbs of action and nouns are never here.
const Set<String> functionWords = {
  'a',
  'aby',
  'albo',
  'ale',
  'az',
  'bez',
  'by',
  'byc',
  'czy',
  'dla',
  'do',
  'dopoki',
  'gdy',
  'gdzie',
  'go',
  'i',
  'jak',
  'jest',
  'jesli',
  'juz',
  'kiedy',
  'lub',
  'mozna',
  'na',
  'nad',
  'nalezy',
  'najpierw',
  'nastepnie',
  'o',
  'od',
  'oraz',
  'po',
  'pod',
  'podczas',
  'potem',
  'przed',
  'przez',
  'przy',
  'sa',
  'sie',
  'ta',
  'tak',
  'takze',
  'te',
  'teraz',
  'to',
  'tez',
  'trzeba',
  'tylko',
  'poza',
  'obok',
  'wokol',
  'miedzy',
  'ku',
  'u',
  'w',
  'we',
  'wiec',
  'wtedy',
  'z',
  'za',
  'ze',
  'zeby',
  'zawsze',
};

/// Normalised tokens of one clause.
List<String> tokens(String s) =>
    normalizePl(s).split(' ').where((e) => e.isNotEmpty).toList();

final RegExp _clauseSplit = RegExp(r'[.,;:!?()\[\]\n\r]|\s[-–—]\s|\s•\s');
final RegExp _decimalComma = RegExp(r'(\d),(\d)');

/// Clauses of [s], each a token list. Negation never crosses a clause.
/// A decimal comma ("2,5") does not split a clause.
List<List<String>> clauses(String s) => [
  for (final part
      in s
          .replaceAllMapped(_decimalComma, (m) => '${m[1]}.${m[2]}')
          .split(_clauseSplit))
    if (tokens(part).isNotEmpty) tokens(part),
];

/// Result of scanning negations in a text.
class NegationScan {
  NegationScan(this.negated, this.affirmed, this.hasNegation);

  /// Tokens that follow a negation word within [negationWindow] content tokens.
  final Set<String> negated;

  /// Tokens that occur outside any negation window.
  final Set<String> affirmed;

  /// Whether any negation word occurs.
  final bool hasNegation;
}

/// Max distance (in content tokens, either side) between a negation word and
/// a word it governs. Symmetric so a reordered phrase keeps its negation.
const int negationWindow = 5;

/// Content tokens of [clause] that fall under a negation of the same clause.
Set<String> negatedIn(List<String> clause) {
  final content = [
    for (final t in clause)
      if (isNegationWord(t) || (t.length >= 3 && !functionWords.contains(t))) t,
  ];
  final out = <String>{};
  for (var i = 0; i < content.length; i++) {
    if (!isNegationWord(content[i])) continue;
    for (var j = i - negationWindow; j <= i + negationWindow; j++) {
      if (j < 0 || j >= content.length || isNegationWord(content[j])) continue;
      out.add(content[j]);
    }
  }
  return out;
}

NegationScan scanNegations(String text) {
  final negated = <String>{};
  final affirmed = <String>{};
  var any = false;
  for (final clause in clauses(text)) {
    final neg = negatedIn(clause);
    if (clause.any(isNegationWord)) any = true;
    for (final t in clause) {
      if (isNegationWord(t) || t.length < 3 || functionWords.contains(t)) {
        continue;
      }
      (neg.contains(t) ? negated : affirmed).add(t);
    }
  }
  return NegationScan(negated, affirmed, any);
}

/// Spelled-out numerals and quantity words (normalised form -> canonical
/// value). Words that are not numbers in the dictionary ("kilka", "kilkanascie")
/// map to themselves, so they must literally occur in the source.
/// "jeden/jedna/pierwszy" are deliberately not here.
const Map<String, String> numeralWords = {
  'dwa': '2',
  'dwie': '2',
  'dwoch': '2',
  'dwoje': '2',
  'trzy': '3',
  'trzech': '3',
  'troje': '3',
  'cztery': '4',
  'czterech': '4',
  'piec': '5',
  'pieciu': '5',
  'szesc': '6',
  'szesciu': '6',
  'siedem': '7',
  'siedmiu': '7',
  'osiem': '8',
  'osmiu': '8',
  'dziewiec': '9',
  'dziewieciu': '9',
  'dziesiec': '10',
  'dziesieciu': '10',
  'jedenascie': '11',
  'jedenastu': '11',
  'dwanascie': '12',
  'dwunastu': '12',
  'trzynascie': '13',
  'trzynastu': '13',
  'czternascie': '14',
  'czternastu': '14',
  'pietnascie': '15',
  'pietnastu': '15',
  'szesnascie': '16',
  'szesnastu': '16',
  'siedemnascie': '17',
  'siedemnastu': '17',
  'osiemnascie': '18',
  'osiemnastu': '18',
  'dziewietnascie': '19',
  'dziewietnastu': '19',
  'dwadziescia': '20',
  'dwudziestu': '20',
  'trzydziesci': '30',
  'trzydziestu': '30',
  'czterdziesci': '40',
  'czterdziestu': '40',
  'piecdziesiat': '50',
  'piecdziesieciu': '50',
  'szescdziesiat': '60',
  'szescdziesieciu': '60',
  'siedemdziesiat': '70',
  'siedemdziesieciu': '70',
  'osiemdziesiat': '80',
  'osiemdziesieciu': '80',
  'dziewiecdziesiat': '90',
  'dziewiecdziesieciu': '90',
  'sto': '100',
  'stu': '100',
  'dwiescie': '200',
  'trzysta': '300',
  'czterysta': '400',
  'piecset': '500',
  'szescset': '600',
  'siedemset': '700',
  'osiemset': '800',
  'dziewiecset': '900',
  'tysiac': '1000',
  'tysiace': '1000',
  'tysiecy': '1000',
  'pol': 'pol',
  'polowa': 'pol',
  'polowe': 'pol',
  'polowy': 'pol',
  'kilka': 'kilka',
  'kilku': 'kilka',
  'kilkanascie': 'kilka',
  'kilkunastu': 'kilka',
  'kilkadziesiat': 'kilka',
  'kilkaset': 'kilka',
  'pare': 'kilka',
  'paru': 'kilka',
  'tuzin': 'kilka',
};

final RegExp _digits = RegExp(r'^\d+(?:\.\d+)?$');

/// Canonical value of a numeric token (digits or numeral word), else null.
String? numericValue(String t) {
  if (_digits.hasMatch(t)) return t;
  return numeralWords[t];
}

/// One number occurrence with the tokens that follow it in the same clause.
class NumberFact {
  NumberFact(this.value, this.following);
  final String value;

  /// Up to two following non-numeric content tokens (the unit / counted noun).
  final List<String> following;
}

/// Numbers (digits or spelled out) of [s] with their units.
List<NumberFact> numberFacts(String s) {
  final out = <NumberFact>[];
  for (final clause in clauses(s)) {
    for (var i = 0; i < clause.length; i++) {
      final v = numericValue(clause[i]);
      if (v == null) continue;
      final next = <String>[];
      for (var j = i + 1; j < clause.length && next.length < 2; j++) {
        final t = clause[j];
        if (numericValue(t) != null) break;
        if (t.length < 3 || functionWords.contains(t) || isNegationWord(t)) {
          if (next.isEmpty) break; // "30 do 40", "2 i 3": no unit
          continue;
        }
        next.add(t);
      }
      out.add(NumberFact(v, next));
    }
  }
  return out;
}
