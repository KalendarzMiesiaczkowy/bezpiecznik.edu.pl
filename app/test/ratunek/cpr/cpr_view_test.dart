import 'dart:io';

import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/ui/chat_controller.dart';
import 'package:bezpiecznik/ratunek/cards/rescue_card.dart' show RescueCardRepository, rescueCardIds;
import 'package:bezpiecznik/ratunek/detect/risk_detector.dart';
import 'package:bezpiecznik/ratunek/ui/rescue_answer.dart';
import 'package:flutter/services.dart' show ByteData, CachingAssetBundle;
import 'package:bezpiecznik/ustawienia/settings_store.dart' show voiceEnabledProvider;
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_session.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_view.dart';
import 'package:bezpiecznik/wspolne/shell/cpr_state.dart';
import 'package:bezpiecznik/wspolne/theme/bz_buttons.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'cpr_fakes.dart';

AssistantAnswer cprAnswer({bool withAed = true}) => AssistantAnswer(
  panels: [
    ChatPanel.fromJson({
      ...rkoCprPanelJson(),
      if (!withAed) 'aed_card_id': null,
    }),
  ],
  origin: AnswerOrigin.rescueCard,
);

/// Reads assets straight from `assets/` on the host.
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(await File(key).readAsBytes());
}

/// Rescue service with the shipped cards (including `aed`).
Future<RescueAnswerService> loadService() async {
  final bundle = _FileBundle();
  return RescueAnswerService(
    detector: await RiskDetector.load(bundle),
    cards: await RescueCardRepository.load(bundle, ids: rescueCardIds),
  );
}

