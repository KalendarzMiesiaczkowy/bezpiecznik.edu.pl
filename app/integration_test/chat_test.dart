import 'dart:async';

import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bezpiecznik/profil/profile_store.dart';

import 'support/harness.dart';
import 'package:material_ui/material_ui.dart' show Key;

/// Chat E2E with `FakeAnswerService` (the host-LLM E2E comes with A06).
/// Run: `flutter test integration_test/chat_test.dart -d emulator-5554`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('send a question and see panels with a source chip', (tester) async {
    final store = ChatStore.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          answerServiceProvider.overrideWithValue(FakeAnswerService(delay: const Duration(milliseconds: 300))),
          chatStoreProvider.overrideWithValue(store),
          profileStoreProvider.overrideWithValue(await onboardedProfileStore()),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.text('Co się dzieje?'));
    expect(find.text('Co się dzieje?'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('composer-field')), 'Jak przechować insulinę bez prądu?');
    await tester.pump(); // send button appears after the rebuild
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    expect(find.text('Szukam w źródłach…'), findsOneWidget);
    expect(find.byKey(const Key('composer-stop')), findsOneWidget);

    await pumpUntil(tester, find.text('Przykładowy krok pierwszy'));
    expect(find.text('Przykładowy krok pierwszy'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Przykład, s.\u00A014'), findsWidgets);
    expect((await store.listChats()).single.title, 'Jak przechować insulinę bez prądu?');
  });

  testWidgets('stop interrupts generation', (tester) async {
    final never = StreamController<AnswerEvent>();
    addTearDown(never.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          answerServiceProvider.overrideWithValue(FakeAnswerService(script: (q, c) => never.stream)),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
          profileStoreProvider.overrideWithValue(await onboardedProfileStore()),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('composer-field')));
    await tester.enterText(find.byKey(const Key('composer-field')), 'Pytanie');
    await tester.pump(); // send button appears after the rebuild
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-stop')));
    await tester.pump();
    expect(find.text('Przerwano.'), findsOneWidget);
    expect(find.byKey(const Key('composer-stop')), findsNothing);
  });
}
