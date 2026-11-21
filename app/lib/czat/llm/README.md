# LLM adapter (`czat/llm`)

`LlmEngine` is the only AI entry point for the chat. Selection by
`--dart-define=LLM=host|edge|off` (see `wspolne/config.dart`); `llmEngineProvider`
builds the engine and disposes it.

| Mode | Engine | Notes |
|---|---|---|
| host | `HostLlmEngine` | llama-server, OpenAI-compatible, `http://127.0.0.1:8080` (`adb reverse tcp:8080 tcp:8080`). Override with `--dart-define=LLM_URL=...`. Thinking off, SSE streaming, `json_object` by default. |
| edge | `EdgeAiEngine` | `flutter_edge_ai` + LiteRT-LM, arm64 only. Native code is touched only at the first `warmUp()`. |
| off | `OffEngine` | `generate` fails with `LlmDisabled`; chat shows source quotes. |

Every generation logs `ttft`, `total`, token count via `dart:developer`
(`name: 'llm'`) and exposes it as `lastTiming`.

## On-device model (edge mode)

File name: `gemma-4-E2B-it.litertlm`. Looked up in this order:

1. `getApplicationDocumentsDirectory()` -> `/data/user/0/pl.edu.bezpiecznik.bezpiecznik/app_flutter/`
   (not writable by `adb push` without root; `run-as` only on debug builds)
2. `getExternalStorageDirectory()` -> `/sdcard/Android/data/pl.edu.bezpiecznik.bezpiecznik/files/`

Push without root:

```
adb shell mkdir -p /sdcard/Android/data/pl.edu.bezpiecznik.bezpiecznik/files
adb push gemma-4-E2B-it.litertlm /sdcard/Android/data/pl.edu.bezpiecznik.bezpiecznik/files/
```

Missing file -> `LlmUnavailable('Model AI nie jest jeszcze pobrany.')`.

## Dependency note

`flutter_edge_ai` core registers no inference engine. Edge mode needs
`flutter_edge_ai_litertlm` in pubspec and `edgeInferenceEnginesProvider`
overridden with `[LiteRtLmEngine()]` (or passed to `createLlmEngine`).
Without it the first `warmUp()` fails with `LlmUnavailable`.

## JSON output

`LlmRequest.jsonMode` -> `response_format: json_object` (host) /
`ResponseFormat.jsonObject()` (edge). With `jsonSchema`: edge uses
`ResponseFormat.jsonSchema`, falling back to no format when refused
(`ResponseFormatUnsupportedException`); host sends `json_object` unless
`useJsonSchemaFormat: true`. In the fallback the schema must be in the prompt.
