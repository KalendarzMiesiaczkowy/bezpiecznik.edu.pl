import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../mapa/position_provider.dart';
import '../mapa/punkty/points_db.dart' show isOutsideRegion;
import '../profil/profile_store.dart';
import '../wspolne/config.dart';
import 'pack.dart';
import 'pack_dir.dart';
import 'pack_downloader.dart';

/// Where one pack is (spec `onb.pkg.state.*`).
enum PackPhase {
  /// Queued: not started yet (e.g. the map waits for the location decision).
  waiting,

  /// Not on Wi-Fi and the user has not allowed mobile data.
  waitingWifi,
  downloading,

  /// Bytes are in, the checksum is being computed.
  verifying,
  done,

  /// Automatic retries are used up; the user can retry.
  error,

  /// The device ran out of storage.
  noSpace,

  /// Not downloaded on purpose: the device is outside the pack's region.
  skipped,
}

class PackStatus {
  const PackStatus(this.pack, {this.phase = PackPhase.waiting, this.received = 0});

  final AssetPack pack;
  final PackPhase phase;

  /// Bytes on disk so far.
  final int received;

  double get fraction => (received / pack.bytes).clamp(0.0, 1.0);

  bool get isDone => phase == PackPhase.done;

  PackStatus copyWith({PackPhase? phase, int? received}) =>
      PackStatus(pack, phase: phase ?? this.phase, received: received ?? this.received);
}

class PacksState {
  const PacksState({this.started = false, this.packs = const []});

  /// False until [PacksController.start] ran: nothing is shown before that.
  final bool started;
  final List<PackStatus> packs;

  PackStatus? byId(String id) {
    for (final s in packs) {
      if (s.pack.id == id) return s;
    }
    return null;
  }

  /// Packs this device downloads (everything except skipped ones).
  Iterable<PackStatus> get wanted => packs.where((s) => s.phase != PackPhase.skipped);

  bool get allDone => started && wanted.every((s) => s.isDone);

  int get totalBytes => wanted.fold(0, (sum, s) => sum + s.pack.bytes);

  int get receivedBytes => wanted.fold(0, (sum, s) => sum + s.received);

  /// Progress of all wanted packs by bytes, 0..1.
  double get fraction => totalBytes == 0 ? 1 : (receivedBytes / totalBytes).clamp(0.0, 1.0);

  PackStatus? firstIn(PackPhase phase) {
    for (final s in packs) {
      if (s.phase == phase) return s;
    }
    return null;
  }
}

/// Everything the controller needs from the platform; faked in tests.
class PackEnv {
  const PackEnv({
    required this.downloader,
    required this.dir,
    required this.onWifi,
    required this.locationGranted,
    required this.firstFix,
    this.networkChanges,
    this.retryDelays = const [Duration(seconds: 2), Duration(seconds: 10), Duration(seconds: 30)],
    this.wifiPoll = const Duration(seconds: 3),
  });

  final PackDownloader downloader;

  /// Directory that holds the downloaded packs.
  final Future<Directory> Function() dir;

  /// True on Wi-Fi or ethernet (unmetered enough for 2.6 GB).
  final Future<bool> Function() onWifi;

  /// Whether location may be read now. Must not show a permission dialog.
  final Future<bool> Function() locationGranted;

  /// Last known or first live position, or null when none arrives in time.
  final Future<({double lat, double lon})?> Function() firstFix;

  /// Fires when the network comes back; failed packs are then retried.
  final Stream<void> Function()? networkChanges;

  /// Pauses before automatic retries (spec: 2 s, 10 s, 30 s).
  final List<Duration> retryDelays;
  final Duration wifiPoll;
}

Future<bool> _onWifi() async {
  try {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);
  } on Object {
    return true; // Cannot tell: do not block the download.
  }
}

Stream<void> _networkBack() => Connectivity().onConnectivityChanged
    .where((r) => r.any((c) => c != ConnectivityResult.none))
    .map((_) {});

