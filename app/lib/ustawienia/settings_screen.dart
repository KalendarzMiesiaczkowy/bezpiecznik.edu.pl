import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_router.dart';
import '../czat/drawer/bz_logo.dart';
import '../paczki/pack_controller.dart';
import '../paczki/pack_progress_strip.dart';
import '../profil/section_card.dart';
import '../wspolne/theme/bz_buttons.dart';
import '../wspolne/theme/bz_theme.dart';
import '../wspolne/theme/top_fade.dart';
import 'data_wipe.dart';
import 'settings_store.dart';
import 'sources.dart';

/// E3 (MVP rows): Profil, Wygląd (text size), AI (Tryb bez AI, Głos
/// instrukcji), Prywatność (Usuń wszystkie dane), O aplikacji. The theme row
/// is hidden in the MVP.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usuń wszystkie dane'),
        content: const Text(
          'Usunąć profil, wszystkie czaty i ustawienia? Pobrane mapy i baza wiedzy zostaną.',
        ),
        actions: [
          BzButton(
            label: 'Anuluj',
            variant: BzButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          BzButton(
            key: const Key('set-delete-all-confirm'),
            label: 'Usuń wszystko',
            variant: BzButtonVariant.dangerSolid,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await wipeAllUserData(ref);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nie udało się usunąć danych. Spróbuj ponownie.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bz = context.bz;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final notifier = ref.read(settingsProvider.notifier);
    // Shown only when this build downloads packs and the download started.
    final hasPacks = packStripView(ref.watch(packsProvider)) != null;

    Widget card({
      String? title,
      IconData? icon,
      required List<Widget> children,
    }) => Padding(
      padding: EdgeInsets.fromLTRB(bz.space4, bz.space4, bz.space4, 0),
      child: SectionCard(title: title, icon: icon, children: children),
    );
    const rowPadding = EdgeInsets.zero;
    Widget divider() => Divider(height: 1, thickness: 1, color: bz.line100);

    return Scaffold(
      backgroundColor: bz.bg000,
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, 96, 0, bz.space6),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: bz.space4),
                  child: Text('Ustawienia', style: bz.title),
                ),
                card(
                  children: [
                    ListTile(
                      key: const Key('set-profile'),
                      contentPadding: rowPadding,
                      leading: const Icon(LucideIcons.house),
                      title: const Text('Profil domu'),
                      trailing: const Icon(LucideIcons.chevronRight),
                      onTap: () => context.go(profileRoutePath),
                    ),
                  ],
                ),
                card(
                  title: 'Wygląd',
                  icon: LucideIcons.type,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rozmiar tekstu', style: bz.chat),
                        SizedBox(height: bz.space2),
                        Container(
                          padding: EdgeInsets.all(bz.space1),
                          decoration: BoxDecoration(
                            color: bz.bg200,
                            borderRadius: BorderRadius.circular(bz.radiusFull),
                          ),
                          child: Row(
                            children: [
                              for (final o in TextSizeOption.values)
                                Expanded(
                                  child: Semantics(
                                    button: true,
                                    selected: o == settings.textSize,
                                    excludeSemantics: true,
                                    label: o.label,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => notifier.setTextSize(o),
                                      child: AnimatedContainer(
                                        duration: bz.durationFast,
                                        curve: bz.easeInOut,
                                        constraints: const BoxConstraints(
                                          minHeight: 48,
                                        ),
                                        alignment: Alignment.center,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: o == settings.textSize
                                              ? bz.bg300
                                              : null,
                                          border: o == settings.textSize
                                              ? Border.all(color: bz.line150)
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            bz.radiusFull,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: bz.space1,
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              o.label,
                                              key: Key(
                                                'set-text-size-${o.name}',
                                              ),
                                              maxLines: 1,
                                              softWrap: false,
                                              style: bz.label.copyWith(
                                                color: o == settings.textSize
                                                    ? bz.ink100
                                                    : bz.ink200,
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
                        ),
                      ],
                    ),
                  ],
                ),
                card(
                  title: 'AI i bateria',
                  icon: LucideIcons.sparkles,
                  children: [
                    SwitchListTile(
                      key: const Key('set-no-ai'),
                      contentPadding: rowPadding,
                      title: const Text('Tryb bez AI'),
                      subtitle: const Text(
                        'Czat pokazuje tylko fragmenty źródeł, bez generowania odpowiedzi.',
                      ),
                      value: settings.noAiMode,
                      onChanged: notifier.setNoAiMode,
                    ),
                    divider(),
                    SwitchListTile(
                      key: const Key('set-voice'),
                      contentPadding: rowPadding,
                      title: const Text('Głos instrukcji'),
                      value: settings.voiceEnabled,
                      onChanged: notifier.setVoiceEnabled,
                    ),
                  ],
                ),
                if (hasPacks)
                  card(
                    title: 'Paczki danych',
                    icon: LucideIcons.download,
                    children: [
                      PackProgressStrip(padding: EdgeInsets.symmetric(vertical: bz.space2)),
                    ],
                  ),
                card(
                  title: 'Prywatność',
                  icon: LucideIcons.shieldCheck,
                  children: [
                    Text(
                      'Profil, czaty i lokalizacja zostają w telefonie. Wysyłasz je tylko ty, np. SMS-em do bliskich. '
                      'Nie ma konta ani serwera. Sieć służy tylko do pobierania paczek.',
                      style: bz.caption.copyWith(color: bz.ink200),
                    ),
                    SizedBox(height: bz.space3),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BzButton(
                        key: const Key('set-delete-all'),
                        label: 'Usuń wszystkie dane',
                        icon: LucideIcons.trash2,
                        variant: BzButtonVariant.danger,
                        onPressed: () => _deleteAll(context, ref),
                      ),
                    ),
                  ],
                ),
                card(
                  title: 'O aplikacji',
                  icon: LucideIcons.info,
                  children: [
                    ListTile(
                      key: const Key('set-sources'),
                      contentPadding: rowPadding,
                      leading: const Icon(LucideIcons.bookOpen),
                      title: const Text('Źródła'),
                      trailing: const Icon(LucideIcons.chevronRight),
                      onTap: () => showSourcesSheet(context),
                    ),
                    divider(),
                    SizedBox(height: bz.space3),
                    Row(
                      key: const Key('set-about'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BzLogo(size: 40),
                        SizedBox(width: bz.space3),
                        Expanded(
                          child: Text(
                            'Bezpiecznik: poradniki kryzysowe offline, w twoim telefonie.',
                            style: bz.chat,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: bz.space3),
                    Text(
                      'Bezpiecznik nie zastępuje 112 ani służb.',
                      style: bz.step,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const TopFade(),
        ],
      ),
    );
  }
}
