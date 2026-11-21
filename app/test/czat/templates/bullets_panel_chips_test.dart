import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/bullets_panel.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
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
      BulletsPanel(title: 'T', items: [for (final id in ids) PanelItem(text: 'punkt $id', sourceId: id)]),
    ],
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildBzTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BulletsPanelView(
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
  testWidgets('bullets: same source on 3 items -> one chip (first item)', (tester) async {
    await _pump(tester, ['a', 'a', 'a']);
    expect(find.text('ERC, s.\u00A067'), findsOneWidget);
  });

  testWidgets('bullets: A, A, B -> two chips; A, B, A -> three', (tester) async {
    await _pump(tester, ['a', 'a', 'b']);
    expect(find.text('ERC, s.\u00A067'), findsOneWidget);
    expect(find.text('ERC, s.\u00A070'), findsOneWidget);
    await _pump(tester, ['a', 'b', 'a']);
    expect(find.text('ERC, s.\u00A067'), findsNWidgets(2));
  });
}
