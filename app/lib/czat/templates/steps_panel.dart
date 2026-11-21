import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ratunek/ui/card_link_button.dart';
import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'panel_card.dart';
import 'panel_model.dart';
import 'read_aloud.dart';
import 'template_registry.dart';

/// Header shown when every step is checked (spec `steps` "Stany").
const String stepsAllDoneText = 'Wszystko zrobione';

/// Read-aloud button labels (spec `steps`).
const String readAloudStartLabel = 'Czytaj na głos';
const String readAloudStopLabel = 'Zatrzymaj czytanie';

/// `steps`: numbered, checkable steps; a source chip appears under a step only
/// when its source differs from the previous step's (BG18: no repeated chips).
/// The first unchecked step is the current one (bar + bold).
class StepsPanelView extends StatelessWidget {
  const StepsPanelView({super.key, required this.scope});

  final PanelScope scope;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final panel = scope.panel as StepsPanel;
    final items = panel.itemsFor(scope.variant);
    final done = scope.done;
    final indexes = List.generate(items.length, (i) => i);
    final allDone = items.isNotEmpty && indexes.every(done.contains);
    final current = indexes.indexWhere((i) => !done.contains(i));

    return PanelCard(
      title: allDone ? '${panel.title}: $stepsAllDoneText' : panel.title,
      done: allDone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scope.showVariantSwitch && scope.variant != null) ...[
            BzSegmented(
              options: panel.variantOptions,
              value: scope.variant!,
              onChanged: scope.onVariantChanged,
            ),
            SizedBox(height: t.space2),
          ],
          for (var i = 0; i < items.length; i++)
            _StepRow(
              number: i + 1,
              item: items[i],
              source: _chipSource(scope, items, i),
              variant: scope.variant ?? scope.answer.selectedVariant,
              done: done.contains(i),
              current: i == current,
              onChanged: (v) => scope.onDoneChanged(i, v),
              onOpenSource: scope.onOpenSource,
            ),
          if (panel.readAloud && items.isNotEmpty) ...[
            SizedBox(height: t.space2),
            ReadAloudButton(
              texts: [for (final it in items) it.text],
              done: done,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Czytaj na głos" / "Zatrzymaj czytanie". Reads the steps from the current
/// (first unchecked) one onwards; checking the current step moves the speech
/// to the next one. Hidden while no Polish voice is known to be available.
class ReadAloudButton extends ConsumerStatefulWidget {
  const ReadAloudButton({super.key, required this.texts, required this.done});

  final List<String> texts;
  final Set<int> done;

  @override
  ConsumerState<ReadAloudButton> createState() => _ReadAloudButtonState();
}

class _ReadAloudButtonState extends ConsumerState<ReadAloudButton> {
  late final ReadAloudVoice _voice = ref.read(readAloudVoiceProvider);
  bool _available = false;
  bool _speaking = false;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _voice.isAvailable().then((ok) {
      if (mounted && ok) setState(() => _available = true);
    }, onError: (_) {});
  }

  int get _current {
    for (var i = 0; i < widget.texts.length; i++) {
      if (!widget.done.contains(i)) return i;
    }
    return -1;
  }

  @override
  void didUpdateWidget(ReadAloudButton old) {
    super.didUpdateWidget(old);
    if (!_speaking || widget.done.length == old.done.length) return;
    final cur = _current;
    if (cur == -1) {
      _stop();
    } else {
      _start(cur);
    }
  }

  @override
  void dispose() {
    if (_speaking) _voice.stop();
    _run++;
    super.dispose();
  }

  Future<void> _stop() async {
    _run++;
    if (mounted) setState(() => _speaking = false);
    await _voice.stop();
  }

  Future<void> _start(int from) async {
    final run = ++_run;
    await _voice.stop();
    if (!mounted || run != _run) return;
    setState(() => _speaking = true);
    for (var i = from; i < widget.texts.length; i++) {
      if (widget.done.contains(i)) continue;
      await _voice.speak(widget.texts[i]);
      if (!mounted || run != _run) return;
    }
    setState(() => _speaking = false);
  }

  void _toggle() {
    if (_speaking) {
      _stop();
      return;
    }
    final cur = _current;
    if (cur != -1) _start(cur);
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return BzButton(
      label: _speaking ? readAloudStopLabel : readAloudStartLabel,
      icon: _speaking ? LucideIcons.volumeX : LucideIcons.volume2,
      size: BzButtonSize.lg,
      fullWidth: true,
      onPressed: _toggle,
    );
  }
}

/// Source for step [i]'s chip, or null when it equals the previous step's.
SourceRecord? _chipSource(PanelScope scope, List<PanelItem> items, int i) {
  final s = scope.answer.source(items[i].sourceId);
  if (s == null || i == 0) return s;
  final p = scope.answer.source(items[i - 1].sourceId);
  final same =
      p != null &&
      p.docId == s.docId &&
      p.pageLabel == s.pageLabel &&
      p.chipLabel == s.chipLabel;
  return same ? null : s;
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.item,
    required this.source,
    required this.variant,
    required this.done,
    required this.current,
    required this.onChanged,
    required this.onOpenSource,
  });

  final int number;
  final PanelItem item;
  final SourceRecord? source;
  final String? variant;
  final bool done;
  final bool current;
  final ValueChanged<bool> onChanged;
  final void Function(SourceRecord) onOpenSource;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final numBg = done ? t.verifiedTint : (current ? t.signal : t.bg300);
    final numFg = done ? t.verified : (current ? t.signalInk : t.ink200);
    return Padding(
      padding: EdgeInsets.only(bottom: t.space1),
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: current ? t.overlayHover : null,
              borderRadius: BorderRadius.circular(t.radiusMd),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: t.space3, top: 10, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: numBg,
                      shape: BoxShape.circle,
                    ),
                    child: done
                        ? Icon(LucideIcons.check, size: 16, color: numFg)
                        : Text(
                            '$number',
                            style: t.label.copyWith(
                              color: numFg,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                  ),
                  SizedBox(width: t.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.text,
                          style: t.chat.copyWith(
                            height: 28 / 17,
                            fontWeight: current
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: done ? t.ink300 : t.ink100,
                          ),
                        ),
                        if (source != null)
                          SourceChip(
                            source: source!,
                            onTap: () => onOpenSource(source!),
                          ),
                        if (item.cardLinkLabel != null && item.cardLinkId != null)
                          CardLinkButton(
                            label: item.cardLinkLabel!,
                            cardId: item.cardLinkId!,
                            variant: variant,
                          ),
                      ],
                    ),
                  ),
                  // The 48 dp hit area is taller than the 28 dp first line;
                  // lift it so the 24 dp visual box centres on that line
                  // (hit testing follows the transform).
                  Transform.translate(
                    offset: Offset(0, -(t.minTouchTarget - 28) / 2),
                    child: BzCheck(
                      value: done,
                      onChanged: onChanged,
                      label: 'Krok $number: ${item.text}',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (current)
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              width: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.signal,
                  borderRadius: BorderRadius.circular(t.radiusFull),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
