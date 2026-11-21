import 'dart:async';

import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/read_aloud.dart';
import 'package:bezpiecznik/czat/templates/steps_panel.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeVoice implements ReadAloudVoice {
  _FakeVoice({this.available = true, this.throwing = false});

  final bool available;
  final bool throwing;
  final spoken = <String>[];
  var stops = 0;
  Completer<void>? _pending;

  @override
  Future<bool> isAvailable() async {
    if (throwing) throw StateError('no tts');
    return available;
  }

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    _pending = Completer<void>();
    return _pending!.future;
  }

  void finish() => _pending?.complete();

  @override
  Future<void> stop() async {
    stops++;
    _pending?.complete();
  }
}

Future<void> _pump(
  WidgetTester tester,
  ReadAloudVoice voice, {
  bool readAloud = true,
  Set<int> done = const {},
}) async {
  final answer = AssistantAnswer(
    sources: const {},
    panels: [
      StepsPanel(
        title: 'T',
        readAloud: readAloud,
        items: const [
          PanelItem(text: 'raz'),
          PanelItem(text: 'dwa'),
          PanelItem(text: 'trzy'),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [readAloudVoiceProvider.overrideWithValue(voice)],
      child: MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StepsPanelView(
              scope: PanelScope(
                panel: answer.panels.first,
                index: 0,
                answer: answer,
                variant: null,
                showVariantSwitch: false,
                onVariantChanged: (_) {},
                done: done,
                onDoneChanged: (_, _) {},
                onOpenSource: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('no button without read_aloud', (tester) async {
    await _pump(tester, _FakeVoice(), readAloud: false);
    expect(find.text(readAloudStartLabel), findsNothing);
  });

  testWidgets('hidden when no voice or TTS throws', (tester) async {
    await _pump(tester, _FakeVoice(available: false));
    expect(find.text(readAloudStartLabel), findsNothing);
    await _pump(tester, _FakeVoice(throwing: true));
    expect(find.text(readAloudStartLabel), findsNothing);
  });

  testWidgets('reads steps in order, tap again stops', (tester) async {
    final v = _FakeVoice();
    await _pump(tester, v);
    expect(
      tester.getSize(find.text(readAloudStartLabel).hitTestable()).height,
      greaterThan(0),
    );
    await tester.tap(find.text(readAloudStartLabel));
    await tester.pump();
    expect(v.spoken, ['raz']);
    expect(find.text(readAloudStopLabel), findsOneWidget);
    v.finish();
    await tester.pump();
    expect(v.spoken, ['raz', 'dwa']);
    await tester.tap(find.text(readAloudStopLabel));
    await tester.pump();
    expect(find.text(readAloudStartLabel), findsOneWidget);
    expect(v.spoken, ['raz', 'dwa']);
  });

  testWidgets('starts at the first unchecked step', (tester) async {
    final v = _FakeVoice();
    await _pump(tester, v, done: {0});
    await tester.tap(find.text(readAloudStartLabel));
    await tester.pump();
    expect(v.spoken, ['dwa']);
  });

  testWidgets('button resets after the last step', (tester) async {
    final v = _FakeVoice();
    await _pump(tester, v, done: {0, 1});
    await tester.tap(find.text(readAloudStartLabel));
    await tester.pump();
    expect(v.spoken, ['trzy']);
    v.finish();
    await tester.pump();
    await tester.pump();
    expect(find.text(readAloudStartLabel), findsOneWidget);
  });
}
