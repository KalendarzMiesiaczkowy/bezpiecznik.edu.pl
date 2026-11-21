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

    test('null variant means the default, an unknown one is not replaced', () {
      final c = RescueCard.fromJson(_card());
      expect(c.variantIds, ['adult', 'child']);
      expect(c.defaultVariant, 'adult');
      expect(c.selectVariant('child'), 'child');
      expect(c.selectVariant(null), 'adult');
      expect(c.selectVariant('infant'), isNull);
      expect(c.stepsFor('child').single.text, 'c');
      expect(c.stepsFor(null).single.text, 'a');
      expect(() => c.stepsFor('nope'), throwsArgumentError);
      final steps = c.panels.whereType<StepsPanel>().single;
      expect(steps.itemsFor('nope'), isNull);
      expect(steps.itemsFor(null)!.single.text, 'a');
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
      expect(cpr.variant(null)!.compressions, 30);
      expect(cpr.variant('x'), isNull, reason: 'no silent fallback');
      expect(cpr.voice['change'], isNull);
    });
  });

  group('RescueCard.fromJson: variants', () {
    Map<String, dynamic> steps(List<String> ids) => {
      'type': 'steps',
      'title': 'T',
      'variants': [
        for (final id in ids)
          {
            'id': id,
            'label': id,
            'items': [
              {'text': 'a', 'source_id': 's1'},
            ],
          },
      ],
    };
    Map<String, dynamic> cpr(List<String> ids) => {
      'type': 'cpr',
      'source_id': 's1',
      'variants': [
        for (final id in ids) {'id': id, 'label': id, 'source_id': 's1'},
      ],
    };

    test('panels with the same variant id set load (order may differ)', () {
      final c = RescueCard.fromJson(
        _card(
          panels: [
            steps(['adult', 'child']),
            steps(['child', 'adult']),
            cpr(['adult', 'child']),
          ],
        ),
      );
      expect(c.variantIds, ['adult', 'child']);
    });

    test('two steps panels with different variant ids are rejected', () {
      expect(
        () => RescueCard.fromJson(
          _card(
            panels: [
              steps(['adult', 'child']),
              steps(['adult', 'infant']),
            ],
          ),
        ),
        throwsA(isA<RescueCardFormatException>()),
      );
    });

    test('a cpr panel with a different variant id set is rejected', () {
      expect(
        () => RescueCard.fromJson(
          _card(
            panels: [
              steps(['adult', 'child', 'infant']),
              cpr(['adult', 'child']),
            ],
          ),
        ),
        throwsA(isA<RescueCardFormatException>()),
      );
    });

    test('empty variants lists are rejected', () {
      expect(
        () => RescueCard.fromJson(_card(panels: [steps([])])),
        throwsA(isA<RescueCardFormatException>()),
      );
      expect(
        () => RescueCard.fromJson(_card(panels: [cpr([])])),
        throwsA(isA<RescueCardFormatException>()),
      );
    });

    test('duplicate variant ids are rejected', () {
      expect(
        () => RescueCard.fromJson(
          _card(
            panels: [
              steps(['adult', 'adult']),
            ],
          ),
        ),
        throwsA(isA<RescueCardFormatException>()),
      );
    });
  });

  group('type errors become RescueCardFormatException', () {
    void bad(String why, Map<String, dynamic> json) {
      expect(
        () => RescueCard.fromJson(json),
        throwsA(isA<RescueCardFormatException>()),
        reason: why,
      );
    }

    test('card fields', () {
      bad('id not a string', {..._card(), 'id': 5});
      bad('phrases with a number', {
        ..._card(),
        'phrases': ['ok', 3],
      });
      bad('phrases not a list', {..._card(), 'phrases': 'x'});
      bad('source_ids with a number', {
        ..._card(),
        'source_ids': ['s1', 3],
      });
      bad('variant_words value not a list', {
        ..._card(),
        'variant_words': {'child': 'dziecko'},
      });
      bad('variant_words word not a string', {
        ..._card(),
        'variant_words': {
          'child': [1],
        },
      });
      bad('verify_note not a string', {..._card(), 'verify_note': 7});
      bad('panels not a list', {..._card(), 'panels': 'x'});
      bad('priority not an int', {..._card(), 'priority': '1'});
      bad('card_link not an object', {
        ..._card(
          panels: [
            {
              'type': 'steps',
              'title': 'T',
              'items': [
                {'text': 'a', 'source_id': 's1', 'card_link': 'rko'},
              ],
            },
          ],
        ),
      });
    });

    test('cpr fields', () {
      Map<String, dynamic> cpr(Map<String, dynamic> extra) => _card(
        panels: [
          {
            'type': 'cpr',
            'source_id': 's1',
            'variants': [
              {'id': 'adult', 'label': 'A', 'source_id': 's1'},
            ],
            ...extra,
          },
        ],
      );
      bad(
        'voice value not a string',
        cpr({
          'voice': {'compress': 3},
        }),
      );
      bad('voice not an object', cpr({'voice': 'x'}));
      bad('aed_card_id not a string', cpr({'aed_card_id': 4}));
      bad('rate_bpm not an int', cpr({'rate_bpm': '110'}));
      bad('rate_note not a string', cpr({'rate_note': 1}));
    });

    test('source records', () {
      Map<String, dynamic> src(Map<String, dynamic> extra) => {
        ..._source('s1'),
        ...extra,
      };
      for (final extra in <Map<String, dynamic>>[
        {'rects': 'x'},
        {
          'rects': [1],
        },
        {
          'rects': [
            ['a'],
          ],
        },
        {'pdf_page': '3'},
        {'doc_id': 4},
      ]) {
        expect(
          () => SourceRecord.fromJson(src(extra)),
          throwsA(isA<RescueCardFormatException>()),
          reason: '$extra',
        );
      }
      expect(
        SourceRecord.fromJson(
          src({
            'rects': [
              [1, 2.5],
            ],
          }),
        ).rects,
        [
          [1.0, 2.5],
        ],
      );
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

    group('lenient loading', () {
      late List<String> logged;
      void log(String m) => logged.add(m);
      setUp(() => logged = <String>[]);

      test('a bad card is logged and skipped, the others load', () {
        final repo = RescueCardRepository(
          cards: [
            _card(id: 'a'),
            {..._card(id: 'broken'), 'phrases': 'not a list'},
            {..._card(id: 'b'), 'priority': 2},
          ],
          sources: _sources,
          strict: false,
          log: log,
        );
        expect(repo.cards.map((c) => c.id), ['a', 'b']);
        expect(logged, hasLength(1));
        expect(logged.single, contains('phrases'));
      });

      test('a card with an unknown source is skipped', () {
        final repo = RescueCardRepository(
          cards: [
            _card(id: 'a'),
            {
              ..._card(id: 'b'),
              'source_ids': ['s1', 'nope'],
            },
          ],
          sources: _sources,
          strict: false,
          log: log,
        );
        expect(repo.card('b'), isNull);
        expect(repo.card('a'), isNotNull);
        expect(logged.single, contains('nope'));
      });

      test('a duplicate card id keeps the first and logs', () {
        final repo = RescueCardRepository(
          cards: [
            _card(id: 'a'),
            _card(id: 'a'),
          ],
          sources: _sources,
          strict: false,
          log: log,
        );
        expect(repo.cards, hasLength(1));
        expect(logged, hasLength(1));
      });

      test('a card_link to a missing card is kept, linkTarget is null', () {
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
        final repo = RescueCardRepository(
          cards: [card],
          sources: _sources,
          strict: false,
          log: log,
        );
        final link = repo.card('demo')!.stepsFor(null).single.cardLink!;
        expect(repo.linkTarget(link), isNull);
        expect(logged.single, contains('missing'));
      });

      test('strict mode still throws on the first bad card', () {
        expect(
          () => RescueCardRepository(
            cards: [
              _card(id: 'a'),
              {..._card(id: 'broken'), 'phrases': 'x'},
            ],
            sources: _sources,
          ),
          throwsA(isA<RescueCardFormatException>()),
        );
      });

      test('load skips a missing and a malformed card file', () async {
        final bundle = _MapBundle({
          'assets/cards/ok.json': jsonEncode(_card(id: 'ok')),
          'assets/cards/bad.json': '{not json',
          'assets/cards/wrong.json': jsonEncode({..._card(), 'id': 7}),
          'assets/cards/sources.json': jsonEncode(_sources),
        });
        final repo = await RescueCardRepository.load(
          bundle,
          ids: ['ok', 'missing', 'bad', 'wrong'],
          log: log,
        );
        expect(repo.cards.map((c) => c.id), ['ok']);
        expect(logged, hasLength(3));
        expect(logged.any((m) => m.contains('"missing"')), isTrue);
        expect(logged.any((m) => m.contains('"bad"')), isTrue);
      });

      test('load throws when sources.json is unreadable', () async {
        final bundle = _MapBundle({
          'assets/cards/ok.json': jsonEncode(_card(id: 'ok')),
        });
        await expectLater(
          RescueCardRepository.load(bundle, ids: ['ok'], log: log),
          throwsA(anything),
        );
      });
    });

    group('aed_card_id', () {
      Map<String, dynamic> rko({String? aed = 'aed'}) => _card(
        id: 'rko',
        panels: [
          {
            'type': 'cpr',
            'source_id': 's1',
            'variants': [
              {'id': 'adult', 'label': 'A', 'source_id': 's1'},
            ],
            'aed_card_id': aed,
          },
        ],
      );

      test('is null when the AED card is not loaded', () {
        final repo = RescueCardRepository(
          cards: [rko()],
          sources: _sources,
          log: (_) {},
        );
        expect(repo.card('rko')!.cpr!.aedCardId, isNull);
        expect(repo.card('rko')!.cpr!.variants, hasLength(1));
      });

      test('is kept when the AED card is loaded', () {
        final repo = RescueCardRepository(
          cards: [
            rko(),
            _card(id: 'aed'),
          ],
          sources: _sources,
        );
        expect(repo.card('rko')!.cpr!.aedCardId, 'aed');
      });

      test('RescueCard.fromJson alone keeps the raw value', () {
        expect(RescueCard.fromJson(rko()).cpr!.aedCardId, 'aed');
      });
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
