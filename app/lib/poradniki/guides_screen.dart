import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../ustawienia/sources.dart';
import '../wspolne/theme/bz_theme.dart';
import '../wspolne/theme/top_fade.dart';
import 'guide.dart';

// Spec: 02-funkcje/06-poradniki. Copy drafted here (verify: true).
const guidesTitle = 'Poradniki';
const guidesIntro = 'Pełne poradniki, z których korzysta Bezpiecznik. Czytasz je bez internetu.';
const guidesEmpty = 'Ta wersja aplikacji nie ma dołączonych poradników.';
const guidesSourcesTitle = 'Źródła i licencje';

String guideRoutePath(String id) => '/poradniki/$id';

/// List of the bundled guides; a tap opens the reader. Below it the sources
/// and licences the old "Źródła" sheet showed. Back and SOS: `RootOverlay`.
class GuidesScreen extends ConsumerWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bz = context.bz;
    final guides = ref.watch(guidesProvider);
    return Scaffold(
      backgroundColor: bz.bg000,
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(bz.space4, 96, bz.space4, bz.space6),
              children: [
                Text(guidesTitle, style: bz.title),
                SizedBox(height: bz.space2),
                Text(guidesIntro, style: bz.chat.copyWith(color: bz.ink200)),
                SizedBox(height: bz.space4),
                ...switch (guides) {
                  AsyncData(:final value) when value.isEmpty => [
                    Text(guidesEmpty, key: const Key('guides-empty'), style: bz.chat),
                  ],
                  AsyncData(:final value) => [
                    for (final g in value) ...[
                      _GuideTile(guide: g, onTap: () => context.push(guideRoutePath(g.id))),
                      SizedBox(height: bz.space3),
                    ],
                  ],
                  _ => const [SizedBox(height: 48)],
                },
                SizedBox(height: bz.space5),
                Semantics(
                  header: true,
                  child: Text(guidesSourcesTitle, style: bz.label.copyWith(color: bz.ink200)),
                ),
                SizedBox(height: bz.space3),
                for (final s in appSources)
                  Padding(
                    padding: EdgeInsets.only(bottom: bz.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: bz.chat),
                        Text(
                          '${s.publisher} · ${s.date} · licencja: ${s.license}',
                          style: bz.caption.copyWith(color: bz.ink200),
                        ),
                      ],
                    ),
                  ),
                Text(osmAttribution, style: bz.caption.copyWith(color: bz.ink200)),
              ],
            ),
          ),
          const TopFade(),
        ],
      ),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.guide, required this.onTap});

  final Guide guide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Semantics(
      button: true,
      label: '${guide.title}. ${guideMetaText(guide)}',
      excludeSemantics: true,
      child: Material(
        color: bz.bg100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(bz.radiusLg),
          side: BorderSide(color: bz.line150),
        ),
        child: InkWell(
          key: Key('guide-${guide.id}'),
          borderRadius: BorderRadius.circular(bz.radiusLg),
          highlightColor: bz.overlayPress,
          splashColor: Colors.transparent,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: bz.space4, vertical: bz.space3),
              child: Row(
                children: [
                  Icon(LucideIcons.bookOpen, size: 24, color: bz.verified),
                  SizedBox(width: bz.space4),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(guide.title, style: bz.step.copyWith(fontWeight: FontWeight.w700)),
                        SizedBox(height: bz.space1),
                        Text(guideMetaText(guide), style: bz.caption.copyWith(color: bz.ink200)),
                      ],
                    ),
                  ),
                  SizedBox(width: bz.space2),
                  Icon(LucideIcons.chevronRight, size: 20, color: bz.ink200),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
