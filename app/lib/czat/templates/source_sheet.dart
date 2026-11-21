import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'panel_model.dart';
import 'quote_panel.dart';

/// Default source opener: bottom sheet pushed from the tapped widget's own
/// [context], like the Settings/map sheets, so it stays below the SOS overlay.
/// (`rootNavigatorKey.currentContext` is the Navigator's own context and put
/// the sheet outside the shell layering, hiding SOS.) MVP shows document,
/// page and the fragment text; no PDF viewer.
void openSourceSheet(BuildContext context, SourceRecord s) =>
    showSourceSheet(context, s);

Future<void> showSourceSheet(BuildContext context, SourceRecord s) =>
    showModalBottomSheet<void>(
      context: context,
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
          padding: EdgeInsets.fromLTRB(bz.space4, 0, bz.space4, bz.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Same hierarchy as the `quote` card (reference czat-zrodlo.png):
              // document, one quiet line of page and publisher, then the
              // fragment on paper.
              Text(
                s.docTitle.isEmpty ? s.docShort : s.docTitle,
                style: bz.step,
              ),
              SizedBox(height: bz.space1),
              Wrap(
                spacing: bz.space1,
                children: [
                  if (s.pageLabel.isNotEmpty)
                    Text(
                      'Strona ${s.pageLabel}',
                      style: bz.caption.copyWith(color: bz.ink200),
                    ),
                  if (meta.isNotEmpty)
                    Text(
                      s.pageLabel.isEmpty ? meta : '· $meta',
                      style: bz.caption.copyWith(color: bz.ink300),
                    ),
                ],
              ),
              if (s.text.isNotEmpty) ...[
                SizedBox(height: bz.space3),
                Flexible(
                  // The clip stays put while the page scrolls under it.
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(bz.radiusMd),
                    child: SingleChildScrollView(
                      child: QuotePaper(text: s.text, expanded: true),
                    ),
                  ),
                ),
              ],
              SizedBox(height: bz.space4),
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
