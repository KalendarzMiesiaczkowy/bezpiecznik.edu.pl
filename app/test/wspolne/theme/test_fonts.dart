import 'dart:io';

import 'package:flutter/services.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';

/// Loads the bundled TTFs under [bzFontFamily] so tests render real glyphs even
/// before the `fonts:` block is in pubspec.yaml.
Future<void> loadBzFonts() async {
  final loader = FontLoader(bzFontFamily);
  for (final w in const [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ]) {
    final bytes = File('assets/fonts/AtkinsonHyperlegibleNext-$w.ttf')
        .readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
