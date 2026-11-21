import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../position_provider.dart';
import 'geo.dart';

const pointsAssetKey = 'assets/generated/points.sqlite';

/// Kinds of the "nearest shelter" list (spec: ekran-2-mapa.md, arkusz `nearest`).
const shelterKinds = ['shelter', 'hiding_place', 'emergency_shelter'];

/// Szczecin centre fallback when there is no position.
const szczecinLat = 53.4285;
const szczecinLon = 14.5528;

/// One row of the `points` table (contract: kontrakty-tresci.md "Baza punktów").
class ShelterPoint {
  const ShelterPoint({
    required this.id,
    required this.kind,
    required this.lat,
    required this.lon,
    required this.source,
    required this.verifiedAt,
    required this.confirmed,
    this.name,
    this.address,
    this.availability,
    this.open24h,
    this.distanceM,
  });

  final int id;
  final String kind;
  final String? name;
  final String? address;
  final double lat;
  final double lon;
  final String? availability;
  final bool? open24h;
  final String source;
  final String verifiedAt;
  final bool confirmed;

  /// Straight-line distance from the query origin, when known.
  final double? distanceM;

  ShelterPoint withDistance(double d) => ShelterPoint(
    id: id,
    kind: kind,
    lat: lat,
    lon: lon,
    source: source,
    verifiedAt: verifiedAt,
    confirmed: confirmed,
    name: name,
    address: address,
    availability: availability,
    open24h: open24h,
    distanceM: d,
  );
}

const _cols = 'p.id, p.kind, p.name, p.address, p.lat, p.lon, p.availability, '
    'p.open_24h, p.source, p.verified_at, p.confirmed';

ShelterPoint _row(Row r) => ShelterPoint(
  id: r['id'] as int,
  kind: r['kind'] as String,
  name: r['name'] as String?,
  address: r['address'] as String?,
  lat: (r['lat'] as num).toDouble(),
  lon: (r['lon'] as num).toDouble(),
  availability: r['availability'] as String?,
  open24h: r['open_24h'] == null ? null : (r['open_24h'] as int) == 1,
  source: r['source'] as String,
  verifiedAt: r['verified_at'] as String,
  confirmed: (r['confirmed'] as int) == 1,
);

/// Read-only access to `points.sqlite` (R*Tree prefilter, exact haversine).
class PointsDb {
  PointsDb(this._db);

  final Database _db;

  /// Opens [file] read-only.
  factory PointsDb.openFile(File file) => PointsDb(sqlite3.open(file.path, mode: OpenMode.readOnly));

  void close() => _db.close();

  List<ShelterPoint> _box(double minLat, double maxLat, double minLon, double maxLon, List<String> kinds) {
    final marks = List.filled(kinds.length, '?').join(',');
    final rows = _db.select(
      'SELECT $_cols FROM points_rtree r JOIN points p ON p.id = r.id '
      'WHERE r.max_lat >= ? AND r.min_lat <= ? AND r.max_lon >= ? AND r.min_lon <= ? '
      'AND p.kind IN ($marks)',
      [minLat, maxLat, minLon, maxLon, ...kinds],
    );
    return rows.map(_row).toList();
  }

  /// The point with [id], or null when unknown.
  ShelterPoint? byId(int id) {
    final rows = _db.select('SELECT $_cols FROM points p WHERE p.id = ?', [id]);
    return rows.isEmpty ? null : _row(rows.first);
  }

  /// Points inside the bounds, for the map layer.
  List<ShelterPoint> inBounds(
    double south,
    double west,
    double north,
    double east, {
    List<String> kinds = shelterKinds,
  }) => _box(south, north, west, east, kinds);

  /// [n] nearest points of [kinds]. Starts with a [startRadiusM] box and
  /// doubles it until [n] points lie within the radius (so the box cannot
  /// hide a closer point) or [maxRadiusM] is reached.
  List<ShelterPoint> nearest(
    double lat,
    double lon, {
    int n = 3,
    List<String> kinds = shelterKinds,
    double startRadiusM = 1000,
    double maxRadiusM = 200000,
  }) {
    var radius = startRadiusM;
    while (true) {
      final dLat = radius / 111320;
      final cosLat = math.max(0.01, math.cos(lat * math.pi / 180));
      final dLon = radius / (111320 * cosLat);
      final hits = [
        for (final pt in _box(lat - dLat, lat + dLat, lon - dLon, lon + dLon, kinds))
          pt.withDistance(haversineM(lat, lon, pt.lat, pt.lon)),
      ]..sort((a, b) => a.distanceM!.compareTo(b.distanceM!));
      final inside = hits.where((h) => h.distanceM! <= radius).length;
      if (inside >= n || radius >= maxRadiusM) {
        return hits.take(n).toList();
      }
      radius *= 2;
    }
  }
}

/// Bump when the bundled points.sqlite changes.
const pointsDbVersion = 1;

/// Copies the asset to [baseDir] on first use (marker holds version and size)
/// and returns the file.
Future<File> installPointsDb({
  required AssetBundle bundle,
  required Directory baseDir,
}) async {
  final data = await bundle.load(pointsAssetKey);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final file = File(p.join(baseDir.path, 'points.sqlite'));
  final marker = File(p.join(baseDir.path, 'points.sqlite.installed'));
  final stamp = '$pointsDbVersion:${bytes.length}';
  if (await file.exists() && await marker.exists() && await marker.readAsString() == stamp) {
    return file;
  }
  await baseDir.create(recursive: true);
  if (await marker.exists()) await marker.delete();
  await file.writeAsBytes(bytes, flush: true);
  await marker.writeAsString(stamp, flush: true);
  return file;
}

final pointsDbProvider = FutureProvider<PointsDb>((ref) async {
  final base = await getApplicationSupportDirectory();
  final file = await installPointsDb(bundle: rootBundle, baseDir: base);
  final db = PointsDb.openFile(file);
  ref.onDispose(db.close);
  return db;
});

/// 3 nearest shelters from the device position (Szczecin centre fallback).
/// Used by the map sheet and by the chat `map` template (B06).
final nearestSheltersProvider = FutureProvider<List<ShelterPoint>>((ref) async {
  final db = await ref.watch(pointsDbProvider.future);
  final pos = ref.watch(positionProvider).value;
  return db.nearest(pos?.latitude ?? szczecinLat, pos?.longitude ?? szczecinLon);
});
