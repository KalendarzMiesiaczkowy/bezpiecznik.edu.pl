// GENERATED — do not edit, run tools/gen_tokens.py
// Source: bezpiecznik/08-design-system/tokens.json
// ignore_for_file: type=lint

import 'package:material_ui/material_ui.dart';

/// Font family registered in pubspec (see app/assets/fonts/README.md).
const String bzFontFamily = "Atkinson Hyperlegible Next";

/// Design tokens as a [ThemeExtension]. Read via `context.bz` (bz_theme.dart).
@immutable
class BzTokens extends ThemeExtension<BzTokens> {
  const BzTokens({
    required this.bg000,
    required this.bg100,
    required this.bg200,
    required this.bg300,
    required this.line100,
    required this.line150,
    required this.line200,
    required this.ink100,
    required this.ink200,
    required this.ink300,
    required this.overlayHover,
    required this.overlayPress,
    required this.action,
    required this.actionPress,
    required this.onAction,
    required this.signal,
    required this.signalPress,
    required this.signalInk,
    required this.signalTint,
    required this.sos,
    required this.sosText,
    required this.sosTint,
    required this.onSos,
    required this.verified,
    required this.verifiedTint,
    required this.info,
    required this.danger,
    required this.highlight,
    required this.scrim,
    required this.paper,
    required this.paperInk,
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space5,
    required this.space6,
    required this.space7,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusFull,
    required this.display,
    required this.title,
    required this.step,
    required this.chat,
    required this.label,
    required this.caption,
    required this.source,
    required this.readout,
    required this.durationFast,
    required this.durationBase,
    required this.durationSlow,
    required this.durationStream,
    required this.durationPulse,
    required this.durationShimmer,
    required this.easeOut,
    required this.easeInOut,
    required this.easeIn,
    required this.easeSheet,
    required this.shadowFloat,
    required this.shadowSheet,
    required this.shadowPop,
    required this.minTouchTarget,
  });

