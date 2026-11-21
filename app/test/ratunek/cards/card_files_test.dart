// Schema and faithfulness checks over the shipped rescue card files.
// Runs with the working directory `app/`, so the sources are `../content/...`.
import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/ratunek/cards/rescue_card.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Lowercase, no Polish diacritics, letters and digits only, no spaces. Used
/// for the strict "excerpt is on the page" check (immune to line wraps,
/// hyphenation and the text-layer artefacts of the poster pages).
String _squash(String s) {
  const from = 'ąćęłńóśźż';
  const to = 'acelnoszz';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    final c = i >= 0 ? to[i] : ch;
    if (RegExp(r'[a-z0-9]').hasMatch(c)) b.write(c);
  }
  return b.toString();
}

List<String> _tokens(String s) {
  const from = 'ąćęłńóśźż';
  const to = 'acelnoszz';
  var t = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    t = t.replaceAll(from[i], to[i]);
  }
  return RegExp(r'[a-z0-9]+').allMatches(t).map((m) => m.group(0)!).toList();
}

/// Page text with line-wrap hyphenation removed.
String _dehyphenate(String s) => s.replaceAllMapped(
  RegExp(r'(\w)-\s*\n\s*([a-ząćęłńóśźż])'),
  (m) => '${m[1]}${m[2]}',
);

Set<String> _digits(String s) =>
    RegExp(r'\d+').allMatches(s).map((m) => m.group(0)!).toSet();

class _Page {
  _Page(this.text);
  final String text;
}

final Map<String, Map<int, _Page>> _pageCache = {};

_Page _page(String docId, int pdfPage) {
  final docs = _pageCache.putIfAbsent(docId, () {
    final out = <int, _Page>{};
    final f = File('../content/sources/$docId/pages.jsonl');
    expect(f.existsSync(), isTrue, reason: 'missing ${f.path}');
    for (final line in f.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final j = jsonDecode(line) as Map<String, dynamic>;
      out[j['pdf_page'] as int] = _Page(j['text'] as String);
    }
    return out;
  });
  final p = docs[pdfPage];
  expect(p, isNotNull, reason: '$docId has no pdf_page $pdfPage');
  return p!;
}

