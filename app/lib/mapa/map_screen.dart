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
import 'kompas/compass_screen.dart';
import 'gps_status.dart';
import 'map_assets.dart';
import 'position_provider.dart';
import 'punkty/clusters.dart';
import 'punkty/point_sheet.dart';
import 'punkty/points_db.dart';
import 'punkty/shelter_layer.dart';

export 'gps_status.dart' show gpsSearchLongSeconds, gpsSearchingLongText, gpsSearchingText;

/// Szczecin centre, used until the first fix (spec: no GPS, no last position).
const szczecinCentre = LatLng(53.4285, 14.5528);
const mapInitialZoom = 14.0;


// Spec: ekran-2-mapa.md, texts table.
const attributionText = '© OpenStreetMap contributors'; // map.attribution
const permissionDeniedText = 'Bez dostępu do lokalizacji nie pokażę, gdzie jesteś.'; // map.permission.denied
const openPhoneSettingsText = 'Otwórz ustawienia telefonu'; // spec Stany: brak zgody

// Drafted (not in the spec, verify: true, source: ekran-2-mapa.md has no copy
// for the first-run state, recenter label or install error).
const recenterLabel = 'Wyśrodkuj mapę na mojej pozycji'; // verify:true
const layersButtonText = 'Warstwy'; // spec: przycisk Warstwy (ekran-2-mapa.md)
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
    this.onCameraMoveStarted,
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
  final void Function(CameraMoveReason reason)? onCameraMoveStarted;
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
    // UserDot: `info` token dot and accuracy circle (not the default blue).
    myLocationStyle: MyLocationStyle(
      fillColor: context.bz.info,
      bearingColor: context.bz.info,
      accuracyColor: context.bz.info,
    ),
    onCameraTrackingDismissed: p.onTrackingDismissed,
    onMapClick: p.onMapClick,
    onStyleLoadedCallback: p.onStyleLoaded,
    onCameraIdle: p.onCameraIdle,
    onCameraMoveStarted: p.onCameraMoveStarted,
    // Without it controller.cameraPosition stays null and marker clustering
    // and tap hit tests would always assume the initial zoom.
    trackCameraPosition: true,
    // Own attribution text and no native north compass (B05 owns the compass).
    attributionEnabled: false,
    compassEnabled: false,
  );
}

/// Focus point id from the route query `?point=<id>` (chat `map` card).
int? parseFocusPointId(Map<String, String>? query) => int.tryParse(query?['point'] ?? '');

