import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_router.dart';
import '../wspolne/theme/bz_buttons.dart';
import '../wspolne/theme/bz_theme.dart';
import 'data_wipe.dart';
import 'settings_store.dart';
import 'sources.dart';

const appVersion = '1.0.0';

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
        content: const Text('Usunąć profil, wszystkie czaty i ustawienia? Pobrane mapy i baza wiedzy zostaną.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Anuluj')),
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
      messenger.showSnackBar(const SnackBar(content: Text('Nie udało się usunąć danych. Spróbuj ponownie.')));
    }
  }

  void _showSources(BuildContext context) {
    final bz = context.bz;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Źródła', style: bz.title),
            const SizedBox(height: 12),
            for (final s in appSources)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, style: bz.chat),
                    Text('${s.publisher} · ${s.date} · licencja: ${s.license}', style: bz.caption),
                  ],
                ),
              ),
            Text(osmAttribution, style: bz.caption),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bz = context.bz;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final notifier = ref.read(settingsProvider.notifier);

    Widget section(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Semantics(header: true, child: Text(t.toUpperCase(), style: bz.label.copyWith(color: bz.ink300))),
    );

    return Scaffold(
      backgroundColor: bz.bg000,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 96, 0, 32),
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Ustawienia', style: bz.title)),
            section('Profil'),
            ListTile(
              key: const Key('set-profile'),
              leading: const Icon(LucideIcons.house),
              title: const Text('Profil domu'),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => context.go(profileRoutePath),
            ),
            section('Wygląd'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rozmiar tekstu', style: bz.chat),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: bz.bg200, borderRadius: BorderRadius.circular(bz.radiusFull)),
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
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 48),
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: o == settings.textSize ? bz.bg300 : null,
                                    border: o == settings.textSize ? Border.all(color: bz.line150) : null,
                                    borderRadius: BorderRadius.circular(bz.radiusFull),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        o.label,
                                        key: Key('set-text-size-${o.name}'),
                                        maxLines: 1,
                                        softWrap: false,
                                        style: bz.label.copyWith(color: o == settings.textSize ? bz.ink100 : bz.ink200),
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
                  const SizedBox(height: 8),
                  Text('Tak będzie wyglądał tekst instrukcji.', style: bz.chat),
                ],
              ),
            ),
            section('AI i bateria'),
            SwitchListTile(
              key: const Key('set-no-ai'),
              title: const Text('Tryb bez AI'),
              subtitle: const Text('Czat pokazuje tylko fragmenty źródeł, bez generowania odpowiedzi.'),
              value: settings.noAiMode,
              onChanged: notifier.setNoAiMode,
            ),
            SwitchListTile(
              key: const Key('set-voice'),
              title: const Text('Głos instrukcji'),
              value: settings.voiceEnabled,
              onChanged: notifier.setVoiceEnabled,
            ),
            section('Prywatność'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Profil, czaty i lokalizacja zostają w telefonie. Wysyłasz je tylko ty, np. SMS-em do bliskich. '
                'Nie ma konta ani serwera. Sieć służy tylko do pobierania paczek.',
                style: bz.caption,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BzButton(
                  key: const Key('set-delete-all'),
                  label: 'Usuń wszystkie dane',
                  icon: LucideIcons.trash2,
                  variant: BzButtonVariant.danger,
                  onPressed: () => _deleteAll(context, ref),
                ),
              ),
            ),
            section('O aplikacji'),
            ListTile(
              key: const Key('set-sources'),
              title: const Text('Źródła'),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => _showSources(context),
            ),
            ListTile(title: const Text('Wersja'), subtitle: const Text(appVersion)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Bezpiecznik nie zastępuje 112 ani służb.', style: bz.step),
            ),
          ],
        ),
      ),
    );
  }
}
