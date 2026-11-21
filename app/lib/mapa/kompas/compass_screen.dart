import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../wspolne/theme/bz_buttons.dart';
import '../../wspolne/theme/bz_theme.dart';
import '../position_provider.dart';
import '../punkty/geo.dart';
import '../punkty/point_sheet.dart';
import '../punkty/points_db.dart';
import 'compass_math.dart';
import 'heading_provider.dart';

// Spec: ekran-2-mapa.md, texts table (map.compass.*).
String compassToText(String kind, String name) => 'Do: $kind, $name';
const compassShowMapText = 'Pokaż mapę';
const compassEndText = 'Zakończ';
const compassCalibrateText = 'Kompas może się mylić. Porusz telefonem ruchem ósemki.';
String compassLastFixText(String age) => 'Brak GPS. Kierunek z ostatniej znanej pozycji ($age temu).';
String compassNoSensorText(String direction) => 'Twój telefon nie ma kompasu. Idź na $direction.';
const compassNoPositionText = 'Brak pozycji GPS. Nie wiem, w którą stronę iść.';

/// Full-screen compass to [target] (map state `compass`). Straight line only.
/// Back and SOS come from the global overlay.
class CompassScreen extends ConsumerStatefulWidget {
  const CompassScreen({
    super.key,
    required this.target,
    required this.onShowMap,
    required this.onEnd,
    this.now = DateTime.now,
  });

  final ShelterPoint target;
  final VoidCallback onShowMap;
  final VoidCallback onEnd;
  final DateTime Function() now;

  @override
  ConsumerState<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends ConsumerState<CompassScreen> {
  /// Last fix we ever saw; kept when GPS drops (arrow points from there).
  Position? _lastFix;

  @override
  void initState() {
    super.initState();
    // Screen must not time out while guiding; ignore platforms without it.
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final live = ref.watch(positionProvider).value;
    if (live != null) _lastFix = live;
    final fix = _lastFix;
    final heading = ref.watch(headingProvider);
    final hasSensor = heading.hasValue && heading.value != null;
    final noSensor = heading.hasValue && heading.value == null;
    final reading = heading.value;
    final t = widget.target;

    double? dist, bearing, angleDeg;
    if (fix != null) {
      dist = haversineM(fix.latitude, fix.longitude, t.lat, t.lon);
      bearing = bearingDeg(fix.latitude, fix.longitude, t.lat, t.lon);
      if (hasSensor) {
        angleDeg = relativeAngleDeg(bearing, reading!.degrees);
      } else if (noSensor && fix.speed > 1 && fix.heading >= 0) {
        angleDeg = relativeAngleDeg(bearing, fix.heading); // GPS course while walking
      }
    }

    String? notice;
    if (fix != null && live == null) {
      notice = compassLastFixText(ageText(widget.now().difference(fix.timestamp)));
    } else if (hasSensor && !reading!.reliable) {
      notice = compassCalibrateText;
    }

    // Material, not ColoredBox: pushed as a bare route it has no Scaffold,
    // and Text without a Material ancestor renders red with yellow underlines.
    return Material(
      color: bz.bg000,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(bz.space4, 72, bz.space4, bz.space4),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  compassToText(kindLabel(t.kind), pointTitle(t)),
                  style: bz.title,
                ),
              ),
              if (notice != null)
                Padding(
                  padding: EdgeInsets.only(top: bz.space3),
                  child: Text(notice, key: const Key('compass-notice'), style: bz.chat.copyWith(color: bz.signal)),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Center(
                        child: fix == null
                            ? Text(compassNoPositionText, textAlign: TextAlign.center, style: bz.title)
                            : _body(bz, dist!, bearing!, angleDeg, noSensor, fix),
                      ),
                    ),
                  ),
                ),
              ),
              // Labels never ellipsize: stack the buttons at large text.
              Builder(
                builder: (context) {
                  final map = BzButton(
                    label: compassShowMapText,
                    onPressed: widget.onShowMap,
                    size: BzButtonSize.xl,
                    fullWidth: true,
                  );
                  final end = BzButton(
                    label: compassEndText,
                    onPressed: widget.onEnd,
                    size: BzButtonSize.xl,
                    fullWidth: true,
                  );
                  if (MediaQuery.textScalerOf(context).scale(1) > 1.15) {
                    return Column(
                      children: [map, SizedBox(height: bz.space3), end],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: map),
                      SizedBox(width: bz.space3),
                      Expanded(child: end),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BzTokens bz, double dist, double bearing, double? angleDeg, bool noSensor, Position fix) {
    final dir = cardinalName(bearing);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (angleDeg != null)
          Semantics(
            label: '${formatDistance(dist)}, $dir',
            child: Transform.rotate(
              key: const Key('compass-arrow'),
              angle: angleDeg * 3.141592653589793 / 180,
              child: Icon(LucideIcons.arrowUp, size: 200, color: bz.ink100),
            ),
          ),
        SizedBox(height: bz.space4),
        Text(formatDistance(dist), key: const Key('compass-distance'), style: bz.display),
        SizedBox(height: bz.space2),
        Text(dir, key: const Key('compass-cardinal'), style: bz.title),
        if (noSensor && angleDeg == null)
          Padding(
            padding: EdgeInsets.only(top: bz.space3),
            child: Text(compassNoSensorText(dir), textAlign: TextAlign.center, style: bz.chat),
          ),
        SizedBox(height: bz.space3),
        Text(
          '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}',
          key: const Key('compass-coords'),
          style: bz.caption.copyWith(color: bz.ink200),
        ),
      ],
    );
  }
}
