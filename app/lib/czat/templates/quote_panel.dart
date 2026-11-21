import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'panel_card.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// Label of the "enlarge" action (opens the PDF preview, post-MVP).
const String quoteExpandLabel = 'Powiększ';

/// `quote`: original source fragment on a paper window (max 200 dp) with the
/// highlight token, document name and page. Text mode: the page image is not
/// available yet, so the fragment text is shown highlighted.
class QuotePanelView extends StatelessWidget {
  const QuotePanelView({super.key, required this.scope});

  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final panel = scope.panel as QuotePanel;
    final source = scope.answer.source(panel.sourceId);
    if (source == null) return const SizedBox.shrink();
    final meta = [
      's. ${source.pageLabel}',
      [source.publisher, source.issued].where((e) => e.isNotEmpty).join(' '),
    ].where((e) => e.isNotEmpty).join(' · ');

    return PanelCard(
      title: panel.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(source.docTitle, style: t.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
          Text(meta, style: t.caption.copyWith(color: t.ink300)),
          SizedBox(height: t.space3),
          Semantics(
            label: source.text,
            excludeSemantics: true,
            button: true,
            onTap: () => scope.onOpenSource(source),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => scope.onOpenSource(source),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radiusMd),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: Stack(
                    children: [
                      ColoredBox(
                        color: t.paper,
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            child: Text.rich(
                              TextSpan(
                                text: source.text,
                                style: TextStyle(
                                  backgroundColor: t.highlight,
                                  decoration: TextDecoration.underline,
                                  decorationColor: t.signalPress,
                                  decorationThickness: 2,
                                ),
                              ),
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 14,
                                height: 22 / 14,
                                color: t.paperInk,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 32,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [t.paper.withValues(alpha: 0), t.paper],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => scope.onOpenSource(source),
              child: const Text(quoteExpandLabel),
            ),
          ),
        ],
      ),
    );
  }
}
