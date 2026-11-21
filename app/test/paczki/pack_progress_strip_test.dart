import 'package:bezpiecznik/onboarding/location_gateway.dart';
import 'package:bezpiecznik/onboarding/onboarding_screen.dart';
import 'package:bezpiecznik/paczki/pack.dart';
import 'package:bezpiecznik/paczki/pack_controller.dart';
import 'package:bezpiecznik/paczki/pack_progress_strip.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final _map = AssetPack(
  id: mapPackId,
  label: 'mapę woj. zachodniopomorskiego',
  url: Uri.parse('https://example.test/m.mbtiles'),
  fileName: 'm.mbtiles',
  bytes: 100 * 1000 * 1000,
);
final _model = AssetPack(
  id: modelPackId,
  label: 'model AI',
  url: Uri.parse('https://example.test/model.bin'),
  fileName: 'model.bin',
  bytes: 2600 * 1000 * 1000,
);

PacksState _state(PackPhase map, PackPhase model, {int mapGot = 0, int modelGot = 0}) => PacksState(
  started: true,
  packs: [
    PackStatus(_map, phase: map, received: mapGot),
    PackStatus(_model, phase: model, received: modelGot),
  ],
);

class _Packs extends PacksController {
  _Packs(this._initial);

  final PacksState _initial;
  final retried = <String>[];
  final locationDecisions = <bool>[];
  bool cellularAllowed = false;

  @override
  PacksState build() => _initial;

  void set(PacksState next) => state = next;

  @override
  Future<void> retry(String id) async => retried.add(id);

  @override
  void allowCellular() => cellularAllowed = true;

  @override
  void locationDecided({required bool granted}) => locationDecisions.add(granted);
}

class _Permission implements LocationPermissionGateway {
  _Permission(this.result);
  final bool result;

  @override
  Future<bool> request() async => result;
}

