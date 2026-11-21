import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/main.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' show Key, ValueKey;

import 'support/harness.dart';

/// Production answer path on the device (no answer-service override):
/// sourced pipeline through the host LLM (`--dart-define=LLM=host`, adb
/// reverse 8080) and the shelter intent → map card without the model.
/// Run: `flutter test integration_test/answer_test.dart -d emulator-5554 --dart-define=LLM=host`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(WidgetTester tester) async {
    final profile = await onboardedProfileStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStoreProvider.overrideWithValue(profile),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('composer-field')));
  }

  Future<void> ask(WidgetTester tester, String q) async {
    await tester.enterText(find.byKey(const Key('composer-field')), q);
    await tester.pump(); // send button appears after the rebuild
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
  }

  testWidgets('question -> sourced answer from the host model', (tester) async {
    await pumpApp(tester);
    final sw = Stopwatch()..start();
    await ask(tester, 'Co spakować do plecaka ewakuacyjnego?');
    final chip = find.textContaining('▸ ');
    final ok = await pumpUntil(tester, chip, timeout: const Duration(seconds: 40));
    // ignore: avoid_print
    print('sourced answer shown after ${sw.elapsedMilliseconds} ms (host LLM)');
    expect(ok, isTrue, reason: 'no source chip within 40 s');
    expect(find.byKey(const Key('composer-stop')), findsNothing);
  });

  testWidgets('off-topic question -> calm refusal, no 112', (tester) async {
    await pumpApp(tester);
    await ask(tester, 'przepis na pierogi');
    final ok = await pumpUntil(tester, find.textContaining('Pomagam tylko w sytuacjach kryzysowych'), timeout: const Duration(seconds: 15));
    expect(ok, isTrue);
  });

  testWidgets('"gdzie jest najbliższy schron" -> map card without the model', (tester) async {
    await pumpApp(tester);
    final sw = Stopwatch()..start();
    await ask(tester, 'gdzie jest najbliższy schron');
    final ok = await pumpUntil(tester, find.text('Najbliższy schron'), timeout: const Duration(seconds: 10));
    // ignore: avoid_print
    print('map card shown after ${sw.elapsedMilliseconds} ms');
    expect(ok, isTrue);
    await tester.pump(const Duration(seconds: 2));
    // BG74: the map pushed from the card shows Back, not the island.
    await tester.ensureVisible(find.byKey(const ValueKey('map-card-open')));
    await tester.tap(find.byKey(const ValueKey('map-card-open')));
    final onMap = await pumpUntil(tester, find.bySemanticsLabel('Wróć'), timeout: const Duration(seconds: 10));
    expect(onMap, isTrue);
    expect(find.bySemanticsLabel('Menu'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });
}
