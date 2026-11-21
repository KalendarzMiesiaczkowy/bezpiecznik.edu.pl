/// Pure aggregation for the A07 eval (no I/O, unit-tested).
library;

enum EvalKind {
  answer,
  noSource,
  offTopic;

  static EvalKind parse(String s) => switch (s) {
    'answer' => EvalKind.answer,
    'no_source' => EvalKind.noSource,
    'off_topic' => EvalKind.offTopic,
    _ => throw FormatException('unknown kind: $s'),
  };
}

class EvalQuestion {
  EvalQuestion({
    required this.id,
    required this.question,
    required this.kind,
    this.expect = const [],
    this.expectCall = false,
    this.tags = const [],
  });

  factory EvalQuestion.fromJson(Map<String, dynamic> j) => EvalQuestion(
    id: j['id'] as String,
    question: j['q'] as String,
    kind: EvalKind.parse(j['kind'] as String),
    expect: [for (final e in (j['expect'] as List? ?? const [])) e as String],
    expectCall: j['expect_call'] == true,
    tags: [for (final e in (j['tags'] as List? ?? const [])) e as String],
  );

  final String id;
  final String question;
  final EvalKind kind;

  /// Acceptable chunk ids (any one counts). Empty for refusals.
  final List<String> expect;
  final bool expectCall;
  final List<String> tags;
}

/// Parses a JSONL body; blank lines are skipped.
List<EvalQuestion> parseQuestions(
  String body,
  Object? Function(String) decode,
) => [
  for (final l in body.split('\n'))
    if (l.trim().isNotEmpty)
      EvalQuestion.fromJson(decode(l) as Map<String, dynamic>),
];

/// Result of one question. Pipeline fields are null when the LLM stage did
/// not run.
class EvalRow {
  EvalRow({
    required this.q,
    required this.retrievalKind,
    required this.topIds,
    this.bestScore,
    this.pipelineKind,
    this.citedIds = const [],
    this.hasCall = false,
    this.fallback = false,
    this.modelRefused = false,
    this.latencyMs,
    this.error,
  });

  final EvalQuestion q;

  /// 'found' | 'no_source' | 'off_topic'.
  final String retrievalKind;
  final List<String> topIds;
  final double? bestScore;

  /// 'answer' | 'no_source' | 'off_topic' | 'failed'; null if not run.
  final String? pipelineKind;
  final List<String> citedIds;
  final bool hasCall;

  /// Validation/parse fallback: quote panels instead of model text.
  final bool fallback;

  /// The model itself returned no panels on a retrieved question.
  final bool modelRefused;
  final int? latencyMs;
  final String? error;

  bool get retrievalHit => q.expect.isNotEmpty && topIds.any(q.expect.contains);

  bool get citedHit => q.expect.isNotEmpty && citedIds.any(q.expect.contains);

  String get _wantRefusal =>
      q.kind == EvalKind.noSource ? 'no_source' : 'off_topic';

  bool get retrievalRefusalStrict =>
      q.kind != EvalKind.answer && retrievalKind == _wantRefusal;

  bool get retrievalRefusalLenient =>
      q.kind != EvalKind.answer && retrievalKind != 'found';

  bool get pipelineRefusalStrict =>
      q.kind != EvalKind.answer && pipelineKind == _wantRefusal;

  bool get pipelineRefusalLenient =>
      q.kind != EvalKind.answer &&
      (pipelineKind == 'no_source' || pipelineKind == 'off_topic');
}

class EvalSummary {
  EvalSummary({
    required this.answerCount,
    required this.refusalCount,
    required this.retrievalHits,
    required this.citedHits,
    required this.retrievalRefusalStrict,
    required this.retrievalRefusalLenient,
    required this.pipelineRefusalStrict,
    required this.pipelineRefusalLenient,
    required this.fallbacks,
    required this.modelRefusedAnswerable,
    required this.pipelineAnswered,
    required this.callMismatches,
    required this.meanLatencyMs,
    required this.p95LatencyMs,
    required this.pipelineRan,
  });

  final int answerCount;
  final int refusalCount;
  final int retrievalHits;
  final int citedHits;
  final int retrievalRefusalStrict;
  final int retrievalRefusalLenient;
  final int pipelineRefusalStrict;
  final int pipelineRefusalLenient;
  final int fallbacks;
  final int modelRefusedAnswerable;

  /// Answerable questions that produced an answer (not a refusal/failure).
  final int pipelineAnswered;
  final int callMismatches;
  final double? meanLatencyMs;
  final int? p95LatencyMs;
  final bool pipelineRan;