/// `?guide=1`: open the compass to the focused point instead of its sheet
/// (BG75: chat MapCard "Prowadź" goes straight to guidance).
bool parseGuide(Map<String, String>? query) => query?['guide'] == '1';

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
  List<MarkerCluster> _clusters = const [];
  List<Symbol> _symbols = const [];
  bool _markerImagesAdded = false;
  int? _focusId;
  bool _focusResolved = false;
  bool _focusDone = false;
  bool _guide = false;
  bool _styleReady = false;
  bool _markerLayersAdded = false;
  Timer? _ageTimer;
  DateTime? _lastTrackedFix;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusResolved) return;
    _focusResolved = true;
    final query = GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.queryParameters;
    _focusId = widget.focusPointId ?? parseFocusPointId(query);
    _guide = parseGuide(query);
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
      if (p == null || !mounted) return;
      if (_guide) {
        await _controller?.animateCamera(CameraUpdate.newLatLng(LatLng(p.lat, p.lon)));
        if (mounted) _openCompass(p);
      } else {
        await _focus(p);
      }
    } on Object {
      // Unknown id or DB error: stay on the normal map.
    }
  }

  @override
  void initState() {
    super.initState();
    _startInstall();
    // Keeps "Ostatnia pozycja: N min temu" current.
    _ageTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
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
    _controller?.onSymbolTapped.remove(_onSymbolTapped);
    _searchTimer?.cancel();
    _ageTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  bool _refreshing = false;
  bool _refreshAgain = false;

  /// Serialised: camera-idle and style-loaded can fire together, and two
  /// overlapping runs would leave orphan symbols on the map.
  Future<void> _refreshShelters() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        await _refreshSheltersOnce();
      } while (_refreshAgain && mounted);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshSheltersOnce() async {
    final c = _controller;
    if (c == null) return;
    try {
      if (_symbols.isNotEmpty) await c.removeSymbols(_symbols);
      _symbols = const [];
      if (!_sheltersOn) {
        _points = const [];
        _clusters = const [];
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
      if (!_markerImagesAdded) {
        for (final st in [...allMarkerStyles, ...allClusterStyles]) {
          final png = await renderMarkerPng(
            st,
            confirmed: bz.verified,
            unconfirmedInk: bz.ink300,
            unconfirmedGlyph: bz.ink200,
            border: bz.bg000,
          );
          await c.addImage(st.imageName, png, false, markerScale);
        }
        // Two close points must both show (no collision hiding).
        await c.setSymbolIconAllowOverlap(true);
        await c.setSymbolIconIgnorePlacement(true);
        _markerImagesAdded = true;
      }
      final zoom = c.cameraPosition?.zoom ?? mapInitialZoom;
      _clusters = clusterPoints(_points, zoom);
      _symbols = await c.addSymbols([for (final cl in _clusters) symbolForCluster(cl)]);
    } on Object {
      // Layer is optional: the map stays usable if points or annotations fail.
    }
  }

  /// Own position marker (replaces MapLibre's puck, which draws nothing
  /// without a live fix): GeoJSON source + halo and dot circle layers.
  Future<void> _syncUserMarker() async {
    final c = _controller;
    if (c == null || !_styleReady || !mounted) return;
    final position = ref.read(positionProvider).value;
    final fix = ref.read(gpsFixProvider);
    final live = position != null && !fix.lastKnownOnly;
    final at = position ?? fix.lastKnown;
    final kind = userMarkerKind(live: live, hasLastKnown: at != null);
    final data = userMarkerGeoJson(
      kind == UserMarkerKind.none ? null : at?.latitude,
      kind == UserMarkerKind.none ? null : at?.longitude,
      live: kind == UserMarkerKind.live,
    );
    try {
      if (!_markerLayersAdded) {
        _markerLayersAdded = true;
        final bz = context.bz;
        final color = ['case', ['get', 'live'], _hex(bz.info), _hex(bz.ink300)];
        await c.addGeoJsonSource(_userSourceId, data);
        await c.addCircleLayer(
          _userSourceId,
          _userHaloLayerId,
          CircleLayerProperties(circleRadius: 16, circleColor: color, circleOpacity: 0.25),
          enableInteraction: false,
        );
        await c.addCircleLayer(
          _userSourceId,
          _userDotLayerId,
          CircleLayerProperties(
            circleRadius: 7,
            circleColor: color,
            circleStrokeColor: _hex(bz.ink100),
            circleStrokeWidth: 2,
          ),
          enableInteraction: false,
        );
      } else {
        await c.setGeoJsonSource(_userSourceId, data);
      }
      // Follow the user while tracking is on (live fixes only).
      if (live && _tracking && position.timestamp != _lastTrackedFix) {
        _lastTrackedFix = position.timestamp;
        await c.animateCamera(CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)));
      }
    } on Object {
      // The marker is best effort: the map stays usable without it.
    }
  }

  void _onMapClick(math.Point<double> _, LatLng at) {
    final zoom = _controller?.cameraPosition?.zoom ?? mapInitialZoom;
    _openCluster(hitTestClusters(_clusters, at.latitude, at.longitude, zoom));
  }

  /// MapLibre routes taps on a symbol annotation to onSymbolTapped, not to
  /// onMapClick, so marker taps arrive here.
  void _onSymbolTapped(Symbol s) {
    final at = s.options.geometry;
    if (at == null) return;
    // Match by position: the tapped object may not be identical to ours.
    MarkerCluster? best;
    var bestD = double.infinity;
    for (final c in _clusters) {
      final d = (c.lat - at.latitude).abs() + (c.lon - at.longitude).abs();
      if (d < bestD) {
        best = c;
        bestD = d;
      }
    }
    if (best != null && bestD < 1e-6) _openCluster(best);
  }

  void _openCluster(MarkerCluster? hit) {
    if (hit == null) return;
    final zoom = _controller?.cameraPosition?.zoom ?? mapInitialZoom;
    if (hit.isSingle) {
      _showPoint(hit.first);
    } else {
      final move = clusterCameraUpdate(hit, zoom);
      if (move == null) {
        _showPoint(hit.first); // members share one place
      } else {
        _controller?.animateCamera(move);
      }
    }
  }

  Future<void> _showPoint(ShelterPoint p) async {
    final pos = ref.read(positionProvider).value;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bz.bg100,
      builder: (sheetContext) => PointSheet(
        point: p,
        fromLat: pos?.latitude,
        fromLon: pos?.longitude,
        // Routing is post-MVP: Prowadź falls back to the straight-line compass.
        onGuide: () {
          Navigator.of(sheetContext).pop();
          _openCompass(p);
        },
        onCompass: () {
          Navigator.of(sheetContext).pop();
          _openCompass(p);
        },
      ),
    );
  }

  /// B05: compass to the point (straight-line direction and distance).
  void _openCompass(ShelterPoint p) {
    final nav = Navigator.of(context);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => CompassScreen(target: p, onShowMap: nav.pop, onEnd: nav.pop),
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

  Future<void> _showLayers() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bz.bg200,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.all(context.bz.space4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ShelterLayerToggle(
              on: _sheltersOn,
              onChanged: (v) {
                setState(() => _sheltersOn = v);
                setSheetState(() {});
                _refreshShelters();
              },
            ),
          ),
        ),
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
    final fix = ref.watch(gpsFixProvider);
    ref.listen(positionProvider, (_, _) => _syncUserMarker());
    ref.listen(gpsFixProvider, (_, _) => _syncUserMarker());
    final live = position != null && !fix.lastKnownOnly;
    final startAt = position ?? fix.lastKnown;
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
                  initialTarget: startAt == null
                      ? szczecinCentre
                      : LatLng(startAt.latitude, startAt.longitude),
                  initialZoom: mapInitialZoom,
                  // Our own marker layer replaces the native puck (one marker only).
                  myLocationEnabled: false,
                  trackingMode: MyLocationTrackingMode.none,
                  onMapCreated: (c) {
                    _controller = c;
                    c.onSymbolTapped.add(_onSymbolTapped);
                  },
                  onStyleLoaded: () async {
                    _styleReady = true;
                    _markerLayersAdded = false;
                    await _syncUserMarker();
                    await _refreshShelters();
                    await _applyFocus();
                  },
                  onCameraIdle: _refreshShelters,
                  onMapClick: _onMapClick,
                  onCameraMoveStarted: (reason) {
                    // A finger on the map switches tracking off (spec).
                    if (reason == CameraMoveReason.gesture && mounted && _tracking) {
                      setState(() => _tracking = false);
                    }
                  },
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
              child: _notice(access.requireValue, live, fix, startAt),
            ),
          ],
          Positioned(
            // Spec layout: [Warstwy] above [◎] (right-aligned), then the
            // full-width "Najbliższy schron" button, then the attribution.
            left: 16,
            right: 16,
            bottom: 16 + bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LayersButton(onPressed: _showLayers),
                      SizedBox(height: bz.space2 + 2),
                      RecenterButton(
                        enabled: granted && live,
                        active: granted && live && _tracking,
                        onPressed: !live ? null : () => _recenter(position),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: bz.space3),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: bz.minTouchTarget),
                  child: FilledButton(
                    onPressed: _showNearest,
                    child: const Text(nearestButtonText),
                  ),
                ),
                SizedBox(height: bz.space2),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AttributionLabel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(LocationAccess access, bool live, GpsFix fix, Position? at) {
    if (access != LocationAccess.granted) {
      return MapNotice(
        text: permissionDeniedText,
        actionLabel: openPhoneSettingsText,
        onAction: () => ref.read(locationGatewayProvider).openSettings(),
      );
    }
    final line = gpsStatusLine(
      live: live,
      lost: fix.lost,
      lastKnownAt: at?.timestamp,
      now: DateTime.now(),
      searchLong: _searchLong,
    );
    if (line == null) return const SizedBox.shrink();
    return MapNotice(text: line.text, detail: line.detail);
  }
}

