// Host-side render of the debug gallery to PNG (no emulator needed).
// Run through polish/tools/render.sh, which copies this file into app/test/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:bezpiecznik/wspolne/theme/gallery_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  final out = Platform.environment['POLISH_OUT']!;
  final scale = double.parse(Platform.environment['POLISH_SCALE'] ?? '1');

  testWidgets('render gallery', (tester) async {
    await tester.runAsync(() async {
      await _font(bzFontFamily, [
        for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
          'assets/fonts/AtkinsonHyperlegibleNext-$w.ttf',
      ]);
      await _font('packages/lucide_icons_flutter/Lucide', [Platform.environment['LUCIDE_TTF']!]);
    });
    const height = 6400.0;
    tester.view.physicalSize = const Size(390 * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildBzTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const GalleryScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
