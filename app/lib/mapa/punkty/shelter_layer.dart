import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import 'geo.dart';
import 'points_db.dart';

/// Hex string `#RRGGBB` as MapLibre expects.
String hexOf(Color c) {
  String h(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

/// Confirmed: filled, solid coloured outline. Unconfirmed: hollow, grey
/// outline (never the PSP shelter look). MapLibre circles have no dashed
/// stroke, so "hollow + grey" is the distinction on the map.
CircleOptions circleFor(ShelterPoint p, {required Color confirmed, required Color unconfirmed}) {
  return p.confirmed
      ? CircleOptions(
          geometry: LatLng(p.lat, p.lon),
          circleRadius: 9,
          circleColor: hexOf(confirmed),
          circleOpacity: 1,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
          circleStrokeOpacity: 1,
        )
      : CircleOptions(
          geometry: LatLng(p.lat, p.lon),
          circleRadius: 9,
          circleColor: hexOf(unconfirmed),
          circleOpacity: 0,
          circleStrokeColor: hexOf(unconfirmed),
          circleStrokeWidth: 3,
          circleStrokeOpacity: 1,
        );
}

/// Finds the point whose 48 dp touch area contains a tap (circles are only
/// 18 dp, so annotation taps would be too small). Metres per dp from the
/// Web Mercator scale at [zoom].
ShelterPoint? hitTest(
  List<ShelterPoint> points,
  double tapLat,
  double tapLon,
  double zoom, {
  double targetDp = 48,
}) {
  final mPerDp = 156543.03392 * math.cos(tapLat * math.pi / 180) / math.pow(2, zoom);
  final limit = targetDp / 2 * mPerDp;
  ShelterPoint? best;
  var bestD = double.infinity;
  for (final p in points) {
    final d = haversineM(tapLat, tapLon, p.lat, p.lon);
    if (d <= limit && d < bestD) {
      best = p;
      bestD = d;
    }
  }
  return best;
}
