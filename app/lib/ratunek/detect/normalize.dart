/// Text normalisation shared with the Python pipeline (task A03).
///
/// Contract (must stay byte-identical with the Python side; shared vectors in
/// `test/ratunek/detect/normalize_vectors.json`):
///   1. lowercase,
///   2. fold Latin letters with diacritics to ASCII (ł -> l, ą -> a, ...;
///      ß -> ss, æ -> ae, œ -> oe), drop combining marks U+0300..U+036F,
///   3. every remaining char outside [a-z0-9] becomes a space
///      (punctuation, symbols, emoji, non-Latin scripts),
///   4. collapse whitespace runs to one space and trim.
library;

const Map<String, String> _fold = {
  'ą': 'a',
  'ć': 'c',
  'ę': 'e',
  'ł': 'l',
  'ń': 'n',
  'ó': 'o',
  'ś': 's',
  'ź': 'z',
  'ż': 'z',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ç': 'c',
  'č': 'c',
  'ď': 'd',
  'đ': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ė': 'e',
  'ě': 'e',
  'ğ': 'g',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ı': 'i',
  'ĺ': 'l',
  'ľ': 'l',
  'ñ': 'n',
  'ň': 'n',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ő': 'o',
  'ř': 'r',
  'ş': 's',
  'š': 's',
  'ť': 't',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ű': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
};

/// Normalises [input] per the contract above.
String normalizePl(String input) {
  final out = StringBuffer();
  var pendingSpace = false;
  for (final rune in input.toLowerCase().runes) {
    if (rune >= 0x300 && rune <= 0x36F) continue; // combining mark: dropped
    final ch = String.fromCharCode(rune);
    final folded = _fold[ch] ?? ch;
    for (final unit in folded.codeUnits) {
      final isAlnum =
          (unit >= 0x61 && unit <= 0x7A) || (unit >= 0x30 && unit <= 0x39);
      if (isAlnum) {
        if (pendingSpace && out.isNotEmpty) out.write(' ');
        pendingSpace = false;
        out.writeCharCode(unit);
      } else {
        pendingSpace = true;
      }
    }
  }
  return out.toString();
}
