import '../../ratunek/detect/normalize.dart';
import 'shelter_intent.dart' show osaDistance;

/// Detects the "plecak / co spakować" intent (ekran-1-czat.md, step 3:
/// `rules`, no model). Pure; null-safe on empty input.
bool detectKitIntent(String text) {
  final norm = normalizePl(text);
  if (norm.isEmpty) return false;
  final tokens = norm.split(' ');
  if (tokens.any(_blockWords.contains)) return false;
  if (tokens.any((t) => _blockStems.any(t.startsWith))) return false;
  if (tokens.first == 'dlaczego' || norm.contains('po co')) return false;

  // "plecak", "plecaka ewakuacyjnego", typo "plecka" (one edit in the stem).
  if (tokens.any(_isBackpack)) return true;

  final pack = tokens.any(_packVerbs.contains);
  final context = tokens.any((t) => _evacStems.any(t.startsWith));
  if (pack && context) return true;

  // "zestaw / lista ewakuacyjna" without the word backpack.
  final set = tokens.any((t) => _setStems.any(t.startsWith));
  return set && tokens.any((t) => t.startsWith('ewakuac'));
}

bool _isBackpack(String t) {
  if (t.length < 5) return false;
  final head = t.length >= 6 ? t.substring(0, 6) : t;
  return osaDistance(head, 'plecak') <= 1 && !_notBackpack.contains(t);
}

/// Near neighbours of "plecak" that are other words.
const _notBackpack = {'placek', 'placka', 'placki', 'plecy', 'plec'};

const _packVerbs = {
  'spakowac', 'zapakowac', 'zabrac', 'wziac', 'miec', 'spakuj', 'pakowac',
  'zapakuj', 'przygotowac', 'spakowanie', 'pakowanie',
};

const _evacStems = ['ewakuac', 'awaryjn', 'kryzys', 'uciec', 'uciek', 'wojn'];

const _setStems = ['zestaw', 'lista', 'liste', 'walizk', 'torb'];

/// Words that turn a mention into a different question ("plecak szkolny",
/// "gdzie kupić plecak", "dlaczego warto mieć plecak").
const _blockWords = {
  'kupic', 'kupie', 'kupno', 'cena', 'ceny', 'cene', 'sklep', 'sklepie',
  'wybrac', 'recenzja', 'ranking', 'szkola', 'szkoly', 'wycieczka', 'wakacje',
  'urlop', 'gory', 'gorach', 'warto',
};

const _blockStems = ['szkoln', 'turyst', 'gorsk', 'wycieczk', 'laptop', 'trekk'];
