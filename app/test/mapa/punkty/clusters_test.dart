import 'package:bezpiecznik/mapa/punkty/clusters.dart';
import 'package:bezpiecznik/mapa/punkty/points_db.dart';
import 'package:flutter_test/flutter_test.dart';

ShelterPoint _p(int id, double lat, double lon, {bool confirmed = false}) => ShelterPoint(
  id: id,
  kind: 'shelter',
  lat: lat,
  lon: lon,
  source: 'osm',
  verifiedAt: '2026-01-01',
  confirmed: confirmed,
);

// ~29 m apart in latitude (0.00026 deg * 111.2 km).
final _a = _p(1, 53.4285, 14.5528);
final _b = _p(2, 53.42876, 14.5528);

void main() {
  test('two points 29 m apart at z15 form one cluster of 2', () {
    final c = clusterPoints([_b, _a], 15);
    expect(c, hasLength(1));
    expect(c.single.count, 2);
    expect(c.single.members.map((p) => p.id), [1, 2]);
    expect(c.single.label, '2');
  });

  test('same points at z19 stay singles', () {
    final c = clusterPoints([_a, _b], 19);
    expect(c, hasLength(2));
    expect(c.every((x) => x.isSingle), isTrue);
  });

  test('three far points are three singles', () {
    final c = clusterPoints([_a, _p(3, 53.5, 14.6), _p(4, 53.3, 14.4)], 15);
    expect(c, hasLength(3));
  });

  test('zoom 10 merges Szczecin points', () {
    final pts = [_a, _b, _p(3, 53.43, 14.56), _p(4, 53.42, 14.54)];
    final c = clusterPoints(pts, 10);
    expect(c, hasLength(1));
    expect(c.single.count, 4);
  });

  test('deterministic regardless of input order', () {
    final pts = [for (var i = 0; i < 6; i++) _p(i, 53.4285 + i * 0.0001, 14.5528)];
    final a = clusterPoints(pts, 14);
    final b = clusterPoints(pts.reversed.toList(), 14);
    expect([for (final c in a) [for (final p in c.members) p.id]], [for (final c in b) [for (final p in c.members) p.id]]);
  });

  test('label is 9+ for 12 and image exists', () {
    final pts = [for (var i = 0; i < 12; i++) _p(i, 53.4285, 14.5528)];
    final c = clusterPoints(pts, 12).single;
    expect(c.label, '9+');
    expect(allClusterStyles.map((s) => s.imageName), contains(c.imageName));
    expect(allClusterStyles, hasLength(18));
  });

  test('confirmed if any member is confirmed', () {
    final c = clusterPoints([_a, _p(2, 53.42876, 14.5528, confirmed: true)], 15).single;
    expect(c.anyConfirmed, isTrue);
    expect(c.imageName, endsWith('-c'));
  });

  test('hit test returns the cluster, misses far taps', () {
    final cl = clusterPoints([_a, _b], 15);
    expect(hitTestClusters(cl, 53.4286, 14.5528, 15), same(cl.single));
    expect(hitTestClusters(cl, 53.5, 14.6, 15), isNull);
  });

  test('camera: zoom to the level that splits the cluster, capped at 18', () {
    final pair = clusterPoints([_a, _b], 15).single; // 29 m apart
    final z = clusterSplitZoom(pair, 15)!;
    expect(z, greaterThan(15));
    expect(z, lessThanOrEqualTo(clusterMaxZoom));
    expect(clusterPoints([_a, _b], z), hasLength(2));
    expect(clusterPoints([_a, _b], z - 1), hasLength(1));
    expect(clusterCameraUpdate(pair, 15), isNotNull);
  });

  test('camera: members at one place never split -> null (open the sheet)', () {
    final same = clusterPoints([_p(1, 53.4, 14.5), _p(2, 53.4, 14.5)], 15).single;
    expect(clusterSplitZoom(same, 15), isNull);
    expect(clusterCameraUpdate(same, 15), isNull);
  });
}
