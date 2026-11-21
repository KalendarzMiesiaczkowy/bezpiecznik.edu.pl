import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app_router.dart' show mapRoutePath;
import '../../../mapa/punkty/geo.dart';
import '../../../mapa/punkty/point_sheet.dart';
import '../../../mapa/punkty/points_db.dart';
import '../../../mapa/position_provider.dart';
import '../../../wspolne/theme/bz_buttons.dart';
import '../../../wspolne/theme/bz_theme.dart';
import '../panel_card.dart';
import '../panel_model.dart';
import '../template_registry.dart';

// Spec: szablony-czatu.md, `map` (states table).
const mapCardTitle = 'Najbliższy schron'; // diagram title
const mapHospitalCardTitle =
    'Najbliższy szpital'; // verify:true (spec: no title)
const mapNoPositionText = 'Nie znam twojej pozycji.'; // state: no position
const mapUnknownDistancesText =
    'Poniżej schrony najbliżej centrum Szczecina.'; // verify:true
const mapShowOnMapText = 'Pokaż na mapie'; // button without a position
const mapNoPointsText =
    'Brak takich punktów w pobranych danych mapy.'; // state: no points of kind

// Drafted (verify:true; source: szablony-czatu.md `map` names no loading copy
// and no label for the "open the map" button when a position is known).
const mapLoadingText = 'Szukam najbliższych schronień…'; // verify:true
const mapOpenMapText = 'Otwórz mapę'; // verify:true

/// Route that opens E2 focused on [pointId] (no route; spec: tap -> map
/// centred on the point).
String mapPointLocation(int pointId) => '$mapRoutePath?point=$pointId';

/// `map` template body for the chat. Only `nearest_shelter` has data in the
/// MVP; any other target shows the spec "no points" text, never invented points.
class MapCardView extends ConsumerWidget {
  const MapCardView({super.key, required this.target});

  final String target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bz = context.bz;
    final Widget body;
    if (target != 'nearest_shelter') {
      body = Text(mapNoPointsText, style: bz.chat);
    } else {
      final nearest = ref.watch(nearestSheltersProvider);
      final pos = ref.watch(positionProvider).value;
      final outside = ref.watch(outsideRegionProvider).value ?? false;
      body = nearest.when(
        loading: () =>
            Text(mapLoadingText, style: bz.chat.copyWith(color: bz.ink200)),
        error: (_, _) => Text(mapNoPointsText, style: bz.chat),
        data: (points) => points.isEmpty
            ? Text(
                outside ? outsideRegionText : mapNoPointsText,
                style: bz.chat,
              )
            : _Points(
                points: points,
                fromLat: pos?.latitude,
                fromLon: pos?.longitude,
              ),
      );
    }
    return PanelCard(
      key: ValueKey('map-card-$target'),
      title: target == 'nearest_hospital' ? mapHospitalCardTitle : mapCardTitle,
      child: body,
    );
  }
}

/// Average walking speed for the walk-time estimate (ekran-2-mapa.md
/// Parametry `WALK_SPEED_KMH` = 4,5).
const walkingSpeedKmh = 4.5;

/// Walk time in whole minutes (rounded up, at least 1) for [metres].
int walkMinutes(double metres) =>
    math.max(1, (metres / (walkingSpeedKmh * 1000 / 60)).ceil());

