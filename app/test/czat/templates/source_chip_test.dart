import 'package:bezpiecznik/czat/templates/panel_card.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const long = SourceRecord(
    sourceId: 's',
    docShort: 'Wytyczne ERC 2025, podstawowe zabiegi resuscytacyjne u dorosłych',
    pageLabel: '167',
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('long title wraps, the page number is never cut (font x$scale)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildBzTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: Center(
              child: SizedBox(width: 240, child: SourceChip(source: long)),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final label = find.textContaining('s. 167');
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.maxLines, isNull);
      expect(paragraph.size.height, greaterThan(18 * scale), reason: 'wrapped to 2+ lines');
      expect(tester.getSize(find.byType(SourceChip)).width, lessThanOrEqualTo(240));
      expect(tester.getSize(find.byType(SourceChip)).height, greaterThanOrEqualTo(48));
    });
  }

  testWidgets('BzSegmented: the whole 48 dp height is tappable', (tester) async {
    String value = 'tak';
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(
          body: Center(
            child: BzSegmented(
              options: const [VariantOption('tak', 'Tak'), VariantOption('nie', 'Nie')],
              value: value,
              onChanged: (v) => value = v,
            ),
          ),
        ),
      ),
    );
    final box = tester.getRect(find.byType(BzSegmented));
    expect(box.height, greaterThanOrEqualTo(48));
    await tester.tapAt(Offset(box.right - 40, box.top + 1));
    expect(value, 'nie');
  });
}
