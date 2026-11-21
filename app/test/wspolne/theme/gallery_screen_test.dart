import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:bezpiecznik/wspolne/theme/gallery_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(loadBzFonts);

  test('gallery route path and debug guard', () {
    expect(galleryRoutePath, '/gallery');
    expect(kDebugMode, isTrue); // tests run in debug; screen is guarded on it
  });

  for (final size in const [Size(360, 800), Size(411, 914)]) {
    testWidgets(
      'gallery pumps without overflow at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(theme: buildBzTheme(), home: const GalleryScreen()),
          ),
        );
        expect(find.text('Typografia'), findsOneWidget);
        expect(find.text('display · 40/44 · w800'), findsOneWidget);
        expect(
          find.text('Zażółć gęślą jaźń. ĄĆĘŁŃÓŚŹŻ ąćęłńóśźż'),
          findsOneWidget,
        );

        // Scroll through the whole list so every lazily built row is laid out.
        final list = find.byType(Scrollable).first;
        for (var i = 0; i < 40; i++) {
          await tester.drag(list, const Offset(0, -300));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'step $i');
        }
        expect(find.text('Zadzwoń 112'), findsOneWidget);
        expect(find.text('radiusSm'), findsOneWidget);
      },
    );
  }

  testWidgets('gallery lists every colour with a hex value', (tester) async {
    tester.view.physicalSize = const Size(411, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildBzTheme(), home: const GalleryScreen()),
      ),
    );
    // The gallery's text fields are scrollables too: scroll the page itself.
    final page = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('paper-ink'), 500, scrollable: page);
    expect(find.text('#2B2722'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('#C9A66B66'), -200, scrollable: page);
    expect(find.text('#C9A66B66'), findsOneWidget);
  });

  testWidgets('Polish glyphs lay out with the bundled font (no tofu width)', (
    tester,
  ) async {
    TextPainter paint(String s, String family) => TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: family, fontSize: 40),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // With the real font loaded, each Polish letter has its own advance width.
    final widths = {
      for (final ch in 'ąćęłńóśźż'.split('')) ch: paint(ch, bzFontFamily).width,
    };
    for (final e in widths.entries) {
      final base = paint(e.key, 'NoSuchFamilyXyz').width;
      expect(e.value, isNot(equals(base)), reason: e.key);
    }
  });
}
