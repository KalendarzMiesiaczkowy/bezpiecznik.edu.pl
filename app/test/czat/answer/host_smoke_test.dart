// Runs the pipeline against the host llama-server and the real kb.
// Only with: BZ_HOST_LLM=1 flutter test test/czat/answer/host_smoke_test.dart
import 'dart:io';

import 'package:bezpiecznik/czat/answer/pipeline_answer_service.dart';
import 'package:bezpiecznik/czat/llm/llm_engine_host.dart';
import 'package:bezpiecznik/czat/retrieval/kb_database.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';
import 'package:bezpiecznik/czat/retrieval/query_builder.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/ratunek/detect/risk_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:convert';

final bool _on = Platform.environment['BZ_HOST_LLM'] == '1';

void main() {
  test('host smoke', () async {
    final kb = KbDatabase(sqlite3.open('assets/generated/kb.sqlite', mode: OpenMode.readOnly));
    final stop = parseStopwords(File('assets/kb/stopwords.txt').readAsStringSync());
    final risk = RiskDetector(
      risk: jsonDecode(File('assets/phrases/risk.json').readAsStringSync()) as Map<String, dynamic>,
      cardsIndex: jsonDecode(File('assets/phrases/cards_index.json').readAsStringSync()) as Map<String, dynamic>,
    );
    final retriever = Retriever(kb, stopwords: stop);
    final engine = HostLlmEngine(baseUrl: 'http://127.0.0.1:8080');
    final service = PipelineAnswerService(
      search: retriever.search,
      engine: engine,
      isRisk: risk.isRisk,
      onLog: (m) => stdout.writeln('  log: $m'),
    );
    for (final q in [
      'Co spakować do plecaka ewakuacyjnego?',
      'Jak długo trzeba uciskać klatkę piersiową?',
      'Jak postępować przy oparzeniach?',
      'przepis na pierogi',
    ]) {
      final sw = Stopwatch()..start();
      final events = await service.answer(q, const ChatContext(chatId: 'smoke')).toList();
      sw.stop();
      final ready = events.whereType<AnswerReady>().first.answer;
      stdout.writeln('Q: $q  [${sw.elapsedMilliseconds} ms, ${engine.lastTiming}]');
      stdout.writeln('  origin=${ready.origin.json} panels=${[for (final p in ready.panels) p.type]}');
      for (final p in ready.panels) {
        switch (p) {
          case StepsPanel():
            for (final i in p.items) {
              stdout.writeln('   - ${i.text}  [${i.sourceId}]');
            }
          case BulletsPanel():
            for (final i in p.items) {
              stdout.writeln('   * ${i.text}  [${i.sourceId}]');
            }
          case QuotePanel():
            stdout.writeln('   > quote ${p.sourceId}');
          default:
        }
      }
    }
    kb.close();
  }, skip: _on ? false : 'set BZ_HOST_LLM=1', timeout: const Timeout(Duration(minutes: 5)));
}
