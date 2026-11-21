import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_router.dart' show appRouterProvider, profileRoutePath;
import '../../czat/templates/call/call_panel_view.dart'
    show callLauncherProvider;
import '../../mapa/position_provider.dart';
import '../../profil/profile_model.dart';
import '../../profil/profile_store.dart';
import '../../wspolne/shell/shell_panels.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'call_gps.dart';
import 'sms_body.dart';

/// One launcher seam shared with the chat `call` template (D03).
export '../../czat/templates/call/call_panel_view.dart'
    show callLauncherProvider;

/// User-facing texts (spec "Teksty").
const callPanelTitle = 'Kontakt ze służbami';
const call112Label = 'ZADZWOŃ 112';
const call112Sub = 'Numer alarmowy';
const call112Semantics = 'Zadzwoń pod numer alarmowy 112';
const callSmsLabel = 'POWIADOM BLISKICH';
const callSmsSub = 'SMS z lokalizacją';
const callAmlNote =
    'Przy połączeniu z 112 telefon sam przekazuje lokalizację, jeśli ma zasięg sieci komórkowej.';
const callSaySection = 'Co powiedzieć dyspozytorowi';
const callSay =
    'Powiedz: co się stało, gdzie jesteś, ile osób potrzebuje pomocy, czy są przytomne.';

enum ContactPanelVariant { sheet, inline }

/// Whether the device can handle `sms:` (needs the `<queries>` entry on Android 11+).
final canSendSmsProvider = FutureProvider<bool>((ref) async {
  try {
    return await canLaunchUrl(Uri.parse('sms:'));
  } on Object {
    return true;
  }
});

/// Panel 2 (`sheet`) and the chat `call` template (`inline`): two 80 px
/// buttons plus a collapsed "Więcej". Nothing is dialled or sent without a tap.
class ContactCallPanel extends ConsumerStatefulWidget {
  const ContactCallPanel({
    super.key,
    this.title,
    this.variant = ContactPanelVariant.sheet,
    this.situation,
    this.signalBuilder,
    this.onClose,
    this.onAddContacts,
  });

  final ContactPanelVariant variant;

  /// Title of the red "Wezwij pomoc" group (`inline` only).
  final String? title;

  /// SMS `{opis}`: rescue card name or last user message.
  final String? situation;

  /// Content of the "Sygnał ratunkowy" section (task D05); hidden when null.
  final WidgetBuilder? signalBuilder;

  /// Defaults to closing P2 in the shell.
  final VoidCallback? onClose;

  /// Defaults to closing P2 and going to the profile screen.
  final VoidCallback? onAddContacts;

  @override
  ConsumerState<ContactCallPanel> createState() => _ContactCallPanelState();
}

