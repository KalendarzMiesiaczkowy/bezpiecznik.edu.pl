import 'package:flutter_edge_ai/flutter_edge_ai.dart' show InferenceEngineProvider;
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart'
    show LiteRtLmEngine;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wspolne/config.dart';
import 'llm_engine.dart';
import 'llm_engine_edge.dart';
import 'llm_engine_host.dart';
import 'llm_engine_off.dart';

/// Active mode; override in tests (`llmModeProvider.overrideWithValue(...)`).
final llmModeProvider = Provider<LlmMode>((ref) => llmMode);

/// Engine providers handed to `FlutterEdgeAi.initialize` in edge mode. Core
/// registers none, so the LiteRT-LM engine (`.litertlm`, arm64) is supplied
/// here. Constructing it is a pure factory; nothing native loads until the
/// edge engine's first `warmUp()`.
final edgeInferenceEnginesProvider = Provider<List<InferenceEngineProvider>>(
  (ref) => const [LiteRtLmEngine()],
);

/// Builds the engine for [mode]. Nothing native is touched here.
LlmEngine createLlmEngine(
  LlmMode mode, {
  String hostUrl = hostLlmBaseUrl,
  List<InferenceEngineProvider> edgeEngines = const [],
}) {
  switch (mode) {
    case LlmMode.host:
      return HostLlmEngine(baseUrl: hostUrl);
    case LlmMode.edge:
      return EdgeAiEngine(
        runtime: FlutterEdgeAiRuntime(inferenceEngines: edgeEngines),
      );
    case LlmMode.off:
      return OffEngine();
  }
}

final llmEngineProvider = Provider<LlmEngine>((ref) {
  final engine = createLlmEngine(
    ref.watch(llmModeProvider),
    edgeEngines: ref.watch(edgeInferenceEnginesProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});
