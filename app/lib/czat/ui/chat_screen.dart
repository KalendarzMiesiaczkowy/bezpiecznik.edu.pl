import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../ratunek/cpr/cpr_view.dart';
import '../../wspolne/theme/bz_theme.dart';
import 'chat_controller.dart';
import 'composer.dart';
import 'message_view.dart';
import 'quick_actions.dart';

const String emptyChatHeading = 'Co się dzieje?';
const String emptyChatNote = 'Działa bez internetu. Nie zastępuje 112.';
const String newAnswerLabel = '↓ Nowa odpowiedź';

/// E1: the chat. The shell overlay draws the island (top left) and SOS (top
/// right) above this screen, so the list leaves room at the top and scrolls
/// under a soft gradient.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  bool _atBottom = true;

  /// Height of the band covered by the island/SOS; set in build.
  double _listTop = 0;

  /// Id of an answer that arrived while the user was reading higher up.
  String? _unseenAnswerId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    final atBottom = m.pixels >= m.maxScrollExtent - 80;
    if (atBottom != _atBottom || (atBottom && _unseenAnswerId != null)) {
      setState(() {
        _atBottom = atBottom;
        if (atBottom) _unseenAnswerId = null;
      });
    }
    return false;
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: context.bz.durationBase,
        curve: context.bz.easeOut,
      );
    });
  }

  /// Scrolls so the top of the message [id] lands just below the floating
  /// island/SOS band (`_listTop`), not at the raw viewport top where the
  /// island would cover the first line.
  void _toStartOf(String id, {bool retry = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final ctx = _keys[id]?.currentContext;
      if (ctx == null) {
        // The lazy list has not built the item yet (far below a tall
        // neighbour): jump near the end so it gets built, then retry once.
        if (retry) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
          _toStartOf(id, retry: false);
        }
        return;
      }
      final box = ctx.findRenderObject();
      if (box == null) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) return;
      final messages = ref.read(chatControllerProvider).messages;
      final index = messages.indexWhere((m) => m.id == id);
      // Every item but the first carries a top gap; the card itself should
      // start at the band edge.
      final gap = index > 0 ? context.bz.space5 : 0.0;
      final reveal = viewport.getOffsetToReveal(box, 0).offset;
      final pos = _scroll.position;
      final target = (reveal + gap - _listTop).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      _scroll.animateTo(
        target,
        duration: context.bz.durationBase,
        curve: context.bz.easeOut,
      );
    });
  }

  void _onState(ChatState? prev, ChatState next) {
    if (next.saveFailed) {
      ref.read(chatControllerProvider.notifier).ackSaveError();
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text(saveErrorText)));
    }
    final before = prev?.messages ?? const [];
    if (next.messages.length == before.length + 1 &&
        before.isNotEmpty &&
        prev?.chatId == next.chatId) {
      // An assistant message inserted without a question (e.g. the AED card
      // from the CPR instructor): show its start, like a fresh answer.
      final added = next.messages.last;
      if (!added.isUser && !added.isThinking && added.answer != null) {
        _toStartOf(added.id);
        return;
      }
    }
    if (next.messages.length > before.length) {
      // A new question: show it with the thinking bubble.
      _toEnd();
      return;
    }
    if (before.isEmpty || next.messages.isEmpty) return;
    final wasThinking = before.last.isThinking;
    final last = next.messages.last;
    if (wasThinking &&
        !last.isUser &&
        !last.isThinking &&
        last.answer != null) {
      // Spec: scroll to the START of the new answer, not to the end; when the
      // user is reading higher up, only offer the pill.
      if (_atBottom) {
        _toStartOf(last.id);
      } else {
        setState(() => _unseenAnswerId = last.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    ref.listen(chatControllerProvider, _onState);

    // Shell: island/SOS sit at topInset (status bar + 8, at least 48) and are
    // 48 dp high.
    final statusBar = MediaQuery.paddingOf(context).top;
    final topInset = statusBar + 8 > 48 ? statusBar + 8 : 48.0;
    final listTop = topInset + 48 + t.space2;
    _listTop = listTop;

    return Scaffold(
      backgroundColor: t.bg000,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: state.isEmpty
                      ? _EmptyChat(topPadding: listTop, onSend: controller.send)
                      : NotificationListener<ScrollNotification>(
                          onNotification: _onScroll,
                          child: ListView.builder(
                            key: const Key('message-list'),
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(
                              t.space4,
                              listTop,
                              t.space4,
                              t.space4,
                            ),
                            itemCount: state.messages.length,
                            itemBuilder: (context, i) {
                              final m = state.messages[i];
                              return Padding(
                                key: _keyFor(m.id),
                                padding: EdgeInsets.only(
                                  top: i == 0 ? 0 : t.space5,
                                ),
                                child: MessageView(
                                  message: m,
                                  onAnswerChanged: (a) =>
                                      controller.updateAnswer(m.id, a),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                // Running RKO instructor stays pinned above the composer.
                Padding(
                  padding: EdgeInsets.fromLTRB(t.space4, 0, t.space4, t.space2),
                  child: const CprPinnedHost(),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space4,
                    t.space1,
                    t.space4,
                    t.space2 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Composer(
                    generating: state.generating,
                    onSend: controller.send,
                    onStop: controller.stop,
                  ),
                ),
              ],
            ),
          ),
          // Fade under the floating island and SOS (spec E1: content scrolls
          // under them over a soft background gradient). Solid behind the
          // status bar and most of the island so scrolled text never collides
          // with the clock or the island (BG16), then a short fade.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: topInset + 48 + t.space4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [t.bg000, t.bg000, t.bg000.withValues(alpha: 0)],
                    stops: [
                      0,
                      (topInset + 36) / (topInset + 48 + t.space4),
                      1,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_unseenAnswerId != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom:
                      52 +
                      t.space4 +
                      t.space2 +
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: Center(
                  child: _JumpPill(
                    onTap: () {
                      final id = _unseenAnswerId!;
                      setState(() => _unseenAnswerId = null);
                      _toStartOf(id);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.topPadding, required this.onSend});

  final double topPadding;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(t.space4, topPadding, t.space4, t.space4),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - topPadding - t.space4).clamp(
              0.0,
              double.infinity,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                emptyChatHeading,
                textAlign: TextAlign.center,
                style: t.display.copyWith(fontSize: 32, height: 38 / 32),
              ),
              SizedBox(height: t.space5),
              QuickActions(onSend: onSend),
              SizedBox(height: t.space5),
              Text(
                emptyChatNote,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: t.ink300),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JumpPill extends StatelessWidget {
  const _JumpPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Semantics(
      button: true,
      label: newAnswerLabel,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('jump-to-answer'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.bg200,
                border: Border.all(color: t.line150),
                borderRadius: BorderRadius.circular(t.radiusFull),
                boxShadow: t.shadowPop,
              ),
              child: Text(newAnswerLabel, style: t.label),
            ),
          ),
        ),
      ),
    );
  }
}
