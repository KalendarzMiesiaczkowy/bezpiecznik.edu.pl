/// Pure logic for the map's GPS status line and own-position marker.
library;

const gpsSearchingText = 'Szukam pozycji GPS…'; // map.gps.searching
const gpsSearchingLongText = 'Nie mogę ustalić pozycji. Wyjdź pod otwarte niebo.'; // map.gps.searchingLong
const gpsLostText = 'Brak sygnału GPS.'; // spec: Stany, Brak GPS

/// Seconds without a first fix before the long "no position" text (spec).
const gpsSearchLongSeconds = 60;

/// Age wording of the last known position, spec "3 min temu".
/// verify:true, source: ekran-2-mapa.md "Pozycja użytkownika" gives only the
/// "3 min temu" form; the "przed chwilą", hours and days forms are drafted.
String ageText(Duration age) {
  if (age.inSeconds < 60) return 'przed chwilą';
  if (age.inMinutes < 60) return '${age.inMinutes} min temu';
  if (age.inHours < 24) return '${age.inHours} godz. temu';
  return '${age.inDays} dni temu';
}

/// Status line under the top bar.
class GpsStatusLine {
  const GpsStatusLine(this.text, [this.detail]);

  final String text;

  /// Second line: "Ostatnia pozycja: 6 min temu".
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is GpsStatusLine && other.text == text && other.detail == detail;

  @override
  int get hashCode => Object.hash(text, detail);
}

/// What the status line shows; null when a fresh live fix makes it hidden.
///
/// [live]: the position comes from the GPS stream. [lost]: a fix existed or the
/// stream failed and there is no signal now. [lastKnownAt]: timestamp of the
/// last known position, when there is one.
GpsStatusLine? gpsStatusLine({
  required bool live,
  required bool lost,
  required DateTime? lastKnownAt,
  required DateTime now,
  required bool searchLong,
}) {
  if (live) return null;
  final detail = lastKnownAt == null
      ? null
      : 'Ostatnia pozycja: ${ageText(now.difference(lastKnownAt).isNegative ? Duration.zero : now.difference(lastKnownAt))}';
  if (lost) return GpsStatusLine(gpsLostText, detail);
  return GpsStatusLine(searchLong ? gpsSearchingLongText : gpsSearchingText, detail);
}

enum UserMarkerKind {
  /// Live fix: `info` dot.
  live,

  /// Only a last-known position: grey `ink-300` dot.
  lastKnown,

  /// Nothing to draw.
  none,
}

UserMarkerKind userMarkerKind({required bool live, required bool hasLastKnown}) {
  if (live) return UserMarkerKind.live;
  return hasLastKnown ? UserMarkerKind.lastKnown : UserMarkerKind.none;
}

/// GeoJSON for the marker source; an empty collection hides the dot.
Map<String, dynamic> userMarkerGeoJson(double? lat, double? lon, {bool live = false}) => {
  'type': 'FeatureCollection',
  'features': [
    if (lat != null && lon != null)
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [lon, lat],
        },
        'properties': <String, dynamic>{'live': live},
      },
  ],
};
