import 'dart:async';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../czat/templates/panel_card.dart' show BzSegmented;
import '../../czat/templates/panel_model.dart' show VariantOption;
import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'signal_panel.dart' show SignalDevices;
import 'sos_pattern.dart';

// Spec: 02-funkcje/05-alarm/sygnal-ratunkowy.md (modes, strobe warning, pause
// between signals, screen stays on). Copy drafted here (verify: true): the
// spec lists the modes but no texts.
const signalTitle = 'Sygnał ratunkowy';
const signalIntro = 'Zwróć na siebie uwagę, gdy nie możesz zadzwonić.';
const signalSoundLabel = 'Dźwięk';
const signalSoundHint = 'Głośny sygnał SOS z głośnika.';
const signalTorchLabel = 'Latarka SOS';
const signalTorchHint = 'Miga alfabetem Morse’a: ··· ––– ···';
const signalTorchMissing = 'Latarka niedostępna.';
const signalScreenLabel = 'Ekran SOS';
const signalScreenHint = 'Cały ekran miga na biało i czerwono.';
const signalPauseLabel = 'Przerwa między sygnałami';
const signalStopAll = 'Zatrzymaj wszystko';
const signalStopScreen = 'Zatrzymaj ekran SOS';
const strobeWarningTitle = 'Ekran będzie migać';
const strobeWarningBody =
    'Migające światło może wywołać napad u osób z padaczką światłoczułą. '
    'Nie patrz w ekran z bliska.';
const strobeWarningConfirm = 'Włącz';
const strobeWarningCancel = 'Anuluj';

// Strobe colours: pure white and a bright red. Brighter than the `sos` token
// on purpose, so the flash carries and the shell's SOS button stays visible.
const _strobeWhite = Color(0xFFFFFFFF);
const _strobeRed = Color(0xFFFF1F1F);

const _pauses = [
  VariantOption('0', '0'),
  VariantOption('10000', '10 s'),
  VariantOption('30000', '30 s'),
  VariantOption('60000', '60 s'),
];

/// Full-screen rescue signal, opened from the SOS panel: loud sound,
/// flashlight SOS and a screen strobe, each with its own switch. Everything
/// stops when the screen is left. Back and SOS come from `RootOverlay`.
class SignalScreen extends StatefulWidget {
  const SignalScreen({super.key, this.devices = const SignalDevices()});

  /// Lamp and sound back-ends (faked in tests).
  final SignalDevices devices;

  @override
  State<SignalScreen> createState() => _SignalScreenState();
}

class _SignalScreenState extends State<SignalScreen> {
  bool _sound = false;
  bool _torch = false;
  bool _screen = false;
  bool? _torchOk;
  int _pauseMs = 10000;
  SosRunner? _torchRunner;
  SosRunner? _screenRunner;

  /// Strobe phase: true = signal (white), false = gap (red).
  final _flash = ValueNotifier<bool>(false);
  Timer? _tick;
  DateTime? _since;
  Duration _elapsed = Duration.zero;

  bool get _active => _sound || _torch || _screen;

