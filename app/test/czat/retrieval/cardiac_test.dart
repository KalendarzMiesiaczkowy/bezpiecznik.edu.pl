// Owner 08:33: circulation / RKO questions were refused (real kb.sqlite).
import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/czat/retrieval/kb_database.dart';
import 'package:bezpiecznik/czat/retrieval/query_builder.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';
import 'package:bezpiecznik/ratunek/detect/risk_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final hasKb = File('assets/generated/kb.sqlite').existsSync();

  test('circulation and RKO questions are answered from the KB', () async {
    final kb = KbDatabase(
      sqlite3.open('assets/generated/kb.sqlite', mode: OpenMode.readOnly),
    );
    final r = Retriever(
      kb,
      stopwords: parseStopwords(File('assets/kb/stopwords.txt').readAsStringSync()),
    );
    for (final q in [
      'zatrzymanie krazenia co robic',
      'nie ma krazenia',
      'krazenie',
      'zawal serca objawy',
      'jak sprawdzic oddech',
      'masaz serca',
      'rko',
      'resuscytacja',
      'jak zrobic rko',
    ]) {
      expect((await r.search(q)).decision, RetrievalDecision.found, reason: q);
    }
    // Not covered by the KB: still "no source".
    expect((await r.search('udar objawy')).decision, RetrievalDecision.noSource);
    kb.close();
  }, skip: hasKb ? false : 'kb.sqlite missing');

  test('cardiac arrest phrasings open the RKO card', () {
    final d = RiskDetector(
      risk: jsonDecode(File('assets/phrases/risk.json').readAsStringSync()),
      cardsIndex: jsonDecode(File('assets/phrases/cards_index.json').readAsStringSync()),
    );
    for (final q in [
      'zatrzymanie krazenia co robic',
      'nie ma krazenia',
      'brak tętna',
      'serce przestało bić',
      'jak robić masaż serca',
    ]) {
      expect(d.detectCard(q)?.cardId, 'rko', reason: q);
    }
  });
}
