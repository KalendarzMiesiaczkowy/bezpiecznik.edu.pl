import 'package:bezpiecznik/czat/templates/chat_text.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('chat_text: plain text with the "not from the guides" label', (tester) async {
    final a = AssistantAnswer.fromJson({
      'origin': 'ai',
      'panels': [
        {'type': 'chat_text', 'text': 'Spokojnie, jestem tu.'},
      ],
    });
    expect(a.panels.single, isA<ChatTextPanel>());
    expect(AssistantAnswer.fromJson(a.toJson()).panels.single, isA<ChatTextPanel>());
    await tester.pumpWidget(ProviderScope(
      overrides: [templateRegistryProvider.overrideWithValue(TemplateRegistry.withDefaults())],
      child: MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(body: TemplateRenderer(answer: a)),
      ),
    ));
    expect(find.text(chatTextLabel), findsOneWidget);
    expect(find.text('Spokojnie, jestem tu.'), findsOneWidget);
  });
}
