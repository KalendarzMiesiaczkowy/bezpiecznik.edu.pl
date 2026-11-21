import 'package:bezpiecznik/czat/llm/llm_engine.dart';
import 'package:bezpiecznik/czat/llm/llm_engine_host.dart';
import 'package:bezpiecznik/wspolne/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Gate h2 (host): measures time-to-first-token against the real bridge.
/// Run: `flutter test integration_test/llm_host_probe_test.dart
///   -d emulator-5554 --dart-define=LLM=host`
/// Prints lines starting `H2:`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('H2 host first token', (tester) async {
    final engine = HostLlmEngine(
      baseUrl: hostLlmBaseUrl,
      noTokenTimeout: const Duration(seconds: 60),
    );
    const prompts = [
      'Podaj numer alarmowy w Polsce jednym zdaniem.',
      'Wymień trzy rzeczy, które warto mieć w plecaku awaryjnym.',
      'Co oznacza słowo "schron"? Odpowiedz krótko.',
    ];
    var ok = 0;
    for (var i = 0; i < prompts.length; i++) {
      final buffer = StringBuffer();
      await for (final t in engine.generate(
        LlmRequest(
          systemPrompt: 'Odpowiadaj po polsku, krótko.',
          messages: [LlmMessage.user(prompts[i])],
          maxTokens: 64,
        ),
      )) {
        buffer.write(t);
      }
      final timing = engine.lastTiming!;
      debugPrint(
        'H2: run=${i + 1} mode=${llmMode.name} '
        'first_token_ms=${timing.timeToFirstToken?.inMilliseconds} '
        'total_ms=${timing.total.inMilliseconds} tokens=${timing.tokenCount} '
        'text="${buffer.toString().replaceAll('\n', ' ')}"',
      );
      if (timing.firstToken != null) ok++;
    }
    await engine.dispose();
    expect(ok, prompts.length);
  });
}
