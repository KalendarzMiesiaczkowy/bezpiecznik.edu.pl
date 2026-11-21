import 'package:bezpiecznik/mapa/punkty/points_db.dart';
import 'package:bezpiecznik/mapa/route_guidance.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _shelter = ShelterPoint(
  id: 1,
  kind: 'shelter',
  name: 'Schron przy Mazurskiej',
  lat: 53.43,
  lon: 14.55,
  source: 'OpenStreetMap',
  verifiedAt: '2026-11-20',
  confirmed: false,
);

void main() {
  group('routeLineGeoJson', () {
    test('a line from the user to the target, lon before lat', () {
      final g = routeLineGeoJson(fromLat: 53.42, fromLon: 14.54, toLat: 53.43, toLon: 14.55);
      final geometry = ((g['features'] as List).single as Map)['geometry'] as Map;
      expect(geometry['type'], 'LineString');
      expect(geometry['coordinates'], [
        [14.54, 53.42],
        [14.55, 53.43],
      ]);
    });

    test('empty without a position or without a target (clears the layer)', () {
      expect(routeLineGeoJson(toLat: 53.43, toLon: 14.55)['features'], isEmpty);
      expect(routeLineGeoJson(fromLat: 53.42, fromLon: 14.54)['features'], isEmpty);
    });
  });

  test('remaining text: distance and walking time, null without a position', () {
    expect(routeRemainingText(850), '850 m · 12 min');
    expect(routeRemainingText(null), isNull);
  });

  group('RouteBar', () {
    Future<List<String>> pump(WidgetTester tester, double? distance, {double textScale = 1}) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildBzTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RouteBar(
                target: _shelter,
                distanceM: distance,
                onCompass: () => taps.add('compass'),
                onEnd: () => taps.add('end'),
              ),
            ),
          ),
        ),
      );
      return taps;
    }

    testWidgets('shows the target, distance, time and that it is a straight line', (tester) async {
      await pump(tester, 850);
      expect(find.text('Do: Schron przy Mazurskiej'), findsOneWidget);
      expect(find.text('850 m · 12 min'), findsOneWidget);
      expect(find.text(routeStraightLineText), findsOneWidget);
    });

    testWidgets('Kompas and Zakończ are separate actions', (tester) async {
      final taps = await pump(tester, 850);
      await tester.tap(find.byKey(const Key('route-compass')));
      await tester.tap(find.byKey(const Key('route-end')));
      expect(taps, ['compass', 'end']);
    });

    testWidgets('without a position it says so instead of a distance', (tester) async {
      await pump(tester, null);
      expect(find.text(routeNoPositionText), findsOneWidget);
      expect(find.textContaining(' min'), findsNothing);
    });

    testWidgets('within 30 m: arrived', (tester) async {
      await pump(tester, 12);
      expect(find.text(routeArrivedText), findsOneWidget);
      expect(find.text(routeStraightLineText), findsNothing);
    });

    testWidgets('no overflow at 2x text', (tester) async {
      await pump(tester, 12850, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
