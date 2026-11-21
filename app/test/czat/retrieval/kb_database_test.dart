import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bezpiecznik/czat/retrieval/kb_database.dart';

class _FileBundle extends CachingAssetBundle {
  _FileBundle(this.path);
  final String path;
  @override
  Future<ByteData> load(String key) async {
    final b = File(path).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(b));
  }
}

void main() {
  final hasKb = File('assets/generated/kb.sqlite').existsSync();
  test(
    'openBundled copies to kb/kb-<version>.sqlite, reuses and replaces stale',
    () async {
      final dir = Directory('.dart_tool/kb_database_test')
        ..createSync(recursive: true);
      addTearDown(() => dir.deleteSync(recursive: true));
      final stale = File('${dir.path}/kb/kb-0.sqlite')
        ..createSync(recursive: true)
        ..writeAsStringSync('old');
      final bundle = _FileBundle('assets/generated/kb.sqlite');

      final kb = await KbDatabase.openBundled(bundle: bundle, supportDir: dir);
      expect(kb.version, 1);
      expect(File('${dir.path}/kb/kb-1.sqlite').existsSync(), isTrue);
      expect(stale.existsSync(), isFalse);
      expect(
        kb.db.select('SELECT count(*) AS n FROM chunks').first['n'],
        greaterThan(0),
      );
      kb.close();

      // Corrupt the copy: bytes differ -> overwritten on next open.
      File('${dir.path}/kb/kb-1.sqlite').writeAsBytesSync([1, 2, 3]);
      final kb2 = await KbDatabase.openBundled(bundle: bundle, supportDir: dir);
      expect(
        kb2.db.select('SELECT count(*) AS n FROM chunks').first['n'],
        greaterThan(0),
      );
      kb2.close();
    },
    skip: hasKb ? false : 'assets/generated/kb.sqlite missing',
  );
}