Future<(Rig, ProviderContainer)> pumpCard(
  WidgetTester tester, {
  bool inline = true,
  bool withAed = true,
  Widget? extra,
}) async {
  final service = await tester.runAsync(loadService);
  final rig = Rig();
  final registry = TemplateRegistry.withDefaults();
  registerCprTemplate(registry, inlinePinned: inline);
  final container = ProviderContainer(
    overrides: [
      templateRegistryProvider.overrideWithValue(registry),
      cprSessionProvider.overrideWithValue(rig.session),
      chatStoreProvider.overrideWithValue(ChatStore.inMemory()),
      rescueAnswerServiceProvider.overrideWith((ref) async => service!),
    ],
  );
  addTearDown(container.dispose);
  var answer = cprAnswer(withAed: withAed);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: Column(
                children: [
                  TemplateRenderer(answer: answer, onChanged: (a) => setState(() => answer = a)),
                  ?extra,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return (rig, container);
}

void main() {
  testWidgets('card: variant switch, summary, start shows the pinned panel', (tester) async {
    final (rig, _) = await pumpCard(tester);
    expect(find.text('Dorosły'), findsOneWidget);
    expect(find.text('Niemowlę'), findsOneWidget);
    expect(find.text('Dorosły · 110/min · 30:2'), findsOneWidget);
    await tester.tap(find.text('Niemowlę'));
    await tester.pump();
    expect(find.text('Niemowlę · 110/min · 30:2'), findsOneWidget);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    expect(rig.session.running, isTrue);
    expect(rig.session.variant!.id, 'infant');
    expect(find.byKey(const ValueKey('cpr-pinned')), findsOneWidget);
    // Infant starts with the initial breaths and waits for the tap.
    expect(find.text(cprInitialBreathsLabel(5)), findsOneWidget);
    expect(find.text(cprBreathsDoneLabel), findsOneWidget);
    rig.session.stop();
  });

  testWidgets('pinned adult: phase, counter, stopwatch, change countdown', (tester) async {
    final (rig, _) = await pumpCard(tester);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    expect(find.text(cprCompressLabel), findsOneWidget);
    expect(find.text('1 / 30'), findsOneWidget);
    expect(find.text('Czas 00:00'), findsOneWidget);
    expect(find.text('Zmiana za 2:00'), findsOneWidget);
    expect(find.text('RKO · Dorosły'), findsOneWidget);
    expect(find.text('112'), findsOneWidget);

    rig.advance(const Duration(seconds: 17));
    await tester.pump();
    expect(find.text('Czas 00:17'), findsOneWidget);
    expect(find.text('Zmiana za 1:43'), findsOneWidget);
    // 17 s = 1 cycle (16.4 s) + breath phase -> breaths label from the card.
    expect(find.text('Dwa oddechy · 0:10'), findsOneWidget);
    expect(find.text(cprBreathsDoneLabel), findsOneWidget);
    rig.session.stop();
  });

  testWidgets('pause, resume and stop buttons', (tester) async {
    final (rig, _) = await pumpCard(tester);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    await tester.tap(find.text(cprPauseLabel));
    await tester.pump();
    expect(find.text(cprPausedLabel), findsOneWidget);
    expect(find.text(cprResumeLabel), findsOneWidget);
    await tester.tap(find.text(cprResumeLabel));
    await tester.pump();
    expect(find.text(cprCompressLabel), findsOneWidget);
    await tester.tap(find.text(cprStopLabel));
    await tester.pump();
    expect(rig.session.running, isFalse);
    expect(find.text(cprStartLabel), findsOneWidget);
    expect(rig.wakelock.on, isFalse);
  });

  testWidgets('change banner appears for 10 s after the prompt', (tester) async {
    final (rig, _) = await pumpCard(tester);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    for (var i = 0; i < 1210; i++) {
      rig.advance(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(find.byKey(const ValueKey('cpr-change-banner')), findsOneWidget);
    for (var i = 0; i < 100; i++) {
      rig.advance(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(find.byKey(const ValueKey('cpr-change-banner')), findsNothing);
    rig.session.stop();
  });

  testWidgets('host mode: card shows a note, CprPinnedHost shows the controls', (tester) async {
    final (rig, _) = await pumpCard(tester, inline: false, extra: const CprPinnedHost());
    expect(find.byKey(const ValueKey('cpr-pinned')), findsNothing);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    expect(find.byKey(const ValueKey('cpr-pinned')), findsOneWidget);
    expect(find.textContaining('Panel jest przypięty'), findsOneWidget);
    rig.session.stop();
    await tester.pump();
    expect(find.byKey(const ValueKey('cpr-pinned')), findsNothing);
  });

  testWidgets('card copy: title "Instruktor RKO", variant-prefixed tempo line, "Zacznij uciskanie"', (tester) async {
    await pumpCard(tester);
    expect(find.text('Instruktor RKO'), findsOneWidget);
    expect(find.text('Zacznij uciskanie'), findsOneWidget);
    expect(find.text('Dorosły · 110/min · 30:2'), findsOneWidget);
    // Child ratio shown must match the card data (compressions:breaths).
    final child = rkoConfig().variant('child')!;
    await tester.tap(find.text('Dziecko'));
    await tester.pump();
    expect(find.text('Dziecko · 110/min · ${child.compressions}:${child.breaths}'), findsOneWidget);
    expect(child.compressions, 30);
    expect(child.breaths, 2);
  });

  testWidgets('breath phase reads "Dwa oddechy · 0:08" and "Dalej" returns to compressions', (tester) async {
    final (rig, _) = await pumpCard(tester);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    rig.advance(rkoConfig().beatInterval * 30 + const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Dwa oddechy · 0:08'), findsOneWidget);
    expect(find.text('Dalej'), findsOneWidget);
    await tester.tap(find.text('Dalej'));
    await tester.pump();
    expect(find.text(cprCompressLabel), findsOneWidget);
    expect(find.text('Dalej'), findsNothing);
    rig.session.stop();
  });

  testWidgets('child initial breaths: neutral label with the card count, untimed, "Dalej"', (tester) async {
    final (rig, _) = await pumpCard(tester);
    await tester.tap(find.text('Dziecko'));
    await tester.pump();
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    expect(find.text('Oddechy ratownicze · 5'), findsOneWidget);
    expect(find.text('Dalej'), findsOneWidget);
    rig.advance(const Duration(seconds: 60));
    await tester.pump();
    expect(find.text('Oddechy ratownicze · 5'), findsOneWidget);
    rig.session.stop();
  });

  testWidgets('AED row: shown at start, check hides it, it returns at the rescuer change', (tester) async {
    final (rig, _) = await pumpCard(tester);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    expect(find.text('Poproś kogoś o AED'), findsOneWidget);
    expect(find.text('Jak użyć AED'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('cpr-aed-row')), matching: find.byType(BzButton)));
    await tester.pump();
    expect(find.text('Poproś kogoś o AED'), findsNothing);
    for (var i = 0; i < 1210; i++) {
      rig.advance(const Duration(milliseconds: 100));
    }
    await tester.pump();
    expect(find.text('Poproś kogoś o AED'), findsOneWidget);
    rig.session.stop();
  });

  testWidgets('pinned controls have touch targets of at least 48 dp', (tester) async {
    final (rig, _) = await pumpCard(tester);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    for (final label in ['112', cprPauseLabel, cprStopLabel]) {
      final button = find.ancestor(of: find.text(label), matching: find.byType(BzButton));
      final size = tester.getSize(button);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
    }
    rig.session.stop();
  });

  testWidgets('one timer per session: the overlay notifier does not tick on its own', (tester) async {
    final clock = FakeClock();
    final container = ProviderContainer(
      overrides: [
        cprVoiceProvider.overrideWithValue(FakeVoice()),
        cprSoundProvider.overrideWithValue(FakeSound()),
        cprHapticsProvider.overrideWithValue(FakeHaptics()),
        cprWakelockProvider.overrideWithValue(FakeWakelock()),
        cprClockProvider.overrideWithValue(clock.call),
        voiceEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(cprSessionProvider);
    session.start(rkoConfig(), 'adult');
    // Five seconds of fake time pass but the session clock does not move:
    // elapsed must stay zero (a second ticker would add 5 s).
    await tester.pump(const Duration(seconds: 5));
    expect(container.read(cprProvider).elapsed, Duration.zero);
    clock.advance(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 20));
    expect(container.read(cprProvider).elapsed, const Duration(seconds: 3));
    session.stop();
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(cprProvider).running, isFalse);
  });

  test('notifier: selfTick false starts no timer, default keeps the one-second ticker', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(cprProvider.notifier);
    n.start(selfTick: false);
    expect(c.read(cprProvider).running, isTrue);
    n.stop();
    n.start();
    n.start();
    n.stop();
    expect(c.read(cprProvider).running, isFalse);
  });

  testWidgets('provider-built session drives the overlay state and survives widget disposal', (tester) async {
    final clock = FakeClock();
    final wake = FakeWakelock();
    final container = ProviderContainer(
      overrides: [
        cprVoiceProvider.overrideWithValue(FakeVoice()),
        cprSoundProvider.overrideWithValue(FakeSound()),
        cprHapticsProvider.overrideWithValue(FakeHaptics()),
        cprWakelockProvider.overrideWithValue(wake),
        cprClockProvider.overrideWithValue(clock.call),
        voiceEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(cprSessionProvider);
    session.start(rkoConfig(), 'adult');
    expect(container.read(cprActiveProvider), isTrue);
    // "Leaving the screen": nothing watches the session, it keeps running.
    await tester.pump(const Duration(seconds: 3));
    clock.advance(const Duration(seconds: 3));
    session.tick();
    expect(container.read(cprProvider).running, isTrue);
    expect(container.read(cprProvider).elapsed, const Duration(seconds: 3));
    expect(wake.on, isTrue);
    session.stop();
    expect(container.read(cprActiveProvider), isFalse);
    expect(wake.on, isFalse);
  });

  testWidgets('"Jak użyć AED" is hidden without aed_card_id', (tester) async {
    final (rig, _) = await pumpCard(tester, withAed: false);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    expect(find.text('Poproś kogoś o AED'), findsOneWidget);
    expect(find.text(cprAedHowLabel), findsNothing);
    rig.session.stop();
  });

  testWidgets('"Jak użyć AED": target >= 48 dp, stays after the reminder tick', (tester) async {
    final (rig, _) = await pumpCard(tester);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    final size = tester.getSize(find.byKey(const ValueKey('cpr-aed-how')));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('cpr-aed-row')), matching: find.byType(BzButton)));
    await tester.pump();
    expect(find.text('Poproś kogoś o AED'), findsNothing);
    expect(find.text(cprAedHowLabel), findsOneWidget);
    rig.session.stop();
  });

  testWidgets('tap inserts the AED card (session variant), session keeps running', (tester) async {
    final (rig, container) = await pumpCard(tester);
    await tester.tap(find.text('Niemowlę'));
    await tester.pump();
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    expect(rig.session.variant!.id, 'infant');
    expect(container.read(chatControllerProvider).messages, isEmpty);

    await tester.tap(find.text(cprAedHowLabel));
    await tester.pump();
    await tester.pump();

    final messages = container.read(chatControllerProvider).messages;
    expect(messages, hasLength(1));
    final m = messages.single;
    expect(m.role, ChatRole.assistant);
    expect(m.status, MessageStatus.done);
    final a = m.answer!;
    expect(a.cardId, 'aed');
    expect(a.origin, AnswerOrigin.rescueCard);
    expect(a.verify, isTrue);
    expect(a.selectedVariant, 'infant');
    expect(a.panels.whereType<CallPanel>(), isEmpty);
    expect(a.panels.whereType<CprPanel>(), isEmpty);
    final steps = a.panels.whereType<StepsPanel>().single;
    expect(steps.itemsFor('infant'), isNotEmpty);
    expect(a.sources, isNotEmpty);

    expect(rig.session.running, isTrue);
    expect(find.byKey(const ValueKey('cpr-pinned')), findsOneWidget);
    rig.session.stop();
  });
}
