import 'package:material_ui/material_ui.dart';

import '../../app_router.dart';
import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'panel_model.dart';

/// Default source opener: bottom sheet on the root navigator (below the SOS
/// overlay). MVP shows document, page and the fragment text; no PDF viewer.
void openSourceSheet(SourceRecord s) {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx == null) return;
  showSourceSheet(ctx, s);
}

Future<void> showSourceSheet(BuildContext context, SourceRecord s) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.bz.bg100,
      builder: (_) => SourceSheet(source: s),
    );

class SourceSheet extends StatelessWidget {
  const SourceSheet({super.key, required this.source});

  final SourceRecord source;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final s = source;
    final meta = [s.publisher, s.issued].where((e) => e.isNotEmpty).join(' · ');
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(bz.space4, 0, bz.space4, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.docTitle.isEmpty ? s.docShort : s.docTitle, style: bz.title),
              if (meta.isNotEmpty) Text(meta, style: bz.caption),
              if (s.pageLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Strona ${s.pageLabel}', style: bz.chat),
              ],
              if (s.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(child: Text(s.text, style: bz.chat)),
                ),
              ],
              const SizedBox(height: 16),
              BzButton(
                label: 'Zamknij',
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
