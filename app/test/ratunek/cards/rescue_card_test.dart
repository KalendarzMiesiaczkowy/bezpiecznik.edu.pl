import 'dart:convert';

import 'package:bezpiecznik/ratunek/cards/rescue_card.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _source(String id) => {
  'source_id': id,
  'doc_id': 'doc',
  'doc_title': 'Doc title',
  'doc_short': 'Doc',
  'publisher': 'Pub',
  'issued': '2025',
  'page_label': '3',
  'pdf_page': 3,
  'pdf_file': 'doc/doc.pdf',
  'original': 'verbatim excerpt',
};

Map<String, dynamic> _card({
  String id = 'demo',
  bool? verify,
  List<Map<String, dynamic>>? panels,
}) => {
  'version': 1,
  'id': id,
  'name': 'Demo',
  'priority': 1,
  'verify': ?verify,
  'phrases': ['demo'],
  'panels':
      panels ??
      [
        {
          'type': 'steps',
          'title': 'Demo',
          'variants': [
            {
              'id': 'adult',
              'label': 'Dorosły',
              'items': [
                {'text': 'a', 'source_id': 's1'},
              ],
            },
            {
              'id': 'child',
              'label': 'Dziecko',
              'items': [
                {'text': 'c', 'source_id': 's1'},
              ],
            },
          ],
        },
      ],
  'source_ids': ['s1'],
};

Map<String, dynamic> get _sources => {
  'version': 1,
  'sources': [_source('s1')],
};

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.files);
  final Map<String, String> files;
  @override
  Future<ByteData> load(String key) async {
    final s = files[key];
    if (s == null) throw FlutterError('no asset $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(s)));
  }
}

void main() {
  group('RescueCard.fromJson', () {
    test('inserts call first when the file has none', () {
      final c = RescueCard.fromJson(_card());
      expect(c.panels.first, isA<CallPanel>());
      expect(c.panels, hasLength(2));
    });

    test('does not duplicate call', () {
      final c = RescueCard.fromJson(
        _card(
          panels: [
            {'type': 'call'},
            {
              'type': 'steps',
              'title': 'T',
              'items': [
                {'text': 'a', 'source_id': 's1'},
              ],
            },
          ],
        ),
      );
      expect(c.panels.whereType<CallPanel>(), hasLength(1));
    });

    test('missing verify counts as true', () {
      expect(RescueCard.fromJson(_card()).isVerify, isTrue);
      expect(RescueCard.fromJson(_card(verify: true)).isVerify, isTrue);
      expect(RescueCard.fromJson(_card(verify: false)).isVerify, isFalse);
    });

    test('variant selection falls back to the first variant', () {
      final c = RescueCard.fromJson(_card());
      expect(c.variantIds, ['adult', 'child']);
      expect(c.selectVariant('child'), 'child');
      expect(c.selectVariant('infant'), 'adult');
      expect(c.selectVariant(null), 'adult');
      expect(c.stepsFor('child').single.text, 'c');
      expect(c.stepsFor('nope').single.text, 'a');
    });

    test('a card without variants selects null', () {
      final c = RescueCard.fromJson(
        _card(
          panels: [
            {
              'type': 'steps',
              'title': 'T',
              'items': [
                {'text': 'a', 'source_id': 's1'},
              ],
            },
          ],
        ),
      );
      expect(c.variantIds, isEmpty);
      expect(c.selectVariant('child'), isNull);
      expect(c.stepsFor(null).single.text, 'a');
    });

    test('rejects bad cards', () {
      expect(
        () => RescueCard.fromJson(_card(id: 'Bad-Id')),
        throwsA(isA<RescueCardFormatException>()),
      );
      expect(
        () => RescueCard.fromJson({..._card(), 'source_ids': <String>[]}),
        throwsA(isA<RescueCardFormatException>()),
      );
      expect(
        () => RescueCard.fromJson({..._card(), 'phrases': <String>[]}),
        throwsA(isA<RescueCardFormatException>()),
      );
      expect(
        () => RescueCard.fromJson(
          _card(
            panels: [
              {
                'type': 'steps',
                'title': 'T',
                'items': [
                  {'text': 'a'},
                ],
              },
            ],
          ),
        ),
        throwsA(isA<RescueCardFormatException>()),
        reason: 'step without source_id',
      );
      expect(
        () => RescueCard.fromJson({
          ..._card(),
          'source_ids': ['other'],
        }),
        throwsA(isA<RescueCardFormatException>()),
        reason: 'panel cites a source missing from source_ids',
      );
    });

    test('cpr: null values stay null and the midpoint is derived', () {
      final c = RescueCard.fromJson(
        _card(
          panels: [
            {
              'type': 'cpr',
              'source_id': 's1',
              'rate_bpm': null,
              'rate_bpm_min': 100,
              'rate_bpm_max': 120,
              'rescuer_change_s': null,
              'variants': [
                {
                  'id': 'adult',
                  'label': 'Dorosły',
                  'source_id': 's1',
                  'compressions': 30,
                  'breaths': 2,
                  'initial_breaths': 0,
                  'breath_phase_s': null,
                },
              ],
              'voice': {'compress': 'Uciskaj', 'change': null},
              'aed_card_id': 'aed',
            },
          ],
        ),
      );
      final cpr = c.cpr!;
      expect(cpr.rateBpm, isNull);
      expect(cpr.effectiveRateBpm, 110);
      expect(cpr.rescuerChangeS, isNull);
      expect(cpr.variant('adult')!.breathPhaseS, isNull);
      expect(cpr.variant('x')!.compressions, 30);
      expect(cpr.voice['change'], isNull);
    });
  });

  group('RescueCardRepository', () {
    test('builds from maps and sorts by priority', () {
      final repo = RescueCardRepository(
        cards: [
          {..._card(id: 'b'), 'priority': 3},
          _card(id: 'a'),
        ],
        sources: _sources,
      );
      expect(repo.cards.map((c) => c.id), ['a', 'b']);
      expect(repo.card('a'), isNotNull);
      expect(repo.card('zzz'), isNull);
      expect(repo.source('s1')!.chipLabel, '▸ Doc, s. 3');
      expect(repo.sourcesFor(repo.card('a')!).single.sourceId, 's1');
    });

    test('rejects an unknown source id', () {
      expect(
        () => RescueCardRepository(
          cards: [_card()],
          sources: {'version': 1, 'sources': <Map<String, dynamic>>[]},
        ),
        throwsA(isA<RescueCardFormatException>()),
      );
    });

    test('rejects a card_link to a missing card', () {
      final card = _card(
        panels: [
          {
            'type': 'steps',
            'title': 'T',
            'items': [
              {
                'text': 'a',
                'source_id': 's1',
                'card_link': {'label': 'x', 'card_id': 'missing'},
              },
            ],
          },
        ],
      );
      expect(
        () => RescueCardRepository(cards: [card], sources: _sources),
        throwsA(isA<RescueCardFormatException>()),
      );
    });

    test('load reads cards and sources from an AssetBundle', () async {
      final bundle = _MapBundle({
        'assets/cards/demo.json': jsonEncode(_card()),
        'assets/cards/sources.json': jsonEncode(_sources),
      });
      final repo = await RescueCardRepository.load(bundle, ids: ['demo']);
      expect(repo.card('demo')!.name, 'Demo');
    });
  });
}