void main() {
  group('packStripView', () {
    test('nothing before the download starts', () {
      expect(packStripView(const PacksState()), isNull);
      expect(packStripView(const PacksState(started: true)), isNull);
    });

    test('downloading: names the pack, the amount and the overall progress', () {
      final v = packStripView(
        _state(PackPhase.done, PackPhase.downloading, mapGot: _map.bytes, modelGot: 1200 * 1000 * 1000),
      )!;
      expect(v.title, packStripTitle);
      expect(v.detail, 'Pobieram model AI · 1,2 z 2,6 GB');
      expect(v.fraction, closeTo(1300 / 2700, 0.001));
      expect(v.actionLabel, isNull);
    });

    test('megabyte packs are counted in whole megabytes', () {
      final v = packStripView(
        _state(PackPhase.downloading, PackPhase.waiting, mapGot: 48 * 1000 * 1000),
      )!;
      expect(v.detail, 'Pobieram mapę woj. zachodniopomorskiego · 48 z 100 MB');
    });

    test('waiting for Wi-Fi: states the size and offers mobile data', () {
      final v = packStripView(_state(PackPhase.waitingWifi, PackPhase.waitingWifi))!;
      expect(v.title, packStripWaitWifiTitle);
      expect(v.detail, 'Do pobrania: 2,7 GB.');
      expect(v.action, PackStripAction.allowCellular);
    });

    test('an error wins over a running download and offers a retry', () {
      final v = packStripView(_state(PackPhase.error, PackPhase.downloading))!;
      expect(v.title, packStripErrorTitle);
      expect(v.problem, isTrue);
      expect(v.action, PackStripAction.retry);
    });

    test('no space wins over everything', () {
      final v = packStripView(_state(PackPhase.error, PackPhase.noSpace))!;
      expect(v.title, packStripNoSpaceTitle);
      expect(v.detail, contains('2,7 GB'));
    });

    test('only the map is left and it waits for the location step', () {
      final v = packStripView(_state(PackPhase.waiting, PackPhase.done, modelGot: _model.bytes))!;
      expect(v.detail, packStripMapWaits);
    });

    test('all done', () {
      final v = packStripView(
        _state(PackPhase.done, PackPhase.done, mapGot: _map.bytes, modelGot: _model.bytes),
      )!;
      expect(v.done, isTrue);
      expect(v.title, packStripDoneTitle);
      expect(v.fraction, isNull);
    });

    test('a skipped map does not count: the model alone decides', () {
      final v = packStripView(_state(PackPhase.skipped, PackPhase.done, modelGot: _model.bytes))!;
      expect(v.done, isTrue);
    });
  });

  group('onboarding', () {
    Future<_Packs> pump(
      WidgetTester tester,
      PacksState initial, {
      double textScale = 1,
      Size size = const Size(360, 720),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final packs = _Packs(initial);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileStoreProvider.overrideWithValue(ProfileStore.inMemory()),
            locationPermissionGatewayProvider.overrideWithValue(_Permission(true)),
            packsProvider.overrideWith(() => packs),
          ],
          child: MaterialApp(
            theme: buildBzTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return packs;
    }

    final downloading = _state(
      PackPhase.waiting,
      PackPhase.downloading,
      modelGot: 1248 * 1000 * 1000,
    );

    testWidgets('no strip when nothing is being downloaded', (tester) async {
      await pump(tester, const PacksState());
      expect(find.byKey(const Key('pack-strip')), findsNothing);
    });

    testWidgets('the strip sits above the Dalej button with the percentage', (tester) async {
      await pump(tester, downloading);
      expect(find.text(packStripTitle), findsOneWidget);
      expect(find.text('46%'), findsOneWidget);
      expect(find.text('Pobieram model AI · 1,2 z 2,6 GB'), findsOneWidget);
      final strip = tester.getRect(find.byKey(const Key('pack-strip')));
      final next = tester.getRect(find.byKey(const Key('onb-next')));
      expect(strip.bottom, lessThanOrEqualTo(next.top));
      expect(strip.left, next.left);
    });

    testWidgets('the strip follows the user through every step', (tester) async {
      await pump(tester, downloading);
      await tester.tap(find.byKey(const Key('onb-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pack-strip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onb-allow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pack-strip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onb-profile-fill')));
      await tester.pumpAndSettle();
      final strip = tester.getRect(find.byKey(const Key('pack-strip')));
      final save = tester.getRect(find.byKey(const Key('onb-profile-save')));
      expect(strip.bottom, lessThanOrEqualTo(save.top));
    });

    testWidgets('the location step tells the pack controller the decision', (tester) async {
      final packs = await pump(tester, downloading);
      await tester.tap(find.byKey(const Key('onb-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onb-allow')));
      await tester.pumpAndSettle();
      expect(packs.locationDecisions, [true]);
    });

    testWidgets('"Nie teraz" also releases the map pack', (tester) async {
      final packs = await pump(tester, downloading);
      await tester.tap(find.byKey(const Key('onb-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onb-later')));
      await tester.pumpAndSettle();
      expect(packs.locationDecisions, [false]);
    });

    testWidgets('progress updates in place', (tester) async {
      final packs = await pump(tester, downloading);
      packs.set(_state(PackPhase.waiting, PackPhase.downloading, modelGot: 2000 * 1000 * 1000));
      await tester.pumpAndSettle();
      expect(find.text('74%'), findsOneWidget);
    });

    testWidgets('waiting for Wi-Fi: the button allows mobile data', (tester) async {
      final packs = await pump(tester, _state(PackPhase.waitingWifi, PackPhase.waitingWifi));
      await tester.tap(find.byKey(const Key('pack-strip-action')));
      expect(packs.cellularAllowed, isTrue);
    });

    testWidgets('an error retries every failed pack', (tester) async {
      final packs = await pump(tester, _state(PackPhase.error, PackPhase.error));
      await tester.tap(find.byKey(const Key('pack-strip-action')));
      expect(packs.retried, [mapPackId, modelPackId]);
    });

    Future<void> walk(WidgetTester tester, void Function(String step) check) async {
      check('intro');
      await tester.tap(find.byKey(const Key('onb-next')));
      await tester.pumpAndSettle();
      check('location');
      await tester.tap(find.byKey(const Key('onb-allow')));
      await tester.pumpAndSettle();
      check('profile ask');
      await tester.tap(find.byKey(const Key('onb-profile-fill')));
      await tester.pumpAndSettle();
      check('profile form');
    }

    // The strip must never push the pinned buttons out (BG-style overflow).
    for (final scale in [1.0, 1.25, 1.5, 2.0]) {
      for (final size in const [Size(360, 720), Size(412, 915)]) {
        for (final phase in [PackPhase.downloading, PackPhase.error, PackPhase.waitingWifi]) {
          testWidgets('no overflow: text x$scale, ${size.width.toInt()}x${size.height.toInt()}, ${phase.name}', (
            tester,
          ) async {
            await pump(tester, _state(phase, phase), textScale: scale, size: size);
            await walk(tester, (step) => expect(tester.takeException(), isNull, reason: step));
          });
        }
      }
    }

    testWidgets('the profile form gets the compact strip (no detail line)', (tester) async {
      await pump(tester, downloading);
      await walk(tester, (_) {});
      expect(find.text(packStripTitle), findsOneWidget);
      expect(find.text('46%'), findsOneWidget);
      expect(find.text('Pobieram model AI · 1,2 z 2,6 GB'), findsNothing);
    });

    testWidgets('small screen with large text: the form keeps its room, no strip', (tester) async {
      await pump(tester, downloading, textScale: 1.5);
      var seenOnIntro = false;
      await walk(tester, (step) {
        if (step == 'intro') seenOnIntro = find.byKey(const Key('pack-strip')).evaluate().isNotEmpty;
      });
      expect(seenOnIntro, isTrue);
      expect(find.byKey(const Key('pack-strip')), findsNothing);
    });

    testWidgets('the strip is one spoken unit for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, downloading);
      expect(
        find.bySemanticsLabel('$packStripTitle. 46%. Pobieram model AI · 1,2 z 2,6 GB'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
