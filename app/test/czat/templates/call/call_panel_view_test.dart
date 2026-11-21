import 'package:bezpiecznik/czat/templates/call/call_panel_view.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/wspolne/shell/shell_panels.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<ProviderContainer> pump(
  WidgetTester tester,
  List<Uri> launched, {
  bool ok = true,
  bool throws = false,
  VoidCallback? onNotify,
}) async {
  final container = ProviderContainer(
    overrides: [
      callLauncherProvider.overrideWithValue((uri) async {
        launched.add(uri);
        if (throws) throw StateError('no handler');
        return ok;
      }),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: CallPanelView(onNotify: onNotify)),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('two 80 px buttons, "Więcej" collapsed', (tester) async {
    await pump(tester, []);
    expect(find.text(call112Label), findsOneWidget);
    expect(find.text(callNotifyLabel), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('call-112'))).height, 80);
    expect(
      tester.getSize(find.byKey(const ValueKey('call-notify'))).height,
      80,
    );
    expect(find.text(callMoreLabel), findsOneWidget);
    expect(find.text('999'), findsNothing);
    expect(find.text(callAmlNote), findsNothing);
  });

  testWidgets('nothing is dialled before a tap; tap dials tel:112', (
    tester,
  ) async {
    final launched = <Uri>[];
    await pump(tester, launched);
    expect(launched, isEmpty);
    await tester.tap(find.byKey(const ValueKey('call-112')));
    await tester.pump();
    expect(launched.single.toString(), 'tel:112');
    expect(find.byKey(const ValueKey('call-fallback')), findsNothing);
  });

  testWidgets('"Więcej" expands to 999 / 998 / 997 and dials them', (
    tester,
  ) async {
    final launched = <Uri>[];
    await pump(tester, launched);
    await tester.tap(find.byKey(const ValueKey('call-more')));
    await tester.pump();
    for (final n in ['999', '998', '997']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('Pogotowie'), findsOneWidget);
    expect(find.text(callAmlNote), findsOneWidget);
    expect(find.text(callWhatToSayTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('call-998')));
    await tester.pump();
    expect(launched.single.toString(), 'tel:998');
    await tester.tap(find.byKey(const ValueKey('call-more')));
    await tester.pump();
    expect(find.text('999'), findsNothing);
  });

  for (final mode in ['returns false', 'throws']) {
    testWidgets('failed launch ($mode) shows the 112 fallback', (tester) async {
      await pump(tester, [], ok: false, throws: mode == 'throws');
      await tester.tap(find.byKey(const ValueKey('call-112')));
      await tester.pump();
      expect(
        find.text('Nie mogę otworzyć telefonu. Wybierz 112 ręcznie.'),
        findsOneWidget,
      );
    });
  }

  testWidgets('"Powiadom bliskich" opens Panel 2 by default', (tester) async {
    final container = await pump(tester, []);
    expect(container.read(shellPanelsProvider).contactOpen, isFalse);
    await tester.tap(find.byKey(const ValueKey('call-notify')));
    await tester.pump();
    expect(container.read(shellPanelsProvider).contactOpen, isTrue);
  });

  testWidgets('onNotify override is used', (tester) async {
    var n = 0;
    await pump(tester, [], onNotify: () => n++);
    await tester.tap(find.byKey(const ValueKey('call-notify')));
    expect(n, 1);
  });

  testWidgets('registerCallTemplate replaces the placeholder', (tester) async {
    final r = TemplateRegistry.withDefaults();
    registerCallTemplate(r);
    expect(r.builderFor('call'), isNotNull);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildBzTheme(),
          home: Material(
            child: SingleChildScrollView(
              child: Builder(
                builder: (c) => r.builderFor('call')!(
                  c,
                  PanelScope(
                    panel: const CallPanel(),
                    index: 0,
                    answer: const AssistantAnswer(),
                    variant: null,
                    showVariantSwitch: false,
                    onVariantChanged: (_) {},
                    done: const {},
                    onDoneChanged: (_, _) {},
                    onOpenSource: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text(call112Label), findsOneWidget);
    expect(find.byKey(const ValueKey('placeholder-call')), findsNothing);
  });
}
