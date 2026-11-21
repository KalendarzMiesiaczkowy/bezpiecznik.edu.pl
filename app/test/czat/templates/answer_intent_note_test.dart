import 'package:flutter_test/flutter_test.dart';

import 'package:bezpiecznik/czat/intent/map_answer.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';

void main() {
  test('answerLabelFor: rules without intent keeps label, with intent none', () {
    expect(answerLabelFor(AnswerOrigin.rules), 'Z twojego profilu');
    expect(answerLabelFor(AnswerOrigin.rules, 'map'), isNull);
    expect(answerLabelFor(AnswerOrigin.noAi, 'map'), 'Tryb bez AI: fragmenty źródeł');
  });

  test('intent and note round-trip; old JSON loads without them', () {
    final a = AssistantAnswer.fromJson({'origin': 'rules', 'intent': 'map', 'note': 'x', 'panels': []});
    expect(a.intent, 'map');
    expect(a.note, 'x');
    final b = AssistantAnswer.fromJson(a.toJson());
    expect(b.intent, 'map');
    expect(b.note, 'x');
    final old = AssistantAnswer.fromJson({'origin': 'rules', 'panels': []});
    expect(old.intent, isNull);
    expect(old.note, isNull);
    expect(old.toJson().containsKey('intent'), isFalse);
    expect(old.toJson().containsKey('note'), isFalse);
  });

  test('map answer carries intent target', () async {
    final a = await const MapAnswerService().tryAnswer('gdzie jest najbliższy schron');
    expect(a, isNotNull);
    expect(a!.intent, isNotNull);
    expect(answerLabelFor(a.origin, a.intent), isNull);
  });
}
