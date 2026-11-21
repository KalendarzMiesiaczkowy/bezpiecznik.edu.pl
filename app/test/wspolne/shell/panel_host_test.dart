import 'package:bezpiecznik/wspolne/shell/panel_host.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('bottom sheet top stays below status bar + SOS row and <= 92 %', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBzTheme(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(padding: const EdgeInsets.only(top: 24)),
          child: child!,
        ),
        home: PanelHost(
          open: true,
          edge: PanelEdge.bottom,
          onClose: () {},
          panelKey: const Key('p'),
          child: const SingleChildScrollView(child: SizedBox(height: 3000)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.byKey(const Key('p'))).dy;
    expect(top, greaterThanOrEqualTo(24 + 8 + 56 + 8));
    expect(top, greaterThanOrEqualTo(800 * 0.08 - 0.01));
  });
}
