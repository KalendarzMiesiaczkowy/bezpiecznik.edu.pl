import 'package:bezpiecznik/profil/profile_form.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'chips are 40 dp tall stadiums; add-medication aligns with headings',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildBzTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ProfileForm(
                initial: HouseholdProfile.empty,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      final chips = find.byType(BzChip);
      expect(chips, findsWidgets);
      for (final e in chips.evaluate()) {
        expect(tester.getSize(find.byWidget(e.widget)).height, 40);
      }
      final material = tester.widget<Material>(
        find.descendant(of: chips.first, matching: find.byType(Material)).first,
      );
      expect(material.shape, isA<StadiumBorder>());

      final headingX = tester.getTopLeft(find.text('Leki')).dx;
      final addLabelX = tester.getTopLeft(find.text('+ Dodaj lek')).dx;
      expect(addLabelX, closeTo(headingX, 0.5));
    },
  );
}
