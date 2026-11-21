import 'package:bezpiecznik/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Shell E2E: opens every screen and goes back with the in-app Back button.
/// Run: `flutter test integration_test/shell_test.dart -d emulator-5554`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navigate to every screen and back', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BezpiecznikApp()));
    await tester.pumpAndSettle();

    final menu = find.bySemanticsLabel('Menu');
    final map = find.bySemanticsLabel('Mapa');
    final back = find.bySemanticsLabel('Wróć');
    final sos = find.bySemanticsLabel(
      'SOS, kontakt ze służbami. Przytrzymaj, aby zadzwonić pod 112.',
    );

    // E1 chat: island, no Back, SOS.
    expect(find.text('Czat'), findsOneWidget);
    expect(menu, findsOneWidget);
    expect(back, findsNothing);
    expect(sos, findsOneWidget);

    // E2 via the island map button, then back.
    await tester.tap(map);
    await tester.pumpAndSettle();
    expect(find.text('Mapa'), findsOneWidget);
    expect(back, findsOneWidget);
    expect(sos, findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('Czat'), findsOneWidget);

    // E3 via the drawer settings icon, E4 via the "Profil" button.
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Panel boczny'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Ustawienia'));
    await tester.pumpAndSettle();
    expect(find.text('Ustawienia'), findsWidgets);
    expect(find.text('Panel boczny'), findsNothing);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(back, findsOneWidget);
    await tester.tap(back); // E4 -> E3
    await tester.pumpAndSettle();
    await tester.tap(back); // E3 -> E1
    await tester.pumpAndSettle();
    expect(find.text('Czat'), findsOneWidget);
    expect(menu, findsOneWidget);

    // P2 via SOS tap, closed with its close button.
    await tester.tap(sos);
    await tester.pumpAndSettle();
    expect(find.text('Kontakt ze służbami'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Zamknij'));
    await tester.pumpAndSettle();
    expect(find.text('Kontakt ze służbami'), findsNothing);
  
    // System Back with P1 open on E1 closes P1 and keeps E1 (not the app).
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Panel boczny'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Panel boczny'), findsNothing);
    expect(find.text('Czat'), findsOneWidget);

    // Same for P2 opened on E1.
    await tester.tap(sos);
    await tester.pumpAndSettle();
    expect(find.text('Kontakt ze służbami'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Kontakt ze służbami'), findsNothing);
    expect(find.text('Czat'), findsOneWidget);
  });
}