Future<bool> _locationGranted() async {
  try {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
  } on Object {
    return false;
  }
}

/// Packs of this build. The model file is only read by the on-device engine,
/// so host and off builds do not download it.
final packCatalogProvider = Provider<List<AssetPack>>(
  (ref) => [
    for (final pack in defaultPackCatalog())
      if (pack.id != modelPackId || llmMode == LlmMode.edge) pack,
  ],
);

final packEnvProvider = Provider<PackEnv>((ref) {
  final downloader = PackDownloader();
  ref.onDispose(downloader.close);
  final gateway = ref.watch(locationGatewayProvider);
  return PackEnv(
    downloader: downloader,
    dir: defaultPacksDir,
    onWifi: _onWifi,
    networkChanges: _networkBack,
    locationGranted: _locationGranted,
    firstFix: () async {
      try {
        final last = await gateway.lastKnown();
        if (last != null) return (lat: last.latitude, lon: last.longitude);
        final fix = await gateway.positions().first.timeout(const Duration(seconds: 20));
        return (lat: fix.latitude, lon: fix.longitude);
      } on Object {
        return null; // No fix in time, services off: region unknown.
      }
    },
  );
});

/// Downloads the packs in the background and exposes their progress.
///
/// The model starts at once. The map pack waits until the app knows whether
/// it may read the location (the onboarding location step, or the stored
/// permission on later starts): it is downloaded unless the device is known to
/// be outside the pack's region.
class PacksController extends Notifier<PacksState> {
  final Map<String, PackCancelToken> _tokens = {};
  final Completer<bool> _location = Completer<bool>();
  final Completer<void> _cellular = Completer<void>();
  bool _allowCellular = false;
  bool _disposed = false;
  StreamSubscription<void>? _network;

  PackEnv get _env => ref.read(packEnvProvider);

  @override
  PacksState build() {
    ref.onDispose(() {
      _disposed = true;
      for (final t in _tokens.values) {
        t.cancel();
      }
      _network?.cancel();
      if (!_cellular.isCompleted) _cellular.complete();
    });
    return const PacksState();
  }

  /// Starts (or resumes) every pack. Safe to call more than once.
  Future<void> start() async {
    if (state.started) return;
    final catalog = ref.read(packCatalogProvider);
    state = PacksState(started: true, packs: [for (final pack in catalog) PackStatus(pack)]);
    _network = _env.networkChanges?.call().listen((_) {
      for (final s in state.packs) {
        if (s.phase == PackPhase.error) unawaited(retry(s.pack.id));
      }
    });
    unawaited(_resolveLocationAfterOnboarding());
    await Future.wait([for (final pack in catalog) _run(pack)]);
  }

  /// After onboarding the location step no longer runs, so the stored
  /// permission decides. During onboarding [locationDecided] is called.
  Future<void> _resolveLocationAfterOnboarding() async {
    var onboarded = true;
    try {
      onboarded = await ref.read(onboardingDoneProvider.future);
    } on Object {
      // Storage error: behave like a returning user.
    }
    if (_disposed || !onboarded || _location.isCompleted) return;
    final granted = await _env.locationGranted();
    if (!_location.isCompleted) _location.complete(granted);
  }

  /// The onboarding location step finished ([granted] or declined).
  void locationDecided({required bool granted}) {
    if (!_location.isCompleted) _location.complete(granted);
  }

  /// The user accepted downloading over mobile data.
  void allowCellular() {
    _allowCellular = true;
    if (!_cellular.isCompleted) _cellular.complete();
  }

  /// Restarts a pack that failed or was skipped (a manual request overrides
  /// the region check).
  Future<void> retry(String id) async {
    final status = state.byId(id);
    if (status == null) return;
    const idle = {PackPhase.error, PackPhase.noSpace, PackPhase.skipped};
    if (!idle.contains(status.phase)) return;
    await _run(status.pack, force: true);
  }

