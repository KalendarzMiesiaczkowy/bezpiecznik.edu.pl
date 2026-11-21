import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:bezpiecznik/czat/retrieval/kb_database.dart';
import 'package:bezpiecznik/czat/retrieval/query_builder.dart';
import 'package:bezpiecznik/czat/retrieval/retriever.dart';
import 'package:bezpiecznik/czat/retrieval/stopwords_fallback.dart';
import 'package:bezpiecznik/ratunek/detect/normalize.dart';

const _kbPath = 'assets/generated/kb.sqlite';
final bool _hasKb = File(_kbPath).existsSync();
const _skip =
    'assets/generated/kb.sqlite missing: run '
    '`uv run --script tools/build_knowledge.py`';

Set<String> _stopwords() =>
    parseStopwords(File('assets/kb/stopwords.txt').readAsStringSync());

const _ddl = '''
CREATE TABLE documents (doc_id TEXT PRIMARY KEY, title TEXT NOT NULL,
  short TEXT NOT NULL, publisher TEXT NOT NULL, issued TEXT NOT NULL,
  pdf_file TEXT NOT NULL, pdf_sha256 TEXT NOT NULL);
CREATE TABLE chunks (id TEXT PRIMARY KEY, doc_id TEXT NOT NULL, page_label TEXT NOT NULL,
  pdf_page INTEGER NOT NULL, chapter TEXT, text TEXT NOT NULL, text_norm TEXT NOT NULL,
  rects TEXT, original TEXT, topics TEXT, keywords TEXT, verify INTEGER);
CREATE VIRTUAL TABLE chunks_fts USING fts5(text_norm, content = 'chunks',
  content_rowid = 'rowid', tokenize = 'unicode61 remove_diacritics 2');
CREATE TABLE synonyms (term TEXT NOT NULL, synonym TEXT NOT NULL, PRIMARY KEY (term, synonym));
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
''';

KbDatabase _synthetic() {
  final db = sqlite3.openInMemory();
  db.execute(_ddl);
  db.execute(
    "INSERT INTO documents VALUES ('d1','Poradnik','Poradnik','RCB','2025','a.pdf','x')",
  );
  void chunk(String id, String page, String text, List<String> kw) {
    db.execute(
      'INSERT INTO chunks (id, doc_id, page_label, pdf_page, chapter, text, text_norm, original, topics, keywords, verify) '
      "VALUES (?, 'd1', ?, 3, 'Rozdzial', ?, ?, 'orig', '[\"t1\"]', ?, 1)",
      [id, page, text, normalizePl('$text ${kw.join(' ')}'), jsonEncode(kw)],
    );
  }

  chunk(
    'c1',
    '5',
    'Gdy wyje syrena alarmowa, wejdz do budynku i sluchaj komunikatow.',
    ['syrena', 'alarm'],
  );
  chunk('c2', '6', 'Zapas wody to trzy litry na osobe na dobe.', [
    'woda',
    'zapas',
  ]);
  chunk('c3', '7', 'Przy powodzi opusc teren zalewowy.', ['powodz']);
  db.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')");
  db.execute(
    "INSERT INTO synonyms VALUES ('alarm','syrena'),('syrena','alarm'),('trwoga','syrena')",
  );
  db.execute("INSERT INTO meta VALUES ('version','7')");
  return KbDatabase(db);
}

