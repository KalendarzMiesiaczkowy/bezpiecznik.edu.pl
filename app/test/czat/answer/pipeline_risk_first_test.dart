import 'package:bezpiecznik/czat/answer/pipeline_answer_service.dart';
import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const ctx = ChatContext(chatId: 'c');

PipelineAnswerService svc(FakeEngine engine, {required bool risk}) => PipelineAnswerService(
  search: (_) async => found([chunk('c1', 'W razie pożaru nie wchodź do windy.')]),
  engine: engine,
  isRisk: (_) => risk,
);

void main() {
  test('risk phrase: a risk thinking event arrives before the model is done', () async {
    final engine = FakeEngine([null]); // the model hangs
    final events = <AnswerEvent>[];
    final sub = svc(engine, risk: true).answer('pożar w bloku', ctx).listen(events.add);
    while (engine.requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final thinking = events.whereType<AnswerThinking>().toList();
    expect(thinking.first.risk, isFalse); // emitted before isRisk resolves
    expect(thinking.where((e) => e.risk), isNotEmpty);
    expect(thinking.last.risk, isTrue); // composing keeps the flag
    expect(events.whereType<AnswerReady>(), isEmpty);
    await sub.cancel();
  });

  test('risk phrase: still exactly one Ready, starting with call', () async {
    final engine = FakeEngine([const LlmTimeout()]);
    final ev = await svc(engine, risk: true).answer('pożar w bloku', ctx).toList();
    expect(ev.last, isA<AnswerReady>());
    expect(ev.whereType<AnswerReady>().length + ev.whereType<AnswerFailed>().length, 1);
    expect((ev.last as AnswerReady).answer.panels.first.type, 'call');
  });

  test('no risk: no thinking event carries the flag', () async {
    final engine = FakeEngine([const LlmTimeout()]);
    final ev = await svc(engine, risk: false).answer('zapas wody', ctx).toList();
    expect(ev.whereType<AnswerThinking>().where((e) => e.risk), isEmpty);
  });
}
