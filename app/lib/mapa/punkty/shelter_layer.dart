import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import 'geo.dart';
import 'points_db.dart';

/// Design-system `MapMarker` look of one shelter point.
class MarkerStyle {
  const MarkerStyle({required this.imageName, required this.glyph, required this.confirmed});
  final String imageName;
  final String glyph;
  final bool confirmed;

  @override
  bool operator ==(Object other) =>
      other is MarkerStyle && other.imageName == imageName && other.glyph == glyph && other.confirmed == confirmed;

  @override
  int get hashCode => Object.hash(imageName, glyph, confirmed);
}

/// Glyph letters per kind (S shelter, U hiding place, M emergency shelter).
const _glyphs = {'shelter': 'S', 'hiding_place': 'U', 'emergency_shelter': 'M'};

/// Confirmed: `verified` disc with the letter; unconfirmed: hollow disc with
/// dashed neutral ring and "?" (never the full PSP symbol).
MarkerStyle markerStyleFor(ShelterPoint p) {
  final glyph = _glyphs[p.kind] ?? 'S';
  final c = p.confirmed;
  return MarkerStyle(imageName: 'bz-marker-$glyph-${c ? 'c' : 'u'}', glyph: c ? glyph : '?', confirmed: c);
}

/// Every image [markerStyleFor] can return; registered once per style.
final allMarkerStyles = [
  for (final g in _glyphs.values)
    for (final c in [true, false])
      MarkerStyle(imageName: 'bz-marker-$g-${c ? 'c' : 'u'}', glyph: c ? g : '?', confirmed: c),
];

/// Logical marker size (dp) and render scale of the PNG.
const markerDp = 36.0;
const markerScale = 3.0;

/// Draws a marker as PNG (offline, no assets). Sizes follow `.bz-marker`:
/// 36 dp disc, 2 dp `bg000` border, glyph in background colour.
Future<Uint8List> renderMarkerPng(
  MarkerStyle style, {
  required Color confirmed,
  required Color unconfirmedInk,
  required Color unconfirmedGlyph,
  required Color border,
}) async {
  const k = markerScale;
  const size = markerDp * k;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  const centre = Offset(size / 2, size / 2);
  const r = size / 2 - 1 * k;
  Color glyphColor;
  if (style.confirmed) {
    canvas.drawCircle(centre, r, Paint()..color = border);
    canvas.drawCircle(centre, r - 2 * k, Paint()..color = confirmed);
    glyphColor = border;
  } else {
    canvas.drawCircle(centre, r, Paint()..color = border);
    final ring = Path()..addOval(Rect.fromCircle(center: centre, radius: r - 1 * k));
    final dash = Paint()
      ..color = unconfirmedInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k;
    for (final m in ring.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 6 * k) {
        canvas.drawPath(m.extractPath(d, math.min(d + 3.5 * k, m.length)), dash);
      }
    }
    glyphColor = unconfirmedGlyph;
  }
  final tp = TextPainter(
    text: TextSpan(
      text: style.glyph,
      style: TextStyle(color: glyphColor, fontSize: 15 * k, fontWeight: FontWeight.w800, height: 1),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  final img = await rec.endRecording().toImage(size.round(), size.round());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Symbol (icon only) for [p].
SymbolOptions symbolFor(ShelterPoint p) => SymbolOptions(
  geometry: LatLng(p.lat, p.lon),
  iconImage: markerStyleFor(p).imageName,
  iconAnchor: 'center',
);

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
