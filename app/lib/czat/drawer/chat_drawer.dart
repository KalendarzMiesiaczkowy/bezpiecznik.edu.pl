import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_router.dart';
import '../../wspolne/shell/cpr_state.dart';
import '../../wspolne/shell/shell_panels.dart';
import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import '../data/chat_store.dart';
import '../ui/chat_controller.dart';
import 'drawer_groups.dart';

const String drawerNewChat = 'Nowy czat';
const String drawerEmpty = 'Brak zapisanych rozmów.';
const String drawerPrivacyNote = 'Rozmowy są zapisane tylko na tym telefonie.';
const String drawerSettings = 'Ustawienia';
const String drawerLoadError = 'Nie mogę wczytać rozmów.';
const String drawerDeleteError = 'Nie udało się usunąć czatu.';
const String drawerCprBlocked = 'Najpierw zakończ RKO.';

const double _rowHeight = 44;

/// The B+ mark, paths from the design system Logo (1024 x 1024 viewBox):
/// "B" in ink-100, the "+" in signal.
class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.letter, required this.cross});

  final Color letter;
  final Color cross;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1024, size.height / 1024);
    final b = Path()
      ..moveTo(95.21765, 91.696941)
      ..relativeLineTo(631.15681, 0)
      ..relativeCubicTo(71.45612, 0, 194.74089, 70.842779, 194.74089, 216.208439)
      ..relativeCubicTo(0, 126.65827, -111.01762, 193.82089, -152.11256, 202.40789)
      ..relativeCubicTo(64.70919, 11.04043, 159.77956, 76.97633, 159.77956, 202.40789)
      ..relativeCubicTo(0, 180.63371, -168.97992, 219.5819, -190.14075, 219.5819)
      ..lineTo(95.21765, 932.303)
      ..close();
    final plus = Path()
      ..moveTo(432.87444, 270.38444)
      ..lineTo(591.12558, 270.38444)
      ..lineTo(591.12558, 432.87443)
      ..lineTo(753.61557, 432.87443)
      ..lineTo(753.61557, 591.12558)
      ..lineTo(591.12558, 591.12558)
      ..lineTo(591.12558, 753.61556)
      ..lineTo(432.87444, 753.61556)
      ..lineTo(432.87444, 591.12558)
      ..lineTo(270.38444, 591.12558)
      ..lineTo(270.38444, 432.87443)
      ..lineTo(432.87444, 432.87443)
      ..close();
    canvas.drawPath(b, Paint()..color = letter);
    canvas.drawPath(plus, Paint()..color = cross);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.letter != letter || old.cross != cross;
}

/// P1 content (spec panel-1-boczny.md): logo, "Nowy czat", chats grouped by
/// day, privacy note and "Ustawienia". Rendered inside `PanelHost`.
class ChatDrawer extends ConsumerWidget {
  const ChatDrawer({super.key});

  void _close(WidgetRef ref) => ref.read(shellPanelsProvider.notifier).closeDrawer();

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  void _newChat(WidgetRef ref) {
    final chat = ref.read(chatControllerProvider.notifier);
    // An empty current chat is reused, not duplicated.
    if (!ref.read(chatControllerProvider).isEmpty) chat.newChat();
    _close(ref);
  }

  void _open(WidgetRef ref, ChatSummary c) {
    if (ref.read(chatControllerProvider).chatId != c.id) {
      ref.read(chatControllerProvider.notifier).openChat(c.id);
    }
    _close(ref);
  }

