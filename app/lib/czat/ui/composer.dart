import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';

const String composerHint = 'Opisz sytuację…';
const String composerSendLabel = 'Wyślij';
const String composerStopLabel = 'Zatrzymaj';

/// Message length limit (spec "Pole wiadomości").
const int composerMaxLength = 1000;

/// DS `Composer`: pill (radius 28, min 52 dp), grows to 4 lines, Enter = new
/// line. Send is always visible (also while generating: sending then
/// interrupts); Stop appears left of the field only while generating.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.generating,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final bool generating;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  bool get _canSend => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    if (!_canSend) return;
    final text = _controller.text;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      decoration: BoxDecoration(
        color: t.bg200,
        border: Border.all(color: t.line150),
        borderRadius: BorderRadius.circular(t.radiusXl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.generating)
            _RoundAction(
              key: const Key('composer-stop'),
              icon: LucideIcons.square,
              label: composerStopLabel,
              onTap: widget.onStop,
              fill: t.bg300,
              color: t.ink100,
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space2, vertical: 10),
              child: TextField(
                key: const Key('composer-field'),
                controller: _controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                maxLength: composerMaxLength,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(composerMaxLength)],
                style: t.chat.copyWith(fontSize: 16, height: 24 / 16),
                cursorColor: t.ink100,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                  hintText: composerHint,
                  hintStyle: t.chat.copyWith(fontSize: 16, height: 24 / 16, color: t.ink300),
                ),
              ),
            ),
          ),
          _RoundAction(
            key: const Key('composer-send'),
            icon: LucideIcons.arrowUp,
            label: composerSendLabel,
            onTap: _canSend ? _send : null,
            fill: t.action,
            color: t.onAction,
          ),
        ],
      ),
    );
  }
}

/// 40 dp circle with a 48 dp hit area.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.fill,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: t.minTouchTarget,
          height: t.minTouchTarget,
          child: Center(
            child: Opacity(
              opacity: onTap == null ? 0.38 : 1,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
