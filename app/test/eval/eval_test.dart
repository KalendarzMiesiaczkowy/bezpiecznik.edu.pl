// A07 eval: runs retrieval and the real answer pipeline (host llama-server)
// over content/tests/questions.jsonl.
//   BZ_EVAL=1 flutter test test/eval/eval_test.dart            (full)
//   BZ_EVAL=1 BZ_EVAL_LLM=0 flutter test test/eval/eval_test.dart (retrieval)
// Env: BZ_EVAL_OUT (default night-shift/work/a07), BZ_EVAL_URL.
import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/czat/answer/pipeline_answer_service.dart';
import 'package:bezpiecznik/czat/llm/llm_engine_host.dart';
import 'package:bezpiecznik/czat/retrieval/kb_database.dart';
import 'package:bezpiecznik/czat/retrieval/query_builder.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/ratunek/detect/risk_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'eval_metrics.dart';

final bool _on = Platform.environment['BZ_EVAL'] == '1';
final bool _llm = Platform.environment['BZ_EVAL_LLM'] != '0';
const _defaultOut =
    '/home/weak/Dokumenty/bezpiecznik/Bezpiecznik/night-shift/work/a07';

void main() {
  test(
    'eval',
    () async {
      final qs = parseQuestions(
        File('../content/tests/questions.jsonl').readAsStringSync(),
        jsonDecode,
      );
      final kb = KbDatabase(
        sqlite3.open('assets/generated/kb.sqlite', mode: OpenMode.readOnly),
      );
      final stop = parseStopwords(
        File('assets/kb/stopwords.txt').readAsStringSync(),
      );
      final risk = RiskDetector(
        risk: jsonDecode(
          File('assets/phrases/risk.json').readAsStringSync(),
        ) as Map<String, dynamic>,
        cardsIndex: jsonDecode(
          File('assets/phrases/cards_index.json').readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      final retriever = Retriever(kb, stopwords: stop);
      final url =
          Platform.environment['BZ_EVAL_URL'] ?? 'http://127.0.0.1:8080';
      final engine = HostLlmEngine(baseUrl: url);
      final logs = <String>[];
      final service = PipelineAnswerService(
        search: retriever.search,
        engine: engine,
        isRisk: risk.isRisk,
        onLog: logs.add,
      );

      final rows = <EvalRow>[];
      final details = <Map<String, Object?>>[];
      for (final q in qs) {
        final r = await retriever.search(q.question);
        final retrievalKind = switch (r.decision) {
          RetrievalDecision.found => 'found',
          RetrievalDecision.noSource => 'no_source',
          RetrievalDecision.offTopic => 'off_topic',
        };
        // For hit-rate the top-k is wanted even when the gate refused.
        var topIds = [for (final c in r.chunks) c.id];
        String? pKind;
        var cited = <String>[];
        var hasCall = false;
        var fallback = false;
        var modelRefused = false;
        int? ms;
        String? err;
        final logStart = logs.length;
        if (_llm) {
          final sw = Stopwatch()..start();
          final events = await service
              .answer(q.question, const ChatContext(chatId: 'eval'))
              .toList();
          sw.stop();
          ms = sw.elapsedMilliseconds;
          final fail = events.whereType<AnswerFailed>();
          final ready = events.whereType<AnswerReady>();
          if (fail.isNotEmpty || ready.isEmpty) {
            pKind = 'failed';
            err = fail.isNotEmpty ? fail.first.message : 'no answer';
          } else {
            final a = ready.first.answer;
            hasCall = a.panels.any((p) => p is CallPanel);
            final ns = a.panels.whereType<NoSourcePanel>();
            if (a.origin == AnswerOrigin.refusal && ns.isNotEmpty) {
              pKind = ns.first.kind == NoSourceKind.offTopic
                  ? 'off_topic'
                  : 'no_source';
              modelRefused = retrievalKind == 'found';
            } else {
              pKind = 'answer';
              fallback =
                  a.origin == AnswerOrigin.noAi ||
                  (a.panels.where((p) => p is! CallPanel).isNotEmpty &&
                      a.panels
                          .where((p) => p is! CallPanel)
                          .every((p) => p is QuotePanel));
              cited = a.sources.keys.toList();
            }
          }
        }
        final row = EvalRow(
          q: q,
          retrievalKind: retrievalKind,
          topIds: topIds,
          bestScore: r.bestScore,
          pipelineKind: pKind,
          citedIds: cited,
          hasCall: hasCall,
          fallback: fallback,
          modelRefused: modelRefused,
          latencyMs: ms,
          error: err,
        );
        rows.add(row);
        details.add({
          'id': q.id,
          'q': q.question,
          'kind': q.kind.name,
          'expect': q.expect,
          'retrieval': retrievalKind,
          'top': topIds,
          'best_score': r.bestScore,
          'pipeline': pKind,
          'cited': cited,
          'call': hasCall,
          'fallback': fallback,
          'model_refused': modelRefused,
          'latency_ms': ms,
          'error': err,
          'logs': logs.sublist(logStart),
        });
        stdout.writeln(
          '${q.id} ${q.kind.name} retr=$retrievalKind pipe=$pKind '
          'hit=${row.retrievalHit}/${row.citedHit} ${ms ?? '-'}ms  ${q.question}',
        );
      }
      kb.close();

      final failures = <String>[];
      for (final r in rows) {
        final q = r.q;
        if (q.kind == EvalKind.answer) {
          final why = <String>[
            if (!r.retrievalHit)
              'retrieval miss (${r.retrievalKind}, top=${r.topIds.take(3).join(',')})',
            if (r.pipelineKind != null && !r.citedHit)
              'not cited (${r.pipelineKind}${r.fallback ? ', fallback' : ''})',
            if (r.pipelineKind != null && q.expectCall && !r.hasCall)
              'risk question without call panel',
          ];
          if (why.isNotEmpty) {
            failures.add('${q.id} "${q.question}": ${why.join('; ')}');
          }
        } else {
          // The gate is the pipeline when it ran; the retrieval stage alone
          // otherwise. Retrieval passing a refused question on to the model is
          // a note, not a failure (the model/validator layer refused it).
          final lenient = r.pipelineKind != null
              ? r.pipelineRefusalLenient
              : r.retrievalRefusalLenient;
          final strict = r.pipelineKind != null
              ? r.pipelineRefusalStrict
              : r.retrievalRefusalStrict;
          if (!lenient) {
            failures.add(
              '${q.id} "${q.question}": NOT REFUSED (retrieval=${r.retrievalKind}, pipeline=${r.pipelineKind})',
            );
          } else if (!strict) {
            failures.add(
              '${q.id} "${q.question}": wrong refusal kind (retrieval=${r.retrievalKind}, pipeline=${r.pipelineKind}, wanted ${q.kind.name})',
            );
          } else if (r.retrievalKind == 'found') {
            failures.add(
              '(note) ${q.id} "${q.question}": retrieval passed it to the model, which refused',
            );
          }
        }
      }
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final summary = summarize(rows);
      final md = renderMarkdown(
        summary,
        timestamp: ts,
        model: 'gemma-4-E2B-it-Q4_0',
        failures: failures,
      );
      final out = Directory(Platform.environment['BZ_EVAL_OUT'] ?? _defaultOut)
        ..createSync(recursive: true);
      File('${out.path}/eval-$ts.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ')
            .convert({'timestamp': ts, 'llm': _llm, 'rows': details}),
      );
      File('${out.path}/eval-$ts.md').writeAsStringSync(md);
      stdout.writeln(md);
    },
    skip: _on ? false : 'set BZ_EVAL=1',
    timeout: const Timeout(Duration(minutes: 60)),
  );
}
