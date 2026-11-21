import 'package:bezpiecznik/czat/llm/llm_provider.dart';
import 'package:bezpiecznik/paczki/pack.dart';
import 'package:bezpiecznik/paczki/pack_controller.dart';
import 'package:bezpiecznik/ustawienia/settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../answer/fakes.dart';

class _CountingEngine extends FakeEngine {
  _CountingEngine() : super(const []);
  int warmUps = 0;
  @override
  Future<void> warmUp() async => warmUps++;
}

void main() {
  Future<int> warmUpsWith({required bool noAi}) async {
    final store = SettingsStore.inMemory();
    await store.save(AppSettings(noAiMode: noAi));
    final engine = _CountingEngine();
    final c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      llmEngineProvider.overrideWithValue(engine),
    ]);
    addTearDown(c.dispose);
    await c.read(llmWarmUpProvider.future);
    return engine.warmUps;
  }

  test('loads the model in the background', () async {
    expect(await warmUpsWith(noAi: false), 1);
  });

  test('skips the load in "Tryb bez AI"', () async {
    expect(await warmUpsWith(noAi: true), 0);
  });

  group('model downloaded by the app', () {
    final model = AssetPack(
      id: modelPackId,
      label: 'model AI',
      url: Uri.parse('https://example.test/model.bin'),
      fileName: 'model.bin',
      bytes: 10,
    );

    test('waits while the model is still downloading, loads when it lands', () async {
      final engine = _CountingEngine();
      final packs = _Packs(PacksState(started: true, packs: [PackStatus(model, phase: PackPhase.downloading)]));
      final c = ProviderContainer(overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.inMemory()),
        llmEngineProvider.overrideWithValue(engine),
        packsProvider.overrideWith(() => packs),
      ]);
      addTearDown(c.dispose);
      c.listen(llmWarmUpProvider, (_, _) {}); // keep it alive like the chat screen
      await c.read(llmWarmUpProvider.future);
      expect(engine.warmUps, 0);

      packs.set(PacksState(started: true, packs: [PackStatus(model, phase: PackPhase.done, received: 10)]));
      await c.read(llmWarmUpProvider.future);
      expect(engine.warmUps, 1);
    });
  });
}

class _Packs extends PacksController {
  _Packs(this._initial);
  final PacksState _initial;

  @override
  PacksState build() => _initial;

  void set(PacksState next) => state = next;
}
