import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app_router.dart' show mapRoutePath;
import '../../../mapa/punkty/geo.dart';
import '../../../mapa/punkty/point_sheet.dart';
import '../../../mapa/punkty/points_db.dart';
import '../../../mapa/position_provider.dart';
import '../../../wspolne/theme/bz_theme.dart';
import '../panel_card.dart';
import '../panel_model.dart';
import '../template_registry.dart';

// Spec: szablony-czatu.md, `map` (states table).
const mapCardTitle = 'Najbliższy schron'; // diagram title
const mapNoPositionText = 'Nie znam twojej pozycji.'; // state: no position
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
      body = nearest.when(
        loading: () =>
            Text(mapLoadingText, style: bz.chat.copyWith(color: bz.ink200)),
        error: (_, _) => Text(mapNoPointsText, style: bz.chat),
        data: (points) => points.isEmpty
            ? Text(mapNoPointsText, style: bz.chat)
            : _Points(
                points: points,
                fromLat: pos?.latitude,
                fromLon: pos?.longitude,
              ),
      );
    }
    return PanelCard(
      key: ValueKey('map-card-$target'),
      title: mapCardTitle,
      child: body,
    );
  }
}

class _Points extends StatelessWidget {
  const _Points({required this.points, this.fromLat, this.fromLon});

  final List<ShelterPoint> points;
  final double? fromLat;
  final double? fromLon;

  bool get _hasPosition => fromLat != null && fromLon != null;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_hasPosition) ...[
          Text(mapNoPositionText, style: bz.label.copyWith(color: bz.ink100)),
          SizedBox(height: bz.space2),
        ],
        for (final p in points)
          _PointRow(point: p, fromLat: fromLat, fromLon: fromLon),
        SizedBox(height: bz.space3),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: bz.minTouchTarget),
          child: FilledButton(
            key: const ValueKey('map-card-open'),
            onPressed: () => context.push(mapRoutePath),
            child: Text(_hasPosition ? mapOpenMapText : mapShowOnMapText),
          ),
        ),
      ],
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.point, this.fromLat, this.fromLon});

  final ShelterPoint point;
  final double? fromLat;
  final double? fromLon;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final from = fromLat != null && fromLon != null;
    String? distance;
    if (from) {
      final d = haversineM(fromLat!, fromLon!, point.lat, point.lon);
      final b = bearingDeg(fromLat!, fromLon!, point.lat, point.lon);
      distance = '${formatDistance(d)} ${arrowFor(b)}';
    }
    final address = point.address?.trim();
    final title = pointTitle(point);
    final subtitle = [
      kindLabel(point.kind),
      if (address != null && address.isNotEmpty && address != title) address,
    ].join(' · ');
    final label = [
      title,
      subtitle,
      ?distance,
      if (!point.confirmed) unconfirmedShortText,
    ].join(', ');
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('map-card-point-${point.id}'),
        borderRadius: BorderRadius.circular(bz.radiusMd),
        onTap: () => context.push(mapPointLocation(point.id)),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bz.minTouchTarget + 8),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: bz.space2),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(point.confirmed ? 'S' : 's?', style: bz.label),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: bz.label),
                      Text(
                        subtitle,
                        style: bz.caption.copyWith(color: bz.ink200),
                      ),
                      if (!point.confirmed)
                        Text(
                          unconfirmedShortText,
                          style: bz.caption.copyWith(color: bz.ink200),
                        ),
                    ],
                  ),
                ),
                if (distance != null) Text(distance, style: bz.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plugs the real `map` template into [r] (replaces the placeholder).
void registerMapTemplate(TemplateRegistry r) {
  r.register('map', (context, scope) {
    final panel = scope.panel as MapPanel;
    return MapCardView(target: panel.target);
  });
}
