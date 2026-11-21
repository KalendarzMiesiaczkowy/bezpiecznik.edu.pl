import 'dart:async';
import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'llm_engine.dart';

/// User-facing message when the model file is not on the device.
const String edgeModelMissingMessage = 'Model AI nie jest jeszcze pobrany.';

/// File name of the Gemma 4 E2B LiteRT-LM model.
const String edgeModelFileName = 'gemma-4-E2B-it.litertlm';

/// Directories searched for [edgeModelFileName], in order.
typedef ModelDirsProvider = Future<List<String>> Function();

/// App documents dir first, then the app-specific external dir (reachable by
/// `adb push` without root).
Future<List<String>> defaultModelDirs() async {
  final dirs = <String>[];
  try {
    dirs.add((await getApplicationDocumentsDirectory()).path);
  } catch (_) {}
  try {
    final ext = await getExternalStorageDirectory();
    if (ext != null) dirs.add(ext.path);
  } catch (_) {}
  return dirs;
}

/// Thin seam over `flutter_edge_ai`, so the engine logic is testable on host.
abstract class EdgeRuntime {
  Future<void> load(String modelPath);
  Stream<String> run(LlmRequest req);
  Future<void> stop();
  Future<void> close();
}

/// Real runtime. Touches the native plugin only from [load].
class FlutterEdgeAiRuntime implements EdgeRuntime {
  FlutterEdgeAiRuntime({this.inferenceEngines = const []});

  /// Engine providers for `FlutterEdgeAi.initialize` (core registers none):
  /// pass `[LiteRtLmEngine()]` from `flutter_edge_ai_litertlm`.
  final List<InferenceEngineProvider> inferenceEngines;

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _stopped = false;

  @override
  Future<void> load(String modelPath) async {
    await FlutterEdgeAi.initialize(inferenceEngines: inferenceEngines);
    await FlutterEdgeAi.installModel(
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
    ).fromFile(modelPath).install();
    _model = await FlutterEdgeAi.getActiveModel(maxTokens: 4096);
  }

  static String _flatten(List<LlmMessage> messages) {
    if (messages.length == 1) return messages.single.content;
    return messages
        .map((m) => '${m.role == LlmRole.user ? 'User' : 'Assistant'}: ${m.content}')
        .join('\n');
  }

  Future<InferenceChat> _open(InferenceModel model, LlmRequest req, ResponseFormat? format) {
    return model.openChat(
      temperature: req.temperature,
      enableThinking: false,
      systemInstruction: req.systemPrompt.isEmpty ? null : req.systemPrompt,
      maxOutputTokens: req.maxTokens,
      modelType: ModelType.gemma4,
      responseFormat: format,
    );
  }

  @override
  Stream<String> run(LlmRequest req) async* {
    final model = _model;
    if (model == null) throw const LlmError('Edge model not loaded');
    _stopped = false;

    ResponseFormat? format;
    if (req.jsonSchema != null) {
      format = ResponseFormat.jsonSchema(req.jsonSchema!);
    } else if (req.jsonMode) {
      format = ResponseFormat.jsonObject();
    }
    InferenceChat chat;
    try {
      chat = await _open(model, req, format);
    } on ResponseFormatUnsupportedException {
      // Fallback path of lokalne-ai.md: schema is described in the prompt.
      chat = await _open(model, req, null);
    }
    _chat = chat;
    try {
      await chat.addQuery(Message.text(text: _flatten(req.messages), isUser: true));
      await for (final r in chat.generateChatResponseAsync()) {
        if (_stopped) break;
        if (r is TextResponse && r.token.isNotEmpty) yield r.token;
      }
    } finally {
      _chat = null;
      await chat.close();
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    await _chat?.stopGeneration();
  }

  @override
  Future<void> close() async {
    await stop();
    await _model?.close();
    _model = null;
  }
}

/// On-device LiteRT-LM engine (arm64 only). Nothing native is touched until
/// the first [warmUp].
class EdgeAiEngine implements LlmEngine {
  EdgeAiEngine({
    EdgeRuntime? runtime,
    ModelDirsProvider? modelDirs,
    this.noTokenTimeout = const Duration(seconds: 20),
    this.onTiming,
  }) : _runtime = runtime ?? FlutterEdgeAiRuntime(),
       _modelDirs = modelDirs ?? defaultModelDirs;

  final EdgeRuntime _runtime;
  final ModelDirsProvider _modelDirs;
  final Duration noTokenTimeout;
  final void Function(LlmTiming timing)? onTiming;

  Future<void>? _warm;
  LlmTiming? _lastTiming;
  bool _cancelled = false;

  @override
  LlmInfo get info => const LlmInfo(name: 'edge', model: edgeModelFileName);

  @override
  LlmTiming? get lastTiming => _lastTiming;

  Future<String?> _findModel() async {
    for (final dir in await _modelDirs()) {
      final path = p.join(dir, edgeModelFileName);
      if (await File(path).exists()) return path;
    }
    return null;
  }

  @override
  Future<void> warmUp() {
    return _warm ??= _load().catchError((Object e) {
      _warm = null; // allow a retry, e.g. after `adb push`
      throw e;
    });
  }

  Future<void> _load() async {
    final path = await _findModel();
    if (path == null) throw const LlmUnavailable(edgeModelMissingMessage);
    try {
      await _runtime.load(path);
    } on LlmException {
      rethrow;
    } catch (e) {
      throw LlmUnavailable('$edgeModelMissingMessage ($e)');
    }
  }

  @override
  Stream<String> generate(LlmRequest req) async* {
    _cancelled = false;
    final timer = LlmTimer('edge');
    var cancelled = false;
    try {
      await warmUp();
      final it = StreamIterator<String>(_runtime.run(req));
      try {
        while (true) {
          final Future<bool> next = it.moveNext();
          final bool has = await (timer.tokenCount == 0 ? next.timeout(noTokenTimeout) : next);
          if (!has) break;
          timer.token();
          yield it.current;
        }
      } finally {
        // Not awaited: a native stream stuck mid-generation never completes
        // its cancellation.
        unawaited(it.cancel());
      }
      cancelled = _cancelled;
    } on TimeoutException {
      await _runtime.stop();
      throw const LlmTimeout();
    } on LlmException {
      rethrow;
    } catch (e) {
      if (_cancelled) {
        cancelled = true;
      } else {
        throw LlmError(e.toString());
      }
    } finally {
      final timing = timer.finish(cancelled: cancelled || _cancelled);
      _lastTiming = timing;
      onTiming?.call(timing);
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await _runtime.stop();
  }

  @override
  Future<void> dispose() async {
    if (_warm != null) await _runtime.close();
    _warm = null;
  }
}
