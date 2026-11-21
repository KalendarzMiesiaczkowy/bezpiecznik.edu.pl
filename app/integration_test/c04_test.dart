import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/main.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' show Key;

import 'support/harness.dart';

/// C04 E2E: two chats, switching through the side drawer.
/// Needs the drawer wired into RootOverlay (see C04 report).
/// Run: `flutter test integration_test/c04_test.dart -d emulator-5554`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create two chats and switch between them', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          answerServiceProvider.overrideWithValue(FakeAnswerService(delay: const Duration(milliseconds: 100))),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
          profileStoreProvider.overrideWithValue(await onboardedProfileStore()),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('composer-field')));

    Future<void> ask(String q) async {
      await tester.enterText(find.byKey(const Key('composer-field')), q);
      await tester.tap(find.byKey(const Key('composer-send')));
      await pumpUntil(tester, find.text('Przykładowy krok pierwszy'));
    }

    await ask('Pierwsze pytanie');
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Nowy czat'));
    await tester.pumpAndSettle();
    expect(find.text('Co się dzieje?'), findsOneWidget);

    await ask('Drugie pytanie');
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Pierwsze pytanie'), findsOneWidget);
    expect(find.text('Drugie pytanie'), findsWidgets);

    await tester.tap(find.text('Pierwsze pytanie'));
    await tester.pumpAndSettle();
    expect(find.text('Pierwsze pytanie'), findsOneWidget);
    expect(find.text('Drugie pytanie'), findsNothing);
  });
}
