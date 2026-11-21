import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bezpiecznik/alarm/signal/signal_panel.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';

Widget _app(SignalDevices d) => MaterialApp(
      theme: buildBzTheme(),
      home: Scaffold(body: SingleChildScrollView(child: SignalPanelView(devices: d))),
    );

void main() {
  setUpAll(() {
    // wakelock_plus has no host in unit tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle'), (_) async => null);
  });

  testWidgets('no torch: Polish message, torch switch disabled, no strobe', (tester) async {
    await tester.pumpWidget(_app(SignalDevices(torchAvailable: () async => false)));
    await tester.pumpAndSettle();
    expect(find.text('Latarka niedostępna.'), findsOneWidget);
    expect(tester.widget<Switch>(find.byKey(const ValueKey('signal-torch'))).onChanged, isNull);
    expect(find.textContaining('Stroboskop'), findsNothing);
  });

  testWidgets('sound switch toggles the sound back-end', (tester) async {
    final calls = <bool>[];
    await tester.pumpWidget(_app(SignalDevices(
      torchAvailable: () async => false,
      setSound: (on) async => calls.add(on),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('signal-sound')));
    await tester.pump();
    expect(calls, [true]);
    expect(find.byKey(const ValueKey('signal-clock')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('signal-sound')));
    await tester.pump();
    expect(calls, [true, false]);
  });
}
