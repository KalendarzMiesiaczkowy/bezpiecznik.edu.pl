import 'dart:math' as math;

import 'package:bezpiecznik/mapa/kompas/compass_screen.dart';
import 'package:bezpiecznik/mapa/kompas/heading_provider.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/mapa/punkty/points_db.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

const target = ShelterPoint(
  id: 1, kind: 'shelter', lat: 53.4385, lon: 14.5528, address: 'ul. Lipowa 5',
  source: 'KG PSP', verifiedAt: '2026-10-12', confirmed: true,
);

Position pos({double lat = 53.4285, DateTime? at}) => Position(
  latitude: lat, longitude: 14.5528, timestamp: at ?? DateTime(2026, 11, 21, 12),
  accuracy: 5, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0,
  speed: 0, speedAccuracy: 0,
);

Widget app({required Position? p, required HeadingReading? h, DateTime? now}) => ProviderScope(
  overrides: [
    positionProvider.overrideWith((ref) => Stream.value(p)),
    headingProvider.overrideWith((ref) => Stream.value(h)),
  ],
  child: MaterialApp(
    theme: buildBzTheme(),
    home: Scaffold(
      body: CompassScreen(
        target: target, onShowMap: () {}, onEnd: () {},
        now: () => now ?? DateTime(2026, 11, 21, 12),
      ),
    ),
  ),
);

void main() {
  testWidgets('arrow = bearing - heading, distance, cardinal, coords', (t) async {
    await t.pumpWidget(app(p: pos(), h: const HeadingReading(90, reliable: true)));
    await t.pump();
    expect(find.text('Do: Schron, ul. Lipowa 5'), findsOneWidget);
    expect(find.text('1,1 km'), findsOneWidget);
    expect(find.text('północ'), findsOneWidget);
    expect(find.text('53.42850, 14.55280'), findsOneWidget);
    final arrow = t.widget<Transform>(find.byKey(const Key('compass-arrow')));
    // target due north, phone faces east -> arrow turns -90 deg
    expect(arrow.transform.getRotation().getColumn(0)[1], closeTo(math.sin(-math.pi / 2), 1e-6));
    expect(find.text('Pokaż mapę'), findsOneWidget);
    expect(find.text('Zakończ'), findsOneWidget);
    expect(find.byKey(const Key('compass-notice')), findsNothing);
  });

  testWidgets('calibration hint when reading unreliable', (t) async {
    await t.pumpWidget(app(p: pos(), h: const HeadingReading(0, reliable: false)));
    await t.pump();
    expect(find.text(compassCalibrateText), findsOneWidget);
  });

  testWidgets('no sensor and standing: direction text, no arrow', (t) async {
    await t.pumpWidget(app(p: pos(), h: null));
    await t.pump();
    expect(find.byKey(const Key('compass-arrow')), findsNothing);
    expect(find.text('Twój telefon nie ma kompasu. Idź na północ.'), findsOneWidget);
  });

  testWidgets('no position at all', (t) async {
    await t.pumpWidget(app(p: null, h: const HeadingReading(0, reliable: true)));
    await t.pump();
    expect(find.text(compassNoPositionText), findsOneWidget);
    expect(find.byKey(const Key('compass-arrow')), findsNothing);
  });

  testWidgets('pushed as a bare route (no Scaffold) the text still has a Material', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        positionProvider.overrideWith((ref) => Stream.value(pos())),
        headingProvider.overrideWith((ref) => Stream.value(const HeadingReading(90, reliable: true))),
      ],
      child: MaterialApp(
        theme: buildBzTheme(),
        home: CompassScreen(
          target: target, onShowMap: () {}, onEnd: () {},
          now: () => DateTime(2026, 11, 21, 12),
        ),
      ),
    ));
    await t.pump();
    final text = find.byType(Text).first;
    expect(find.ancestor(of: text, matching: find.byType(Material)), findsWidgets);
  });
}