void main() {
  group('normalisation vectors (shared)', () {
    final vectors =
        (jsonDecode(
              File('test/ratunek/detect/normalize_vectors.json')
                  .readAsStringSync(),
            ) as Map)['vectors']
            as List;
    test('normalizePl matches the shared JSON', () {
      for (final v in vectors) {
        expect(
          normalizePl(v['input'] as String),
          v['expected'],
          reason: '${v['input']}',
        );
      }
    });
  });

  group('stopwords', () {
    test('const fallback equals the bundled asset', () {
      expect({for (final w in fallbackStopwords) normalizePl(w)}, _stopwords());
      expect(fallbackStopwords, isNotEmpty);
    });
  });

  group('QueryBuilder vs Python', () {
    final raw = jsonDecode(
      File('test/czat/retrieval/query_vectors.json').readAsStringSync(),
    ) as Map;
    final vectors = raw['vectors'] as List;

    test(
      'has at least 10 vectors',
      () => expect(vectors.length, greaterThanOrEqualTo(10)),
    );

    test('identical MATCH strings', () {
      final db = KbDatabase(sqlite3.open(_kbPath, mode: OpenMode.readOnly));
      final r = Retriever(db, stopwords: _stopwords());
      for (final v in vectors) {
        expect(
          r.queryBuilder.build(v['query'] as String),
          v['match'],
          reason: 'query: ${v['query']}',
        );
      }
      db.close();
    }, skip: _hasKb ? false : _skip);

    test('synthetic DB: phrase synonym expansion, both directions', () {
      final kb = _synthetic();
      final r = Retriever(kb, stopwords: _stopwords());
      // "alarm" -> "syrena" and "trwoga" (term) -> "syrena".
      expect(r.queryBuilder.build('alarm'), 'alar* OR syre*');
      expect(r.queryBuilder.build('trwoga'), 'trwo* OR syre*');
      expect(r.queryBuilder.build(''), isNull);
      expect(r.queryBuilder.build('co jak'), isNull);
    });
  });

  group('synthetic DB', () {
    late Retriever r;
    // Tiny corpus: bm25 values are near zero, so the floor is opened up.
    setUp(() => r = Retriever(_synthetic(), stopwords: _stopwords(), floor: 0));

    test('found with synonym only in query', () async {
      final res = await r.search('alarm');
      expect(res.decision, RetrievalDecision.found);
      expect(res.chunks.first.id, 'c1');
      expect(res.chunks.first.docShort, 'Poradnik');
      expect(res.chunks.first.topics, ['t1']);
      expect(res.chunks.first.verify, isTrue);
    });

    test('diacritics and typos in endings', () async {
      expect((await r.search('POWÓDŹ')).chunks.first.id, 'c3');
      expect((await r.search('powodzi')).chunks.first.id, 'c3');
    });

    test('default floor rejects near-zero bm25 on a tiny corpus', () async {
      final d = Retriever(_synthetic(), stopwords: _stopwords());
      expect(d.floor, kDefaultBm25Floor);
      expect((await d.search('syrena')).decision, RetrievalDecision.noSource);
    });

    test('offTopic without domain word', () async {
      expect(
        (await r.search('przepis na pierogi')).decision,
        RetrievalDecision.offTopic,
      );
      expect((await r.search('')).decision, RetrievalDecision.offTopic);
    });

    test('noSource when domain word present but score above floor', () async {
      final strict = Retriever(
        _synthetic(),
        stopwords: _stopwords(),
        floor: -1000,
      );
      final res = await strict.search('syrena');
      expect(res.decision, RetrievalDecision.noSource);
      expect(res.chunks, isEmpty);
    });

    test('noSource when domain word has no matching row', () async {
      // "zapas" is domain vocabulary (keyword) but "zapasy" stem has rows... use
      // a keyword that is not in any indexed text.
      final kb = _synthetic();
      kb.db.execute(
        "UPDATE chunks SET keywords = '[\"wyjatkowo\"]' WHERE id = 'c1'",
      );
      final rr = Retriever(kb, stopwords: _stopwords(), floor: 0);
      final res = await rr.search('wyjatkowo');
      expect(res.decision, RetrievalDecision.noSource);
    });

    test('sourcesFor returns quote-panel fields', () async {
      final m = await r.sourcesFor(['c2', 'nope']);
      expect(m.keys, ['c2']);
      expect(m['c2']!.pageLabel, '6');
      expect(m['c2']!.pdfPage, 3);
      expect(m['c2']!.original, 'orig');
      expect(await r.sourcesFor([]), isEmpty);
    });

    test('k limits results', () async {
      final res = await r.search('woda syrena powodz', k: 2);
      expect(res.chunks.length, lessThanOrEqualTo(2));
    });

    test('FTS syntax in user input does not throw', () async {
      for (final q in [
        '"',
        '*',
        'NEAR',
        'NEAR(a b)',
        'OR',
        'AND',
        '(',
        ')',
        '-',
        'syrena OR',
        '"syrena" *',
        '-syrena',
        'syrena AND NOT (woda',
        'col:syrena',
        "syrena'; DROP TABLE chunks;--",
      ]) {
        await r.search(q);
      }
      expect(
        (await r.search('"syrena" OR (woda')).decision,
        isNot(RetrievalDecision.offTopic),
      );
    });
  });

  group('real kb.sqlite', () {
    late Retriever r;
    late List vectors;
    setUpAll(() {
      if (!_hasKb) return;
      r = Retriever(
        KbDatabase(sqlite3.open(_kbPath, mode: OpenMode.readOnly)),
        stopwords: _stopwords(),
      );
      vectors =
          (jsonDecode(
                File('test/czat/retrieval/query_vectors.json')
                    .readAsStringSync(),
              ) as Map)['vectors']
              as List;
    });

    test('sample queries hit the same top-1 as Python', () async {
      for (final v in vectors) {
        final top = v['top'] as List;
        if (top.isEmpty) continue;
        final res = await r.search(v['query'] as String);
        if (res.decision != RetrievalDecision.found) continue; // gate refused
        expect(res.chunks.first.id, top.first[0], reason: v['query'] as String);
        expect(
          res.chunks.first.score,
          closeTo((top.first[1] as num).toDouble(), 1e-4),
        );
      }
      // The five "must" samples of tools/kb_samples.md are always found.
      for (final q in [
        'co robić gdy wyje syrena',
        'ile wody na osobę',
        'jak uciskać klatkę piersiową',
        'powódź ewakuacja',
        'brak prądu',
      ]) {
        final res = await r.search(q);
        expect(res.decision, RetrievalDecision.found, reason: q);
        final py = vectors.firstWhere((v) => v['query'] == q)['top'] as List;
        expect(res.chunks.first.id, py.first[0], reason: q);
      }
    }, skip: _hasKb ? false : _skip);

    // QA 07:45 B-06/B-10: "dzien" alone stems to "dzie*" (= "dzieci"), so the
    // AED-for-children chunk won; "na dzień" <-> "na dobę" reaches the KB wording.
    test(
      'water per day and evacuation documents hit the right chunk',
      () async {
        for (final (q, id) in [
          ('ile wody na osobe na dzien', 'rcb-poradnik-2025-s21-f1'),
          ('ile wody pic dziennie', 'rcb-poradnik-2025-s21-f1'),
          ('zapas wody na osobe', 'rcb-poradnik-2025-s21-f1'),
          (
            'jakie dokumenty zabrac przy ewakuacji',
            'rcb-powodz-poradnik-2024-s20-f1',
          ),
        ]) {
          final res = await r.search(q);
          expect(res.decision, RetrievalDecision.found, reason: q);
          expect(res.chunks.first.id, id, reason: q);
        }
      },
      skip: _hasKb ? false : _skip,
    );

    test('typos and missing diacritics are still found', () async {
      for (final q in [
        'co robic gdy wyje syrena',
        'brak pradu',
        'powodz',
        'jak uciskac klatke',
        'POWÓDŹ',
        'zadlawil sie',
        'krwotok z nogi',
      ]) {
        final res = await r.search(q);
        expect(res.decision, RetrievalDecision.found, reason: q);
        expect(res.chunks, isNotEmpty);
      }
    }, skip: _hasKb ? false : _skip);

    test('off-topic questions are offTopic', () async {
      for (final q in [
        'przepis na pierogi',
        'kto wygra mecz',
        'pogoda jutro',
        'bitcoin',
      ]) {
        expect(
          (await r.search(q)).decision,
          RetrievalDecision.offTopic,
          reason: q,
        );
      }
    }, skip: _hasKb ? false : _skip);

    test('BG91: typos in normal questions are repaired', () async {
      // question -> chunk id expected among the hits
      const cases = {
        'nie ma prundu co robci': 'rcb-poradnik-2025-s33-f1', // nasal, swap
        'co zrbic jak nie ma prdu i wdy w bloku': 'rcb-poradnik-2025-s33-f1',
        'brak prdu': 'rcb-poradnik-2025-s33-f1', // missing letter
        'jak zatamowac krwawinie': 'erc-2025-pierwsza-pomoc-s12-f1',
        'jak zatamowac krowtok': 'erc-2025-pierwsza-pomoc-s12-f1', // swap
      };
      for (final e in cases.entries) {
        final res = await r.search(e.key);
        expect(res.decision, RetrievalDecision.found, reason: e.key);
        expect(res.chunks.map((c) => c.id), contains(e.value), reason: e.key);
      }
      // The repaired question ranks like the correctly spelled one.
      final fixed = await r.search('nie ma prundu co robci');
      final exact = await r.search('nie ma pradu co robic');
      expect(fixed.chunks.first.id, exact.chunks.first.id);
    }, skip: _hasKb ? false : _skip);

    test('BG91: typo repair keeps refusals', () async {
      for (final q in [
        'przepis na pierogi',
        'kto wygra mecz w sobotę',
        'ile kosztuje bitcoin',
        'przepis na ciasto', // "ciasto" is not rewritten to "ciało"
        'co obejrzec w kinie', // real words missing from the KB stay
        'jak zrobic pranie',
        'jak sie ubrac na wesele',
        'zakupy na sobote',
      ]) {
        expect(
          (await r.search(q)).decision,
          RetrievalDecision.offTopic,
          reason: q,
        );
      }
      for (final q in [
        'ugryzienie węża',
        'Co robić przy ugryzieniu węża?',
        'ugryzenie weza', // typo of an absent safety topic: no source
        'trzęsenie zimi co robic',
      ]) {
        expect(
          (await r.search(q)).decision,
          RetrievalDecision.noSource,
          reason: q,
        );
      }
    }, skip: _hasKb ? false : _skip);

    test('in-domain but absent topics (documented behaviour)', () async {
      // "agregat" is a keyword of rcb-poradnik-2025-s33 (power cut), so the
      // question is in-domain and retrieval is found (-4.43 on this build);
      // the validator/LLM layers decide what the chunk can answer.
      final agr = await r.search('jak naprawić agregat prądotwórczy diesla');
      expect(agr.decision, RetrievalDecision.found);
      expect(agr.chunks.first.id, 'rcb-poradnik-2025-s33-f1');
      // Medical question whose words are absent from the vocabulary: the
      // domain gate cannot see it as in-domain => offTopic (KB-only vocabulary;
      // the coordinator can extend it via Retriever.extraVocabulary).
      final dog = await r.search('jaką dawkę ibuprofenu dać psu');
      expect(dog.decision, RetrievalDecision.noSource);
    }, skip: _hasKb ? false : _skip);

    test('BG03: safety questions absent from the KB are noSource', () async {
      for (final q in [
        'ugryzienie węża',
        'ugryzienie weza',
        'co zrobić po ugryzieniu węża',
        'zatrucie grzybami',
        'zatrucie grzybami co robic',
        'zatrucie grzybow',
        'trzęsienie ziemi',
        'trzesienie ziemi',
        'co robić podczas trzęsienia ziemi',
        'dawka ibuprofenu',
        'jaka dawka paracetamolu dla dziecka',
        'DAWKA IBUPROFENU',
        'oparzenie chemiczne',
        'ukaszenie zmii',
        'atak epilepsji drgawki',
      ]) {
        final res = await r.search(q);
        expect(res.decision, isNot(RetrievalDecision.offTopic), reason: q);
        if (res.decision != RetrievalDecision.found) {
          expect(res.chunks, isEmpty, reason: q);
        }
      }
      for (final q in [
        'ugryzienie węża',
        'zatrucie grzybami',
        'trzęsienie ziemi',
        'dawka ibuprofenu',
      ]) {
        expect(
          (await r.search(q)).decision,
          RetrievalDecision.noSource,
          reason: q,
        );
      }
    }, skip: _hasKb ? false : _skip);

    test('BG03: truly off-topic stays offTopic', () async {
      for (final q in [
        'przepis na pierogi',
        'kto wygra mecz',
        'ile kosztuje bitcoin',
        'prawo jazdy kategoria b',
        'jak zrobić szarlotkę',
        'jaka jest stolica francji',
        'kiedy gra reprezentacja polski',
      ]) {
        expect(
          (await r.search(q)).decision,
          RetrievalDecision.offTopic,
          reason: q,
        );
      }
    }, skip: _hasKb ? false : _skip);

    test('BG03: synthetic DB, safety word without chunk is noSource', () async {
      final rr = Retriever(_synthetic(), stopwords: _stopwords(), floor: 0);
      expect(
        (await rr.search('ugryzienie węża')).decision,
        RetrievalDecision.noSource,
      );
      expect(
        (await rr.search('dawka ibuprofenu')).decision,
        RetrievalDecision.noSource,
      );
      expect(
        (await rr.search('przepis na pierogi')).decision,
        RetrievalDecision.offTopic,
      );
    });

    test('real DB: injection strings do not throw', () async {
      for (final q in [
        '"',
        '*',
        'NEAR',
        'OR',
        '(',
        '-',
        'pożar NEAR/3 woda',
        '"pozar" OR *',
      ]) {
        await r.search(q);
      }
    }, skip: _hasKb ? false : _skip);

    test('performance: mean < 50 ms over 50 queries', () async {
      final qs = [for (final v in vectors) v['query'] as String];
      final all = [for (var i = 0; i < 50; i++) qs[i % qs.length]];
      final sw = Stopwatch()..start();
      for (final q in all) {
        await r.search(q);
      }
      sw.stop();
      final mean = sw.elapsedMicroseconds / 1000 / all.length;
      // ignore: avoid_print
      print('mean search ms: ${mean.toStringAsFixed(2)}');
      expect(mean, lessThan(50));
    }, skip: _hasKb ? false : _skip);
  });
}
