import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'panel_card.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// Header shown when every step is checked (spec `steps` "Stany").
const String stepsAllDoneText = 'Wszystko zrobione';

/// `steps`: numbered, checkable steps with a source chip under each one.
/// The first unchecked step is the current one (bar + bold).
class StepsPanelView extends StatelessWidget {
  const StepsPanelView({super.key, required this.scope});

  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final panel = scope.panel as StepsPanel;
    final items = panel.itemsFor(scope.variant);
    final done = scope.done;
    final indexes = List.generate(items.length, (i) => i);
    final allDone = items.isNotEmpty && indexes.every(done.contains);
    final current = indexes.indexWhere((i) => !done.contains(i));

    return PanelCard(
      title: allDone ? '${panel.title}: $stepsAllDoneText' : panel.title,
      done: allDone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scope.showVariantSwitch && scope.variant != null) ...[
            BzSegmented(
              options: panel.variantOptions,
              value: scope.variant!,
              onChanged: scope.onVariantChanged,
            ),
            SizedBox(height: t.space2),
          ],
          for (var i = 0; i < items.length; i++)
            _StepRow(
              number: i + 1,
              item: items[i],
              source: scope.answer.source(items[i].sourceId),
              done: done.contains(i),
              current: i == current,
              onChanged: (v) => scope.onDoneChanged(i, v),
              onOpenSource: scope.onOpenSource,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.item,
    required this.source,
    required this.done,
    required this.current,
    required this.onChanged,
    required this.onOpenSource,
  });

  final int number;
  final PanelItem item;
  final SourceRecord? source;
  final bool done;
  final bool current;
  final ValueChanged<bool> onChanged;
  final void Function(SourceRecord) onOpenSource;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final numBg = done ? t.verifiedTint : (current ? t.signal : t.bg300);
    final numFg = done ? t.verified : (current ? t.signalInk : t.ink200);
    return Padding(
      padding: EdgeInsets.only(bottom: t.space1),
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: current ? t.overlayHover : null,
              borderRadius: BorderRadius.circular(t.radiusMd),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: t.space3, top: 10, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: numBg, shape: BoxShape.circle),
                    child: done
                        ? Icon(LucideIcons.check, size: 16, color: numFg)
                        : Text(
                            '$number',
                            style: t.label.copyWith(
                              color: numFg,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                  ),
                  SizedBox(width: t.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.text,
                          style: t.chat.copyWith(
                            height: 28 / 17,
                            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                            color: done ? t.ink300 : t.ink100,
                          ),
                        ),
                        if (source != null)
                          SourceChip(source: source!, onTap: () => onOpenSource(source!)),
                      ],
                    ),
                  ),
                  BzCheck(
                    value: done,
                    onChanged: onChanged,
                    label: 'Krok $number: ${item.text}',
                  ),
                ],
              ),
            ),
          ),
          if (current)
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              width: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.signal,
                  borderRadius: BorderRadius.circular(t.radiusFull),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
