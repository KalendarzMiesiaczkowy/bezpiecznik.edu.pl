import 'package:bezpiecznik/alarm/signal/signal_panel.dart' show SignalDevices;
import 'package:bezpiecznik/alarm/signal/signal_screen.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _Devices {
  final sound = <bool>[];
  final torch = <bool>[];
  bool torchOk = true;

  SignalDevices get devices => SignalDevices(
    torchAvailable: () async => torchOk,
    setTorch: (on) async => torch.add(on),
    setSound: (on) async => sound.add(on),
  );
}

void main() {
  setUpAll(() {
    // wakelock_plus has no host in unit tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle'),
      (_) async => null,
    );
  });

  Future<_Devices> pump(WidgetTester tester, {bool torchOk = true, double textScale = 1}) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = _Devices()..torchOk = torchOk;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBzTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: SignalScreen(devices: d.devices),
      ),
    );
    await tester.pump();
    return d;
  }

  /// Leaves the screen so runners and timers stop before the test ends.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('three modes are visible at once, nothing runs until asked', (tester) async {
    final d = await pump(tester);
    expect(find.text(signalSoundLabel), findsOneWidget);
    expect(find.text(signalTorchLabel), findsOneWidget);
    expect(find.text(signalScreenLabel), findsOneWidget);
    expect(d.sound, isEmpty);
    expect(d.torch, isEmpty);
    expect(find.byKey(const Key('signal-stop-all')), findsNothing);
    await leave(tester);
  });

  testWidgets('the sound tile starts and stops the sound', (tester) async {
    final d = await pump(tester);
    await tester.tap(find.byKey(const Key('signal-tile-sound')));
    await tester.pump();
    expect(d.sound, [true]);
    expect(find.byKey(const Key('signal-screen-clock')), findsOneWidget);
    await tester.tap(find.byKey(const Key('signal-tile-sound')));
    await tester.pump();
    expect(d.sound, [true, false]);
    await leave(tester);
  });

  testWidgets('the flashlight blinks and goes dark when switched off', (tester) async {
    final d = await pump(tester);
    await tester.tap(find.byKey(const Key('signal-tile-torch')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(d.torch.first, isTrue);
    await tester.tap(find.byKey(const Key('signal-tile-torch')));
    await tester.pump(const Duration(seconds: 2));
    expect(d.torch.last, isFalse);
    await leave(tester);
  });

  testWidgets('without a flashlight the tile says so and does nothing', (tester) async {
    final d = await pump(tester, torchOk: false);
    expect(find.text(signalTorchMissing), findsOneWidget);
    await tester.tap(find.byKey(const Key('signal-tile-torch')));
    await tester.pump();
    expect(d.torch, isEmpty);
    await leave(tester);
  });

  testWidgets('the screen strobe asks first (photosensitive epilepsy)', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('signal-tile-screen')));
    await tester.pumpAndSettle();
    expect(find.text(strobeWarningTitle), findsOneWidget);
    expect(find.byKey(const Key('signal-strobe')), findsNothing);

    await tester.tap(find.byKey(const Key('strobe-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('signal-strobe')), findsNothing);
    await leave(tester);
  });

  testWidgets('after confirming, the screen flashes white and red with one way out', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('signal-tile-screen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('strobe-confirm')));
    await tester.pump(const Duration(milliseconds: 300));

    final colors = <Color>{};
    for (var i = 0; i < 12; i++) {
      colors.add(tester.widget<ColoredBox>(find.byKey(const Key('signal-strobe'))).color);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(colors, hasLength(2));
    expect(colors, contains(const Color(0xFFFFFFFF)));

    // The way out is a button at the bottom, not a screen-sized slab.
    final stop = tester.getRect(find.byKey(const Key('signal-stop-screen')));
    expect(stop.height, inInclusiveRange(56, 120));
    expect(stop.bottom, greaterThan(720 - 40));

    await tester.tap(find.byKey(const Key('signal-stop-screen')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('signal-strobe')), findsNothing);
    await leave(tester);
  });

  testWidgets('"Zatrzymaj wszystko" stops every running mode', (tester) async {
    final d = await pump(tester);
    await tester.tap(find.byKey(const Key('signal-tile-sound')));
    await tester.tap(find.byKey(const Key('signal-tile-torch')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.byKey(const Key('signal-stop-all')));
    await tester.tap(find.byKey(const Key('signal-stop-all')));
    await tester.pump(const Duration(seconds: 2));
    expect(d.sound.last, isFalse);
    expect(d.torch.last, isFalse);
    expect(find.byKey(const Key('signal-stop-all')), findsNothing);
    await leave(tester);
  });

  testWidgets('leaving the screen stops the sound and the flashlight', (tester) async {
    final d = await pump(tester);
    await tester.tap(find.byKey(const Key('signal-tile-sound')));
    await tester.tap(find.byKey(const Key('signal-tile-torch')));
    await tester.pump(const Duration(milliseconds: 250));
    await leave(tester);
    expect(d.sound.last, isFalse);
    expect(d.torch.last, isFalse);
  });

  testWidgets('no overflow at 2x text', (tester) async {
    await pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    await leave(tester);
  });
}