class _ContactCallPanelState extends ConsumerState<ContactCallPanel> {
  bool _more = false;
  bool _signal = false;
  bool _searchTimedOut = false;
  String? _notice;
  Timer? _noticeTimer;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _searchTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() => _searchTimedOut = true);
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _toast(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  Future<void> _launch(Uri uri, String what, String fallback) async {
    var ok = false;
    try {
      ok = await ref.read(callLauncherProvider)(uri);
    } on Object {
      ok = false;
    }
    if (!ok && mounted) _toast('Nie mogę otworzyć $what. $fallback');
  }

  void _dial(String number) =>
      _launch(telUri(number), 'telefonu', 'Wybierz $number ręcznie.');

  void _close() => widget.onClose != null
      ? widget.onClose!()
      : ref.read(shellPanelsProvider.notifier).closeContactPanel();

  void _addContacts() {
    if (widget.onAddContacts != null) return widget.onAddContacts!();
    // The panel lives in the root overlay above the router: no GoRouter in context.
    final router = ref.read(appRouterProvider);
    _close();
    router.go(profileRoutePath);
  }

  SosSmsInput _smsInput(CallGps? gps, ProfileSmsFacts facts) {
    final p = gps?.position;
    return SosSmsInput(
      lat: p?.latitude,
      lon: p?.longitude,
      accuracyM: p?.accuracy,
      positionTime: p?.timestamp.toLocal(),
      fresh: gps?.fresh ?? false,
      situation: widget.situation == null
          ? null
          : clipSituation(widget.situation!),
      profile: facts.isEmpty ? null : facts,
    );
  }

  void _notify(List<String> recipients, CallGps? gps, ProfileSmsFacts facts) {
    final body = buildSosSms(_smsInput(gps, facts));
    _launch(smsUri(recipients, body), 'wiadomości', 'Wyślij SMS ręcznie.');
  }

  Future<void> _copy(Position p) async {
    final text =
        '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}\n${formatDms(p.latitude, p.longitude)}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast('Skopiowano współrzędne');
  }

  String _gpsLine(CallGps? gps) {
    final p = gps?.position;
    if (gps != null && gps.access != LocationAccess.granted) {
      return gps.access == LocationAccess.serviceOff
          ? 'Brak sygnału GPS. Wyjdź na otwartą przestrzeń.'
          : 'Brak dostępu do lokalizacji.';
    }
    if (p != null && gps!.fresh) return 'GPS ±${p.accuracy.round()} m';
    final last = p == null
        ? ''
        : ' Ostatnia pozycja (${_hhmm(p.timestamp.toLocal())})';
    if (_searchTimedOut) {
      return 'Brak sygnału GPS. Wyjdź na otwartą przestrzeń.$last';
    }
    return p == null ? 'Szukam pozycji GPS…' : 'Szukam pozycji GPS…$last';
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final gps = ref.watch(callGpsProvider).asData?.value;
    final profile =
        ref.watch(profileProvider).asData?.value ?? HouseholdProfile.empty;
    final canSms = ref.watch(canSendSmsProvider).asData?.value ?? true;
    final facts = profileSmsFacts(profile);
    final recipients = smsRecipients(profile.iceContacts);
    final names = [
      for (final c in profile.iceContacts)
        if (c.name.trim().isNotEmpty) c.name.trim(),
    ];
    final noPermission = gps != null && gps.access == LocationAccess.denied;
    final pos = gps?.position;
    final sheet = widget.variant == ContactPanelVariant.sheet;

    final contacts = <Widget>[
      if (!canSms)
        Padding(
          padding: EdgeInsets.only(top: bz.space2),
          child: Text(
            'Ten telefon nie wysyła SMS-ów.',
            style: bz.caption.copyWith(color: bz.ink200),
          ),
        )
      else if (recipients.isEmpty)
        _LinkButton(label: 'Dodaj kontakty', onTap: _addContacts)
      else
        Align(
          alignment: Alignment.centerRight,
          child: _LinkButton(label: 'Zmień', onTap: _addContacts),
        ),
      Text(
        _gpsLine(gps),
        key: const Key('call-gps'),
        style: bz.caption.copyWith(color: bz.ink200),
      ),
      if (noPermission)
        _LinkButton(
          label: 'Zezwól',
          onTap: () async {
            final access = await ref
                .read(locationGatewayProvider)
                .ensureAccess();
            if (access != LocationAccess.granted) {
              await ref.read(locationGatewayProvider).openSettings();
            }
            ref.invalidate(locationAccessProvider);
          },
        ),
      if (_notice != null)
        Padding(
          padding: EdgeInsets.only(top: bz.space2),
          child: Semantics(
            liveRegion: true,
            child: Container(
              key: const Key('call-notice'),
              width: double.infinity,
              padding: EdgeInsets.all(bz.space3),
              decoration: BoxDecoration(
                color: bz.bg300,
                borderRadius: BorderRadius.circular(bz.radiusMd),
              ),
              child: Text(_notice!, style: bz.chat),
            ),
          ),
        ),
    ];

    final buttons = <Widget>[
      _BigButton(
        key: const Key('call-112'),
        label: call112Label,
        sub: call112Sub,
        semantics: call112Semantics,
        icon: LucideIcons.phone,
        filled: true,
        onTap: () => _dial('112'),
      ),
      SizedBox(height: bz.space3),
      _BigButton(
        key: const Key('call-notify'),
        label: callSmsLabel,
        // Recipients live in the subtitle (DS CallPanel): "SMS z lokalizacją do: Mama".
        sub: canSms && recipients.isNotEmpty
            ? '$callSmsSub do: ${names.isEmpty ? recipients.join(', ') : names.join(', ')}'
            : callSmsSub,
        icon: LucideIcons.users,
        filled: false,
        onTap: canSms ? () => _notify(recipients, gps, facts) : null,
      ),
      ...contacts,
    ];

    final more = _MoreToggle(
      key: const Key('call-more'),
      expand: sheet,
      open: _more,
      onTap: () => setState(() => _more = !_more),
    );
    final dials = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: bz.space4,
      children: [
        for (final (n, name) in const [
          ('999', 'Pogotowie'),
          ('998', 'Straż'),
          ('997', 'Policja'),
        ])
          _SmallDial(
            key: Key('call-$n'),
            number: n,
            name: name,
            onTap: () => _dial(n),
          ),
      ],
    );

    final children = <Widget>[
      if (sheet) ...[
        Row(
          children: [
            _IconTap(icon: LucideIcons.x, label: 'Zamknij', onTap: _close),
            SizedBox(width: bz.space2),
            Expanded(child: Text(callPanelTitle, style: bz.step)),
          ],
        ),
        SizedBox(height: bz.space3),
        ...buttons,
        SizedBox(height: bz.space2),
        dials,
        Divider(color: bz.line100, height: bz.space5),
        more,
      ] else ...[
        // "Wezwij pomoc" group: the only red-outlined block (DS `.bz-panel--sos`).
        DecoratedBox(
          decoration: BoxDecoration(
            color: bz.sosTint,
            border: Border.all(color: bz.sos),
            borderRadius: BorderRadius.circular(bz.radiusLg),
          ),
          child: Padding(
            padding: EdgeInsets.all(bz.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.title != null) ...[
                  Text(
                    widget.title!,
                    style: bz.label.copyWith(
                      fontSize: 16,
                      height: 22 / 16,
                      fontWeight: FontWeight.w700,
                      color: bz.sosText,
                    ),
                  ),
                  SizedBox(height: bz.space3),
                ],
                ...buttons,
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: bz.space1),
          child: Row(
            children: [
              Expanded(child: dials),
              more,
            ],
          ),
        ),
      ],
      if (_more) ..._moreChildren(bz, pos),
    ];

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (!sheet) return column;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(bz.space4),
        child: column,
      ),
    );
  }

  List<Widget> _moreChildren(BzTokens bz, Position? pos) => [
    SizedBox(height: bz.space3),
    Text('Twoja pozycja', style: bz.label),
    if (pos == null)
      Text('Brak pozycji.', style: bz.caption.copyWith(color: bz.ink200))
    else
      InkWell(
        key: const Key('call-coords'),
        onTap: () => _copy(pos),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}\n${formatDms(pos.latitude, pos.longitude)}',
              style: bz.readout,
            ),
          ),
        ),
      ),
    SizedBox(height: bz.space2),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.info, size: 16, color: bz.ink200),
        SizedBox(width: bz.space2),
        Expanded(
          child: Text(
            callAmlNote,
            style: bz.caption.copyWith(color: bz.ink200),
          ),
        ),
      ],
    ),
    SizedBox(height: bz.space3),
    Text(callSaySection, style: bz.label),
    SizedBox(height: bz.space1),
    Text(callSay, style: bz.chat),
    if (widget.signalBuilder != null) ...[
      SizedBox(height: bz.space2),
      _MoreToggle(
        key: const Key('call-signal'),
        label: 'Sygnał ratunkowy',
        open: _signal,
        expand: true,
        onTap: () => setState(() => _signal = !_signal),
      ),
      if (_signal) Builder(builder: widget.signalBuilder!),
    ],
  ];
}

