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

    test('call panel is first and appears once', () {
      for (final c in repo.cards) {
        expect(c.panels.first, isA<CallPanel>());
        expect(c.panels.whereType<CallPanel>(), hasLength(1));
        final raw = (cardJson[c.id]!['panels'] as List).first as Map;
        expect(raw['type'], 'call', reason: '${c.id}: file has call first');
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
        expect(first.text, startsWith('Sprawdź oddech'));
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
          expect(steps[1].itemsFor(v).last.cardLink?.cardId, 'rko');
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
      expect(
        cpr.rateBpm,
        isNull,
        reason: 'sources give a range, not one tempo',
      );
      expect(cpr.rateBpmMin, 100);
      expect(cpr.rateBpmMax, 120);
      final rateOrig = orig(
        cardJson['rko']!['panels'][2]['rate_source_id'] as String,
      );
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

    test('values the sources do not give stay null (human fills them in)', () {
      final cpr = repo.card('rko')!.cpr!;
      expect(cpr.rescuerChangeS, isNull);
      expect(cpr.voice['change'], isNull);
      expect(cpr.variant('child')!.breathPhaseS, isNull);
      expect(cpr.variant('infant')!.breathPhaseS, isNull);
    });
  });
}
