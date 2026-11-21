import 'dart:math' as math;

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'geo.dart';
import 'points_db.dart';

// Spec: ekran-2-mapa.md, texts table.
const pointConfirmedText = '✓ Potwierdzony'; // map.point.confirmed
String pointUnconfirmedText(String source) =>
    '? Niepotwierdzony. Dane z $source, niesprawdzone przez PSP.'; // map.point.unconfirmed
String pointSourceText(String source, String verifiedAt) =>
    'Źródło: $source, ${formatPointDate(verifiedAt)}'; // map.point.source

/// Spec date format "DD.MM.RRRR" (ekran-2-mapa.md, Formaty); unparsable
/// values are shown as they are.
String formatPointDate(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}
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
    double? bearing;
    if (dist != null) {
      if (hasFrom) {
        bearing = bearingDeg(fromLat!, fromLon!, point.lat, point.lon);
        distanceLine = '${formatDistance(dist)} · ${cardinalName(bearing)}';
      } else {
        distanceLine = formatDistance(dist);
      }
    }
    final stale = isStale(point.verifiedAt, now ?? DateTime.now());
    final btn = Size(bz.minTouchTarget, bz.minTouchTarget);
    return SafeArea(
      top: false,
      child: Padding(
      padding: EdgeInsets.fromLTRB(bz.space4, 0, bz.space4, 24),
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
          if (distanceLine != null)
            Row(
              children: [
                Text(distanceLine, style: bz.label),
                if (bearing != null) ...[
                  SizedBox(width: bz.space2),
                  BearingArrow(bearing: bearing, color: bz.ink100),
                ],
              ],
            ),
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
    ));
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
    this.outside = false,
  });

  /// Position lies outside the bundled region: honest notice, no download.
  final bool outside;
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
          if (points.isEmpty) Text(outside ? outsideRegionText : noDataText, style: bz.chat),
          for (final p in points) _row(context, p),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ShelterPoint p) {
    final bz = context.bz;
    final trailing = formatDistance(p.distanceM ?? 0);
    final bearing = fromLat != null && fromLon != null
        ? bearingDeg(fromLat!, fromLon!, p.lat, p.lon)
        : null;
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
            if (bearing != null) ...[
              SizedBox(width: bz.space2),
              BearingArrow(bearing: bearing, color: bz.ink100),
            ],
          ],
        ),
      ),
    );
  }
}

/// Layer row (DS ListRow + Switch), >= 48 dp, label `map.layers.shelters`.
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
      child: InkWell(
        onTap: () => onChanged(!on),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bz.minTouchTarget),
          child: Row(
            children: [
              Expanded(child: Text(layerShelterLabel, style: bz.label)),
              ExcludeSemantics(child: Switch(value: on, onChanged: onChanged)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Direction arrow: Lucide arrow-up rotated by the bearing. Unicode arrows
/// (↙ …) fall back to the colour emoji font on Android.
class BearingArrow extends StatelessWidget {
  const BearingArrow({super.key, required this.bearing, required this.color, this.size = 20});

  final double bearing;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        key: const ValueKey('bearing-arrow'),
        angle: bearing * math.pi / 180,
        child: Icon(LucideIcons.arrowUp, size: size, color: color),
      );
}
