import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'panel_model.dart';

/// DS `PanelCard`: container of every template.
class PanelCard extends StatelessWidget {
  const PanelCard({super.key, this.title, this.aside, this.done = false, required this.child});

  final String? title;
  final Widget? aside;

  /// Verified-green header (all steps done).
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg100,
        border: Border.all(color: t.line100),
        borderRadius: BorderRadius.circular(t.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null && title!.isNotEmpty) ...[
              Row(
                children: [
                  if (done) ...[
                    Icon(LucideIcons.check, size: 18, color: t.verified),
                    SizedBox(width: t.space2),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: t.label.copyWith(
                        fontSize: 16,
                        height: 22 / 16,
                        fontWeight: FontWeight.w700,
                        color: done ? t.verified : t.ink100,
                      ),
                    ),
                  ),
                  ?aside,
                ],
              ),
              SizedBox(height: t.space3),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// DS `SourceChip`: book icon + `{doc_short}, s. {page_label}` in `verified`
/// on `verified-tint`. One line is a 28 dp pill; a long title wraps to more
/// lines instead of being cut, and "s. N" never breaks apart, so the page
/// number is always readable. The hit area is at least 48 dp high.
class SourceChip extends StatefulWidget {
  const SourceChip({super.key, required this.source, this.onTap});

  final SourceRecord source;
  final VoidCallback? onTap;

  @override
  State<SourceChip> createState() => _SourceChipState();
}

class _SourceChipState extends State<SourceChip> {
  bool _pressed = false;

  void _press(bool v) {
    if (widget.onTap != null && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final s = widget.source;
    return Semantics(
      button: true,
      label: s.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.minTouchTarget),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: AnimatedContainer(
              duration: t.durationFast,
              curve: t.easeInOut,
              constraints: const BoxConstraints(minHeight: 28),
              padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space1),
              decoration: BoxDecoration(
                color: _pressed ? Color.alphaBlend(t.overlayPress, t.verifiedTint) : t.verifiedTint,
                // radius-lg: a full pill on one line, a rounded box when wrapped.
                borderRadius: BorderRadius.circular(t.radiusLg),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.bookOpen, size: 16, color: t.verified),
                  SizedBox(width: t.space2),
                  Flexible(
                    child: Text(
                      // No-break space keeps "s. 33" on one line.
                      '${s.docShort}, s.\u00A0${s.pageLabel}',
                      style: t.source.copyWith(color: t.verified),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// DS `Checkbox`: 24 dp box, 44 dp+ hit area.
class BzCheck extends StatelessWidget {
  const BzCheck({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Semantics(
      checked: value,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: t.minTouchTarget,
          height: t.minTouchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: t.durationFast,
              curve: t.easeInOut,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? t.action : null,
                border: Border.all(color: value ? t.action : t.line200, width: 1.5),
                borderRadius: BorderRadius.circular(t.radiusSm),
              ),
              child: value ? Icon(LucideIcons.check, size: 16, color: t.onAction) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// DS `Segmented` (full width, max 3 options).
class BzSegmented extends StatelessWidget {
  const BzSegmented({super.key, required this.options, required this.value, required this.onChanged});

  final List<VariantOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.bg200,
        borderRadius: BorderRadius.circular(t.radiusFull),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: o.id == value,
                label: o.label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(o.id),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: t.minTouchTarget - 6),
                    child: Container(
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: o.id == value ? t.bg300 : null,
                        border: o.id == value ? Border.all(color: t.line150) : null,
                        borderRadius: BorderRadius.circular(t.radiusFull),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      // BG109: at large font scales the label shrinks to fit
                      // instead of ellipsizing ('Niemo…').
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          o.label,
                          maxLines: 1,
                          style: t.label.copyWith(color: o.id == value ? t.ink100 : t.ink200),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
