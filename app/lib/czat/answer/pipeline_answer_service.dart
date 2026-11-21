/// The real answer pipeline: retrieval -> prompt -> LLM -> tolerant parse
/// (1 retry) -> validation -> panels. AI is always on; the model only
/// rephrases retrieved chunks, never answers from its own knowledge.
library;

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profil/profile_store.dart';
import '../../ratunek/detect/risk_detector.dart';
import '../../ustawienia/settings_store.dart';
import '../intent/shelter_intent.dart' show isAlarmQuickAction;
import '../llm/llm_engine.dart';
import '../llm/llm_engine_off.dart';
import '../llm/llm_provider.dart';
import '../retrieval/retrieval_provider.dart';
import '../retrieval/retriever.dart';
import '../templates/panel_model.dart';
import '../ui/answer_service.dart';
import 'answer_builder.dart';
import 'answer_parser.dart';
import 'answer_prompt.dart';
import 'answer_validator.dart';

typedef SearchFn = Future<RetrievalResult> Function(String question);

/// Retrieval / prompt query for the "Alarm / schron" quick action.
const String kAlarmQuery = 'sygnały alarmowe syreny alarm schron';

AssistantAnswer _withShelterMap(AssistantAnswer a) => a.copyWith(
  panels: [
    ...a.panels,
    const MapPanel(
      target: 'nearest_shelter',
      raw: {'type': 'map', 'target': 'nearest_shelter'},
    ),
  ],
);

class PipelineAnswerService implements AnswerService {
  PipelineAnswerService({
    required this.search,
    required this.engine,
    required this.isRisk,
    this.profileContext,
    this.noAi,
    AnswerValidator? validator,
    this.onLog,
  }) : validator = validator ?? AnswerValidator();

  final SearchFn search;
  final LlmEngine engine;

  /// Risk phrase check on the user's question only (never on model output).
  final FutureOr<bool> Function(String question) isRisk;

  /// Compact profile context for the prompt; empty / null when unavailable.
  final Future<String> Function()? profileContext;
  final AnswerValidator validator;

  /// "Tryb bez AI", asked once per request (the setting may still be loading
  /// at a cold start). When true the model is never called: source quotes only.
  final Future<bool> Function()? noAi;

  /// Diagnostics (rejected items, retries); no user data beyond the question.
  final void Function(String message)? onLog;

  @override
  Stream<AnswerEvent> answer(String question, ChatContext ctx) {
    final run = _Run(engine);
    late final StreamController<AnswerEvent> out;
    out = StreamController<AnswerEvent>(
      onListen: () => unawaited(_execute(question, ctx, run, out)),
      onCancel: run.cancel,
    );
    return out.stream;
  }

  Future<void> _execute(
    String question,
    ChatContext ctx,
    _Run run,
    StreamController<AnswerEvent> out,
  ) async {
    void emit(AnswerEvent e) {
      if (!run.cancelled && !out.isClosed) out.add(e);
    }

    try {
      if (await _noAiMode()) run.engine = OffEngine();
      if (run.cancelled) return;
      emit(const AnswerThinking(ThinkingPhase.searching));
      // "Alarm / schron" quick action: ask for the alarm signals and add the
      // nearest-shelter map card to whatever the sources give.
      final alarm = isAlarmQuickAction(question);
      if (alarm) question = kAlarmQuery;
      final result = await search(question);
      if (run.cancelled) return;
      final risk = await isRisk(question);
      if (run.cancelled) return;

      if (result.decision != RetrievalDecision.found || result.chunks.isEmpty) {
        final kind = result.decision == RetrievalDecision.offTopic
            ? NoSourceKind.offTopic
            : NoSourceKind.noSource;
        final refusal = buildRefusal(kind, risk: risk);
        emit(AnswerReady(alarm ? _withShelterMap(refusal) : refusal));
        return;
      }

      final chunks = result.chunks;
      emit(const AnswerThinking(ThinkingPhase.composing));
      final ctxText = await _profile();
      if (run.cancelled) return;

      final answer = await _compose(
        question: question,
        previous: ctx.previousQuestion,
        profile: ctxText,
        chunks: chunks,
        risk: risk,
        run: run,
      );
      if (answer != null) emit(AnswerReady(alarm ? _withShelterMap(answer) : answer));
    } catch (e) {
      // Retrieval or an unexpected bug: never crash the chat.
      onLog?.call('pipeline error: $e');
      emit(const AnswerFailed('Nie udało się przygotować odpowiedzi. Spróbuj ponownie.'));
    } finally {
      if (!out.isClosed) await out.close();
    }
  }

