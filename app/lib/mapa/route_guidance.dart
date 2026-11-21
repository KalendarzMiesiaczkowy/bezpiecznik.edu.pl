import 'package:material_ui/material_ui.dart';

import '../czat/templates/map/map_card_view.dart' show walkMinutes, walkTimeText;
import '../wspolne/theme/bz_buttons.dart';
import '../wspolne/theme/bz_theme.dart';
import 'punkty/geo.dart';
import 'punkty/point_sheet.dart' show pointCompassText, pointTitle;
import 'punkty/points_db.dart';

// Spec texts: ekran-2-mapa.md (`map.route.*`). The pedestrian road graph is
// not built yet (Po MVP), so guidance is the straight line to the point and
// says so, like the spec's fallback `map.route.noPath`.
const routeEndText = 'Zakończ'; // map.route.end
const routeArrivedText = 'Jesteś u celu'; // map.route.arrived
const routeStraightLineText = 'Pokazuję kierunek w linii prostej.'; // map.route.noPath
const routeNoPositionText = 'Szukam pozycji GPS… Pokazuję cel na mapie.'; // verify:true

/// Below this distance the user has arrived (spec `ARRIVAL_M`).
const double routeArrivalM = 30;

/// GeoJSON of the guidance line from the user to the target; an empty
/// collection (which clears the layer) when either end is unknown.
Map<String, dynamic> routeLineGeoJson({
  double? fromLat,
  double? fromLon,
  double? toLat,
  double? toLon,
}) => {
  'type': 'FeatureCollection',
  'features': [
    if (fromLat != null && fromLon != null && toLat != null && toLon != null)
      {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [fromLon, fromLat],
            [toLon, toLat],
          ],
        },
        'properties': <String, dynamic>{},
      },
  ],
};

/// "850 m · 12 min" (`map.route.remaining`), or null without a position.
String? routeRemainingText(double? metres) =>
    metres == null ? null : '${formatDistance(metres)} · ${walkTimeText(walkMinutes(metres))}';

/// Bottom bar of the guidance state: target, remaining distance and walking
/// time, and the Kompas / Zakończ actions.
class RouteBar extends StatelessWidget {
  const RouteBar({
    super.key,
    required this.target,
    required this.distanceM,
    required this.onCompass,
    required this.onEnd,
  });

  final ShelterPoint target;

  /// Straight-line distance to the target; null without a position.
  final double? distanceM;
  final VoidCallback onCompass;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final arrived = distanceM != null && distanceM! < routeArrivalM;
    final headline = arrived ? routeArrivedText : routeRemainingText(distanceM);
    return DecoratedBox(
      key: const Key('route-bar'),
      decoration: BoxDecoration(
        color: bz.bg200,
        borderRadius: BorderRadius.circular(bz.radiusLg),
        border: Border.all(color: bz.line150),
      ),
      child: Padding(
        padding: EdgeInsets.all(bz.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              liveRegion: arrived,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Do: ${pointTitle(target)}', style: bz.caption.copyWith(color: bz.ink200)),
                  SizedBox(height: bz.space1),
                  if (headline != null)
                    Text(
                      headline,
                      style: bz.title.copyWith(color: arrived ? bz.verified : bz.ink100),
                    ),
                  if (!arrived) ...[
                    SizedBox(height: bz.space1),
                    Text(
                      distanceM == null ? routeNoPositionText : routeStraightLineText,
                      style: bz.caption.copyWith(color: bz.ink200),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: bz.space3),
            Row(
              children: [
                Expanded(
                  child: BzButton(
                    key: const Key('route-compass'),
                    label: pointCompassText,
                    size: BzButtonSize.xl,
                    fullWidth: true,
                    onPressed: onCompass,
                  ),
                ),
                SizedBox(width: bz.space2),
                Expanded(
                  child: BzButton(
                    key: const Key('route-end'),
                    label: routeEndText,
                    variant: BzButtonVariant.primary,
                    size: BzButtonSize.xl,
                    fullWidth: true,
                    onPressed: onEnd,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