  void _set(AssetPack pack, {PackPhase? phase, int? received}) {
    if (_disposed) return;
    state = PacksState(
      started: true,
      packs: [
        for (final s in state.packs)
          if (s.pack.id == pack.id) s.copyWith(phase: phase, received: received) else s,
      ],
    );
  }

  Future<void> _run(AssetPack pack, {bool force = false}) async {
    try {
      final dir = await _env.dir();
      if (await PackDownloader.isComplete(pack, dir)) {
        _set(pack, phase: PackPhase.done, received: pack.bytes);
        return;
      }
      _set(pack, phase: PackPhase.waiting, received: await PackDownloader.bytesOnDisk(pack, dir));
      if (pack.id == mapPackId && !force && !await _inRegion()) {
        _set(pack, phase: PackPhase.skipped);
        return;
      }
      await _download(pack, dir);
    } on Object {
      // Storage unavailable (no support directory): surface as an error.
      _set(pack, phase: PackPhase.error);
    }
  }

  /// False only when the device is known to be outside the map's region.
  Future<bool> _inRegion() async {
    final granted = await _location.future;
    if (!granted || _disposed) return true;
    final fix = await _env.firstFix();
    return fix == null || !isOutsideRegion(fix.lat, fix.lon);
  }

  Future<void> _download(AssetPack pack, Directory dir) async {
    final delays = _env.retryDelays;
    for (var attempt = 0; ; attempt++) {
      if (!await _waitForNetworkKind(pack)) return;
      final token = PackCancelToken();
      _tokens[pack.id] = token;
      _set(pack, phase: PackPhase.downloading);
      final sinceUpdate = Stopwatch()..start();
      try {
        await _env.downloader.download(
          pack,
          dir,
          cancel: token,
          onVerify: () => _set(pack, phase: PackPhase.verifying, received: pack.bytes),
          onProgress: (received, _) {
            // A 2.6 GB download reports thousands of chunks: repaint ~5x/s.
            if (sinceUpdate.elapsedMilliseconds < 200 && received < pack.bytes) return;
            sinceUpdate.reset();
            _set(pack, received: received);
          },
        );
        _set(pack, phase: PackPhase.done, received: pack.bytes);
        return;
      } on PackDownloadCancelled {
        return;
      } on PackDownloadException catch (e) {
        if (_disposed) return;
        _set(pack, received: await PackDownloader.bytesOnDisk(pack, dir));
        if (e.noSpace) {
          _set(pack, phase: PackPhase.noSpace);
          return;
        }
        if (attempt >= delays.length) {
          _set(pack, phase: PackPhase.error);
          return;
        }
        await Future<void>.delayed(delays[attempt]);
        if (_disposed) return;
      }
    }
  }

  /// Waits until the pack may use the current network. False when disposed.
  Future<bool> _waitForNetworkKind(AssetPack pack) async {
    while (!_allowCellular && !await _env.onWifi()) {
      if (_disposed) return false;
      _set(pack, phase: PackPhase.waitingWifi);
      await Future.any([Future<void>.delayed(_env.wifiPoll), _cellular.future]);
    }
    return !_disposed;
  }
}

final packsProvider = NotifierProvider<PacksController, PacksState>(PacksController.new);

/// One line for the chat when it shows source quotes because the model file
/// is not on the device yet; null when the model is there (or not a pack of
/// this build), so nothing needs explaining.
String? modelPendingNote(PacksState state) {
  final model = state.byId(modelPackId);
  if (model == null) return null;
  const quotes = 'Na razie pokazuję fragmenty poradników.';
  return switch (model.phase) {
    PackPhase.done || PackPhase.skipped => null,
    PackPhase.waitingWifi => 'Model AI czeka na Wi-Fi. $quotes',
    PackPhase.error || PackPhase.noSpace =>
      'Model AI nie jest pobrany (Ustawienia → Paczki danych). $quotes',
    PackPhase.waiting || PackPhase.downloading || PackPhase.verifying =>
      'Model AI jeszcze się pobiera (${(model.fraction * 100).floor()}%). $quotes',
  };
}
