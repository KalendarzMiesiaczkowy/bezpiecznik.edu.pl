import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../czat/templates/call/call_panel_view.dart'
    show callLauncherProvider;
import '../../czat/templates/panel_card.dart';
import '../../czat/templates/panel_model.dart';
import '../../czat/templates/template_registry.dart';
import '../../czat/ui/chat_controller.dart';
import '../ui/rescue_answer.dart';
import '../../wspolne/shell/cpr_state.dart' show formatCprElapsed;
import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'cpr_config.dart';
import 'cpr_engine.dart';
import 'cpr_session.dart';

/// Copy of the instructor (Polish, per `instruktor-rko.md`).
const String cprTitle = 'Instruktor RKO';

/// Short name in the pinned header ("RKO · Dorosły").
const String cprShortTitle = 'RKO';
const String cprStartLabel = 'Zacznij uciskanie';
const String cprPauseLabel = 'Pauza';
const String cprResumeLabel = 'Wznów';
const String cprStopLabel = 'Zakończ';
const String cprBreathsDoneLabel = 'Dalej';
const String cprAedReminderLabel = 'Poproś kogoś o AED';

/// Opens the AED card in the chat (hidden without `aed_card_id`).
const String cprAedHowLabel = 'Jak użyć AED';
const String cprAedDoneLabel = 'Ukryj przypomnienie o AED';

/// Short in-chat notice while the pinned instructor runs (spec: szablony-czatu.md, CprPinned).
const String cprRunningNotice = 'Instruktor RKO działa ↓';
const String cprCompressLabel = 'UCISKAJ';

/// Initial rescue breaths: neutral label; the count (card data
/// `initial_breaths`) is shown in the counter slot, like the compressions.
const String cprInitialBreathsLabel = 'Oddechy ratownicze';
const String cprPausedLabel = 'PAUZA';

