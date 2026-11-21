/// Access to the bundled knowledge SQLite (`assets/generated/kb.sqlite`).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

const String kbAssetPath = 'assets/generated/kb.sqlite';

/// Thin owner of an open read-only knowledge [CommonDatabase].
class KbDatabase {
  /// Wraps an already open database (tests, in-memory fixtures).
  KbDatabase(this.db);

  final CommonDatabase db;

  /// `meta.version` of the opened database (0 when missing).
  int get version {
    final r = db.select("SELECT value FROM meta WHERE key = 'version'");
    return r.isEmpty ? 0 : int.tryParse(r.first['value'] as String) ?? 0;
  }

  /// Copies the bundled asset to
  /// `<support dir>/kb/kb-<version>.sqlite` when that file is missing or its
  /// bytes differ from the bundle, then opens it read-only. Stale
  /// `kb-*.sqlite` files of other versions are removed.
  static Future<KbDatabase> openBundled({
    AssetBundle? bundle,
    Directory? supportDir,
    String assetPath = kbAssetPath,
  }) async {
    final data = await (bundle ?? rootBundle).load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final base = supportDir ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'kb'));
    await dir.create(recursive: true);

    final version = _versionOf(bytes, dir);
    final target = File(p.join(dir.path, 'kb-$version.sqlite'));
    if (!await _sameBytes(target, bytes)) {
      final tmp = File('${target.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(target.path);
    }
    await for (final e in dir.list()) {
      final name = p.basename(e.path);
      if (e is File &&
          name != p.basename(target.path) &&
          name.startsWith('kb-')) {
        await e.delete();
      }
    }
    final db = sqlite3.open(target.path, mode: OpenMode.readOnly);
    return KbDatabase(db);
  }

  /// Reads `meta.version` from the bundled [bytes] by materialising them in a
  /// scratch file inside [dir] (deleted afterwards).
  static int _versionOf(Uint8List bytes, Directory dir) {
    final probe = File(p.join(dir.path, 'probe.tmp'));
    probe.writeAsBytesSync(bytes, flush: true);
    try {
      final db = sqlite3.open(probe.path, mode: OpenMode.readOnly);
      try {
        final r = db.select("SELECT value FROM meta WHERE key = 'version'");
        return r.isEmpty ? 0 : int.tryParse(r.first['value'] as String) ?? 0;
      } finally {
        db.close();
      }
    } finally {
      probe.deleteSync();
    }
  }

  static Future<bool> _sameBytes(File f, Uint8List bytes) async {
    if (!await f.exists() || await f.length() != bytes.length) return false;
    final existing = await f.readAsBytes();
    for (var i = 0; i < bytes.length; i++) {
      if (existing[i] != bytes[i]) return false;
    }
    return true;
  }

  void close() => db.close();
}
