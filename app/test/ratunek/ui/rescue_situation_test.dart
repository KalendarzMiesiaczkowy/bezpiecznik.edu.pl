import 'dart:io';

import 'package:bezpiecznik/czat/data/chat_store.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/chat_controller.dart';
import 'package:bezpiecznik/ratunek/ui/rescue_answer.dart';
import 'package:bezpiecznik/ratunek/ui/rescue_situation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chatSituationProvider: newest rescue card name in the chat, null without one', () async {
    final service = await RescueAnswerService.load(_FileBundle());
    final store = ChatStore.inMemory();
    addTearDown(store.close);
    final c = ProviderContainer(
      overrides: [
        rescueAnswerServiceProvider.overrideWith((_) => service),
        chatStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(c.dispose);
    await c.read(rescueAnswerServiceProvider.future);

    expect(c.read(chatSituationProvider), isNull);
    final ctl = c.read(chatControllerProvider.notifier);
    ctl.insertAssistantAnswer(const AssistantAnswer());
    expect(c.read(chatSituationProvider), isNull);
    ctl.insertAssistantAnswer(service.answerForCard('unconscious')!);
    expect(c.read(chatSituationProvider), 'Utrata przytomności');
    ctl.insertAssistantAnswer(service.answerForCard('rko')!);
    expect(c.read(chatSituationProvider), service.cards.card('rko')!.name);
    expect(c.read(rescueCardNameProvider('unconscious')), 'Utrata przytomności');
  });
}
