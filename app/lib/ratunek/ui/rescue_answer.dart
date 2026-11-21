import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../czat/templates/panel_model.dart' as chat;
import '../../czat/ui/answer_service.dart';
import '../cards/rescue_card.dart' as card;
import '../detect/risk_detector.dart';

/// Answers a risk phrase with a rescue card, without the model.
///
/// Spec: `szablony-czatu.md` (`call` is always the first panel of a
/// `rescue_card` message; one variant per message) and
/// `ekran-1-czat.md`. Pure Dart + assets, so it is fast: detection is a token
/// match, mapping builds a JSON map and parses it with the chat model.
class RescueAnswerService {
  RescueAnswerService({required this.detector, required this.cards});

  /// Loads the detector and the card repository from [bundle].
  static Future<RescueAnswerService> load(AssetBundle bundle) async {
    final detector = await RiskDetector.load(bundle);
    final cards = await card.RescueCardRepository.load(bundle);
    return RescueAnswerService(detector: detector, cards: cards);
  }

  final RiskDetector detector;
  final card.RescueCardRepository cards;

  /// True when [question] hits a risk phrase or a card phrase: the message
  /// must get the `call` panel (spec rule 2), also when the answer is not a
  /// card (see [withCallFirst]).
  bool isRisk(String question) => detector.isRisk(question);

  /// The rescue-card answer for [question], or null when no card matches.
  Future<chat.AssistantAnswer?> tryAnswer(String question) async {
    final hit = detector.detectCard(question);
    if (hit == null) return null;
    final c = cards.card(hit.cardId);
    if (c == null) return null;
    return buildAnswer(c, requestedVariant: hit.variant);
  }

  /// Converts [c] into a chat answer: `call` first, then the card panels with
  /// the selected variant, the source records they cite and the
  /// `verify` flag (drives the "Do weryfikacji" badge).
  chat.AssistantAnswer buildAnswer(
    card.RescueCard c, {
    String? requestedVariant,
  }) {
    final variant = c.selectVariant(requestedVariant) ?? c.defaultVariant;
    final panels = <Map<String, Object?>>[
      {'type': 'call'},
      for (final p in c.panels) ?_panelJson(p),
    ];
    final sources = <String, Object?>{};
    for (final id in <String>{...c.citedSourceIds, ...c.sourceIds}) {
      final s = cards.source(id);
      if (s != null) sources[id] = _sourceJson(s);
    }
    return chat.AssistantAnswer.fromJson({
      'origin': chat.AnswerOrigin.rescueCard.json,
      'card_id': c.id,
      'verify': c.verify,
      'selected_variant': ?variant,
      'panels': panels,
      'sources': sources,
    });
  }

  /// Returns [answer] with a `call` panel in front (unless it has one).
  /// For model / rules answers to risk phrases (spec rule 2 and 3).
  static chat.AssistantAnswer withCallFirst(chat.AssistantAnswer answer) {
    if (answer.panels.any((p) => p is chat.CallPanel)) return answer;
    return answer.copyWith(
      panels: [
        const chat.CallPanel({'type': 'call'}),
        ...answer.panels,
      ],
    );
  }
}

Map<String, Object?>? _panelJson(card.RescuePanel p) => switch (p) {
  card.CallPanel() => null, // the app inserts exactly one, first
  card.StepsPanel() => {
    'type': 'steps',
    'title': p.title,
    'read_aloud': p.readAloud,
    if (p.variants.isEmpty)
      'items': [for (final i in p.items) _itemJson(i)]
    else
      'variants': [
        for (final v in p.variants)
          {
            'id': v.id,
            'label': v.label,
            'items': [for (final i in v.items) _itemJson(i)],
          },
      ],
  },
  card.CprPanel() => {
    'type': 'cpr',
    'source_id': p.sourceId,
    'rate_bpm': ?p.effectiveRateBpm,
    'rate_bpm_min': ?p.rateBpmMin,
    'rate_bpm_max': ?p.rateBpmMax,
    'rescuer_change_s': ?p.rescuerChangeS,
    'rate_source_id': ?p.rateSourceId,
    'rescuer_change_source_id': ?p.rescuerChangeSourceId,
    'rate_note': ?p.rateNote,
    'verify_note': ?p.verifyNote,
    'variants': [
      for (final v in p.variants)
        {
          'id': v.id,
          'label': v.label,
          'source_id': v.sourceId,
          'compressions': ?v.compressions,
          'compressions_pbls_trained': ?v.compressionsPblsTrained,
          'breaths': ?v.breaths,
          'initial_breaths': ?v.initialBreaths,
          'breath_phase_s': ?v.breathPhaseS,
        },
    ],
    'voice': p.voice,
    'aed_card_id': ?p.aedCardId,
  },
  card.RawPanel() => p.json,
};

Map<String, Object?> _itemJson(card.StepItem i) => {
  'text': i.text,
  'source_id': i.sourceId,
  if (i.cardLink case final l?)
    'card_link': {'label': l.label, 'card_id': l.cardId},
};

Map<String, Object?> _sourceJson(card.SourceRecord s) => {
  'source_id': s.sourceId,
  'doc_id': s.docId,
  'doc_title': s.docTitle,
  'doc_short': s.docShort,
  'publisher': s.publisher,
  'issued': s.issued,
  'page_label': s.pageLabel,
  'pdf_page': s.pdfPage,
  'pdf_file': s.pdfFile,
  'text': s.original,
  'rects': s.rects,
};

/// Loads the detector and cards once (assets are bundled).
final rescueAnswerServiceProvider = FutureProvider<RescueAnswerService>(
  (ref) => RescueAnswerService.load(rootBundle),
);

/// [AnswerService] that tries the rescue card first and only then asks
/// [fallback] (the model pipeline). The card path emits no thinking phase:
/// the answer is ready as soon as the (cached) service is.
class RescueFirstAnswerService implements AnswerService {
  RescueFirstAnswerService({required this.rescue, required this.fallback});

  final Future<RescueAnswerService> Function() rescue;
  final AnswerService fallback;

  @override
  Stream<AnswerEvent> answer(String question, ChatContext ctx) async* {
    final hit = await (await rescue()).tryAnswer(question);
    if (hit != null) {
      yield AnswerReady(hit);
      return;
    }
    yield* fallback.answer(question, ctx);
  }
}