/// "6 min" below an hour, "1 h 10 min" from 60 min (ekran-2-mapa.md Formaty).
String walkTimeText(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "Dane sprzed {n} mies." for a point older than the stale threshold.
String staleMonthsText(int months) => 'Dane sprzed $months mies.';

/// Whole months between [verifiedAt] (ISO date) and [now]; null if unparsable.
int? monthsSince(String verifiedAt, DateTime now) {
  final d = DateTime.tryParse(verifiedAt);
  if (d == null) return null;
  var m = (now.year - d.year) * 12 + now.month - d.month;
  if (now.day < d.day) m -= 1;
  return math.max(0, m);
}

/// Source chip label: "KG PSP · zweryf. 03.2026" (DS example) for confirmed
/// points. An unconfirmed point (e.g. OSM) is never called verified (the card
/// already carries the "niepotwierdzony" label): "OSM · dane z 03.2026".
String sourceChipText(
  String source,
  String verifiedAt, {
  bool confirmed = true,
}) {
  final d = DateTime.tryParse(verifiedAt);
  if (d == null) return source;
  final mm = d.month.toString().padLeft(2, '0');
  if (!confirmed) return '$source · dane z $mm.${d.year}'; // verify:true
  return '$source · zweryf. $mm.${d.year}';
}

/// Straight-line distance text: the MVP has no street routing, so the distance
/// is always the spec's `straight_line = true` form.
String distanceLineText(double metres) =>
    '${formatDistance(metres)} w linii prostej · ok. ${walkTimeText(walkMinutes(metres))}';

class _Points extends StatelessWidget {
  const _Points({required this.points, this.fromLat, this.fromLon});

  final List<ShelterPoint> points;
  final double? fromLat;
  final double? fromLon;

  bool get _hasPosition => fromLat != null && fromLon != null;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    // DS: one nearest point per card.
    final point = points.first;
    double? distance;
    double? bearing;
    if (_hasPosition) {
      distance = haversineM(fromLat!, fromLon!, point.lat, point.lon);
      bearing = bearingDeg(fromLat!, fromLon!, point.lat, point.lon);
    }
    final name = point.name?.trim();
    final hasName = name != null && name.isNotEmpty;
    final address = point.address?.trim();
    final hasAddress = address != null && address.isNotEmpty;
    // Never an invented name: an unnamed point is titled by its kind and the
    // address (if any) becomes the subtitle.
    final title = hasName ? name : kindLabel(point.kind);
    final subtitle = [
      if (hasName) kindLabel(point.kind),
      if (hasAddress) address,
    ].join(' · ');
    final months = isStale(point.verifiedAt, DateTime.now())
        ? monthsSince(point.verifiedAt, DateTime.now())
        : null;
    void focus() {
      // Drop composer focus first, otherwise Flutter restores it on pop and
      // the keyboard opens over the card.
      FocusManager.instance.primaryFocus?.unfocus();
      context.push(mapPointLocation(point.id));
    }

    final label = [
      title,
      if (subtitle.isNotEmpty) subtitle,
      if (distance != null) distanceLineText(distance),
      if (!point.confirmed) unconfirmedShortText,
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_hasPosition) ...[
          Text(mapNoPositionText, style: bz.label.copyWith(color: bz.ink100)),
          Text(
            mapUnknownDistancesText,
            style: bz.caption.copyWith(color: bz.ink200),
          ),
          SizedBox(height: bz.space2),
        ],
        // Non-interactive mini map; a tap opens E2 centred on the point.
        Semantics(
          button: true,
          label: 'Mini mapa. Pokaż punkt na mapie',
          excludeSemantics: true,
          child: GestureDetector(
            key: const ValueKey('map-card-minimap'),
            behavior: HitTestBehavior.opaque,
            onTap: focus,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(bz.radiusMd),
                border: Border.all(color: bz.line100),
              ),
              child: SizedBox(
                height: 96,
                child: CustomPaint(
                  painter: MiniMapPainter(
                    bearing: bearing,
                    confirmed: point.confirmed,
                    land: bz.bg200,
                    grid: bz.line150,
                    link: bz.signal,
                    you: bz.info,
                    target: bz.ink100,
                    halo: bz.bg000,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: bz.space2),
        Semantics(
          label: label,
          excludeSemantics: true,
          child: ConstrainedBox(
            key: ValueKey('map-card-point-${point.id}'),
            constraints: BoxConstraints(minHeight: bz.minTouchTarget),
            child: Row(
              children: [
                PointMarker(point: point),
                SizedBox(width: bz.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: bz.label),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: bz.caption.copyWith(color: bz.ink200),
                        ),
                      if (distance != null)
                        Text(
                          distanceLineText(distance),
                          style: bz.label.copyWith(
                            color: bz.ink100,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      if (!point.confirmed)
                        Text(
                          unconfirmedShortText,
                          style: bz.caption.copyWith(color: bz.ink200),
                        ),
                      if (months != null)
                        Text(
                          staleMonthsText(months),
                          style: bz.caption.copyWith(color: bz.signal),
                        ),
                    ],
                  ),
                ),
                if (bearing != null) ...[
                  SizedBox(width: bz.space2),
                  KeyedSubtree(
                    key: ValueKey('map-card-bearing-${point.id}'),
                    child: BearingArrow(bearing: bearing, color: bz.ink200),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: bz.space2),
        Align(
          alignment: Alignment.centerLeft,
          child: _SourceChip(point: point),
        ),
        SizedBox(height: bz.space3),
        BzButton(
          key: const ValueKey('map-card-open'),
          label: _hasPosition ? pointGuideText : mapShowOnMapText,
          icon: _hasPosition ? LucideIcons.navigation2 : LucideIcons.map,
          onPressed: focus,
          variant: BzButtonVariant.primary,
          size: BzButtonSize.lg,
          fullWidth: true,
        ),
      ],
    );
  }
}

/// DS `SourceChip` look: `verified-tint` for a confirmed point, neutral
/// `bg-200` for an unconfirmed one (never dressed as verified); tap shows
/// source and verification date.
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.point});

  final ShelterPoint point;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Semantics(
      button: true,
      label: pointSourceText(point.source, point.verifiedAt),
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('map-card-source'),
        borderRadius: BorderRadius.circular(bz.radiusFull),
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(
              point.confirmed
                  ? pointSourceText(point.source, point.verifiedAt)
                  : '${pointUnconfirmedText(point.source)}\n'
                        '${pointSourceText(point.source, point.verifiedAt)}',
              style: bz.chat,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Zamknij'),
              ),
            ],
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bz.minTouchTarget),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: point.confirmed ? bz.verifiedTint : bz.bg200,
                borderRadius: BorderRadius.circular(bz.radiusFull),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: bz.space3, vertical: bz.space1),
                child: Text(
                  sourceChipText(
                    point.source,
                    point.verifiedAt,
                    confirmed: point.confirmed,
                  ),
                  style: bz.source.copyWith(
                    color: point.confirmed ? bz.verified : bz.ink200,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight static schematic of the DS mini map (no second MapLibre view in
/// the chat list): you = `info` dot, target = marker, dotted straight line in
/// `signal`. The target is placed by bearing; the line length is a fixed
/// fraction of the box, so it conveys direction, not scale. Without a position
/// only the target is drawn.
class MiniMapPainter extends CustomPainter {
  MiniMapPainter({
    required this.bearing,
    required this.confirmed,
    required this.land,
    required this.grid,
    required this.link,
    required this.you,
    required this.target,
    required this.halo,
  });

  final double? bearing;
  final bool confirmed;
  final Color land, grid, link, you, target, halo;

  /// Pixel offsets (you -> target) for [bearing] fitting [size]; null when the
  /// bearing is unknown.
  static Offset vectorFor(double bearing, Size size) {
    final dx = math.sin(bearing * math.pi / 180);
    final dy = -math.cos(bearing * math.pi / 180);
    final maxX = size.width * 0.7;
    final maxY = size.height * 0.6;
    final lx = dx.abs() < 1e-6 ? double.infinity : maxX / dx.abs();
    final ly = dy.abs() < 1e-6 ? double.infinity : maxY / dy.abs();
    final l = math.min(lx, ly);
    return Offset(dx * l, dy * l);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var x = size.width / 6; x < size.width; x += size.width / 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = size.height / 3; y < size.height; y += size.height / 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final centre = size.center(Offset.zero);
    void marker(Offset c) {
      canvas.drawCircle(c, 9, Paint()..color = halo);
      if (confirmed) {
        canvas.drawCircle(c, 7, Paint()..color = target);
      } else {
        canvas.drawCircle(
          c,
          6,
          Paint()
            ..color = target
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    final b = bearing;
    if (b == null) {
      marker(centre);
      return;
    }
    final v = vectorFor(b, size);
    final from = centre - v / 2;
    final to = centre + v / 2;
    final linePaint = Paint()
      ..color = link
      ..strokeWidth = 2;
    final total = (to - from).distance;
    final dir = (to - from) / total;
    for (var d = 0.0; d < total; d += 10) {
      canvas.drawLine(
        from + dir * d,
        from + dir * math.min(d + 5, total),
        linePaint,
      );
    }
    marker(to);
    canvas.drawCircle(from, 8, Paint()..color = halo);
    canvas.drawCircle(from, 6, Paint()..color = you);
  }

  @override
  bool shouldRepaint(MiniMapPainter o) =>
      o.bearing != bearing || o.confirmed != confirmed || o.land != land;
}

/// Plugs the real `map` template into [r] (replaces the placeholder).
void registerMapTemplate(TemplateRegistry r) {
  r.register('map', (context, scope) {
    final panel = scope.panel as MapPanel;
    return MapCardView(target: panel.target);
  });
}
