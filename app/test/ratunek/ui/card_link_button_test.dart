import 'dart:io';

import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/templates/app_templates.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/czat/templates/template_renderer.dart';
import 'package:bezpiecznik/czat/ui/chat_controller.dart';
import 'package:bezpiecznik/ratunek/ui/rescue_answer.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  testWidgets('unconscious steps show "Nie oddycha → RKO"; tap inserts the RKO card', (tester) async {
    final service = (await tester.runAsync(() => RescueAnswerService.load(_FileBundle())))!;
    final store = ChatStore.inMemory();
    final answer = service.answerForCard('unconscious')!;
    final container = ProviderContainer(
      overrides: [
        rescueAnswerServiceProvider.overrideWith((_) => service),
        chatStoreProvider.overrideWithValue(store),
        templateRegistryProvider.overrideWithValue(buildAppTemplateRegistry()),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(rescueAnswerServiceProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildBzTheme(),
          home: Scaffold(body: SingleChildScrollView(child: TemplateRenderer(answer: answer))),
        ),
      ),
    );
    await tester.pump();

    final link = find.text('Nie oddycha → RKO');
    expect(link, findsWidgets);
    expect(container.read(chatControllerProvider).messages, isEmpty);
    await tester.ensureVisible(link.first);
    await tester.tap(link.first);
    await tester.pump();
    final msgs = container.read(chatControllerProvider).messages;
    expect(msgs, hasLength(1));
    expect(msgs.single.answer?.cardId, 'rko');
  });
}
