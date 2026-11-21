import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_tokens.g.dart';

/// Text of the badge shown on every `verify: true` rescue card.
const String verifyBadgeText = 'Do weryfikacji';

/// Warning-style badge "Do weryfikacji". Owner decision: cards that are not
/// signed off by a human appear in the demo with this badge.
///
/// Colours come from the `BzTokens` theme extension (`signal` family, the
/// amber warning colour); without the extension the plain Material scheme is
/// used, so the badge also renders in a bare `MaterialApp`.
class VerifyBadge extends StatelessWidget {
  const VerifyBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<BzTokens>();
    // Pill (ref): amber icon carries the warning, the text stays high-contrast.
    final icon = tokens?.signal ?? theme.colorScheme.tertiary;
    final fg = tokens?.ink100 ?? theme.colorScheme.onTertiaryContainer;
    final bg = tokens?.signalTint ?? theme.colorScheme.tertiaryContainer;
    final radius = tokens?.radiusFull ?? 9999.0;
    final padH = tokens?.space3 ?? 12.0;
    final padV = tokens?.space1 ?? 4.0;
    return Semantics(
      label: 'Treść do weryfikacji przez ratownika. Nie została jeszcze sprawdzona.',
      container: true,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(LucideIcons.triangleAlert, size: 16, color: icon),
              SizedBox(width: padV + 2),
              Flexible(
                child: Text(
                  verifyBadgeText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
