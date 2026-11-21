import 'package:bezpiecznik/czat/answer/answer_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
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
      expect((r.panels[0]['title'] as String).length, kMaxTitleChars);
      expect(r.panels[1]['title'], 'Najważniejsze');
    });

    test('garbage structures do not throw', () {
      expect(v.validate({'panels': 'x'}, chunks).hasContent, isFalse);
      expect(v.validate({'panels': [1, null, {'type': 'steps', 'items': 3}]}, chunks).hasContent, isFalse);
    });
  });
}
