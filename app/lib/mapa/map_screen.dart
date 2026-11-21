import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

import '../wspolne/shell/shell_icon_button.dart';
import '../wspolne/shell/sos_button.dart';
import '../wspolne/theme/bz_theme.dart';
import 'map_assets.dart';
import 'position_provider.dart';
import 'punkty/point_sheet.dart';
import 'punkty/points_db.dart';
import 'punkty/shelter_layer.dart';

/// Szczecin centre, used until the first fix (spec: no GPS, no last position).
const szczecinCentre = LatLng(53.4285, 14.5528);
const mapInitialZoom = 14.0;

/// Seconds without a first fix before the long "no position" text (spec).
const gpsSearchLongSeconds = 60;

// Spec: ekran-2-mapa.md, texts table.
const attributionText = '© OpenStreetMap contributors'; // map.attribution
const gpsSearchingText = 'Szukam pozycji GPS…'; // map.gps.searching
const gpsSearchingLongText = 'Nie mogę ustalić pozycji. Wyjdź pod otwarte niebo.'; // map.gps.searchingLong
const permissionDeniedText = 'Bez dostępu do lokalizacji nie pokażę, gdzie jesteś.'; // map.permission.denied
const openPhoneSettingsText = 'Otwórz ustawienia telefonu'; // spec Stany: brak zgody

// Drafted (not in the spec, verify: true, source: ekran-2-mapa.md has no copy
// for the first-run state, recenter label or install error).
const recenterLabel = 'Wyśrodkuj mapę na mojej pozycji'; // verify:true
const preparingTitle = 'Przygotowuję mapę…'; // verify:true
const preparingBody = 'Kopiuję mapę na telefon. Dzieje się to tylko raz. Potem mapa działa bez internetu.'; // verify:true
const installErrorText = 'Nie mogę przygotować mapy.'; // verify:true
const retryText = 'Spróbuj ponownie'; // verify:true

/// What the map widget needs; lets tests replace `MapLibreMap` (a platform
/// view that cannot run in widget tests).
class MapViewParams {
  const MapViewParams({
    required this.styleString,
    required this.initialTarget,
    required this.initialZoom,
    required this.myLocationEnabled,
    required this.trackingMode,
    required this.onMapCreated,
    required this.onTrackingDismissed,
    this.onMapClick,
    this.onStyleLoaded,
    this.onCameraIdle,
  });

  final String styleString;
  final LatLng initialTarget;
  final double initialZoom;
  final bool myLocationEnabled;
  final MyLocationTrackingMode trackingMode;
  final void Function(MapLibreMapController controller) onMapCreated;
  final VoidCallback onTrackingDismissed;
  final OnMapClickCallback? onMapClick;
  final VoidCallback? onStyleLoaded;
  final VoidCallback? onCameraIdle;
}

typedef MapViewBuilder = Widget Function(BuildContext context, MapViewParams params);

Widget defaultMapViewBuilder(BuildContext context, MapViewParams p) {
  return MapLibreMap(
    styleString: p.styleString,
    initialCameraPosition: CameraPosition(target: p.initialTarget, zoom: p.initialZoom),
    onMapCreated: p.onMapCreated,
    myLocationEnabled: p.myLocationEnabled,
    myLocationTrackingMode: p.trackingMode,
    // Heading cone from the device compass (works offline).
    myLocationRenderMode:
        p.myLocationEnabled ? MyLocationRenderMode.compass : MyLocationRenderMode.normal,
    onCameraTrackingDismissed: p.onTrackingDismissed,
    onMapClick: p.onMapClick,
    onStyleLoadedCallback: p.onStyleLoaded,
    onCameraIdle: p.onCameraIdle,
    // Own attribution text and no native north compass (B05 owns the compass).
    attributionEnabled: false,
    compassEnabled: false,
  );
}

/// Focus point id from the route query `?point=<id>` (chat `map` card).
int? parseFocusPointId(Map<String, String>? query) => int.tryParse(query?['point'] ?? '');

/// Installs the map files; overridable in tests.
final mapInstallerProvider = FutureProvider<MapAssetInstaller>((ref) => createDefaultMapInstaller());

