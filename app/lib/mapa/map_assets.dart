import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Asset key of the style template (placeholders, see `assets/map/README.md`).
const mapStyleAsset = 'assets/map/style.json';

/// Asset key of the bundled MBTiles (git-ignored, built by `tools/`).
const mapTilesAsset = 'assets/generated/zachodniopomorskie.mbtiles';

/// Prefix of the glyph PBF assets: `<prefix><Fontstack>/<range>.pbf`.
const mapGlyphsAssetPrefix = 'assets/map/glyphs/';

const mbtilesPlaceholder = '{MBTILES_PATH}';
const glyphsPlaceholder = '{GLYPHS_DIR}';

/// Bump when the bundled tiles or glyphs change: forces a fresh copy.
const mapAssetsVersion = 2;

const _markerName = '.installed.json';
const _chunkSize = 1024 * 1024;

/// Plain string substitution of both placeholders (README contract).
/// `{fontstack}` and `{range}` are MapLibre tokens and stay untouched.
String substituteStyle(
  String template, {
  required String mbtilesPath,
  required String glyphsDir,
}) {
  return template
      .replaceAll(mbtilesPlaceholder, mbtilesPath)
      .replaceAll(glyphsPlaceholder, glyphsDir);
}

/// Glyph PBF asset keys, sorted, taken from the asset manifest listing.
List<String> glyphAssetKeys(Iterable<String> allAssets) {
  final keys = allAssets
      .where((k) => k.startsWith(mapGlyphsAssetPrefix) && k.endsWith('.pbf'))
      .toList()
    ..sort();
  return keys;
}

/// Result of [MapAssetInstaller.install].
class MapAssets {
  const MapAssets({
    required this.styleJson,
    required this.stylePath,
    required this.mbtilesPath,
    required this.glyphsDir,
  });

  /// Final style JSON with absolute paths. Passed to
  /// `MapLibreMap(styleString: ...)`: maplibre_gl accepts the raw JSON text
  /// (see `MapLibreMap.styleString` docs, format 4).
  final String styleJson;

  /// Same JSON written to disk (format 3 of `styleString`, kept for debugging
  /// and for consumers that prefer a path).
  final String stylePath;
  final String mbtilesPath;
  final String glyphsDir;
}

/// Copy progress, 0..1.
typedef MapInstallProgress = void Function(double fraction);

/// First-run installer: copies the MBTiles and the glyph PBFs from the asset
/// bundle to `<support dir>/map/` (native MapLibre cannot read Flutter assets
/// for `mbtiles://` and, in maplibre_gl 0.28, not for glyphs either) and writes
/// the style with absolute paths.
///
/// Memory note: Flutter has no streaming asset API. `AssetBundle.load` returns
/// the whole file as one `ByteData`, so the 101 MB tiles file is resident once
/// during the copy (external memory, released right after). The write itself is
/// chunked (1 MiB) with event-loop yields so the UI stays responsive.
///
/// Skip logic: a marker file `.installed.json` written last (after an atomic
/// rename of the tiles file) holds [mapAssetsVersion], tiles size and glyph
/// count. On later runs only the cheap style rewrite happens.
class MapAssetInstaller {
  MapAssetInstaller({
    required this.bundle,
    required this.baseDir,
    required this.listAssets,
  });

  final AssetBundle bundle;

  /// Directory that will hold `map/` (support directory in production).
  final Directory baseDir;

  /// Returns every asset key (production: from `AssetManifest`).
  final Future<List<String>> Function() listAssets;

  Directory get mapDir => Directory(p.join(baseDir.path, 'map'));
  String get mbtilesPath => p.join(mapDir.path, p.basename(mapTilesAsset));
  String get glyphsDir => p.join(mapDir.path, 'glyphs');
  String get stylePath => p.join(mapDir.path, 'style.json');
  File get _marker => File(p.join(mapDir.path, _markerName));

  /// True when tiles and glyphs are already installed in this version.
  Future<bool> isInstalled() async {
    try {
      final marker = _marker;
      if (!await marker.exists()) return false;
      final json = jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
      if (json['version'] != mapAssetsVersion) return false;
      final tiles = File(mbtilesPath);
      if (!await tiles.exists() || await tiles.length() != json['tilesBytes']) {
        return false;
      }
      final glyphs = Directory(glyphsDir);
      if (!await glyphs.exists()) return false;
      var count = 0;
      await for (final e in glyphs.list(recursive: true)) {
        if (e is File && e.path.endsWith('.pbf')) count++;
      }
      return count == json['glyphCount'];
    } on Object {
      return false; // Corrupt marker: reinstall.
    }
  }

  Future<MapAssets> install({MapInstallProgress? onProgress}) async {
    if (!await isInstalled()) {
      await _copyAll(onProgress);
    }
    onProgress?.call(1);
    final template = await bundle.loadString(mapStyleAsset);
    final json = substituteStyle(template, mbtilesPath: mbtilesPath, glyphsDir: glyphsDir);
    await File(stylePath).writeAsString(json, flush: true);
    return MapAssets(
      styleJson: json,
      stylePath: stylePath,
      mbtilesPath: mbtilesPath,
      glyphsDir: glyphsDir,
    );
  }

  Future<void> _copyAll(MapInstallProgress? onProgress) async {
    final dir = mapDir;
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final glyphKeys = glyphAssetKeys(await listAssets());
    // Glyphs are tiny (~500 KB total); weight them as 2% of the progress.
    for (var i = 0; i < glyphKeys.length; i++) {
      final key = glyphKeys[i];
      final data = await bundle.load(key);
      final target = File(p.join(glyphsDir, key.substring(mapGlyphsAssetPrefix.length)));
      await target.parent.create(recursive: true);
      await target.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      onProgress?.call(0.02 * (i + 1) / glyphKeys.length);
    }

    final tilesBytes = await _copyTiles(onProgress);

    await _marker.writeAsString(
      jsonEncode({
        'version': mapAssetsVersion,
        'tilesBytes': tilesBytes,
        'glyphCount': glyphKeys.length,
      }),
      flush: true,
    );
  }

  Future<int> _copyTiles(MapInstallProgress? onProgress) async {
    final data = await bundle.load(mapTilesAsset);
    final total = data.lengthInBytes;
    final bytes = data.buffer.asUint8List(data.offsetInBytes, total);
    final part = File('$mbtilesPath.part');
    final raf = await part.open(mode: FileMode.write);
    try {
      for (var offset = 0; offset < total; offset += _chunkSize) {
        final end = offset + _chunkSize < total ? offset + _chunkSize : total;
        await raf.writeFrom(bytes, offset, end);
        onProgress?.call(0.02 + 0.98 * end / total);
      }
      await raf.flush();
    } finally {
      await raf.close();
    }
    await part.rename(mbtilesPath);
    return total;
  }
}

/// Production installer: support dir + manifest listing from the root bundle.
Future<MapAssetInstaller> createDefaultMapInstaller() async {
  final base = await getApplicationSupportDirectory();
  return MapAssetInstaller(
    bundle: rootBundle,
    baseDir: base,
    listAssets: () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets();
    },
  );
}
