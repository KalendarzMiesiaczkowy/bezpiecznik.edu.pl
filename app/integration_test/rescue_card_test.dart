import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/templates/call/call_panel_view.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/main.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/ratunek/ui/rescue_answer.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart' show Key;

/// Rescue card E2E: a risk phrase gets a card with `call` and the
/// "Do weryfikacji" badge without the model, in under 1 s.
/// Run: `flutter test integration_test/rescue_card_test.dart -d emulator-5554`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('"dziecko nie oddycha" -> child CPR card in under 1 s', (
    tester,
  ) async {
    final profiles = ProfileStore.inMemory();
    await profiles.setOnboardingDone(true);
    final model = FakeAnswerService(script: (q, c) => const Stream.empty());
    final registry = TemplateRegistry.withDefaults();
    registerCallTemplate(registry);

    // Expected content straight from the shipped card.
    final rescue = await RescueAnswerService.load(rootBundle);
    final expected = (await rescue.tryAnswer('dziecko nie oddycha'))!;
    final firstChildStep = expected.panels
        .whereType<StepsPanel>()
        .first
        .itemsFor('child')
        .first
        .text;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStoreProvider.overrideWithValue(profiles),
          chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
          templateRegistryProvider.overrideWithValue(registry),
          answerServiceProvider.overrideWith(
            (ref) => RescueFirstAnswerService(
              rescue: () => ref.read(rescueAnswerServiceProvider.future),
              fallback: model,
            ),
          ),
        ],
        child: const BezpiecznikApp(),
      ),
    );
    // No pumpAndSettle: spinners may run. Wait for the empty chat.
    await _pumpUntil(
      tester,
      () => find.text('Co się dzieje?').evaluate().isNotEmpty,
    );

    await tester.enterText(
      find.byKey(const Key('composer-field')),
      'dziecko nie oddycha',
    );
    await tester.pump();
    final sw = Stopwatch()..start();
    await tester.tap(find.byKey(const Key('composer-send')));
    await _pumpUntil(
      tester,
      () => find.text(call112Label).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 1),
    );
    sw.stop();

    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(find.text(call112Label), findsOneWidget);
    expect(find.text('Do weryfikacji'), findsOneWidget);
    expect(find.text('Karta ratunkowa'), findsOneWidget);
    expect(find.text('RKO'), findsWidgets);
    expect(find.text(firstChildStep, skipOffstage: false), findsOneWidget);
    expect(model.questions, isEmpty, reason: 'the model must not be asked');
    // ignore: avoid_print
    print('rescue card shown after ${sw.elapsedMilliseconds} ms');
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(end)) break;
    await tester.pump(const Duration(milliseconds: 50));
  }
}