/// E2 map screen (MVP subset: map, own position + heading, recenter,
/// attribution, GPS notices). Back and SOS come from `RootOverlay`.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.mapBuilder = defaultMapViewBuilder, this.focusPointId});

  final MapViewBuilder mapBuilder;

  /// Point to centre on and open; when null it is read from `?point=`.
  final int? focusPointId;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _progress = ValueNotifier<double>(0);
  Future<MapAssets>? _assets;
  MapLibreMapController? _controller;
  bool _tracking = true;
  Timer? _searchTimer;
  bool _searchLong = false;
  bool _sheltersOn = true;
  List<ShelterPoint> _points = const [];
  List<Circle> _circles = const [];
  int? _focusId;
  bool _focusResolved = false;
  bool _focusDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusResolved) return;
    _focusResolved = true;
    _focusId = widget.focusPointId ??
        parseFocusPointId(GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.queryParameters);
    if (_focusId != null) _tracking = false; // do not snap back to the user
  }

  /// Centres on the route's point and opens its sheet, once.
  Future<void> _applyFocus() async {
    final id = _focusId;
    final c = _controller;
    if (id == null || c == null || _focusDone) return;
    _focusDone = true;
    try {
      final db = await ref.read(pointsDbProvider.future);
      final p = db.byId(id);
      if (p != null && mounted) await _focus(p);
    } on Object {
      // Unknown id or DB error: stay on the normal map.
    }
  }

  @override
  void initState() {
    super.initState();
    _startInstall();
    _searchTimer = Timer(const Duration(seconds: gpsSearchLongSeconds), () {
      if (mounted) setState(() => _searchLong = true);
    });
  }

  void _startInstall() {
    _assets = () async {
      final installer = await ref.read(mapInstallerProvider.future);
      return installer.install(onProgress: (f) => _progress.value = f);
    }();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _refreshShelters() async {
    final c = _controller;
    if (c == null) return;
    try {
      if (_circles.isNotEmpty) await c.removeCircles(_circles);
      _circles = const [];
      if (!_sheltersOn) {
        _points = const [];
        return;
      }
      final db = await ref.read(pointsDbProvider.future);
      final b = await c.getVisibleRegion();
      _points = db.inBounds(
        b.southwest.latitude,
        b.southwest.longitude,
        b.northeast.latitude,
        b.northeast.longitude,
      );
      if (!mounted) return;
      final bz = context.bz;
      _circles = await c.addCircles([
        for (final p in _points)
          circleFor(p, confirmed: bz.verified, unconfirmed: bz.ink300),
      ]);
    } on Object {
      // Layer is optional: the map stays usable if points or annotations fail.
    }
  }

  void _onMapClick(math.Point<double> _, LatLng at) {
    final zoom = _controller?.cameraPosition?.zoom ?? mapInitialZoom;
    final hit = hitTest(_points, at.latitude, at.longitude, zoom);
    if (hit != null) _showPoint(hit);
  }

  Future<void> _showPoint(ShelterPoint p) async {
    final pos = ref.read(positionProvider).value;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bz.bg200,
      builder: (_) => PointSheet(
        point: p,
        fromLat: pos?.latitude,
        fromLon: pos?.longitude,
      ),
    );
  }

  Future<void> _focus(ShelterPoint p) async {
    await _controller?.animateCamera(CameraUpdate.newLatLng(LatLng(p.lat, p.lon)));
    if (mounted) await _showPoint(p);
  }

  Future<void> _showNearest() async {
    final pos = ref.read(positionProvider).value;
    final points = await ref.read(nearestSheltersProvider.future);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bz.bg200,
      builder: (sheetContext) => NearestList(
        points: points,
        fromLat: pos?.latitude,
        fromLon: pos?.longitude,
        onSelect: (p) {
          Navigator.of(sheetContext).pop();
          _focus(p);
        },
      ),
    );
  }

  Future<void> _recenter(Position position) async {
    final c = _controller;
    if (c != null) {
      await c.animateCamera(CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)));
    }
    if (mounted) setState(() => _tracking = true);
  }

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    final access = ref.watch(locationAccessProvider);
    final position = ref.watch(positionProvider).value;
    final granted = access.value == LocationAccess.granted;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;
    final topInset = top + 8 > 48 ? top + 8 : 48.0;

    return Scaffold(
      backgroundColor: bz.bg000,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<MapAssets>(
            future: _assets,
            builder: (context, snap) {
              if (snap.hasError) {
                return _InstallError(
                  onRetry: () => setState(_startInstall),
                );
              }
              if (!snap.hasData || !access.hasValue) {
                return _Preparing(progress: _progress);
              }
              return widget.mapBuilder(
                context,
                MapViewParams(
                  styleString: snap.requireData.styleJson,
                  initialTarget: position == null
                      ? szczecinCentre
                      : LatLng(position.latitude, position.longitude),
                  initialZoom: mapInitialZoom,
                  myLocationEnabled: granted,
                  trackingMode: granted && _tracking
                      ? MyLocationTrackingMode.tracking
                      : MyLocationTrackingMode.none,
                  onMapCreated: (c) => _controller = c,
                  onStyleLoaded: () async {
                    await _refreshShelters();
                    await _applyFocus();
                  },
                  onCameraIdle: _refreshShelters,
                  onMapClick: _onMapClick,
                  onTrackingDismissed: () {
                    if (mounted) setState(() => _tracking = false);
                  },
                ),
              );
            },
          ),
          if (access.hasValue) ...[
            Positioned(
              // Below Back (left) and SOS (right), never over them.
              top: topInset + SosButton.size + 8,
              left: 16,
              right: 16,
              child: _notice(access.requireValue, position),
            ),
            Positioned(
              right: 16,
              bottom: 16 + bottom + 28,
              child: RecenterButton(
                enabled: granted && position != null,
                onPressed: position == null ? null : () => _recenter(position),
              ),
            ),
          ],
          Positioned(
            left: 16,
            bottom: 16 + bottom + 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShelterLayerToggle(
                  on: _sheltersOn,
                  onChanged: (v) {
                    setState(() => _sheltersOn = v);
                    _refreshShelters();
                  },
                ),
                SizedBox(height: bz.space2),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: bz.minTouchTarget),
                  child: FilledButton(
                    onPressed: _showNearest,
                    child: const Text(nearestButtonText),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16 + bottom,
            child: const AttributionLabel(),
          ),
        ],
      ),
    );
  }

  Widget _notice(LocationAccess access, Position? position) {
    if (access != LocationAccess.granted) {
      return MapNotice(
        text: permissionDeniedText,
        actionLabel: openPhoneSettingsText,
        onAction: () => ref.read(locationGatewayProvider).openSettings(),
      );
    }
    if (position == null) {
      return MapNotice(text: _searchLong ? gpsSearchingLongText : gpsSearchingText);
    }
    return const SizedBox.shrink();
  }
}

