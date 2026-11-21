import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'eval_metrics.dart';

EvalQuestion _q(String id, EvalKind k, {List<String> expect = const []}) =>
    EvalQuestion(id: id, question: id, kind: k, expect: expect);

void main() {
  test('percentile nearest rank', () {
    expect(percentile([], 95), isNull);
    expect(percentile([5], 95), 5);
    expect(percentile([for (var i = 1; i <= 20; i++) i], 95), 19);
    expect(percentile([for (var i = 1; i <= 100; i++) i], 95), 95);
    expect(percentile([3, 1, 2], 100), 3);
  });

  test('parseQuestions reads kinds, expect and flags', () {
    final qs = parseQuestions(
      '{"id":"a","q":"x","kind":"answer","expect":["c1"],"expect_call":true}\n\n'
      '{"id":"b","q":"y","kind":"off_topic"}\n',
      jsonDecode,
    );
    expect(qs.length, 2);
    expect(qs[0].expect, ['c1']);
    expect(qs[0].expectCall, isTrue);
    expect(qs[1].kind, EvalKind.offTopic);
    expect(() => EvalKind.parse('zzz'), throwsFormatException);
  });

  test('questions.jsonl is valid, big enough and ids exist in the kb', () {
    final f = File('../content/tests/questions.jsonl');
    final qs = parseQuestions(f.readAsStringSync(), jsonDecode);
    expect(qs.length, greaterThanOrEqualTo(40));
    expect({for (final q in qs) q.id}.length, qs.length);
    expect(
      qs.where((q) => q.kind != EvalKind.answer).length,
      greaterThanOrEqualTo(15),
    );
    for (final q in qs.where((q) => q.kind == EvalKind.answer)) {
      expect(q.expect, isNotEmpty, reason: q.id);
    }
    final kb = File('assets/generated/kb.sqlite');
    if (!kb.existsSync()) return;
    // Existence of ids is checked against the knowledge front matter ids.
    final ids = <String>{};
    final re = RegExp(r'^\s*-?\s*id:\s*(\S+)', multiLine: true);
    for (final e in Directory(
      '../content/knowledge',
    ).listSync(recursive: true)) {
      if (e is File &&
          e.path.endsWith('.md') &&
          !e.path.endsWith('README.md')) {
        for (final m in re.allMatches(e.readAsStringSync())) {
          ids.add(m.group(1)!.replaceAll('"', '').replaceAll("'", ''));
        }
      }
    }
    if (ids.isEmpty) return;
    for (final q in qs) {
      for (final id in q.expect) {
        expect(ids, contains(id), reason: '${q.id}: $id');
      }
    }
  });

  test('summarize: hits, refusals, fallbacks, latency', () {
    final rows = [
      EvalRow(
        q: _q('a1', EvalKind.answer, expect: ['c1']),
        retrievalKind: 'found',
        topIds: ['c2', 'c1'],
        pipelineKind: 'answer',
        citedIds: ['c1'],
        latencyMs: 1000,
      ),
      EvalRow(
        q: _q('a2', EvalKind.answer, expect: ['c1']),
        retrievalKind: 'found',
        topIds: ['c3'],
        pipelineKind: 'answer',
        citedIds: ['c3'],
        fallback: true,
        latencyMs: 3000,
      ),
      EvalRow(
        q: _q('n1', EvalKind.noSource),
        retrievalKind: 'off_topic',
        topIds: [],
        pipelineKind: 'off_topic',
        latencyMs: 10,
      ),
      EvalRow(
        q: _q('o1', EvalKind.offTopic),
        retrievalKind: 'off_topic',
        topIds: [],
        pipelineKind: 'off_topic',
        latencyMs: 10,
      ),
    ];
    final s = summarize(rows);
    expect(s.answerCount, 2);
    expect(s.refusalCount, 2);
    expect(s.retrievalHits, 1);
    expect(s.citedHits, 1);
    expect(s.fallbacks, 1);
    expect(s.retrievalRefusalStrict, 1);
    expect(s.retrievalRefusalLenient, 2);
    expect(s.pipelineRefusalStrict, 1);
    expect(s.pipelineRefusalLenient, 2);
    expect(s.meanLatencyMs, 1005);
    expect(s.p95LatencyMs, 3000);
    final md = renderMarkdown(s, timestamp: 't', model: 'm', failures: ['x']);
    expect(md, contains('1/2 (50.0%)'));
    expect(md, contains('- x'));
  });

  test('summarize without pipeline omits pipeline rows', () {
    final s = summarize([
      EvalRow(
        q: _q('a', EvalKind.answer, expect: ['c']),
        retrievalKind: 'found',
        topIds: ['c'],
      ),
    ]);
    expect(s.pipelineRan, isFalse);
    expect(
      renderMarkdown(s, timestamp: 't', model: 'm', failures: []),
      isNot(contains('Latency')),
    );
  });

  test('call mismatch counted only for run pipeline', () {
    final r = EvalRow(
      q: EvalQuestion(
        id: 'r',
        question: 'r',
        kind: EvalKind.answer,
        expect: ['c'],
        expectCall: true,
      ),
      retrievalKind: 'found',
      topIds: ['c'],
      pipelineKind: 'answer',
      hasCall: false,
    );
    expect(summarize([r]).callMismatches, 1);
  });
}
