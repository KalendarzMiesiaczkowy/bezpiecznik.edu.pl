import 'package:bezpiecznik/czat/answer/answer_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('sentenceCase lowers title case, keeps acronyms', () {
    expect(sentenceCase('Sygnały Alarmowe'), 'Sygnały alarmowe');
    expect(sentenceCase('Przygotowanie do Powodzi'), 'Przygotowanie do powodzi');
    expect(sentenceCase('Zasady RKO'), 'Zasady RKO');
  });

  final v = AnswerValidator();

  final lift = chunk(
    'c1',
    'W razie pożaru nie wchodź do windy. Zejdź schodami na zewnątrz budynku.',
  );
  final cpr = chunk(
    'c2',
    'Uciskaj środek klatki piersiowej 30 razy, potem wykonaj 2 oddechy ratownicze. '
    'Nie przerywaj uciśnięć bez potrzeby.',
  );
  final bag = chunk(
    'c3',
    'Zapakuj do plecaka wodę, latarkę z zapasowymi bateriami i apteczkę.',
  );

  RejectReason? check(String t, c) => v.checkItem(t, c);

  test('accepts a faithful paraphrase', () {
    expect(check('Nie wchodź do windy.', lift), isNull);
    expect(check('Zejdź schodami na zewnątrz budynku.', lift), isNull);
    expect(check('Uciskaj środek klatki piersiowej 30 razy.', cpr), isNull);
    expect(check('Zapakuj wodę, latarkę i apteczkę.', bag), isNull);
  });

  test('invented number', () {
    expect(check('Uciskaj klatkę piersiową 15 razy.', cpr), RejectReason.invalidNumber);
    expect(check('Wykonaj 3 oddechy ratownicze.', cpr), RejectReason.invalidNumber);
  });

  test('invented spelled-out number', () {
    expect(check('Wykonaj trzy oddechy ratownicze.', cpr), RejectReason.invalidNumber);
  });

  test('decimal comma equals dot', () {
    final c = chunk('c4', 'Zapas wody to 2,5 litra na osobę dziennie.');
    expect(check('Zapas wody to 2.5 litra na osobę.', c), isNull);
  });

  test('dropped negation', () {
    expect(check('Wchodź do windy.', lift), RejectReason.droppedNegation);
    expect(check('Przerywaj uciśnięcia.', cpr), RejectReason.droppedNegation);
  });

  test('added negation', () {
    expect(check('Nie schodź schodami na zewnątrz.', lift), RejectReason.addedNegation);
    expect(check('Nie zapakuj wody do plecaka.', bag), RejectReason.addedNegation);
  });

  test('negation in the item but none in the source at all', () {
    expect(check('Nigdy nie zabieraj apteczki.', bag), RejectReason.addedNegation);
  });

  test('negation of one clause does not poison the next', () {
    final c = chunk('c5', 'Nie zapalaj świec, używaj latarki.');
    expect(check('Używaj latarki.', c), isNull);
    expect(check('Nie zapalaj świec.', c), isNull);
    expect(check('Zapalaj świece.', c), RejectReason.droppedNegation);
  });

  test('"zakaz" counts as negation', () {
    final c = chunk('c6', 'Obowiązuje zakaz używania otwartego ognia.');
    expect(check('Używaj otwartego ognia.', c), RejectReason.droppedNegation);
  });

  test('keyword overlap too low', () {
    expect(
      check('Zadzwoń do rodziny i poinformuj sąsiadów.', lift),
      RejectReason.lowOverlap,
    );
  });

  test('empty and overlong items', () {
    expect(check('  ', lift), RejectReason.emptyText);
    expect(check('Zejdź schodami ${'na zewnątrz ' * 30}', lift), RejectReason.tooLong);
  });

  test('inflection tolerant overlap', () {
    expect(check('Zejdź schodami poza budynek na zewnątrz.', lift), isNull);
  });

  group('validate()', () {
    final chunks = [lift, cpr];

    Map<String, Object?> panels(List<Object?> p) => {'panels': p};

    test('unknown source_id removes the item, unknown type the panel', () {
      final r = v.validate(
        panels([
          {
            'type': 'steps',
            'title': 'Teraz',
            'items': [
              {'text': 'Nie wchodź do windy.', 'source_id': 'c1'},
              {'text': 'Nie wchodź do windy.', 'source_id': 'zmyslone'},
              {'text': 'Zejdź schodami.', 'source_id': null},
            ],
          },
          {'type': 'call'},
          {'type': 'map', 'target': 'nearest_shelter'},
          {'type': 'cpr', 'source_id': 'c2'},
        ]),
        chunks,
      );
      expect(r.panels.length, 1);
      expect((r.panels.first['items'] as List).length, 1);
      expect(r.rejected.where((e) => e.reason == RejectReason.unknownSource).length, 2);
    });

    test('panel without surviving items is removed', () {
      final r = v.validate(
        panels([
          {
            'type': 'bullets',
            'title': 'x',
            'items': [
              {'text': 'Wchodź do windy.', 'source_id': 'c1'},
            ],
          },
        ]),
        chunks,
      );
      expect(r.hasContent, isFalse);
      expect(r.rejected.single.reason, RejectReason.droppedNegation);
    });

    test('quote needs a retrieved source, duplicates collapse', () {
      final r = v.validate(
        panels([
          {'type': 'quote', 'source_id': 'c1'},
          {'type': 'quote', 'source_id': 'c1'},
          {'type': 'quote', 'source_id': 'nie-ma'},
        ]),
        chunks,
      );
      expect(r.panels.length, 1);
    });

    test('missing title gets a neutral default, long title is cut', () {
      final r = v.validate(
        panels([
          {
            'type': 'steps',
            'title': 'A' * 80,
            'items': [
              {'text': 'Nie wchodź do windy.', 'source_id': 'c1'},
            ],
          },
          {
            'type': 'bullets',
            'items': [
              {'text': 'Zejdź schodami.', 'source_id': 'c1'},
            ],
          },
        ]),
        chunks,
      );
      expect(r.panels[0]['title'], 'Co zrobić');
      expect(r.panels[1]['title'], 'Najważniejsze');
    });

    test('titles: fixed list or short and grounded in the cited chunks', () {
      String titleOf(Object? t) {
        final r = v.validate(
          panels([
            {
              'type': 'steps',
              'title': t,
              'items': [
                {'text': 'Nie wchodź do windy.', 'source_id': 'c1'},
              ],
            },
          ]),
          chunks,
        );
        return r.panels.single['title'] as String;
      }

      expect(titleOf('Podaj 2 tabletki'), 'Co zrobić');
      expect(titleOf('teraz'), 'Teraz');
      expect(titleOf('Do zapamiętania'), 'Do zapamiętania');
      expect(titleOf(42), 'Co zrobić');
      // Not on the list, but every content word is in the cited chunk.
      expect(titleOf('Zejdź schodami'), 'Zejdź schodami');
      expect(titleOf('Nie wchodź do windy'), 'Nie wchodź do windy');
      // Words missing from the source, empty, or longer than 30 characters.
      expect(titleOf('Zadzwoń po lekarza'), 'Co zrobić');
      expect(titleOf('  '), 'Co zrobić');
      expect(titleOf('Zejdź schodami na zewnątrz budynku'), 'Co zrobić');
    });

    test('garbage structures do not throw', () {
      expect(v.validate({'panels': 'x'}, chunks).hasContent, isFalse);
      expect(v.validate({'panels': [1, null, {'type': 'steps', 'items': 3}]}, chunks).hasContent, isFalse);
    });
  });

  group('strict coverage (BG07)', () {
    final cprFull = chunk(
      'c7',
      'Połóż poszkodowanego na plecach na twardym, płaskim podłożu. '
      'Uciskaj środek klatki piersiowej 30 razy, potem wykonaj 2 oddechy.',
    );
    final drink = chunk('c8', 'Nie podawaj nic do picia osobie nieprzytomnej.');
    final fire = chunk('c9', 'Nie wchodź do windy podczas pożaru.');
    final ice = chunk('c10', 'Na oparzenie przyłóż lód i zadzwoń po pomoc.');

    test('invented actions and drugs are rejected', () {
      for (final t in [
        'Połóż poszkodowanego na plecach i podaj aspirynę',
        'Uciskaj środek klatki piersiowej 30 razy i podaj nitroglicerynę pod język',
        'Połóż poszkodowanego na brzuchu na twardym podłożu',
      ]) {
        expect(check(t, cprFull), isNotNull, reason: t);
      }
    });

    test('short content words are checked too', () {
      expect(check('Przyłóż lód.', ice), isNull);
      expect(check('Przyłóż gaz.', ice), isNotNull);
      expect(check('Przyłóż lód na oko.', ice), isNotNull);
      expect(check('Zadzwoń po pomoc i przyłóż lód.', ice), isNull);
    });

    test('negation survives a different verb form', () {
      for (final t in [
        'Podaj osobie nieprzytomnej coś do picia',
        'Osobie nieprzytomnej podaj wodę do picia',
        'Podaj osobie nieprzytomnej do picia',
      ]) {
        expect(check(t, drink), isNotNull, reason: t);
      }
      expect(check('Zjedź windą podczas pożaru na parter', fire), isNotNull);
      expect(check('Skorzystaj z windy podczas pożaru', fire), isNotNull);
      expect(check('Jedź windą podczas pożaru', fire), isNotNull);
    });

    test('numbers are bound to their units', () {
      expect(check('Uciskaj 2 razy, potem wykonaj 30 oddechów', cprFull), RejectReason.invalidNumber);
      expect(check('Uciskaj klatkę piersiową 30 sekund', cprFull), RejectReason.invalidNumber);
      expect(check('Uciskaj klatkę piersiową przez piętnaście minut', cprFull), RejectReason.invalidNumber);
      expect(check('Uciskaj klatkę piersiową kilka razy', cprFull), RejectReason.invalidNumber);
      expect(check('Uciskaj klatkę piersiową sto razy', cprFull), RejectReason.invalidNumber);
    });

    test('numeral words equal digits when bound to the same unit', () {
      expect(check('Wykonaj dwa oddechy.', cprFull), isNull);
      expect(check('Uciskaj środek klatki piersiowej trzydzieści razy.', cprFull), isNull);
    });

    test('legit paraphrases still pass', () {
      expect(check('Połóż poszkodowanego na plecach na twardym, płaskim podłożu.', cprFull), isNull);
      expect(check('Na twardym płaskim podłożu połóż poszkodowanego na plecach.', cprFull), isNull);
      expect(check('Uciskaj środek klatki piersiowej 30 razy, potem wykonaj 2 oddechy.', cprFull), isNull);
      expect(check('Uciskaj klatkę piersiową 30 razy.', cprFull), isNull);
      expect(check('Nie podawaj osobie nieprzytomnej nic do picia.', drink), isNull);
      expect(check('Nie wchodź do windy podczas pożaru.', fire), isNull);
      expect(check('Podczas pożaru nie wchodź do windy.', fire), isNull);
    });
  });
}