  /// The dark theme (the only one in the MVP).
  static const BzTokens dark = BzTokens(
    bg000: Color(0xFF100F0E),
    bg100: Color(0xFF181715),
    bg200: Color(0xFF21201D),
    bg300: Color(0xFF2C2A27),
    line100: Color(0xFF282623),
    line150: Color(0xFF3A3732),
    line200: Color(0xFF67635D),
    ink100: Color(0xFFEEECE6),
    ink200: Color(0xFFA9A59D),
    ink300: Color(0xFF8A867F),
    overlayHover: Color(0x14EEECE6),
    overlayPress: Color(0x24EEECE6),
    action: Color(0xFFEEECE6),
    actionPress: Color(0xFFD1CEC7),
    onAction: Color(0xFF100F0E),
    signal: Color(0xFFC9A66B),
    signalPress: Color(0xFFB08E57),
    signalInk: Color(0xFF1A1408),
    signalTint: Color(0xFF241F16),
    sos: Color(0xFFA8433B),
    sosText: Color(0xFFE0857B),
    sosTint: Color(0xFF261816),
    onSos: Color(0xFFFFFFFF),
    verified: Color(0xFF8DB89E),
    verifiedTint: Color(0xFF18211C),
    info: Color(0xFF8FAACB),
    danger: Color(0xFFE0857B),
    highlight: Color(0x66C9A66B),
    scrim: Color(0xA3000000),
    paper: Color(0xFFF4F1EA),
    paperInk: Color(0xFF2B2722),
    space1: 4.0,
    space2: 8.0,
    space3: 12.0,
    space4: 16.0,
    space5: 24.0,
    space6: 32.0,
    space7: 48.0,
    radiusSm: 8.0,
    radiusMd: 12.0,
    radiusLg: 18.0,
    radiusXl: 28.0,
    radiusFull: 9999.0,
    display: TextStyle(
      fontFamily: bzFontFamily,
      fontSize: 40.0,
      height: 44.0 / 40.0,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
    ),
    title: TextStyle(
      fontFamily: bzFontFamily,
      fontSize: 24.0,
      height: 30.0 / 24.0,
      fontWeight: FontWeight.w700,
    ),
    step: TextStyle(
      fontFamily: bzFontFamily,
      fontSize: 20.0,
      height: 28.0 / 20.0,
      fontWeight: FontWeight.w700,
    ),
    chat: TextStyle(
      fontFamily: bzFontFamily,
      fontSize: 17.0,
      height: 26.0 / 17.0,
      fontWeight: FontWeight.w400,
    ),
    label: TextStyle(
      fontFamily: bzFontFamily,
      fontSize: 14.0,
      height: 20.0 / 14.0,
      fontWeight: FontWeight.w600,
    ),
    caption: TextStyle(
      fontFamily: bzFontFamily,
      fontSize: 13.0,
      height: 18.0 / 13.0,
      fontWeight: FontWeight.w400,
    ),
    source: TextStyle(
      fontFamily: bzFontFamily,
      fontSize: 13.0,
      height: 18.0 / 13.0,
      fontWeight: FontWeight.w500,
    ),
    readout: TextStyle(
      fontFamily: bzFontFamily,
      fontSize: 28.0,
      height: 32.0 / 28.0,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    durationFast: Duration(milliseconds: 150),
    durationBase: Duration(milliseconds: 200),
    durationSlow: Duration(milliseconds: 300),
    durationStream: Duration(milliseconds: 300),
    durationPulse: Duration(milliseconds: 1200),
    durationShimmer: Duration(milliseconds: 2000),
    easeOut: Cubic(0.2, 0, 0, 1),
    easeInOut: Cubic(0.4, 0, 0.2, 1),
    easeIn: Cubic(0.4, 0, 1, 1),
    easeSheet: Cubic(0.32, 0.72, 0, 1),
    shadowFloat: [
      BoxShadow(
        color: Color(0x80000000),
        offset: Offset(0.0, 2.0),
        blurRadius: 12.0,
      ),
    ],
    shadowSheet: [
      BoxShadow(
        color: Color(0x99000000),
        offset: Offset(0.0, -8.0),
        blurRadius: 32.0,
      ),
    ],
    shadowPop: [
      BoxShadow(
        color: Color(0x80000000),
        offset: Offset(0.0, 8.0),
        blurRadius: 24.0,
      ),
    ],
    minTouchTarget: 48.0,
  );

  /// Tło aplikacji i ekranu czatu. Grafit, nie czysta czerń — mniej smużenia na OLED przy przewijaniu, wciąż tani dla baterii.
  final Color bg000;

  /// Sidebar, pasek dolny, pole wpisywania (composer).
  final Color bg100;

  /// Dymek wiadomości użytkownika, karty planu 72h, arkusze.
  final Color bg200;

  /// Hover i stan aktywny na bg-100/bg-200. Nie do tekstu w kolorze ink-300.
  final Color bg300;

  /// Hairline: separatory list, krawędzie kart. Dekoracyjne, nie niesie znaczenia.
  final Color line100;

  /// Subtelna ramka elementów z etykietą: przycisk secondary, chipy, karty klikalne — odpowiednik border-medium z ChatGPT. Dekoracyjna: kontrolkę identyfikuje tekst, nie ramka.
  final Color line150;

  /// Obramowanie kontrolek (input, checkbox, przycisk outline) — 3.3:1 na bg-000.
  final Color line200;

  /// Tekst główny: odpowiedzi asystenta, nagłówki. 16:1 na bg-000.
  final Color ink100;

  /// Tekst drugorzędny: opisy, metadane, placeholder w composerze. ≥5.7:1 na każdym bg.
  final Color ink200;

  /// Tekst pomocniczy (znaczniki czasu, podpisy). Tylko na bg-000…bg-200 (≥4.5:1); na bg-300 użyj ink-200.
  final Color ink300;

  /// Półprzezroczyste podświetlenie hover (8%) dla przycisków ghost/secondary — działa na każdym tle bg-000…bg-300.
  final Color overlayHover;

  /// Stan wciśnięty (14%) dla ghost/secondary; nakładka hover na przyciskach sos.
  final Color overlayPress;

  /// Główny przycisk (wyślij, „Pokaż plan”, „Prowadź do schronu”) — jasny na grafitowym tle, jak w ChatGPT. Jeden na ekran.
  final Color action;

  /// Hover/wciśnięcie przycisku action.
  final Color actionPress;

  /// Tekst i ikona na przycisku action (16:1).
  final Color onAction;

  /// Akcent marki — przygaszona ochra, „lampka w ciemnym pokoju”. Używany oszczędnie: logo, focus ring, igła kompasu, aktywny krok planu. NIE na główny przycisk (to robi action).
  final Color signal;

  /// Stan wciśnięty/hover elementu w kolorze signal.
  final Color signalPress;

  /// Tekst i ikony NA tle signal (8:1).
  final Color signalInk;

  /// Tło podświetlenia: aktywny krok planu, zaznaczony punkt na mapie. Tekst: signal lub ink-100.
  final Color signalTint;

  /// WYŁĄCZNIE fallback „nie wiem — dzwoń 112” i przycisk połączenia alarmowego. Przygaszona cegła, nie alarmowa czerwień — powaga zamiast paniki. Tekst: on-sos (5.9:1).
  final Color sos;

  /// Tekst/ikona ostrzeżenia krytycznego na ciemnym tle (≥5.2:1 na każdym bg).
  final Color sosText;

  /// Tło bloku ostrzeżenia. Tekst: sos-text lub ink-100.
  final Color sosTint;

  /// Tekst na tle sos.
  final Color onSos;

  /// Szałwiowa zieleń: odpowiedź potwierdzona źródłem oficjalnym (chip „RCB · s. 34”), bezpieczny punkt na mapie, tryb offline aktywny.
  final Color verified;

  /// Tło chipa źródła i karty cytatu. Tekst: verified lub ink-100.
  final Color verifiedTint;

  /// Stalowy błękit: trasa, pozycja GPS, punkty poboru wody. Nie do akcji.
  final Color info;

  /// Tekst i ramka błędów walidacji oraz akcji niszczących (Usuń czat, Usuń wszystkie dane). Pełne tło sos zostaje tylko dla SOS i 112.
  final Color danger;

  /// Zakreślacz cytowanego fragmentu na stronie PDF (QuotePanel, podgląd PDF) — ochra 40%.
  final Color highlight;

  /// Przyciemnienie pod panelem bocznym, arkuszami i dialogami.
  final Color scrim;

  /// Tło strony PDF w podglądzie cytatu. Jedyna jasna powierzchnia w ciemnym motywie — to dokument, nie UI.
  final Color paper;

  /// Tekst strony PDF na paper (13:1).
  final Color paperInk;

  /// Odstęp ikona–tekst w małych elementach, gap w chipie źródła.
  final double space1;

  /// Gap między przyciskami, odstęp chipów źródeł pod odpowiedzią.
  final double space2;

  /// Padding pionowy dymka, odstęp tytuł–opis w kroku.
  final double space3;

  /// Padding kart i dymków (poziomy), margines boczny ekranu na telefonie.
  final double space4;

  /// Odstęp między wiadomościami w czacie, padding karty 112.
  final double space5;

  /// Odstęp między sekcjami ekranu.
  final double space6;

  /// Duże przerwy: ekran startowy, nad composerem.
  final double space7;

  /// Małe elementy wewnątrz kart, pola liczbowe, miniatury.
  final double radiusSm;

  /// Karty w liście (plan 72h, punkt na mapie).
  final double radiusMd;

  /// Dymek wiadomości użytkownika i karty w czacie (karta 112) — jak w ChatGPT.
  final double radiusLg;

  /// Composer (pole wpisywania) i panel dolny mapy — jak w ChatGPT.
  final double radiusXl;

  /// Pigułka i koło: wszystkie przyciski, chipy, znacznik offline.
  final double radiusFull;

  /// Ekran powitalny, wordmark, slajd na scenie.
  final TextStyle display;

  /// Tytuł ekranu, nagłówek planu.
  final TextStyle title;

  /// Krok instrukcji „co zrobić teraz” — czytany w stresie, z odległości ręki.
  final TextStyle step;

  /// Treść odpowiedzi asystenta i wiadomości użytkownika.
  final TextStyle chat;

  /// Przyciski, zakładki, etykiety pól.
  final TextStyle label;

  /// Metadane, znaczniki czasu, podpisy mapy.
  final TextStyle caption;

  /// Chip źródła pod odpowiedzią: „Poradnik bezp., s. 14”. Ten sam krój co reszta — zielone tło chipu mówi „źródło”.
  final TextStyle source;

  /// Duże liczby: odległość w kompasie, licznik RKO. Cyfry tabelaryczne (font-variant-numeric: tabular-nums), żeby się nie przesuwały.
  final TextStyle readout;

  /// Hover, press, zmiana koloru, focus — wszystkie mikro-reakcje kontrolek.
  final Duration durationFast;

  /// Pojawienie się wiadomości, karty, menu; zanikanie elementów.
  final Duration durationBase;

  /// Panel od dołu (mapa, źródło), przejścia ekranów. Maksimum dla przejść.
  final Duration durationSlow;

  /// Wygaszanie (fade-in) każdego nowego fragmentu tekstu podczas strumieniowania odpowiedzi.
  final Duration durationStream;

  /// Pętla pulsującej kropki „myślę” (Thinking).
  final Duration durationPulse;

  /// Pętla połysku tekstu statusu („Szukam w Poradniku…”).
  final Duration durationShimmer;

  /// Domyślna: wszystko, co się pojawia — wiadomości, karty, menu, strumień tekstu.
  final Curve easeOut;

  /// Zmiany stanu w miejscu: hover, kolor, pulsowanie kropki.
  final Curve easeInOut;

  /// Znikanie: zamykanie menu i panelu (szybciej niż wejście).
  final Curve easeIn;

  /// Panel wysuwany od dołu — miękkie, „natywne” hamowanie jak w iOS.
  final Curve easeSheet;

  /// Elementy pływające nad treścią i mapą: wyspa, Wstecz, SOS, pigułka stanu, przyciski mapy.
  final List<BoxShadow> shadowFloat;

  /// Arkusz od dołu i panel boczny.
  final List<BoxShadow> shadowSheet;

  /// Menu, dialog, toast.
  final List<BoxShadow> shadowPop;

  /// Minimum touch target in dp (spec: every control >= 48 dp).
  final double minTouchTarget;

  @override
  BzTokens copyWith({
    Color? bg000,
    Color? bg100,
    Color? bg200,
    Color? bg300,
    Color? line100,
    Color? line150,
    Color? line200,
    Color? ink100,
    Color? ink200,
    Color? ink300,
    Color? overlayHover,
    Color? overlayPress,
    Color? action,
    Color? actionPress,
    Color? onAction,
    Color? signal,
    Color? signalPress,
    Color? signalInk,
    Color? signalTint,
    Color? sos,
    Color? sosText,
    Color? sosTint,
    Color? onSos,
    Color? verified,
    Color? verifiedTint,
    Color? info,
    Color? danger,
    Color? highlight,
    Color? scrim,
    Color? paper,
    Color? paperInk,
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? space5,
    double? space6,
    double? space7,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusFull,
    TextStyle? display,
    TextStyle? title,
    TextStyle? step,
    TextStyle? chat,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? source,
    TextStyle? readout,
    Duration? durationFast,
    Duration? durationBase,
    Duration? durationSlow,
    Duration? durationStream,
    Duration? durationPulse,
    Duration? durationShimmer,
    Curve? easeOut,
    Curve? easeInOut,
    Curve? easeIn,
    Curve? easeSheet,
    List<BoxShadow>? shadowFloat,
    List<BoxShadow>? shadowSheet,
    List<BoxShadow>? shadowPop,
    double? minTouchTarget,
  }) {
    return BzTokens(
      bg000: bg000 ?? this.bg000,
      bg100: bg100 ?? this.bg100,
      bg200: bg200 ?? this.bg200,
      bg300: bg300 ?? this.bg300,
      line100: line100 ?? this.line100,
      line150: line150 ?? this.line150,
      line200: line200 ?? this.line200,
      ink100: ink100 ?? this.ink100,
      ink200: ink200 ?? this.ink200,
      ink300: ink300 ?? this.ink300,
      overlayHover: overlayHover ?? this.overlayHover,
      overlayPress: overlayPress ?? this.overlayPress,
      action: action ?? this.action,
      actionPress: actionPress ?? this.actionPress,
      onAction: onAction ?? this.onAction,
      signal: signal ?? this.signal,
      signalPress: signalPress ?? this.signalPress,
      signalInk: signalInk ?? this.signalInk,
      signalTint: signalTint ?? this.signalTint,
      sos: sos ?? this.sos,
      sosText: sosText ?? this.sosText,
      sosTint: sosTint ?? this.sosTint,
      onSos: onSos ?? this.onSos,
      verified: verified ?? this.verified,
      verifiedTint: verifiedTint ?? this.verifiedTint,
      info: info ?? this.info,
      danger: danger ?? this.danger,
      highlight: highlight ?? this.highlight,
      scrim: scrim ?? this.scrim,
      paper: paper ?? this.paper,
      paperInk: paperInk ?? this.paperInk,
      space1: space1 ?? this.space1,
      space2: space2 ?? this.space2,
      space3: space3 ?? this.space3,
      space4: space4 ?? this.space4,
      space5: space5 ?? this.space5,
      space6: space6 ?? this.space6,
      space7: space7 ?? this.space7,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusFull: radiusFull ?? this.radiusFull,
      display: display ?? this.display,
      title: title ?? this.title,
      step: step ?? this.step,
      chat: chat ?? this.chat,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      source: source ?? this.source,
      readout: readout ?? this.readout,
      durationFast: durationFast ?? this.durationFast,
      durationBase: durationBase ?? this.durationBase,
      durationSlow: durationSlow ?? this.durationSlow,
      durationStream: durationStream ?? this.durationStream,
      durationPulse: durationPulse ?? this.durationPulse,
      durationShimmer: durationShimmer ?? this.durationShimmer,
      easeOut: easeOut ?? this.easeOut,
      easeInOut: easeInOut ?? this.easeInOut,
      easeIn: easeIn ?? this.easeIn,
      easeSheet: easeSheet ?? this.easeSheet,
      shadowFloat: shadowFloat ?? this.shadowFloat,
      shadowSheet: shadowSheet ?? this.shadowSheet,
      shadowPop: shadowPop ?? this.shadowPop,
      minTouchTarget: minTouchTarget ?? this.minTouchTarget,
    );
  }

  /// Tokens are discrete design constants: no interpolation, swap at t = 0.5.
  @override
  BzTokens lerp(ThemeExtension<BzTokens>? other, double t) {
    if (other is! BzTokens) return this;
    return t < 0.5 ? this : other;
  }

  /// Colour tokens by their tokens.json name, for the gallery and tests.
  Map<String, Color> get colorsByName => {
    "bg-000": bg000,
    "bg-100": bg100,
    "bg-200": bg200,
    "bg-300": bg300,
    "line-100": line100,
    "line-150": line150,
    "line-200": line200,
    "ink-100": ink100,
    "ink-200": ink200,
    "ink-300": ink300,
    "overlay-hover": overlayHover,
    "overlay-press": overlayPress,
    "action": action,
    "action-press": actionPress,
    "on-action": onAction,
    "signal": signal,
    "signal-press": signalPress,
    "signal-ink": signalInk,
    "signal-tint": signalTint,
    "sos": sos,
    "sos-text": sosText,
    "sos-tint": sosTint,
    "on-sos": onSos,
    "verified": verified,
    "verified-tint": verifiedTint,
    "info": info,
    "danger": danger,
    "highlight": highlight,
    "scrim": scrim,
    "paper": paper,
    "paper-ink": paperInk,
  };

  /// Text styles by their tokens.json name, for the gallery and tests.
  Map<String, TextStyle> get textStylesByName => {
    "display": display,
    "title": title,
    "step": step,
    "chat": chat,
    "label": label,
    "caption": caption,
    "source": source,
    "readout": readout,
  };
}
