import 'package:lucide_icons_flutter/lucide_icons.dart';
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
          _QuoteWindow(text: source.text, onTap: () => scope.onOpenSource(source)),
          SizedBox(height: t.space2),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => scope.onOpenSource(source),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(t.minTouchTarget, t.minTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
                side: BorderSide(color: t.line150),
                foregroundColor: t.ink100,
                textStyle: t.label.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(LucideIcons.maximize2, size: 16),
              label: const Text(quoteExpandLabel),
            ),
          ),
        ],
      ),
    );
  }
}

const double _lineHeight = 22;
const double _padV = 18;
const double _padH = 20;
const int _maxLines = 8;

/// Collapsed window height: top padding plus a whole number of lines.
const double quoteWindowMaxHeight = _padV + _maxLines * _lineHeight;

/// Paper window with the highlighted fragment. Clipped to whole lines; the
/// fade into the paper only shows when the text is actually clipped.
class _QuoteWindow extends StatelessWidget {
  const _QuoteWindow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    const baseStyle = TextStyle(fontFamily: 'serif', fontSize: 14, height: _lineHeight / 14);
    return Semantics(
      label: text,
      excludeSemantics: true,
      button: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusMd),
          child: LayoutBuilder(
            builder: (context, box) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: baseStyle),
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: (box.maxWidth - 2 * _padH).clamp(0, double.infinity));
              final clipped = painter.height + _padV * 2 > quoteWindowMaxHeight;
              painter.dispose();
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: quoteWindowMaxHeight),
                child: Stack(
                  children: [
                    ColoredBox(
                      color: t.paper,
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: _padH, vertical: _padV),
                          child: Text.rich(
                            TextSpan(
                              text: text,
                              style: TextStyle(
                                backgroundColor: t.highlight,
                                decoration: TextDecoration.underline,
                                decorationColor: t.signalPress,
                                decorationThickness: 2,
                              ),
                            ),
                            style: baseStyle.copyWith(color: t.paperInk),
                          ),
                        ),
                      ),
                    ),
                    if (clipped)
                      Positioned(
                        key: const ValueKey('quote-fade'),
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 2 * _lineHeight,
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
              );
            },
          ),
        ),
      ),
    );
  }
}
