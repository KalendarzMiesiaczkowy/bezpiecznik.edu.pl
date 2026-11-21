import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ratunek/ui/rescue_answer.dart';
import 'answer/pipeline_answer_service.dart';
import 'intent/map_answer.dart';
import 'ui/answer_service.dart';

/// Production answer order (spec ekran-1-czat.md, zakres-mvp.md):
/// 1. risk phrase → rescue card, no model (< 1 s);
/// 2. shelter / where-to-go / hospital intent → `map` template, no model;
/// 3. everything else → the sourced answer pipeline (retrieval + model).
class RoutedAnswerService implements AnswerService {
  RoutedAnswerService({required this.rescue, required this.map, required this.pipeline});

  final Future<RescueAnswerService> Function() rescue;
  final MapAnswerService map;
  final AnswerService pipeline;

  @override
  Stream<AnswerEvent> answer(String question, ChatContext ctx) async* {
    final card = await (await rescue()).tryAnswer(question);
    if (card != null) {
      yield AnswerReady(card);
      return;
    }
    final mapAnswer = await map.tryAnswer(question);
    if (mapAnswer != null) {
      yield AnswerReady(mapAnswer);
      return;
    }
    yield* pipeline.answer(question, ctx);
  }
}

/// Wired as the default of `answerServiceProvider`.
final routedAnswerServiceProvider = Provider<AnswerService>(
  (ref) => RoutedAnswerService(
    rescue: () => ref.read(rescueAnswerServiceProvider.future),
    map: ref.watch(mapAnswerServiceProvider),
    pipeline: ref.watch(pipelineAnswerServiceProvider),
  ),
);
