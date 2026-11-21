import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../wspolne/shell/shell_panels.dart';
import '../../../wspolne/shell/sos_button.dart'
    show UriLauncher, defaultSosLauncher;
import '../../../wspolne/theme/bz_theme.dart';
import '../panel_card.dart';
import '../template_registry.dart';

/// Texts of the `call` template (spec `panel-2-kontakt-ze-sluzbami.md`, "Teksty").
const String callTitle = 'Wezwij pomoc';
const String call112Label = 'ZADZWOŃ 112';
const String call112Sub = 'Numer alarmowy';
const String call112Semantics = 'Zadzwoń pod numer alarmowy 112';
const String callNotifyLabel = 'POWIADOM BLISKICH';
const String callNotifySub = 'SMS z lokalizacją';
const String callMoreLabel = 'Więcej';
const String callAmlNote =
    'Przy połączeniu z 112 telefon sam przekazuje lokalizację, jeśli ma zasięg sieci komórkowej.';
const String callWhatToSayTitle = 'Co powiedzieć dyspozytorowi';
const String callWhatToSay =
    'Powiedz: co się stało, gdzie jesteś, ile osób potrzebuje pomocy, czy są przytomne.';

/// Secondary services shown under "Więcej": number and name.
const List<(String number, String name)> callServices = [
  ('999', 'Pogotowie'),
  ('998', 'Straż'),
  ('997', 'Policja'),
];

/// "Nie mogę otworzyć telefonu. Wybierz {number} ręcznie." (spec "Stany").
String callFailureText(String number) =>
    'Nie mogę otworzyć telefonu. Wybierz $number ręcznie.';

/// Opens `tel:` links. The default is `url_launcher`; tests and the shell
/// override it. Dialling always needs the user's tap, the system dialler asks
/// for confirmation.
final callLauncherProvider = Provider<UriLauncher>((ref) => defaultSosLauncher);

/// `call` template (DS `CallPanel`, `inline`): "ZADZWOŃ 112", "POWIADOM
/// BLISKICH" (opens Panel 2, where the SMS is prepared) and a collapsed
/// "Więcej" row with 999 / 998 / 997.
///
/// The GPS line, the profile toggle and the coordinates belong to Panel 2
/// (D06) and are not drawn here.
class CallPanelView extends ConsumerStatefulWidget {
  const CallPanelView({super.key, this.onNotify});

  /// Default: opens the contact panel (Panel 2).
  final VoidCallback? onNotify;

  @override
  ConsumerState<CallPanelView> createState() => _CallPanelViewState();
}

class _CallPanelViewState extends ConsumerState<CallPanelView> {
  bool _expanded = false;

  /// Number whose `tel:` launch failed (the Fallback112 hint is shown).
  String? _failed;

  Future<void> _dial(String number) async {
    var ok = false;
    try {
      ok = await ref.read(callLauncherProvider)(
        Uri(scheme: 'tel', path: number),
      );
    } on Object {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _failed = ok ? null : number);
  }

  void _notify() {
    final cb = widget.onNotify;
    if (cb != null) {
      cb();
    } else {
      ref.read(shellPanelsProvider.notifier).openContactPanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return PanelCard(
      title: callTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BigButton(
            key: const ValueKey('call-112'),
            label: call112Label,
            sub: call112Sub,
            semanticLabel: call112Semantics,
            icon: LucideIcons.phone,
            fill: t.sos,
            fg: t.onSos,
            onTap: () => unawaited(_dial('112')),
          ),
          SizedBox(height: t.space3),
          _BigButton(
            key: const ValueKey('call-notify'),
            label: callNotifyLabel,
            sub: callNotifySub,
            icon: LucideIcons.messageSquare,
            fill: null,
            fg: t.ink100,
            border: t.line150,
            onTap: _notify,
          ),
          if (_failed != null) ...[
            SizedBox(height: t.space3),
            _Fallback112(number: _failed!),
          ],
          SizedBox(height: t.space2),
          _MoreRow(
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            SizedBox(height: t.space2),
            Row(
              children: [
                for (var i = 0; i < callServices.length; i++) ...[
                  if (i > 0) SizedBox(width: t.space2),
                  Expanded(
                    child: _ServiceButton(
                      number: callServices[i].$1,
                      name: callServices[i].$2,
                      onTap: () => unawaited(_dial(callServices[i].$1)),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: t.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: 16, color: t.ink200),
                SizedBox(width: t.space2),
                Expanded(
                  child: Text(
                    callAmlNote,
                    style: t.caption.copyWith(color: t.ink200),
                  ),
                ),
              ],
            ),
            SizedBox(height: t.space3),
            Text(callWhatToSayTitle, style: t.label.copyWith(color: t.ink100)),
            SizedBox(height: t.space1),
            Text(callWhatToSay, style: t.caption.copyWith(color: t.ink200)),
          ],
        ],
      ),
    );
  }
}

/// 80 px full-width button (spec: both main buttons are 80 px).
class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.label,
    required this.sub,
    required this.icon,
    required this.fill,
    required this.fg,
    required this.onTap,
    this.border,
    this.semanticLabel,
  });

  final String label;
  final String sub;
  final IconData icon;
  final Color? fill;
  final Color fg;
  final Color? border;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final shape = StadiumBorder(
      side: border == null ? BorderSide.none : BorderSide(color: border!),
    );
    return Semantics(
      button: true,
      label: semanticLabel ?? '$label. $sub',
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        height: 80,
        child: Material(
          color: fill ?? const Color(0x00000000),
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: fg),
                SizedBox(width: t.space3),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.label.copyWith(
                          color: fg,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        sub,
                        style: t.caption.copyWith(
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
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Semantics(
      button: true,
      expanded: expanded,
      label: callMoreLabel,
      excludeSemantics: true,
      onTap: onToggle,
      child: InkWell(
        key: const ValueKey('call-more'),
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.minTouchTarget),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  callMoreLabel,
                  style: t.label.copyWith(color: t.ink200),
                ),
              ),
              Icon(
                expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 20,
                color: t.ink200,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  const _ServiceButton({
    required this.number,
    required this.name,
    required this.onTap,
  });

  final String number;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(t.radiusMd),
      side: BorderSide(color: t.line150),
    );
    return Semantics(
      button: true,
      label: '$number · $name',
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Material(
          color: const Color(0x00000000),
          shape: shape,
          child: InkWell(
            key: ValueKey('call-$number'),
            customBorder: shape,
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  number,
                  style: t.label.copyWith(
                    color: t.ink100,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(name, style: t.caption.copyWith(color: t.ink200)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when `tel:` cannot be opened (DS `Fallback112`: `sos-tint` fill,
/// `sos` border, `sos-text` text, announced to screen readers at once).
class _Fallback112 extends StatelessWidget {
  const _Fallback112({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        key: const ValueKey('call-fallback'),
        decoration: BoxDecoration(
          color: t.sosTint,
          border: Border.all(color: t.sos),
          borderRadius: BorderRadius.circular(t.radiusMd),
        ),
        child: Padding(
          padding: EdgeInsets.all(t.space3),
          child: Text(
            callFailureText(number),
            style: t.label.copyWith(color: t.sosText),
          ),
        ),
      ),
    );
  }
}

/// Registers the real `call` template (replaces the placeholder).
void registerCallTemplate(TemplateRegistry r) =>
    r.register('call', (context, scope) => const CallPanelView());
