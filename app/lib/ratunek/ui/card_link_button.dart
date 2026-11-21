import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../czat/ui/chat_controller.dart';
import '../../wspolne/theme/bz_buttons.dart';
import 'rescue_answer.dart';

/// Step action from a card's `card_link` ("Nie oddycha → RKO"): inserts the
/// linked card as a new assistant message in the step's variant (karty-
/// ratunkowe.md). Hidden while the target card is not loaded.
class CardLinkButton extends ConsumerWidget {
  const CardLinkButton({super.key, required this.label, required this.cardId, this.variant});

  final String label;
  final String cardId;
  final String? variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(rescueAnswerServiceProvider).value;
    if (service == null || service.cards.card(cardId) == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: BzButton(
        key: ValueKey('card-link-$cardId'),
        label: label,
        variant: BzButtonVariant.ghost,
        size: BzButtonSize.md,
        onPressed: () {
          final answer = service.answerForCard(cardId, variant: variant);
          if (answer != null) ref.read(chatControllerProvider.notifier).insertAssistantAnswer(answer);
        },
      ),
    );
  }
}
