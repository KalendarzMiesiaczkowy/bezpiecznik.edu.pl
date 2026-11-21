import 'package:bezpiecznik/ratunek/cards/verify_badge.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders "Do weryfikacji" with the app theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBzTheme(),
        home: const Scaffold(body: Center(child: VerifyBadge())),
      ),
    );
    expect(find.text('Do weryfikacji'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Do weryfikacji'));
    expect(text.style?.color, BzTokens.dark.signal);
  });

  testWidgets('renders in a bare MaterialApp without the token extension', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: VerifyBadge())),
      ),
    );
    expect(find.text('Do weryfikacji'), findsOneWidget);
  });

  testWidgets('exposes a semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBzTheme(),
        home: const Scaffold(body: Center(child: VerifyBadge())),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('do weryfikacji')), findsOneWidget);
    handle.dispose();
  });
}
