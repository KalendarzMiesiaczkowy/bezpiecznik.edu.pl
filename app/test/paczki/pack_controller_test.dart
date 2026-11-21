import 'dart:async';
import 'dart:io';

import 'package:bezpiecznik/paczki/pack.dart';
import 'package:bezpiecznik/paczki/pack_controller.dart';
import 'package:bezpiecznik/paczki/pack_downloader.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

class _Done extends OnboardingDoneNotifier {
  _Done(this.value);
  final bool value;

  @override
  Future<bool> build() async => value;
}

final _map = AssetPack(
  id: mapPackId,
  label: 'mapę',
  url: Uri.parse('https://example.test/map.mbtiles'),
  fileName: 'map.mbtiles',
  bytes: 5000,
);
final _model = AssetPack(
  id: modelPackId,
  label: 'model AI',
  url: Uri.parse('https://example.test/model.bin'),
  fileName: 'model.bin',
  bytes: 15000,
);

// Szczecin (inside the bundled region) and Warsaw (outside).
const _szczecin = (lat: 53.43, lon: 14.55);
const _warsaw = (lat: 52.23, lon: 21.01);

void main() {
  late Directory dir;
  late List<String> requested;
  var failures = 0;

  MockClient server() => MockClient.streaming((request, _) async {
    requested.add(request.url.pathSegments.last);
    if (failures > 0) {
      failures--;
      throw const SocketException('offline');
    }
    final size = request.url.path.contains('map') ? _map.bytes : _model.bytes;
    final from = int.parse(
      RegExp(r'bytes=(\d+)-').firstMatch(request.headers['range'] ?? 'bytes=0-')!.group(1)!,
    );
    return http.StreamedResponse(
      Stream.value(List<int>.filled(size - from, 7)),
      from > 0 ? 206 : 200,
    );
  });

  ProviderContainer container({
    bool onboarded = true,
    bool wifi = true,
    bool Function()? wifiNow,
    bool locationGranted = false,
    ({double lat, double lon})? fix,
    Stream<void> Function()? networkChanges,
  }) {
    final c = ProviderContainer(
      overrides: [
        onboardingDoneProvider.overrideWith(() => _Done(onboarded)),
        packCatalogProvider.overrideWithValue([_map, _model]),
        packEnvProvider.overrideWithValue(
          PackEnv(
            downloader: PackDownloader(client: server()),
            dir: () async => dir,
            onWifi: () async => wifiNow?.call() ?? wifi,
            locationGranted: () async => locationGranted,
            firstFix: () async => fix,
            networkChanges: networkChanges,
            retryDelays: const [Duration.zero, Duration.zero],
            wifiPoll: const Duration(milliseconds: 5),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  PackPhase phase(ProviderContainer c, String id) => c.read(packsProvider).byId(id)!.phase;

  setUp(() async {
    final root = Directory(p.join(Directory.current.path, '.dart_tool', 'test_tmp'));
    await root.create(recursive: true);
    dir = await root.createTemp('packs_ctl_');
    requested = [];
    failures = 0;
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('nothing is shown or downloaded before start', () {
    final c = container();
    expect(c.read(packsProvider).started, isFalse);
    expect(c.read(packsProvider).packs, isEmpty);
    expect(requested, isEmpty);
  });

  test('start downloads every pack and reports overall progress', () async {
    final c = container();
    await c.read(packsProvider.notifier).start();
    final s = c.read(packsProvider);
    expect(s.allDone, isTrue);
    expect(s.fraction, 1);
    expect(File(p.join(dir.path, 'map.mbtiles')).lengthSync(), _map.bytes);
    expect(File(p.join(dir.path, 'model.bin')).lengthSync(), _model.bytes);
  });

  test('files already on the device are not downloaded again', () async {
    await File(p.join(dir.path, 'map.mbtiles')).writeAsBytes(List.filled(_map.bytes, 1));
    await File(p.join(dir.path, 'model.bin')).writeAsBytes(List.filled(_model.bytes, 1));
    final c = container();
    await c.read(packsProvider.notifier).start();
    expect(c.read(packsProvider).allDone, isTrue);
    expect(requested, isEmpty);
  });

  test('without Wi-Fi nothing is downloaded until mobile data is allowed', () async {
    final c = container(wifi: false);
    final run = c.read(packsProvider.notifier).start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(phase(c, modelPackId), PackPhase.waitingWifi);
    expect(phase(c, mapPackId), PackPhase.waitingWifi);
    expect(requested, isEmpty);

    c.read(packsProvider.notifier).allowCellular();
    await run;
    expect(c.read(packsProvider).allDone, isTrue);
  });

  test('the download starts by itself when Wi-Fi appears', () async {
    var wifi = false;
    final c = container(wifiNow: () => wifi);
    final run = c.read(packsProvider.notifier).start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(requested, isEmpty);
    wifi = true;
    await run;
    expect(c.read(packsProvider).allDone, isTrue);
  });

  test('inside the region the map pack is downloaded', () async {
    final c = container(locationGranted: true, fix: _szczecin);
    await c.read(packsProvider.notifier).start();
    expect(phase(c, mapPackId), PackPhase.done);
  });

  test('outside the region the map pack is skipped, the model is not', () async {
    final c = container(locationGranted: true, fix: _warsaw);
    await c.read(packsProvider.notifier).start();
    expect(phase(c, mapPackId), PackPhase.skipped);
    expect(phase(c, modelPackId), PackPhase.done);
    expect(requested, ['model.bin']);
    // Skipped packs do not hold the overall progress back.
    expect(c.read(packsProvider).allDone, isTrue);
    expect(c.read(packsProvider).fraction, 1);
  });

  test('a skipped map pack can be downloaded on request', () async {
    final c = container(locationGranted: true, fix: _warsaw);
    await c.read(packsProvider.notifier).start();
    await c.read(packsProvider.notifier).retry(mapPackId);
    expect(phase(c, mapPackId), PackPhase.done);
  });

  test('without a position the map pack is downloaded', () async {
    final c = container(locationGranted: true);
    await c.read(packsProvider.notifier).start();
    expect(phase(c, mapPackId), PackPhase.done);
  });

  test('during onboarding the map pack waits for the location step', () async {
    final c = container(onboarded: false, fix: _szczecin);
    final run = c.read(packsProvider.notifier).start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(phase(c, mapPackId), PackPhase.waiting);
    expect(phase(c, modelPackId), PackPhase.done); // the model does not wait
    expect(requested, ['model.bin']);

    c.read(packsProvider.notifier).locationDecided(granted: true);
    await run;
    expect(phase(c, mapPackId), PackPhase.done);
  });

  test('declining location in onboarding still downloads the map pack', () async {
    final c = container(onboarded: false, fix: _warsaw);
    final run = c.read(packsProvider.notifier).start();
    c.read(packsProvider.notifier).locationDecided(granted: false);
    await run;
    expect(phase(c, mapPackId), PackPhase.done);
  });

  test('a failing download is retried automatically', () async {
    failures = 2; // first request of each pack
    final c = container();
    await c.read(packsProvider.notifier).start();
    expect(c.read(packsProvider).allDone, isTrue);
  });

  test('after the automatic retries the pack shows an error and can be retried', () async {
    failures = 1000;
    final c = container();
    await c.read(packsProvider.notifier).start();
    expect(phase(c, modelPackId), PackPhase.error);
    expect(phase(c, mapPackId), PackPhase.error);
    expect(c.read(packsProvider).allDone, isFalse);

    failures = 0;
    await c.read(packsProvider.notifier).retry(modelPackId);
    expect(phase(c, modelPackId), PackPhase.done);
    expect(phase(c, mapPackId), PackPhase.error);
  });

  test('failed packs resume when the network comes back', () async {
    failures = 1000;
    final network = StreamController<void>.broadcast();
    addTearDown(network.close);
    final c = container(networkChanges: () => network.stream);
    await c.read(packsProvider.notifier).start();
    expect(phase(c, modelPackId), PackPhase.error);

    failures = 0;
    network.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(packsProvider).allDone, isTrue);
  });

  test('start is idempotent', () async {
    final c = container();
    await c.read(packsProvider.notifier).start();
    final before = requested.length;
    await c.read(packsProvider.notifier).start();
    expect(requested.length, before);
  });

  group('modelPendingNote', () {
    PacksState model(PackPhase phase, {int received = 0}) =>
        PacksState(started: true, packs: [PackStatus(_model, phase: phase, received: received)]);

    test('nothing to explain when the model is on the device or not a pack of this build', () {
      expect(modelPendingNote(model(PackPhase.done, received: _model.bytes)), isNull);
      expect(modelPendingNote(const PacksState(started: true)), isNull);
      expect(modelPendingNote(const PacksState()), isNull);
    });

    test('downloading: says how far it is', () {
      expect(
        modelPendingNote(model(PackPhase.downloading, received: 6900)),
        'Model AI jeszcze się pobiera (46%). Na razie pokazuję fragmenty poradników.',
      );
    });

    test('waiting for Wi-Fi and failed downloads say what blocks the model', () {
      expect(modelPendingNote(model(PackPhase.waitingWifi)), startsWith('Model AI czeka na Wi-Fi.'));
      expect(modelPendingNote(model(PackPhase.error)), contains('Ustawienia → Paczki danych'));
    });
  });
}
