import 'package:bezpiecznik/mapa/gps_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 21, 12);

  test('age wording', () {
    expect(ageText(const Duration(seconds: 20)), 'przed chwilą');
    expect(ageText(const Duration(minutes: 6)), '6 min temu');
    expect(ageText(const Duration(hours: 2)), '2 godz. temu');
    expect(ageText(const Duration(days: 3)), '3 dni temu');
  });

  test('live fix hides the status line', () {
    expect(gpsStatusLine(live: true, lost: false, lastKnownAt: null, now: now, searchLong: false), isNull);
  });

  test('searching without any position', () {
    final l = gpsStatusLine(live: false, lost: false, lastKnownAt: null, now: now, searchLong: false);
    expect(l, const GpsStatusLine('Szukam pozycji GPS…'));
    final long = gpsStatusLine(live: false, lost: false, lastKnownAt: null, now: now, searchLong: true);
    expect(long!.text, 'Nie mogę ustalić pozycji. Wyjdź pod otwarte niebo.');
  });

  test('searching with a last known position adds its age', () {
    final l = gpsStatusLine(
      live: false,
      lost: false,
      lastKnownAt: now.subtract(const Duration(minutes: 6)),
      now: now,
      searchLong: false,
    );
    expect(l, const GpsStatusLine('Szukam pozycji GPS…', 'Ostatnia pozycja: 6 min temu'));
  });

  test('lost signal', () {
    expect(
      gpsStatusLine(live: false, lost: true, lastKnownAt: null, now: now, searchLong: false),
      const GpsStatusLine('Brak sygnału GPS.'),
    );
    expect(
      gpsStatusLine(
        live: false,
        lost: true,
        lastKnownAt: now.subtract(const Duration(minutes: 3)),
        now: now,
        searchLong: false,
      ),
      const GpsStatusLine('Brak sygnału GPS.', 'Ostatnia pozycja: 3 min temu'),
    );
  });

  test('a future timestamp does not produce a negative age', () {
    final l = gpsStatusLine(
      live: false,
      lost: true,
      lastKnownAt: now.add(const Duration(minutes: 1)),
      now: now,
      searchLong: false,
    );
    expect(l!.detail, 'Ostatnia pozycja: przed chwilą');
  });

  test('marker kind', () {
    expect(userMarkerKind(live: true, hasLastKnown: true), UserMarkerKind.live);
    expect(userMarkerKind(live: false, hasLastKnown: true), UserMarkerKind.lastKnown);
    expect(userMarkerKind(live: false, hasLastKnown: false), UserMarkerKind.none);
  });

  test('marker GeoJSON is lon,lat and empty without a position', () {
    final g = userMarkerGeoJson(53.4, 14.5, live: true);
    final f = (g['features'] as List).single as Map;
    expect((f['geometry'] as Map)['coordinates'], [14.5, 53.4]);
    expect((f['properties'] as Map)['live'], true);
    expect(userMarkerGeoJson(null, null)['features'], isEmpty);
  });
}
