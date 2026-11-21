import 'package:bezpiecznik/czat/llm/llm_provider.dart';
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
}
