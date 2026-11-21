import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/steps_panel.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:bezpiecznik/czat/templates/panel_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

SourceRecord _src(String id, String page) => SourceRecord(
  sourceId: id,
  docId: 'erc',
  docTitle: 'ERC 2025',
  docShort: 'ERC',
  pageLabel: page,
);

Future<void> _pump(WidgetTester tester, List<String> ids) async {
  final answer = AssistantAnswer(
    sources: {'a': _src('a', '67'), 'b': _src('b', '70')},
    panels: [
      StepsPanel(title: 'T', items: [for (final id in ids) PanelItem(text: 'krok $id', sourceId: id)]),
    ],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildBzTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: StepsPanelView(
            scope: PanelScope(
              panel: answer.panels.first,
              index: 0,
              answer: answer,
              variant: null,
              showVariantSwitch: false,
              onVariantChanged: (_) {},
              done: const {},
              onDoneChanged: (_, _) {},
              onOpenSource: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('same source on 3 steps -> one chip (first step)', (tester) async {
    await _pump(tester, ['a', 'a', 'a']);
    expect(find.text('ERC, s.\u00A067'), findsOneWidget);
  });

  testWidgets('A, A, B -> two chips; A, B, A -> three', (tester) async {
    await _pump(tester, ['a', 'a', 'b']);
    expect(find.text('ERC, s.\u00A067'), findsOneWidget);
    expect(find.text('ERC, s.\u00A070'), findsOneWidget);
    await _pump(tester, ['a', 'b', 'a']);
    expect(find.text('ERC, s.\u00A067'), findsNWidgets(2));
  });

  testWidgets('checkbox visual box centre aligns with number circle centre', (tester) async {
    await _pump(tester, ['a', 'a']);
    final circle = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints?.maxWidth == 28 &&
          w.constraints?.maxHeight == 28,
    );
    final box = find.descendant(
      of: find.byType(BzCheck),
      matching: find.byType(AnimatedContainer),
    );
    expect(circle, findsNWidgets(2));
    expect(box, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      final dy = tester.getCenter(box.at(i)).dy - tester.getCenter(circle.at(i)).dy;
      expect(dy.abs(), lessThanOrEqualTo(2));
    }
    // The hit area stays at least 48 dp tall.
    expect(tester.getSize(find.byType(BzCheck).first).height, greaterThanOrEqualTo(48));
  });
}
