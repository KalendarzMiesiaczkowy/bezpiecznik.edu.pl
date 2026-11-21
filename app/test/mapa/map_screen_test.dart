import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:bezpiecznik/mapa/map_assets.dart';
import 'package:bezpiecznik/mapa/map_screen.dart';
import 'package:bezpiecznik/wspolne/theme/bz_buttons.dart';
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
  _FakeGateway(this.access, [this.stream, this.last]);

  final Position? last;

  final LocationAccess access;
  final Stream<Position>? stream;
  int settingsOpened = 0;

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Future<Position?> lastKnown() async => last;

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
    Position? last,
    MapViewBuilder? builder,
  }) async {
    final gw = _FakeGateway(access, stream, last);
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
            mapBuilder: builder ?? (context, params) => const SizedBox.expand(key: Key('fake-map')),
          ),
        ),
      ),
    );
    // Real file IO: let the installer finish (up to ~2 s; fixed 0.4 s was
    // flaky when the whole suite runs in parallel).
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (i >= 19 && find.text(preparingTitle).evaluate().isEmpty) break;
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

  testWidgets('Warstwy sits above the recenter button, right-aligned, opens layer toggle', (tester) async {
    final controller = StreamController<Position>();
    addTearDown(controller.close);
    await pump(tester, LocationAccess.granted, stream: controller.stream);
    final layers = find.text('Warstwy');
    expect(layers, findsOneWidget);
    final layersRect = tester.getRect(find.byType(LayersButton));
    final recenterRect = tester.getRect(find.bySemanticsLabel(recenterLabel));
    expect(layersRect.bottom, lessThan(recenterRect.top));
    expect(layersRect.right, recenterRect.right);
    expect(layersRect.height, greaterThanOrEqualTo(48));
    expect(find.text('Schrony i ukrycia'), findsNothing);
    await tester.tap(layers);
    await tester.pumpAndSettle();
    expect(find.text('Schrony i ukrycia'), findsOneWidget);
    expect(find.text('Warstwy'), findsNWidgets(2)); // button + sheet title
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('Najbliższy schron is full width minus 16 dp margins, below Warstwy and recenter', (tester) async {
    final controller = StreamController<Position>();
    addTearDown(controller.close);
    await pump(tester, LocationAccess.granted, stream: controller.stream);
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final nearest = find.ancestor(of: find.text('Najbliższy schron'), matching: find.byType(BzButton));
    expect(nearest, findsOneWidget);
    final rect = tester.getRect(nearest);
    expect(rect.width, screenWidth - 32);
    expect(rect.left, 16);
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(tester.getRect(find.byType(LayersButton)).bottom, lessThanOrEqualTo(rect.top));
    expect(tester.getRect(find.bySemanticsLabel(recenterLabel)).bottom, lessThanOrEqualTo(rect.top));
  });

  testWidgets('last known position only: searching line with its age, recenter disabled', (tester) async {
    final controller = StreamController<Position>();
    addTearDown(controller.close);
    MapViewParams? params;
    final old = Position(
      latitude: 53.5,
      longitude: 14.6,
      timestamp: DateTime.now().subtract(const Duration(minutes: 6, seconds: 5)),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
    await pump(
      tester,
      LocationAccess.granted,
      stream: controller.stream,
      last: old,
      builder: (context, p) {
        params = p;
        return const SizedBox.expand(key: Key('fake-map'));
      },
    );
    expect(find.text('Szukam pozycji GPS…'), findsOneWidget);
    expect(find.text('Ostatnia pozycja: 6 min temu'), findsOneWidget);
    final sem = tester.getSemantics(find.bySemanticsLabel(recenterLabel));
    expect(sem.getSemanticsData().flagsCollection.isEnabled, Tristate.isFalse);
    // Camera starts at the last known position; native puck is off.
    expect(params!.initialTarget.latitude, 53.5);
    expect(params!.myLocationEnabled, isFalse);
  });

  testWidgets('lost signal shows "Brak sygnału GPS." with the last live position age', (tester) async {
    final controller = StreamController<Position>();
    addTearDown(controller.close);
    await pump(tester, LocationAccess.granted, stream: controller.stream);
    controller.add(_pos());
    await tester.pump();
    await tester.pump();
    controller.addError(StateError('gps off'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Brak sygnału GPS.'), findsOneWidget);
    expect(find.textContaining('Ostatnia pozycja:'), findsOneWidget);
  });

  testWidgets('a live fix starts the camera at the fix', (tester) async {
    final controller = StreamController<Position>();
    addTearDown(controller.close);
    controller.add(_pos());
    MapViewParams? params;
    await pump(
      tester,
      LocationAccess.granted,
      stream: controller.stream,
      builder: (context, p) {
        params = p;
        return const SizedBox.expand(key: Key('fake-map'));
      },
    );
    expect(params!.initialTarget.latitude, 53.43);
  });
}
