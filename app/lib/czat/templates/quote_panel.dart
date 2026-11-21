import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_buttons.dart';
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
          QuotePaper(text: source.text, onTap: () => scope.onOpenSource(source)),
          SizedBox(height: t.space1),
          // Quiet 32 dp pill (48 dp hit area), reference czat-zrodlo.png.
          Align(
            alignment: Alignment.centerRight,
            child: BzButton(
              label: quoteExpandLabel,
              icon: LucideIcons.maximize2,
              size: BzButtonSize.sm,
              onPressed: () => scope.onOpenSource(source),
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

/// Paper window with the highlighted fragment. Collapsed (default): clipped
/// to whole lines, the fade into the paper only shows when the text is
/// actually clipped. [expanded] (source sheet): the whole fragment as a plain
/// page, since a mark over everything marks nothing.
class QuotePaper extends StatelessWidget {
  const QuotePaper({super.key, required this.text, this.onTap, this.expanded = false});

  final String text;
  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    const baseStyle = TextStyle(fontFamily: 'serif', fontSize: 14, height: _lineHeight / 14);
    return Semantics(
      label: text,
      excludeSemantics: true,
      button: onTap != null,
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
              final clipped = !expanded && painter.height + _padV * 2 > quoteWindowMaxHeight;
              painter.dispose();
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: expanded ? double.infinity : quoteWindowMaxHeight),
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
                              style: expanded ? null : TextStyle(
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
