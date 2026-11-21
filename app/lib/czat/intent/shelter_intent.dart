import '../../ratunek/detect/normalize.dart';

/// What the user wants to find on the map (spec: zakres-mvp.md, intent
/// "schron / gdzie iść / szpital" -> `map` template, no model, no threshold).
enum ShelterIntent {
  /// Mentions a shelter ("schron", "schronienie").
  shelter('nearest_shelter'),

  /// "Gdzie iść / gdzie się schować": answered with the nearest shelters.
  whereToGo('nearest_shelter'),

  /// Mentions a hospital or ER ("szpital", "SOR").
  hospital('nearest_hospital');

  const ShelterIntent(this.target);

  /// `map` template `target` (szablony-czatu.md, `map`).
  final String target;
}

/// Optimal-string-alignment distance (insert, delete, substitute, adjacent
/// swap), so "schorn" is 1 away from "schron".
int osaDistance(String a, String b) {
  final d = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = [
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        final t = d[i - 2][j - 2] + 1;
        if (t < v) v = t;
      }
      d[i][j] = v;
    }
  }
  return d[a.length][b.length];
}

/// True when [token] starts with [stem] allowing one typo in the stem
/// (tokens shorter than 5 characters must match exactly).
bool _stemMatch(String token, String stem) {
  if (token.length < 5) return false;
  final head = token.length >= stem.length
      ? token.substring(0, stem.length)
      : token;
  return osaDistance(head, stem) <= 1;
}

bool _wordMatch(String token, String word) {
  if (word.length < 5) return token == word;
  return osaDistance(token, word) <= 1;
}

const _shelterStem = 'schron';
const _hospitalStem = 'szpital';
const _questionWords = ['gdzie', 'dokad'];

/// Movement verbs, matched exactly (no typo tolerance: "uciskac" is one edit
/// from "uciekac" and must never count as a movement verb).
const _goVerbs = {
  'isc',
  'pojsc',
  'udac',
  'uciekac',
  'uciec',
  'schronic',
  'uciekam',
  'ide',
  'schronie',
};

/// Hide verbs: only a where-to-go question when the object is the person
/// ("sie") or absent; "gdzie schowac leki" is not a shelter question.
const _hideVerbs = {
  'schowac',
  'ukryc',
  'skryc',
  'chowac',
  'ukrywac',
  'skrywac',
  'schowam',
  'ukryje',
};

/// Words allowed next to a hide verb when no explicit "sie" is present.
const _hideFillers = {
  'gdzie', 'dokad', 'mam', 'moge', 'mozna', 'mamy', 'powinienem',
  'powinnam', 'powinnismy', 'teraz', 'szybko', 'jak', 'nalezy',
};

/// First-aid stems: a "gdzie ..." question with one of these is about the
/// body or a procedure, never a where-to-go request.
const _firstAidStems = [
  'ucisk',
  'klatk',
  'oparz',
  'krwaw',
  'krwot',
  'oddych',
  'opatrun',
  'rko',
  'reka',
  'rece',
  'reke',
  'rane',
  'rany',
  'rana',
  'ranie',
  'zlaman',
  'masaz',
  'resuscyt',
];

/// Cues that the user wants a place ("where is"), not information.
const _locationCues = [
  'gdzie',
  'dokad',
  'najblizszy',
  'najblizsza',
  'najblizsze',
  'najblizszego',
  'najblizszym',
  'blisko',
  'poblizu',
  'pokaz',
  'mapa',
  'mapie',
  'dojsc',
  'dojechac',
  'szukam',
  'znajde',
  'znalezc',
];

/// Words that turn a mention into a different question.
const _questionStarters = [
  'jak',
  'co',
  'czy',
  'dlaczego',
  'kiedy',
  'ile',
  'po',
  'czym',
  'jaki',
  'jaka',
];
const _blockWords = [
  'przygotowac',
  'zbudowac',
  'wybudowac',
  'wyposazyc',
  'urzadzic',
  'zwierzat',
  'zwierzeta',
  'zwierzak',
  'psa',
  'kota',
  'spacer',
  'wakacje',
  'urlop',
  'zakupy',
  'obiad',
  'kino',
  'praca',
  'pracy',
  'historia',
];

/// Detects the "shelter / where to go / hospital" intent in [text]. Pure and
/// model-free. Returns null for anything else (informational questions such as
/// "jak przygotować schronienie dla zwierząt?" included).
ShelterIntent? detectShelterIntent(String text) {
  final norm = normalizePl(text);
  if (norm.isEmpty) return null;
  final tokens = norm.split(' ');
  if (tokens.any(_blockWords.contains)) return null;

  final hasCue = tokens.any((t) => _locationCues.any((c) => _wordMatch(t, c)));
  final startsAsQuestion = _questionStarters.contains(tokens.first);
  // A bare mention ("schron", "najblizszy schron") counts as a request; an
  // informational question ("co to schron") does not.
  final bare = tokens.length <= 3 && !startsAsQuestion;
  final wantsPlace = hasCue || bare;

  // A hospital needs an explicit place request: "czy jechac do szpitala z
  // oparzeniem" is a first-aid question, not a map request.
  final hospital = tokens.any(
    (t) => t == 'sor' || _stemMatch(t, _hospitalStem),
  );
  if (hospital && wantsPlace) return ShelterIntent.hospital;

  // "schronic" is the verb ("gdzie sie schronic"), handled as where-to-go.
  final shelter = tokens.any(
    (t) => t != 'schronic' && _stemMatch(t, _shelterStem),
  );
  if (shelter && wantsPlace) return ShelterIntent.shelter;

  final question = tokens.any(
    (t) => _questionWords.any((q) => _wordMatch(t, q)),
  );
  if (!question) return null;
  if (tokens.any((t) => _firstAidStems.any(t.startsWith))) return null;
  if (tokens.any(_goVerbs.contains)) return ShelterIntent.whereToGo;
  if (tokens.any(_hideVerbs.contains)) {
    final self = tokens.contains('sie');
    final bareHide = tokens.every(
      (t) => _hideFillers.contains(t) || _hideVerbs.contains(t),
    );
    if (self || bareHide) return ShelterIntent.whereToGo;
  }
  return null;
}