const _userSourceId = 'user-position';
const _userHaloLayerId = 'user-position-halo';
const _userDotLayerId = 'user-position-dot';

/// `#rrggbb` for MapLibre style colours.
String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Floating round recenter button, >= 48 dp, same surface as Back.
class RecenterButton extends StatelessWidget {
  const RecenterButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.active = false,
  });

  final bool enabled;

  /// Tracking is on: glyph in the `info` colour (DS `FloatingButton.is-active`).
  final bool active;
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
        opacity: enabled ? 1 : 0.45,
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
                child: Icon(LucideIcons.locateFixed, size: 22, color: active ? bz.info : bz.ink100),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating pill "Warstwy" (spec: opens the layers sheet), >= 48 dp.
class LayersButton extends StatelessWidget {
  const LayersButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    return Semantics(
      container: true,
      button: true,
      label: layersButtonText,
      onTap: onPressed,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: shellFloatDecoration(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: bz.minTouchTarget, minWidth: bz.minTouchTarget),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(bz.radiusFull),
              onTap: onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: bz.space4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.layers, size: 18, color: bz.ink100),
                    SizedBox(width: bz.space2),
                    Text(layersButtonText, style: bz.label.copyWith(color: bz.ink100)),
                  ],
                ),
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
  const MapNotice({super.key, required this.text, this.detail, this.actionLabel, this.onAction});

  final String text;
  final String? detail;
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
              if (detail != null) Text(detail!, style: bz.caption.copyWith(color: bz.ink200)),
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
