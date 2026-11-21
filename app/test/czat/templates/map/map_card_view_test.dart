import 'dart:async';

import 'package:bezpiecznik/czat/templates/map/map_card_view.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/mapa/punkty/point_sheet.dart';
import 'package:bezpiecznik/mapa/punkty/points_db.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

ShelterPoint point(
  int id, {
  bool confirmed = false,
  String? name,
  double lat = 53.43,
}) => ShelterPoint(
  id: id,
  kind: 'shelter',
  name: name,
  address: 'ul. Długa $id',
  lat: lat,
  lon: 14.55,
  source: 'OSM',
  verifiedAt: '2026-03-01',
  confirmed: confirmed,
);

Position pos() => Position(
  latitude: 53.42,
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

Future<List<String>> pump(
  WidgetTester tester, {
  required Future<List<ShelterPoint>> Function() nearest,
  Position? position,
  String target = 'nearest_shelter',
}) async {
  final visited = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => Scaffold(
          body: SingleChildScrollView(child: MapCardView(target: target)),
        ),
      ),
      GoRoute(
        path: '/mapa',
        builder: (c, s) {
          visited.add(s.uri.toString());
          return const Scaffold(body: Text('map screen'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nearestSheltersProvider.overrideWith((ref) => nearest()),
        positionProvider.overrideWith(
          (ref) =>
              position == null ? const Stream.empty() : Stream.value(position),
        ),
      ],
      child: MaterialApp.router(theme: buildBzTheme(), routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return visited;
}

void main() {
  testWidgets('empty result outside the region shows the honest notice', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearestSheltersProvider.overrideWith((ref) async => <ShelterPoint>[]),
          outsideRegionProvider.overrideWith((ref) async => true),
          positionProvider.overrideWith((ref) => Stream.value(pos())),
        ],
        child: MaterialApp(
          theme: buildBzTheme(),
          home: const Scaffold(body: MapCardView(target: 'nearest_shelter')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(outsideRegionText), findsOneWidget);
    expect(find.text(mapNoPointsText), findsNothing);
  });

  final three = [
    point(1, name: 'Schron A'),
    point(2, confirmed: true, name: 'Schron B', lat: 53.44),
    point(3),
  ];

  testWidgets(
    'shows the nearest point: distance, walk time, source chip, Prowadź',
    (tester) async {
      await pump(tester, nearest: () async => three, position: pos());
      expect(find.text('Schron A'), findsOneWidget);
      expect(find.text('Schron B'), findsNothing); // one point per card
      // 53.43 vs 53.42 -> ~1,1 km -> 15 min at 4,5 km/h.
      expect(
        find.textContaining('w linii prostej · ok. 15 min'),
        findsOneWidget,
      );
      expect(find.text('OSM · zweryf. 03.2026'), findsOneWidget);
      expect(find.text('niepotwierdzony'), findsOneWidget);
      expect(find.byKey(const ValueKey('map-card-bearing-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-card-minimap')), findsOneWidget);
      expect(find.text(pointGuideText), findsOneWidget);
      expect(find.text(mapNoPositionText), findsNothing);
    },
  );

  testWidgets('unnamed point: titled by kind, address as subtitle', (
    tester,
  ) async {
    await pump(tester, nearest: () async => [point(3)], position: pos());
    expect(find.text('Schron'), findsOneWidget);
    expect(find.text('ul. Długa 3'), findsOneWidget);
    expect(find.text('Punkt bez nazwy'), findsNothing);
  });

  testWidgets('confirmed point has no "niepotwierdzony"', (tester) async {
    await pump(
      tester,
      nearest: () async => [point(2, confirmed: true, name: 'B')],
      position: pos(),
    );
    expect(find.text('niepotwierdzony'), findsNothing);
  });

  testWidgets('stale data shows months', (tester) async {
    await pump(
      tester,
      nearest: () async => [
        const ShelterPoint(
          id: 9,
          kind: 'shelter',
          lat: 53.43,
          lon: 14.55,
          source: 'OSM',
          verifiedAt: '2020-01-01',
          confirmed: true,
        ),
      ],
      position: pos(),
    );
    expect(find.textContaining('Dane sprzed '), findsOneWidget);
  });

  testWidgets('source chip opens a dialog with source and date', (
    tester,
  ) async {
    await pump(tester, nearest: () async => three, position: pos());
    await tester.tap(find.byKey(const ValueKey('map-card-source')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Źródło: OSM, 2026-03-01'), findsOneWidget);
    expect(find.textContaining('niesprawdzone przez PSP'), findsOneWidget);
  });

  testWidgets('mini map tap opens /mapa?point=<id>', (tester) async {
    final visited = await pump(
      tester,
      nearest: () async => three,
      position: pos(),
    );
    await tester.tap(find.byKey(const ValueKey('map-card-minimap')));
    await tester.pumpAndSettle();
    expect(visited, ['/mapa?point=1']);
  });

  testWidgets('Prowadź opens the map focused on the point', (tester) async {
    final visited = await pump(
      tester,
      nearest: () async => three,
      position: pos(),
    );
    await tester.tap(find.byKey(const ValueKey('map-card-open')));
    await tester.pumpAndSettle();
    expect(visited, ['/mapa?point=1']);
  });

  testWidgets('tap targets are at least 48 dp high', (tester) async {
    await pump(tester, nearest: () async => three, position: pos());
    for (final k in ['map-card-point-1', 'map-card-open', 'map-card-source']) {
      expect(
        tester.getSize(find.byKey(ValueKey(k))).height,
        greaterThanOrEqualTo(48),
        reason: k,
      );
    }
  });

  test('walkMinutes: 450 m -> 6 min, min 1, rounds up', () {
    expect(walkMinutes(450), 6);
    expect(walkMinutes(10), 1);
    expect(walkMinutes(808), 11);
    expect(walkMinutes(1000), 14);
    expect(walkMinutes(54600), 728);
  });

  test('walkTimeText: minutes below an hour, "X h Y min" from 60', () {
    expect(walkTimeText(6), '6 min');
    expect(walkTimeText(59), '59 min');
    expect(walkTimeText(60), '1 h');
    expect(walkTimeText(70), '1 h 10 min');
    expect(walkTimeText(728), '12 h 8 min');
  });

  test('sourceChipText / monthsSince', () {
    expect(sourceChipText('OSM', '2026-03-01'), 'OSM · zweryf. 03.2026');
    expect(sourceChipText('OSM', 'x'), 'OSM');
    expect(monthsSince('2025-11-21', DateTime(2026, 11, 21)), 12);
    expect(monthsSince('2025-11-22', DateTime(2026, 11, 21)), 11);
    expect(monthsSince('x', DateTime(2026)), isNull);
  });

  test('MiniMapPainter.vectorFor points along the bearing', () {
    const size = Size(300, 96);
    final north = MiniMapPainter.vectorFor(0, size);
    expect(north.dx.abs(), lessThan(1e-6));
    expect(north.dy, lessThan(0));
    final east = MiniMapPainter.vectorFor(90, size);
    expect(east.dx, greaterThan(0));
    expect(east.dy.abs(), lessThan(1e-6));
    final ne = MiniMapPainter.vectorFor(45, size);
    expect(ne.dx, greaterThan(0));
    expect(ne.dy, lessThan(0));
    expect(ne.dx.abs(), closeTo(ne.dy.abs(), 1e-6));
  });

  testWidgets('no position: message, no distances, "Pokaż na mapie"', (
    tester,
  ) async {
    await pump(tester, nearest: () async => three);
    expect(find.text(mapNoPositionText), findsOneWidget);
    expect(find.text(mapShowOnMapText), findsOneWidget);
    expect(find.text(mapUnknownDistancesText), findsOneWidget);
    expect(find.textContaining('ok. '), findsNothing);
  });

  testWidgets('card reacts to a position fix arriving after the first build', (
    tester,
  ) async {
    final ctl = StreamController<Position?>();
    addTearDown(ctl.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => const Scaffold(
            body: SingleChildScrollView(
              child: MapCardView(target: 'nearest_shelter'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearestSheltersProvider.overrideWith((ref) async => three),
          positionProvider.overrideWith((ref) => ctl.stream),
        ],
        child: MaterialApp.router(theme: buildBzTheme(), routerConfig: router),
      ),
    );
    ctl.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text(mapNoPositionText), findsOneWidget);
    ctl.add(pos());
    await tester.pump();
    await tester.pump();
    expect(find.text(mapNoPositionText), findsNothing);
    expect(find.text(pointGuideText), findsOneWidget);
    expect(find.byKey(const ValueKey('map-card-bearing-1')), findsOneWidget);
  });

  testWidgets('empty list shows the spec text', (tester) async {
    await pump(tester, nearest: () async => const [], position: pos());
    expect(find.text(mapNoPointsText), findsOneWidget);
  });

  testWidgets('loading shows calm text', (tester) async {
    final never = Future<List<ShelterPoint>>.delayed(
      const Duration(days: 1),
      () => const [],
    );
    await pump(tester, nearest: () => never, position: pos());
    expect(find.text(mapLoadingText), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(days: 2));
  });

  testWidgets('hospital target has no data: spec text, no invented points', (
    tester,
  ) async {
    await pump(
      tester,
      nearest: () async => three,
      position: pos(),
      target: 'nearest_hospital',
    );
    expect(find.text(mapNoPointsText), findsOneWidget);
    expect(find.text('Schron A'), findsNothing);
    expect(find.text(mapHospitalCardTitle), findsOneWidget);
    expect(find.text(mapCardTitle), findsNothing);
  });

  test('registerMapTemplate replaces the placeholder', () {
    final r = TemplateRegistry.withDefaults();
    registerMapTemplate(r);
    expect(r.builderFor('map'), isNotNull);
  });
}
