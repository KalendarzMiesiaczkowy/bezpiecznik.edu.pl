import 'package:bezpiecznik/czat/intent/map_answer.dart';
import 'package:bezpiecznik/czat/intent/shelter_intent.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const positives = <String, ShelterIntent>{
    'gdzie jest najbliższy schron': ShelterIntent.shelter,
    'gdzie jest najblizszy schron': ShelterIntent.shelter,
    'Gdzie jest najbliższy schron?': ShelterIntent.shelter,
    'schron': ShelterIntent.shelter,
    'SCHRON!!!': ShelterIntent.shelter,
    'schorn': ShelterIntent.shelter,
    'gdzie jest najblizszy schorn': ShelterIntent.shelter,
    'gdzie jest schron w pobliżu': ShelterIntent.shelter,
    'pokaż schrony w okolicy': ShelterIntent.shelter,
    'najbliższe schronienie': ShelterIntent.shelter,
    'gdzie znajdę schronienie': ShelterIntent.shelter,
    'szukam schronu': ShelterIntent.shelter,
    'gdzie mam iść': ShelterIntent.whereToGo,
    'gdzie mam isc': ShelterIntent.whereToGo,
    'gdzie się schować': ShelterIntent.whereToGo,
    'gdzie sie schowac': ShelterIntent.whereToGo,
    'gdize sie schowac': ShelterIntent.whereToGo,
    'dokąd uciekać': ShelterIntent.whereToGo,
    'gdzie się ukryć?': ShelterIntent.whereToGo,
    'gdzie mogę się schronić': ShelterIntent.whereToGo,
    'najbliższy szpital': ShelterIntent.hospital,
    'najblizszy szpital': ShelterIntent.hospital,
    'gdzie jest szpital': ShelterIntent.hospital,
    'szpital': ShelterIntent.hospital,
    'szpitla': ShelterIntent.hospital,
    'gdzie jest najbliższy SOR': ShelterIntent.hospital,
    'gdzie znajdę szpital w pobliżu': ShelterIntent.hospital,
  };

  for (final e in positives.entries) {
    test('detects "${e.key}" as ${e.value.name}', () {
      expect(detectShelterIntent(e.key), e.value);
    });
  }

  test('has at least 15 positive phrasings', () => expect(positives.length, greaterThanOrEqualTo(15)));

  const negatives = [
    '',
    '   ',
    'jak przygotować schronienie dla zwierząt?',
    'jak zbudować schron w ogrodzie',
    'co to jest schron',
    'czy schron jest bezpieczny',
    'jak wygląda praca w szpitalu',
    'jak zatamować krwotok',
    'nie oddycha, pomocy',
    'ratunku pali się dom',
    'gdzie mogę iść na spacer',
    'co zabrać do plecaka',
    'chronić dokumenty przed wilgocią',
    'gdzie kupić wodę',
  ];
  for (final q in negatives) {
    test('ignores "$q"', () => expect(detectShelterIntent(q), isNull));
  }

  test('osaDistance counts a transposition as one edit', () {
    expect(osaDistance('schorn', 'schron'), 1);
    expect(osaDistance('abc', 'abc'), 0);
  });

  group('MapAnswerService', () {
    const service = MapAnswerService();

    test('returns null without intent', () async {
      expect(await service.tryAnswer('jak zatamować krwotok'), isNull);
    });

    test('shelter question gives one map panel, rules origin', () async {
      final a = await service.tryAnswer('gdzie jest najbliższy schron');
      expect(a, isNotNull);
      expect(a!.origin, AnswerOrigin.rules);
      expect(a.panels, hasLength(1));
      expect((a.panels.single as MapPanel).target, 'nearest_shelter');
      expect(a.sources, isEmpty);
    });

    test('where-to-go maps to nearest_shelter, hospital to nearest_hospital', () async {
      expect(((await service.tryAnswer('gdzie sie schowac'))!.panels.single as MapPanel).target, 'nearest_shelter');
      expect(((await service.tryAnswer('najblizszy szpital'))!.panels.single as MapPanel).target, 'nearest_hospital');
    });
  });
}