void main() {
  const cardIds = ['rko', 'choking', 'bleeding', 'unconscious'];
  late Map<String, dynamic> sourcesJson;
  late Map<String, Map<String, dynamic>> cardJson;
  late RescueCardRepository repo;
  late Map<String, dynamic> index;

  setUpAll(() {
    sourcesJson = _json('assets/cards/sources.json');
    cardJson = {for (final id in cardIds) id: _json('assets/cards/$id.json')};
    index = _json('assets/phrases/cards_index.json');
    repo = RescueCardRepository(
      cards: cardJson.values.toList(),
      sources: sourcesJson,
    );
  });

  group('card files', () {
    test('every card file parses and has the contract fields', () {
      for (final id in cardIds) {
        final j = cardJson[id]!;
        for (final k in [
          'version',
          'id',
          'name',
          'priority',
          'phrases',
          'panels',
          'source_ids',
        ]) {
          expect(j.containsKey(k), isTrue, reason: '$id lacks $k');
        }
        final card = repo.card(id);
        expect(card, isNotNull);
        expect(card!.id, id);
        expect(card.name.length, lessThanOrEqualTo(30));
        expect(card.sourceIds, isNotEmpty);
      }
    });

    test('files have no call panel, the parser puts it first once', () {
      for (final c in repo.cards) {
        expect(c.panels.first, isA<CallPanel>());
        expect(c.panels.whereType<CallPanel>(), hasLength(1));
        final raw = (cardJson[c.id]!['panels'] as List).cast<Map>();
        expect(
          raw.map((p) => p['type']),
          isNot(contains('call')),
          reason: '${c.id}: the app adds call (contract)',
        );
      }
    });

    test('every step is at most 120 characters (one action per step)', () {
      var count = 0;
      for (final c in repo.cards) {
        for (final p in c.panels.whereType<StepsPanel>()) {
          for (final item in [
            ...p.items,
            for (final v in p.variants) ...v.items,
          ]) {
            count++;
            expect(
              item.text.length,
              lessThanOrEqualTo(120),
              reason: '${c.id}: "${item.text}"',
            );
          }
        }
      }
      expect(count, greaterThan(100));
    });

    test('card source ids never equal a content/knowledge chunk id', () {
      final chunkIds = <String>{};
      for (final d in Directory('../content/knowledge').listSync()) {
        if (d is! Directory) continue;
        for (final f in d.listSync()) {
          if (f is! File || !f.path.endsWith('.md')) continue;
          final name = f.uri.pathSegments.last;
          if (name == 'README.md') continue;
          chunkIds.add(name.substring(0, name.length - 3));
        }
      }
      expect(chunkIds, isNotEmpty, reason: 'content/knowledge is readable');
      final collisions = <String>[
        for (final s in repo.sources)
          if (chunkIds.contains(s.sourceId)) s.sourceId,
      ];
      expect(collisions, isEmpty);
      // The convention that keeps the ranges apart: card fragments are
      // numbered from 101 on each page.
      for (final s in repo.sources) {
        expect(
          int.parse(s.sourceId.split('-f').last),
          greaterThanOrEqualTo(101),
          reason: s.sourceId,
        );
      }
    });

    test('all cards are verify: true and cite a source', () {
      for (final c in repo.cards) {
        expect(cardJson[c.id]!['verify'], isTrue, reason: c.id);
        expect(c.isVerify, isTrue);
        expect(c.citedSourceIds, isNotEmpty);
        expect(
          c.sourceIds.toSet(),
          c.citedSourceIds,
          reason: '${c.id}: source_ids = every source_id used in panels',
        );
      }
    });

    test('card ids, priority, variants and phrases match cards_index.json', () {
      final idx = {
        for (final c in (index['cards'] as List)) (c as Map)['id'] as String: c,
      };
      expect(idx.keys.toSet(), cardIds.toSet());
      final vw = (index['variant_words'] as Map).cast<String, dynamic>();
      for (final c in repo.cards) {
        final ix = idx[c.id]!;
        expect(c.priority, ix['priority'], reason: c.id);
        expect(
          c.variantIds,
          (ix['variants'] as List).cast<String>(),
          reason: '${c.id} variants',
        );
        expect(
          c.phrases,
          (ix['phrases'] as List).cast<String>(),
          reason: '${c.id} phrases',
        );
        for (final v in c.variantIds) {
          if (vw.containsKey(v)) {
            expect(
              c.variantWords[v],
              (vw[v] as List).cast<String>(),
              reason: '${c.id} variant_words $v',
            );
          }
        }
      }
    });

    test(
      'the unconscious card starts with the breath check and links to rko',
      () {
        final u = repo.card('unconscious')!;
        final first = u.stepsFor(null).first;
        expect(
          first.text,
          'Udrożnij drogi oddechowe i sprawdź oddech: patrz, słuchaj, czuj do 10 s',
        );
        expect(first.cardLink?.cardId, 'rko');
        expect(first.cardLink?.label, 'Nie oddycha → RKO');
      },
    );

    test('rko has adult/child/infant and a cpr panel', () {
      final r = repo.card('rko')!;
      expect(r.variantIds, ['adult', 'child', 'infant']);
      expect(r.cpr, isNotNull);
      expect(r.cpr!.variants.map((v) => v.id), ['adult', 'child', 'infant']);
    });

    test(
      'choking has adult/child/infant and a loss-of-consciousness panel',
      () {
        final c = repo.card('choking')!;
        expect(c.variantIds, ['adult', 'child', 'infant']);
        final steps = c.panels.whereType<StepsPanel>().toList();
        expect(steps, hasLength(2));
        expect(steps[1].title, 'Gdy straci przytomność');
        for (final v in c.variantIds) {
          expect(steps[1].itemsFor(v)!.last.cardLink?.cardId, 'rko');
        }
      },
    );
  });

  group('sources.json', () {
    test('records are unique, well formed and cover every cited id', () {
      final list = (sourcesJson['sources'] as List)
          .cast<Map<String, dynamic>>();
      final ids = list.map((s) => s['source_id'] as String).toList();
      expect(ids.toSet(), hasLength(ids.length));
      final pattern = RegExp(r'^[a-z0-9-]+-s\d+-f\d+$');
      for (final s in list) {
        final id = s['source_id'] as String;
        expect(pattern.hasMatch(id), isTrue, reason: id);
        expect(id, '${s['doc_id']}-s${s['pdf_page']}-f${id.split('-f').last}');
        for (final k in [
          'doc_id',
          'doc_title',
          'doc_short',
          'publisher',
          'issued',
          'page_label',
          'pdf_page',
          'pdf_file',
          'original',
        ]) {
          expect(s[k], isNotNull, reason: '$id lacks $k');
        }
        expect((s['pdf_file'] as String).startsWith('${s['doc_id']}/'), isTrue);
      }
      final used = {for (final c in repo.cards) ...c.citedSourceIds};
      expect(used.difference(ids.toSet()), isEmpty);
      expect(
        ids.toSet().difference(used),
        isEmpty,
        reason: 'sources.json keeps only cited records',
      );
    });

    test('every step and cpr value has a source_id that exists', () {
      for (final c in repo.cards) {
        for (final id in c.citedSourceIds) {
          expect(repo.source(id), isNotNull, reason: '${c.id}: $id');
        }
      }
    });

    test('every doc_id is listed in content/sources/SOURCES.md', () {
      final md = File('../content/sources/SOURCES.md').readAsStringSync();
      final listed = RegExp(
        r'^\| ([a-z0-9-]+) \| `',
        multiLine: true,
      ).allMatches(md).map((m) => m.group(1)!).toSet();
      expect(listed, isNotEmpty);
      for (final s in repo.sources) {
        expect(listed, contains(s.docId), reason: s.sourceId);
      }
    });

    test('every original is at most 60 words and appears on its pdf_page', () {
      for (final s in repo.sources) {
        expect(
          s.original.split(RegExp(r'\s+')).length,
          lessThanOrEqualTo(60),
          reason: s.sourceId,
        );
        final page = _dehyphenate(_page(s.docId, s.pdfPage).text);
        // Token coverage >= 90 % (spec) ...
        final pageTokens = _tokens(page).toSet();
        final tok = _tokens(s.original);
        final hit = tok.where(pageTokens.contains).length;
        expect(
          hit / tok.length,
          greaterThanOrEqualTo(0.9),
          reason: '${s.sourceId}: ${s.original}',
        );
        // ... and, stricter, the whole excerpt is a contiguous run.
        expect(
          _squash(page),
          contains(_squash(s.original)),
          reason: '${s.sourceId}: excerpt is not contiguous on the page',
        );
      }
    });

    test('page_label is the printed number or the pdf page', () {
      for (final s in repo.sources) {
        expect(int.tryParse(s.pageLabel), isNotNull, reason: s.sourceId);
        expect(s.pageLabel, '${s.pdfPage}', reason: s.sourceId);
      }
    });
  });

  group('faithfulness', () {
    test('every number in a step appears in the cited original or page', () {
      for (final c in repo.cards) {
        for (final p in c.panels.whereType<StepsPanel>()) {
          final all = [...p.items, for (final v in p.variants) ...v.items];
          for (final item in all) {
            final src = repo.source(item.sourceId)!;
            final allowed = {
              ..._digits(src.original),
              ..._digits(_page(src.docId, src.pdfPage).text),
            };
            final missing = _digits(item.text).difference(allowed);
            expect(
              missing,
              isEmpty,
              reason: '${c.id}: "${item.text}" cites ${item.sourceId}',
            );
          }
        }
      }
    });

    test('step text shares most words with the cited original', () {
      // Cheap guard against a step citing an unrelated fragment: at least a
      // third of the step's longer words (>= 5 letters) must occur in the
      // excerpt. Paraphrase changes endings, so compare 5-letter stems.
      String stem(String w) => w.length > 5 ? w.substring(0, 5) : w;
      for (final c in repo.cards) {
        for (final item
            in c
                .stepsFor(null)
                .followedBy(
                  c.panels.whereType<StepsPanel>().expand(
                    (p) => p.variants.expand((v) => v.items),
                  ),
                )) {
          final src = repo.source(item.sourceId)!;
          final orig = _tokens(src.original).map(stem).toSet();
          final words = _tokens(item.text)
              .where((w) => w.length >= 5)
              .map(stem)
              .toList();
          if (words.isEmpty) continue;
          final hit = words.where(orig.contains).length;
          expect(
            hit / words.length,
            greaterThanOrEqualTo(0.34),
            reason: '${c.id}: "${item.text}" vs ${item.sourceId}',
          );
        }
      }
    });

    test('cpr numbers come from the cited originals', () {
      final cpr = repo.card('rko')!.cpr!;
      String orig(String id) => repo.source(id)!.original;
      expect(cpr.rateBpm, 110, reason: 'midpoint of the cited range');
      expect(cpr.rateNote, contains('środek'));
      expect(cpr.rateBpmMin, 100);
      expect(cpr.rateBpmMax, 120);
      final rateOrig = orig(cpr.rateSourceId!);
      expect(rateOrig, contains('100–120'));
      expect(cpr.effectiveRateBpm, 110);
      for (final v in cpr.variants) {
        final d = _digits(orig(v.sourceId));
        for (final n in [
          v.compressions, v.compressionsPblsTrained, v.breaths, v.breathPhaseS,
          // 0 initial breaths = adults start with compressions; it is the
          // absence of the child step, not a quoted number.
          if (v.initialBreaths != 0) v.initialBreaths,
        ]) {
          if (n != null) expect(d, contains('$n'), reason: '${v.id}: $n');
        }
      }
    });

    test('cpr has no null except child/infant breath_phase_s', () {
      final raw = (cardJson['rko']!['panels'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['type'] == 'cpr');
      final nulls = <String>[];
      void scan(String path, Object? v) {
        if (v == null) nulls.add(path);
        if (v is Map) v.forEach((k, x) => scan('$path.$k', x));
        if (v is List) {
          for (var i = 0; i < v.length; i++) {
            scan('$path[$i]', v[i]);
          }
        }
      }

      scan('cpr', raw);
      expect(nulls, [
        'cpr.variants[1].breath_phase_s',
        'cpr.variants[2].breath_phase_s',
      ]);
      final cpr = repo.card('rko')!.cpr!;
      expect(cpr.variant('child')!.breathPhaseS, isNull);
      expect(cpr.variant('infant')!.breathPhaseS, isNull);
      expect(cpr.variant('adult')!.breathPhaseS, 10);
    });

    test('rescuer change is 2 minutes, from the cited sentence', () {
      final cpr = repo.card('rko')!.cpr!;
      expect(cpr.rescuerChangeS, 120);
      final src = repo.source(cpr.rescuerChangeSourceId!)!;
      expect(src.docId, 'erc-2025-podsumowanie');
      expect(src.pdfPage, 72);
      expect(src.original, contains('zmieniaj co najmniej co 2 minuty'));
      expect(cpr.verifyNote, contains('zaawansowanych'));
      expect(cpr.voice['change'], isNotEmpty);
      expect(
        repo.card('rko')!.sourceIds,
        contains(src.sourceId),
        reason: 'source_ids lists it',
      );
    });

    test('the aed button is hidden: no aed card is shipped', () {
      expect(repo.card('aed'), isNull);
      expect(repo.card('rko')!.cpr!.aedCardId, isNull);
    });
  });

  group('fixes from the fidelity review', () {
    List<String> texts(String card, String variant, [int panel = 0]) {
      final p = repo.card(card)!.panels.whereType<StepsPanel>().toList()[panel];
      return [for (final i in p.itemsFor(variant)!) i.text];
    }

    test('rko child/infant: lay 5 breaths then 30:2, PBLS 15:2 apart', () {
      for (final v in ['child', 'infant']) {
        final t = texts('rko', v);
        final lay = t.indexOf(
          'Wykonaj 5 oddechów ratowniczych, potem uciskaj klatkę piersiową 30 razy i wykonaj 2 oddechy (30:2).',
        );
        expect(lay, isNonNegative, reason: v);
        final pbls = t.indexWhere(
          (x) => x.startsWith('Jeśli masz przeszkolenie PBLS: po 5 oddechach'),
        );
        expect(pbls, lay + 1, reason: v);
        expect(t[pbls], contains('15:2'));
        // 15 appears only in PBLS-labelled steps about the ratio.
        for (final x in t.where((x) => x.contains('15'))) {
          expect(x, contains('PBLS'), reason: '$v: $x');
        }
        final cpr = repo.card('rko')!.cpr!.variant(v)!;
        expect(cpr.compressions, 30);
        expect(cpr.breaths, 2);
        expect(cpr.initialBreaths, 5);
        expect(cpr.compressionsPblsTrained, 15);
        expect(
          repo.source(cpr.sourceId)!.original,
          allOf(contains('30:2'), contains('15:2')),
        );
      }
    });

    test('rko infant: no head-tilt step before the neutral-head step', () {
      final t = texts('rko', 'infant');
      expect(t.any((x) => x.contains('odgięciem głowy')), isFalse);
      expect(t.first, isNot(contains('odgięciem')));
      expect(
        t,
        contains(
          'Udrożnij drogi oddechowe i oceń oddech oraz oznaki życia maks. 10 s.',
        ),
      );
      expect(t.any((x) => x.contains('pozycji neutralnej')), isTrue);
      // The child keeps the PBLS head-tilt step.
      expect(
        texts('rko', 'child').any((x) => x.contains('odgięciem głowy')),
        isTrue,
      );
    });

    test('rko adult: AED unavailable and no-shock steps', () {
      final t = texts('rko', 'adult');
      expect(
        t,
        contains(
          'Jeśli defibrylacja nie jest zalecana, natychmiast wróć do RKO.',
        ),
      );
      expect(
        t,
        contains(
          'Jeśli AED jest niedostępne lub czekasz na nie, kontynuuj RKO.',
        ),
      );
      final items = repo
          .card('rko')!
          .panels
          .whereType<StepsPanel>()
          .first
          .itemsFor('adult')!;
      for (final i in items.where(
        (i) =>
            i.text.startsWith('Jeśli defibrylacja nie jest zalecana') ||
            i.text.startsWith('Jeśli AED jest niedostępne'),
      )) {
        final s = repo.source(i.sourceId)!;
        expect(s.docId, 'erc-2025-bls-algorytmy');
        expect(s.pdfPage, 3);
      }
    });

    test('unconscious: agonal breathing goes to rko, trauma stays supine', () {
      final u = repo.card('unconscious')!;
      final items = u.stepsFor(null);
      final agonal = items.firstWhere(
        (i) => i.text.startsWith('Przy oddechu agonalnym'),
      );
      expect(
        agonal.text,
        'Przy oddechu agonalnym (nieprawidłowym) nie układaj na boku – rozpocznij RKO.',
      );
      expect(agonal.cardLink?.cardId, 'rko');
      final trauma = items.firstWhere((i) => i.text.startsWith('Po urazie'));
      expect(
        trauma.text,
        'Po urazie zostaw poszkodowanego leżącego na plecach.',
      );
      final src = repo.source(trauma.sourceId)!;
      expect(src.docId, 'erc-2025-pierwsza-pomoc');
      expect(src.pdfPage, 18);
      expect(
        src.original,
        contains('należy zachować ułożenie w pozycji leżącej na plecach'),
      );
      expect(
        items.any(
          (i) => i.text.startsWith('Nie układaj w pozycji bezpiecznej'),
        ),
        isFalse,
      );
      final first = repo.source(items.first.sourceId)!;
      expect(first.docId, 'erc-2025-pierwsza-pomoc-algorytmy');
      expect(first.pdfPage, 3);
    });

    test('choking: "lub karmienia" and the 112 call right after step 1', () {
      for (final v in ['child', 'infant']) {
        expect(
          texts('choking', v).any((x) => x.contains('jedzenia lub karmienia')),
          isTrue,
          reason: v,
        );
      }
      final adult = texts('choking', 'adult');
      expect(adult[3], 'Zadzwoń pod numer ratunkowy 112/999.');
      final firstBlows = adult.indexWhere((x) => x.contains('uderzeń'));
      expect(
        adult.indexOf('Zadzwoń pod numer ratunkowy 112/999.'),
        lessThan(firstBlows),
      );
      final call = repo
          .card('choking')!
          .panels
          .whereType<StepsPanel>()
          .first
          .itemsFor('adult')![3];
      expect(repo.source(call.sourceId)!.pdfPage, 93);
    });
  });
}
