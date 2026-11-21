import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/mapa/map_assets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, List<int>> files;
  final loaded = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loaded.add(key);
    final data = files[key];
    if (data == null) throw FlutterError('missing asset $key');
    return ByteData.sublistView(Uint8List.fromList(data));
  }
}

class _FakeManifest implements AssetManifest {
  _FakeManifest(this.keys);

  final List<String> keys;

  @override
  List<String> listAssets() => keys;

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

const _template = '''
{"version":8,
 "sources":{"openmaptiles":{"type":"vector","url":"mbtiles://{MBTILES_PATH}"}},
 "glyphs":"file://{GLYPHS_DIR}/{fontstack}/{range}.pbf","layers":[]}
''';

void main() {
  late Directory base;

  setUp(() async {
    final root = Directory(p.join(Directory.current.path, '.dart_tool', 'test_tmp'));
    await root.create(recursive: true);
    base = await root.createTemp('map_assets_');
  });

  tearDown(() async {
    if (await base.exists()) await base.delete(recursive: true);
  });

  _FakeBundle bundle({int tilesLen = 3 * 1024 * 1024 + 17}) => _FakeBundle({
    mapStyleAsset: utf8.encode(_template),
    mapTilesAsset: List<int>.generate(tilesLen, (i) => i % 251),
    '${mapGlyphsAssetPrefix}Stack-Regular/0-255.pbf': [1, 2, 3],
    '${mapGlyphsAssetPrefix}Stack-Bold/0-255.pbf': [4, 5],
  });

  MapAssetInstaller installer(_FakeBundle b) => MapAssetInstaller(
    bundle: b,
    baseDir: base,
    listAssets: () async => [
      'assets/map/style.json',
      'assets/map/README.md',
      '${mapGlyphsAssetPrefix}Stack-Regular/0-255.pbf',
      '${mapGlyphsAssetPrefix}Stack-Bold/0-255.pbf',
      mapTilesAsset,
    ],
  );

  group('substituteStyle', () {
    test('replaces both placeholders and keeps MapLibre tokens', () {
      final out = substituteStyle(
        _template,
        mbtilesPath: '/data/user/0/app/files/map/t.mbtiles',
        glyphsDir: '/data/user/0/app/files/map/glyphs',
      );
      expect(out, isNot(contains(mbtilesPlaceholder)));
      expect(out, isNot(contains(glyphsPlaceholder)));
      expect(out, isNot(matches(RegExp('https?://'))));
      expect(out, contains('mbtiles:///data/user/0/app/files/map/t.mbtiles'));
      expect(out, contains('file:///data/user/0/app/files/map/glyphs/{fontstack}/{range}.pbf'));
      expect(jsonDecode(out), isA<Map<String, dynamic>>());
    });

    test('the real style template only uses the two known placeholders', () {
      final real = File('assets/map/style.json').readAsStringSync();
      final out = substituteStyle(real, mbtilesPath: '/a/b.mbtiles', glyphsDir: '/a/glyphs');
      expect(out, isNot(contains('{MBTILES_PATH}')));
      expect(out, isNot(contains('{GLYPHS_DIR}')));
      expect(RegExp('https?://').hasMatch(out), isFalse);
      final json = jsonDecode(out) as Map<String, dynamic>;
      expect(json['sources']['openmaptiles']['url'], 'mbtiles:///a/b.mbtiles');
      expect(json['glyphs'], 'file:///a/glyphs/{fontstack}/{range}.pbf');
    });
  });

  group('glyphAssetKeys', () {
    test('keeps only glyph pbfs, sorted', () {
      final keys = glyphAssetKeys(
        _FakeManifest([
          'assets/map/style.json',
          'assets/map/glyphs/B/0-255.pbf',
          'assets/map/glyphs/A/256-511.pbf',
          'assets/map/glyphs/A/0-255.pbf',
          'assets/map/glyphs/A/readme.txt',
          'assets/generated/x.mbtiles',
        ]).listAssets(),
      );
      expect(keys, [
        'assets/map/glyphs/A/0-255.pbf',
        'assets/map/glyphs/A/256-511.pbf',
        'assets/map/glyphs/B/0-255.pbf',
      ]);
    });
  });

  group('MapAssetInstaller', () {
    test('first run copies tiles and glyphs and writes the style', () async {
      final b = bundle();
      final fractions = <double>[];
      final inst = installer(b);
      expect(await inst.isInstalled(), isFalse);
      final res = await inst.install(onProgress: fractions.add);

      expect(await File(res.mbtilesPath).length(), 3 * 1024 * 1024 + 17);
      expect(
        await File(res.mbtilesPath).readAsBytes(),
        b.files[mapTilesAsset],
      );
      expect(
        await File(p.join(res.glyphsDir, 'Stack-Bold', '0-255.pbf')).readAsBytes(),
        [4, 5],
      );
      expect(File('${res.mbtilesPath}.part').existsSync(), isFalse);
      expect(p.isAbsolute(res.mbtilesPath), isTrue);
      expect(res.styleJson, contains('mbtiles://${res.mbtilesPath}'));
      expect(await File(res.stylePath).readAsString(), res.styleJson);
      expect(await inst.isInstalled(), isTrue);
      expect(fractions.last, 1);
      expect(fractions, orderedEquals([...fractions]..sort()));
      expect(fractions.length, greaterThan(4));
    });

    test('second run skips the copy (tiles not loaded again)', () async {
      await installer(bundle()).install();
      final b2 = bundle();
      final res = await installer(b2).install();
      expect(b2.loaded, [mapStyleAsset], reason: 'only the style is re-read');
      expect(res.styleJson, contains(res.mbtilesPath));
    });

    test('truncated tiles file triggers a reinstall', () async {
      final first = await installer(bundle()).install();
      await File(first.mbtilesPath).writeAsBytes([1, 2, 3]);
      final b = bundle();
      final inst = installer(b);
      expect(await inst.isInstalled(), isFalse);
      await inst.install();
      expect(await File(first.mbtilesPath).length(), 3 * 1024 * 1024 + 17);
    });

    test('version mismatch or corrupt marker triggers a reinstall', () async {
      final inst = installer(bundle());
      await inst.install();
      final marker = File(p.join(inst.mapDir.path, '.installed.json'));
      await marker.writeAsString('not json');
      expect(await inst.isInstalled(), isFalse);
      await marker.writeAsString(
        jsonEncode({'version': mapAssetsVersion + 1, 'tilesBytes': 1, 'glyphCount': 2}),
      );
      expect(await inst.isInstalled(), isFalse);
    });

    test('failed copy leaves no marker', () async {
      final b = bundle();
      b.files.remove(mapTilesAsset);
      final inst = installer(b);
      await expectLater(inst.install(), throwsA(isA<FlutterError>()));
      expect(await inst.isInstalled(), isFalse);
    });
  });

  group('bundled style and glyphs', () {
    final style = jsonDecode(File('assets/map/style.json').readAsStringSync())
        as Map<String, dynamic>;
    final glyphDirs = Directory('assets/map/glyphs')
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toSet();

    // First field of the first fontstack message of a glyph PBF (its name).
    String stackName(File f) {
      final b = f.readAsBytesSync();
      // 0x0A len (fontstack) | 0x0A len name ...
      expect(b[0], 0x0A);
      var i = 1;
      while (b[i] & 0x80 != 0) {
        i++;
      }
      i++;
      expect(b[i], 0x0A);
      final len = b[i + 1];
      return utf8.decode(b.sublist(i + 2, i + 2 + len));
    }

    test('every symbol layer has a text-field, visible, with bundled fonts', () {
      final symbols = (style['layers'] as List)
          .cast<Map<String, dynamic>>()
          .where((l) => l['type'] == 'symbol')
          .toList();
      expect(symbols, isNotEmpty);
      for (final l in symbols) {
        final layout = l['layout'] as Map<String, dynamic>;
        expect(layout['text-field'], isNotNull, reason: l['id'] as String);
        expect(layout['visibility'], isNot('none'), reason: l['id'] as String);
        for (final font in layout['text-font'] as List) {
          expect(glyphDirs, contains(font), reason: l['id'] as String);
        }
      }
    });

    test('glyph PBF fontstack name equals its directory name', () {
      for (final dir in glyphDirs) {
        final files = Directory('assets/map/glyphs/$dir').listSync().whereType<File>();
        expect(files, isNotEmpty);
        for (final f in files) {
          expect(stackName(f), dir, reason: f.path);
        }
      }
    });
  });
}
