import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ratunek/detect/normalize.dart';
import 'kb_database.dart';
import 'query_builder.dart';
import 'retriever.dart';
import 'stopwords_fallback.dart';

/// Stopwords from `assets/kb/stopwords.txt`, falling back to the const list.
Future<Set<String>> loadStopwords() async {
  try {
    final s = parseStopwords(
      await rootBundle.loadString('assets/kb/stopwords.txt'),
    );
    if (s.isNotEmpty) return s;
  } catch (_) {}
  return {for (final w in fallbackStopwords) normalizePl(w)};
}

/// Rescue-card phrases (`cards_index.json`) and risk phrases (`risk.json`,
/// leading `=` exact-match marker stripped) as extra domain vocabulary; empty
/// when unavailable.
Future<List<String>> loadRescuePhrases() async {
  final out = <String>[];
  try {
    final j = jsonDecode(
      await rootBundle.loadString('assets/phrases/cards_index.json'),
    );
    for (final c in (j['cards'] as List)) {
      for (final p in ((c as Map)['phrases'] as List)) {
        out.add(p.toString());
      }
    }
  } catch (_) {}
  try {
    final j = jsonDecode(
      await rootBundle.loadString('assets/phrases/risk.json'),
    );
    for (final p in (j['phrases'] as List)) {
      out.add(p.toString().replaceFirst('=', ''));
    }
  } catch (_) {}
  return out;
}

/// Opens the bundled knowledge base once and builds the [Retriever].
final retrieverProvider = FutureProvider<Retriever>((ref) async {
  final kb = await KbDatabase.openBundled();
  ref.onDispose(kb.close);
  return Retriever(
    kb,
    stopwords: await loadStopwords(),
    extraVocabulary: await loadRescuePhrases(),
  );
});
