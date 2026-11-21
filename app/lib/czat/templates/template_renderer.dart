import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ratunek/cards/verify_badge.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// Footer under every `rescue_card` message (spec "Teksty").
const String rescueCardFooterText = 'Ta instrukcja nie zastępuje połączenia z 112.';

/// Label above a message by origin (spec "Etykieta nad wiadomoscia"); null = none.
/// Intent answers (`intent` set) carry no label.
String? answerLabelFor(AnswerOrigin origin, [String? intent]) => switch (origin) {
  AnswerOrigin.rescueCard => 'Karta ratunkowa',
  AnswerOrigin.rules => intent == null ? 'Z twojego profilu' : null,
  AnswerOrigin.noAi => 'Tryb bez AI: fragmenty źródeł',
  AnswerOrigin.ai || AnswerOrigin.refusal => null,
};

/// Draws the panels of an [AssistantAnswer] through the [TemplateRegistry]:
/// optional label, `VerifyBadge` for drafted content, the templates in order
/// (unknown ones skipped) and the 112 footer for rescue cards.
///
/// Per-message state (variant, checked items) is changed through
/// [onChanged], which receives the updated answer (the owner stores it).
class TemplateRenderer extends ConsumerWidget {
  const TemplateRenderer({super.key, required this.answer, this.onChanged});

  final AssistantAnswer answer;
  final ValueChanged<AssistantAnswer>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.bz;
    final registry = ref.watch(templateRegistryProvider);
    final openSource = ref.watch(sourceOpenerProvider);

    // The first panel with variants draws the switch; all share one variant.
    int? switchIndex;
    List<VariantOption> options = const [];
    for (var i = 0; i < answer.panels.length; i++) {
      final o = answer.panels[i].variantOptions;
      if (o.isNotEmpty) {
        switchIndex = i;
        options = o;
        break;
      }
    }
    final variant = options.isEmpty
        ? null
        : (options.any((o) => o.id == answer.selectedVariant)
              ? answer.selectedVariant
              : options.first.id);

    final label = answerLabelFor(answer.origin, answer.intent);
    final children = <Widget>[];
    if (label != null || answer.verify) {
      children.add(
        Row(
          children: [
            if (label != null) Text(label, style: t.caption.copyWith(color: t.ink300)),
            if (label != null && answer.verify) SizedBox(width: t.space2),
            if (answer.verify) const VerifyBadge(),
          ],
        ),
      );
    }
    for (var i = 0; i < answer.panels.length; i++) {
      final panel = answer.panels[i];
      if (panel is UnknownPanel) continue;
      final builder = registry.builderFor(panel.type);
      if (builder == null) continue;
      final panelVariant = panel.variantOptions.isEmpty ? null : variant;
      final scope = PanelScope(
        panel: panel,
        index: i,
        answer: answer,
        variant: variant,
        showVariantSwitch: i == switchIndex,
        onVariantChanged: (id) => onChanged?.call(answer.copyWith(selectedVariant: id)),
        done: answer.doneFor(i, panelVariant),
        onDoneChanged: (item, value) =>
            onChanged?.call(answer.withDone(i, panelVariant, item, value)),
        onOpenSource: (s) => openSource(context, s),
      );
      children.add(KeyedSubtree(key: ValueKey('panel-$i-${panel.type}'), child: builder(context, scope)));
    }
    final note = answer.note;
    if (note != null && note.isNotEmpty) {
      children.add(Text(note, key: const Key('answer-note'), style: t.caption.copyWith(color: t.ink300)));
    }
    if (answer.origin == AnswerOrigin.rescueCard) {
      children.add(Text(rescueCardFooterText, style: t.caption.copyWith(color: t.ink300)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: t.space3),
          children[i],
        ],
      ],
    );
  }
}
