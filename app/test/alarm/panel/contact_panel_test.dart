import 'package:bezpiecznik/alarm/panel/call_gps.dart';
import 'package:bezpiecznik/alarm/panel/call_panel.dart';
import 'package:bezpiecznik/alarm/panel/contact_panel.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/wspolne/shell/shell_panels.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('ContactPanel: Zamknij closes P2, nothing launched without a tap', (tester) async {
    final launched = <Uri>[];
    final container = ProviderContainer(
      overrides: [
        callLauncherProvider.overrideWithValue((u) async {
          launched.add(u);
          return true;
        }),
        canSendSmsProvider.overrideWith((_) async => true),
        callGpsProvider.overrideWith((_) => Stream.value(const CallGps(access: LocationAccess.denied))),
      ],
    );
    addTearDown(container.dispose);
    container.read(shellPanelsProvider.notifier).openContactPanel();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildBzTheme(), home: const Scaffold(body: ContactPanel())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Kontakt ze służbami'), findsOneWidget);
    expect(find.text('ZADZWOŃ 112'), findsOneWidget);
    expect(launched, isEmpty);

    await tester.tap(find.bySemanticsLabel('Zamknij'));
    await tester.pump();
    expect(container.read(shellPanelsProvider).contactOpen, isFalse);
    expect(launched, isEmpty);
  });
}
