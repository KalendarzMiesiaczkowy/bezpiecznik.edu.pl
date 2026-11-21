import 'dart:io';

import 'package:bezpiecznik/czat/templates/app_templates.dart';
import 'package:bezpiecznik/czat/templates/call/call_panel_view.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/ratunek/cpr/cpr_view.dart' show cprStartLabel;
import 'package:bezpiecznik/ratunek/ui/rescue_answer.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  testWidgets('child CPR card renders call, badge, child steps, footer', (tester) async {
    final service = (await tester.runAsync(() => RescueAnswerService.load(_FileBundle())))!;
    final answer = (await service.tryAnswer('dziecko nie oddycha'))!;
    // The app registry: call, cpr (draws the variant switch now that it is
    // the first panel with variants), map, signal.
    final registry = buildAppTemplateRegistry();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [templateRegistryProvider.overrideWithValue(registry)],
        child: MaterialApp(
          theme: buildBzTheme(),
          home: Scaffold(
            body: SingleChildScrollView(child: TemplateRenderer(answer: answer)),
          ),
        ),
      ),
    );
    expect(find.text(call112Label), findsOneWidget);
    expect(find.text('Do weryfikacji'), findsOneWidget);
    expect(find.text('Karta ratunkowa'), findsOneWidget);
    expect(find.text(rescueCardFooterText), findsOneWidget);
    // Child variant is selected in the switch.
    expect(find.text('Dziecko'), findsWidgets);
    // Call panel, then the CPR instructor, then the steps (BG26).
    final call = tester.getTopLeft(find.text(call112Label)).dy;
    final start = tester.getTopLeft(find.text(cprStartLabel)).dy;
    final firstStep = tester.getTopLeft(find.textContaining('Zapewnij bezpieczeństwo')).dy;
    expect(call, lessThan(start));
    expect(start, lessThan(firstStep));
  });
}