/// `m:ss` for the change countdown ("Zmiana za 0:18").
String formatCprChange(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// How long the "Zmiana ratownika" banner stays after the prompt.
const Duration cprChangeBannerDuration = Duration(seconds: 10);

/// Registers the `cpr` template. With [inlinePinned] the running panel is
/// drawn inside the message (use it until a [CprPinnedHost] is mounted above
/// the composer; then pass false and the card only shows a note).
void registerCprTemplate(TemplateRegistry r, {bool inlinePinned = true}) {
  r.register(
    'cpr',
    (context, scope) => CprCard(scope: scope, inlinePinned: inlinePinned),
  );
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
    final source = panel.sourceId == null
        ? null
        : scope.answer.source(panel.sourceId!);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.running) {
          if (inlinePinned) return CprPinned(session: session);
          return PanelCard(
            title: cprTitle,
            child: Text(
              cprRunningNotice,
              style: t.chat.copyWith(color: t.ink200),
            ),
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
                  '${variant.label} · ${config.rateBpm}/min · ${variant.compressions}:${variant.breaths}',
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
                  child: SourceChip(
                    source: source,
                    onTap: () => scope.onOpenSource(source),
                  ),
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
      builder: (context, _) => session.running
          ? CprPinned(session: session)
          : const SizedBox.shrink(),
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

  /// Inserts the AED card as a new assistant message; the session keeps
  /// running and stays pinned.
  Future<void> _insertAedCard(WidgetRef ref, String cardId) async {
    try {
      final service = await ref.read(rescueAnswerServiceProvider.future);
      final answer = service.answerForCard(
        cardId,
        variant: session.variant?.id,
      );
      if (answer == null) return;
      ref.read(chatControllerProvider.notifier).insertAssistantAnswer(answer);
    } on Object {
      // Card assets failed to load: the instructor keeps running untouched.
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
        if (s == null || cfg == null || v == null) {
          return const SizedBox.shrink();
        }
        return _body(context, ref, s, cfg, v);
      },
    );
  }

  Widget _aedRowBody(
    BuildContext context,
    WidgetRef ref,
    CprConfig cfg,
    bool large,
  ) {
    final t = context.bz;
    final text = Text(
      cprAedReminderLabel,
      style: t.label.copyWith(color: t.ink100),
    );
    final how = cfg.aedCardId == null
        ? null
        : BzButton(
            key: const ValueKey('cpr-aed-how'),
            label: cprAedHowLabel,
            variant: BzButtonVariant.ghost,
            size: BzButtonSize.md,
            onPressed: () => unawaited(_insertAedCard(ref, cfg.aedCardId!)),
          );
    final check = BzButton(
      icon: LucideIcons.check,
      semanticLabel: cprAedDoneLabel,
      variant: BzButtonVariant.ghost,
      size: BzButtonSize.md,
      onPressed: session.dismissAedReminder,
    );
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: t.space2, right: t.space3),
            child: text,
          ),
          Wrap(children: [?how, check]),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: text),
        ?how,
        check,
      ],
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    CprSnapshot s,
    CprConfig cfg,
    CprVariantConfig v,
  ) {
    final t = context.bz;
    final paused = s.phase == CprPhase.paused;
    final breathing =
        s.phase == CprPhase.breathing || s.phase == CprPhase.initialBreaths;
    final inBreaths =
        breathing || (paused && (s.awaitingTap || s.breathRemaining != null));
    final breathLeft = s.breathRemaining;
    final breathTime = breathLeft == null
        ? null
        : formatCprChange(Duration(seconds: ceilSeconds(breathLeft)!));
    final String label;
    if (paused) {
      label = cprPausedLabel;
    } else if (s.phase == CprPhase.breathing) {
      // "Dwa oddechy · 0:08": card text plus the countdown of a timed phase.
      label = breathTime == null
          ? cfg.voice.breaths
          : '${cfg.voice.breaths} · $breathTime';
    } else if (s.phase == CprPhase.initialBreaths) {
      label = cprInitialBreathsLabel;
    } else {
      label = cprCompressLabel;
    }
    final counter = s.phase == CprPhase.initialBreaths
        ? '${v.initialBreaths}'
        : inBreaths
        ? ''
        : '${s.beatInCycle} / ${s.cycleLength}';
    final showChange =
        s.changesDue > 0 &&
        s.sinceChange < cprChangeBannerDuration &&
        cfg.voice.change.isNotEmpty;
    final accent = breathing ? t.signal : t.ink100;

    // Large text: the AED reminder wraps to two lines instead of overflowing.
    final large = MediaQuery.textScalerOf(context).scale(15) > 15 * 1.25;
    final metaStyle = t.label.copyWith(
      color: t.ink300,
      fontSize: 14,
      height: 20 / 14,
    );

    return DecoratedBox(
      key: const ValueKey('cpr-pinned'),
      decoration: BoxDecoration(
        color: t.bg200,
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusLg)),
        boxShadow: t.shadowFloat,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(t.space4, t.space1, t.space4, t.space2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: the 112 pill keeps a 48 dp hit area (BzButton pads to it).
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$cprShortTitle · ${v.label}',
                    style: t.label.copyWith(color: t.ink100),
                  ),
                ),
                BzButton(
                  key: const ValueKey('cpr-112'),
                  label: '112',
                  variant: BzButtonVariant.sos,
                  size: BzButtonSize.sm,
                  onPressed: () => unawaited(_dial(ref)),
                ),
              ],
            ),
            Row(
              children: [
                _Dots(
                  active: s.phase == CprPhase.compressing
                      ? (s.beatInCycle - 1) % 4
                      : -1,
                  color: accent,
                ),
                SizedBox(width: t.space3),
                Expanded(
                  // One line, never broken mid-phrase: shrinks when too wide.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      key: const ValueKey('cpr-phase'),
                      maxLines: 1,
                      softWrap: false,
                      style: t.title.copyWith(
                        color: t.ink100,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: t.space3),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      counter,
                      key: const ValueKey('cpr-counter'),
                      style: t.readout.copyWith(color: t.ink100),
                    ),
                  ),
                ),
              ],
            ),
            if (showChange)
              Padding(
                padding: EdgeInsets.only(top: t.space2),
                child: Container(
                  key: const ValueKey('cpr-change-banner'),
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space3,
                    vertical: t.space2,
                  ),
                  decoration: BoxDecoration(
                    color: t.signalTint,
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                  child: Text(
                    cfg.voice.change,
                    style: t.label.copyWith(color: t.signalInk),
                  ),
                ),
              ),
            // One meta line (the variant is already in the header).
            Padding(
              padding: EdgeInsets.only(top: t.space1),
              child: Wrap(
                spacing: t.space2,
                children: [
                  Text(
                    'Czas ${formatCprElapsed(s.elapsed)}',
                    key: const ValueKey('cpr-time'),
                    style: metaStyle,
                  ),
                  Text('·', style: metaStyle),
                  Text(
                    'Zmiana za ${formatCprChange(s.untilChange)}',
                    key: const ValueKey('cpr-change'),
                    style: metaStyle,
                  ),
                ],
              ),
            ),
            SizedBox(height: t.space1),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: t.space2,
              children: [
                if (breathing)
                  BzButton(
                    label: cprBreathsDoneLabel,
                    variant: BzButtonVariant.secondary,
                    size: BzButtonSize.md,
                    onPressed: session.breathsDone,
                  ),
                BzButton(
                  label: paused ? cprResumeLabel : cprPauseLabel,
                  variant: BzButtonVariant.ghost,
                  size: BzButtonSize.md,
                  onPressed: paused ? session.resume : session.pause,
                ),
                BzButton(
                  label: cprStopLabel,
                  variant: BzButtonVariant.ghost,
                  size: BzButtonSize.md,
                  onPressed: session.stop,
                ),
              ],
            ),
            if (session.aedReminderVisible)
              Container(
                key: const ValueKey('cpr-aed-row'),
                padding: EdgeInsets.only(left: t.space3),
                decoration: BoxDecoration(
                  color: t.overlayHover,
                  borderRadius: BorderRadius.circular(t.radiusMd),
                ),
                child: _aedRowBody(context, ref, cfg, large),
              )
            else if (cfg.aedCardId case final aedId?)
              Align(
                alignment: Alignment.centerLeft,
                child: BzButton(
                  key: const ValueKey('cpr-aed-how'),
                  label: cprAedHowLabel,
                  variant: BzButtonVariant.ghost,
                  size: BzButtonSize.md,
                  onPressed: () => unawaited(_insertAedCard(ref, aedId)),
                ),
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
