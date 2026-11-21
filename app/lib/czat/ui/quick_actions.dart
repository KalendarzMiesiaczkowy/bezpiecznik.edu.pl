import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';

class QuickAction {
  const QuickAction(this.label, this.icon, {this.urgent = false});

  final String label;
  final IconData icon;

  /// Only "Ktoś nie oddycha" (icon in `sos-text`).
  final bool urgent;
}

/// Default set (spec ekran-1-czat.md "Szybkie przyciski"; "do potwierdzenia").
const List<QuickAction> defaultQuickActions = [
  QuickAction('Ktoś nie oddycha', LucideIcons.heartPulse, urgent: true),
  QuickAction('Brak prądu', LucideIcons.zapOff),
  QuickAction('Alarm / schron', LucideIcons.siren),
  QuickAction('Ewakuacja', LucideIcons.backpack),
];

/// DS `QuickActions`: 2 x 2 grid, tiles at least 88 dp high (spec: >= 64 dp).
/// A tap sends the label as the user's message.
class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.onSend,
    this.actions = defaultQuickActions,
  });

  final ValueChanged<String> onSend;
  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final rows = <Widget>[];
    for (var i = 0; i < actions.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : t.space2),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Tile(action: actions[i], onTap: () => onSend(actions[i].label))),
                SizedBox(width: t.space2),
                Expanded(
                  child: i + 1 < actions.length
                      ? _Tile(
                          action: actions[i + 1],
                          onTap: () => onSend(actions[i + 1].label),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _Tile extends StatefulWidget {
  const _Tile({required this.action, required this.onTap});

  final QuickAction action;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final a = widget.action;
    return Semantics(
      button: true,
      label: a.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _pressed ? t.overlayPress : null,
            border: Border.all(color: t.line150),
            borderRadius: BorderRadius.circular(t.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(a.icon, size: 22, color: a.urgent ? t.sosText : t.ink200),
              SizedBox(height: t.space3),
              Text(
                a.label,
                style: t.chat.copyWith(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
