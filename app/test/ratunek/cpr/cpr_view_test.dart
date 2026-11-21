import 'package:bezpiecznik/ustawienia/settings_store.dart' show voiceEnabledProvider;
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_session.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_view.dart';
import 'package:bezpiecznik/wspolne/shell/cpr_state.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'cpr_fakes.dart';

AssistantAnswer cprAnswer() => AssistantAnswer(
  panels: [ChatPanel.fromJson(rkoCprPanelJson())],
  origin: AnswerOrigin.rescueCard,
);

Future<(Rig, ProviderContainer)> pumpCard(WidgetTester tester, {bool inline = true, Widget? extra}) async {
  final rig = Rig();
  final registry = TemplateRegistry.withDefaults();
  registerCprTemplate(registry, inlinePinned: inline);
  final container = ProviderContainer(
    overrides: [
      templateRegistryProvider.overrideWithValue(registry),
      cprSessionProvider.overrideWithValue(rig.session),
    ],
  );
  addTearDown(container.dispose);
  var answer = cprAnswer();
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
    expect(find.text('Tempo 110 na minutę · 30:2'), findsOneWidget);
    await tester.tap(find.text('Niemowlę'));
    await tester.pump();
    expect(find.text('Tempo 110 na minutę · 30:2'), findsOneWidget);
    await tester.tap(find.text(cprStartLabel));
    await tester.pump();
    expect(rig.session.running, isTrue);
    expect(rig.session.variant!.id, 'infant');
    expect(find.byKey(const ValueKey('cpr-pinned')), findsOneWidget);
    // Infant starts with the initial breaths and waits for the tap.
    expect(find.text(cprBreathsLabel), findsOneWidget);
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
    expect(find.text('DWA ODDECHY'), findsOneWidget);
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
}
