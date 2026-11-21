import 'dart:async';
import 'dart:convert';

import 'package:bezpiecznik/czat/answer/pipeline_answer_service.dart';
import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const ctx = ChatContext(chatId: 'c');

final lift = chunk('c1', 'W razie pożaru nie wchodź do windy. Zejdź schodami na zewnątrz budynku.');
final water = chunk('c2', 'Zapas wody to trzy litry na osobę na dobę.', page: '6');

String good() => jsonEncode({
  'panels': [
    {
      'type': 'steps',
      'title': 'Teraz',
      'items': [
        {'text': 'Nie wchodź do windy.', 'source_id': 'c1'},
        {'text': 'Zejdź schodami na zewnątrz.', 'source_id': 'c1'},
      ],
    },
  ],
});

PipelineAnswerService svc(
  FakeEngine engine, {
  RetrievalResult? result,
  bool risk = false,
  String profile = '',
  void Function(String)? log,
}) => PipelineAnswerService(
  search: (_) async => result ?? found([lift, water]),
  engine: engine,
  isRisk: (_) => risk,
  profileContext: () async => profile,
  onLog: log,
);

Future<List<AnswerEvent>> run(PipelineAnswerService s, [String q = 'pożar w bloku']) =>
    s.answer(q, ctx).toList();

AssistantAnswer ready(List<AnswerEvent> ev) {
  expect(ev.last, isA<AnswerReady>());
  expect(ev.whereType<AnswerReady>().length + ev.whereType<AnswerFailed>().length, 1);
  return (ev.last as AnswerReady).answer;
}

List<String> types(AssistantAnswer a) => [for (final p in a.panels) p.type];

