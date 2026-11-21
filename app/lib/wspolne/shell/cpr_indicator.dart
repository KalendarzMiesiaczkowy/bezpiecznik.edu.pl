import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/bz_theme.dart';
import 'cpr_state.dart';

/// Top-centre pill `● RKO 03:42 · wróć` shown outside the chat while the CPR
/// instructor runs. Visibility is decided by `RootOverlay`; tap -> [onTap].
class CprIndicator extends ConsumerWidget {
  const CprIndicator({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bz = context.bz;
    final elapsed = ref.watch(cprProvider.select((s) => s.elapsed));
    final text = '● RKO ${formatCprElapsed(elapsed)} · wróć';
    return Semantics(
      container: true,
      button: true,
      label: text,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bz.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bz.sosTint,
                borderRadius: BorderRadius.circular(bz.radiusFull),
                border: Border.all(color: bz.line150),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bz.label.copyWith(color: bz.sosText),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