  Future<bool> _noAiMode() async {
    try {
      return await noAi?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> _profile() async {
    try {
      return await profileContext?.call() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Null when cancelled.
  Future<AssistantAnswer?> _compose({
    required String question,
    required String? previous,
    required String profile,
    required List<KbChunk> chunks,
    required bool risk,
    required _Run run,
  }) async {
    final prompted = chunks.take(kMaxPromptChunks).toList();
    for (var attempt = 0; attempt < 2; attempt++) {
      final req = buildAnswerRequest(
        question: question,
        previousQuestion: previous,
        profileContext: profile,
        chunks: prompted,
        retry: attempt > 0,
      );
      final String text;
      try {
        text = await run.collect(req);
      } catch (e) {
        if (run.cancelled) return null;
        onLog?.call('llm unavailable: $e');
        return buildQuoteFallback(
          prompted,
          risk: risk,
          modelOff: true,
          note: e is LlmTimeout ? kLlmTimeoutNote : null,
        );
      }
      if (run.cancelled) return null;

      final json = parseModelJson(text);
      if (json == null) {
        onLog?.call('unparseable model output (attempt ${attempt + 1}): ${text.length > 400 ? text.substring(0, 400) : text}');
        continue;
      }
      final raw = json['panels'];
      if (raw is List && raw.isEmpty) {
        // The model itself says the fragments do not answer the question.
        return buildRefusal(NoSourceKind.noSource, risk: risk);
      }
      final v = validator.validate(json, prompted);
      for (final r in v.rejected) {
        onLog?.call('rejected $r');
      }
      if (!v.hasContent) {
        return buildQuoteFallback(prompted, risk: risk, modelOff: false);
      }
      return buildModelAnswer(v.panels, prompted, risk: risk);
    }
    return buildQuoteFallback(prompted, risk: risk, modelOff: false);
  }
}

/// State of one answer: cancellation and the running LLM subscription.
class _Run {
  _Run(this.engine);

  LlmEngine engine;
  bool cancelled = false;
  StreamSubscription<String>? _sub;
  Completer<String>? _pending;

  /// Collects the whole generation. Completes with '' when cancelled.
  Future<String> collect(LlmRequest req) {
    final done = Completer<String>();
    _pending = done;
    final buf = StringBuffer();
    _sub = engine.generate(req).listen(
      (t) => buf.write(t),
      onError: (Object e, StackTrace st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
      onDone: () {
        if (!done.isCompleted) done.complete(buf.toString());
      },
      cancelOnError: true,
    );
    return done.future;
  }

  Future<void> cancel() async {
    if (cancelled) return;
    cancelled = true;
    final sub = _sub;
    _sub = null;
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete('');
    await sub?.cancel();
    await engine.cancel();
  }
}

/// Loads the risk detector from the bundled phrase assets.
final answerRiskDetectorProvider = FutureProvider<RiskDetector>(
  (ref) => RiskDetector.load(rootBundle),
);

/// The pipeline wired to the real providers. The coordinator points
/// `answerServiceProvider` at this.
final pipelineAnswerServiceProvider = Provider<AnswerService>((ref) {
  return PipelineAnswerService(
    search: (q) async => (await ref.read(retrieverProvider.future)).search(q),
    engine: ref.watch(llmEngineProvider),
    // "Tryb bez AI" (opt-in): awaits the settings so the first question after
    // a cold start already honours it.
    noAi: () async => (await ref.read(settingsProvider.future)).noAiMode,
    isRisk: (q) async {
      try {
        return (await ref.read(answerRiskDetectorProvider.future)).isRisk(q);
      } catch (_) {
        return false;
      }
    },
    profileContext: () async =>
        (await ref.read(profileProvider.future)).toPromptContext(),
  );
});
