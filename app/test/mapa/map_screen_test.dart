import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:bezpiecznik/mapa/map_assets.dart';
import 'package:bezpiecznik/mapa/map_screen.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == mapStyleAsset) {
      return ByteData.sublistView(Uint8List.fromList('{"version":8}'.codeUnits));
    }
    return ByteData.sublistView(Uint8List.fromList([1, 2, 3]));
  }
}

class _FakeGateway implements LocationGateway {
  _FakeGateway(this.access, [this.stream]);

  final LocationAccess access;
  final Stream<Position>? stream;
  int settingsOpened = 0;

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Future<Position?> lastKnown() async => null;

  @override
  Stream<Position> positions() => stream ?? const Stream.empty();

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

Position _pos() => Position(
  latitude: 53.43,
  longitude: 14.55,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

void main() {
  late Directory base;

  setUp(() async {
    final root = Directory(p.join(Directory.current.path, '.dart_tool', 'test_tmp'));
    await root.create(recursive: true);
    base = await root.createTemp('map_screen_');
  });

  tearDown(() async {
    if (await base.exists()) await base.delete(recursive: true);
  });

  Future<_FakeGateway> pump(
    WidgetTester tester,
    LocationAccess access, {
    Stream<Position>? stream,
  }) async {
    final gw = _FakeGateway(access, stream);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationGatewayProvider.overrideWithValue(gw),
          mapInstallerProvider.overrideWith(
            (ref) => MapAssetInstaller(
              bundle: _Bundle(),
              baseDir: base,
              listAssets: () async => [mapTilesAsset],
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildBzTheme(),
          home: MapScreen(
            mapBuilder: (context, params) => const SizedBox.expand(key: Key('fake-map')),
          ),
        ),
      ),
    );
    // Real file IO: let the installer finish.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    return gw;
  }

  testWidgets('shows attribution, map and searching notice while there is no fix', (tester) async {
    final controller = StreamController<Position>();
    addTearDown(controller.close);
    await pump(tester, LocationAccess.granted, stream: controller.stream);
    expect(find.byKey(const Key('fake-map')), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(find.text('Szukam pozycji GPS…'), findsOneWidget);
    // Recenter is disabled without a fix.
    final sem = tester.getSemantics(find.bySemanticsLabel(recenterLabel));
    expect(sem.getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('permission denied shows notice and opens phone settings', (tester) async {
    final gw = await pump(tester, LocationAccess.denied);
    expect(find.text('Bez dostępu do lokalizacji nie pokażę, gdzie jesteś.'), findsOneWidget);
    expect(find.text('Szukam pozycji GPS…'), findsNothing);
    await tester.tap(find.text('Otwórz ustawienia telefonu'));
    expect(gw.settingsOpened, 1);
    expect(find.byKey(const Key('fake-map')), findsOneWidget);
  });

  testWidgets('with a fix: no notice, recenter is >= 48 dp and enabled', (tester) async {
    final controller = StreamController<Position>();
    addTearDown(controller.close);
    await pump(tester, LocationAccess.granted, stream: controller.stream);
    controller.add(_pos());
    await tester.pump();
    await tester.pump();
    expect(find.text('Szukam pozycji GPS…'), findsNothing);
    final btn = find.bySemanticsLabel(recenterLabel);
    expect(btn, findsOneWidget);
    final size = tester.getSize(btn);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    final data = tester.getSemantics(btn).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isTrue);
  });
}