  double rate(int n, int d) => d == 0 ? 0 : n / d;
}

/// Nearest-rank percentile of [values] (unsorted), `p` in (0, 100].
int? percentile(List<int> values, double p) {
  if (values.isEmpty) return null;
  final s = [...values]..sort();
  var rank = (p / 100 * s.length).ceil();
  if (rank < 1) rank = 1;
  if (rank > s.length) rank = s.length;
  return s[rank - 1];
}

EvalSummary summarize(List<EvalRow> rows) {
  final ans = rows.where((r) => r.q.kind == EvalKind.answer).toList();
  final ref = rows.where((r) => r.q.kind != EvalKind.answer).toList();
  final ran = rows.any((r) => r.pipelineKind != null);
  final lat = [
    for (final r in rows)
      if (r.latencyMs != null) r.latencyMs!,
  ];
  return EvalSummary(
    answerCount: ans.length,
    refusalCount: ref.length,
    retrievalHits: ans.where((r) => r.retrievalHit).length,
    citedHits: ans.where((r) => r.citedHit).length,
    retrievalRefusalStrict: ref.where((r) => r.retrievalRefusalStrict).length,
    retrievalRefusalLenient: ref.where((r) => r.retrievalRefusalLenient).length,
    pipelineRefusalStrict: ref.where((r) => r.pipelineRefusalStrict).length,
    pipelineRefusalLenient: ref.where((r) => r.pipelineRefusalLenient).length,
    fallbacks: ans.where((r) => r.fallback).length,
    modelRefusedAnswerable: ans.where((r) => r.modelRefused).length,
    pipelineAnswered: ans.where((r) => r.pipelineKind == 'answer').length,
    callMismatches: ans
        .where((r) => r.pipelineKind != null && r.q.expectCall && !r.hasCall)
        .length,
    meanLatencyMs: lat.isEmpty
        ? null
        : lat.reduce((a, b) => a + b) / lat.length,
    p95LatencyMs: percentile(lat, 95),
    pipelineRan: ran,
  );
}

String _pct(int n, int d) =>
    d == 0 ? 'n/a' : '$n/$d (${(100 * n / d).toStringAsFixed(1)}%)';

/// Markdown report. [failures] are pre-rendered lines.
String renderMarkdown(
  EvalSummary s, {
  required String timestamp,
  required String model,
  required List<String> failures,
}) {
  final b = StringBuffer()
    ..writeln('# Eval $timestamp')
    ..writeln()
    ..writeln(
      'Model: $model (host llama-server; host latency is not phone latency)',
    )
    ..writeln()
    ..writeln('| Metric | Value |')
    ..writeln('|---|---|')
    ..writeln(
      '| Questions (answerable / refusal) | ${s.answerCount + s.refusalCount} (${s.answerCount} / ${s.refusalCount}) |',
    )
    ..writeln(
      '| Source hit rate, retrieval top-k | ${_pct(s.retrievalHits, s.answerCount)} |',
    );
  if (s.pipelineRan) {
    b
      ..writeln(
        '| Source hit rate, cited in answer | ${_pct(s.citedHits, s.answerCount)} |',
      )
      ..writeln(
        '| Answerable that produced an answer | ${_pct(s.pipelineAnswered, s.answerCount)} |',
      )
      ..writeln('| Model refused answerable | ${s.modelRefusedAnswerable} |')
      ..writeln(
        '| Validation fallback (quotes only) | ${_pct(s.fallbacks, s.answerCount)} |',
      )
      ..writeln(
        '| Refusal pass, pipeline, right kind | ${_pct(s.pipelineRefusalStrict, s.refusalCount)} |',
      )
      ..writeln(
        '| Refusal pass, pipeline, any refusal | ${_pct(s.pipelineRefusalLenient, s.refusalCount)} |',
      )
      ..writeln('| Risk questions without call panel | ${s.callMismatches} |')
      ..writeln(
        '| Latency mean / p95 | ${s.meanLatencyMs?.round()} ms / ${s.p95LatencyMs} ms |',
      );
  }
  b
    ..writeln(
      '| Refusal pass, retrieval, right kind | ${_pct(s.retrievalRefusalStrict, s.refusalCount)} |',
    )
    ..writeln(
      '| Refusal pass, retrieval, any refusal | ${_pct(s.retrievalRefusalLenient, s.refusalCount)} |',
    )
    ..writeln()
    ..writeln('## Failures')
    ..writeln();
  if (failures.isEmpty) {
    b.writeln('None.');
  } else {
    for (final f in failures) {
      b.writeln('- $f');
    }
  }
  return b.toString();
}
