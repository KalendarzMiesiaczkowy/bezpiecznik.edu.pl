import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../wspolne/theme/bz_buttons.dart';
import '../wspolne/theme/bz_theme.dart';
import 'pack.dart';
import 'pack_controller.dart';

// Copy: ekran-0-pierwsze-uruchomienie.md (`onb.pkg.*`) where it exists; the
// title is the owner's wording (2026-11-21).
const packStripTitle = 'Przygotowuję środowisko';
const packStripWaitWifiTitle = 'Czekam na Wi-Fi'; // onb.pkg.waitWifi
const packStripUseCellular = 'Pobierz przez sieć komórkową'; // onb.pkg.useCellular
const packStripErrorTitle = 'Pobieranie przerwane';
const packStripErrorDetail = 'Sprawdź internet. To, co już pobrane, zostaje w telefonie.';
const packStripNoSpaceTitle = 'Za mało miejsca w telefonie';
const packStripRetry = 'Ponów'; // onb.pkg.state.error
const packStripVerifying = 'Sprawdzam pobrany plik…';
const packStripMapWaits = 'Mapa pobierze się po kroku z lokalizacją.';
const packStripDoneTitle = 'Środowisko gotowe';
const packStripDoneDetail = 'Wszystko jest w telefonie. Działa bez internetu.';

/// What the strip says for [state]; pure, so the wording is unit-tested.
class PackStripView {
  const PackStripView({
    required this.title,
    required this.detail,
    this.fraction,
    this.done = false,
    this.problem = false,
    this.actionLabel,
    this.action,
  });

  final String title;
  final String detail;

  /// Overall progress 0..1; null hides the bar and the percentage.
  final double? fraction;
  final bool done;

  /// Needs the user (error, no space): title in the warning colour.
  final bool problem;
  final String? actionLabel;

  /// Which controller call the button makes.
  final PackStripAction? action;
}

enum PackStripAction { retry, allowCellular }

/// "1,2 z 2,6 GB" / "48 z 101 MB".
String _amount(int received, int total) {
  final unit = formatPackSize(total).split(' ').last;
  final whole = formatPackSize(total).split(' ').first;
  final part = unit == 'GB'
      ? (received / 1e9).toStringAsFixed(1).replaceAll('.', ',')
      : '${(received / 1e6).round()}';
  return '$part z $whole $unit';
}

/// Null when there is nothing to show (not started, no packs in this build).
PackStripView? packStripView(PacksState state) {
  if (!state.started || state.packs.isEmpty) return null;
  final total = formatPackSize(state.totalBytes);

  final noSpace = state.firstIn(PackPhase.noSpace);
  if (noSpace != null) {
    return PackStripView(
      title: packStripNoSpaceTitle,
      detail: 'Potrzeba ok. $total. Zwolnij miejsce i ponów.',
      problem: true,
      actionLabel: packStripRetry,
      action: PackStripAction.retry,
    );
  }
  if (state.firstIn(PackPhase.error) != null) {
    return PackStripView(
      title: packStripErrorTitle,
      detail: packStripErrorDetail,
      fraction: state.fraction,
      problem: true,
      actionLabel: packStripRetry,
      action: PackStripAction.retry,
    );
  }
  final active = state.firstIn(PackPhase.downloading);
  if (active != null) {
    return PackStripView(
      title: packStripTitle,
      detail: 'Pobieram ${active.pack.label} · ${_amount(active.received, active.pack.bytes)}',
      fraction: state.fraction,
    );
  }
  if (state.firstIn(PackPhase.verifying) != null) {
    return PackStripView(title: packStripTitle, detail: packStripVerifying, fraction: state.fraction);
  }
  if (state.firstIn(PackPhase.waitingWifi) != null) {
    return PackStripView(
      title: packStripWaitWifiTitle,
      detail: 'Do pobrania: $total.',
      fraction: state.fraction,
      actionLabel: packStripUseCellular,
      action: PackStripAction.allowCellular,
    );
  }
  if (state.firstIn(PackPhase.waiting) != null) {
    return PackStripView(title: packStripTitle, detail: packStripMapWaits, fraction: state.fraction);
  }
  if (state.wanted.isEmpty) return null; // everything skipped: nothing to report
  return const PackStripView(
    title: packStripDoneTitle,
    detail: packStripDoneDetail,
    done: true,
  );
}

/// Progress of the background pack download: title + percentage, a 6 dp bar
/// and one detail line. Renders nothing before the download starts.
///
/// Pinned above the onboarding buttons and reused in Settings.
class PackProgressStrip extends ConsumerWidget {
  const PackProgressStrip({super.key, this.padding = EdgeInsets.zero, this.compact = false});

  /// Applied only when the strip is visible.
  final EdgeInsets padding;

  /// One-line title + bar, no detail line: for steps where the content above
  /// needs the height (the profile form).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = packStripView(ref.watch(packsProvider));
    if (view == null) return const SizedBox.shrink();
    final bz = context.bz;
    final fraction = view.fraction;
    final percent = fraction == null ? null : '${(fraction * 100).floor()}%';
    final controller = ref.read(packsProvider.notifier);

    return Padding(
      padding: padding,
      child: Column(
        key: const Key('pack-strip'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // One spoken unit; the percentage is not a live region (it would
          // interrupt the screen reader several times a second).
          Semantics(
            container: true,
            label: [view.title, ?percent, view.detail].join('. '),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (view.done) ...[
                      Icon(LucideIcons.check, size: 18, color: bz.verified),
                      SizedBox(width: bz.space2),
                    ],
                    Expanded(
                      child: Text(
                        view.title,
                        maxLines: compact ? 1 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: bz.label.copyWith(color: view.problem ? bz.signal : bz.ink100),
                      ),
                    ),
                    if (percent != null)
                      Text(
                        percent,
                        style: bz.label.copyWith(
                          color: bz.ink200,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                if (fraction != null) ...[
                  SizedBox(height: bz.space2),
                  PackProgressBar(fraction: fraction),
                ],
                if (!compact) ...[
                  SizedBox(height: bz.space2),
                  Text(view.detail, style: bz.caption.copyWith(color: bz.ink200)),
                ],
              ],
            ),
          ),
          if (view.actionLabel != null) ...[
            SizedBox(height: bz.space2),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: bz.minTouchTarget),
                child: BzButton(
                  key: const Key('pack-strip-action'),
                  label: view.actionLabel,
                  size: BzButtonSize.lg,
                  onPressed: () => switch (view.action!) {
                    PackStripAction.allowCellular => controller.allowCellular(),
                    PackStripAction.retry => _retryAll(ref),
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _retryAll(WidgetRef ref) {
    final controller = ref.read(packsProvider.notifier);
    for (final s in ref.read(packsProvider).packs) {
      if (s.phase == PackPhase.error || s.phase == PackPhase.noSpace) controller.retry(s.pack.id);
    }
  }
}

/// 6 dp bar: `bg-300` track, `ink-100` fill (DS `ProgressBar`). The fill
/// eases to the new value unless the system asks for reduced motion.
class PackProgressBar extends StatelessWidget {
  const PackProgressBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final still = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: ColoredBox(
          color: bz.bg300,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fraction.clamp(0.0, 1.0)),
            duration: still ? Duration.zero : const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            builder: (context, value, _) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                key: const Key('pack-strip-fill'),
                widthFactor: value,
                heightFactor: 1,
                child: ColoredBox(color: bz.ink100),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