  void _askDelete(BuildContext context, WidgetRef ref, ChatSummary c) {
    final current = ref.read(chatControllerProvider).chatId == c.id;
    if (current && ref.read(cprActiveProvider)) {
      _snack(context, drawerCprBlocked);
      return;
    }
    final panels = ref.read(shellPanelsProvider.notifier);
    panels.openDialog(
      (_) => _DeleteDialog(
        title: c.title,
        onCancel: panels.closeDialog,
        onConfirm: () async {
          panels.closeDialog();
          try {
            await ref.read(chatStoreProvider).deleteChat(c.id);
          } on Object {
            if (context.mounted) _snack(context, drawerDeleteError);
            return;
          }
          if (ref.read(chatControllerProvider).chatId == c.id) {
            ref.read(chatControllerProvider.notifier).newChat();
          }
          ref.read(chatRevisionProvider.notifier).bump();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bz = context.bz;
    final chats = ref.watch(chatListProvider);
    final currentId = ref.watch(chatControllerProvider.select((s) => s.chatId));
    final now = DateTime.now();

    Widget list;
    if (chats.hasError) {
      list = _Note(drawerLoadError);
    } else if (!chats.hasValue) {
      // Skeleton of three rows while the first load runs.
      list = Column(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: _rowHeight - 16,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: bz.overlayHover, borderRadius: BorderRadius.circular(10)),
            ),
        ],
      );
    } else if (chats.requireValue.isEmpty) {
      list = _Note(drawerEmpty);
    } else {
      final items = <Object>[
        for (final s in groupChats(chats.requireValue, now)) ...[s.heading, ...s.chats],
      ];
      list = ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          if (item is String) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(item, style: bz.caption.copyWith(color: bz.ink300)),
            );
          }
          final c = item as ChatSummary;
          return _Row(
            label: c.title,
            semanticLabel: '${c.title}. Przytrzymaj, aby usunąć.',
            selected: c.id == currentId,
            onTap: () => _open(ref, c),
            onLongPress: () => _askDelete(context, ref, c),
          );
        },
      );
    }

    return Semantics(
      label: 'Lista rozmów',
      container: true,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room for SOS, which stays above the panel at the top right.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  key: const Key('drawer-logo'),
                  width: 36,
                  height: 36,
                  child: Semantics(
                    label: 'Bezpiecznik',
                    image: true,
                    child: ExcludeSemantics(
                      child: CustomPaint(painter: _LogoPainter(letter: bz.ink100, cross: bz.signal)),
                    ),
                  ),
                ),
              ),
            ),
            _Row(
              label: drawerNewChat,
              icon: LucideIcons.squarePen,
              onTap: () => _newChat(ref),
            ),
            Expanded(child: list),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(drawerPrivacyNote, style: bz.caption.copyWith(color: bz.ink300)),
            ),
            _Row(
              label: drawerSettings,
              icon: LucideIcons.settings,
              onTap: () {
                _close(ref);
                ref.read(appRouterProvider).go(settingsRoutePath);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Align(
      alignment: Alignment.topLeft,
      child: Text(text, style: context.bz.chat.copyWith(color: context.bz.ink200, fontSize: 15)),
    ),
  );
}

/// 44 px borderless row: optional icon, one-line title, selection by fill.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.onTap,
    this.icon,
    this.onLongPress,
    this.selected = false,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          height: _rowHeight,
          child: Material(
            color: selected ? bz.overlayPress : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(10),
              splashFactory: NoSplash.splashFactory,
              highlightColor: bz.overlayPress,
              hoverColor: bz.overlayHover,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (icon != null) ...[Icon(icon, size: 20, color: bz.ink100), const SizedBox(width: 12)],
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bz.chat.copyWith(fontSize: 15, height: 20 / 15, color: bz.ink100),
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

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.title, required this.onCancel, required this.onConfirm});

  final String title;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      // Swallows taps so the scrim underneath does not dismiss the dialog.
      child: GestureDetector(
        onTap: () {},
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: bz.bg200, borderRadius: BorderRadius.circular(bz.radiusLg)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Usunąć czat?', style: bz.title),
              const SizedBox(height: 8),
              Text('„$title” zniknie z telefonu na zawsze.', style: bz.chat.copyWith(color: bz.ink200)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BzButton(label: 'Anuluj', variant: BzButtonVariant.ghost, onPressed: onCancel),
                  const SizedBox(width: 8),
                  BzButton(label: 'Usuń', variant: BzButtonVariant.dangerSolid, onPressed: onConfirm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
