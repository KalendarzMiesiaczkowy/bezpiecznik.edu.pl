import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import 'geo.dart';
import 'points_db.dart';
import 'shelter_layer.dart';

/// A group of shelter points drawn as one marker (one point = plain marker).
class MarkerCluster {
  const MarkerCluster(this.members, this.lat, this.lon);

  /// Members sorted by id.
  final List<ShelterPoint> members;

  /// Centroid.
  final double lat;
  final double lon;

  int get count => members.length;
  bool get isSingle => members.length == 1;
  bool get anyConfirmed => members.any((p) => p.confirmed);

  /// "2".."9", then "9+".
  String get label => count > 9 ? '9+' : '$count';

  /// Name of the cluster image, see [allClusterStyles].
  String get imageName => clusterImageName(label, anyConfirmed);

  ShelterPoint get first => members.first;
}

String clusterImageName(String label, bool confirmed) => 'bz-cluster-${label == '9+' ? '9p' : label}-${confirmed ? 'c' : 'u'}';

/// Every cluster image: counts 2..9 and "9+", confirmed and not.
final allClusterStyles = [
  for (final label in [for (var i = 2; i <= 9; i++) '$i', '9+'])
    for (final c in [true, false])
      MarkerStyle(imageName: clusterImageName(label, c), glyph: label, confirmed: c),
];

/// Web Mercator world position in dp at [zoom]. MapLibre GL zoom levels use
/// 512 dp tiles (the world is 512 dp wide at z0), not raster 256 px tiles.
({double x, double y}) _worldDp(double lat, double lon, double zoom) {
  final world = 512.0 * math.pow(2, zoom);
  final s = math.sin(lat.clamp(-85.05112878, 85.05112878) * math.pi / 180);
  return (
    x: (lon + 180) / 360 * world,
    y: (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * world,
  );
}

/// Groups points closer on screen than [radiusDp] (one marker diameter).
/// Greedy and deterministic: points are visited by id; each joins the first
/// cluster whose seed is within range, otherwise seeds a new one.
List<MarkerCluster> clusterPoints(List<ShelterPoint> points, double zoom, {double radiusDp = markerDp}) {
  final sorted = [...points]..sort((a, b) => a.id.compareTo(b.id));
  final seeds = <({double x, double y})>[];
  final groups = <List<ShelterPoint>>[];
  for (final p in sorted) {
    final w = _worldDp(p.lat, p.lon, zoom);
    var joined = false;
    for (var i = 0; i < seeds.length; i++) {
      final dx = seeds[i].x - w.x;
      final dy = seeds[i].y - w.y;
      if (math.sqrt(dx * dx + dy * dy) < radiusDp) {
        groups[i].add(p);
        joined = true;
        break;
      }
    }
    if (!joined) {
      seeds.add(w);
      groups.add([p]);
    }
  }
  return [
    for (final g in groups)
      MarkerCluster(
        g,
        g.fold<double>(0, (s, p) => s + p.lat) / g.length,
        g.fold<double>(0, (s, p) => s + p.lon) / g.length,
      ),
  ];
}

/// Symbol for a cluster: plain marker for a single point, count image else.
SymbolOptions symbolForCluster(MarkerCluster c) => c.isSingle
    ? symbolFor(c.first)
    : SymbolOptions(geometry: LatLng(c.lat, c.lon), iconImage: c.imageName, iconAnchor: 'center');

/// Cluster whose 48 dp touch area contains the tap (nearest wins).
MarkerCluster? hitTestClusters(
  List<MarkerCluster> clusters,
  double tapLat,
  double tapLon,
  double zoom, {
  double targetDp = 48,
}) {
  final mPerDp = 78271.51696 * math.cos(tapLat * math.pi / 180) / math.pow(2, zoom);
  final limit = targetDp / 2 * mPerDp;
  MarkerCluster? best;
  var bestD = double.infinity;
  for (final c in clusters) {
    final d = haversineM(tapLat, tapLon, c.lat, c.lon);
    if (d <= limit && d < bestD) {
      best = c;
      bestD = d;
    }
  }
  return best;
}

/// Highest zoom a cluster tap may move to (tiles stop at z14; overzoom
/// past this shows an empty map).
const clusterMaxZoom = 18.0;

/// Smallest whole zoom above [zoom] (up to [clusterMaxZoom]) at which the
/// cluster's members no longer form one group; null when they never split
/// (practically the same place: the caller opens the first point instead).
double? clusterSplitZoom(MarkerCluster c, double zoom) {
  for (var z = zoom.floorToDouble() + 1; z <= clusterMaxZoom; z++) {
    if (clusterPoints(c.members, z).length > 1) return z;
  }
  return null;
}

/// Camera move for a tapped cluster: centre on it at the zoom that splits
/// it, or null when it never splits (see [clusterSplitZoom]).
CameraUpdate? clusterCameraUpdate(MarkerCluster c, double zoom) {
  final z = clusterSplitZoom(c, zoom);
  if (z == null) return null;
  return CameraUpdate.newLatLngZoom(LatLng(c.lat, c.lon), z);
}