  @override
  void initState() {
    super.initState();
    widget.devices.torchAvailable().then((ok) {
      if (mounted) setState(() => _torchOk = ok);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _torchRunner?.stop();
    _screenRunner?.stop();
    if (_sound) widget.devices.setSound(false);
    if (_active) WakelockPlus.disable().catchError((_) {});
    _flash.dispose();
    super.dispose();
  }

  /// Starts or stops the run-time clock and the wakelock with the first / last
  /// active mode.
  void _sync() {
    if (_active && _tick == null) {
      _since = DateTime.now();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed = DateTime.now().difference(_since!));
      });
      WakelockPlus.enable().catchError((_) {});
    } else if (!_active && _tick != null) {
      _tick!.cancel();
      _tick = null;
      _elapsed = Duration.zero;
      WakelockPlus.disable().catchError((_) {});
    }
  }

  void _setSound(bool on) {
    setState(() => _sound = on);
    widget.devices.setSound(on);
    _sync();
  }

  void _setTorch(bool on) {
    setState(() => _torch = on);
    _torchRunner?.stop();
    _torchRunner = on
        ? (SosRunner(setTorch: widget.devices.setTorch, pauseMs: _pauseMs)
            ..run())
        : null;
    _sync();
  }

  Future<void> _askScreen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(strobeWarningTitle),
        content: const Text(strobeWarningBody),
        actions: [
          TextButton(
            key: const Key('strobe-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(strobeWarningCancel),
          ),
          TextButton(
            key: const Key('strobe-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(strobeWarningConfirm),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _setScreen(true);
  }

  void _setScreen(bool on) {
    setState(() => _screen = on);
    _screenRunner?.stop();
    _screenRunner = on
        ? (SosRunner(
            setTorch: (v) async {
              if (mounted) _flash.value = v;
            },
            pauseMs: _pauseMs,
          )..run())
        : null;
    _sync();
  }

  void _stopAll() {
    if (_sound) _setSound(false);
    if (_torch) _setTorch(false);
    if (_screen) _setScreen(false);
  }

  String get _clock {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final torchBlocked = _torchOk == false;
    return Scaffold(
      backgroundColor: bz.bg000,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              // Room for the floating Back and SOS of the shell.
              padding: EdgeInsets.fromLTRB(bz.space4, 96, bz.space4, bz.space6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(signalTitle, style: bz.title),
                  SizedBox(height: bz.space2),
                  Text(signalIntro, style: bz.chat.copyWith(color: bz.ink200)),
                  SizedBox(height: bz.space4),
                  _ModeTile(
                    keyName: 'sound',
                    icon: LucideIcons.volume2,
                    label: signalSoundLabel,
                    hint: signalSoundHint,
                    value: _sound,
                    onChanged: _setSound,
                  ),
                  SizedBox(height: bz.space3),
                  _ModeTile(
                    keyName: 'torch',
                    icon: LucideIcons.flashlight,
                    label: signalTorchLabel,
                    hint: torchBlocked ? signalTorchMissing : signalTorchHint,
                    value: _torch,
                    onChanged: torchBlocked || _torchOk == null
                        ? null
                        : _setTorch,
                  ),
                  SizedBox(height: bz.space3),
                  _ModeTile(
                    keyName: 'screen',
                    icon: LucideIcons.smartphone,
                    label: signalScreenLabel,
                    hint: signalScreenHint,
                    value: _screen,
                    onChanged: (on) => on ? _askScreen() : _setScreen(false),
                  ),
                  SizedBox(height: bz.space5),
                  Text(
                    signalPauseLabel,
                    style: bz.caption.copyWith(color: bz.ink200),
                  ),
                  SizedBox(height: bz.space2),
                  BzSegmented(
                    options: _pauses,
                    value: '$_pauseMs',
                    onChanged: (v) => setState(() {
                      _pauseMs = int.parse(v);
                      _torchRunner?.pauseMs = _pauseMs;
                      _screenRunner?.pauseMs = _pauseMs;
                    }),
                  ),
                  if (_active) ...[
                    SizedBox(height: bz.space5),
                    Semantics(
                      liveRegion: false,
                      child: Text(
                        'Działa $_clock',
                        key: const Key('signal-screen-clock'),
                        style: bz.caption.copyWith(color: bz.ink200),
                      ),
                    ),
                    SizedBox(height: bz.space3),
                    BzButton(
                      key: const Key('signal-stop-all'),
                      label: signalStopAll,
                      variant: BzButtonVariant.primary,
                      size: BzButtonSize.xl,
                      fullWidth: true,
                      onPressed: _stopAll,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_screen)
            // The strobe covers the controls: one clear way out, at the bottom.
            ValueListenableBuilder<bool>(
              valueListenable: _flash,
              builder: (context, on, child) => ColoredBox(
                key: const Key('signal-strobe'),
                color: on ? _strobeWhite : _strobeRed,
                child: child,
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(bz.space4),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: bz.bg000,
                        borderRadius: BorderRadius.circular(bz.radiusFull),
                        child: InkWell(
                          key: const Key('signal-stop-screen'),
                          borderRadius: BorderRadius.circular(bz.radiusFull),
                          onTap: () => _setScreen(false),
                          child: Padding(
                            // 72 dp tall at the default text size.
                            padding: EdgeInsets.symmetric(horizontal: bz.space5, vertical: 22),
                            child: Text(
                              signalStopScreen,
                              textAlign: TextAlign.center,
                              style: bz.step.copyWith(color: bz.ink100, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One signal mode: icon, name, what it does, and a switch. The whole tile is
/// the touch target (large, for cold or shaking hands).
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final enabled = onChanged != null;
    final fg = enabled ? bz.ink100 : bz.ink300;
    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: '$label. $hint',
      onTap: enabled ? () => onChanged!(!value) : null,
      excludeSemantics: true,
      child: Material(
        color: value ? bz.bg200 : bz.bg100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(bz.radiusLg),
          side: BorderSide(color: value ? bz.signal : bz.line150),
        ),
        child: InkWell(
          key: Key('signal-tile-$keyName'),
          borderRadius: BorderRadius.circular(bz.radiusLg),
          highlightColor: bz.overlayPress,
          splashColor: Colors.transparent,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: bz.space4,
                vertical: bz.space3,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 24, color: value ? bz.signal : fg),
                  SizedBox(width: bz.space4),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: bz.step.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          hint,
                          style: bz.caption.copyWith(
                            color: enabled ? bz.ink200 : bz.ink300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: bz.space2),
                  IgnorePointer(
                    child: Switch(
                      key: Key('signal-switch-$keyName'),
                      value: value,
                      onChanged: enabled ? (_) {} : null,
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
