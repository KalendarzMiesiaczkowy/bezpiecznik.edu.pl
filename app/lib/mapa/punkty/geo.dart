import 'dart:math' as math;

/// Mean Earth radius in metres (spherical model).
const earthRadiusM = 6371008.8;

double _rad(double deg) => deg * math.pi / 180;

/// Great-circle distance in metres (haversine).
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusM * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Initial bearing from point 1 to point 2, degrees clockwise from true
/// north, in [0, 360).
double bearingDeg(double lat1, double lon1, double lat2, double lon2) {
  final p1 = _rad(lat1);
  final p2 = _rad(lat2);
  final dLon = _rad(lon2 - lon1);
  final y = math.sin(dLon) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// 8 compass directions in Polish (spec: ekran-2-mapa.md, stan `compass`).
const cardinalNames = [
  'północ',
  'północny wschód',
  'wschód',
  'południowy wschód',
  'południe',
  'południowy zachód',
  'zachód',
  'północny zachód',
];

String cardinalName(double bearing) {
  final i = (((bearing % 360) + 360) % 360 + 22.5) ~/ 45 % 8;
  return cardinalNames[i];
}

/// Arrow glyph for a bearing (north = up).
String arrowFor(double bearing) {
  const arrows = ['↑', '↗', '→', '↘', '↓', '↙', '←', '↖'];
  return arrows[(((bearing % 360) + 360) % 360 + 22.5) ~/ 45 % 8];
}

/// "450 m" (rounded to 10 m) below 1 km, "1,2 km" above (Polish decimal
/// comma; ekran-2-mapa.md Formaty).
String formatDistance(double metres) {
  if (metres < 995) return '${(metres / 10).round() * 10} m';
  return '${(metres / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}
