// A07: absent safety topics and generic question words (real kb.sqlite).
import 'dart:io';

import 'package:bezpiecznik/czat/retrieval/kb_database.dart';
import 'package:bezpiecznik/czat/retrieval/query_builder.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final hasKb = File('assets/generated/kb.sqlite').existsSync();
  late KbDatabase kb;
  late Retriever r;
  setUpAll(() {
    if (!hasKb) return;
    kb = KbDatabase(
      sqlite3.open('assets/generated/kb.sqlite', mode: OpenMode.readOnly),
    );
    r = Retriever(
      kb,
      stopwords: parseStopwords(File('assets/kb/stopwords.txt').readAsStringSync()),
    );
  });
  tearDownAll(() {
    if (hasKb) kb.close();
  });

  Future<RetrievalDecision> d(String q) async => (await r.search(q)).decision;

  test('generic words do not ground a hit for an absent safety topic', () async {
    for (final q in [
      'Co robić przy ugryzieniu węża?',
      'Jak zachować się podczas trzęsienia ziemi?',
      'Gdzie się schować podczas burzy z piorunami?',
      'Jak rozpoznać udar mózgu?',
      'Jak pomóc osobie z niskim cukrem przy cukrzycy?',
      'Jak usunąć kleszcza?',
      'zatrucie czadem objawy',
      'Jak pomóc osobie podczas ataku padaczki?',
    ]) {
      expect(await d(q), RetrievalDecision.noSource, reason: q);
    }
  }, skip: hasKb ? false : 'no kb');

  test('person-state words are not topics', () async {
    expect(await d('Ranny mocno krwawi, jak mu pomóc?'), RetrievalDecision.found);
    expect(await d('Mój tata nie oddycha, co robić?'), RetrievalDecision.found);
  }, skip: hasKb ? false : 'no kb');

  test('regular in-KB questions stay found', () async {
    for (final q in [
      'Jak postępować przy oparzeniach?',
      'Co zrobić, gdy ktoś się zadławił?',
      'Jak użyć defibrylatora AED?',
      'Jakie są objawy zawału serca?',
      'jak uzyc defibrylatora',
    ]) {
      expect(await d(q), RetrievalDecision.found, reason: q);
    }
  }, skip: hasKb ? false : 'no kb');

  test('off-topic stays offTopic', () async {
    for (final q in ['Jak naprawić zmywarkę?', 'Opowiedz mi dowcip', 'Ile kosztuje bitcoin?']) {
      expect(await d(q), RetrievalDecision.offTopic, reason: q);
    }
  }, skip: hasKb ? false : 'no kb');
}
