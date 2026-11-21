import 'dart:convert';

import 'package:bezpiecznik/app_router.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_fixtures.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpApp(WidgetTester t, String fixture) => t.pumpWidget(
  ProviderScope(
    overrides: [templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults())],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      theme: buildBzTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TemplateRenderer(answer: AssistantAnswer.fromJson(jsonDecode(templateFixtures[fixture]!))),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('chip opens source sheet with title, page, text; Zamknij closes', (t) async {
    await pumpApp(t, 'steps');
    await t.tap(find.text('▸ Przykład, s. 22'));
    await t.pumpAndSettle();
    expect(find.text('Strona 22'), findsOneWidget);
    expect(find.text('Zamknij'), findsOneWidget);
    await t.tap(find.text('Zamknij'));
    await t.pumpAndSettle();
    expect(find.text('Strona 22'), findsNothing);
  });

  testWidgets('Powiększ in quote opens sheet with fragment text', (t) async {
    await pumpApp(t, 'quote');
    await t.tap(find.text('Powiększ'));
    await t.pumpAndSettle();
    expect(find.text('Strona 14'), findsOneWidget);
    expect(find.text('Dokument przykładowy (fixture)'), findsNWidgets(2));
    expect(find.textContaining('Przykładowy fragment źródła'), findsNWidgets(2));
  });
}
