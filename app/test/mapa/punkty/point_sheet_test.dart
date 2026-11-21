import 'package:bezpiecznik/mapa/punkty/point_sheet.dart';
import 'package:bezpiecznik/mapa/punkty/points_db.dart';
import 'package:bezpiecznik/mapa/punkty/shelter_layer.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

ShelterPoint pt({String? name, String? address, bool confirmed = false, String verified = '2026-11-19'}) =>
    ShelterPoint(
      id: 1,
      kind: 'shelter',
      lat: 53.43,
      lon: 14.55,
      source: confirmed ? 'KG PSP' : 'OpenStreetMap',
      verifiedAt: verified,
      confirmed: confirmed,
      name: name,
      address: address,
      distanceM: 450,
    );

Widget wrap(Widget child) => MaterialApp(
  theme: buildBzTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('unconfirmed OSM point without name', (t) async {
    await t.pumpWidget(wrap(PointSheet(point: pt(address: 'ul. Polna 2'), now: DateTime(2026, 11, 21))));
    expect(find.text('ul. Polna 2'), findsOneWidget);
    expect(find.text('? Niepotwierdzony. Dane z OpenStreetMap, niesprawdzone przez PSP.'), findsOneWidget);
    expect(find.text('Źródło: OpenStreetMap, 2026-11-19'), findsOneWidget);
    expect(find.text('Dostępność: brak danych'), findsOneWidget);
    expect(find.text('450 m'), findsOneWidget);
    expect(find.text('Prowadź'), findsOneWidget);
    expect(find.text('Kompas'), findsOneWidget);
    expect(find.text(pointStaleText), findsNothing);
  });

  testWidgets('fallback label, confirmed and stale', (t) async {
    await t.pumpWidget(wrap(PointSheet(
      point: pt(confirmed: true, verified: '2025-01-01'),
      now: DateTime(2026, 11, 21),
    )));
    expect(find.text('Punkt bez nazwy'), findsOneWidget);
    expect(find.text('✓ Potwierdzony'), findsOneWidget);
    expect(find.text('Dane sprawdzono ponad rok temu. Mogą być nieaktualne.'), findsOneWidget);
  });

  testWidgets('toggle is at least 48 dp and fires', (t) async {
    var v = true;
    await t.pumpWidget(wrap(ShelterLayerToggle(on: v, onChanged: (x) => v = x)));
    final size = t.getSize(find.byType(ShelterLayerToggle));
    expect(size.height, greaterThanOrEqualTo(48));
    await t.tap(find.text('Schrony i ukrycia'));
    expect(v, isFalse);
  });

  testWidgets('nearest rows are >= 56 dp, tap selects, unconfirmed label', (t) async {
    ShelterPoint? picked;
    await t.pumpWidget(wrap(NearestList(
      points: [pt(address: 'ul. Polna 2')],
      onSelect: (p) => picked = p,
    )));
    expect(find.text('Najbliższe schronienie'), findsOneWidget);
    expect(find.text('niepotwierdzony'), findsOneWidget);
    expect(t.getSize(find.byKey(const ValueKey('nearest-1'))).height, greaterThanOrEqualTo(56));
    await t.tap(find.byKey(const ValueKey('nearest-1')));
    expect(picked?.id, 1);
  });

  test('marker style: confirmed vs unconfirmed, kind glyphs; hit test uses 48 dp', () {
    final c = markerStyleFor(pt(confirmed: true));
    final u = markerStyleFor(pt());
    expect(c.imageName, 'bz-marker-S-c');
    expect(c.glyph, 'S');
    expect(u.imageName, 'bz-marker-S-u');
    expect(u.glyph, '?');
    expect(allMarkerStyles.map((m) => m.imageName).toSet().length, 6);
    expect(allMarkerStyles, contains(c));
    expect(symbolFor(pt()).iconImage, 'bz-marker-S-u');
    final a = pt();
    expect(hitTest([a], 53.43, 14.55, 14), same(a));
    expect(hitTest([a], 53.5, 14.55, 14), isNull);
  });

  testWidgets('direction is a rotated Lucide arrow, not a Unicode arrow (BG55)', (t) async {
    // From a point due north-east of the shelter -> bearing ~225 deg (SW).
    await t.pumpWidget(wrap(PointSheet(
      point: pt(),
      fromLat: 53.436,
      fromLon: 14.56,
      now: DateTime(2026, 11, 21),
    )));
    final arrow = t.widget<Transform>(find.byKey(const ValueKey('bearing-arrow')));
    expect(arrow, isNotNull);
    final texts = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').join(' ');
    expect(texts, contains('południowy zachód'));
    expect(RegExp('[↑↗→↘↓↙←↖]').hasMatch(texts), isFalse);
  });
}
