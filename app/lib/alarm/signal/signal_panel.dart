import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:torch_light/torch_light.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../czat/templates/panel_card.dart';
import '../../czat/templates/panel_model.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'sos_pattern.dart';

/// Lamp + sound back-ends, injectable for tests.
class SignalDevices {
  const SignalDevices({
    this.torchAvailable = _torchAvailable,
    this.setTorch = _setTorch,
    this.setSound = _setSound,
  });

  final Future<bool> Function() torchAvailable;
  final Future<void> Function(bool on) setTorch;
  final Future<void> Function(bool on) setSound;
}

Future<bool> _torchAvailable() async {
  try {
    return await TorchLight.isTorchAvailable();
  } catch (_) {
    return false;
  }
}

Future<void> _setTorch(bool on) async {
  try {
    on ? await TorchLight.enableTorch() : await TorchLight.disableTorch();
  } catch (_) {}
}

AudioPlayer? _player;
Future<void> _setSound(bool on) async {
  try {
    if (on) {
      final p = _player ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(1.0);
      await p.play(AssetSource('audio/sos.wav'));
    } else {
      await _player?.stop();
    }
  } catch (_) {}
}

/// Template `signal` (DS SignalPanel): sound + flashlight SOS, pause, timer.
/// Screen strobe is hidden (post-MVP). Battery counter needs a battery plugin
/// (not in pubspec yet), so only the run time is shown.
class SignalPanelView extends StatefulWidget {
  const SignalPanelView({super.key, this.panel, this.devices = const SignalDevices(), this.bare = false});

  final SignalPanel? panel;
  final SignalDevices devices;

  /// Without the card (inside Panel 2).
  final bool bare;

  @override
  State<SignalPanelView> createState() => _SignalPanelViewState();
}

const _pauses = [
  VariantOption('0', '0'),
  VariantOption('10000', '10 s'),
  VariantOption('30000', '30 s'),
  VariantOption('60000', '60 s'),
];

class _SignalPanelViewState extends State<SignalPanelView> {
  bool _sound = false;
  bool _torch = false;
  bool? _torchOk;
  int _pauseMs = 10000;
  SosRunner? _runner;
  Timer? _tick;
  DateTime? _since;
  Duration _elapsed = Duration.zero;

  bool get _showSound => widget.panel?.modes.contains('sound') ?? true;
  bool get _showTorch => widget.panel?.modes.contains('flashlight') ?? true;

  @override
  void initState() {
    super.initState();
    if (_showTorch) {
      widget.devices.torchAvailable().then((ok) {
        if (mounted) setState(() => _torchOk = ok);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _runner?.stop();
    if (_sound) widget.devices.setSound(false);
    if (_sound || _torch) WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  void _sync() {
    final active = _sound || _torch;
    if (active && _tick == null) {
      _since = DateTime.now();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed = DateTime.now().difference(_since!));
      });
      WakelockPlus.enable().catchError((_) {});
    } else if (!active && _tick != null) {
      _tick!.cancel();
      _tick = null;
      _elapsed = Duration.zero;
      WakelockPlus.disable().catchError((_) {});
    }
  }

  void _setSound(bool v) {
    setState(() => _sound = v);
    widget.devices.setSound(v);
    _sync();
  }

  void _setTorch(bool v) {
    setState(() => _torch = v);
    if (v) {
      _runner = SosRunner(setTorch: widget.devices.setTorch, pauseMs: _pauseMs)..run();
    } else {
      _runner?.stop();
      _runner = null;
    }
    _sync();
  }

  String get _clock {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final torchBlocked = _torchOk == false;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showSound)
          _ModeRow(
            keyName: 'sound',
            icon: LucideIcons.volume2,
            label: 'Dźwięk',
            value: _sound,
            onChanged: _setSound,
          ),
        if (_showTorch)
          _ModeRow(
            keyName: 'torch',
            icon: LucideIcons.flashlight,
            label: 'Latarka SOS',
            hint: torchBlocked ? 'Latarka niedostępna.' : null,
            value: _torch,
            onChanged: torchBlocked || _torchOk == null ? null : _setTorch,
          ),
        SizedBox(height: t.space3),
        Text('Przerwa', style: t.caption.copyWith(color: t.ink300)),
        SizedBox(height: t.space2),
        BzSegmented(
          options: _pauses,
          value: '$_pauseMs',
          onChanged: (v) => setState(() {
            _pauseMs = int.parse(v);
            _runner?.pauseMs = _pauseMs;
          }),
        ),
        if (_sound || _torch) ...[
          SizedBox(height: t.space3),
          Text('Działa $_clock', key: const ValueKey('signal-clock'), style: t.caption.copyWith(color: t.ink200)),
        ],
      ],
    );
    if (widget.bare) return body;
    return PanelCard(title: 'Sygnał ratunkowy', child: body);
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: t.minTouchTarget),
      child: Row(
        children: [
          Icon(icon, size: 20, color: onChanged == null ? t.ink300 : t.ink100),
          SizedBox(width: t.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: t.label.copyWith(color: onChanged == null ? t.ink300 : t.ink100)),
                if (hint != null) Text(hint!, style: t.caption.copyWith(color: t.ink300)),
              ],
            ),
          ),
          Switch(key: ValueKey('signal-$keyName'), value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