/// Floating round recenter button, >= 48 dp, same surface as Back.
class RecenterButton extends StatelessWidget {
  const RecenterButton({super.key, required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: recenterLabel,
      onTap: enabled ? onPressed : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: DecoratedBox(
          decoration: shellFloatDecoration(context, circle: true),
          child: SizedBox(
            width: bz.minTouchTarget,
            height: bz.minTouchTarget,
            child: Material(
              type: MaterialType.transparency,
              child: InkResponse(
                onTap: enabled ? onPressed : null,
                customBorder: const CircleBorder(),
                child: Icon(LucideIcons.locateFixed, size: 22, color: bz.ink100),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bar notice (spec: `Notice`, variant `bar`).
class MapNotice extends StatelessWidget {
  const MapNotice({super.key, required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bz.bg200,
          borderRadius: BorderRadius.circular(bz.radiusMd),
          border: Border.all(color: bz.line150),
        ),
        child: Padding(
          padding: EdgeInsets.all(bz.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: bz.label.copyWith(color: bz.ink100)),
              if (actionLabel != null) ...[
                SizedBox(height: bz.space2),
                BzButtonLike(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal >= 48 dp text button (kept local; shared buttons live in the theme).
class BzButtonLike extends StatelessWidget {
  const BzButtonLike({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: bz.minTouchTarget),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: bz.signal),
        child: Text(label, style: bz.label.copyWith(color: bz.signal)),
      ),
    );
  }
}

class AttributionLabel extends StatelessWidget {
  const AttributionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bz.bg000.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(bz.radiusSm),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: bz.space2, vertical: 2),
        child: Text(attributionText, style: bz.caption.copyWith(color: bz.ink200)),
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing({required this.progress});

  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(bz.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(preparingTitle, style: bz.title, textAlign: TextAlign.center),
            SizedBox(height: bz.space3),
            Text(
              preparingBody,
              style: bz.chat.copyWith(color: bz.ink200),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: bz.space5),
            ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value, // determinate: calm, no endless animation
                minHeight: 4,
                color: bz.signal,
                backgroundColor: bz.bg300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallError extends StatelessWidget {
  const _InstallError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(installErrorText, style: bz.title, textAlign: TextAlign.center),
          SizedBox(height: bz.space3),
          BzButtonLike(label: retryText, onPressed: onRetry),
        ],
      ),
    );
  }
}
