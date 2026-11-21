import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../czat/ui/chat_controller.dart';
import 'rescue_answer.dart';

/// SMS `{opis}` for Panel 2: the name of the newest rescue card in the current
/// chat (e.g. "Utrata przytomności"), null when the chat has none or the cards
/// are not loaded.
final chatSituationProvider = Provider<String?>((ref) {
  final messages = ref.watch(chatControllerProvider.select((s) => s.messages));
  final cards = ref.watch(rescueAnswerServiceProvider).value?.cards;
  if (cards == null) return null;
  for (final m in messages.reversed) {
    final id = m.answer?.cardId;
    if (id != null) {
      final name = cards.card(id)?.name;
      if (name != null) return name;
    }
  }
  return null;
});

/// Name of rescue card [cardId] (the inline `call` template knows its card).
final rescueCardNameProvider = Provider.family<String?, String?>((ref, cardId) {
  if (cardId == null) return null;
  return ref.watch(rescueAnswerServiceProvider).value?.cards.card(cardId)?.name;
});
