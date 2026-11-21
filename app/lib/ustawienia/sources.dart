import 'package:material_ui/material_ui.dart';

import '../wspolne/theme/bz_theme.dart';

/// One row of "Źródła" (spec: title, publisher, release date, licence).
class SourceInfo {
  const SourceInfo(this.title, this.publisher, this.date, this.license);
  final String title;
  final String publisher;
  final String date;
  final String license;
}

const _toConfirm = 'do potwierdzenia';

/// Knowledge and map data sources (`04-dane/zrodla-wiedzy.md`, `dane-mapy.md`,
/// `licencje.md`).
const appSources = <SourceInfo>[
  SourceInfo('Poradnik bezpieczeństwa', 'RCB, MON, MSWiA', '2025', _toConfirm),
  SourceInfo('„Nim nadejdzie dzień”', 'Akademia Pożarnicza', 'brak daty', _toConfirm),
  SourceInfo('Procedury i materiały PSP', 'Państwowa Straż Pożarna', 'brak daty', _toConfirm),
  SourceInfo('Wytyczne resuscytacji 2025', 'Polska Rada Resuscytacji, ERC', '2025', _toConfirm),
  SourceInfo('OpenStreetMap', 'Współtwórcy OpenStreetMap', 'dane z 2026', 'ODbL'),
];

const osmAttribution = '© OpenStreetMap contributors';

/// Bottom sheet "Źródła": guides and data the app content comes from.
void showSourcesSheet(BuildContext context) {
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
