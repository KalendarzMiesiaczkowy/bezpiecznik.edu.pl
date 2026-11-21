import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:bezpiecznik/wspolne/theme/gallery_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

/// Polish screenshots of the shared components: scrolls the debug gallery
/// section by section and prints `POLISH_SHOT <name>`;
/// `polish/tools/gallery-shots.sh` grabs `adb screencap` on each mark.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gallery', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildBzTheme(),
          home: const GalleryScreen(),
        ),
      ),
    );
    Future<void> linger(int ms) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Section titles, in gallery order; a section taller than the screen gets
    // a second shot one screen further down.
    const sections = {
      'Przyciski Material': 'material-shell',
      'Karta, źródło, wybór': 'cards',
      'Formularz': 'form',
      'Przyciski': 'buttons',
    };
    for (final e in sections.entries) {
      final title = find.text(e.key);
      await tester.scrollUntilVisible(title, 300, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(title), alignment: 0.02);
      await linger(1200);
      debugPrint('POLISH_SHOT gallery-${e.value}');
      await linger(2500);
    }
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -620));
    await linger(1200);
    debugPrint('POLISH_SHOT gallery-buttons-2');
    await linger(2500);
  });
}
