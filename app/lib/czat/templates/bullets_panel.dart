import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'panel_card.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// `bullets`: unordered list; `checkable` adds a checkbox per element and an
/// "{n} z {m}" counter in the header (DS BulletsPanel). Checked state is kept
/// in the message for now (profile `supplies.kit[]` sync comes later).
class BulletsPanelView extends StatelessWidget {
  const BulletsPanelView({super.key, required this.scope});

  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final panel = scope.panel as BulletsPanel;
    final done = scope.done;
    return PanelCard(
      title: panel.title,
      aside: panel.checkable
          ? Text(
              '${done.where((i) => i < panel.items.length).length} z ${panel.items.length}',
              style: t.caption.copyWith(color: t.ink300),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < panel.items.length; i++)
            _BulletRow(
              item: panel.items[i],
              source: scope.answer.source(panel.items[i].sourceId),
              checkable: panel.checkable,
              checked: done.contains(i),
              onChanged: (v) => scope.onDoneChanged(i, v),
              onOpenSource: scope.onOpenSource,
            ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.item,
    required this.source,
    required this.checkable,
    required this.checked,
    required this.onChanged,
    required this.onOpenSource,
  });

  final PanelItem item;
  final SourceRecord? source;
  final bool checkable;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final void Function(SourceRecord) onOpenSource;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 3, right: 15),
            child: DecoratedBox(
              decoration: BoxDecoration(color: t.ink200, shape: BoxShape.circle),
              child: const SizedBox(width: 6, height: 6),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.text,
                  style: t.chat.copyWith(color: checked ? t.ink300 : t.ink100),
                ),
                if (source != null)
                  SourceChip(source: source!, onTap: () => onOpenSource(source!)),
              ],
            ),
          ),
          if (checkable)
            BzCheck(value: checked, onChanged: onChanged, label: item.text),
        ],
      ),
    );
  }
}
