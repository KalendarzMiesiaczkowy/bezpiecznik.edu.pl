// Checks the `aed` rescue card ("Jak użyć AED") against its sources.
import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/ratunek/cards/rescue_card.dart';
import 'package:bezpiecznik/ratunek/detect/risk_detector.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  late RescueCardRepository repo;
  late RescueCard aed;
  late Map<String, dynamic> raw;

  setUpAll(() {
    final ids = ['rko', 'choking', 'bleeding', 'unconscious', 'aed'];
    repo = RescueCardRepository(
      cards: [for (final id in ids) _json('assets/cards/$id.json')],
      sources: _json('assets/cards/sources.json'),
    );
    aed = repo.card('aed')!;
    raw = _json('assets/cards/aed.json');
  });

  List<String> texts(String variant) {
    final p = aed.panels.whereType<StepsPanel>().single;
    return [for (final i in p.itemsFor(variant)!) i.text];
  }

  test('is a drafted card with the verification badge', () {
    expect(aed.verify, isTrue);
    expect(aed.name, 'Jak użyć AED');
    expect(raw['verify_note'], isNotEmpty);
  });

  test('has adult, child and infant variants like rko', () {
    final p = aed.panels.whereType<StepsPanel>().single;
    expect(p.variants.map((v) => v.id), ['adult', 'child', 'infant']);
    expect(p.readAloud, isTrue);
  });

  test('every step cites a source with doc and page', () {
    final p = aed.panels.whereType<StepsPanel>().single;
    var n = 0;
    for (final v in p.variants) {
      for (final i in v.items) {
        final src = repo.source(i.sourceId);
        expect(src, isNotNull, reason: i.sourceId);
        expect(src!.docId, isNotEmpty);
        expect(src.pdfPage, greaterThan(0));
        expect(src.original, isNotEmpty);
        n++;
      }
    }
    expect(n, greaterThan(20));
  });

  test('aed source ids use the f101+ range', () {
    for (final id in aed.sourceIds) {
      final n = int.parse(id.split('-f').last);
      expect(n, greaterThanOrEqualTo(101), reason: id);
    }
  });

  test('the adult sequence follows the cited order', () {
    final t = texts('adult');
    int at(String s) {
      final i = t.indexWhere((x) => x.contains(s));
      expect(i, greaterThanOrEqualTo(0), reason: s);
      return i;
    }

    expect(at('natychmiast'), lessThan(at('włącz urządzenie')));
    expect(at('włącz urządzenie'), lessThan(at('Przyklej elektrody')));
    expect(at('Przyklej elektrody'), lessThan(at('poniżej prawego obojczyka')));
    expect(at('analizuje rytm'), lessThan(at('przycisk defibrylacji')));
    expect(at('przycisk defibrylacji'), lessThan(at('po defibrylacji')));
    expect(t.sublist(t.length - 2).join(' '), contains('instrukcjami AED'));
  });

  test('the last step of every variant links back to rko', () {
    final p = aed.panels.whereType<StepsPanel>().single;
    for (final v in p.variants) {
      expect(v.items.last.cardLink?.cardId, 'rko', reason: v.id);
      expect(repo.linkTarget(v.items.last.cardLink!)?.id, 'rko');
    }
  });

  test('child numbers (25 kg, 8 years) come from the cited originals', () {
    final p = aed.panels.whereType<StepsPanel>().single;
    final child = p.variants.firstWhere((v) => v.id == 'child');
    final cited = child.items
        .map((i) => repo.source(i.sourceId)!.original)
        .join(' ');
    final stepText = texts('child').join(' ');
    for (final n in RegExp(r'\d+').allMatches(stepText).map((m) => m[0]!)) {
      expect(cited, contains(n), reason: 'number $n not in cited text');
    }
    expect(stepText, contains('25 kg'));
    expect(stepText, contains('tryb pediatryczny'));
    expect(texts('infant'), texts('child'));
  });

  test('adult steps contain no digits that are absent from the sources', () {
    final p = aed.panels.whereType<StepsPanel>().single;
    final adult = p.variants.firstWhere((v) => v.id == 'adult');
    final cited = adult.items
        .map((i) => repo.source(i.sourceId)!.original)
        .join(' ');
    for (final i in adult.items) {
      for (final m in RegExp(r'\d+').allMatches(i.text)) {
        expect(cited, contains(m[0]!), reason: i.text);
      }
    }
  });

  test('card phrases equal the detection index entry', () {
    final idx = _json('assets/phrases/cards_index.json');
    final entry = (idx['cards'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((c) => c['id'] == 'aed');
    expect(raw['phrases'], entry['phrases']);
    expect(raw['priority'], entry['priority']);
    expect(entry['phrases'], containsAll(['aed', 'defibrylator']));
  });

  group('detection', () {
    late RiskDetector d;
    setUpAll(() {
      d = RiskDetector(
        risk: _json('assets/phrases/risk.json'),
        cardsIndex: _json('assets/phrases/cards_index.json'),
      );
    });

    for (final (msg, variant) in [
      ('jak użyć defibrylatora', 'adult'),
      ('Gdzie jest AED?', 'adult'),
      ('jak użyć AED u dziecka', 'child'),
      ('jak użyć defibrylatora u niemowlaka', 'infant'),
    ]) {
      test('"$msg" opens aed/$variant', () {
        final r = d.detectCard(msg);
        expect(r, isNotNull);
        expect(r!.cardId, 'aed');
        expect(r.variant, variant);
      });
    }

    test('"nie oddycha, jest AED" still opens rko first', () {
      final r = d.detectCard('nie oddycha, jest AED')!;
      expect(r.cardId, 'rko');
      expect(r.alsoCardIds, contains('aed'));
    });
  });
}
