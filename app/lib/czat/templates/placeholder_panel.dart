import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';

/// Placeholder of a template owned by another task (call, cpr, map, signal,
/// animation): a bordered box with the type name. Replaced through
/// `TemplateRegistry.register`.
class PlaceholderPanelView extends StatelessWidget {
  const PlaceholderPanelView({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Container(
      key: ValueKey('placeholder-$type'),
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(
        border: Border.all(color: t.line200),
        borderRadius: BorderRadius.circular(t.radiusLg),
      ),
      child: Text(type, style: t.label.copyWith(color: t.ink200)),
    );
  }
}
