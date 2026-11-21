import 'package:bezpiecznik/czat/templates/map/map_card_view.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/mapa/punkty/points_db.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

ShelterPoint point(int id, {bool confirmed = false, String? name, double lat = 53.43}) => ShelterPoint(
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
      GoRoute(path: '/', builder: (c, s) => Scaffold(body: SingleChildScrollView(child: MapCardView(target: target)))),
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
        positionProvider.overrideWith((ref) => position == null ? const Stream.empty() : Stream.value(position)),
      ],
      child: MaterialApp.router(theme: buildBzTheme(), routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  return visited;
}

void main() {
  final three = [point(1, name: 'Schron A'), point(2, confirmed: true, name: 'Schron B', lat: 53.44), point(3)];

  testWidgets('shows 3 points with distance and unconfirmed status', (tester) async {
    await pump(tester, nearest: () async => three, position: pos());
    expect(find.text('Schron A'), findsOneWidget);
    expect(find.text('Schron B'), findsOneWidget);
    expect(find.text('ul. Długa 3'), findsOneWidget); // unnamed: address is the title
    expect(find.text('niepotwierdzony'), findsNWidgets(2));
    expect(find.textContaining(' m'), findsWidgets);
    expect(find.text(mapNoPositionText), findsNothing);
    expect(find.text(mapOpenMapText), findsOneWidget);
  });

  testWidgets('tap on a point opens /mapa?point=<id>', (tester) async {
    final visited = await pump(tester, nearest: () async => three, position: pos());
    await tester.tap(find.byKey(const ValueKey('map-card-point-2')));
    await tester.pumpAndSettle();
    expect(visited, ['/mapa?point=2']);
  });

  testWidgets('open map button goes to /mapa', (tester) async {
    final visited = await pump(tester, nearest: () async => three, position: pos());
    await tester.tap(find.byKey(const ValueKey('map-card-open')));
    await tester.pumpAndSettle();
    expect(visited, ['/mapa']);
  });

  testWidgets('rows and button are at least 48 dp high', (tester) async {
    await pump(tester, nearest: () async => three, position: pos());
    expect(tester.getSize(find.byKey(const ValueKey('map-card-point-1'))).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byKey(const ValueKey('map-card-open'))).height, greaterThanOrEqualTo(48));
  });

  testWidgets('no position: message, no distances, "Pokaż na mapie"', (tester) async {
    await pump(tester, nearest: () async => three);
    expect(find.text(mapNoPositionText), findsOneWidget);
    expect(find.text(mapShowOnMapText), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d+ m ')), findsNothing);
  });

  testWidgets('empty list shows the spec text', (tester) async {
    await pump(tester, nearest: () async => const [], position: pos());
    expect(find.text(mapNoPointsText), findsOneWidget);
  });

  testWidgets('loading shows calm text', (tester) async {
    final never = Future<List<ShelterPoint>>.delayed(const Duration(days: 1), () => const []);
    await pump(tester, nearest: () => never, position: pos());
    expect(find.text(mapLoadingText), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(days: 2));
  });

  testWidgets('hospital target has no data: spec text, no invented points', (tester) async {
    await pump(tester, nearest: () async => three, position: pos(), target: 'nearest_hospital');
    expect(find.text(mapNoPointsText), findsOneWidget);
    expect(find.text('Schron A'), findsNothing);
  });

  test('registerMapTemplate replaces the placeholder', () {
    final r = TemplateRegistry.withDefaults();
    registerMapTemplate(r);
    expect(r.builderFor('map'), isNotNull);
  });
}
