import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'geo.dart';
import 'points_db.dart';

// Spec: ekran-2-mapa.md, texts table.
const pointConfirmedText = '✓ Potwierdzony'; // map.point.confirmed
String pointUnconfirmedText(String source) =>
    '? Niepotwierdzony. Dane z $source, niesprawdzone przez PSP.'; // map.point.unconfirmed
String pointSourceText(String source, String verifiedAt) =>
    'Źródło: $source, $verifiedAt'; // map.point.source
const pointStaleText = 'Dane sprawdzono ponad rok temu. Mogą być nieaktualne.'; // map.point.stale
const pointAvailabilityUnknownText = 'Dostępność: brak danych'; // map.point.availabilityUnknown
const pointGuideText = 'Prowadź'; // map.point.guide
const pointCompassText = 'Kompas'; // map.point.compass
const nearestTitleText = 'Najbliższe schronienie'; // map.nearest.title
const nearestButtonText = 'Najbliższy schron'; // map.nearest.button
const unconfirmedShortText = 'niepotwierdzony'; // spec: nearest row label
const layerShelterLabel = 'Schrony i ukrycia'; // map.layers.shelters
const emptyViewText = 'Brak punktów w tym widoku.'; // map.empty.view
const noDataText = 'Nie mam danych o punktach w tej okolicy. Pobierz mapę województwa.'; // map.empty.noData

// Drafted (verify:true; source: ekran-2-mapa.md names the kinds, no copy for
// an unnamed point or "24 h" wording beyond the "Całodobowo" example).
const unnamedPointText = 'Punkt bez nazwy'; // verify:true
const open24hText = 'Całodobowo'; // spec example in arkusz `point`

/// Days after which data counts as stale (spec: `POINT_STALE_DAYS`).
const pointStaleDays = 365;

const _kindLabels = {
  'shelter': 'Schron',
  'hiding_place': 'Ukrycie',
  'emergency_shelter': 'Miejsce doraźnego schronienia',
};

String kindLabel(String kind) => _kindLabels[kind] ?? kind;

/// Name, else address, else the fallback label.
String pointTitle(ShelterPoint p) {
  final n = p.name?.trim();
  if (n != null && n.isNotEmpty) return n;
  final a = p.address?.trim();
  if (a != null && a.isNotEmpty) return a;
  return unnamedPointText;
}

String availabilityText(ShelterPoint p) {
  final a = p.availability?.trim();
  if (a != null && a.isNotEmpty) return a;
  if (p.open24h == true) return open24hText;
  return pointAvailabilityUnknownText;
}

bool isStale(String verifiedAt, DateTime now) {
  final d = DateTime.tryParse(verifiedAt);
  return d != null && now.difference(d).inDays > pointStaleDays;
}

/// E2 `point` sheet content (name, address, availability, distance, status,
/// source and date, stale warning, Prowadź and Kompas).
class PointSheet extends StatelessWidget {
  const PointSheet({
    super.key,
    required this.point,
    this.fromLat,
    this.fromLon,
    this.onGuide,
    this.onCompass,
    this.now,
  });

  final ShelterPoint point;
  final double? fromLat;
  final double? fromLon;
  final VoidCallback? onGuide;
  final VoidCallback? onCompass;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final hasFrom = fromLat != null && fromLon != null;
    final dist = hasFrom
        ? haversineM(fromLat!, fromLon!, point.lat, point.lon)
        : point.distanceM;
    String? distanceLine;
    if (dist != null) {
      if (hasFrom) {
        final b = bearingDeg(fromLat!, fromLon!, point.lat, point.lon);
        distanceLine = '${formatDistance(dist)} · ${cardinalName(b)} ${arrowFor(b)}';
      } else {
        distanceLine = formatDistance(dist);
      }
    }
    final stale = isStale(point.verifiedAt, now ?? DateTime.now());
    final btn = Size(bz.minTouchTarget, bz.minTouchTarget);
    return Padding(
      padding: EdgeInsets.all(bz.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kindLabel(point.kind), style: bz.caption.copyWith(color: bz.ink200)),
          Text(pointTitle(point), style: bz.title),
          if (point.address != null && pointTitle(point) != point.address)
            Text(point.address!, style: bz.chat.copyWith(color: bz.ink200)),
          SizedBox(height: bz.space2),
          Text(availabilityText(point), style: bz.label),
          if (distanceLine != null) Text(distanceLine, style: bz.label),
          SizedBox(height: bz.space2),
          Text(
            point.confirmed ? pointConfirmedText : pointUnconfirmedText(point.source),
            style: bz.label.copyWith(color: point.confirmed ? bz.verified : bz.ink100),
          ),
          Text(pointSourceText(point.source, point.verifiedAt),
              style: bz.caption.copyWith(color: bz.ink200)),
          if (stale)
            Text(pointStaleText, style: bz.caption.copyWith(color: bz.highlight)),
          SizedBox(height: bz.space4),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onGuide,
                  style: FilledButton.styleFrom(minimumSize: btn),
                  child: const Text(pointGuideText),
                ),
              ),
              SizedBox(width: bz.space3),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCompass,
                  style: OutlinedButton.styleFrom(minimumSize: btn),
                  child: const Text(pointCompassText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `nearest` sheet: up to 3 rows with marker, title, distance, arrow.
class NearestList extends StatelessWidget {
  const NearestList({
    super.key,
    required this.points,
    required this.onSelect,
    this.fromLat,
    this.fromLon,
  });

  final List<ShelterPoint> points;
  final double? fromLat;
  final double? fromLon;
  final void Function(ShelterPoint) onSelect;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Padding(
      padding: EdgeInsets.all(bz.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nearestTitleText, style: bz.title),
          SizedBox(height: bz.space2),
          if (points.isEmpty) Text(noDataText, style: bz.chat),
          for (final p in points) _row(context, p),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ShelterPoint p) {
    final bz = context.bz;
    var trailing = formatDistance(p.distanceM ?? 0);
    if (fromLat != null && fromLon != null) {
      trailing += ' ${arrowFor(bearingDeg(fromLat!, fromLon!, p.lat, p.lon))}';
    }
    return InkWell(
      key: ValueKey('nearest-${p.id}'),
      onTap: () => onSelect(p),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(p.confirmed ? 'S' : 's?', style: bz.label),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(pointTitle(p), style: bz.label),
                  if (!p.confirmed)
                    Text(unconfirmedShortText, style: bz.caption.copyWith(color: bz.ink200)),
                ],
              ),
            ),
            Text(trailing, style: bz.label),
          ],
        ),
      ),
    );
  }
}

/// Layer toggle, >= 48 dp, label `map.layers.shelters`.
class ShelterLayerToggle extends StatelessWidget {
  const ShelterLayerToggle({super.key, required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Semantics(
      container: true,
      toggled: on,
      label: layerShelterLabel,
      onTap: () => onChanged(!on),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: bz.minTouchTarget, minWidth: bz.minTouchTarget),
        child: Material(
          color: on ? bz.signalTint : bz.bg200,
          borderRadius: BorderRadius.circular(bz.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(bz.radiusLg),
            onTap: () => onChanged(!on),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: bz.space3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(on ? Icons.visibility : Icons.visibility_off, size: 20, color: bz.ink100),
                  SizedBox(width: bz.space2),
                  Text(layerShelterLabel, style: bz.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
