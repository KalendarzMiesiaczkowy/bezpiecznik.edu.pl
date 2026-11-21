import 'dart:async';

import 'package:bezpiecznik/alarm/panel/call_gps.dart';
import 'package:bezpiecznik/alarm/panel/call_panel.dart';
import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/czat/ui/chat_screen.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<List<Uri>> pumpChat(WidgetTester tester, AnswerService service) async {
  tester.view.physicalSize = const Size(1080, 2400); // Ahem test glyphs overflow the 112 row below ~350 dp
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final launched = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        answerServiceProvider.overrideWithValue(service),
        chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
        callLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
        canSendSmsProvider.overrideWith((_) async => true),
        callGpsProvider.overrideWith(
          (_) => Stream.value(const CallGps(access: LocationAccess.serviceOff)),
        ),
      ],
      child: MaterialApp(theme: buildBzTheme(), home: const ChatScreen()),
    ),
  );
  return launched;
}

Future<void> ask(WidgetTester tester, String q) async {
  await tester.enterText(find.byKey(const Key('composer-field')), q);
  await tester.pump();
  await tester.tap(find.byKey(const Key('composer-send')));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('risk: ZADZWOŃ 112 shows while the answer is pending, then stays once', (tester) async {
    final answer = StreamController<AnswerEvent>();
    final launched = await pumpChat(
      tester,
      FakeAnswerService(script: (_, _) => answer.stream),
    );
    await ask(tester, 'pożar w bloku');

    answer.add(const AnswerThinking(ThinkingPhase.searching, true));
    await tester.pump();
    expect(find.text(call112Label), findsOneWidget);
    expect(find.byKey(const Key('thinking-label')), findsOneWidget);
    // The call panel sits above the thinking indicator.
    expect(
      tester.getTopLeft(find.text(call112Label)).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('thinking-label'))).dy),
    );

    // A later phase without the flag keeps the panel (sticky).
    answer.add(const AnswerThinking(ThinkingPhase.composing));
    await tester.pump();
    expect(find.text(call112Label), findsOneWidget);
    final before = tester.getTopLeft(find.text(call112Label)).dy;

    answer.add(
      AnswerReady(
        AssistantAnswer.fromJson({
          'origin': 'ai',
          'panels': [
            {'type': 'call'},
            {
              'type': 'no_source',
              'kind': 'no_source',
            },
          ],
        }),
      ),
    );
    await answer.close();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('thinking-label')), findsNothing);
    expect(find.text(call112Label), findsOneWidget);
    expect(tester.getTopLeft(find.text(call112Label)).dy, before); // no jump
    expect(launched, isEmpty); // nothing dialled without a tap
  });

  testWidgets('no risk: the thinking bubble has no call panel', (tester) async {
    final answer = StreamController<AnswerEvent>();
    await pumpChat(tester, FakeAnswerService(script: (_, _) => answer.stream));
    await ask(tester, 'zapas wody');
    answer.add(const AnswerThinking(ThinkingPhase.composing));
    await tester.pump();
    expect(find.byKey(const Key('thinking-label')), findsOneWidget);
    expect(find.text(call112Label), findsNothing);
    await answer.close();
    await tester.pump();
  });
  testWidgets('stopping a risk answer keeps the 112 panel', (tester) async {
    final answer = StreamController<AnswerEvent>();
    final launched = await pumpChat(tester, FakeAnswerService(script: (_, _) => answer.stream));
    await ask(tester, 'pożar w bloku');
    answer.add(const AnswerThinking(ThinkingPhase.searching, true));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-stop')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('thinking-label')), findsNothing);
    expect(find.text(call112Label), findsOneWidget);
    expect(launched, isEmpty);
    unawaited(answer.close()); // the subscription is cancelled: close never completes
  });
}
