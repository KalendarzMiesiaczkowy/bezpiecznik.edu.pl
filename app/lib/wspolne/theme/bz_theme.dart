import 'package:material_ui/material_ui.dart';

import 'bz_tokens.g.dart';

export 'bz_tokens.g.dart';

/// Shorthand for the design tokens: `context.bz.ink100`.
extension BzContext on BuildContext {
  BzTokens get bz => Theme.of(this).extension<BzTokens>()!;
}

/// Dark Material 3 theme built from [BzTokens] (the only theme in the MVP).
ThemeData buildBzTheme({BzTokens tokens = BzTokens.dark}) {
  final t = tokens;
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: t.action,
    onPrimary: t.onAction,
    primaryContainer: t.signalTint,
    onPrimaryContainer: t.ink100,
    secondary: t.signal,
    onSecondary: t.signalInk,
    secondaryContainer: t.signalTint,
    onSecondaryContainer: t.signal,
    tertiary: t.verified,
    onTertiary: t.bg000,
    tertiaryContainer: t.verifiedTint,
    onTertiaryContainer: t.verified,
    error: t.danger,
    onError: t.bg000,
    errorContainer: t.sosTint,
    onErrorContainer: t.sosText,
    surface: t.bg000,
    onSurface: t.ink100,
    onSurfaceVariant: t.ink200,
    surfaceContainerLowest: t.bg000,
    surfaceContainerLow: t.bg100,
    surfaceContainer: t.bg100,
    surfaceContainerHigh: t.bg200,
    surfaceContainerHighest: t.bg300,
    outline: t.line200,
    outlineVariant: t.line150,
    shadow: const Color(0xFF000000),
    scrim: t.scrim,
    inverseSurface: t.ink100,
    onInverseSurface: t.bg000,
    inversePrimary: t.bg000,
  );

  // Material 3 type roles mapped to DS roles (labels use the DS `label` size).
  final textTheme = TextTheme(
    displayLarge: t.display,
    displayMedium: t.display,
    displaySmall: t.title,
    headlineLarge: t.title,
    headlineMedium: t.title,
    headlineSmall: t.step,
    titleLarge: t.title,
    titleMedium: t.step,
    titleSmall: t.label,
    bodyLarge: t.chat,
    bodyMedium: t.chat,
    bodySmall: t.caption,
    labelLarge: t.label,
    labelMedium: t.source,
    labelSmall: t.caption,
  ).apply(bodyColor: t.ink100, displayColor: t.ink100);

  const pill = StadiumBorder();
  final minSize = Size(t.minTouchTarget, t.minTouchTarget);
  final focusRing = BorderSide(color: t.signal, width: 2);

  // Pressed/hovered fills come from DS overlays, not ripples.
  Color? overlayFor(Set<WidgetState> s) {
    if (s.contains(WidgetState.pressed)) return t.overlayPress;
    if (s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)) {
      return t.overlayHover;
    }
    return null;
  }

  final textButtonShape = WidgetStateProperty.all<OutlinedBorder>(pill);

  ButtonStyle baseButton({
    required WidgetStateProperty<Color?> bg,
    required WidgetStateProperty<Color?> fg,
    WidgetStateProperty<BorderSide?>? side,
  }) {
    return ButtonStyle(
      minimumSize: WidgetStateProperty.all(minSize),
      tapTargetSize: MaterialTapTargetSize.padded,
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(horizontal: t.space5, vertical: t.space2),
      ),
      shape: textButtonShape,
      textStyle: WidgetStateProperty.all(t.label.copyWith(fontSize: 15)),
      backgroundColor: bg,
      foregroundColor: fg,
      surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
      elevation: WidgetStateProperty.all(0),
      overlayColor: WidgetStateProperty.resolveWith(overlayFor),
      side: side,
      splashFactory: NoSplash.splashFactory,
      iconSize: WidgetStateProperty.all(20),
    );
  }

  WidgetStateProperty<Color?> disabledAware(Color enabled, [Color? pressed]) {
    return WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.disabled)) {
        return enabled.withValues(alpha: 0.38);
      }
      if (pressed != null &&
          (s.contains(WidgetState.pressed) ||
              s.contains(WidgetState.hovered))) {
        return pressed;
      }
      return enabled;
    });
  }

  WidgetStateProperty<BorderSide?> outline(Color color) =>
      WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.focused)) return focusRing;
        return BorderSide(
          color: s.contains(WidgetState.disabled)
              ? color.withValues(alpha: 0.38)
              : color,
        );
      });

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(t.radiusMd),
    borderSide: BorderSide(color: t.line200),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: bzFontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg000,
    canvasColor: t.bg000,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[t],
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: t.overlayPress,
    hoverColor: t.overlayHover,
    focusColor: t.overlayHover,
    dividerColor: t.line100,
    dividerTheme: DividerThemeData(color: t.line100, thickness: 1, space: 1),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg000,
      foregroundColor: t.ink100,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: t.title.copyWith(color: t.ink100),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          baseButton(
            bg: disabledAware(t.action, t.actionPress),
            fg: disabledAware(t.onAction),
            side: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.focused) ? focusRing : BorderSide.none,
            ),
          ).copyWith(
            // Primary hover is a solid colour (action-press), not an overlay.
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: baseButton(
        bg: WidgetStateProperty.all(Colors.transparent),
        fg: disabledAware(t.ink100),
        side: outline(t.line150),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: baseButton(
        bg: WidgetStateProperty.all(Colors.transparent),
        fg: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) {
            return t.ink200.withValues(alpha: 0.38);
          }
          return s.contains(WidgetState.pressed) ||
                  s.contains(WidgetState.hovered)
              ? t.ink100
              : t.ink200;
        }),
        side: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.focused) ? focusRing : BorderSide.none,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(minSize),
        fixedSize: WidgetStateProperty.all(minSize),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: WidgetStateProperty.all(const CircleBorder()),
        iconSize: WidgetStateProperty.all(24),
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) {
            return t.ink200.withValues(alpha: 0.38);
          }
          return s.contains(WidgetState.pressed) ||
                  s.contains(WidgetState.hovered)
              ? t.ink100
              : t.ink200;
        }),
        overlayColor: WidgetStateProperty.resolveWith(overlayFor),
        splashFactory: NoSplash.splashFactory,
        side: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.focused) ? focusRing : BorderSide.none,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: t.bg100,
      constraints: BoxConstraints(minHeight: t.minTouchTarget),
      contentPadding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
      labelStyle: t.label.copyWith(color: t.ink200),
      floatingLabelStyle: t.label.copyWith(color: t.ink200),
      // Same size as the typed text (bodyLarge = chat), so nothing jumps.
      hintStyle: t.chat.copyWith(color: t.ink300),
      helperStyle: t.caption.copyWith(color: t.ink300),
      errorStyle: t.caption.copyWith(color: t.danger),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      disabledBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: t.line200.withValues(alpha: 0.38)),
      ),
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: t.ink200, width: 2),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: t.danger),
      ),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: t.danger, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.ink100,
      selectionColor: t.highlight,
      selectionHandleColor: t.signal,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.bg100,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: t.bg100,
      modalBarrierColor: t.scrim,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: t.line200,
      dragHandleSize: const Size(36, 5),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: t.line150),
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusXl)),
      ),
      constraints: const BoxConstraints(),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.bg200,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      barrierColor: t.scrim,
      titleTextStyle: t.step.copyWith(fontSize: 18, height: 24 / 18),
      contentTextStyle: t.chat.copyWith(
        fontSize: 15,
        height: 22 / 15,
        color: t.ink200,
      ),
      insetPadding: EdgeInsets.all(t.space4),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: t.line150),
        borderRadius: BorderRadius.circular(t.radiusLg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.bg300,
      contentTextStyle: t.label.copyWith(
        fontWeight: FontWeight.w400,
        color: t.ink100,
      ),
      actionTextColor: t.ink100,
      disabledActionTextColor: t.ink200,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: EdgeInsets.all(t.space4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
    ),
    switchTheme: SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      // DS Switch: monochrome. On = action track + dark knob; off = bg-300 + ink-200 knob.
      trackColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        final c = on ? t.action : t.bg300;
        return s.contains(WidgetState.disabled) ? c.withValues(alpha: 0.38) : c;
      }),
      thumbColor: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        final c = on ? t.bg000 : t.ink200;
        return s.contains(WidgetState.disabled) ? c.withValues(alpha: 0.38) : c;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused) ? t.signal : Colors.transparent,
      ),
      trackOutlineWidth: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused) ? 2.0 : 0.0,
      ),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashRadius: 0,
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: 56,
      contentPadding: EdgeInsets.symmetric(horizontal: t.space4),
      iconColor: t.ink200,
      textColor: t.ink100,
      titleTextStyle: t.chat.copyWith(fontSize: 16, height: 22 / 16),
      subtitleTextStyle: t.caption.copyWith(color: t.ink300),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
      selectedTileColor: t.bg300,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.ink100,
      linearTrackColor: t.bg300,
      circularTrackColor: Colors.transparent,
    ),
    checkboxTheme: CheckboxThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.action : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(t.onAction),
      side: BorderSide(color: t.line200, width: 2),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: t.bg300,
        borderRadius: BorderRadius.circular(t.radiusSm),
      ),
      textStyle: t.caption.copyWith(color: t.ink100),
    ),
  );
}