/// 80 px main button (spec: two per panel).
class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.label,
    required this.sub,
    required this.icon,
    required this.filled,
    required this.onTap,
    this.semantics,
  });

  final String label;
  final String sub;
  final String? semantics;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final fg = filled ? bz.onSos : bz.ink100;
    return Opacity(
      opacity: onTap == null ? 0.38 : 1,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: semantics ?? '$label. $sub',
        excludeSemantics: true,
        child: Material(
          color: filled ? bz.sos : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(bz.radiusLg),
            side: filled ? BorderSide.none : BorderSide(color: bz.line200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(bz.radiusLg),
            highlightColor: bz.overlayPress,
            splashColor: Colors.transparent,
            onTap: onTap,
            // Grows with text scale: min 80, labels wrap instead of clipping.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              // DS `.bz-call__btn`: left-aligned stack, 12 x 20 padding, 16 gap.
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: bz.space3),
                child: Row(
                  children: [
                    Icon(icon, size: 24, color: fg),
                    SizedBox(width: bz.space4),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            softWrap: true,
                            style: bz.step.copyWith(
                              height: 26 / 20,
                              fontWeight: FontWeight.w800,
                              color: fg,
                            ),
                          ),
                          Text(
                            sub,
                            softWrap: true,
                            style: bz.label.copyWith(
                              height: 18 / 14,
                              fontWeight: FontWeight.w500,
                              color: fg.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet text dial ("999 Pogotowie"): no frame, 48 dp hit area.
class _SmallDial extends StatelessWidget {
  const _SmallDial({
    super.key,
    required this.number,
    required this.name,
    required this.onTap,
  });
  final String number;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Semantics(
      button: true,
      label: 'Zadzwoń: $number $name',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(bz.radiusSm),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bz.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: number,
                    style: bz.label.copyWith(
                      color: bz.ink200,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: ' $name',
                    style: bz.label.copyWith(
                      color: bz.ink300,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Collapsible row toggle ("Więcej", "Sygnał ratunkowy"): label + chevron.
class _MoreToggle extends StatelessWidget {
  const _MoreToggle({
    super.key,
    this.label = 'Więcej',
    required this.open,
    required this.onTap,
    this.expand = false,
  });
  final String label;
  final bool open;
  final VoidCallback onTap;

  /// Full-width row (sheet) instead of a compact trailing toggle (inline).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final text = Text(label, style: bz.label.copyWith(color: bz.ink100));
    return InkWell(
      borderRadius: BorderRadius.circular(bz.radiusSm),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: bz.minTouchTarget),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (expand) Expanded(child: text) else text,
            SizedBox(width: bz.space1),
            Icon(
              open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 20,
              color: bz.ink200,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    // Zero horizontal padding keeps the label flush with the panel content.
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
      child: Text(label),
    ),
  );
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkResponse(
      onTap: onTap,
      radius: 24,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, size: 24, color: context.bz.ink100),
      ),
    ),
  );
}
