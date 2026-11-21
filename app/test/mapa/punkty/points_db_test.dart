import 'dart:io';

import 'package:bezpiecznik/mapa/punkty/geo.dart';
import 'package:bezpiecznik/mapa/punkty/points_db.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const _ddl = '''
CREATE TABLE points (
  id INTEGER PRIMARY KEY,
  kind TEXT NOT NULL, name TEXT, address TEXT,
  lat REAL NOT NULL, lon REAL NOT NULL, availability TEXT, open_24h INTEGER,
  source TEXT NOT NULL, verified_at TEXT NOT NULL, confirmed INTEGER NOT NULL);
CREATE VIRTUAL TABLE points_rtree USING rtree(id, min_lat, max_lat, min_lon, max_lon);
''';

void _add(Database db, int id, double lat, double lon, {String kind = 'shelter'}) {
  db.execute(
    "INSERT INTO points VALUES (?, ?, NULL, NULL, ?, ?, NULL, NULL, 'OpenStreetMap', '2026-11-19', 0)",
    [id, kind, lat, lon],
  );
  db.execute('INSERT INTO points_rtree VALUES (?,?,?,?,?)', [id, lat, lat, lon, lon]);
}

class _Bundle extends CachingAssetBundle {
  _Bundle(this.bytes);
  final List<int> bytes;
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(bytes));
}

void main() {
  late Database mem;
  setUp(() {
    mem = sqlite3.openInMemory()..execute(_ddl);
    _add(mem, 1, 53.4300, 14.5500); // close
    _add(mem, 2, 53.4400, 14.5600);
    _add(mem, 3, 53.5000, 14.6000);
    _add(mem, 4, 53.9000, 14.9000); // far
    _add(mem, 5, 53.4286, 14.5529, kind: 'hospital'); // wrong kind
  });
  tearDown(() => mem.close());

  test('bounds spans all points', () {
    final b = PointsDb(mem).bounds()!;
    expect(b.south, closeTo(53.4286, 1e-4)); // R*Tree stores float32
    expect(b.north, closeTo(53.9, 1e-4));
    expect(b.west, closeTo(14.55, 1e-4));
    expect(b.east, closeTo(14.9, 1e-4));
  });

  test('nearest returns 3 sorted by distance, widening the box', () {
    final r = PointsDb(mem).nearest(szczecinLat, szczecinLon);
    expect(r.map((e) => e.id), [1, 2, 3]);
    final d = r.map((e) => e.distanceM!).toList();
    expect(d, [...d]..sort());
    expect(d.first, closeTo(haversineM(szczecinLat, szczecinLon, 53.43, 14.55), 1e-6));
  });

  test('widening can reach a far point, kinds filter applies', () {
    final all = PointsDb(mem).nearest(szczecinLat, szczecinLon, n: 10);
    expect(all.map((e) => e.id), [1, 2, 3, 4]);
    final h = PointsDb(mem).nearest(szczecinLat, szczecinLon, kinds: ['hospital']);
    expect(h.map((e) => e.id), [5]);
  });

  test('box corner does not hide a closer point (exact sort after prefilter)', () {
    // Point B is inside the first box corner but farther than A outside it.
    final r = PointsDb(mem).nearest(53.43, 14.55, n: 2);
    expect(r.first.id, 1);
  });

  test('inBounds uses the rtree', () {
    final r = PointsDb(mem).inBounds(53.42, 14.54, 53.45, 14.57);
    expect(r.map((e) => e.id).toSet(), {1, 2});
  });

  test('install copies once and reopens read-only', () async {
    final dir = Directory.systemTemp.createTempSync('pts');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File('assets/generated/points.sqlite');
    if (!src.existsSync()) return;
    final bundle = _Bundle(src.readAsBytesSync());
    final f1 = await installPointsDb(bundle: bundle, baseDir: dir);
    final m1 = f1.lastModifiedSync();
    final f2 = await installPointsDb(bundle: bundle, baseDir: dir);
    expect(f2.lastModifiedSync(), m1);
    final db = PointsDb.openFile(f2);
    addTearDown(db.close);
    final r = db.nearest(szczecinLat, szczecinLon);
    expect(r.length, 3);
    final d = r.map((e) => e.distanceM!).toList();
    expect(d, [...d]..sort());
    expect(r.every((e) => !e.confirmed && e.source == 'OpenStreetMap'), isTrue);
  });

  test('region bounds: south of the voivodeship is inside, Warsaw outside', () {
    expect(isOutsideRegion(53.17, 15.42), isFalse); // Choszczno
    expect(isOutsideRegion(53.16, 14.88), isFalse); // Pyrzyce
    expect(isOutsideRegion(53.4285, 14.5528), isFalse); // Szczecin
    expect(isOutsideRegion(52.2297, 21.0122), isTrue); // Warszawa
    expect(isOutsideRegion(52.40, 16.92), isTrue); // Poznań
  });
}
