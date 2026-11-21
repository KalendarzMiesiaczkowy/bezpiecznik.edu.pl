/// One row of "Źródła i licencje" (shown on the guides screen) (spec: title, publisher, release date, licence).
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
  SourceInfo(
    '„Nim nadejdzie dzień”',
    'Akademia Pożarnicza',
    'brak daty',
    _toConfirm,
  ),
  SourceInfo(
    'Procedury i materiały PSP',
    'Państwowa Straż Pożarna',
    'brak daty',
    _toConfirm,
  ),
  SourceInfo(
    'Wytyczne resuscytacji 2025',
    'Polska Rada Resuscytacji, ERC',
    '2025',
    _toConfirm,
  ),
  SourceInfo(
    'OpenStreetMap',
    'Współtwórcy OpenStreetMap',
    'dane z 2026',
    'ODbL',
  ),
];

const osmAttribution = '© OpenStreetMap contributors';
