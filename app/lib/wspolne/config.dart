import 'package:flutter/foundation.dart';

/// Which LLM backend the build uses: `--dart-define=LLM=host|edge|off`.
///
/// Debug/emulator defaults to `host` (llama-server through `adb reverse`),
/// release defaults to `edge` (on-device LiteRT-LM).
enum LlmMode { host, edge, off }

const String _llmDefine = String.fromEnvironment('LLM');

LlmMode get llmMode {
  switch (_llmDefine) {
    case 'host':
      return LlmMode.host;
    case 'edge':
      return LlmMode.edge;
    case 'off':
      return LlmMode.off;
    default:
      return kReleaseMode ? LlmMode.edge : LlmMode.host;
  }
}

/// Host LLM bridge base URL (OpenAI-compatible), reachable via `adb reverse`.
const String hostLlmBaseUrl = String.fromEnvironment(
  'LLM_URL',
  defaultValue: 'http://127.0.0.1:8080',
);
