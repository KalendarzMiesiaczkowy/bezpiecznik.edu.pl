import 'package:bezpiecznik/czat/answer/answer_builder.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Map<String, Object?> _steps(String title, List<String> texts, {String type = 'steps'}) => {
  'type': type,
  'title': title,
  'items': [
    for (final t in texts) {'text': t, 'source_id': 'c1'},
  ],
};

void main() {
  final chunks = [chunk('c1', 'tekst')];

  List<String> itemTexts(ChatPanel p) => [for (final i in (p as StepsPanel).items) i.text];

  // The on-device model often writes one panel per step, each numbered "1".
  test('one-step panels with the same title become one numbered list', () {
    final a = buildModelAnswer(
      [
        _steps('Co zrobić', ['Pierwszy krok.']),
        _steps('Co zrobić', ['Drugi krok.']),
        _steps('Co zrobić', ['Trzeci krok.']),
      ],
      chunks,
      risk: false,
    );
    expect(a.panels, hasLength(1));
    expect(itemTexts(a.panels.single), ['Pierwszy krok.', 'Drugi krok.', 'Trzeci krok.']);
  });

  test('panels with different titles or types stay apart', () {
    final a = buildModelAnswer(
      [
        _steps('Teraz', ['A.']),
        _steps('Potem', ['B.']),
        _steps('Potem', ['C.'], type: 'bullets'),
      ],
      chunks,
      risk: false,
    );
    expect(a.panels, hasLength(3));
  });

  test('only neighbours merge: a quote in between keeps the order of the answer', () {
    final a = buildModelAnswer(
      [
        _steps('Teraz', ['A.']),
        {'type': 'quote', 'source_id': 'c1'},
        _steps('Teraz', ['B.']),
      ],
      chunks,
      risk: false,
    );
    expect([for (final p in a.panels) p.type], ['steps', 'quote', 'steps']);
  });

  test('the call panel still goes first for a risk phrase', () {
    final a = buildModelAnswer(
      [_steps('Teraz', ['A.']), _steps('Teraz', ['B.'])],
      chunks,
      risk: true,
    );
    expect([for (final p in a.panels) p.type], ['call', 'steps']);
  });
}
