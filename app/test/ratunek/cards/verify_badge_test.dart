import 'package:bezpiecznik/ratunek/cards/verify_badge.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  badgeScaleTest();
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

void badgeScaleTest() {
  testWidgets('badge at 2.0 text scale wraps in a Wrap without overflow', (tester) async {
    tester.view.physicalSize = const Size(412 * 2.625, 915 * 2.625);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(2.0)), child: w!),
        home: const Scaffold(
          body: Row(children: [Expanded(child: Text('Karta ratunkowa')), Flexible(child: VerifyBadge())]),
        ),
      ),
    );
    expect(find.text(verifyBadgeText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