void main() {
  test('happy path: events, panels, sources, request shape', () async {
    final e = FakeEngine([
      [good()],
    ]);
    final ev = await run(svc(e, profile: 'Mieszkanie: 7. piętro.'));
    expect((ev[0] as AnswerThinking).phase, ThinkingPhase.searching);
    expect((ev[1] as AnswerThinking).phase, ThinkingPhase.composing);
    final a = ready(ev);
    expect(a.origin, AnswerOrigin.ai);
    expect(types(a), ['steps']);
    expect(a.sources.keys, ['c1']);
    expect(a.sources['c1']!.docShort, 'Poradnik');
    expect(a.sources['c1']!.pageLabel, '14');
    final req = e.requests.single;
    expect(req.jsonMode, isTrue);
    final user = req.messages.single.content;
    expect(user, contains('c1'));
    expect(user, contains('c2'));
    expect(user, contains('7. piętro'));
    expect(user, contains('Pytanie: pożar w bloku'));
    expect(req.systemPrompt, contains('WYŁĄCZNIE'));
  });

  test('previous question is passed to the model', () async {
    final e = FakeEngine([
      [good()],
    ]);
    await svc(e).answer('a w nocy?', const ChatContext(chatId: 'c', previousQuestion: 'pożar')).toList();
    expect(e.requests.single.messages.single.content, contains('Poprzednie pytanie: pożar'));
  });

  test('fenced answer with prose is parsed', () async {
    final e = FakeEngine([
      ['Proszę:\n```json\n', good(), '\n```'],
    ]);
    expect(types(ready(await run(svc(e)))), ['steps']);
    expect(e.requests.length, 1);
  });

  test('truncated output is retried once and then accepted', () async {
    final g = good();
    final e = FakeEngine([
      [g.substring(0, g.length - 20)],
      [g],
    ]);
    final a = ready(await run(svc(e)));
    expect(types(a), ['steps']);
    expect(e.requests.length, 2);
    expect(e.requests[1].messages.single.content, contains('nie była poprawnym JSON'));
  });

  test('second parse failure falls back to quote panels (still sourced)', () async {
    final e = FakeEngine([
      ['not json'],
      ['{"panels": ['],
    ]);
    final a = ready(await run(svc(e)));
    expect(e.requests.length, 2);
    expect(types(a), ['quote', 'quote']);
    expect(a.origin, AnswerOrigin.ai);
    expect(a.sources.keys, containsAll(['c1', 'c2']));
    expect(a.sources['c1']!.text, lift.text);
  });

  test('validation failure (dropped negation + invented number) -> quotes', () async {
    final logs = <String>[];
    final e = FakeEngine([
      [
        jsonEncode({
          'panels': [
            {
              'type': 'steps',
              'title': 'x',
              'items': [
                {'text': 'Wchodź do windy.', 'source_id': 'c1'},
                {'text': 'Zapas wody to 5 litrów.', 'source_id': 'c2'},
                {'text': 'Zejdź schodami.', 'source_id': 'zmyslone'},
              ],
            },
          ],
        }),
      ],
    ]);
    final a = ready(await run(svc(e, log: logs.add)));
    expect(types(a), ['quote', 'quote']);
    expect(e.requests.length, 1, reason: 'validation failure is not retried');
    expect(logs.where((l) => l.startsWith('rejected')).length, 3);
  });

  test('partially valid answer keeps only covered items', () async {
    final e = FakeEngine([
      [
        jsonEncode({
          'panels': [
            {
              'type': 'steps',
              'title': 'x',
              'items': [
                {'text': 'Nie wchodź do windy.', 'source_id': 'c1'},
                {'text': 'Wchodź do windy.', 'source_id': 'c1'},
              ],
            },
          ],
        }),
      ],
    ]);
    final a = ready(await run(svc(e)));
    expect(((a.panels.single as StepsPanel).items).length, 1);
  });

  test('model panels other than steps/bullets/quote never reach the answer', () async {
    final e = FakeEngine([
      [
        jsonEncode({
          'panels': [
            {'type': 'call'},
            {'type': 'cpr', 'source_id': 'c1'},
            {'type': 'quote', 'source_id': 'c2'},
          ],
        }),
      ],
    ]);
    final a = ready(await run(svc(e))); // no risk
    expect(types(a), ['quote']);
  });

  test('empty panels from the model -> calm noSource refusal', () async {
    final e = FakeEngine([
      ['{"panels":[]}'],
    ]);
    final a = ready(await run(svc(e)));
    expect(a.origin, AnswerOrigin.refusal);
    expect((a.panels.single as NoSourcePanel).kind, NoSourceKind.noSource);
  });

  test('LlmUnavailable -> quotes with no_ai origin, not a crash', () async {
    final e = FakeEngine([const LlmUnavailable('Model AI jest niedostępny.')]);
    final ev = await run(svc(e));
    final a = ready(ev);
    expect(a.origin, AnswerOrigin.noAi);
    expect(types(a), ['quote', 'quote']);
    expect(e.requests.length, 1);
  });

  test('LlmTimeout and LlmDisabled behave the same', () async {
    for (final err in <LlmException>[const LlmTimeout(), const LlmDisabled(), const LlmError('x')]) {
      final a = ready(await run(svc(FakeEngine([err]))));
      expect(types(a), ['quote', 'quote'], reason: '$err');
    }
  });

  test('fallback shows at most three quotes', () async {
    final many = [for (var i = 0; i < 4; i++) chunk('k$i', 'Tekst $i')];
    final a = ready(await run(svc(FakeEngine([const LlmTimeout()]), result: found(many))));
    expect(types(a), ['quote', 'quote', 'quote']);
  });

  group('refusals', () {
    test('noSource: calm refusal, model never called, no call panel', () async {
      final e = FakeEngine([]);
      final ev = await run(
        svc(e, result: const RetrievalResult(decision: RetrievalDecision.noSource, chunks: [])),
        'jaka dawka ibuprofenu dla psa',
      );
      final a = ready(ev);
      expect(e.requests, isEmpty);
      expect(a.origin, AnswerOrigin.refusal);
      expect(types(a), ['no_source']);
      expect((a.panels.single as NoSourcePanel).kind, NoSourceKind.noSource);
      expect(ev.whereType<AnswerThinking>().length, 1);
    });

    test('offTopic: refusal, never a call panel even on a risk phrase', () async {
      final e = FakeEngine([]);
      final a = ready(await run(
        svc(e, risk: true, result: const RetrievalResult(decision: RetrievalDecision.offTopic, chunks: [])),
        'przepis na pierogi',
      ));
      expect(types(a), ['no_source']);
      expect((a.panels.single as NoSourcePanel).kind, NoSourceKind.offTopic);
      expect(jsonEncode(a.toJson()).contains('112'), isFalse);
    });

    test('noSource with a risk phrase gets the call panel first', () async {
      final a = ready(await run(
        svc(FakeEngine([]), risk: true, result: const RetrievalResult(decision: RetrievalDecision.noSource, chunks: [])),
        'krwawi mi pies',
      ));
      expect(types(a), ['call', 'no_source']);
    });

    test('refusal JSON carries no 112 text', () async {
      final a = ready(await run(
        svc(FakeEngine([]), result: const RetrievalResult(decision: RetrievalDecision.noSource, chunks: [])),
      ));
      expect(jsonEncode(a.toJson()).contains('112'), isFalse);
    });
  });

  group('call panel (app-added)', () {
    test('risk question: call first, then model panels', () async {
      final a = ready(await run(svc(FakeEngine([[good()]]), risk: true)));
      expect(types(a), ['call', 'steps']);
      expect(a.panels.whereType<CallPanel>().length, 1);
    });

    test('risk + quote fallback: call first', () async {
      final a = ready(await run(svc(FakeEngine([const LlmTimeout()]), risk: true)));
      expect(types(a), ['call', 'quote', 'quote']);
    });

    test('model-supplied call is ignored, only the app adds one', () async {
      final e = FakeEngine([
        [
          jsonEncode({
            'panels': [
              {'type': 'call'},
              {'type': 'quote', 'source_id': 'c1'},
            ],
          }),
        ],
      ]);
      expect(types(ready(await run(svc(e, risk: true)))), ['call', 'quote']);
    });

    test('no risk: no call', () async {
      final a = ready(await run(svc(FakeEngine([[good()]]))));
      expect(types(a), ['steps']);
    });
  });

  group('cancel', () {
    test('cancelling the subscription cancels the engine and emits nothing more', () async {
      final e = FakeEngine([null]); // hangs
      final got = <AnswerEvent>[];
      final sub = svc(e).answer('pożar', ctx).listen(got.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(e.requests.length, 1);
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(e.cancelCalls, 1);
      expect(e.streamCancelled, isTrue);
      expect(got.whereType<AnswerReady>(), isEmpty);
      expect(got.whereType<AnswerFailed>(), isEmpty);
    });

    test('cancel during retrieval never calls the model', () async {
      final gate = Completer<RetrievalResult>();
      final e = FakeEngine([
        [good()],
      ]);
      final s = PipelineAnswerService(
        search: (_) => gate.future,
        engine: e,
        isRisk: (_) => false,
      );
      final sub = s.answer('pożar', ctx).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      gate.complete(found([lift]));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(e.requests, isEmpty);
    });
  });

  test('retrieval exception becomes AnswerFailed, stream closes', () async {
    final s = PipelineAnswerService(
      search: (_) async => throw StateError('db'),
      engine: FakeEngine([]),
      isRisk: (_) => false,
    );
    final ev = await s.answer('x', ctx).toList();
    expect(ev.last, isA<AnswerFailed>());
  });

  test('profile failure does not break the answer', () async {
    final s = PipelineAnswerService(
      search: (_) async => found([lift]),
      engine: FakeEngine([
        [good()],
      ]),
      isRisk: (_) => false,
      profileContext: () async => throw StateError('x'),
    );
    expect(types(ready(await s.answer('pożar', ctx).toList())), ['steps']);
  });

  group('noAi (per-request "Tryb bez AI")', () {
    test('awaited setting true: model never called, no_ai quotes', () async {
      final e = FakeEngine([
        [good()],
      ]);
      final s = PipelineAnswerService(
        search: (_) async => found([lift]),
        engine: e,
        isRisk: (_) => false,
        noAi: () async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return true;
        },
      );
      final a = ready(await s.answer('pożar', ctx).toList());
      expect(e.requests, isEmpty);
      expect(a.origin, AnswerOrigin.noAi);
      expect(types(a), ['quote']);
    });

    test('false or failing setting keeps the model', () async {
      for (final f in <Future<bool> Function()>[
        () async => false,
        () async => throw StateError('settings'),
      ]) {
        final s = PipelineAnswerService(
          search: (_) async => found([lift]),
          engine: FakeEngine([
            [good()],
          ]),
          isRisk: (_) => false,
          noAi: f,
        );
        expect(types(ready(await s.answer('pożar', ctx).toList())), ['steps']);
      }
    });
  });
}
