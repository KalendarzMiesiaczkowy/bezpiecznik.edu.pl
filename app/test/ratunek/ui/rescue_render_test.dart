import 'dart:io';

import 'package:bezpiecznik/czat/templates/call/call_panel_view.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
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
    final registry = TemplateRegistry.withDefaults();
    registerCallTemplate(registry);
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
    // Call panel is above the steps.
    expect(
      tester.getTopLeft(find.text(call112Label)).dy,
      lessThan(tester.getTopLeft(find.text('RKO')).dy),
    );
  });
}
