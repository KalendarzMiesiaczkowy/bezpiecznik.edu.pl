import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../czat/templates/call/call_panel_view.dart' show callLauncherProvider;
import '../../czat/templates/panel_card.dart';
import '../../czat/templates/panel_model.dart';
import '../../czat/templates/template_registry.dart';
import '../../wspolne/shell/cpr_state.dart' show formatCprElapsed;
import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'cpr_config.dart';
import 'cpr_engine.dart';
import 'cpr_session.dart';

/// Copy of the instructor (Polish, per `instruktor-rko.md`).
const String cprTitle = 'RKO';
const String cprStartLabel = 'Start RKO';
const String cprPauseLabel = 'Pauza';
const String cprResumeLabel = 'Wznów';
const String cprStopLabel = 'Zakończ';
const String cprBreathsDoneLabel = 'Wdechy zrobione';
const String cprCompressLabel = 'UCISKAJ';
const String cprBreathsLabel = 'ODDECHY';
const String cprPausedLabel = 'PAUZA';

/// `m:ss` for the change countdown ("Zmiana za 0:18").
String formatCprChange(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// How long the "Zmiana ratownika" banner stays after the prompt.
const Duration cprChangeBannerDuration = Duration(seconds: 10);

/// Registers the `cpr` template. With [inlinePinned] the running panel is
/// drawn inside the message (use it until a [CprPinnedHost] is mounted above
/// the composer; then pass false and the card only shows a note).
void registerCprTemplate(TemplateRegistry r, {bool inlinePinned = true}) {
  r.register('cpr', (context, scope) => CprCard(scope: scope, inlinePinned: inlinePinned));
}

/// DS `CprCard`: before start (variant switch, rate, Start). While the
/// instructor runs it shows [CprPinned] inline or a note.
class CprCard extends ConsumerWidget {
  const CprCard({super.key, required this.scope, this.inlinePinned = true});

  final PanelScope scope;
  final bool inlinePinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.bz;
    final panel = scope.panel as CprPanel;
    final config = CprConfig.tryParse(panel.raw);
    if (config == null) return const SizedBox.shrink();
    final session = ref.watch(cprSessionProvider);
    final source = panel.sourceId == null ? null : scope.answer.source(panel.sourceId!);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.running) {
          if (inlinePinned) return CprPinned(session: session);
          return PanelCard(
            title: cprTitle,
            child: Text('RKO trwa. Panel jest przypięty nad polem wiadomości.', style: t.chat.copyWith(color: t.ink200)),
          );
        }
        final variant = config.variant(scope.variant);
        return PanelCard(
          title: cprTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (scope.showVariantSwitch && scope.variant != null) ...[
                BzSegmented(
                  options: panel.variantOptions,
                  value: scope.variant!,
                  onChanged: scope.onVariantChanged,
                ),
                SizedBox(height: t.space3),
              ],
              if (variant != null)
                Text(
                  'Tempo ${config.rateBpm} na minutę · ${variant.compressions}:${variant.breaths}',
                  key: const ValueKey('cpr-summary'),
                  style: t.chat.copyWith(color: t.ink200),
                ),
              SizedBox(height: t.space3),
              BzButton(
                label: cprStartLabel,
                icon: LucideIcons.heartPulse,
                variant: BzButtonVariant.primary,
                size: BzButtonSize.xl,
                fullWidth: true,
                onPressed: () => session.start(config, scope.variant),
              ),
              if (source != null) ...[
                SizedBox(height: t.space2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SourceChip(source: source, onTap: () => scope.onOpenSource(source)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Mount above the composer: shows [CprPinned] while the instructor runs and
/// nothing otherwise.
class CprPinnedHost extends ConsumerWidget {
  const CprPinnedHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cprSessionProvider);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => session.running ? CprPinned(session: session) : const SizedBox.shrink(),
    );
  }
}

/// DS `CprPinned`: the running instructor (phase, counter, stopwatch,
/// rescuer change, pause / stop, 112).
class CprPinned extends ConsumerWidget {
  const CprPinned({super.key, required this.session});

  final CprSession session;

  Future<void> _dial(WidgetRef ref) async {
    try {
      await ref.read(callLauncherProvider)(Uri(scheme: 'tel', path: '112'));
    } on Object {
      // The chat call panel carries the fallback hint.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session.snapshot;
        final cfg = session.config;
        final v = session.variant;
        if (s == null || cfg == null || v == null) return const SizedBox.shrink();
        return _body(context, ref, s, cfg, v);
      },
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, CprSnapshot s, CprConfig cfg, CprVariantConfig v) {
    final t = context.bz;
    final paused = s.phase == CprPhase.paused;
    final breathing = s.phase == CprPhase.breathing || s.phase == CprPhase.initialBreaths;
    final inBreaths = breathing || (paused && (s.awaitingTap || s.breathRemaining != null));
    final label = paused
        ? cprPausedLabel
        : (breathing
              ? (s.phase == CprPhase.breathing ? cfg.voice.breaths.toUpperCase() : cprBreathsLabel)
              : cprCompressLabel);
    final counter = inBreaths
        ? (s.breathRemaining != null ? formatCprChange(s.breathRemaining!) : '')
        : '${s.beatInCycle} / ${s.cycleLength}';
    final showChange =
        s.changesDue > 0 && s.sinceChange < cprChangeBannerDuration && cfg.voice.change.isNotEmpty;
    final accent = breathing ? t.signal : t.ink100;

    return DecoratedBox(
      key: const ValueKey('cpr-pinned'),
      decoration: BoxDecoration(
        color: t.bg100,
        border: Border(top: BorderSide(color: t.line150)),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('$cprTitle · ${v.label}', style: t.label.copyWith(color: t.ink100))),
                BzButton(
                  label: '112',
                  variant: BzButtonVariant.sos,
                  size: BzButtonSize.sm,
                  onPressed: () => unawaited(_dial(ref)),
                ),
              ],
            ),
            SizedBox(height: t.space2),
            Row(
              children: [
                _Dots(active: s.phase == CprPhase.compressing ? (s.beatInCycle - 1) % 4 : -1, color: accent),
                SizedBox(width: t.space3),
                Expanded(
                  child: Text(
                    label,
                    key: const ValueKey('cpr-phase'),
                    style: t.title.copyWith(color: accent),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      counter,
                      key: const ValueKey('cpr-counter'),
                      style: t.readout.copyWith(color: accent),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: t.space2),
            if (showChange)
              Padding(
                padding: EdgeInsets.only(bottom: t.space2),
                child: Container(
                  key: const ValueKey('cpr-change-banner'),
                  padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
                  decoration: BoxDecoration(
                    color: t.signalTint,
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                  child: Text(cfg.voice.change, style: t.label.copyWith(color: t.signalInk)),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: t.space1,
              children: [
                Text(
                  'Czas ${formatCprElapsed(s.elapsed)}',
                  key: const ValueKey('cpr-time'),
                  style: t.label.copyWith(color: t.ink200),
                ),
                Text(
                  'Zmiana za ${formatCprChange(s.untilChange)}',
                  key: const ValueKey('cpr-change'),
                  style: t.label.copyWith(color: t.ink200),
                ),
              ],
            ),
            SizedBox(height: t.space3),
            if (breathing) ...[
              BzButton(
                label: cprBreathsDoneLabel,
                variant: BzButtonVariant.primary,
                size: BzButtonSize.xl,
                fullWidth: true,
                onPressed: session.breathsDone,
              ),
              SizedBox(height: t.space2),
            ],
            Row(
              children: [
                Expanded(
                  child: BzButton(
                    label: paused ? cprResumeLabel : cprPauseLabel,
                    size: BzButtonSize.lg,
                    fullWidth: true,
                    onPressed: paused ? session.resume : session.pause,
                  ),
                ),
                SizedBox(width: t.space3),
                Expanded(
                  child: BzButton(
                    label: cprStopLabel,
                    variant: BzButtonVariant.danger,
                    size: BzButtonSize.lg,
                    fullWidth: true,
                    onPressed: session.stop,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.active, required this.color});

  final int active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == active ? color : t.bg300,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
