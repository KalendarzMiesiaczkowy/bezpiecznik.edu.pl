/// Prompt for the closed-book answer (odpowiedzi-tylko-ze-zrodel.md,
/// szablony-czatu.md, lokalne-ai.md). Polish, so the model answers in Polish.
library;

import '../llm/llm_engine.dart';
import '../retrieval/retriever.dart';

const int kMaxPromptChunks = 4;

/// Per-chunk character cap, keeps the prompt near 1 k tokens.
const int kMaxChunkChars = 1500;

const String kSystemPrompt = '''
Jesteś asystentem bezpieczeństwa. Odpowiadasz WYŁĄCZNIE na podstawie fragmentów źródeł podanych w wiadomości. Nigdy nie korzystaj z własnej wiedzy.

Zwróć jeden obiekt JSON, bez tekstu poza nim:
{"panels":[{"type":"steps","title":"Teraz","items":[{"text":"...","source_id":"..."}]}]}

Dozwolone panele:
- "steps": kroki po kolei, "bullets": lista bez kolejności. Każdy element ma "text" i "source_id" wybrany z podanych fragmentów.
- "quote": {"type":"quote","source_id":"..."} gdy nie umiesz krótko streścić fragmentu.

Zasady:
- Jeden element to jedna czynność, jedno krótkie zdanie (do 120 znaków), po polsku.
- Używaj słów i liczb z fragmentu. Nie dodawaj liczb, dawek, czasów ani nazw leków, których nie ma we fragmencie.
- Zachowaj zaprzeczenia ze źródła: jeśli fragment mówi "nie" lub "nigdy", krok też. Nie dodawaj zaprzeczeń, których nie ma.
- Nie diagnozuj. Nie dodawaj panelu "call" ani innych paneli.
- Gdy fragmenty nie odpowiadają na pytanie, zwróć {"panels":[]}.
- Najwyżej 6 elementów w całej odpowiedzi, wybierz najważniejsze.
- Tytuł panelu: do 30 znaków.''';

/// Short reminder appended on the single retry after an unparseable answer.
const String kRetryReminder =
    'Poprzednia odpowiedź nie była poprawnym JSON. Zwróć wyłącznie jeden '
    'kompletny obiekt JSON {"panels":[...]} i nic poza nim. Krótko.';

/// JSON schema for engines with constrained decoding (the edge engine). The
/// host engine only uses `json_object`; the schema is repeated in the prompt.
Map<String, Object?> answerSchema(List<String> sourceIds) => {
  'type': 'object',
  'properties': {
    'panels': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'enum': ['steps', 'bullets', 'quote'],
          },
          'title': {'type': 'string'},
          'source_id': {'type': 'string', 'enum': sourceIds},
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'text': {'type': 'string'},
                'source_id': {'type': 'string', 'enum': sourceIds},
              },
              'required': ['text', 'source_id'],
            },
          },
        },
        'required': ['type'],
      },
    },
  },
  'required': ['panels'],
};

/// Builds the request: top-k chunks (best first), profile context and the
/// current plus previous question.
LlmRequest buildAnswerRequest({
  required String question,
  String? previousQuestion,
  String profileContext = '',
  required List<KbChunk> chunks,
  bool retry = false,
}) {
  final used = chunks.take(kMaxPromptChunks).toList();
  final b = StringBuffer('Fragmenty źródeł:\n');
  for (final c in used) {
    final text = c.text.length > kMaxChunkChars
        ? c.text.substring(0, kMaxChunkChars)
        : c.text;
    b
      ..writeln('[source_id: ${c.id}] (${c.docShort}, s. ${c.pageLabel})')
      ..writeln(text.trim())
      ..writeln();
  }
  if (profileContext.trim().isNotEmpty) {
    b
      ..writeln('Profil domu (tylko kontekst, nie źródło faktów):')
      ..writeln(profileContext.trim())
      ..writeln();
  }
  if (previousQuestion != null && previousQuestion.trim().isNotEmpty) {
    b.writeln('Poprzednie pytanie: ${previousQuestion.trim()}');
  }
  b.writeln('Pytanie: ${question.trim()}');
  if (retry) b.writeln('\n$kRetryReminder');
  return LlmRequest(
    systemPrompt: kSystemPrompt,
    messages: [LlmMessage.user(b.toString())],
    jsonMode: true,
    jsonSchema: answerSchema([for (final c in used) c.id]),
    maxTokens: 900,
    temperature: retry ? 0.0 : 0.1,
  );
}
