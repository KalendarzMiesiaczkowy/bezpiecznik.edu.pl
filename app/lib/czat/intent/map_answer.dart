import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../templates/panel_model.dart';
import 'shelter_intent.dart';

/// Answers the "schron / gdzie iść / szpital" intent with a `map` template.
/// No model, no retrieval threshold (zakres-mvp.md). Distances and points are
/// computed by the card at display time, never stored in the message.
class MapAnswerService {
  const MapAnswerService();

  /// Null when [question] carries no map intent.
  Future<AssistantAnswer?> tryAnswer(String question) async {
    final intent = detectShelterIntent(question);
    if (intent == null) return null;
    return answerFor(intent);
  }

  AssistantAnswer answerFor(ShelterIntent intent) => AssistantAnswer(
    panels: [
      MapPanel(
        target: intent.target,
        raw: {'type': 'map', 'target': intent.target},
      ),
    ],
    origin: AnswerOrigin.rules,
    intent: intent.target,
  );
}

final mapAnswerServiceProvider = Provider<MapAnswerService>(
  (ref) => const MapAnswerService(),
);
