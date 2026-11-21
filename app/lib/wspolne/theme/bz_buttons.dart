import 'package:material_ui/material_ui.dart';

import 'bz_theme.dart';

/// Button variants, mirroring components/Button in the design system.
enum BzButtonVariant {
  /// Light `action` fill. One per screen.
  primary,

  /// Transparent with a `line-150` border (default).
  secondary,

  /// No fill, no border; `ink-200` text.
  ghost,

  /// Destructive actions: `danger` text, `line-150` border.
  danger,

  /// Destructive, filled with `danger`.
  dangerSolid,

  /// Only for "Zadzwon 112".
  sos,
}

/// Visual sizes (DS: sm 32, md 36, lg 44, xl 56). The hit area is always at
/// least [BzTokens.minTouchTarget] (48 dp), also for the small visuals.
enum BzButtonSize {
  sm(32, 12, 13, 16, 4),
  md(36, 14, 14, 20, 8),
  lg(44, 18, 15, 20, 8),
  xl(56, 20, 16, 20, 10);

  const BzButtonSize(
    this.height,
    this.hPadding,
    this.fontSize,
    this.iconSize,
    this.gap,
  );

  final double height;
  final double hPadding;
  final double fontSize;
  final double iconSize;
  final double gap;
}

/// Design-system button: pill with a label, circle when it has only an icon.
class BzButton extends StatefulWidget {
  const BzButton({
    super.key,
    this.label,
    this.sub,
    this.icon,
    this.iconRight,
    this.onPressed,
    this.variant = BzButtonVariant.secondary,
    this.size = BzButtonSize.md,
    this.loading = false,
    this.fullWidth = false,
    this.semanticLabel,
  }) : assert(
         label != null || semanticLabel != null,
         'An icon-only BzButton needs a semanticLabel.',
       );

  final String? label;

  /// Second line under the label (e.g. "Numer alarmowy").
  final String? sub;
  final IconData? icon;
  final IconData? iconRight;

  /// Null disables the button (38% opacity).
  final VoidCallback? onPressed;
  final BzButtonVariant variant;
  final BzButtonSize size;
  final bool loading;
  final bool fullWidth;
  final String? semanticLabel;

  @override
  State<BzButton> createState() => _BzButtonState();
}

class _BzButtonState extends State<BzButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _activate() {
    if (_enabled) widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final v = widget.variant;
    final sz = widget.size;
    final active = _pressed || _hovered;

    Color? fill;
    Color fg;
    Color? border;
    switch (v) {
      case BzButtonVariant.primary:
        fill = active ? t.actionPress : t.action;
        fg = t.onAction;
      case BzButtonVariant.secondary:
        fill = _pressed
            ? t.overlayPress
            : _hovered
            ? t.overlayHover
            : null;
        fg = t.ink100;
        border = t.line150;
      case BzButtonVariant.ghost:
        fill = _pressed
            ? t.overlayPress
            : _hovered
            ? t.overlayHover
            : null;
        fg = active ? t.ink100 : t.ink200;
      case BzButtonVariant.danger:
        fill = _pressed
            ? t.overlayPress
            : _hovered
            ? t.overlayHover
            : null;
        fg = t.danger;
        border = t.line150;
      case BzButtonVariant.dangerSolid:
        fill = t.danger;
        fg = t.bg000;
      case BzButtonVariant.sos:
        fill = _pressed
            ? Color.alphaBlend(t.overlayPress, t.sos)
            : _hovered
            ? Color.alphaBlend(t.overlayHover, t.sos)
            : t.sos;
        fg = t.onSos;
    }

    final iconOnly = widget.label == null;
    final stacked = widget.sub != null;
    final labelStyle = t.label.copyWith(
      fontSize: sz.fontSize,
      height: stacked ? 1.15 : null,
      color: fg,
    );

    Widget leading() {
      if (widget.loading) {
        return SizedBox(
          width: sz.iconSize,
          height: sz.iconSize,
          child: CircularProgressIndicator(strokeWidth: 2, color: fg),
        );
      }
      return Icon(widget.icon, size: sz.iconSize, color: fg);
    }

    final children = <Widget>[
      if (widget.icon != null || widget.loading) leading(),
      if (!iconOnly) ...[
        if (widget.icon != null || widget.loading) SizedBox(width: sz.gap),
        Flexible(
          child: stacked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: widget.fullWidth
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label!,
                      style: labelStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.sub!,
                      style: t.caption.copyWith(
                        color: fg.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Text(
                  widget.label!,
                  style: labelStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
        ),
      ],
      if (widget.iconRight != null) ...[
        SizedBox(width: sz.gap),
        Icon(widget.iconRight, size: sz.iconSize, color: fg),
      ],
    ];

    final visualHeight = stacked
        ? (sz == BzButtonSize.xl ? 72.0 : 56.0)
        : sz.height;
    final side = border == null ? BorderSide.none : BorderSide(color: border);
    final decoration = ShapeDecoration(
      color: fill,
      shape: iconOnly ? CircleBorder(side: side) : StadiumBorder(side: side),
    );

    Widget visual = AnimatedContainer(
      duration: t.durationFast,
      curve: t.easeInOut,
      height: visualHeight,
      width: iconOnly ? visualHeight : null,
      padding: iconOnly
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(horizontal: sz.hPadding),
      decoration: decoration,
      foregroundDecoration: _focused
          ? ShapeDecoration(
              shape: iconOnly
                  ? CircleBorder(side: BorderSide(color: t.signal, width: 2))
                  : StadiumBorder(side: BorderSide(color: t.signal, width: 2)),
            )
          : null,
      child: Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );

    visual = Opacity(
      opacity: _enabled || widget.loading ? 1 : 0.38,
      child: visual,
    );

    // The hit area is padded up to the minimum touch target around the visual.
    final hit = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: t.minTouchTarget,
        minHeight: t.minTouchTarget,
      ),
      child: Center(
        widthFactor: widget.fullWidth ? null : 1,
        heightFactor: 1,
        child: visual,
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: FocusableActionDetector(
        enabled: _enabled,
        onShowHoverHighlight: (h) => setState(() => _hovered = h),
        onShowFocusHighlight: (f) => setState(() => _focused = f),
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTap: _enabled ? _activate : null,
          child: hit,
        ),
      ),
    );
  }
}
