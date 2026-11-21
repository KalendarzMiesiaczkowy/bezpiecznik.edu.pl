import 'dart:async';

import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/czat/ui/chat_controller.dart';
import 'package:bezpiecznik/czat/ui/chat_screen.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<ProviderContainer> pumpChat(WidgetTester tester, AnswerService service) async {
  final store = ChatStore.inMemory();
  final container = ProviderContainer(
    overrides: [
      answerServiceProvider.overrideWithValue(service),
      chatStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildBzTheme(), home: const ChatScreen()),
    ),
  );
  return container;
}

void main() {
  testWidgets('empty state: heading, 4 quick actions, note, composer hint', (tester) async {
    await pumpChat(tester, FakeAnswerService());
    expect(find.text('Co się dzieje?'), findsOneWidget);
    for (final l in ['Ktoś nie oddycha', 'Brak prądu', 'Alarm / schron', 'Ewakuacja']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('Działa bez internetu. Nie zastępuje 112.'), findsOneWidget);
    expect(find.text('Opisz sytuację…'), findsOneWidget);
    expect(find.byKey(const Key('composer-stop')), findsNothing);
  });

  testWidgets('quick action tiles are at least 64 dp high', (tester) async {
    await pumpChat(tester, FakeAnswerService());
    for (final l in ['Ktoś nie oddycha', 'Brak prądu', 'Alarm / schron', 'Ewakuacja']) {
      final tile = find.ancestor(of: find.text(l), matching: find.byType(Container)).first;
      expect(tester.getSize(tile).height, greaterThanOrEqualTo(64));
    }
  });

  testWidgets('tapping a quick action sends its label and hides the empty state', (tester) async {
    final service = FakeAnswerService();
    await pumpChat(tester, service);
    await tester.tap(find.text('Brak prądu'));
    await tester.pump();
    expect(service.questions, ['Brak prądu']);
    expect(find.text('Co się dzieje?'), findsNothing);
    expect(find.byKey(const Key('user-bubble')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('typing and sending shows a right-aligned bubble, then panels with a source chip', (tester) async {
    final service = FakeAnswerService();
    await pumpChat(tester, service);
    await tester.enterText(find.byKey(const Key('composer-field')), 'Jak przechować insulinę?');
   await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(service.questions, ['Jak przechować insulinę?']);
    final bubble = find.byKey(const Key('user-bubble'));
    expect(bubble, findsOneWidget);
    expect(tester.getTopRight(bubble).dx, greaterThan(tester.view.physicalSize.width / tester.view.devicePixelRatio - 40));
    expect(find.text('Przykładowy krok pierwszy'), findsOneWidget);
    expect(find.text('▸ Przykład, s. 14'), findsNWidgets(2));
    // The input is cleared after sending.
    expect(tester.widget<TextField>(find.byKey(const Key('composer-field'))).controller!.text, isEmpty);
  });

  testWidgets('send is disabled for empty or whitespace-only input', (tester) async {
    final service = FakeAnswerService();
    await pumpChat(tester, service);
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.enterText(find.byKey(const Key('composer-field')), '   ');
   await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    expect(service.questions, isEmpty);
  });

  testWidgets('composer: hit targets are at least 48 dp', (tester) async {
    await pumpChat(tester, FakeAnswerService(script: (q, c) => StreamController<AnswerEvent>().stream));
    await tester.enterText(find.byKey(const Key('composer-field')), 'x');
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    for (final k in ['composer-send', 'composer-stop']) {
      final s = tester.getSize(find.byKey(Key(k)));
      expect(s.width, greaterThanOrEqualTo(48), reason: k);
      expect(s.height, greaterThanOrEqualTo(48), reason: k);
    }
  });

  testWidgets('while generating: thinking skeleton, Stop and Send; Stop interrupts', (tester) async {
    final stream = StreamController<AnswerEvent>();
    final service = FakeAnswerService(script: (q, c) => stream.stream);
    final container = await pumpChat(tester, service);
    await tester.enterText(find.byKey(const Key('composer-field')), 'Pytanie');
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();

    expect(find.text('Szukam w źródłach…'), findsOneWidget);
    expect(find.byKey(const Key('composer-stop')), findsOneWidget);
    expect(find.byKey(const Key('composer-send')), findsOneWidget);
    // Stop is left of the field, Send right of it.
    expect(
      tester.getCenter(find.byKey(const Key('composer-stop'))).dx,
      lessThan(tester.getCenter(find.byKey(const Key('composer-field'))).dx),
    );

    stream.add(const AnswerThinking(ThinkingPhase.composing));
    stream.add(const AnswerPartialText('Wstępny tekst'));
    await tester.pump();
    expect(find.text('Układam odpowiedź…'), findsOneWidget);
    expect(find.text('Wstępny tekst'), findsOneWidget);

    await tester.tap(find.byKey(const Key('composer-stop')));
    await tester.pump();
    expect(find.text('Przerwano.'), findsOneWidget);
    expect(find.byKey(const Key('composer-stop')), findsNothing);
    expect(container.read(chatControllerProvider).generating, isFalse);
  });

  testWidgets('sending during generation interrupts the running answer', (tester) async {
    final streams = <StreamController<AnswerEvent>>[];
    final service = FakeAnswerService(
      script: (q, c) {
        final s = StreamController<AnswerEvent>();
        streams.add(s);
        return s.stream;
      },
    );
    await pumpChat(tester, service);
    await tester.enterText(find.byKey(const Key('composer-field')), 'Pierwsze');
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('composer-field')), 'Drugie');
   await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();

    expect(service.questions, ['Pierwsze', 'Drugie']);
    expect(find.text('Przerwano.'), findsOneWidget);
    expect(find.text('Szukam w źródłach…'), findsOneWidget);
  });

  testWidgets('refusal answer renders NoSource text', (tester) async {
    await pumpChat(tester, const EchoQuoteAnswerService());
    await tester.tap(find.text('Ewakuacja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Nie wiem. Moje źródła tego nie opisują.'), findsOneWidget);
    expect(find.textContaining('112'), findsNothing);
  });
}
